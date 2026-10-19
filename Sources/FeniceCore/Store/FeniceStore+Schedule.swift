import Foundation

public struct TimeSlot: Hashable, Identifiable, Sendable {
    public let start: Date
    public let end: Date
    public let availabilityId: Int

    public var id: Date { start }
}

public enum Schedule {
    public static let lessonDurations = [60, 90, 120]
    public static let stepMinutes = 30
    public static let earliestStartMinutes = 7 * 60
    public static let latestEndMinutes = 23 * 60 + 30
    /// l'addebito scatta 12 ore prima dell'inizio
    public static let chargeLeadTime: TimeInterval = 12 * 60 * 60

    /// orari proposti per inizio/fine delle fasce, in minuti dalla mezzanotte
    public static var bandTimeOptions: [Int] {
        Array(stride(from: earliestStartMinutes, through: latestEndMinutes, by: stepMinutes))
    }

    static func overlaps(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
        aStart < bEnd && bStart < aEnd
    }
}

extension FeniceStore {
    public func date(on day: Date, minutes: Int) -> Date {
        let midnight = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: minutes, to: midnight) ?? midnight
    }

    func minutesFromMidnight(_ date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    public func availabilities(forTutor tutorId: Int) -> [Availability] {
        let current = now()
        return db.availabilities
            .filter { $0.tutorId == tutorId && $0.end > current }
            .sorted { $0.start < $1.start }
    }

    /// prenotazioni non annullate che cadono nella fascia
    public func bookings(inAvailability id: Int) -> [Booking] {
        db.bookings
            .filter { $0.availabilityId == id && $0.status != .cancelled }
            .sorted { $0.start < $1.start }
    }

    @discardableResult
    public func addAvailability(tutorId: Int, start: Date, end: Date) throws -> Availability {
        guard let tutor = user(tutorId), tutor.role == .tutor, tutor.isActive else {
            throw FeniceError("Solo i tutor possono pubblicare fasce di disponibilità.")
        }
        guard end > start else { throw FeniceError("La fine della fascia deve essere dopo l'inizio.") }
        guard start > now() else { throw FeniceError("Non puoi aggiungere una fascia nel passato.") }
        guard calendar.isDate(start, inSameDayAs: end) else {
            throw FeniceError("La fascia deve iniziare e finire nello stesso giorno.")
        }
        let startMinutes = minutesFromMidnight(start)
        let endMinutes = minutesFromMidnight(end)
        guard startMinutes % Schedule.stepMinutes == 0,
              endMinutes % Schedule.stepMinutes == 0,
              calendar.component(.second, from: start) == 0,
              calendar.component(.second, from: end) == 0 else {
            throw FeniceError("Usa orari a passi di 30 minuti (es. 18:00 o 18:30).")
        }
        guard endMinutes <= Schedule.latestEndMinutes else {
            throw FeniceError("Le fasce devono finire entro le 23:30.")
        }
        guard end.timeIntervalSince(start) >= 60 * 60 else {
            throw FeniceError("La fascia deve durare almeno un'ora.")
        }
        let clash = db.availabilities.contains {
            $0.tutorId == tutorId && Schedule.overlaps(start, end, $0.start, $0.end)
        }
        guard !clash else { throw FeniceError("Questa fascia si sovrappone a un'altra che hai già pubblicato.") }

        return try mutate { db in
            let band = Availability(id: db.makeId(), tutorId: tutorId, start: start, end: end)
            db.availabilities.append(band)
            return band
        }
    }

    public func deleteAvailability(id: Int, tutorId: Int) throws {
        guard let band = db.availabilities.first(where: { $0.id == id }), band.tutorId == tutorId else {
            throw FeniceError("Fascia non trovata.")
        }
        guard bookings(inAvailability: id).isEmpty else {
            throw FeniceError("Non puoi eliminare una fascia che ha già delle prenotazioni.")
        }
        try mutate { db in
            db.availabilities.removeAll { $0.id == id }
        }
    }

    /// Inizi ogni 30 minuti dentro le fasce future del tutor, saltando gli orari
    /// in cui il tutor o lo studente hanno già una lezione confermata.
    public func freeSlots(tutorId: Int, studentId: Int?, durationMinutes: Int) -> [TimeSlot] {
        let current = now()
        let length = TimeInterval(durationMinutes * 60)
        let step = TimeInterval(Schedule.stepMinutes * 60)
        let busy = db.bookings.filter { booking in
            booking.status == .confirmed
                && (booking.tutorId == tutorId || (studentId != nil && booking.studentId == studentId))
        }

        var slots: [TimeSlot] = []
        for band in db.availabilities where band.tutorId == tutorId && band.end > current {
            var start = band.start
            while start.addingTimeInterval(length) <= band.end {
                let end = start.addingTimeInterval(length)
                let isFree = !busy.contains { Schedule.overlaps(start, end, $0.start, $0.end) }
                if start > current && isFree {
                    slots.append(TimeSlot(start: start, end: end, availabilityId: band.id))
                }
                start = start.addingTimeInterval(step)
            }
        }
        return slots.sorted { $0.start < $1.start }
    }
}
