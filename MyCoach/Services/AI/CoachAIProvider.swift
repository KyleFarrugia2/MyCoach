import Foundation

// MARK: - Protocol

protocol CoachAIProvider: Sendable {
    /// Explains or elaborates on an engine `CoachDecision` using only engine numbers.
    func explain(
        decision: CoachDecision,
        context: CoachAIContext,
        userMessage: String?
    ) async throws -> CoachAIStructuredResponse

    /// Free-form chat that must stay anchored to engine decision numbers when present.
    func chat(
        messages: [CoachChatMessage],
        decision: CoachDecision?,
        context: CoachAIContext
    ) async throws -> CoachAIStructuredResponse
}

enum CoachAIError: Error, LocalizedError, Sendable {
    case offlineUnavailable
    case invalidResponse
    case httpStatus(Int)
    case transport(String)

    static let offlineUserMessage =
        "Coach AI is temporarily unavailable. Your plan and tracking are still available."

    var errorDescription: String? {
        switch self {
        case .offlineUnavailable:
            Self.offlineUserMessage
        case .invalidResponse:
            "Coach AI returned an invalid response."
        case .httpStatus(let code):
            "Coach AI request failed (HTTP \(code))."
        case .transport(let detail):
            detail.isEmpty ? Self.offlineUserMessage : detail
        }
    }
}

// MARK: - Local deterministic (offline)

/// Deterministic coach messaging from engine outputs only — never invents calorie/macro/step numbers.
struct LocalDeterministicCoachAI: CoachAIProvider {
    func explain(
        decision: CoachDecision,
        context: CoachAIContext,
        userMessage: String?
    ) async throws -> CoachAIStructuredResponse {
        let response = build(decision: decision, context: context, userPrompt: userMessage)
        return Self.validatePreferringEngine(response, decision: decision, context: context)
    }

    func chat(
        messages: [CoachChatMessage],
        decision: CoachDecision?,
        context: CoachAIContext
    ) async throws -> CoachAIStructuredResponse {
        let lastUser = messages.last(where: { $0.role == .user })?.text
        guard let decision else {
            return CoachAIStructuredResponse(
                summary: "Your current plan is active.",
                recommendation: "Continue logging weight, food, and weekly check-ins so the engine can review progress.",
                reasoning: [
                    "Training target: \(context.trainingCalories) kcal.",
                    "Rest target: \(context.restCalories) kcal.",
                    "Protein: \(Int(context.protein.rounded())) g · Carbs: \(Int(context.carbs.rounded())) g · Fat: \(Int(context.fat.rounded())) g.",
                    "Step target: \(context.stepTarget)."
                ],
                userMessage: lastUser.map { "Regarding “\($0)”: stick to your engine targets while we gather more data." }
                    ?? "Stick to your engine targets while we gather more data."
            )
        }
        let response = build(decision: decision, context: context, userPrompt: lastUser)
        return Self.validatePreferringEngine(response, decision: decision, context: context)
    }

    private func build(
        decision: CoachDecision,
        context: CoachAIContext,
        userPrompt: String?
    ) -> CoachAIStructuredResponse {
        let actionLine = describeAction(decision.action, decision: decision, context: context)
        let reasonLines = decision.reasons.map(describeReason(_:))
        let numberLines = numberAnchors(decision: decision, context: context)

        let summary = decision.summary.isEmpty ? actionLine : decision.summary
        var reasoning = reasonLines
        reasoning.append(contentsOf: numberLines)
        if !decision.secondaryActions.isEmpty {
            let secondary = decision.secondaryActions.map { describeAction($0, decision: decision, context: context) }
            reasoning.append(contentsOf: secondary.map { "Also: \($0)" })
        }

        let recommendation = actionLine
        let userMessage: String
        if let userPrompt, !userPrompt.isEmpty {
            userMessage = "You asked: “\(userPrompt)”. \(summary) \(actionLine)"
        } else {
            userMessage = "\(summary) \(actionLine)"
        }

        return CoachAIStructuredResponse(
            summary: summary,
            recommendation: recommendation,
            reasoning: reasoning,
            userMessage: userMessage
        )
    }

