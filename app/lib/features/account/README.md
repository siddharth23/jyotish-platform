# Account feature — deletion

US-015. The mobile half of self-service account deletion.

| File | Purpose |
|---|---|
| `account_deletion_controller.dart` | Requests deletion once; never reports success it did not get. |
| `presentation/delete_account_screen.dart` | The explanation the user reads before confirming (AC2). |

## Why this screen is mostly prose

Apple guideline **5.1.1(v)**: an app offering account creation must offer deletion *inside the app*.
A support address or a web link is a review rejection, so this route gates store submission. AC1
caps the distance at three taps — Profile tab, the row, the confirm — and there is a test that
counts them, so inserting a "Settings" level in between fails in CI rather than in review.

The rest is AC2. "Delete my account" and "erase every trace of me" are different promises: German
tax law obliges us to keep invoices for ten years (§147 AO), and GDPR Art. 17(3)(b) is what makes
that lawful. A user who learns this afterwards has a complaint to a supervisory authority. So the
retained item names the paragraph, states the term, and says what the kept record contains — and
the confirmation dialog repeats it, because the last screen before an irreversible action must not
be the one place where the promise is simpler than the truth.

`DELETION_PLAN` in `api/src/modules/identity/deletion.ts` is the authoritative list. **If it
changes, this copy changes with it.**

## The shipped gateway refuses

`UnavailableAccountDeletionGateway` returns null, because `api/src/main.ts` has no HTTP layer yet —
the same posture as `UnavailableAuthGateway` and `UnavailableSessionRefresher`. Reporting a
scheduled deletion without a server would be the worst possible lie for this particular feature, so
the screen shows its error state instead.
