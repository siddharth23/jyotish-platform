# Auth feature — sign-in and sessions

US-012 (social sign-in) and US-016 (sessions and token refresh). The mobile half of both.

| File | Purpose |
|---|---|
| `social_provider.dart` | Which providers each platform may show. Guideline 4.8 lives here (AC1, AC2). |
| `social_credential.dart` | What a provider returns, private-relay detection, Apple's first-authorisation problem (AC4). |
| `apple_authorisation_store.dart` | Persists what Apple disclosed once. |
| `account_linking.dart` | When a social sign-in may join an existing account (AC3). |
| `social_sign_in.dart` | Port to the platform sheets. No real adapter yet — see below. |
| `auth_gateway.dart` | Port to the API's identity module. Unimplemented; the API has no HTTP layer. |
| `auth_controller.dart` | Riverpod state machine. Double-tap guard, cancel handling, relay flag. |
| `presentation/sign_in_screen.dart` | The screen and the linking prompt. |
| `session_tokens.dart` | The token pair, its expiry skew, and a `toString` that never prints a token. |
| `secure_token_store.dart` | Keychain / Android Keystore. **Not** `shared_preferences` (US-016 AC2). |
| `session_controller.dart` | Holds the session, renews it single-flight, ends it on rejection. |

## Five rules that are easy to break by accident

**Never refresh twice at once.** The server rotates the refresh token on every use and treats a
second presentation of an already-rotated token as proof it was copied — it revokes every session
for the account. So the ordinary client shortcut of firing a refresh per in-flight request does not
merely waste a call: three screens opening together means three refreshes with the same token, two
of which look exactly like theft, and the user is signed out everywhere. `SessionController`
collapses concurrent callers onto one in-flight refresh. That latch is a correctness requirement,
not an optimisation.

**Never put a token in `shared_preferences`.** Everything else the app persists goes there; a
refresh token is the account for sixty days and belongs in the Keychain or the Keystore.
`apple_authorisation_store.dart` is the deliberate exception and explains itself — it holds an
address, which authenticates nobody.

**Never build a provider list by hand.** `SocialSignInAvailability.providersFor` puts Apple first
on iOS and returns *nothing at all* when Apple is unavailable there. Guideline 4.8 makes Google
alone on an iPhone a rejection, and the way that ships is not a developer deciding to break it —
it is a kill switch turning Apple off during an incident. The rule fails closed and has one home.

**Never decide anything from `SocialCredential.email`.** It is a field an SDK filled in, inside a
process the user controls. Linking on it means: send the victim's address, receive their account.
The API reads the address and the `email_verified` claim out of the verified identity token, and
the API is the only side that can.

**Never let a second Apple authorisation overwrite the first.** Apple discloses the address and
the name once, on the first authorisation, and there is no way to ask again — the user would have
to revoke the app under their Apple ID and start over. `withRememberedAppleDetails` writes them to
disk before the network is touched, and `AppleAuthorisationStore.write` refuses to replace a stored
value with null.

## Wiring the real adapters

Everything above this line is tested. What is missing is the SDK calls, and the credentials they
need:

1. **Dependencies** — `sign_in_with_apple` and `google_sign_in`. Both add native surface, so they
   go through the dependency review `CLAUDE.md` requires.
2. **Apple** — an App ID with the Sign in with Apple capability, the matching entitlement in
   `ios/Runner/Runner.entitlements`, and a provisioning profile that carries it. A Services ID and
   a return URL are needed as well once the API verifies tokens server-side.
3. **Google** — OAuth client IDs for the Android signing certificate (debug *and* release SHA-1;
   a release build with only the debug fingerprint registered fails on the device and nowhere
   else) and for the iOS bundle, plus the reversed client ID as a URL scheme in `Info.plist`.
4. **Buttons** — Apple's branding rules require their own button asset and one of their approved
   labels. `signInWithApple` in the ARB carries the approved German wording; the button currently
   uses the design system's own with a material icon, which must be swapped before review.
5. **Implement `SocialSignIn`** and override `socialSignInProvider`. The adapter's only jobs are
   to map cancellation onto `SocialAuthorisationCancelled` — not an error — and to pass the raw
   identity token through untouched.

Until then `UnconfiguredSocialSignIn` reports every provider unavailable, the screen shows the
email and password path instead, and nothing pretends to work.

## Licensing

No engine code, no chart computation. See `docs/AGPL-BOUNDARY.md`.