    private func numberAnchors(decision: CoachDecision, context: CoachAIContext) -> [String] {
        var lines: [String] = []
        let training = decision.suggestedTrainingCalories ?? context.trainingCalories
        let rest = decision.suggestedRestCalories ?? context.restCalories
        lines.append("Training calories (engine): \(training) kcal.")
        lines.append("Rest calories (engine): \(rest) kcal.")
        let macros = decision.suggestedMacros ?? MacroGrams(
            protein: context.protein,
            carbohydrates: context.carbs,
            fat: context.fat
        )
        lines.append(
            "Macros (engine): \(Int(macros.protein.rounded())) g protein, \(Int(macros.carbohydrates.rounded())) g carbs, \(Int(macros.fat.rounded())) g fat."
        )
        let steps = decision.suggestedSteps ?? context.stepTarget
        lines.append("Step target (engine): \(steps).")
        if let rate = context.weeklyRateKg {
            lines.append(String(format: "Weekly average change (logged): %.2f kg.", rate))
        }
        if let refeed = decision.refeed {
            lines.append(
                "Refeed day calories (engine): \(refeed.refeedTarget.calories) kcal vs normal \(refeed.normalTarget.calories) kcal."
            )
        }
        return lines
    }

    private func describeAction(
        _ action: CoachAdjustment,
        decision: CoachDecision,
        context: CoachAIContext
    ) -> String {
        switch action {
        case .maintain:
            return "Maintain current targets (\(context.trainingCalories) / \(context.restCalories) kcal training/rest)."
        case .increaseCalories(let amount):
            let training = decision.suggestedTrainingCalories ?? (context.trainingCalories + amount)
            return "Increase calories by \(amount) kcal (suggested training day: \(training) kcal)."
        case .decreaseCalories(let amount):
            let training = decision.suggestedTrainingCalories ?? (context.trainingCalories - amount)
            return "Decrease calories by \(amount) kcal (suggested training day: \(training) kcal)."
        case .increaseSteps(let amount):
            let steps = decision.suggestedSteps ?? min(CoachingConfig.maxStepTarget, context.stepTarget + amount)
            return "Increase steps by \(amount) (suggested target: \(steps))."
        case .decreaseSteps(let amount):
            let steps = decision.suggestedSteps ?? max(0, context.stepTarget - amount)
            return "Decrease steps by \(amount) (suggested target: \(steps))."
        case .suggestRefeed:
            if let refeed = decision.refeed {
                return "Consider a refeed at \(refeed.refeedTarget.calories) kcal (\(refeed.reason))."
            }
            return "Consider a controlled refeed day using the engine refeed targets."
        case .requireMoreData:
            return "Keep logging morning weigh-ins; the engine needs more data before adjusting."
        case .reviewAdherence:
            return "Focus on adherence to the current plan before changing calories."
        case .reviewRecovery:
            return "Review recovery, sleep, and training stress before further calorie cuts."
        case .recommendNutritionIncreaseReview:
            return "Review a measured nutrition increase using the engine’s suggested calories."
        case .recommendNutritionDecreaseReview:
            return "Review a measured nutrition decrease using the engine’s suggested calories."
        }
    }

    private func describeReason(_ code: CoachReasonCode) -> String {
        switch code {
        case .rateOnTarget: return "Weekly rate of change is on target."
        case .rateTooFastLoss: return "Weekly loss is faster than the preferred range."
        case .rateTooFastGain: return "Weekly gain is faster than the preferred range."
        case .rateTooSlow: return "Weekly change is slower than expected for the goal."
        case .highAdherence: return "Adherence has been high."
        case .poorAdherence: return "Adherence has been inconsistent."
        case .insufficientWeighIns: return "Not enough morning weigh-ins this week."
        case .performanceStable: return "Training performance is stable."
        case .performanceDeclining: return "Training performance is declining."
        case .appearanceFlat: return "Appearance feedback suggests a flatter look."
        case .appearanceSoft: return "Appearance feedback suggests a softer look."
        case .appearanceImproving: return "Appearance feedback suggests improvement."
        case .extremeWeeklyChange: return "Weekly average change was extreme."
        case .stepCapReached: return "Step target is already at the configured cap."
        case .userFeelingHungry: return "Hunger feedback is elevated."
        case .recoveryConcern: return "Recovery indicators warrant caution."
        }
    }

