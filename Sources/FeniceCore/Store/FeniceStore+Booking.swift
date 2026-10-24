import Foundation

extension FeniceStore {
    public func hourlyRate(subjectId: Int) -> Int {
        subject(subjectId)?.hourlyRateCents ?? db.settings.hourlyRateCents
    }

    public func price(subjectId: Int, durationMinutes: Int) -> Int {
        hourlyRate(subjectId: subjectId) * durationMinutes / 60
    }

    public func bookings(forStudent studentId: Int) -> [Booking] {
        db.bookings.filter { $0.studentId == studentId }.sorted { $0.start < $1.start }
    }

    public func bookings(forTutor tutorId: Int) -> [Booking] {
        db.bookings.filter { $0.tutorId == tutorId }.sorted { $0.start < $1.start }
    }

    @discardableResult
    public func bookLesson(
        studentId: Int,
        tutorId: Int,
        subjectId: Int,
        start: Date,
        durationMinutes: Int,
        canAdvance: Bool,
        note: String
    ) throws -> Booking {
        guard Schedule.lessonDurations.contains(durationMinutes) else {
            throw FeniceError("Durata della lezione non valida.")
        }
        guard let student = user(studentId), student.role == .student, student.isActive else {
            throw FeniceError("Solo gli studenti possono prenotare lezioni.")
        }
        guard let lessonSubject = subject(subjectId) else { throw FeniceError("Materia non trovata.") }
        guard let tutor = user(tutorId), tutor.role == .tutor, tutor.isActive, tutor.subjectIds.contains(subjectId) else {
            throw FeniceError("Questo tutor non insegna la materia scelta.")
        }
        let cleanNote = note.trimmed
        guard cleanNote.count <= 300 else {
            throw FeniceError("La nota per il tutor può avere al massimo 300 caratteri.")
        }
        let slots = freeSlots(tutorId: tutorId, studentId: studentId, durationMinutes: durationMinutes)
        guard let slot = slots.first(where: { $0.start == start }) else {
            throw FeniceError("Questo orario non è più disponibile, scegline un altro.")
        }
        let amount = price(subjectId: subjectId, durationMinutes: durationMinutes)
        let current = now()

        return try mutate { db in
            let booking = Booking(
                id: db.makeId(),
                studentId: studentId,
                tutorId: tutorId,
                subjectId: subjectId,
                availabilityId: slot.availabilityId,
                start: slot.start,
                end: slot.end,
                durationMinutes: durationMinutes,
                canAdvance: canAdvance,
                note: cleanNote,
                priceCents: amount,
                status: .confirmed,
                chargedAt: nil,
                refundedAt: nil,
                createdAt: current
            )
            db.bookings.append(booking)
            db.notify(
                tutorId,
                title: "Nuova lezione prenotata",
                body: "\(student.fullName) ha prenotato \(lessonSubject.name) (\(Format.duration(durationMinutes))) per \(Format.dateTime(slot.start)).",
                at: current
            )
            db.notify(
                studentId,
                title: "Lezione confermata",
                body: "\(lessonSubject.name) con \(tutor.fullName), \(Format.dateTime(slot.start)).",
                at: current
            )
            return booking
        }
    }
}
