import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var env = env
        TabView(selection: $env.selectedTab) {
            TodayView()
                .mcScreenEntrance()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(MainTab.today)

            MealPlanView()
                .mcScreenEntrance()
                .tabItem { Label("Meal Plan", systemImage: "fork.knife") }
                .tag(MainTab.mealPlan)

            FoodLogView()
                .mcScreenEntrance()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
                .tag(MainTab.log)

            FoodsView()
                .mcScreenEntrance()
                .tabItem { Label("Foods", systemImage: "basket.fill") }
                .tag(MainTab.foods)

            WorkoutHomeView()
                .mcScreenEntrance()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
                .tag(MainTab.workout)

            ProgressViewScreen()
                .mcScreenEntrance()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(MainTab.progress)

            CoachHomeView()
                .mcScreenEntrance()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(MainTab.coach)
        }
        .tint(MCTheme.ColorToken.primary)
        .toolbarBackground(MCTheme.Surface.elevated(colorScheme), for: .tabBar)
    }
}

#Preview {
    MainTabView()
        .environment(AppEnvironment())
}
