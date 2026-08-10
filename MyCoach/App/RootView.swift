import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if env.profile.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .animation(MCTheme.Motion.standard, value: env.profile.hasCompletedOnboarding)
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
