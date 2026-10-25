---
id: STREAK-REMINDER
title: Opt-in streak-at-risk reminder (ExperienceNotificationService), inert until Jack configures it
priority: P2
role: Mason
worker_tier: sonnet
release_gate: after
depends_on: [SHIFT-END]
status: READY-PENDING-CONFIRM
source_commit: 098175c
read_scope:
  - src/server/Modules/DailyRewardService.luau (GetRewardStatus, ClaimReward)
  - src/shared/Configuration/DailyRewardConfig.luau (STREAK_EXPIRE_SECONDS, GetStreakStatus)
  - src/shared/Configuration/ProfileTemplate.luau (DailyRewardData, template table)
  - src/server/Modules/DialogService.luau (CreateDialog)
  - src/server/Modules/TrashService.luau (ButtonPrompt usage pattern, Styles require)
  - src/server/init.server.luau (PlayerAdded / PlayerRemoving hook order)
write_scope:
  - NEW src/server/Modules/ExperienceNotificationService.luau (Knit service Name "StreakReminderService")
  - NEW src/client/Modules/StreakReminderController.luau
  - src/shared/Configuration/ProfileTemplate.luau (add one field and its type only)
  - NEW src/server/Tests/StreakReminder.spec.luau (written, not run)
invariants:
  - Add-only profile change (HARD STOP 2 respected); no ProfileStore name bump.
  - Not on the serve path. No yield inside PlayerRemoving hooks: MemoryStore work is task.spawn'd (init.server runs all other hooks, then DataService).
  - No secret is created or stored. The Open Cloud key is read with HttpService:GetSecret and only when SEND_ENABLED is true.
  - Prompt UI is the existing ButtonPrompt dialog through DialogService:CreateDialog; no new component, token or visual (DEC-013).
  - Never blocks join or play; every call is wrapped in pcall; failure is warn-once.
acceptance:
  - Default build is inert: SEND_ENABLED = false and MESSAGE_ID = "" so nothing is sent and nothing errors.
  - A player with Streak >= 2 who has not been prompted sees one ButtonPrompt 45 s after join; the answer is stored and never asked again.
  - PlanReminder returns the right times per D5 (spec).
  - Gate shows no new findings in changed files; rojo build succeeds.
checks: ["gate on every changed file (WORKER-PRIMER 2)", "rojo build default.project.json -o <outside repo>"]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/STREAK-REMINDER
forbidden: [WORKER-PRIMER 8, editing DailyRewardService.luau or any DailyReward UI, creating API keys or secrets, enabling SEND_ENABLED, inventing a Creator Hub message template id]
---

## Source excerpt (verbatim)
- Q5: What: Streak-at-risk reminder via ExperienceNotificationService opt-in (plan 4.7). Why: D1/D7 retention. Files: new service. Effort: M. Risk: Low. Tag: JACK.
- Plan 4.7: "Experience notification opt-in (`ExperienceNotificationService`) for event start times."
- INVENTORY (e): STREAK-REMINDER needs the Roblox ExperienceNotifications feature enabled in the experience settings, a Jack-side setting, not an asset.

## Verified from the repo (HEAD 098175c)
- Streak data: `profile.DailyRewards = { Streak, LastClaimTime }`; claim cooldown 20 h, streak expires after 48 h (`DailyRewardConfig.CLAIM_COOLDOWN_SECONDS`, `STREAK_EXPIRE_SECONDS`). `DailyRewardService:GetRewardStatus` reads exactly these fields; this packet reads the same fields from the profile and does not edit that service.
- `init.server.luau` runs every service's `PlayerRemoving` before DataService, so the profile is still readable there. `playerAdded` hooks run in `task.spawn`.
- ButtonPrompt via server: `DialogService:CreateDialog(player, "ButtonPrompt", { Title, Text, Buttons = { { Text, Color } }, OffsetX = 0.1 }, timeoutSeconds)` returns a Promise of the clicked `Text` (RealOrderService `_askHearts`, TrashService).
- No file in `src/` references ExperienceNotificationService, HttpService secrets or MemoryStore for this purpose.

