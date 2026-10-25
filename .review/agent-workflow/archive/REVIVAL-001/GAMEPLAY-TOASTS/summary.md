RESULT: PASS (code; runtime UNVERIFIED)
Files: src/shared/UI/Components/Core/Hud/SmallNotification.luau, docs/STYLE.md (4.4 behaviour, 9.8 payload)
- Push normalises Text from Title/Description (sep " " after ! ? . :, else ": "), clones table, warns once if no text.
  Computed: serve "Order served!"+desc -> "Order served! +N ..."; "Wrong drink"+reason -> "Wrong drink: reason"; "Customer left"+"Customer left. Combo lost." -> "Customer left: Customer left. Combo lost."
- Queue cap 3 (drop oldest hint else oldest); HOLD_BUSY=2 when queue non-empty else 5; hint loop skips when active/queued/<HINT_QUIET_SECONDS=20 after gameplay push.
- SmallNotification.IdleFor() added.
- Gate PASS (selene new=0, stylua ok), rojo build ok. Story unchanged (Text provided). No Push caller relied on replace-immediately (only AppDialogs/story push).
