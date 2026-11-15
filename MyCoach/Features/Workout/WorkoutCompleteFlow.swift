import SwiftUI

/// Everything the celebration needs, captured when the workout is saved.
struct WorkoutCompletion: Equatable {
    var session: WorkoutSession
    var previous: WorkoutSession?
    var streakBefore: Int
    var streakAfter: Int
    /// Exercises with no progress for several sessions in a row (the coach's stagnation check).
    var stagnant: [String]
}

/// Full-screen celebration after a workout saves: Complete → Progress review → Streak.
/// Mirrors `web/src/screens/WorkoutComplete.tsx`.
struct WorkoutCompleteFlow: View {
    let completion: WorkoutCompletion
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    private var tint: Color {
        switch step {
        case 0: return MCTheme.ColorToken.primary
        case 1: return MCTheme.ColorToken.success
        default: return MCTheme.ColorToken.warning
        }
    }

    var body: some View {
        ZStack {
            MCTheme.Surface.background(colorScheme).ignoresSafeArea()
            RadialGradient(colors: [tint.opacity(0.25), .clear], center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: step)

            VStack(spacing: MCTheme.Spacing.sm) {
                stepDots
                ZStack {
                    switch step {
                    case 0: CompleteStep(completion: completion).transition(stepTransition)
                    case 1: ReviewStep(completion: completion).transition(stepTransition)
                    default: StreakStep(completion: completion).transition(stepTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                MCPrimaryButton(title: step == 2 ? "Done" : "Continue") { next() }
                    .buttonSound(.workout)
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                    .padding(.bottom, MCTheme.Spacing.md)
            }
        }
        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.96)),
                removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.96))
            )
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == step ? MCTheme.ColorToken.primary : i < step ? MCTheme.ColorToken.success : MCTheme.Surface.border(colorScheme))
                    .frame(width: i == step ? 22 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
        .padding(.top, MCTheme.Spacing.sm)
        .accessibilityHidden(true)
    }

    private func next() {
        guard step < 2 else { return onDone() }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.82)) {
            step += 1
        }
    }
}

// MARK: - Screen 1: Workout Complete!

private struct CompleteStep: View {
    let completion: WorkoutCompletion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badgeIn = false
    @State private var checkDrawn = false
    @State private var textIn = false
    @State private var countedVolume = 0.0
    @State private var countedSets = 0

    private var stats: WorkoutReview.Stats { WorkoutReview.stats(completion.session) }

