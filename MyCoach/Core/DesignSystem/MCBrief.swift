import SwiftUI

/// The app's signature layout pieces for Today, Log and Meal Plan (mirrors `web/src/ui/brief.tsx`):
///   - `MCBrief`      — the navy summary panel with the logo's cut corner and roof chevrons
///   - `MCFuel`       — calories ring + macro meters, drawn on the brief
///   - `MCWeekStrip`  — seven-day navigator shared by all three screens
///   - `MCHex`        — hexagon marker (icon chips, timeline nodes), from the logo's outline
///   - `MCSection`    — eyebrow-labelled group
///   - `MCRailItem`   — one stop on the meal rail

// MARK: - Ink palette

enum MCInk {
    static func one(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.08, green: 0.13, blue: 0.30) : Color(red: 0.06, green: 0.12, blue: 0.28)
    }

    static func two(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.11, green: 0.23, blue: 0.53) : Color(red: 0.09, green: 0.21, blue: 0.49)
    }

    static let sky = Color(red: 0.22, green: 0.78, blue: 1.0)
    static let ring = Color(red: 0.31, green: 0.69, blue: 1.0)
    /// Fat purple, lightened so it reads on navy.
    static let fatOnInk = Color(red: 0.71, green: 0.55, blue: 0.94)
    static let soft = Color.white.opacity(0.7)
    static let line = Color.white.opacity(0.13)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [MCTheme.ColorToken.primary, sky], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Shapes

/// Rounded rectangle with the logo's cut (chamfered) top-right corner.
struct MCCutCornerShape: Shape {
    var radius: CGFloat = 24
    var cut: CGFloat = 30

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        let c = min(cut, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Pointy-top hexagon.
struct MCHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + w * x, y: rect.minY + h * y) }
        var p = Path()
        p.move(to: pt(0.5, 0))
        p.addLine(to: pt(0.933, 0.25))
        p.addLine(to: pt(0.933, 0.75))
        p.addLine(to: pt(0.5, 1))
        p.addLine(to: pt(0.067, 0.75))
        p.addLine(to: pt(0.067, 0.25))
        p.closeSubpath()
        return p
    }
}

/// The logo's roof chevron, repeated — the faint watermark on the brief.
struct MCRoofMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 200
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var p = Path()
        let offsets: [CGFloat] = [0, 58]
        for dy in offsets {
            p.move(to: pt(100, 20 + dy))
            p.addLine(to: pt(190, 92 + dy))
            p.addLine(to: pt(172, 92 + dy))
            p.addLine(to: pt(100, 46 + dy))
            p.addLine(to: pt(28, 92 + dy))
            p.addLine(to: pt(10, 92 + dy))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - Small pieces

/// Small uppercase label.
struct MCEyebrow: View {
    let text: String
    var onInk: Bool

    @Environment(\.colorScheme) private var colorScheme

    init(_ text: String, onInk: Bool = false) {
        self.text = text
        self.onInk = onInk
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(onInk ? Color.white.opacity(0.62) : MCTheme.Surface.secondaryText(colorScheme))
    }
}

/// Hexagon marker — an SF Symbol or a short text.
struct MCHex: View {
    var systemImage: String? = nil
    var text: String? = nil
    var color: Color = MCTheme.ColorToken.primary
    var solid: Bool = false
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            MCHexagon().fill(solid ? color : color.opacity(0.16))
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
            } else if let text {
                Text(text)
                    .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
            }
        }
        .foregroundStyle(solid ? Color.white : color)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Eyebrow-labelled group with an optional trailing note.
struct MCSection<Aside: View, Content: View>: View {
    let label: String
    @ViewBuilder var aside: () -> Aside
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(MCInk.accentGradient)
                    .frame(width: 14, height: 3)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                aside()
            }
            .frame(minHeight: 24)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension MCSection where Aside == EmptyView {
    init(label: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(label: label, aside: { EmptyView() }, content: content)
    }
}

/// The small counter on the right of a section header ("2 of 3 logged").
struct MCSectionCount: View {
    let text: String
    var complete: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(complete ? MCTheme.ColorToken.success : MCTheme.Surface.secondaryText(colorScheme))
    }
}

/// Amber / neutral capsule tag.
struct MCTag: View {
    let text: String
    var color: Color = MCTheme.ColorToken.warning

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundStyle(color)
    }
}

/// White elevated surface with the screen's standard corner radius.
struct MCSurface: ViewModifier {
    var radius: CGFloat = 18
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(MCTheme.Surface.elevated(colorScheme))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 4)
        )
    }
}

extension View {
    func mcSurface(radius: CGFloat = 18) -> some View { modifier(MCSurface(radius: radius)) }
}

// MARK: - Brief

/// Navy summary panel. Its content is laid out in a column on the ink background.
struct MCBrief<Content: View>: View {
    enum Tint {
        case training, rest, neutral
    }

