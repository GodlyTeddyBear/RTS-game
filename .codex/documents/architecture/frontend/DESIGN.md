# Frontend Design

- This document defines how to create the visual style of frontend UI.
- It applies before implementation: screens should have an intentional appearance plan before components are built.
- This does not replace layer, hook, or component placement rules.
- Use this with `FRONTEND.md`, `COMPONENTS.md`, `ANIMATION_PATTERN.md`, and `UDIM_LAYOUT_RULES.md`.

---

## Style Creation Process

Start with concept, not tokens.

For every new screen or feature UI, define:

- Player-facing purpose of the screen
- Primary action or primary information
- Emotional role: command center, inventory, combat, log, market, upgrade, alert, etc.
- Hierarchy: what should be seen first, second, and last
- Interaction model: inspect, select, compare, confirm, navigate, manage, or monitor

Choose surfaces, accents, spacing, and motion only after that concept is clear.

---

## Visual Direction

Use tactical RTS/game UI, not generic app UI.

- Prefer near-black surfaces, warm gold metallic strokes, strong readable panels, compact information density, and purposeful highlights.
- UI should feel like an in-game command interface: structured, decisive, and readable under pressure.
- Avoid default gray boxes, flat utility dashboards, randomly themed feature screens, and decoration that does not support hierarchy.

---

## Cards And Panels

Cards are strictly limited.

- Use cards for repeated items, selectable entries, inventory slots, compact summaries, modal choices, or functional framed panels.
- Do not use cards as the default way to lay out an entire screen.
- Do not put cards inside cards.
- Prefer full-screen bands, anchored panels, split functional regions, list rows, slots, tabs, and command bars for major structure.
- Frame a surface only when the boundary helps the player understand grouping, selection, containment, or interaction.

If everything is a card, nothing has hierarchy.

---

## Composition Rules

- Every screen needs one dominant focus.
- Group related controls into functional regions, not decorative boxes.
- Align repeated elements to clear rows, columns, grids, or anchored panel regions.
- Leave enough negative space around primary actions and important values.
- Dense RTS UI is allowed, but density must come from organized information, not clutter.
- Use scale-based sizing and positioning from `UDIM_LAYOUT_RULES.md`.

---

## Depth, Chrome, And Decoration

Use purposeful chrome.

- Gold strokes, gradients, bevel-like highlights, shadows, and glows should communicate importance, selection, rarity, danger, progress, or interactability.
- Avoid decorative effects that compete with gameplay information.
- Major panels may use stronger chrome; secondary controls should be quieter.
- Do not stack gradients, strokes, glows, and shadows unless each layer has a distinct role.

---

## Token Use

After choosing the visual concept, implement it with existing tokens first:

- `ColorTokens`
- `GradientTokens`
- `SpacingTokens`
- `BorderTokens`
- `TypographyTokens`
- `AnimationTokens`

Hardcoded colors, spacing, radii, and animation values need a clear reason. Add new tokens only for values expected to recur across multiple UI pieces or features.

---

## Typography And Copy

- Use typography to establish command hierarchy: title, section label, value, description, metadata.
- Use short, functional text.
- Important values should be scannable without reading full sentences.
- Do not reduce text below readable token sizes to force a layout to fit.

---

## Interaction States

- Interactive elements need clear default, hover, pressed, selected, disabled, and loading/error states where relevant.
- Hover and press motion must not resize or shift neighboring layout.
- Selected state should be stronger and more persistent than hover.
- Destructive, expensive, or irreversible actions need stronger visual distinction than ordinary navigation.

---

## Common Anti-Patterns

- A screen made from floating cards with no clear primary focus.
- Cards nested inside panels inside more cards.
- Generic app dashboard styling.
- Hardcoded visual values when tokens already exist.
- Decorative gold everywhere with no hierarchy.
- Low-contrast text on dark surfaces.
- Offset-based layout for screen structure.
- Feature UI inventing a new unrelated style without a gameplay reason.
- Empty space filled with decoration instead of improving composition.

---

## Design Review Checklist

- [ ] The screen has a named visual concept.
- [ ] The primary focus is obvious.
- [ ] Cards are used only where they clarify repeated or contained content.
- [ ] Major structure uses panels, regions, rows, grids, command bars, or tabs rather than generic cards.
- [ ] Chrome communicates hierarchy or interaction.
- [ ] Existing tokens are used before hardcoded values.
- [ ] Layout follows `UDIM_LAYOUT_RULES.md`.
- [ ] Repeated and interactive elements are layout-stable.
- [ ] Motion supports interaction and follows `ANIMATION_PATTERN.md`.
