import SwiftUI

@main
struct FeniceApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(.fenice)
        }
    }
}
