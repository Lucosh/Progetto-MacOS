import FeniceCore
import Foundation

@MainActor
final class AppState: ObservableObject {
    let store: FeniceStore
    let databaseURL: URL

    @Published private(set) var currentUser: User?
    @Published var errorMessage: String?
    @Published private(set) var toast: String?
    /// cambia a ogni modifica, così le viste rileggono i dati dallo store
    @Published private(set) var revision = 0

    private var timer: Timer?

    init() {
        databaseURL = JSONFilePersistence.defaultURL()
        do {
            store = try FeniceStore(persistence: JSONFilePersistence(url: databaseURL), hasher: PBKDF2Hasher())
        } catch {
            fatalError("Impossibile aprire il database in \(databaseURL.path): \(error.localizedDescription)")
        }
        try? store.runMaintenance()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    // MARK: - Sessione

    func login(email: String, password: String) {
        perform {
            currentUser = try store.login(email: email, password: password)
        }
    }

    func register(firstName: String, lastName: String, email: String, password: String) {
        perform("Benvenuto! Il tuo account è pronto.") {
            currentUser = try store.registerStudent(firstName: firstName, lastName: lastName, email: email, password: password)
        }
    }

    func logout() {
        currentUser = nil
        revision += 1
    }

    // MARK: - Azioni

    /// Esegue un'azione sullo store; se fallisce mostra l'errore in un alert.
    func perform(_ success: String? = nil, _ action: () throws -> Void) {
        if let message = attempt(success, action) {
            errorMessage = message
        }
    }

    /// Come perform ma restituisce l'errore invece di mostrarlo (comodo nei fogli modali).
    @discardableResult
    func attempt(_ success: String? = nil, _ action: () throws -> Void) -> String? {
        do {
            try action()
        } catch {
            return error.localizedDescription
        }
        refresh()
        if let success {
            showToast(success)
        }
        return nil
    }

    func refresh() {
        if let id = currentUser?.id {
            let fresh = store.user(id)
            currentUser = fresh?.isActive == true ? fresh : nil
        }
        revision += 1
    }

    func showToast(_ text: String) {
        toast = text
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self?.toast == text {
                self?.toast = nil
            }
        }
    }

    private func tick() {
        do {
            try store.runMaintenance()
            refresh()
        } catch {
            // ci riprova al giro dopo
        }
    }
}
