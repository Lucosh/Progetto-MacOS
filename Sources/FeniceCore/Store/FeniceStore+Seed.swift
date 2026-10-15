import Foundation

extension FeniceStore {
    public static let defaultAdminEmail = "admin@ardentisfenice.it"
    public static let defaultAdminPassword = "admin1234"
    static let defaultSubjects = ["Matematica", "Fisica", "Inglese", "Italiano", "Chimica"]

    static func seededDatabase(hasher: PasswordHasher, date: Date) -> AppDatabase {
        var db = AppDatabase()
        for name in defaultSubjects {
            let id = db.makeId()
            db.subjects.append(Subject(id: id, name: name, hourlyRateCents: nil))
        }
        makeUser(
            in: &db,
            hasher: hasher,
            email: defaultAdminEmail,
            password: defaultAdminPassword,
            role: .admin,
            firstName: "Admin",
            lastName: "Fenice",
            date: date
        )
        return db
    }

    @discardableResult
    static func makeUser(
        in db: inout AppDatabase,
        hasher: PasswordHasher,
        email: String,
        password: String,
        role: Role,
        firstName: String,
        lastName: String,
        date: Date
    ) -> User {
        let salt = UUID().uuidString
        let user = User(
            id: db.makeId(),
            email: email,
            passwordHash: hasher.hash(password: password, salt: salt),
            passwordSalt: salt,
            role: role,
            firstName: firstName,
            lastName: lastName,
            phone: "",
            parent1Phone: "",
            parent2Phone: "",
            balanceCents: 0,
            isActive: true,
            subjectIds: [],
            createdAt: date
        )
        db.users.append(user)
        return user
    }
}
