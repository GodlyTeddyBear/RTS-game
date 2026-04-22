# UDim Layout Rules

This document defines where `Scale` vs `Offset` should be used in frontend UI.

---

## Core Rule

Use `Scale` for layout and positioning.

- Layout dimensions and positions should be responsive (`UDim2.fromScale(...)` or scale-based `UDim2.new(...)`).
- Do not build screen structure with pixel offsets.

---

## Why

- Scale-based layout adapts across devices and resolutions.
- Offset-heavy layout drifts, clips, or misaligns on different aspect ratios.

---

## Allowed Offset Use Cases

Offset is allowed only for decorative/detail values that are intentionally pixel-based.

- `UICorner.CornerRadius` (pixel radius)
- `UIStroke.Thickness`
- Small border/shadow/outline style values
- Other visual polish values that are not responsible for structural layout

If a value controls screen structure (where elements are placed, how big they are, or how they flow), it should use scale.

---

## Anti-Pattern

**Wrong (layout by offset):**
```lua
Size = UDim2.fromOffset(420, 260),
Position = UDim2.new(0, 200, 0, 120),
```

**Correct (layout by scale):**
```lua
Size = UDim2.fromScale(0.32, 0.24),
Position = UDim2.fromScale(0.5, 0.5),
AnchorPoint = Vector2.new(0.5, 0.5),
```

---

## Enforcement Checklist

- [ ] No frame/container layout uses `UDim2.fromOffset(...)`.
- [ ] Positional layout avoids offset-based `UDim2.new(0, px, 0, px)` patterns.
- [ ] Offset is limited to decorative pixel constants (corner radius, stroke thickness, etc.).
