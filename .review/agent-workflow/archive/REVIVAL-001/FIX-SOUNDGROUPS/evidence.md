RESULT: PASS (Jack: "make whatever changes necessary to the tree")
CHANGED: SettingsConfig.luau (SFX toggle -> SoundService.UISounds; on = volume 1). Studio: new SoundGroup SoundService.Music (BuiltBy=FIX-SOUNDGROUPS, vol 1) for SFX.Music.{DiscoMusic,MusicSound}; the other 19 sounds in SFX + UISounds now have SoundGroup=UISounds (attr SoundGroupSetBy=FIX-SOUNDGROUPS); UISounds.Volume 0.5 -> 1 so loudness is unchanged. Place needs saving.
GATE: PASS (stylua reformatted the config table, formatting only)
STUDIO LATER: Settings > Music/SFX off mutes music / kitchen+UI sounds; no "[Settings] ... not a SoundGroup" warn.
QUESTIONS: none
