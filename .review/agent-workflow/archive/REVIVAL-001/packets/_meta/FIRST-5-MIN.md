# FIRST-5-MIN (Prime, 2026-10-20): the first session of a new profile, in order

Governs ONBOARD-FIRSTRUN, ONBOARD-NICK, SERVE-FEEDBACK, SHIFT-END, GAMEPLAY-PROGRESS-CALLOUTS, HUD-LEVELBAR, SOUNDS. Copy lives in FEEDBACK-VOICE.md section 6.

## Timeline (new profile: CustomersServed == 0, ShiftsCompleted == 0)
| t | Event | Owner | Rule |
|---|-------|-------|------|
| 0:00 | Join. No Daily dialog, no nickname prompt. HUD shows Bucks, Lv 1 bar, Shift pill. | FIRSTRUN, NICK | Both modals deferred. |
| 0:10 | Player clocks in. Welcome toast (once per session, ShiftsCompleted == 0). | FIRSTRUN | 3 s quiet window after clock-in; welcome is the only beat. |
| ~0:40 | First scripted customer ordered; gold glow guides the first drink. | existing | Hints stay silent (queue non-empty or welcome showing). |
| ~1:30 | First serve: popup +N BB, serve toast, Serve chime, Bucks pulse, NPC wave. | SERVE-FEEDBACK, PAYPOPUP | |
| +0.2 s | "Your first order! +N Boba Bucks" toast (Success). | SERVE-FEEDBACK | Replaces any combo toast on this serve. |
| +toast drain +1 s | Daily reward dialog opens (if claimable). | FIRSTRUN | Waits for CustomersServed > 0 AND no tier 1-2 toast on screen. Collision fix: previously the modal could cover the first-order toast. |
| 2-5 min | Normal serves; combo milestone toast at 3 (Pop1). Level-up toast + LevelUp sound + bar flash on first level. | SERVE-FEEDBACK, PROGRESS-CALLOUTS | Level-up is tier 1: shows before a queued serve toast. |
| shift end | Shift card (stars, best-shift row on first shift is skipped: no previous best). | SHIFT-END | First shift never shows "Best shift ever!" (nothing to beat). |
| card +8 s | Nickname prompt with Skip. | NICK | Opens 8 s after ShiftEnding, never over the card. |
| after nick (or Skip) | Capsule nudge toast if Bucks >= cheapest capsule, once per session. | SHIFT-END | Fires after the nickname prompt is closed (wait for it), never stacked on it. |

## Ordering rules to enforce in code
1. Nickname prompt: opens 8 s after ShiftEnding and only when the shift card is closed; if the card is still open, retry every 1 s up to 30 s, then skip until next shift end.
2. Capsule nudge: NUDGE_DELAY_SECONDS stays (balance has landed); if the nickname prompt is open, defer until it closes (client toast, so a server delay of 12 s is enough: nick at 8 s plus typing).
3. Daily dialog: opens only when the toast queue is empty for 1 s (see FEEDBACK-VOICE 7).
4. Level-up callout is never suppressed by the first-order toast; it queues after.
5. Welcome toast text must not change (SOUNDS contract).

## Collisions found and resolved
- Daily (modal) vs first-order toast: resolved by the drain wait.
- Nickname prompt vs shift card vs capsule nudge: resolved by items 1-2.
- "Best shift ever!" on a first shift: suppressed (previous best is 0).
- Hints vs welcome: hints rotate only on an empty queue.
