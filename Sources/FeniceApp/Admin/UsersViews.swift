import FeniceCore
import SwiftUI

struct UsersView: View {
    @EnvironmentObject private var app: AppState
    @State private var search = ""
    @State private var roleFilter: Role?
    @State private var showInactive = false
    @State private var creating = false

    var body: some View {
        List {
            if filtered.isEmpty {
                Text("Nessun utente trovato.")
                    .foregroundStyle(.secondary)
            }
            ForEach(filtered) { user in
                NavigationLink {
                    UserDetailView(userId: user.id)
                } label: {
                    UserRow(user: user)
                }
            }
        }
        .searchable(text: $search, prompt: "Cerca per nome o email")
        .navigationTitle("Utenti")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Ruolo", selection: $roleFilter) {
                        Text("Tutti").tag(Role?.none)
                        ForEach(Role.allCases) { role in
                            Text(role.label).tag(Role?.some(role))
                        }
                    }
                    Toggle("Mostra disattivati", isOn: $showInactive)
                } label: {
                    Label("Filtri", systemImage: roleFilter == nil && !showInactive
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                }
            }
            ToolbarItem {
                Button {
                    creating = true
                } label: {
                    Label("Nuovo utente", systemImage: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $creating) {
            NewUserSheet()
                .environmentObject(app)
        }
    }

    private var filtered: [User] {
        app.store.allUsers.filter { user in
            (showInactive || user.isActive)
                && (roleFilter == nil || user.role == roleFilter)
                && (search.isEmpty
                    || user.fullName.localizedCaseInsensitiveContains(search)
                    || user.email.localizedCaseInsensitiveContains(search))
        }
    }
}

