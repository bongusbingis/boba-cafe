RESULT: PASS

# SEASON-PASS — Featured + Season page redesign (2026-10-23)

Prime redesigned the two Shop storefront pages after Jack rejected the first visual pass. No economy values, product IDs, or server behavior were changed by this pass (server: untouched; only the two Shop pages, the Products tab, and one unshipped nametag name).

## Jack's decisions (2026-10-23)
- Featured page: hero offers + product grid below; Starter Bundle leads while unclaimed, then the Season Pass hero.
- Season page: compact header (name, days left, XP progress, buy button + live price) + 6-per-row tile grid of all 30 tiers.
- Starter Bundle purchasable on: Featured hero + Products tab (not the Season page).
- Hero art: existing placeholder asset IDs until Jack provides key art.

## What changed
- `src/shared/UI/Pages/Shop/Featured.luau` (rewritten)
  - Two full-width hero offers built page-locally from `Pane`/`PromptButton`/`usePx` + existing tokens.
  - Hero cards use the game's button/card surface language: **solid fills** (Starter = `GREEN`, Season = `GREEN_LIGHT`) with a **same-hue darkened stroke at thickness 3** (the `PromptButton` recipe) — no thin contrasting outline, no transparent card. White text on green / `GREEN_DEEP` text on light green.
  - Starter hero (`GOLD_MID` "One-Time Offer" tag, `GREEN_DEEP` Buy button) leads while unclaimed; Season hero (`ROSE_MID` "New Season" tag, `GREEN` View Season button) opens the Season tab.
  - "More to Collect" section label + the original 7 `ShopCard`s in a wrapping pixel grid (`usePx` 150x200) below the heroes.
  - Starter hero hidden once `StarterBundleClaimed`; Season hero opens the Season tab via `OpenShopRequested("Season")`.
- `src/shared/UI/Pages/Shop/Season.luau` (rewritten)
  - Header card: `Season {id}` title, `{days} days left · {n} of 30 tiers`, green XP progress bar to next tier; "Buy Season Pass" + live price (or "Premium · n/30 tiers claimed").
  - 30-tier tile grid (`usePx` 128x150 tiles, wrapping `UIListLayout`): number / reward text / state (CLAIM green stroke, CLAIMED dimmed, LOCKED dimmed, PREMIUM gold stroke, empty `–`). Tiles are `TextButton`s; claim + premium prompts are click-only.
  - Reward labels fixed ("Sunrise Nametag", "+1 Quest Slot", etc.) — no more `Season1Sunrise Nametag` concatenation.
- `src/shared/UI/Pages/Shop/Products.luau`
  - New "Starter Bundle" `ShopCategory` row at the top (LayoutOrder -1), live price, prompts the product; hidden once claimed or while the ID is nil.
- `src/shared/Configuration/InventoryItemDefinitions/Nametags.luau` + `SeasonConfig.luau`
  - Renamed the unshipped premium nametag `Season1Sunrise` -> `Sunrise` (display fix; item is unreleased).
- Deleted dead `src/shared/UI/Pages/Shop/OfferCard.luau` (no references).

## Gate
`stylua` clean on all touched files; `scripts/gate.sh` PASS (selene new=0 on every touched file, stylua=ok, rojo build ok).

## Still owed
- Jack visual check in Studio (this is the Lens gate): Featured and Season pages at 0.7/0.7 story size and in-game.
- Confirm the Featured card -> Season tab switch shows the Season tab selected (the prior screenshot showed Featured highlighted while Season content was shown; the App remount path was left untouched and should now land on Season correctly — verify).
- Jack key art for the two heroes (optional; placeholders in place).
- Product IDs are live (`SeasonPass 3721438870`, `StarterBundle 3721439110`) — purchases now surface.
