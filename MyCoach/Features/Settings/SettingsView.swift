import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showDeleteDataConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showExportShare = false
    @State private var exportURL: URL?
    @State private var showPaywall = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var mealName1 = ""
    @State private var mealName2 = ""
    @State private var mealName3 = ""
    @State private var mealName4 = ""
    @State private var mealName5 = ""
    @State private var mealNamePre = ""
    @State private var mealNamePost = ""

    var body: some View {
        @Bindable var env = env
        List {
            profileSection
            coachingSection
            nutritionSection
            appearanceSection
            notificationsSection
            subscriptionSection
            privacySection
            accountSection
            aboutSection
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            mealName1 = env.preferences.mealName(for: .breakfast)
            mealName2 = env.preferences.mealName(for: .snack)
            mealName3 = env.preferences.mealName(for: .lunch)
            mealName4 = env.preferences.mealName(for: .afternoonSnack)
            mealName5 = env.preferences.mealName(for: .dinner)
            mealNamePre = env.preferences.mealName(for: .preWorkout)
            mealNamePost = env.preferences.mealName(for: .postWorkout)
        }
        .confirmationDialog(
            "Delete coaching data?",
            isPresented: $showDeleteDataConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Weight, Meals, Photos & Check-Ins", role: .destructive) {
                env.deleteCoachingData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes weigh-ins, meal plans, diaries, photos and check-ins from this device. Custom foods are kept.")
        }
        .confirmationDialog(
            "Delete your My Coach account?",
            isPresented: $showDeleteAccountConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account & All Local Data", role: .destructive) {
                env.deleteAccountLocally()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your local My Coach profile, coaching history, foods and preferences on this device. This cannot be undone.")
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showTerms) {
            LegalDocView(title: "Terms of Use", urlPlaceholder: AppIdentity.termsURLPlaceholder)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocView(title: "Privacy Policy", urlPlaceholder: AppIdentity.privacyPolicyURLPlaceholder)
        }
        .sheet(isPresented: $showExportShare, onDismiss: { exportURL = nil }) {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Text("Share Export")
                }
                .padding()
            }
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            LabeledContent("Name", value: env.profile.displayName)
            if let age = env.profile.ageYears {
                LabeledContent("Age", value: "\(age)")
            }
            LabeledContent("Height", value: String(format: "%.0f cm", env.profile.heightCm))
            Picker("Weight unit", selection: Binding(
                get: { env.profile.weightUnit },
                set: { unit in env.updateProfile { $0.weightUnit = unit } }
            )) {
                Text("kg").tag(WeightUnit.kilogram)
                Text("lb").tag(WeightUnit.pound)
            }
            Picker("Goal", selection: Binding(
                get: { env.profile.goalPhase },
                set: { goal in
                    env.updateProfile { $0.goalPhase = goal }
                    env.rebuildTargetsFromProfile()
                }
            )) {
                Text(GoalPhase.cut.displayName).tag(GoalPhase.cut)
                Text(GoalPhase.gain.displayName).tag(GoalPhase.gain)
            }
        }
    }

    private var coachingSection: some View {
        Section("Coaching") {
            LabeledContent("Phase", value: env.profile.goalPhase.displayName)
            LabeledContent("Training days", value: "\(env.profile.trainingSchedule.trainingDaysPerWeek) / week")
            Stepper(
                "Step target: \(env.profile.stepTarget)",
                value: Binding(
                    get: { env.profile.stepTarget },
                    set: { value in
                        env.updateProfile { $0.stepTarget = min(value, CoachingConfig.maxStepTarget) }
                        env.rebuildTargetsFromProfile()
                    }
                ),
                in: 1_000...CoachingConfig.maxStepTarget,
                step: CoachingConfig.defaultStepIncrement
            )
            LabeledContent("Meals per day", value: "\(CoachingConfig.requiredMealCount)")
            LabeledContent("Preferred foods", value: "\(env.profile.preferredFoods.count)")
            LabeledContent("Avoided foods", value: "\(env.profile.dislikedFoods.count)")
            Toggle("Intra-workout nutrition", isOn: Binding(
                get: { env.profile.intraWorkoutEnabled },
                set: { env.setIntraWorkoutEnabled($0) }
            ))
        }
    }

    private var nutritionSection: some View {
        Section("Nutrition") {
            TextField("Meal 1 name", text: $mealName1)
                .onSubmit { saveMealNames() }
            TextField("Meal 2 name", text: $mealName2)
                .onSubmit { saveMealNames() }
            TextField("Meal 3 name (rest days)", text: $mealName3)
                .onSubmit { saveMealNames() }
            TextField("Meal 4 name (rest days)", text: $mealName4)
                .onSubmit { saveMealNames() }
            TextField("Meal 5 name", text: $mealName5)
                .onSubmit { saveMealNames() }
            TextField("Pre / Intra Workout name", text: $mealNamePre)
                .onSubmit { saveMealNames() }
            TextField("Post Workout name", text: $mealNamePost)
                .onSubmit { saveMealNames() }
            NavigationLink("Custom foods (\(env.customFoods.count))") {
                CustomFoodsListView()
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: Binding(
                get: { env.profile.appearance },
                set: { value in env.updateProfile { $0.appearance = value } }
            )) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.inline)
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Morning weigh-in", isOn: Binding(
                get: { env.preferences.notifications.morningWeighInEnabled },
                set: { value in
                    env.preferences.notifications.morningWeighInEnabled = value
                    env.save()
                }
            ))
            Toggle("Meal reminders", isOn: Binding(
                get: { env.preferences.notifications.mealRemindersEnabled },
                set: { value in
                    env.preferences.notifications.mealRemindersEnabled = value
                    env.save()
                }
            ))
            Toggle("Step reminders", isOn: Binding(
                get: { env.preferences.notifications.stepRemindersEnabled },
                set: { value in
                    env.preferences.notifications.stepRemindersEnabled = value
                    env.save()
                }
            ))
            Toggle("Weekly check-in", isOn: Binding(
                get: { env.preferences.notifications.weeklyCheckInEnabled },
                set: { value in
                    env.preferences.notifications.weeklyCheckInEnabled = value
                    env.save()
                }
            ))
            Toggle("Progress photos", isOn: Binding(
                get: { env.preferences.notifications.progressPhotosEnabled },
                set: { value in
                    env.preferences.notifications.progressPhotosEnabled = value
                    env.save()
                }
            ))
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            LabeledContent("Current plan", value: subscriptionLabel)
            Button("Manage Subscription / Upgrade") { showPaywall = true }
            Button("Restore Purchases") {
                env.restorePurchasesLocally()
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Button("Privacy Policy") { showPrivacy = true }
            Button("Export My Data") { exportData() }
            Button("Delete Coaching Data", role: .destructive) {
                showDeleteDataConfirm = true
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            Button("Sign Out") {
                // Local-first app: sign-out resets session soft-state without wiping history.
                dismiss()
            }
            Button("Delete Account", role: .destructive) {
                showDeleteAccountConfirm = true
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            Button("Terms of Use") { showTerms = true }
            LabeledContent("Support", value: AppIdentity.supportContactPlaceholder)
        }
    }

    private var subscriptionLabel: String {
        switch env.subscription.status {
        case .trial: return "Trial"
        case .active: return "My Coach AI"
        case .gracePeriod: return "Grace period"
        case .billingRetry: return "Billing retry"
        case .expired: return "Expired"
        case .pending: return "Pending"
        case .notSubscribed: return "Free (Food Log)"
        }
    }

    private func saveMealNames() {
        env.preferences.setMealName(mealName1, for: .breakfast)
        env.preferences.setMealName(mealName2, for: .snack)
        env.preferences.setMealName(mealName3, for: .lunch)
        env.preferences.setMealName(mealName4, for: .afternoonSnack)
        env.preferences.setMealName(mealName5, for: .dinner)
        env.preferences.setMealName(mealNamePre, for: .preWorkout)
        env.preferences.setMealName(mealNamePost, for: .postWorkout)
        env.save()
    }

    private func exportData() {
        guard let data = env.exportDataJSON() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MyCoach-Export.json")
        try? data.write(to: url, options: .atomic)
        exportURL = url
        showExportShare = true
    }
}

private struct CustomFoodsListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showEditor = false

    var body: some View {
        List {
            if env.customFoods.isEmpty {
                Text("No custom foods yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(env.customFoods) { food in
                    MCFoodRow(food: food)
                }
            }
        }
        .navigationTitle("Custom Foods")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Create") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            CustomFoodEditorView { food in
                env.saveCustomFood(food)
            }
        }
    }
}

private struct LegalDocView: View {
    let title: String
    let urlPlaceholder: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                    Text("\(title) placeholder")
                        .font(MCTheme.Typography.title2)
                    Text("Replace before App Store submission. URL: \(urlPlaceholder)")
                        .font(MCTheme.Typography.body)
                    Text("Legal entity: \(AppIdentity.legalEntityPlaceholder)")
                    Text("Contact: \(AppIdentity.supportContactPlaceholder)")
                }
                .padding()
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppEnvironment())
    }
}
