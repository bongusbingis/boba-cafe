RESULT: PASS
Task: REALORDER-HEARTS (source 098175c)
Files: src/server/Modules/RealOrderService.luau, src/server/Tests/RealOrder.spec.luau (append only)
Gate: PASS (selene new=0 both files, stylua=ok, rojo build ok); rojo build default.project.json -> /tmp/boba-hearts.rbxlx ok
Acceptance:
- Prompt wired for fresh serves only: call site after REALORDER-SHIFT block, before final AdvanceQuest pcall, guarded `customer ~= nil and CountsForTeamChain(multiplier)`, task.defer+pcall (RealOrderService.luau:_onOrderPickedUp)
- Rating tap N: HeartsReceived +N, HeartsCount +1, toast `HeartsToast(customerName, hearts)` via DialogService:Notify in pcall inside andThen (RealOrderService.luau:_askHearts)
- Singular/plural: HeartsToast 1 -> "heart", 2-5 -> "hearts"; CUSTOMER_NAME_MAX=20; DisplayName cleaned `[<>&]` via own local (RealOrderService.luau:HeartsToast)
- Dismiss/timeout/throttled: ParseHearts nil -> return, no stats/toast; throttled (multiplier 1) never defers prompt; rating guard prevents second prompt
- D6/D7/X6 inert: HEART_BUTTONS text 1-5 unchanged, ParseHearts unchanged, prompt Title/Text unchanged, no icon/emoji built
UNVERIFIED: all runtime behavior (S1-S6 Studio checks batched by Prime); spec written not run per DEC-019
Risks: money-path file edited — Sentry review required before sign-off
Next: Sentry review lane; Jack S1-S6 milestone run; HARD-STOP 1 heart-asset question pending