private struct UserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(user: user, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.headline)
                Text(user.email)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !user.isActive {
                StatusBadge(text: "Disattivato", color: .secondary)
            }
            StatusBadge(text: user.role.label, color: .fenice)
            if user.role == .student {
                Text(Format.euros(user.balanceCents))
                    .monospacedDigit()
                    .foregroundStyle(user.balanceCents < 0 ? Color.red : Color.primary)
                    .frame(width: 90, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct NewUserSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var role = Role.tutor
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        SheetForm(
            title: "Nuovo utente",
            confirmTitle: "Crea",
            confirmDisabled: firstName.isEmpty || email.isEmpty || password.isEmpty,
            onConfirm: create
        ) {
            Section {
                Picker("Ruolo", selection: $role) {
                    ForEach(Role.allCases) { role in
                        Text(role.label).tag(role)
                    }
                }
                TextField("Nome", text: $firstName)
                TextField("Cognome", text: $lastName)
                TextField("Email", text: $email)
                    .emailField()
                SecureField("Password iniziale", text: $password)
                    .textContentType(.newPassword)
            }
            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func create() {
        guard let me = app.currentUser else { return }
        error = app.attempt("Utente creato") {
            _ = try app.store.createUser(
                adminId: me.id, role: role, firstName: firstName,
                lastName: lastName, email: email, password: password
            )
        }
        if error == nil {
            dismiss()
        }
    }
}

struct UserDetailView: View {
    @EnvironmentObject private var app: AppState
    let userId: Int

    var body: some View {
        if let target = app.store.user(userId), let me = app.currentUser {
            UserDetailForm(target: target, adminId: me.id)
                .id(target.id)
        } else {
            ContentUnavailableView("Utente non trovato", systemImage: "person.slash")
        }
    }
}

private struct UserDetailForm: View {
    @EnvironmentObject private var app: AppState
    let target: User
    let adminId: Int

    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var phone: String
    @State private var parent1Phone: String
    @State private var parent2Phone: String
    @State private var role: Role
    @State private var operation = BalanceOperation.payment
    @State private var amount = ""
    @State private var newPassword = ""

    init(target: User, adminId: Int) {
        self.target = target
        self.adminId = adminId
        _firstName = State(initialValue: target.firstName)
        _lastName = State(initialValue: target.lastName)
        _email = State(initialValue: target.email)
        _phone = State(initialValue: target.phone)
        _parent1Phone = State(initialValue: target.parent1Phone)
        _parent2Phone = State(initialValue: target.parent2Phone)
        _role = State(initialValue: target.role)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    AvatarView(user: target, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.fullName)
                            .font(.title2.bold())
                        Text("\(target.role.label) · iscritto il \(Format.timestamp(target.createdAt))")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !target.isActive {
                        StatusBadge(text: "Disattivato", color: .secondary)
                    }
                }
            }

            Section("Anagrafica") {
                TextField("Nome", text: $firstName)
                TextField("Cognome", text: $lastName)
                TextField("Email", text: $email)
                    .emailField()
                TextField("Telefono", text: $phone)
                    .keyboardType(.phonePad)
                if role == .student {
                    TextField("Telefono genitore 1", text: $parent1Phone)
                        .keyboardType(.phonePad)
                    TextField("Telefono genitore 2", text: $parent2Phone)
                        .keyboardType(.phonePad)
                }
                Picker("Ruolo", selection: $role) {
                    ForEach(Role.allCases) { role in
                        Text(role.label).tag(role)
                    }
                }
                HStack {
                    Spacer()
                    Button("Salva modifiche") { saveProfile() }
                }
            }

            if target.role == .student {
                balanceSection
            }

            Section("Account") {
                HStack {
                    SecureField("Nuova password", text: $newPassword)
                    Button("Reimposta") { resetPassword() }
                        .disabled(newPassword.isEmpty)
                }
                if target.id != adminId {
                    Button(target.isActive ? "Disattiva account" : "Riattiva account") {
                        let active = !target.isActive
                        app.perform(active ? "Account riattivato" : "Account disattivato") {
                            try app.store.setUserActive(adminId: adminId, userId: target.id, active: active)
                        }
                    }
                }
            }

            lessonsSection
        }
        .formStyle(.grouped)
        .navigationTitle(target.fullName)
    }

    private var balanceSection: some View {
        Section("Saldo") {
            BalanceCard(cents: target.balanceCents)
            Picker("Operazione", selection: $operation) {
                ForEach(BalanceOperation.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            HStack {
                TextField(operation == .setBalance ? "Nuovo saldo (€, negativo = da pagare)" : "Importo (€)", text: $amount)
                    // serve anche il segno meno per i saldi negativi
                    .keyboardType(.numbersAndPunctuation)
                Button("Conferma") { applyBalance() }
                    .disabled(amount.isEmpty)
            }
            ForEach(app.store.transactions(forUser: target.id).prefix(10)) { movement in
                TransactionRow(transaction: movement)
            }
        }
    }

    @ViewBuilder
    private var lessonsSection: some View {
        let lessons: [Booking] = {
            switch target.role {
            case .student: return Array(app.store.bookings(forStudent: target.id).reversed())
            case .tutor: return Array(app.store.bookings(forTutor: target.id).reversed())
            case .admin: return []
            }
        }()
        if target.role != .admin {
            Section("Lezioni") {
                if lessons.isEmpty {
                    Text("Nessuna lezione.")
                        .foregroundStyle(.secondary)
                }
                ForEach(lessons.prefix(20)) { booking in
                    NavigationLink {
                        BookingDetailView(bookingId: booking.id)
                    } label: {
                        BookingRow(booking: booking, perspective: target.role)
                    }
                }
            }
        }
        if target.role == .tutor {
            Section("Materie") {
                let names = target.subjectIds.map { app.store.subjectName($0) }.sorted()
                Text(names.isEmpty ? "Nessuna materia scelta." : names.joined(separator: ", "))
            }
        }
    }

    private func saveProfile() {
        app.perform("Modifiche salvate") {
            try app.store.updateUser(
                adminId: adminId, userId: target.id, firstName: firstName, lastName: lastName,
                email: email, phone: phone, parent1Phone: parent1Phone, parent2Phone: parent2Phone, role: role
            )
        }
    }

    private func applyBalance() {
        guard let cents = Format.parseEuros(amount) else {
            app.errorMessage = "Importo non valido, scrivilo tipo 20 oppure 15,50."
            return
        }
        let error = app.attempt("Saldo aggiornato") {
            try app.store.adjustBalance(adminId: adminId, userId: target.id, operation: operation, amountCents: cents)
        }
        if let error {
            app.errorMessage = error
        } else {
            amount = ""
        }
    }

    private func resetPassword() {
        let error = app.attempt("Password reimpostata") {
            try app.store.resetPassword(adminId: adminId, userId: target.id, newPassword: newPassword)
        }
        if let error {
            app.errorMessage = error
        } else {
            newPassword = ""
        }
    }
}
