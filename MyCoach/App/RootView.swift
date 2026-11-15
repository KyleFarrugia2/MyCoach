import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if env.profile.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
                    .buttonSound(.onboarding)
            }
        }
        .animation(MCTheme.Motion.standard, value: env.profile.hasCompletedOnboarding)
        // Calm music only while the app is in the foreground (and not during workouts).
        .onChange(of: scenePhase) { _, phase in
            env.music.sync(
                enabled: env.preferences.calmingMusic,
                workoutActive: env.activeWorkout != nil,
                appActive: phase == .active
            )
        }
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
