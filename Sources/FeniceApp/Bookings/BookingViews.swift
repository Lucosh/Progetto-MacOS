import FeniceCore
import SwiftUI

struct BookingRow: View {
    @EnvironmentObject private var app: AppState
    let booking: Booking
    var perspective: Role = .student

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.store.subjectName(booking.subjectId))
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Format.dateTime(booking.start))
                    .monospacedDigit()
                StatusBadge(text: booking.status.label, color: booking.status.color)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let who: String
        switch perspective {
        case .student: who = "con \(app.store.userName(booking.tutorId))"
        case .tutor: who = app.store.userName(booking.studentId)
        case .admin: who = "\(app.store.userName(booking.studentId)) · \(app.store.userName(booking.tutorId))"
        }
        return "\(who) · \(Format.duration(booking.durationMinutes))"
    }
}

struct BalanceCard: View {
    let cents: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saldo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Format.euros(cents))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(cents < 0 ? Color.red : Color.primary)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "eurosign.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(Color.fenice)
        }
        .padding(.vertical, 6)
    }

    private var caption: String {
        if cents < 0 { return "Da pagare" }
        if cents > 0 { return "Credito disponibile" }
        return "Sei in pari"
    }
}

struct BookingDetailView: View {
    @EnvironmentObject private var app: AppState
    let bookingId: Int
    @State private var askingCancellation = false

    var body: some View {
        if let booking = app.store.booking(bookingId), let me = app.currentUser {
            content(booking, me)
        } else {
            ContentUnavailableView("Lezione non trovata", systemImage: "questionmark.circle")
        }
    }

    private func content(_ booking: Booking, _ me: User) -> some View {
        Form {
            Section("Lezione") {
                LabeledContent("Materia", value: app.store.subjectName(booking.subjectId))
                LabeledContent("Quando", value: "\(Format.day(booking.start)), \(Format.timeRange(booking.start, booking.end))")
                LabeledContent("Durata", value: Format.duration(booking.durationMinutes))
                LabeledContent("Tutor", value: app.store.userName(booking.tutorId))
                LabeledContent("Studente", value: app.store.userName(booking.studentId))
                LabeledContent("Prezzo", value: Format.euros(booking.priceCents))
                LabeledContent("Stato") {
                    StatusBadge(text: booking.status.label, color: booking.status.color)
                }
                LabeledContent("Disponibile ad anticipare", value: booking.canAdvance ? "Sì" : "No")
                if !booking.note.isEmpty {
                    LabeledContent("Nota per il tutor", value: booking.note)
                }
            }
            Section("Addebito") {
                Text(chargeText(booking))
            }
            Section("Annullamento") {
                cancellationSection(booking, me)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(app.store.subjectName(booking.subjectId))
        .sheet(isPresented: $askingCancellation) {
            CancelRequestSheet(booking: booking)
                .environmentObject(app)
        }
    }

    private func chargeText(_ booking: Booking) -> String {
        if let refunded = booking.refundedAt {
            return "Addebitata e poi stornata il \(Format.timestamp(refunded))."
        }
        if let charged = booking.chargedAt {
            return "Addebitata il \(Format.timestamp(charged))."
        }
        if booking.status == .cancelled {
            return "Annullata, nessun addebito."
        }
        let when = booking.start.addingTimeInterval(-Schedule.chargeLeadTime)
        return "Verrà addebitata 12 ore prima dell'inizio (\(Format.dateTime(when)))."
    }

    @ViewBuilder
    private func cancellationSection(_ booking: Booking, _ me: User) -> some View {
        if let request = app.store.cancellation(forBooking: booking.id) {
            LabeledContent("Stato") {
                StatusBadge(text: request.status.label, color: request.status.color)
            }
            LabeledContent("Chiesta il", value: Format.timestamp(request.requestedAt))
            LabeledContent("Anticipo", value: request.isEarly ? "Almeno 12 ore prima" : "Meno di 12 ore prima")
            LabeledContent("Motivo", value: request.reason)
            if let decider = request.decidedById {
                LabeledContent("Decisa da", value: app.store.userName(decider))
            }
            if request.status.isOpen && canDecide(booking, me) {
                CancellationActions(request: request)
            }
        } else if me.role == .student && booking.status == .confirmed && booking.start > app.store.now() {
            Text("Puoi chiedere l'annullamento fino all'inizio della lezione. Se lo chiedi almeno 12 ore prima e viene approvato, la lezione non si paga.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Chiedi l'annullamento…") {
                askingCancellation = true
            }
        } else {
            Text("Nessuna richiesta di annullamento.")
                .foregroundStyle(.secondary)
        }
    }

    private func canDecide(_ booking: Booking, _ me: User) -> Bool {
        me.role == .admin || (me.role == .tutor && booking.tutorId == me.id)
    }
}

/// Pulsanti per tutor e admin su una richiesta ancora aperta.
struct CancellationActions: View {
    @EnvironmentObject private var app: AppState
    let request: CancellationRequest

    var body: some View {
        if let me = app.currentUser {
            HStack {
                Button("Approva") {
                    app.perform("Annullamento approvato") {
                        try app.store.decideCancellation(requestId: request.id, deciderId: me.id, approve: true)
                    }
                }
                Button("Rifiuta") {
                    app.perform("Annullamento rifiutato") {
                        try app.store.decideCancellation(requestId: request.id, deciderId: me.id, approve: false)
                    }
                }
                if me.role == .tutor && request.status == .pending {
                    Button("Inoltra all'admin") {
                        app.perform("Richiesta inoltrata") {
                            try app.store.forwardCancellation(requestId: request.id, tutorId: me.id)
                        }
                    }
                }
            }
            // in una riga di lista iOS altrimenti un tocco attiva tutti i pulsanti
            .buttonStyle(.bordered)
        }
    }
}

struct CancelRequestSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let booking: Booking
    @State private var reason = ""
    @State private var error: String?

    var body: some View {
        SheetForm(
            title: "Chiedi l'annullamento",
            confirmTitle: "Invia",
            confirmDisabled: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onConfirm: send
        ) {
            Section {
                Text("\(app.store.subjectName(booking.subjectId)), \(Format.dateTime(booking.start))")
                    .font(.headline)
                Text(info)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Motivo") {
                TextField("Perché vuoi annullare?", text: $reason, axis: .vertical)
                    .lineLimit(4...8)
            }
            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var info: String {
        if booking.start.timeIntervalSince(app.store.now()) >= Schedule.chargeLeadTime {
            return "Mancano più di 12 ore: se il tutor approva, la lezione non ti verrà addebitata."
        }
        return "Mancano meno di 12 ore: anche se approvata, la lezione resterà addebitata."
    }

    private func send() {
        guard let me = app.currentUser else { return }
        error = app.attempt("Richiesta inviata al tutor") {
            _ = try app.store.requestCancellation(bookingId: booking.id, studentId: me.id, reason: reason)
        }
        if error == nil {
            dismiss()
        }
    }
}
