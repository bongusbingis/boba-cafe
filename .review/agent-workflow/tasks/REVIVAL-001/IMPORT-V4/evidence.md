RESULT: PASS
Files changed: IMPORT-V4/extract-v4.luau (new; serializeModel({clone}) direct form worked), src/shared/Configuration/CustomerDialogue.luau (new; Default/Karen Greeting, WrongOrder, Leaving verbatim), outputs in /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/v4-import/ (boba-v4.rbxl not committed)
Gate: PASS src/shared/Configuration/CustomerDialogue.luau (selene new=0, stylua ok, rojo build PASS)
Studio steps for later: RIG-1: insert the five .rbxm files in Studio and confirm BuiltBy="REVIVAL-001-import-v4" on each top-level instance.
Question for Jack: none. Note: lune 0.10.5 passes "--" as process.args[1], so extract-v4.luau skips a leading "--".
Per-file (byte size, root class, descendant count): CleanlinessStorage.rbxm 150230 Folder 94; NPCStorage-Karen.rbxm 2944 HumanoidDescription 8; NPCStorage-Animations.rbxm 1017 Folder 6; S_DefaultUniform.rbxm 578 Shirt 0; P_DefaultUniform.rbxm 578 Pants 0; CustomerConfig.v4.txt 4823 (text, no root). All five .rbxm round-tripped with BuiltBy="REVIVAL-001-import-v4".
NPCStorage-Idle.rbxm (523 bytes, Animation Idle, BuiltBy="REVIVAL-001-import-v4", exported by IMPORT-V4/extract-idle.luau to boba-gate/v4-import/); AnimationId not readable in lune 0.10.5 (missing default), so the id is unverified.
RIG-1: insert NPCStorage-Idle.rbxm into SharedStorage.NPCStorage.Animations
