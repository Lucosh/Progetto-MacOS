import Foundation

extension FeniceStore {
    public func tutors(teaching subjectId: Int) -> [User] {
        allUsers.filter { $0.role == .tutor && $0.isActive && $0.subjectIds.contains(subjectId) }
    }

    /// tutor della materia che hanno almeno un orario libero per quella durata
    public func availableTutors(subjectId: Int, durationMinutes: Int, studentId: Int) -> [User] {
        tutors(teaching: subjectId).filter {
            !freeSlots(tutorId: $0.id, studentId: studentId, durationMinutes: durationMinutes).isEmpty
        }
    }

    public func setTeaches(tutorId: Int, subjectId: Int, enabled: Bool) throws {
        guard let tutor = user(tutorId), tutor.role == .tutor else {
            throw FeniceError("Solo i tutor possono scegliere le materie.")
        }
        guard subject(subjectId) != nil else { throw FeniceError("Materia non trovata.") }
        try mutate { db in
            guard let index = db.users.firstIndex(where: { $0.id == tutorId }) else { return }
            if enabled {
                if !db.users[index].subjectIds.contains(subjectId) {
                    db.users[index].subjectIds.append(subjectId)
                }
            } else {
                db.users[index].subjectIds.removeAll { $0 == subjectId }
            }
        }
    }
}
