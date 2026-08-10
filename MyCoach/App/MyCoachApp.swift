import SwiftUI

@main
struct MyCoachApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .applyingAppearance(environment.profile.appearance)
        }
    }
}
