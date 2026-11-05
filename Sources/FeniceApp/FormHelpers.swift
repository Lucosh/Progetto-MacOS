import SwiftUI

/// Foglio modale con Annulla e il pulsante di conferma nella barra in alto.
struct SheetForm<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let confirmTitle: String
    var confirmDisabled = false
    let onConfirm: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            Form {
                content
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle, action: onConfirm)
                        .disabled(confirmDisabled)
                }
            }
        }
    }
}

extension View {
    /// tastiera e correzioni adatte a un campo email
    func emailField() -> some View {
        textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}
