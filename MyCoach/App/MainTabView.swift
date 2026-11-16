import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var env = env
        ZStack {
            TodayView()
                .mcScreenEntrance()
                .buttonSound(.today)
                .tabPane(visible: env.selectedTab == .today)

            MealPlanView()
                .mcScreenEntrance()
                .buttonSound(.mealPlan)
                .tabPane(visible: env.selectedTab == .mealPlan)

            FoodLogView()
                .mcScreenEntrance()
                .buttonSound(.log)
                .tabPane(visible: env.selectedTab == .log)

            FoodsView()
                .mcScreenEntrance()
                .buttonSound(.foods)
                .tabPane(visible: env.selectedTab == .foods)

            WorkoutHomeView()
                .mcScreenEntrance()
                .buttonSound(.workout)
                .tabPane(visible: env.selectedTab == .workout)

            ProgressViewScreen()
                .mcScreenEntrance()
                .buttonSound(.progress)
                .tabPane(visible: env.selectedTab == .progress)

            CoachHomeView()
                .mcScreenEntrance()
                .buttonSound(.coach)
                .tabPane(visible: env.selectedTab == .coach)
        }
        .tint(MCTheme.ColorToken.primary)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CoachTabDock(selection: $env.selectedTab)
        }
        .onChange(of: env.selectedTab) { _, _ in ButtonSounds.play(.nav) }
    }
}

/// Floating dock that keeps every destination on-screen. System `TabView` overflows into More after five tabs.
private struct CoachTabDock: View {
    @Binding var selection: MainTab
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var dockNS

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases) { tab in
                dockButton(tab)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? MCTheme.ColorToken.darkElevated.opacity(0.72)
                                : Color.white.opacity(0.78)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.16 : 0.95),
                                    MCTheme.ColorToken.primary.opacity(0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: MCTheme.ColorToken.navy.opacity(colorScheme == .dark ? 0.5 : 0.16), radius: 20, y: 10)
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("MainTabBar")
        .animation(MCTheme.Motion.spring, value: selection)
    }

    private func dockButton(_ tab: MainTab) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 20)
                Text(tab.shortTitle)
                    .font(.system(size: 9, weight: selected ? .heavy : .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? Color.white : MCTheme.Surface.secondaryText(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    MCTheme.ColorToken.primary,
                                    MCTheme.ColorToken.primary.opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .matchedGeometryEffect(id: "dock-pill", in: dockNS)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("Tab.\(tab.rawValue)")
    }
}

private extension View {
    func tabPane(visible: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
            .zIndex(visible ? 1 : 0)
    }
}

#Preview {
    MainTabView()
        .environment(AppEnvironment())
}
