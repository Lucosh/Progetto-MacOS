import FeniceCore
import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        let users = app.store.allUsers.filter(\.isActive)
        let upcoming = app.store.upcomingBookings(limit: 12)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    StatTile(title: "Studenti attivi", value: "\(users.filter { $0.role == .student }.count)", icon: "person.2")
                    StatTile(title: "Tutor attivi", value: "\(users.filter { $0.role == .tutor }.count)", icon: "person.crop.rectangle")
                    StatTile(title: "Lezioni in programma", value: "\(app.store.upcomingBookings(limit: .max).count)", icon: "calendar")
                    StatTile(title: "Annullamenti da decidere", value: "\(app.store.openCancellations().count)", icon: "xmark.circle")
                    StatTile(title: "Da incassare", value: Format.euros(app.store.totalOutstandingCents), icon: "eurosign.circle")
                }

                GroupBox("Prossime lezioni") {
                    if upcoming.isEmpty {
                        Text("Nessuna lezione in programma.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(upcoming) { booking in
                                NavigationLink {
                                    BookingDetailView(bookingId: booking.id)
                                } label: {
                                    BookingRow(booking: booking, perspective: .admin)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if booking.id != upcoming.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Panoramica")
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.fenice)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }
}

// MARK: - Annullamenti

struct AdminCancellationsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        let open = app.store.openCancellations()
        let closed = app.store.closedCancellations()
        List {
            Section("Da decidere") {
                if open.isEmpty {
                    Text("Niente da decidere.")
                        .foregroundStyle(.secondary)
                }
                ForEach(open) { request in
                    CancellationRow(request: request, showActions: true)
                }
            }
            Section("Storico") {
                if closed.isEmpty {
                    Text("Ancora nessuna richiesta chiusa.")
                        .foregroundStyle(.secondary)
                }
                ForEach(closed) { request in
                    CancellationRow(request: request)
                }
            }
        }
        .navigationTitle("Annullamenti")
    }
}

// MARK: - Materie

struct SubjectsView: View {
    @EnvironmentObject private var app: AppState
    let user: User
    @State private var editing: SubjectDraft?

    var body: some View {
        List {
            ForEach(app.store.subjects) { subject in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subject.name)
                            .font(.headline)
                        Text(rateText(subject))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(app.store.tutors(teaching: subject.id).count) tutor")
                        .foregroundStyle(.secondary)
                    Button {
                        editing = SubjectDraft(subject: subject)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    Button {
                        app.perform("Materia eliminata") {
                            try app.store.deleteSubject(adminId: user.id, subjectId: subject.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Materie")
        .toolbar {
            ToolbarItem {
                Button {
                    editing = SubjectDraft(subject: nil)
                } label: {
                    Label("Nuova materia", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { draft in
            SubjectSheet(draft: draft, adminId: user.id)
                .environmentObject(app)
        }
    }

    private func rateText(_ subject: Subject) -> String {
        if let rate = subject.hourlyRateCents {
            return "\(Format.euros(rate)) / ora"
        }
        return "Tariffa globale (\(Format.euros(app.store.settings.hourlyRateCents)) / ora)"
    }
}

struct SubjectDraft: Identifiable {
    let id = UUID()
    let subject: Subject?
}

private struct SubjectSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let draft: SubjectDraft
    let adminId: Int

    @State private var name = ""
    @State private var customRate = false
    @State private var rate = ""
    @State private var error: String?

    var body: some View {
        SheetForm(
            title: draft.subject == nil ? "Nuova materia" : "Modifica materia",
            confirmTitle: "Salva",
            confirmDisabled: name.isEmpty,
            onConfirm: save
        ) {
            Section {
                TextField("Nome", text: $name)
                Toggle("Tariffa specifica", isOn: $customRate)
                if customRate {
                    TextField("Tariffa oraria (€)", text: $rate)
                        .keyboardType(.decimalPad)
                }
            }
            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            if let subject = draft.subject {
                name = subject.name
                if let cents = subject.hourlyRateCents {
                    customRate = true
                    rate = String(format: "%.2f", Double(cents) / 100).replacingOccurrences(of: ".", with: ",")
                }
            }
        }
    }

    private func save() {
        var cents: Int?
        if customRate {
            guard let parsed = Format.parseEuros(rate) else {
                error = "Tariffa non valida, scrivila tipo 22,50."
                return
            }
            cents = parsed
        }
        error = app.attempt("Materia salvata") {
            if let subject = draft.subject {
                try app.store.updateSubject(adminId: adminId, subjectId: subject.id, name: name, hourlyRateCents: cents)
            } else {
                _ = try app.store.addSubject(adminId: adminId, name: name, hourlyRateCents: cents)
            }
        }
        if error == nil {
            dismiss()
        }
    }
}

// MARK: - Impostazioni

struct AdminSettingsView: View {
    @EnvironmentObject private var app: AppState
    let user: User
    @State private var rate = ""

    var body: some View {
        Form {
            Section("Tariffe") {
                LabeledContent("Tariffa oraria attuale", value: Format.euros(app.store.settings.hourlyRateCents))
                TextField("Nuova tariffa oraria (€)", text: $rate)
                    .keyboardType(.decimalPad)
                HStack {
                    Spacer()
                    Button("Salva tariffa") { saveRate() }
                        .disabled(rate.isEmpty)
                }
                Text("Vale per tutte le materie senza una tariffa specifica e solo per le prenotazioni nuove.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Dati di prova") {
                Text("Aggiunge tutor@demo.it e studente@demo.it (password \(FeniceStore.demoPassword)) con cinque fasce nei prossimi giorni.")
                    .font(.callout)
                Button("Aggiungi dati di prova") {
                    app.perform("Dati di prova aggiunti") {
                        try app.store.addDemoData(adminId: user.id)
                    }
                }
            }
            Section("Database") {
                LabeledContent("File", value: app.databaseURL.lastPathComponent)
                ShareLink(item: app.databaseURL) {
                    Label("Esporta una copia", systemImage: "square.and.arrow.up")
                }
                Text("Per fare un backup salva la copia in File o mandala via AirDrop.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Impostazioni")
    }

    private func saveRate() {
        guard let cents = Format.parseEuros(rate) else {
            app.errorMessage = "Tariffa non valida, scrivila tipo 20 oppure 22,50."
            return
        }
        app.perform("Tariffa aggiornata") {
            try app.store.updateHourlyRate(adminId: user.id, cents: cents)
        }
        rate = ""
    }
}
