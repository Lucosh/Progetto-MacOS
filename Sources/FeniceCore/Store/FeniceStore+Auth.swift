import Foundation

extension FeniceStore {
    public func login(email: String, password: String) throws -> User {
        let key = email.trimmed.lowercased()
        guard let user = db.users.first(where: { $0.email == key }),
              hasher.hash(password: password, salt: user.passwordSalt) == user.passwordHash else {
            throw FeniceError("Email o password non corretti.")
        }
        guard user.isActive else {
            throw FeniceError("Questo account è stato disattivato. Contatta l'amministrazione.")
        }
        return user
    }

    /// Gli studenti si registrano da soli, tutor e admin li crea l'amministrazione.
    @discardableResult
    public func registerStudent(firstName: String, lastName: String, email: String, password: String) throws -> User {
        let first = firstName.trimmed
        guard !first.isEmpty else { throw FeniceError("Inserisci il nome.") }
        let mail = try validatedEmail(email)
        try validatePassword(password)
        guard !emailTaken(mail) else { throw FeniceError("Esiste già un account con questa email.") }
        let current = now()
        return try mutate { db in
            let user = FeniceStore.makeUser(
                in: &db,
                hasher: hasher,
                email: mail,
                password: password,
                role: .student,
                firstName: first,
                lastName: lastName.trimmed,
                date: current
            )
            db.notifyAdmins(title: "Nuovo studente", body: "\(user.fullName) (\(mail)) si è registrato.", at: current)
            return user
        }
    }

    public func changePassword(userId: Int, currentPassword: String, newPassword: String) throws {
        guard let account = user(userId) else { throw FeniceError("Utente non trovato.") }
        guard hasher.hash(password: currentPassword, salt: account.passwordSalt) == account.passwordHash else {
            throw FeniceError("La password attuale non è corretta.")
        }
        try validatePassword(newPassword)
        try setPassword(userId: userId, password: newPassword)
    }

    func setPassword(userId: Int, password: String) throws {
        let salt = UUID().uuidString
        let hash = hasher.hash(password: password, salt: salt)
        try mutate { db in
            guard let index = db.users.firstIndex(where: { $0.id == userId }) else { return }
            db.users[index].passwordSalt = salt
            db.users[index].passwordHash = hash
        }
    }

    func validatedEmail(_ raw: String) throws -> String {
        let email = raw.trimmed.lowercased()
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              parts[1].contains("."),
              !parts[1].hasPrefix("."),
              !parts[1].hasSuffix("."),
              !email.contains(" ") else {
            throw FeniceError("Inserisci un indirizzo email valido.")
        }
        return email
    }

    func validatePassword(_ password: String) throws {
        guard password.count >= 8 else {
            throw FeniceError("La password deve avere almeno 8 caratteri.")
        }
    }

    func emailTaken(_ email: String, except userId: Int? = nil) -> Bool {
        db.users.contains { $0.email == email && $0.id != userId }
    }
}
