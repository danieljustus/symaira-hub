import SwiftUI

@main
struct SymairaHubApp: App {
    @State private var state = HubState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .task {
                    await state.refresh()
                }
        }
        .windowStyle(.automatic)

        Settings {
            SettingsView()
                .environment(state)
        }
    }
}
