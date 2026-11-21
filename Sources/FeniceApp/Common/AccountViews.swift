import FeniceCore
import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    var body: some View {
        let items = app.store.notifications(forUser: user.id)
        List {
            if items.isEmpty {
                Text("Nessuna notifica.")
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                Button {
                    app.perform {
                        try app.store.markNotificationRead(id: item.id, userId: user.id)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(item.isRead ? Color.clear : Color.fenice)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.headline)
                                .fontWeight(item.isRead ? .regular : .semibold)
                            Text(item.body)
                                .foregroundStyle(.secondary)
                            Text(Format.timestamp(item.createdAt))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Notifiche")
        .toolbar {
            ToolbarItem {
                Button("Segna tutte come lette") {
                    app.perform {
                        try app.store.markAllNotificationsRead(userId: user.id)
                    }
                }
                .disabled(app.store.unreadCount(forUser: user.id) == 0)
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    @State private var firstName: String
    @State private var lastName: String
    @State private var phone: String
    @State private var parent1Phone: String
    @State private var parent2Phone: String
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    init(user: User) {
        self.user = user
        _firstName = State(initialValue: user.firstName)
        _lastName = State(initialValue: user.lastName)
        _phone = State(initialValue: user.phone)
        _parent1Phone = State(initialValue: user.parent1Phone)
        _parent2Phone = State(initialValue: user.parent2Phone)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    AvatarView(user: user, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(user.fullName)
                            .font(.title2.bold())
                        Text("\(user.email) · \(user.role.label)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Dati personali") {
                TextField("Nome", text: $firstName)
                TextField("Cognome", text: $lastName)
                TextField("Telefono", text: $phone)
                    .keyboardType(.phonePad)
                if user.role == .student {
                    TextField("Telefono genitore 1", text: $parent1Phone)
                        .keyboardType(.phonePad)
                    TextField("Telefono genitore 2", text: $parent2Phone)
                        .keyboardType(.phonePad)
                    Text("I numeri dei genitori li vede solo l'amministrazione.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Salva") { saveProfile() }
                }
            }
            Section("Cambia password") {
                SecureField("Password attuale", text: $currentPassword)
                    .textContentType(.password)
                SecureField("Nuova password", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Ripeti la nuova password", text: $confirmPassword)
                    .textContentType(.newPassword)
                HStack {
                    if !confirmPassword.isEmpty && confirmPassword != newPassword {
                        Text("Le password non coincidono.")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Button("Cambia password") { changePassword() }
                        .disabled(currentPassword.isEmpty || newPassword.isEmpty || newPassword != confirmPassword)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Profilo")
    }

    private func saveProfile() {
        app.perform("Profilo aggiornato") {
            try app.store.updateProfile(
                userId: user.id, firstName: firstName, lastName: lastName,
                phone: phone, parent1Phone: parent1Phone, parent2Phone: parent2Phone
            )
        }
    }

    private func changePassword() {
        let error = app.attempt("Password cambiata") {
            try app.store.changePassword(userId: user.id, currentPassword: currentPassword, newPassword: newPassword)
        }
        if let error {
            app.errorMessage = error
        } else {
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
        }
    }
}
