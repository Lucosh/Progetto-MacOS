import Foundation

extension FeniceStore {
    public func updateProfile(userId: Int, firstName: String, lastName: String, phone: String, parent1Phone: String, parent2Phone: String) throws {
        let first = firstName.trimmed
        guard !first.isEmpty else { throw FeniceError("Il nome non può essere vuoto.") }
        try mutate { db in
            guard let index = db.users.firstIndex(where: { $0.id == userId }) else { return }
            db.users[index].firstName = first
            db.users[index].lastName = lastName.trimmed
            db.users[index].phone = phone.trimmed
            // i telefoni dei genitori servono solo per gli studenti
            if db.users[index].role == .student {
                db.users[index].parent1Phone = parent1Phone.trimmed
                db.users[index].parent2Phone = parent2Phone.trimmed
            }
        }
    }

    // MARK: - Notifiche

    public func notifications(forUser userId: Int) -> [AppNotification] {
        db.notifications
            .filter { $0.userId == userId }
            .sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
    }

    public func unreadCount(forUser userId: Int) -> Int {
        db.notifications.filter { $0.userId == userId && !$0.isRead }.count
    }

    public func markNotificationRead(id: Int, userId: Int) throws {
        guard db.notifications.contains(where: { $0.id == id && $0.userId == userId && !$0.isRead }) else { return }
        let current = now()
        try mutate { db in
            guard let index = db.notifications.firstIndex(where: { $0.id == id }) else { return }
            db.notifications[index].readAt = current
        }
    }

    public func markAllNotificationsRead(userId: Int) throws {
        guard unreadCount(forUser: userId) > 0 else { return }
        let current = now()
        try mutate { db in
            for index in db.notifications.indices where db.notifications[index].userId == userId && db.notifications[index].readAt == nil {
                db.notifications[index].readAt = current
            }
        }
    }

    // MARK: - Tutor

    /// lezioni confermate del tutor, dalla prossima in poi
    public func agenda(tutorId: Int) -> [Booking] {
        bookings(forTutor: tutorId).filter { $0.status == .confirmed }
    }

    /// studenti che hanno prenotato almeno una lezione con il tutor
    public func students(ofTutor tutorId: Int) -> [User] {
        let ids = Set(db.bookings.filter { $0.tutorId == tutorId }.map(\.studentId))
        return allUsers.filter { ids.contains($0.id) }
    }

    public func nextLesson(studentId: Int, tutorId: Int) -> Booking? {
        agenda(tutorId: tutorId).first { $0.studentId == studentId }
    }
}
