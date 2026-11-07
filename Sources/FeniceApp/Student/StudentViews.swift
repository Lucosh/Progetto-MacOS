import FeniceCore
import SwiftUI

struct StudentDashboardView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    var body: some View {
        let bookings = app.store.bookings(forStudent: user.id)
        let upcoming = bookings.filter { $0.status == .confirmed }
        let past = bookings.filter { $0.status != .confirmed }.reversed()

        List {
            Section {
                BalanceCard(cents: user.balanceCents)
            }
            Section("In programma") {
                if upcoming.isEmpty {
                    Text("Nessuna lezione in programma. Vai su Prenota per fissarne una.")
                        .foregroundStyle(.secondary)
                }
                ForEach(upcoming) { booking in
                    NavigationLink {
                        BookingDetailView(bookingId: booking.id)
                    } label: {
                        BookingRow(booking: booking)
                    }
                }
            }
            if !past.isEmpty {
                Section("Storico") {
                    ForEach(Array(past)) { booking in
                        NavigationLink {
                            BookingDetailView(bookingId: booking.id)
                        } label: {
                            BookingRow(booking: booking)
                        }
                    }
                }
            }
        }
        .navigationTitle("Ciao \(user.firstName)")
    }
}

struct BalanceView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    var body: some View {
        let movements = app.store.transactions(forUser: user.id)
        List {
            Section {
                BalanceCard(cents: user.balanceCents)
                Text("Le lezioni si pagano a debito: l'importo viene scalato dal saldo 12 ore prima dell'inizio. I pagamenti li registra l'amministrazione.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Movimenti") {
                if movements.isEmpty {
                    Text("Ancora nessun movimento.")
                        .foregroundStyle(.secondary)
                }
                ForEach(movements) { movement in
                    TransactionRow(transaction: movement)
                }
            }
        }
        .navigationTitle("Saldo")
    }
}

struct TransactionRow: View {
    let transaction: BalanceTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                Text("\(transaction.type.label) · \(Format.timestamp(transaction.createdAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.euros(transaction.amountCents))
                .monospacedDigit()
                .foregroundStyle(transaction.amountCents < 0 ? Color.red : Color.green)
        }
    }
}
