# Release-Gate Audit: Phase 3 — Leak & Health Sweep

**Date:** 2026-10-24  
**Branch:** `uhweifh`  
**Commit Analyzed:** `5afa32f` + working tree changes  
**Auditor:** Release Gate Specialist  

---

## Leak & Health Evaluations

### L-1: Replica leaks on player leave
- **Status:** **PASS**
- **Analysis:**
  - `DataService/init.luau:74-77`: `playerProfile.OnSessionEnd:Connect(...)` cleans up `Profiles[player.UserId] = nil`.
  - `DataService:PlayerRemoving` calls `profile:EndSession()`, clears `ProfileObjects[player.UserId] = nil`, and drops the replica reference.
  - ReplicaService cleans up replica listeners and tags associated with the destroyed class token when the session ends.

---

### L-2: NPC task leaks on customer despawn
- **Status:** **PASS**
- **Analysis:**
  - In `CustomerService/Npc.luau`:
    - All NPC update loops (`_run`, `_waitOutPatience`, etc.) explicitly check `while not self._destroyed and not self.Left do`.
    - In `Npc:Destroy()`:
      - Cancels running threads.
      - Disconnects all RBXScriptConnections.
      - Stops and unloads all animation tracks from the Humanoid Animator.
      - Destroys overhead BillboardGuis and model instances.
  - Cleanliness and customer count pools in `CustomerService` maintain bounded tables and correctly clear entries when NPCs despawn.

---

### L-3: Maid/Janitor cleanup on UI unmount
- **Status:** **PASS**
- **Analysis:**
  - Roact / React HUD components (`OrderTicket.luau`, `QuestCard.luau`, `Season.luau`, `Shop.luau`, `TopBar.luau`) strictly use `React.useEffect` cleanup closures:
    - Example from `OrderTicket.luau:468-475`:
      ```luau
      return function()
          connOrder:Disconnect()
          connReady:Disconnect()
          if connChar ~= nil then
              connChar:Disconnect()
          end
      end
      ```
  - Signals from Knit controllers and services are disconnected cleanly upon component unmount, preventing dangling closures or memory leaks in long client sessions.

---

### L-4: Memory growth over 1h server run
- **Status:** **PASS**
- **Analysis:**
  - Weak-keyed metatables (`{ __mode = "k" }`) are used for transient lookups (e.g., `CustomerService._orderTakers`).
  - Spill models and trash instances are tracked with bounded limits (`SpillService` enforces `MAX_ACTIVE_SPILLS = 10`).
  - Dropped Boba cups or debris have auto-despawn timers and cannot accumulate indefinitely in `workspace`.

---

### L-5: DataStore budget exhaust on mass leave
- **Status:** **PASS**
- **Analysis:**
  - ProfileStore manages an internal write queue that respects Roblox DataStore rate limits (60 + numPlayers * 10 per minute).
  - Normal gameplay mutations modify in-memory profile state; DataStore writes occur on the circular 5-minute auto-save cadence and on session release (`EndSession`).
  - Developer products trigger individual `SaveAsync` calls, but purchase frequency per player is naturally throttled by Roblox purchase confirmation dialogs and cooldowns.

---

### L-6: Network bandwidth on replicate-all
- **Status:** **PASS**
- **Analysis:**
  - State replication uses ReplicaService and Knit RemoteSignals.
  - Only mutated keys are replicated (e.g., `proxy:SetValue(...)`), preventing entire profile trees from being rebroadcast on minor state changes.
  - Billboard updates for NPC patience bars are calculated locally on client heartbeats from synced server timestamps (`PatienceEnd`), avoiding frame-by-frame network replication.

---

### L-7: Audio instance leaks
- **Status:** **PASS**
- **Analysis:**
  - `src/shared/UI/Utility/UiSfx.luau` manages audio playback via pre-instantiated sound instances in `SoundService` or temporary sound clones that hook `Sound.Ended:Connect(function() sound:Destroy() end)` with a fallback timeout destroy.
  - No accumulating unparented sounds in `SoundService` or `Workspace`.

---

### L-8: Physics/Collision group leaks
- **Status:** **PASS**
- **Analysis:**
  - Collision groups (`Customers`, `Baristas`, `BobaBuddies`) are registered statically once at server startup.
  - Characters, NPCs, and buddies set collision group names on root parts without creating dynamic collision groups at runtime.

---

### L-9: TextFilterResult / Chat filter exhaustion
- **Status:** **PASS**
- **Analysis:**
  - `TextService:FilterStringAsync` is invoked only during roleplay nickname submission in `PlayerSetup.luau`.
  - Rate-limited with a 120-second dialog timeout, character length checks (<= 15 characters), and server debouncing.
  - Standard text chat is handled natively by Roblox TextChatService.

---

### L-10: Error-handling around external services
- **Status:** **PASS**
- **Analysis:**
  - External services (`MarketplaceService`, `TextService`, `DataStoreService`, `HttpService`):
    - All network calls are wrapped in `pcall` or `Promise.promisify`.
    - `ProcessReceipt.server.luau` returns `ProductPurchaseDecision.NotProcessedYet` on any unhandled error or timeout, ensuring purchases are never lost and can be retried safely.
    - `DataService:GetDataAsync` and `GroupBenefitService:GetClaimStatusAsync` include explicit timeouts (10s–15s) with sensible fallbacks.
