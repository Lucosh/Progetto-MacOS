import Foundation

public enum BalanceOperation: String, CaseIterable, Identifiable, Sendable {
    case payment
    case credit
    case setBalance

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .payment: return "Registra pagamento"
        case .credit: return "Aggiungi credito"
        case .setBalance: return "Imposta saldo"
        }
    }
}

extension FeniceStore {
    @discardableResult
    func requireAdmin(_ id: Int) throws -> User {
        guard let admin = user(id), admin.role == .admin, admin.isActive else {
            throw FeniceError("Operazione riservata all'amministrazione.")
        }
        return admin
    }

    // MARK: - Utenti

    @discardableResult
    public func createUser(adminId: Int, role: Role, firstName: String, lastName: String, email: String, password: String) throws -> User {
        let admin = try requireAdmin(adminId)
        let first = firstName.trimmed
        guard !first.isEmpty else { throw FeniceError("Inserisci il nome.") }
        let mail = try validatedEmail(email)
        try validatePassword(password)
        guard !emailTaken(mail) else { throw FeniceError("Esiste già un account con questa email.") }
        let current = now()
        return try mutate { db in
            let user = FeniceStore.makeUser(
                in: &db, hasher: hasher, email: mail, password: password,
                role: role, firstName: first, lastName: lastName.trimmed, date: current
            )
            db.notify(user.id, title: "Benvenuto in Fenice", body: "Il tuo account è stato creato da \(admin.fullName).", at: current)
            return user
        }
    }

    public func updateUser(
        adminId: Int,
        userId: Int,
        firstName: String,
        lastName: String,
        email: String,
        phone: String,
        parent1Phone: String,
        parent2Phone: String,
        role: Role
    ) throws {
        try requireAdmin(adminId)
        guard let target = user(userId) else { throw FeniceError("Utente non trovato.") }
        let first = firstName.trimmed
        guard !first.isEmpty else { throw FeniceError("Il nome non può essere vuoto.") }
        let mail = try validatedEmail(email)
        guard !emailTaken(mail, except: userId) else { throw FeniceError("Questa email è già usata da un altro account.") }
        if role != target.role {
            guard userId != adminId else { throw FeniceError("Non puoi cambiare il tuo ruolo.") }
            let busy = db.bookings.contains {
                $0.status == .confirmed && ($0.studentId == userId || $0.tutorId == userId)
            }
            guard !busy else { throw FeniceError("Non puoi cambiare ruolo a chi ha lezioni in programma.") }
        }
        try mutate { db in
            guard let index = db.users.firstIndex(where: { $0.id == userId }) else { return }
            db.users[index].firstName = first
            db.users[index].lastName = lastName.trimmed
            db.users[index].email = mail
            db.users[index].phone = phone.trimmed
            db.users[index].parent1Phone = parent1Phone.trimmed
            db.users[index].parent2Phone = parent2Phone.trimmed
            db.users[index].role = role
            if role != .tutor {
                db.users[index].subjectIds = []
            }
        }
    }

    /// soft-delete: l'utente resta nello storico ma non può più entrare
    public func setUserActive(adminId: Int, userId: Int, active: Bool) throws {
        try requireAdmin(adminId)
        guard userId != adminId else { throw FeniceError("Non puoi disattivare il tuo account.") }
        try mutate { db in
            guard let index = db.users.firstIndex(where: { $0.id == userId }) else { return }
            db.users[index].isActive = active
        }
    }

    public func resetPassword(adminId: Int, userId: Int, newPassword: String) throws {
        try requireAdmin(adminId)
        guard user(userId) != nil else { throw FeniceError("Utente non trovato.") }
        try validatePassword(newPassword)
        try setPassword(userId: userId, password: newPassword)
    }

    public func adjustBalance(adminId: Int, userId: Int, operation: BalanceOperation, amountCents: Int) throws {
        let admin = try requireAdmin(adminId)
        guard let target = user(userId), target.role == .student else {
            throw FeniceError("Il saldo si gestisce solo per gli studenti.")
        }
        let delta: Int
        let type: TransactionType
        let description: String
        switch operation {
        case .payment:
            guard amountCents > 0 else { throw FeniceError("L'importo deve essere maggiore di zero.") }
            delta = amountCents
            type = .payment
            description = "Pagamento registrato"
        case .credit:
            guard amountCents > 0 else { throw FeniceError("L'importo deve essere maggiore di zero.") }
            delta = amountCents
            type = .topUp
            description = "Credito aggiunto"
        case .setBalance:
            delta = amountCents - target.balanceCents
            type = .adjustment
            description = "Saldo impostato a \(Format.euros(amountCents))"
        }
        guard delta != 0 else { return }
        let current = now()
        try mutate { db in
            db.addTransaction(
                userId: userId, amountCents: delta, type: type, description: description,
                bookingId: nil, createdById: admin.id, at: current
            )
            db.notify(
                userId,
                title: "Saldo aggiornato",
                body: "\(description). Nuovo saldo: \(Format.euros(target.balanceCents + delta)).",
                at: current
            )
        }
    }

