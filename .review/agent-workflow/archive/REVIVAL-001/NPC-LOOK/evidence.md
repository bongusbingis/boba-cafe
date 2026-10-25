RESULT: PASS (with one question)
Files: src/server/Modules/CustomerService/Npc.luau, CustomerService/init.luau (PlayConfused/SayWrong hook), src/server/Modules/UniformService.luau (new)
Gate: see final run; Npc/init/UniformService selene new=0, stylua ok, rojo build PASS
Paths used: ReplicatedStorage.SharedStorage.NPCs (HumanoidDescriptions), SharedStorage.NPCStorage.Animations (Wave, Confused, Idle), SharedStorage.KitchenStorage.Assets.S_DefaultUniform / P_DefaultUniform. Missing = warn once + fallback.
Question for Jack: NPCStorage-Animations.rbxm holds Wave, Confused, BoothSit, ComfySit, CafeSit, CouchSit; there is NO Idle. Idle is skipped silently until one exists.
M1.6 capture: NPC arriving (look, wave, greeting line), wrong serve (confused + WrongOrder line), served/patience-out (Leaving line), barista clock in/out (uniform on, original clothes back).
