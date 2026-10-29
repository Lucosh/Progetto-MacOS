import Foundation

extension AppDatabase {
    mutating func charge(bookingAt index: Int, now: Date) {
        let booking = bookings[index]
        guard booking.chargedAt == nil, booking.priceCents > 0 else { return }
        bookings[index].chargedAt = now
        addTransaction(
            userId: booking.studentId,
            amountCents: -booking.priceCents,
            type: .charge,
            description: "Lezione del \(Format.dateTime(booking.start))",
            bookingId: booking.id,
            createdById: nil,
            at: now
        )
    }

    mutating func refund(bookingAt index: Int, now: Date) {
        let booking = bookings[index]
        guard booking.chargedAt != nil, booking.refundedAt == nil else { return }
        bookings[index].refundedAt = now
        addTransaction(
            userId: booking.studentId,
            amountCents: booking.priceCents,
            type: .refund,
            description: "Storno lezione del \(Format.dateTime(booking.start))",
            bookingId: booking.id,
            createdById: nil,
            at: now
        )
    }

    /// Addebita le lezioni che iniziano entro 12 ore e segna come svolte quelle finite.
    /// Restituisce true se ha cambiato qualcosa.
    @discardableResult
    mutating func runBillingCycle(now: Date) -> Bool {
        var changed = false
        for index in bookings.indices where bookings[index].status == .confirmed {
            let booking = bookings[index]
            let chargeDate = booking.start.addingTimeInterval(-Schedule.chargeLeadTime)
            if booking.chargedAt == nil && booking.priceCents > 0 && chargeDate <= now {
                charge(bookingAt: index, now: now)
                notify(
                    booking.studentId,
                    title: "Lezione addebitata",
                    body: "Addebitati \(Format.euros(booking.priceCents)) per la lezione del \(Format.dateTime(booking.start)).",
                    at: now
                )
                changed = true
            }
            if booking.end <= now {
                bookings[index].status = .completed
                // richieste mai decise: la lezione ormai c'è stata
                for request in cancellations.indices where cancellations[request].bookingId == booking.id {
                    if cancellations[request].status.isOpen {
                        cancellations[request].status = .expired
                        cancellations[request].decidedAt = now
                    }
                }
                changed = true
            }
        }
        return changed
    }
}

extension FeniceStore {
    /// Da chiamare all'avvio e periodicamente (l'app lo fa ogni minuto).
    public func runMaintenance() throws {
        var copy = db
        guard copy.runBillingCycle(now: now()) else { return }
        try persistence.save(copy)
        db = copy
    }

    public func transactions(forUser userId: Int) -> [BalanceTransaction] {
        db.transactions.filter { $0.userId == userId }.sorted { $0.createdAt > $1.createdAt }
    }
}
