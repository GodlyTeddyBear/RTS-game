<!-- This is a repo-local prompt template. Codex does not automatically expose this as a slash command. Prefer the matching skill when available. -->

Analyze the UI code at `$ARGUMENTS` and suggest refactors to align it with this project's frontend separation patterns. Do not modify files unless the user explicitly asks after seeing the report.

If no argument is provided, analyze the most recently edited UI files from the conversation context.

---

## Before starting

Read these docs first:
- `.codex/documents/architecture/frontend/FRONTEND.md`
- `.codex/documents/architecture/frontend/HOOKS.md`
- `.codex/documents/architecture/frontend/COMPONENTS.md`
- `.codex/documents/architecture/frontend/SCREEN_TEMPLATES.md`
- `.codex/documents/architecture/frontend/ANIMATION_PATTERN.md`
- `.codex/documents/architecture/frontend/ANTI_PATTERNS.md`

Do not recommend patterns that conflict with these docs.

---

## Scope

Target can be:
- a screen file (`Presentation/Screens/...`)
- a component file (`Presentation/Atoms|Molecules|Organisms/...`)
- a folder containing related UI files

Always read all directly related files before judging (parent screen/template, called hooks, child components, and key imports).

---

## What to analyze

Evaluate each target against these separation rules:

1. **Screen composition**
   - Screen/template files should mostly compose and wire props.
   - Complex orchestration (timers, chained side effects, sequencing) should be in `use[Screen]Controller`.
   - Screen/template files should not directly orchestrate animation primitives (`TweenService:Create`, `spr.target`, `spr.completed`, animation sequencing via `task.delay/task.wait`).

2. **Presentation purity**
   - Atoms/molecules/organisms should render and emit intent.
   - Side effects (sound, navigation sequencing, service calls) should not live in presentational components.

3. **Animated component structure**
   - For animation-heavy organisms, prefer:
     - wrapper component
     - `use[Component]Controller` hook
     - pure `[Component]View`

4. **Prop contract quality**
   - Flag unused props, redundant props, and leaky prop surfaces.
   - Suggest minimal, truthful contracts.
   - Flag any inline data transformation inside a render function (e.g. `string.sub(...)`, arithmetic on props). These belong in the ViewModel, not the component.

5. **Hook structure quality**
   - Hook bodies should be readable orchestration, with helpers extracted as needed.
   - Flag unstable callback creation when it meaningfully harms readability/perf.
   - Flag delayed tasks without cancellation/cleanup.
   - Flag screen controllers that call `useSoundActions` directly. Sound side-effects should be delegated to a dedicated `Hooks/Sounds/use[Feature]Sounds.lua` hook that wraps all sound calls for the feature.
   - Flag screen controllers that contain animation orchestration (spring calls, refs, `useHoverSpring`, `useSpring`). These belong in `Hooks/Animations/use[Component]Controller.lua`.
   - Flag flat `Hooks/` folders with 5+ files that mix concerns — suggest organizing into `Sounds/` and `Animations/` sub-folders.

6. **Layer placement**
   - Presentation depends downward on Application; no infra/service orchestration directly in render files.

7. **Component decomposition**
   - A component whose `return` block is longer than ~40 lines or contains multiple clearly named sub-regions is a decomposition candidate.
   - Each logical region that can be named (icon area, description, quantity controls, action buttons) should be extracted to `[Feature]/Presentation/Molecules/` as a molecule — even if it is only used once. The test: can you give it a meaningful name and a clean props contract? If yes, extract it.
   - Components that rely on loops or condition checks to construct parts of themselves should not remain as one monolithic function. Small variants: break into local sub-functions within the file. Larger variants (with own state, refs, or hooks): move to a folder with constructor files and an `init.lua` that returns the root component.
   - Two or more components that share the same structure and differ only by variant (label text, color token, gradient) should be collapsed into one parameterized component. Flag these as **Generic Opportunity**. This applies to both components and hooks.
   - Shared visual patterns that appear in two or more organisms within the same feature (e.g. the same icon display frame with gradient + stroke + fallback text) should be extracted to a feature-local molecule immediately. Flag these as **Duplication**.

8. **Grid and list organism extraction**
   - Templates must not build grid children inline (constructing `UIGridLayout`, cells, empty state text, and key strings inside the template file). This logic belongs in a dedicated organism.
   - Flag any template that calls `ipairs` over a list to construct keyed children directly in its render function. Suggest extracting to a `[Feature]Grid` or `[Feature]List` organism that receives data props and owns the child-building logic.
   - The organism should receive: the items array, the selected item (for highlight), the active tab (for empty state messaging), and the selection callback. The template passes these as props.

9. **Token and style hygiene**
   - Flag any `Font.new(...)` call that is not referencing a `TypographyTokens` value. Font construction belongs in tokens.
   - Flag any hardcoded `Color3.fromRGB(...)` or `Color3.new(...)` that is not referencing a color/gradient token file. Colors belong in tokens.

10. **Conditional child clarity**
    - `if X then e(...) else nil` patterns are acceptable at the top level of a component's children table.
    - Flag them as a readability concern when they appear nested **3 or more levels deep** inside the return tree. The condition should be lifted to a named local variable or a sub-function before the return.

11. **Early-return shell duplication**
    - When a component has an early-return empty state that reconstructs the same outer shell as the main return path, flag it. The shared shell should be extracted so the conditional content renders inside it rather than duplicating the frame.

---

## Output format

### summary
```
Files analyzed: N
Overall: Good | Needs improvements | High refactor opportunity
```

### findings

Group by severity:
- **High**: architecture mismatch or side effects in Presentation
- **Medium**: structure/readability issues that reduce maintainability
- **Low**: polish opportunities

For each finding include:
- `file:line`
- rule violated
- brief why
- suggested refactor

### refactor_plan

Provide an incremental plan with:
1. smallest safe step first
2. file(s) touched
3. expected benefit
4. risk level (low/medium/high)

### target_shape

Show the recommended final file split for this target, e.g.:
- `GameView.lua` (composition)
- `useGameViewController.lua` (orchestration)
- `GameHUD.lua` (presentational)

If a component should become a folder, show the folder structure:
```
ShopDetailPanel/
  init.lua          (root, composes sub-components)
  ItemIcon.lua
  QuantityControls.lua
  ActionButton.lua
```

### clean_areas

List files that already match the desired pattern (to avoid unnecessary churn).

### enforcement_check

Include whether `scripts/check-ui-animation-boundaries.ps1` would pass for the target scope.