## Not verified (no repo or local docs source; the worker must not assert these as fact)
- Client API names `ExperienceNotificationService:PromptOptIn()` and `:CanPromptOptInAsync()` and the `OptInPromptClosed` event.
- The Open Cloud route `POST https://apis.roblox.com/cloud/v2/users/{userId}/notifications`, its body `{ source = { universe = "universes/<GameId>" }, payload = { type = "MOMENT", messageId = "<template id>", parameters = { streak = { stringValue = "<n>" } } } }`, the `x-api-key` header, the required key permission and rate limits.
- That message templates (with the text below) are created in Creator Hub, and that `HttpService:GetSecret` and MemoryStore SortedMap `GetRangeAsync/UpdateAsync` behave as coded.
The code keeps every one of these inside pcall and constants, so a wrong name only disables the reminder.

## Decisions made
- D1 Service file `ExperienceNotificationService.luau`, Knit `Name = "StreakReminderService"` (avoids shadowing Roblox's built-in service name). Client signal `PromptOptIn` (server to one client).
- D2 Profile field, add-only: `StreakReminder = { OptedIn = false, Prompted = false }`, type `StreakReminderData = { OptedIn: boolean, Prompted: boolean }` added to `ProfileTemplate` type and table, placed after `Quests`. Rationale: Reconcile fills it for old profiles.
- D3 Ask once. 45 s after `PlayerAdded`, if the player is still in game, `StreakReminder.Prompted` is false and `DailyRewards.Streak >= 2`, set `Prompted = true` first, then show the ButtonPrompt (D6). Rationale: players with a 2-day streak have something to lose and have seen the daily reward; marking first guarantees one ask even if the dialog times out.
- D4 On the answer `Remind me`: set `OptedIn = true`, then fire `Client.PromptOptIn:Fire(player)`; the client calls the Roblox opt-in prompt. On `No thanks` or timeout (90 s): nothing more. There is no settings toggle in this packet; re-asking is an Open item.
- D5 Plan (pure function `ExperienceNotificationService.PlanReminder(optedIn, streak, lastClaimTime, now)` returns the send time or nil): nil unless `optedIn`, `streak >= MIN_STREAK`, `lastClaimTime > 0` and `now < lastClaimTime + SEND_DEADLINE_SECONDS`; otherwise `math.max(lastClaimTime + REMIND_AFTER_SECONDS, now)`. Rationale: 36 h after the claim is 12 h before the 48 h expiry; 46 h leaves a 2 h margin.
- D6 Queue, since the player is offline when it is due: in `PlayerRemoving` (all reads first, then `task.spawn`), write the plan into MemoryStore SortedMap `StreakReminders`, key `tostring(userId)`, sort key = send time, value `{ u = userId, s = streak, d = lastClaimTime + SEND_DEADLINE_SECONDS }`, expiration `QUEUE_TTL_SECONDS`. On `PlayerAdded` remove that key (the player is back, the reminder is void). The claim path needs no hook because a rejoin always passes through PlayerAdded.
- D7 Poller: one `task.spawn` loop in `KnitStart`, every `POLL_SECONDS`, reads up to `POLL_BATCH` earliest entries; for each entry with sort key `<= os.time()` it claims the entry with `UpdateAsync` returning nil and acts only if the callback saw a non-nil old value (so two servers never both send); it sends only if `os.time() < d`. Stops reading at the first entry not yet due.
- D8 Send is inert by default: `SEND_ENABLED = false`, `MESSAGE_ID = ""`. `Send` returns false with a warn-once (`[StreakReminder] sending disabled; set MESSAGE_ID and enable after Jack configures the key.`) when either is unset. When enabled it uses `HttpService:RequestAsync` with the secret named `SECRET_NAME`, inside pcall, and never retries.
- D9 Client controller: `StreakReminderController:KnitStart` connects `Knit.GetService("StreakReminderService").PromptOptIn`; the handler pcalls `CanPromptOptInAsync` (a false result stops; an error is ignored) and then pcalls `PromptOptIn`. All inside `task.spawn`.

## Exact strings
- Prompt Title: `Streak reminders`
- Prompt Text: `Want a heads-up when your <b>{streak}-day</b> Daily Reward streak is about to end?` (streak is a plain integer; strip nothing else, no player text is inserted)
- Buttons: `{ Text = "Remind me", Color = Styles.GREEN }`, `{ Text = "No thanks", Color = Styles.RED }` (same Styles require as TrashService).
- Notification template text for Jack to create in Creator Hub (parameter name `streak`): `Your {streak}-day Boba Cafe streak ends soon! Claim your Daily Reward to keep it.`
- Warn strings: `[StreakReminder] sending disabled; set MESSAGE_ID and enable after Jack configures the key.` and `[StreakReminder] %s failed: %s`.

## Exact numbers (no economy values; nothing goes to the ledger)
- MIN_STREAK 2; REMIND_AFTER_SECONDS 129600 (36 h); SEND_DEADLINE_SECONDS 165600 (46 h); PROMPT_DELAY_SECONDS 45; PROMPT_TIMEOUT_SECONDS 90.
- POLL_SECONDS 120; POLL_BATCH 20; QUEUE_TTL_SECONDS 259200 (3 days); QUEUE_NAME `StreakReminders`; SECRET_NAME `OpenCloudNotifyKey`.

## Signatures and names
- `ExperienceNotificationService.PlanReminder(optedIn: boolean, streak: number, lastClaimTime: number, now: number): number?` (static, no Knit needed, tested by the spec).
- Methods: `:PlayerAdded(player)`, `:PlayerRemoving(player)`, `:_askOptIn(player)`, `:_enqueue(userId, sendAt, streak, deadline)`, `:_dequeue(userId)`, `:_poll()`, `:_send(userId, streak): boolean`, `:KnitStart()`.
- Profile reads: `playerData.DailyRewards.Streak`, `.LastClaimTime`, `playerData.StreakReminder.OptedIn/Prompted`; writes via `playerData:SetValue({ "StreakReminder", "Prompted" }, true)`. Data via `Knit.GetService("DataService"):GetDataAsync(player)` (cache the proxy in `_data[player]` at PlayerAdded, clear at PlayerRemoving).
- Spec cases: not opted in gives nil; streak 1 gives nil; lastClaim 0 gives nil; now before lastClaim + 36 h gives lastClaim + 36 h; now at lastClaim + 40 h gives now; now at lastClaim + 46 h gives nil.

## UI spec
Existing ButtonPrompt only, shown by the server on the Priority gui. No new element. Phone 844x390: ButtonPrompt already scales (OffsetX 0.1 as in TrashService).

## Studio checks (batched by Prime)
- S1 With a test profile at Streak 2 and Prompted false: join, wait 45 s, the Streak reminders prompt shows once; rejoin: it does not show again.
- S2 Press Remind me: `StreakReminder.OptedIn` is true in the profile; no error with the default inert constants (one warn at send time only).
- S3 Leave while opted in: no yield or error in output at leave; join again: no error removing the queue key.

## Asset prerequisites
None in the place file. Jack-side before it can work (not done by this packet): enable Experience Notifications for the experience, create the message template with the text above (gives MESSAGE_ID), create an Open Cloud API key with notifications permission, store it as the secret `OpenCloudNotifyKey`, enable HTTP requests. Only then set `SEND_ENABLED = true` and `MESSAGE_ID` (a later one-line change).

Open items:
- HARD-STOP 4 (secrets/credentials, Jack approval): Do you approve creating the Open Cloud key and secret `OpenCloudNotifyKey`, and the Creator Hub template text above (yes/no)
- Not verified facts above must be checked against Creator Docs by Prime or Jack before SEND_ENABLED is turned on.
- Re-ask path (a Settings toggle or a second prompt after 14 days) is not built; say so if wanted.

## Summary
- New server service (Knit name StreakReminderService) plus a small client controller; ButtonPrompt opt-in once at 45 s after join for Streak >= 2.
- Add-only profile field StreakReminder { OptedIn, Prompted }; reads DailyRewards Streak and LastClaimTime, never edits DailyRewardService.
- Offline delivery via MemoryStore SortedMap queue (send at claim + 36 h, drop after +46 h, cancelled on rejoin); polled every 120 s by any live server.
- Ships inert: SEND_ENABLED false, MESSAGE_ID empty; Roblox API names and Open Cloud route listed as Not verified.
- Hard stop: API key/secret and Creator Hub template need Jack; status READY-PENDING-CONFIRM; release gate after.
- No economy values, no ledger rows.
