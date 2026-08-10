# Coach AI secure backend proxy

## Why a proxy is required

Never embed private AI API keys (or food-provider secrets) in the iOS app.

The iOS client talks only to **your** HTTPS backend:

```
My Coach (iOS)
  → CoachAIProvider / RemoteCoachAI
    → HTTPS backend (your domain)
      → authenticates caller
      → validates Coach AI subscription entitlement when required
      → rate-limits requests
      → strips unnecessary / sensitive fields
      → calls the configured model provider with server-side secrets
      → validates structured JSON
      → returns a safe response to the app
```

Secrets stay server-side. Rotate keys without shipping an App Store update.

## Client responsibilities

- Use HTTPS only.
- Prefer short-lived auth (Sign in with Apple / App Store server notifications / your session tokens stored in Keychain — never in UserDefaults as long-lived raw secrets).
- Treat AI output as **explanatory**. Deterministic engines remain the source of truth for calories, macros, steps, and weekly adjustments.
- Validate structured responses before display (summary, recommendation, reasoning, userMessage).
- If the network fails, fall back to `LocalDeterministicCoachAI` messaging and keep food logging / plans available.

## Backend responsibilities

1. **Authenticate** the user or device session.
2. **Authorize** premium Coach AI features against a trusted entitlement signal (App Store Server API / signed transaction), not a client-only boolean.
3. **Rate limit** per user and IP.
4. **Minimize payload**: do not upload progress photo binaries to the model unless you have an explicit architecture, consent, and retention policy for that.
5. **Call** the model provider with server credentials.
6. **Validate** schema; reject hallucinated numbers that disagree with engine-provided targets when those targets were supplied in context.
7. **Redact logs**: no AI auth tokens, passwords, progress image URLs, or full health dumps.

## Configuration placeholders

| Item | Where to set | Notes |
|---|---|---|
| Backend base URL | App environment / remote AI initializer | e.g. `https://api.yourdomain.com` |
| Model provider API key | Backend secrets manager | Never in the IPA |
| Entitlement verification | Backend + App Store Server API | Required for paid Coach AI |
| Food API credentials | Backend or licensed SDK terms | Do not ship unrestricted secret keys in the client |

Until the proxy is live, the app should continue to compile and run with the local deterministic coach provider. Do not present mocked third-party AI or nutrition APIs as production services.
