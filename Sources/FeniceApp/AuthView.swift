import FeniceCore
import SwiftUI

struct AuthView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case login = "Accedi"
        case register = "Registrati"

        var id: String { rawValue }
    }

    @State private var mode = Mode.login

    var body: some View {
        Form {
            Section {
                BrandHeader()
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            switch mode {
            case .login: LoginFields()
            case .register: RegisterFields()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        // su iPad il modulo non si allarga a tutto lo schermo
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct BrandHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.fenice)
            Text("Fenice")
                .font(.system(size: 34, weight: .bold, design: .serif))
            Text("Ripetizioni, fasce orarie e saldi in un'unica app.")
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(colors: [.night, .feniceDeep], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

private struct LoginFields: View {
    @EnvironmentObject private var app: AppState
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Section {
            TextField("Email", text: $email)
                .emailField()
            SecureField("Password", text: $password)
                .textContentType(.password)
                .onSubmit(login)
        }
        Section {
            Button("Accedi", action: login)
                .frame(maxWidth: .infinity)
                .disabled(email.isEmpty || password.isEmpty)
        }
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else { return }
        app.login(email: email, password: password)
    }
}

private struct RegisterFields: View {
    @EnvironmentObject private var app: AppState
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""

    var body: some View {
        Section {
            TextField("Nome", text: $firstName)
                .textContentType(.givenName)
            TextField("Cognome", text: $lastName)
                .textContentType(.familyName)
            TextField("Email", text: $email)
                .emailField()
        }
        Section {
            SecureField("Password (almeno 8 caratteri)", text: $password)
                .textContentType(.newPassword)
            SecureField("Ripeti la password", text: $confirm)
                .textContentType(.newPassword)
            if !confirm.isEmpty && confirm != password {
                Text("Le password non coincidono.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        } footer: {
            Text("La registrazione è per gli studenti. Gli account dei tutor li crea l'amministrazione.")
        }
        Section {
            Button("Crea account") {
                app.register(firstName: firstName, lastName: lastName, email: email, password: password)
            }
            .frame(maxWidth: .infinity)
            .disabled(firstName.isEmpty || email.isEmpty || password.isEmpty || password != confirm)
        }
    }
}