    var tint: Tint = .neutral
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    private var glow: Color {
        switch tint {
        case .training: return MCInk.sky
        case .rest: return MCTheme.ColorToken.carbohydrates
        case .neutral: return .clear
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(EdgeInsets(top: 18, leading: 16, bottom: 16, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color.white)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [MCInk.one(colorScheme), MCInk.two(colorScheme)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(colors: [glow.opacity(0.28), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
                MCRoofMark()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 220, height: 220)
                    .offset(x: 34, y: -18)
            }
        }
        .clipShape(MCCutCornerShape())
        .shadow(color: MCTheme.ColorToken.navy.opacity(colorScheme == .dark ? 0.5 : 0.22), radius: 12, y: 10)
        .animation(.easeInOut(duration: 0.4), value: tint)
    }
}

/// Small capsule tag on the brief ("Personalised", "Done").
struct MCBriefTag: View {
    let text: String
    var systemImage: String? = nil
    var positive: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(text).font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(positive ? MCTheme.ColorToken.success.opacity(0.45) : Color.white.opacity(0.14)))
        .foregroundStyle(Color.white)
    }
}

/// Pill button for use on the brief.
struct MCInkButton: View {
    enum Kind {
        case primary, ghost
    }

    let title: String
    var kind: Kind = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .frame(maxWidth: kind == .primary ? .infinity : nil)
                .foregroundStyle(Color.white)
                .background {
                    if kind == .primary {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [MCTheme.ColorToken.primary, Color(red: 0.18, green: 0.61, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .shadow(color: MCTheme.ColorToken.primary.opacity(0.45), radius: 7, y: 4)
                    } else {
                        Capsule().fill(Color.white.opacity(0.1))
                    }
                }
                .overlay {
                    if kind == .ghost {
                        Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(MCPressStyle())
    }
}

// MARK: - Fuel

/// Calories + macros against a target, drawn on the brief.
///  - `.eaten`: the big number is what's been eaten (Today, Log)
///  - `.plan`:  the big number is the target, with the planned total beside it (Meal Plan)
struct MCFuel: View {
    enum Mode {
        case eaten, plan
    }

    let calories: Double
    let target: Double
    let macros: MacroGrams
    let targetMacros: MacroGrams
    var mode: Mode = .eaten
    /// No divider above — when the fuel block opens the brief.
    var flush: Bool = false

    var body: some View {
        let left = Int((target - calories).rounded())
        let over = left < 0
        let progress = target > 0 ? calories / target : 0

        VStack(alignment: .leading, spacing: 14) {
            if !flush {
                Rectangle().fill(MCInk.line).frame(height: 1)
            }
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: min(max(progress, 0), 1))
                        .stroke(
                            mode == .eaten && over ? MCTheme.ColorToken.warning : MCInk.ring,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.7), value: progress)
                    // Inside the ring: calories still to go (eaten vs target, or plan vs target).
                    VStack(spacing: 1) {
                        Text(abs(left).formatted())
                            .font(.system(size: 19, weight: .heavy, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                        Text(over ? "cals over" : "cals left")
                            .font(.system(size: 9.5, weight: .bold))
                            .opacity(0.65)
                    }
                    .foregroundStyle(mode == .eaten && over ? MCTheme.ColorToken.warning : Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
                }
                .padding(4.5)
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(mode == .eaten ? Int(calories.rounded()).formatted() : Int(target.rounded()).formatted())
                            .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                        Text(mode == .eaten ? "kcal eaten" : "kcal target")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MCInk.soft)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    Text(
                        mode == .eaten
                            ? "of your \(Int(target.rounded()).formatted()) kcal target"
                            : "Plan totals \(Int(calories.rounded()).formatted()) kcal"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(MCInk.soft)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            HStack(alignment: .top, spacing: 12) {
                meter(.protein, macros.protein, targetMacros.protein)
                meter(.carbohydrates, macros.carbohydrates, targetMacros.carbohydrates)
                meter(.fat, macros.fat, targetMacros.fat)
            }
        }
    }

    private func meter(_ kind: MCTheme.MacroKind, _ current: Double, _ target: Double) -> some View {
        let safeTarget = max(target, 1)
        let fraction = min(max(current / safeTarget, 0), 1)
        let diff = Int((target - current).rounded())
        let color = kind == .fat ? MCInk.fatOnInk : kind.color
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(45))
                Text(kind.label.uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.66))
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(current.rounded()))")
                    .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text("/ \(Int(target.rounded())) g")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * fraction)
                        .animation(.easeOut(duration: 0.5), value: fraction)
                }
            }
            .frame(height: 5)
            Text(diff >= 0 ? "\(diff) g left" : "\(-diff) g over")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.label) \(Int(current.rounded())) of \(Int(target.rounded())) grams")
    }
}

// MARK: - Week strip

