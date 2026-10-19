`StarterGui.UIArchive.OldUI.__REACT_PHONE` (ModuleScript; note the name has ONE underscore between REACT and PHONE, not `__REACT__PHONE`)
exists in place "jacks project" (89999123284040) but its Source is EMPTY: 0 bytes, 0 lines, 0 children. Confirmed with
`#Source == 0` via execute_luau and an empty script_read. Nothing to save.

Searched: whole DataModel of "jacks project" for names containing react / roact (only the Packages React libs and this module);
"v2 place" (132358996787633) for react_phone / BobaPhone / Boba Phone / FoodTable (no hits). "Shore Watch" studio not searched (unrelated place).
Likely cause: the plugin output was never written to this open place, or the place file was not saved/synced after the plugin ran. Ask Jack (DEC-008).
