import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var env = env
        TabView(selection: $env.selectedTab) {
            TodayView()
                .mcScreenEntrance()
                .buttonSound(.today)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(MainTab.today)

            MealPlanView()
                .mcScreenEntrance()
                .buttonSound(.mealPlan)
                .tabItem { Label("Meal Plan", systemImage: "fork.knife") }
                .tag(MainTab.mealPlan)

            FoodLogView()
                .mcScreenEntrance()
                .buttonSound(.log)
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
                .tag(MainTab.log)

            FoodsView()
                .mcScreenEntrance()
                .buttonSound(.foods)
                .tabItem { Label("Foods", systemImage: "basket.fill") }
                .tag(MainTab.foods)

            WorkoutHomeView()
                .mcScreenEntrance()
                .buttonSound(.workout)
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
                .tag(MainTab.workout)

            ProgressViewScreen()
                .mcScreenEntrance()
                .buttonSound(.progress)
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(MainTab.progress)

            CoachHomeView()
                .mcScreenEntrance()
                .buttonSound(.coach)
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(MainTab.coach)
        }
        .tint(MCTheme.ColorToken.primary)
        .toolbarBackground(MCTheme.Surface.elevated(colorScheme), for: .tabBar)
        // The tab bar has its own designated sound.
        .onChange(of: env.selectedTab) { _, _ in ButtonSounds.play(.nav) }
    }
}

#Preview {
    MainTabView()
        .environment(AppEnvironment())
}