/// Seven-day navigator. `mark` draws the small indicator under each date.
struct MCWeekStrip: View {
    enum Mark {
        case training, rest, done, partial, blank
    }

    let days: [Date]
    @Binding var selected: Date
    var isDisabled: (Date) -> Bool = { _ in false }
    var mark: (Date) -> Mark = { _ in .blank }
    var onPrevious: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil
    var previousDisabled: Bool = false
    var nextDisabled: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    private var calendar: Calendar { Calendar.current }

    var body: some View {
        HStack(spacing: 2) {
            if let onPrevious {
                arrow("chevron.left", label: "Previous week", disabled: previousDisabled, action: onPrevious)
            }
            HStack(spacing: 3) {
                ForEach(days, id: \.self) { day in
                    cell(day)
                }
            }
            .padding(4)
            .mcSurface()
            if let onNext {
                arrow("chevron.right", label: "Next week", disabled: nextDisabled, action: onNext)
            }
        }
    }

    private func arrow(_ icon: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                .frame(width: 28, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(MCPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.25 : 1)
        .accessibilityLabel(label)
    }

    private func markColor(_ mark: Mark, on: Bool) -> Color {
        switch mark {
        case .blank: return .clear
        case .training, .partial: return on ? .white : MCTheme.ColorToken.primary
        case .rest: return on ? .white : MCTheme.ColorToken.success.opacity(0.75)
        case .done: return on ? .white : MCTheme.ColorToken.success
        }
    }

    private func cell(_ day: Date) -> some View {
        let on = calendar.isDate(day, inSameDayAs: selected)
        let today = calendar.isDateInToday(day)
        let disabled = isDisabled(day)
        let numberColor: Color = on ? .white : (today ? MCTheme.ColorToken.primary : MCTheme.Surface.primaryText(colorScheme))
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selected = calendar.startOfDay(for: day)
            }
        } label: {
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(on ? Color.white : MCTheme.Surface.secondaryText(colorScheme))
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(numberColor)
                Capsule()
                    .fill(markColor(mark(day), on: on))
                    .frame(width: 14, height: 3)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(on ? MCTheme.ColorToken.primary : Color.clear)
                    .shadow(color: on ? MCTheme.ColorToken.primary.opacity(0.4) : .clear, radius: 5, y: 3)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(MCPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
        .accessibilityLabel(
            today
                ? "Today, \(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
                : day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        )
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Meal rail

/// P / C / F with the macro colours, for light surfaces.
struct MCMacroChips: View {
    let macros: MacroGrams

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            chip(.protein, macros.protein)
            chip(.carbohydrates, macros.carbohydrates)
            chip(.fat, macros.fat)
        }
        .font(.system(size: 12, weight: .semibold).monospacedDigit())
        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
        .accessibilityElement(children: .combine)
    }

    private func chip(_ kind: MCTheme.MacroKind, _ grams: Double) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(kind.color)
                .frame(width: 6, height: 6)
                .rotationEffect(.degrees(45))
            Text("\(kind.shortLabel) \(Int(grams.rounded())) g")
        }
    }
}

/// One stop on the meal rail: a numbered hexagon, the connecting line, and the meal beside it.
struct MCRailItem<Content: View>: View {
    let number: Int
    /// Solid node — the meal has food logged.
    var filled: Bool = false
    /// Grey node and line — nothing logged yet.
    var muted: Bool = false
    var isLast: Bool = false
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 2) {
                MCHex(
                    text: "\(number)",
                    color: muted ? MCTheme.Surface.secondaryText(colorScheme) : MCTheme.ColorToken.primary,
                    solid: filled
                )
                .padding(.top, 4)
                if !isLast {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(muted ? MCTheme.Surface.border(colorScheme) : MCTheme.ColorToken.primary.opacity(0.45))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 34)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, isLast ? 0 : 12)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Square icon button used inside rail rows (lock, swap, delete).
struct MCToolButton: View {
    let systemImage: String
    var active: Bool = false
    var plain: Bool = false
    let label: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? MCTheme.ColorToken.primary : MCTheme.Surface.secondaryText(colorScheme))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            plain
                                ? Color.clear
                                : (active ? MCTheme.ColorToken.primary.opacity(0.16) : MCTheme.Surface.secondaryFill(colorScheme))
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(MCPressStyle())
        .accessibilityLabel(label)
    }
}

/// Tinted pill button ("Add food", "Log meal").
struct MCTintButton: View {
    let title: String
    var systemImage: String? = nil
    var fullWidth: Bool = false
    var clear: Bool = false
    var label: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 12, weight: .bold))
                }
                Text(title).font(.system(size: 14, weight: .bold))
            }
            .lineLimit(1)
            .foregroundStyle(MCTheme.ColorToken.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(clear ? Color.clear : MCTheme.ColorToken.primary.opacity(0.1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(MCPressStyle())
        .accessibilityLabel(label ?? title)
    }
}
