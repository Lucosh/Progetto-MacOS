import Foundation

// Regola: conta il momento della richiesta, non quello della decisione.
// Chiesta >= 12 h prima e approvata -> non si paga (storno se già addebitata).
// Chiesta < 12 h prima e approvata -> annullata ma resta addebitata.
extension FeniceStore {
    public func cancellation(forBooking bookingId: Int) -> CancellationRequest? {
        db.cancellations.first { $0.bookingId == bookingId }
    }

    public func openCancellations(forTutor tutorId: Int) -> [CancellationRequest] {
        db.cancellations
            .filter { request in request.status.isOpen && booking(request.bookingId)?.tutorId == tutorId }
            .sorted { $0.requestedAt < $1.requestedAt }
    }

    /// per l'admin: prima le inoltrate, poi le altre ancora aperte
    public func openCancellations() -> [CancellationRequest] {
        db.cancellations
            .filter { $0.status.isOpen }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status { return lhs.status == .forwarded }
                return lhs.requestedAt < rhs.requestedAt
            }
    }

    public func closedCancellations() -> [CancellationRequest] {
        db.cancellations
            .filter { !$0.status.isOpen }
            .sorted { ($0.decidedAt ?? $0.requestedAt) > ($1.decidedAt ?? $1.requestedAt) }
    }

    @discardableResult
    public func requestCancellation(bookingId: Int, studentId: Int, reason: String) throws -> CancellationRequest {
        guard let lesson = booking(bookingId), lesson.studentId == studentId else {
            throw FeniceError("Lezione non trovata.")
        }
        let current = now()
        guard lesson.status == .confirmed, lesson.start > current else {
            throw FeniceError("Questa lezione non si può più annullare.")
        }
        let text = reason.trimmed
        guard !text.isEmpty else { throw FeniceError("Scrivi il motivo dell'annullamento.") }
        guard text.count <= 500 else { throw FeniceError("Il motivo può avere al massimo 500 caratteri.") }
        guard cancellation(forBooking: bookingId) == nil else {
            throw FeniceError("Hai già inviato una richiesta di annullamento per questa lezione.")
        }
        let isEarly = lesson.start.timeIntervalSince(current) >= Schedule.chargeLeadTime
        let studentName = userName(studentId)

        return try mutate { db in
            let request = CancellationRequest(
                id: db.makeId(),
                bookingId: bookingId,
                requestedById: studentId,
                reason: text,
                requestedAt: current,
                isEarly: isEarly,
                status: .pending,
                decidedById: nil,
                decidedAt: nil
            )
            db.cancellations.append(request)
            db.notify(
                lesson.tutorId,
                title: "Richiesta di annullamento",
                body: "\(studentName) chiede di annullare la lezione del \(Format.dateTime(lesson.start)): \(text)",
                at: current
            )
            return request
        }
    }

    public func forwardCancellation(requestId: Int, tutorId: Int) throws {
        let (request, lesson) = try openRequest(requestId)
        guard lesson.tutorId == tutorId else { throw FeniceError("Questa richiesta non riguarda una tua lezione.") }
        guard request.status == .pending else { throw FeniceError("La richiesta è già stata inoltrata.") }
        let current = now()
        let body = "\(userName(tutorId)) ha inoltrato la richiesta di \(userName(lesson.studentId)) per la lezione del \(Format.dateTime(lesson.start))."
        try mutate { db in
            guard let index = db.cancellations.firstIndex(where: { $0.id == requestId }) else { return }
            db.cancellations[index].status = .forwarded
            db.notifyAdmins(title: "Annullamento da decidere", body: body, at: current)
        }
    }

    /// Decidono il tutor della lezione o un admin; vale la prima decisione.
    public func decideCancellation(requestId: Int, deciderId: Int, approve: Bool) throws {
        let (request, lesson) = try openRequest(requestId)
        guard let decider = user(deciderId), decider.isActive else { throw FeniceError("Utente non valido.") }
        switch decider.role {
        case .admin:
            break
        case .tutor where lesson.tutorId == deciderId:
            break
        default:
            throw FeniceError("Non puoi decidere su questa richiesta.")
        }
        let current = now()
        let when = Format.dateTime(lesson.start)
        let message: String
        if !approve {
            message = "La richiesta per la lezione del \(when) è stata rifiutata: la lezione resta confermata."
        } else if request.isEarly {
            message = "La lezione del \(when) è annullata e non ti verrà addebitata."
        } else {
            message = "La lezione del \(when) è annullata ma resta addebitata, perché la richiesta è arrivata a meno di 12 ore dall'inizio."
        }

        try mutate { db in
            guard let r = db.cancellations.firstIndex(where: { $0.id == requestId }),
                  let b = db.bookings.firstIndex(where: { $0.id == lesson.id }) else { return }
            db.cancellations[r].status = approve ? .approved : .rejected
            db.cancellations[r].decidedById = deciderId
            db.cancellations[r].decidedAt = current
            if approve {
                db.bookings[b].status = .cancelled
                if request.isEarly {
                    db.refund(bookingAt: b, now: current)
                } else {
                    db.charge(bookingAt: b, now: current)
                }
            }
            db.notify(lesson.studentId, title: approve ? "Annullamento approvato" : "Annullamento rifiutato", body: message, at: current)
            if decider.role == .admin {
                db.notify(
                    lesson.tutorId,
                    title: "Annullamento deciso dall'amministrazione",
                    body: "Lezione del \(when) con \(userName(lesson.studentId)): \(approve ? "approvato" : "rifiutato").",
                    at: current
                )
            }
        }
    }

    private func openRequest(_ id: Int) throws -> (CancellationRequest, Booking) {
        guard let request = db.cancellations.first(where: { $0.id == id }),
              let lesson = booking(request.bookingId) else {
            throw FeniceError("Richiesta non trovata.")
        }
        guard request.status.isOpen else { throw FeniceError("Questa richiesta è già stata decisa.") }
        guard lesson.status == .confirmed else { throw FeniceError("La lezione non è più modificabile.") }
        return (request, lesson)
    }
}