    var body: some View {
        ScrollView {
            VStack(spacing: MCTheme.Spacing.sm) {
                Spacer(minLength: MCTheme.Spacing.xl)
                ZStack {
                    ConfettiBurst(count: 48)
                    Circle()
                        .fill(MCTheme.ColorToken.success)
                        .frame(width: 96, height: 96)
                        .shadow(color: MCTheme.ColorToken.success.opacity(0.45), radius: 18, y: 8)
                    CheckShape()
                        .trim(from: 0, to: checkDrawn ? 1 : 0)
                        .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        .frame(width: 46, height: 36)
                }
                .scaleEffect(badgeIn ? 1 : 0.2)
                .rotationEffect(.degrees(badgeIn ? 0 : -25))
                .opacity(badgeIn ? 1 : 0)

                Text("Workout Complete!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .scaleEffect(textIn ? 1 : 0.6)
                    .opacity(textIn ? 1 : 0)
                Text("\(completion.session.templateName) saved.")
                    .font(MCTheme.Typography.body)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .opacity(textIn ? 1 : 0)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    stat("Time", durationLabel, 0)
                    stat("Sets", "\(countedSets)", 1)
                    stat("Volume", "\(Int(countedVolume.rounded()).formatted()) kg", 2)
                    stat("Exercises", "\(stats.exercises)", 3)
                }
                .padding(.top, MCTheme.Spacing.sm)
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear(perform: animateIn)
    }

    private var durationLabel: String {
        let s = stats.durationSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func stat(_ label: String, _ value: String, _ index: Int) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
            Text(label)
                .font(MCTheme.Typography.caption)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                .fill(MCTheme.Surface.elevated(colorScheme))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
        .mcAppear(index + 6)
    }

    private func animateIn() {
        ButtonSounds.play(effect: .celebration)
        guard !reduceMotion else {
            badgeIn = true
            checkDrawn = true
            textIn = true
            countedVolume = stats.volumeKg
            countedSets = stats.sets
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { badgeIn = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.35)) { checkDrawn = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.35)) { textIn = true }
        withAnimation(.easeOut(duration: 1.0).delay(0.7)) {
            countedVolume = stats.volumeKg
            countedSets = stats.sets
        }
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

// MARK: - Screen 2: progress review

private struct ReviewStep: View {
    let completion: WorkoutCompletion
    @Environment(\.colorScheme) private var colorScheme
    @State private var emblemBounce = 0

    private var summary: WorkoutReview.Summary {
        WorkoutReview.review(previous: completion.previous, current: completion.session)
    }

    var body: some View {
        let review = summary
        let progressed = review.progressed > 0
        ScrollView {
            VStack(spacing: MCTheme.Spacing.sm) {
                Image(systemName: progressed ? "figure.strengthtraining.traditional" : "leaf.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(progressed ? MCTheme.ColorToken.success : MCTheme.ColorToken.carbohydrates)
                    .symbolEffect(.bounce, value: emblemBounce)
                    .padding(.top, MCTheme.Spacing.lg)
                    .mcAppear(0)
                Text(review.headline)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .mcAppear(1)
                Text(review.subline)
                    .font(MCTheme.Typography.body)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .multilineTextAlignment(.center)
                    .mcAppear(2)

                VStack(spacing: 8) {
                    ForEach(Array(review.exercises.enumerated()), id: \.element.id) { index, e in
                        row(e).mcAppear(3 + index)
                    }
                }
                .padding(.top, MCTheme.Spacing.xs)

                if let encouragement = review.encouragement {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "quote.opening")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(MCTheme.ColorToken.success)
                        Text(encouragement)
                            .font(MCTheme.Typography.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                            .fill(MCTheme.ColorToken.success.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                            .stroke(MCTheme.ColorToken.success.opacity(0.35))
                    )
                    .mcAppear(4 + review.exercises.count)
                }
                if !completion.stagnant.isEmpty {
                    Text("Your coach noticed \(completion.stagnant.joined(separator: ", ")) \(completion.stagnant.count == 1 ? "has" : "have") held steady for a few sessions — try adding one rep or a small weight jump next time.")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        .multilineTextAlignment(.center)
                        .mcAppear(5 + review.exercises.count)
                }
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            .padding(.bottom, MCTheme.Spacing.md)
        }
        .onAppear {
            ButtonSounds.play(effect: .whoosh)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { emblemBounce += 1 }
        }
    }

    private func row(_ e: WorkoutReview.ExerciseReview) -> some View {
        let color: Color
        let icon: String
        switch e.status {
        case .progressed: color = MCTheme.ColorToken.success; icon = "arrow.up"
        case .same: color = MCTheme.ColorToken.grey600; icon = "equal"
        case .less: color = MCTheme.ColorToken.warning; icon = "arrow.down"
        case .new: color = MCTheme.ColorToken.primary; icon = "star.fill"
        }
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(e.name).font(MCTheme.Typography.headline)
                (Text(e.status.label).bold() + Text(" · \(e.detail)"))
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                .fill(MCTheme.Surface.elevated(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                .stroke(e.status == .progressed ? MCTheme.ColorToken.success.opacity(0.45) : MCTheme.Surface.border(colorScheme))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Screen 3: streak

private struct StreakStep: View {
    let completion: WorkoutCompletion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Int
    @State private var bumped = false
    @State private var flameIn = false
    @State private var flicker = false

    init(completion: WorkoutCompletion) {
        self.completion = completion
        _shown = State(initialValue: completion.streakBefore)
    }

    var body: some View {
        let message = WorkoutReview.streakMessage(completion.streakAfter)
        VStack(spacing: MCTheme.Spacing.xs) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [MCTheme.ColorToken.warning.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 60))
                    .frame(width: 120, height: 120)
                    .scaleEffect(flicker ? 1.12 : 0.95)
                    .opacity(flicker ? 1 : 0.6)
                Image(systemName: "flame.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .bottom, endPoint: .top))
                    .scaleEffect(x: flicker ? 1.05 : 0.97, y: flicker ? 0.97 : 1.05, anchor: .bottom)
                    .symbolEffect(.bounce, value: bumped)
                if bumped {
                    ConfettiBurst(count: 28)
                }
            }
            .scaleEffect(flameIn ? 1 : 0.2)
            .opacity(flameIn ? 1 : 0)

            ZStack(alignment: .topTrailing) {
                Text("\(shown)")
                    .font(.system(size: 72, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(MCTheme.ColorToken.warning)
                    .contentTransition(.numericText(value: Double(shown)))
                    .scaleEffect(bumped && !reduceMotion ? 1.0 : 0.94)
                if bumped, completion.streakAfter > completion.streakBefore {
                    PlusOne(amount: completion.streakAfter - completion.streakBefore)
                        .offset(x: 36, y: -8)
                }
            }
            Text("workout streak")
                .font(MCTheme.Typography.caption)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))

            Group {
                Text(message.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .padding(.top, MCTheme.Spacing.sm)
                Text(message.subtitle)
                    .font(MCTheme.Typography.body)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
            .opacity(bumped ? 1 : 0)
            .scaleEffect(bumped || reduceMotion ? 1 : 0.6)
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout streak \(completion.streakAfter). \(message.title) \(message.subtitle)")
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        if reduceMotion {
            flameIn = true
            shown = completion.streakAfter
            bumped = true
            ButtonSounds.play(effect: .fire)
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { flameIn = true }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { flicker = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            ButtonSounds.play(effect: .fire)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                shown = completion.streakAfter
                bumped = true
            }
        }
    }
}

private struct PlusOne: View {
    let amount: Int
    @State private var up = false

    var body: some View {
        Text("+\(amount)")
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            .foregroundStyle(MCTheme.ColorToken.success)
            .offset(y: up ? -44 : 0)
            .opacity(up ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.4)) { up = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Confetti

/// A one-shot burst of coloured pieces from the centre of its frame.
struct ConfettiBurst: View {
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false
    @State private var pieces: [Piece] = []

    private struct Piece: Identifiable {
        let id: Int
        let dx: CGFloat
        let dy: CGFloat
        let rotation: Double
        let color: Color
        let round: Bool
        let delay: Double
    }

    private static let colors: [Color] = [
        MCTheme.ColorToken.primary, MCTheme.ColorToken.success, MCTheme.ColorToken.protein,
        MCTheme.ColorToken.fat, MCTheme.ColorToken.warning, Color(red: 1, green: 0.42, blue: 0.6),
    ]

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                Group {
                    if p.round {
                        Circle().frame(width: 9, height: 9)
                    } else {
                        RoundedRectangle(cornerRadius: 2).frame(width: 8, height: 14)
                    }
                }
                .foregroundStyle(p.color)
                .rotationEffect(.degrees(fired ? p.rotation : 0))
                .offset(x: fired ? p.dx : 0, y: fired ? p.dy + 120 : 0)
                .opacity(fired ? 0 : 1)
                .animation(.timingCurve(0.1, 0.7, 0.3, 1, duration: 1.4).delay(p.delay), value: fired)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            pieces = (0..<count).map { i in
                let angle = Double(i) / Double(count) * .pi * 2 + Double.random(in: 0...0.4)
                let dist = CGFloat.random(in: 110...260)
                return Piece(
                    id: i,
                    dx: cos(angle) * dist,
                    dy: sin(angle) * dist - 60,
                    rotation: Double.random(in: -360...360),
                    color: Self.colors[i % Self.colors.count],
                    round: i % 3 == 0,
                    delay: Double.random(in: 0...0.12)
                )
            }
            DispatchQueue.main.async { fired = true }
        }
    }
}
