import SwiftUI

struct CoachChatView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !env.hasCoachAccess {
                MCCard {
                    VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                        Text("Coach AI subscription required.")
                            .font(MCTheme.Typography.headline)
                        Text("Your tracking data stays available. Upgrade for live coaching conversations.")
                            .font(MCTheme.Typography.subheadline)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                }
                .padding(MCTheme.Spacing.md)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: MCTheme.Spacing.sm) {
                        ForEach(env.chatMessages) { message in
                            MCCoachMessage(text: message.text, role: message.role, structured: message.structured)
                                .id(message.id)
                        }
                    }
                    .padding(MCTheme.Spacing.md)
                }
                .onChange(of: env.chatMessages.count) { _, _ in
                    if let last = env.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: MCTheme.Spacing.sm) {
                TextField("Ask your coach…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                Button {
                    env.sendCoachMessage(draft)
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? MCTheme.ColorToken.grey400
                                : MCTheme.ColorToken.primary
                        )
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send")
            }
            .padding(MCTheme.Spacing.md)
            .background(MCTheme.Surface.elevated(colorScheme))
        }
        .mcScreenBackground()
        .navigationTitle("Coach Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CoachChatView()
            .environment(AppEnvironment())
    }
}
