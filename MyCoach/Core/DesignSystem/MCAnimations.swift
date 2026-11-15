import SwiftUI

/// Shared motion for the app (mirrors the web/Android animations). All of it respects Reduce Motion.

/// Cards rise in one after another when a screen appears.
struct MCAppear: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(min(index, 8)) * 0.045)) {
                        shown = true
                    }
                }
            }
    }
}

/// Whole-screen entrance when switching tabs.
struct MCScreenEntrance: ViewModifier {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.985)
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { shown = true }
            }
    }
}

/// Buttons and tappable cards press down slightly and play the screen's designated sound.
struct MCPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MCPressBody(configuration: configuration)
    }
}

private struct MCPressBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.buttonSound) private var sound

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { ButtonSounds.play(sound) }
            }
    }
}

/// A soft light sweep across the training-day card.
struct MCShimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.22), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.6)
                    .allowsHitTesting(false)
                }
                .clipped()
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.2).delay(1).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            }
        }
    }
}

extension View {
    func mcAppear(_ index: Int) -> some View { modifier(MCAppear(index: index)) }
    func mcScreenEntrance() -> some View { modifier(MCScreenEntrance()) }
    func mcShimmer() -> some View { modifier(MCShimmer()) }
}
