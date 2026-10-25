# ENGAGE-FRIEND-INVITE / X10: Friend Invite Reward

## Status: COMPLETE (PASS)
- Date: 2026-10-21
- Role: Mason
- Gate: PASS (selene new=0, stylua=ok, rojo build ok)
- TestEZ: PASS (11 passing specs, 0 failing; full suite 714 passing, 0 failing)

## Implementation Summary
1. **Profile Schema (`src/shared/Configuration/ProfileTemplate.luau`)**:
   - Added add-only schema field: `InvitedFriends: { [string]: boolean }`.
   - Default value: `{}` in ProfileTemplate.

2. **Server Service (`src/server/Modules/SocialInviteService.luau`)**:
   - Knit service `SocialInviteService`.
   - Config: `INVITE_REWARD_BOBABUCKS = 50`.
   - Client signal: `InvitePromptRequested`.
   - Methods:
     - `PromptInvite(player)`: Fires client request.
     - `ProcessPlayerJoin(player)`: Reads `player.FollowUserId` (or `GetJoinData().FollowUserId`). Verifies valid inviter in server (`inviter ~= player`). Validates and updates `profile.Data.InvitedFriends[tostring(player.UserId)]`.
     - Payout: `CurrencyService:Modify(inviter, "BobaBucks", 50, "FriendInvite")`.
     - Toast: `DialogService:Notify(inviter, "Friend Joined!", "Your friend joined! +50 BobaBucks")`.
   - Handles `Players.PlayerAdded` and existing players on startup.

3. **Client Controller (`src/client/Modules/SocialInviteController.luau`)**:
   - Connects to `SocialInviteService.InvitePromptRequested`.
   - Invokes `SocialService:CanSendGameInviteAsync` and `SocialService:PromptGameInvite(player)`.

4. **HUD Trigger (`src/shared/UI/Components/Core/Hud/BottomLeft.luau`)**:
   - Added "Invite Friends" button in HUD bottom left to trigger `SocialService:PromptGameInvite`.

5. **Unit Specs (`src/server/Tests/SocialInviteService.spec.luau`)**:
   - 11 unit tests covering:
     - Config reward constants
     - `PromptInvite` client signal emission
     - Non-invite joins (no FollowUserId or invalid)
     - Valid friend join and first-time payout + notification
     - Duplicate friend join prevention (idempotent, no second payout)
     - Self-join guard
     - Data load failure guard
