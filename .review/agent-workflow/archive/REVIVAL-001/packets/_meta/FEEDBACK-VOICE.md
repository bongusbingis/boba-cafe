# FEEDBACK-VOICE (Prime, 2026-10-20): one voice for every serve and progress beat

Governs copy and budget for SERVE-FEEDBACK, SERVE-PAYPOPUP, NPC-REACTIONS, SOUNDS, SHIFT-END, HUD-LEVELBAR, QUESTS-PING, RUSH-BANNER, NOTIF-HINTS, ONBOARD-*. Packets amended to match.

## 1. Voice
- Short, warm, present tense, sentence case. Max 8 words per toast headline, max 60 characters total.
- Exclamation mark only on celebrations (first order, combo, team combo, level up, best shift, rush). Never on nudges or info.
- Numbers first-class: "+12 BB", "Combo x5", "Team 7/10". Use "BB" in popups and toasts; "Boba Bucks" only in the first-order toast and the Shop.
- No emoji, no "Congratulations", no "Great job". Name people by DisplayName (cut to 8 chars in banners only).
- Separator inside a toast is " · " (middle dot). Multiplication sign is U+00D7 as the current serve toast.

## 2. Serve feedback budget (per serve, in order of appearance)
| # | Beat | Channel | When | Sound |
|---|------|---------|------|-------|
| 1 | "+N BB" popup over the NPC | world gui (GOLD) | instantly, always | none |
| 2 | Serve toast "Order served! ..." (grade, combo, Team N/10 from 5) | toast queue | instantly, always | Serve chime, pitch rises with combo |
| 3 | Bucks pulse + count-up | HUD CurrencyPanel | when balance replicates | none |
| 4 | NPC wave + leaving line | NPC | on leave | none |
| 5 | Perfect sparkles | world particle | Perfect only | none |
| 6 | Combo milestone toast (3, 5, 10) | toast queue | after #2 | Pop1 |
| 7 | First-order toast | toast queue | first serve only | Success |
| 8 | Team Combo (named) toast | toast queue | on 10th chain | Pop1 |
Hard limits: at most 2 toasts per serve in steady state (#2 plus one of #6/#7/#8). #6 and #7 never both: first order wins (combo is 1 anyway). Popup and pulse are not toasts and do not count.

## 3. Toast priority (higher shows first; queue is FIFO within a tier, tier 4 may drop when 3+ are waiting)
1. Level up (includes unlocks) and shift card events. 2. Team Combo, first order, Best shift. 3. Combo milestone, quest complete/claim, quest halfway. 4. Serve toast, capsule nudge, welcome, Rush thanks, hints.
GAMEPLAY-TOASTS owns the queue; this tier list is the target when it gets a priority field. Until then FIFO is acceptable.

## 4. Which beats get sound (SoundService.SFX.UI, skip silently if missing)
Serve (per serve), LevelUp (level-up flash, reuse Success until supplied), Success (first order, quest claim), Pop1 (combo milestone, Team Combo, quest complete), Rush (Rush start), StepDone (held-tool step). No sound for: popup, Bucks pulse, hints, welcome, capsule nudge, halfway ping, banners. Never two sounds within 150 ms of each other; Serve is the exception (always plays).

## 5. Gold rule
GOLD (and its derived stroke) is reserved for money (+N BB, balance, Bucks pulse) and rank (Lv pill, level fill, stars, Best shift). Not for combo, team, quest, hints, buttons or banners. Combo toast text is plain; Rush banner uses the existing event colour token.

## 6. Exact strings (canonical; packets must match)
- Serve toast: `Order served! {Grade} · Combo ×{n}` + ` · Team {chain}/10` when chain >= 5 (keep the current head text; only the suffix is new).
- Combo: `Combo ×{n}! Next serve +{P}% pay`. First order: `Your first order! +{pay} Boba Bucks`.
- Team: `{Name} completed the Team Combo! +10% pay for 60 seconds!`.
- Level up: `Level up! You are now level {L} · {unlock1} · {unlock2}`.
- Welcome: `Welcome to Boba Cafe! Follow the gold glow to make your first drink.`
- Capsule: `You can afford a capsule! Check the Shop.` Best: `Best shift ever!` / `New best combo!`.
- Rush: `Rush Hour! m:ss`; party `{Name}'s Party! m:ss`; thanks `Thank {Name} with an emote!`.
- Leaving: served lines from DEC-054 Q-G6; walkout `Wow... Ok...`.

## 7. Timing rules
- A modal (Daily dialog, nickname prompt, shift card) never opens while a toast from tier 1-2 is on screen: wait for the queue to drain, +1 s.
- No beat fires during the first 3 s after clock-in other than the welcome toast.
- Hints rotate only when the queue is empty.