    /// If messaging somehow drifts, re-anchor calorie/macro/step figures to the engine decision.
    static func validatePreferringEngine(
        _ response: CoachAIStructuredResponse,
        decision: CoachDecision,
        context: CoachAIContext
    ) -> CoachAIStructuredResponse {
        var reasoning = response.reasoning
        let training = decision.suggestedTrainingCalories ?? context.trainingCalories
        let rest = decision.suggestedRestCalories ?? context.restCalories
        let steps = decision.suggestedSteps ?? context.stepTarget
        let macros = decision.suggestedMacros ?? MacroGrams(
            protein: context.protein,
            carbohydrates: context.carbs,
            fat: context.fat
        )

        // Ensure engine numbers appear explicitly; they take precedence over any free-form AI wording.
        let anchor = "Engine numbers: training \(training) kcal, rest \(rest) kcal, steps \(steps), P/C/F \(Int(macros.protein.rounded()))/\(Int(macros.carbohydrates.rounded()))/\(Int(macros.fat.rounded())) g."
        if !reasoning.contains(where: { $0.contains("\(training)") && $0.lowercased().contains("kcal") }) {
            reasoning.append(anchor)
        } else if !reasoning.contains(anchor) {
            reasoning.append(anchor)
        }

        let recommendation: String
        if response.recommendation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recommendation = decision.summary
        } else {
            recommendation = response.recommendation
        }

        let summary = response.summary.isEmpty ? decision.summary : response.summary
        let userMessage = response.userMessage.isEmpty ? summary : response.userMessage

        return CoachAIStructuredResponse(
            summary: summary,
            recommendation: recommendation,
            reasoning: reasoning,
            userMessage: userMessage
        )
    }
}

// MARK: - Remote HTTPS stub

/// Calls a configurable HTTPS base URL. **Never embeds API keys** — supply them via Keychain or the host environment.
struct RemoteCoachAIClient: CoachAIProvider {
    var baseURL: URL
    /// Optional bearer token loaded from Keychain (or nil). Not hardcoded.
    var authorizationTokenProvider: @Sendable () async -> String?
    var session: URLSession
    var fallback: LocalDeterministicCoachAI

    init(
        baseURL: URL,
        authorizationTokenProvider: @escaping @Sendable () async -> String? = { nil },
        session: URLSession = .shared,
        fallback: LocalDeterministicCoachAI = LocalDeterministicCoachAI()
    ) {
        self.baseURL = baseURL
        self.authorizationTokenProvider = authorizationTokenProvider
        self.session = session
        self.fallback = fallback
    }

    func explain(
        decision: CoachDecision,
        context: CoachAIContext,
        userMessage: String?
    ) async throws -> CoachAIStructuredResponse {
        let body = ExplainRequest(
            decision: decision,
            context: context,
            userMessage: userMessage
        )
        do {
            let remote = try await post(path: "/v1/coach/explain", body: body)
            return LocalDeterministicCoachAI.validatePreferringEngine(
                remote,
                decision: decision,
                context: context
            )
        } catch {
            throw mapTransportError(error)
        }
    }

    func chat(
        messages: [CoachChatMessage],
        decision: CoachDecision?,
        context: CoachAIContext
    ) async throws -> CoachAIStructuredResponse {
        let body = ChatRequest(messages: messages, decision: decision, context: context)
        do {
            let remote = try await post(path: "/v1/coach/chat", body: body)
            if let decision {
                return LocalDeterministicCoachAI.validatePreferringEngine(
                    remote,
                    decision: decision,
                    context: context
                )
            }
            return remote
        } catch {
            throw mapTransportError(error)
        }
    }

    // MARK: - Networking

    private struct ExplainRequest: Encodable {
        var decision: CoachDecision
        var context: CoachAIContext
        var userMessage: String?
    }

    private struct ChatRequest: Encodable {
        var messages: [CoachChatMessage]
        var decision: CoachDecision?
        var context: CoachAIContext
    }

    private func post<Body: Encodable>(path: String, body: Body) async throws -> CoachAIStructuredResponse {
        let trimmed = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL else {
            throw CoachAIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        if let token = await authorizationTokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CoachAIError.offlineUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw CoachAIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CoachAIError.httpStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let decoded = try decoder.decode(CoachAIStructuredResponse.self, from: data)
            guard Self.isStructurallyValid(decoded) else {
                throw CoachAIError.invalidResponse
            }
            return decoded
        } catch {
            throw CoachAIError.invalidResponse
        }
    }

    private static func isStructurallyValid(_ response: CoachAIStructuredResponse) -> Bool {
        !response.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !response.recommendation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !response.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func mapTransportError(_ error: Error) -> CoachAIError {
        if let ai = error as? CoachAIError { return ai }
        if error is URLError { return .offlineUnavailable }
        return .transport(CoachAIError.offlineUserMessage)
    }
}