    // MARK: - Materie e impostazioni

    @discardableResult
    public func addSubject(adminId: Int, name: String, hourlyRateCents: Int?) throws -> Subject {
        try requireAdmin(adminId)
        let clean = try validatedSubject(name: name, hourlyRateCents: hourlyRateCents, except: nil)
        return try mutate { db in
            let created = Subject(id: db.makeId(), name: clean, hourlyRateCents: hourlyRateCents)
            db.subjects.append(created)
            return created
        }
    }

    public func updateSubject(adminId: Int, subjectId: Int, name: String, hourlyRateCents: Int?) throws {
        try requireAdmin(adminId)
        guard subject(subjectId) != nil else { throw FeniceError("Materia non trovata.") }
        let clean = try validatedSubject(name: name, hourlyRateCents: hourlyRateCents, except: subjectId)
        try mutate { db in
            guard let index = db.subjects.firstIndex(where: { $0.id == subjectId }) else { return }
            db.subjects[index].name = clean
            db.subjects[index].hourlyRateCents = hourlyRateCents
        }
    }

    public func deleteSubject(adminId: Int, subjectId: Int) throws {
        try requireAdmin(adminId)
        guard !db.bookings.contains(where: { $0.subjectId == subjectId }) else {
            throw FeniceError("Non puoi eliminare una materia che ha già delle lezioni.")
        }
        try mutate { db in
            db.subjects.removeAll { $0.id == subjectId }
            for index in db.users.indices {
                db.users[index].subjectIds.removeAll { $0 == subjectId }
            }
        }
    }

    public func updateHourlyRate(adminId: Int, cents: Int) throws {
        try requireAdmin(adminId)
        guard cents > 0 else { throw FeniceError("La tariffa deve essere maggiore di zero.") }
        try mutate { db in
            db.settings.hourlyRateCents = cents
        }
    }

    private func validatedSubject(name: String, hourlyRateCents: Int?, except subjectId: Int?) throws -> String {
        let clean = name.trimmed
        guard !clean.isEmpty else { throw FeniceError("Inserisci il nome della materia.") }
        if let rate = hourlyRateCents, rate <= 0 {
            throw FeniceError("La tariffa deve essere maggiore di zero.")
        }
        let duplicate = db.subjects.contains {
            $0.id != subjectId && $0.name.lowercased() == clean.lowercased()
        }
        guard !duplicate else { throw FeniceError("Esiste già una materia con questo nome.") }
        return clean
    }

    // MARK: - Riepiloghi

    public func upcomingBookings(limit: Int = 20) -> [Booking] {
        Array(db.bookings.filter { $0.status == .confirmed }.sorted { $0.start < $1.start }.prefix(limit))
    }

    /// somma dei saldi negativi degli studenti, in centesimi (numero positivo)
    public var totalOutstandingCents: Int {
        db.users
            .filter { $0.role == .student && $0.balanceCents < 0 }
            .reduce(0) { $0 - $1.balanceCents }
    }

    // MARK: - Dati di prova

    public static let demoPassword = "demo12345"

    /// tutor@demo.it e studente@demo.it, con cinque fasce nei prossimi giorni
    public func addDemoData(adminId: Int) throws {
        try requireAdmin(adminId)
        let current = now()
        try mutate { db in
            if !db.users.contains(where: { $0.email == "tutor@demo.it" }) {
                let tutor = FeniceStore.makeUser(
                    in: &db, hasher: hasher, email: "tutor@demo.it", password: FeniceStore.demoPassword,
                    role: .tutor, firstName: "Giulia", lastName: "Bianchi", date: current
                )
                let taught = db.subjects.filter { ["Matematica", "Fisica"].contains($0.name) }.map(\.id)
                if let index = db.users.firstIndex(where: { $0.id == tutor.id }) {
                    db.users[index].subjectIds = taught
                    db.users[index].phone = "+39 333 1234567"
                }
            }
            if !db.users.contains(where: { $0.email == "studente@demo.it" }) {
                FeniceStore.makeUser(
                    in: &db, hasher: hasher, email: "studente@demo.it", password: FeniceStore.demoPassword,
                    role: .student, firstName: "Marco", lastName: "Rossi", date: current
                )
            }
            guard let tutor = db.users.first(where: { $0.email == "tutor@demo.it" }) else { return }
            let hasBands = db.availabilities.contains { $0.tutorId == tutor.id && $0.start > current }
            guard !hasBands else { return }
            let today = calendar.startOfDay(for: current)
            for offset in 1...5 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                let id = db.makeId()
                db.availabilities.append(Availability(
                    id: id,
                    tutorId: tutor.id,
                    start: date(on: day, minutes: 15 * 60),
                    end: date(on: day, minutes: 19 * 60)
                ))
            }
        }
    }
}
