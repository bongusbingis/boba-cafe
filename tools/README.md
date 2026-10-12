# Place-file inspection tools

Read-only [lune](https://lune-org.github.io/docs) scripts for inspecting `.rbxl` files. They were
written to diff `old-v3.rbxl` (the live V3 game) against `current-baseplate-build.rbxl` (the new
build) while porting, and are kept because that diff has to be re-run as the port progresses.

**Requires lune >= 0.10.5.** Earlier versions fail with
`Property Accessory.Tags should be SharedString, but it was Tags`
([lune#397](https://github.com/lune-org/lune/pull/397)). The version is pinned in `aftman.toml`.

None of these scripts write to the place file — they only read and print.

## `tree.luau` — hierarchy dump

```bash
lune run tools/tree.luau <place.rbxl> [maxDepth]
```

Prints `Name [ClassName] {childCount}` per instance across the major services. Depth defaults to 3.
Use depth 1–2 to get the shape of a place quickly.

```bash
lune run tools/tree.luau old-v3.rbxl 2
```

## `extract.luau` — dump every script source

```bash
lune run tools/extract.luau <place.rbxl> <outDir>
```

Writes every `Script`/`LocalScript`/`ModuleScript` source into a directory mirroring the DataModel
hierarchy, suffixed `.server.luau` / `.client.luau` / `.module.luau`. Also writes `_MANIFEST.txt`,
sorted by byte size — the fastest way to spot which systems carry real weight.

**`outDir` is deleted and recreated on each run.** Point it somewhere disposable, not at `src/`.

```bash
lune run tools/extract.luau old-v3.rbxl /tmp/old-scripts
head -40 /tmp/old-scripts/_MANIFEST.txt
```

## `gui.luau` — GUI dump with styling properties

```bash
lune run tools/gui.luau <place.rbxl> <path/within/place> [maxDepth]
```

Prints a GUI subtree with the properties that matter for reproducing a design in React (Size,
Position, colours, Text, Image, Font, constraints, corner radii). The path is slash-separated and
starts with a service name.

```bash
lune run tools/gui.luau current-baseplate-build.rbxl StarterGui/MainUI 2
lune run tools/gui.luau current-baseplate-build.rbxl StarterGui/Popups/PriorityHolder 1
```

This is the intended way to get exact values when rebuilding one of the art-reference frames in
`StarterGui/MainUI` as a React page.
