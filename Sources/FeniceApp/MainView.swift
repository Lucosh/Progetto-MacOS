import FeniceCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Group {
            if let user = app.currentUser {
                MainView(user: user)
                    .id(user.id)
            } else {
                AuthView()
            }
        }
        .alert("Attenzione", isPresented: errorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(text: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.toast)
    }

    private var errorShown: Binding<Bool> {
        Binding(
            get: { app.errorMessage != nil },
            set: { if !$0 { app.errorMessage = nil } }
        )
    }
}

enum Pane: Hashable {
    case studentHome, book, balance
    case agenda, availability, tutorCancellations, tutorStudents, tutorSubjects
    case adminHome, users, subjects, adminCancellations, adminSettings
    case notifications, profile
}

struct MainView: View {
    @EnvironmentObject private var app: AppState
    let user: User
    @State private var pane: Pane?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                switch user.role {
                case .student: studentSections
                case .tutor: tutorSections
                case .admin: adminSections
                }
                Section("Account") {
                    NavigationLink(value: Pane.notifications) {
                        Label("Notifiche", systemImage: "bell")
                    }
                    .badge(app.store.unreadCount(forUser: user.id))
                    NavigationLink(value: Pane.profile) {
                        Label("Profilo", systemImage: "person.crop.circle")
                    }
                }
            }
            .navigationTitle("Fenice")
            .navigationSplitViewColumnWidth(min: 250, ideal: 280)
            .safeAreaInset(edge: .bottom) {
                userFooter
                    .background(.bar)
            }
        } detail: {
            NavigationStack {
                detail(for: pane ?? home)
            }
            .id(pane)
        }
        .onAppear {
            // su iPhone si parte dal menu, su iPad (due colonne) dalla pagina principale
            if pane == nil && sizeClass == .regular { pane = home }
        }
    }

    private var home: Pane {
        switch user.role {
        case .student: return .studentHome
        case .tutor: return .agenda
        case .admin: return .adminHome
        }
    }

    @ViewBuilder
    private var studentSections: some View {
        Section("Lezioni") {
            NavigationLink(value: Pane.studentHome) { Label("Le mie lezioni", systemImage: "book.closed") }
            NavigationLink(value: Pane.book) { Label("Prenota", systemImage: "calendar.badge.plus") }
            NavigationLink(value: Pane.balance) { Label("Saldo", systemImage: "eurosign.circle") }
        }
    }

    @ViewBuilder
    private var tutorSections: some View {
        Section("Lezioni") {
            NavigationLink(value: Pane.agenda) { Label("Agenda", systemImage: "calendar") }
            NavigationLink(value: Pane.availability) { Label("Disponibilità", systemImage: "clock") }
            NavigationLink(value: Pane.tutorCancellations) {
                Label("Annullamenti", systemImage: "xmark.circle")
            }
            .badge(app.store.openCancellations(forTutor: user.id).count)
        }
        Section("Studenti") {
            NavigationLink(value: Pane.tutorStudents) { Label("I miei studenti", systemImage: "person.2") }
            NavigationLink(value: Pane.tutorSubjects) { Label("Materie", systemImage: "books.vertical") }
        }
    }

    @ViewBuilder
    private var adminSections: some View {
        Section("Gestione") {
            NavigationLink(value: Pane.adminHome) { Label("Panoramica", systemImage: "square.grid.2x2") }
            NavigationLink(value: Pane.users) { Label("Utenti", systemImage: "person.3") }
            NavigationLink(value: Pane.adminCancellations) {
                Label("Annullamenti", systemImage: "xmark.circle")
            }
            .badge(app.store.openCancellations().count)
            NavigationLink(value: Pane.subjects) { Label("Materie", systemImage: "books.vertical") }
            NavigationLink(value: Pane.adminSettings) { Label("Impostazioni", systemImage: "gearshape") }
        }
    }

    private var userFooter: some View {
        HStack(spacing: 10) {
            AvatarView(user: user, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(user.fullName).font(.callout.weight(.medium)).lineLimit(1)
                Text(user.role.label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                app.logout()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.borderless)
            .help("Esci")
        }
        .padding(12)
    }

    @ViewBuilder
    private func detail(for pane: Pane) -> some View {
        switch pane {
        case .studentHome: StudentDashboardView(user: user)
        case .book: BookingWizardView(user: user)
        case .balance: BalanceView(user: user)
        case .agenda: PlaceholderView(title: "Agenda")
        case .availability: PlaceholderView(title: "Disponibilità")
        case .tutorCancellations: PlaceholderView(title: "Annullamenti")
        case .tutorStudents: PlaceholderView(title: "I miei studenti")
        case .tutorSubjects: PlaceholderView(title: "Materie")
        case .adminHome: PlaceholderView(title: "Panoramica")
        case .users: PlaceholderView(title: "Utenti")
        case .subjects: PlaceholderView(title: "Materie")
        case .adminCancellations: PlaceholderView(title: "Annullamenti")
        case .adminSettings: PlaceholderView(title: "Impostazioni")
        case .notifications: PlaceholderView(title: "Notifiche")
        case .profile: PlaceholderView(title: "Profilo")
        }
    }
}
