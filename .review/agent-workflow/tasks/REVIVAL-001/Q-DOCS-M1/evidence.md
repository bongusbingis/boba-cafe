RESULT: PASS
CHANGED: docs/SYSTEMS.md (Ordering: OrderSpec/tool attributes, auto-match deposit, launch allowlist; new Customers (NPCs) section incl. contract paths, tickets, ServePrompt, PAY_TABLE marked PROPOSED, UniformService, TrashService, RIG-1 paths; Kitchen: KitchenGuidance + Q14 gates; Spills path to CleanlinessStorage; new M2 Systems table at end) and docs/ARCHITECTURE.md (world-path row, module lists, Customers data-flow bullet). No src/ or board changes; CRLF kept.
GATE: n/a (docs only).
CHECK: grep hits for CleanlinessStorage, workspace.Customers, CafePlayers, KitchenGuidance, ServePrompt in SYSTEMS.md; the only existing line changed is the Spills path.
STUDIO: none.
QUESTIONS: (1) code reads ReplicatedStorage.SharedStorage.NPCs, not in RIG-1 import; (2) RIG-1 lists Animations.Idle but NPC-LOOK reports the .rbxm has none; (3) AreaController does not reference workspace.Assets.AreaLimits.DesertWalls (authored only).
