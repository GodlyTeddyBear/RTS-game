# PRD: Path-guided boids movement (SimplePath + BoidsHelper)

## Purpose

Replace the current split between **straight-line boids advance** (no navmesh corridor) and **solo SimplePath `MoveTo` chains** with a **single hybrid**: obstacle-aware **global routes** from Roblox pathfinding, plus **local flocking** so grouped enemies spread and advance together without stacking.

This document states **intent and scope** only; implementation sequencing is decided during engineering.

---

## Background

- **Today:** [`MovementService`](../../src/ServerScriptService/Contexts/Combat/Infrastructure/Services/MovementService.lua) selects **`Path`** (via [`PathfindingHelper`](../../src/ReplicatedStorage/Utilities/PathfindingHelper.lua) + [`SimplePath`](../../src/ReplicatedStorage/Utilities/SimplePath.lua)) or **`Boids`** ([`BoidsHelper`](../../src/ReplicatedStorage/Utilities/BoidsHelper.lua)). Boids seek a shared goal on the XZ plane without waypoint corridors; path mode walks waypoints via **`Humanoid:MoveTo`** inside SimplePath.
- **Gap:** Swarms lack global obstacle avoidance; path mode lacks separation between agents.

---

## Product intent

1. **Planning:** Obtain an ordered list of **`PathWaypoint`** values (positions + **`Action`** including jump hints) using the same agent profile semantics as today (`AgentRadius`, `AgentHeight`, `AgentCanJump`, role overrides from [`CombatMovementConfig`](../../src/ReplicatedStorage/Contexts/Combat/Config/CombatMovementConfig.lua)).
2. **Execution:** Each tick, steer units **toward the active waypoint** (or lookahead on the polyline) while blending **flocking** (separation / optional cohesion-alignment) into a **single `Humanoid:Move` direction**, advancing waypoints **per entity** when close enough.
3. **Jumps:** When the active waypoint requires **`Jump`**, transition **`Humanoid`** state to jump per waypoint semantics (engine plans jumps; gameplay code **applies** them).
4. **Replanning:** When the **goal moves materially**, path computation fails, or agents drift **off-corridor**, **explicitly re-run** path computation (see **§Automatic recomputation** below)—not assumed from stock SimplePath behavior alone.

---

## Section A — SimplePath: compute and expose waypoints

### Requirement

Add a **compute-only** API on the vendored **`SimplePath`** module so callers can:

- Run **`ComputeAsync`** from the agent’s current position to a target (`Vector3` or `BasePart`), using the **same validation** as **`Run`** where applicable (e.g. minimum waypoint count, `NoPath`, humanoid freefall guards if desired).
- Populate or return **`PathWaypoint`** data (**`GetWaypoints()`** on the underlying Roblox **`Path`**) **without** starting **`Humanoid:MoveTo`**, **without** wiring **`MoveToFinished`**, and **without** treating the path as “walking until `Reached`.”

### Non-requirements (for this API)

- No obligation to duplicate **every** runtime branch of **`Run`** (e.g. visualization) unless needed for debugging parity.

### Optional follow-up

- Extend [**`PathfindingHelper`**](../../src/ReplicatedStorage/Utilities/PathfindingHelper.lua) with a **planning-only** twin of **`RunPath`** that reuses **retry / target-Y reconcile** options from [`CombatMovementConfig.PATHFINDING`](../../src/ReplicatedStorage/Contexts/Combat/Config/CombatMovementConfig.lua) but resolves when **waypoints are ready** (or rejects), instead of calling **`path:Run`**.

---

## Section B — BoidsHelper: consume SimplePath waypoints

### Requirement

Evolve [**`BoidsHelper`**](../../src/ReplicatedStorage/Utilities/BoidsHelper.lua) (or a clearly named successor module if separation is cleaner) so that:

- **Waypoint lists** come from **SimplePath compute-only** output (or equivalent **`Path:GetWaypoints()`** pipeline), not from ad hoc straight-line goals alone for this mode.
- Session/state tracks **per-entity progress** along the polyline (indices and/or distance-along-path), because separation guarantees agents **do not share** the same instantaneous footprint on the route.
- **Final strategic goal** may still align with combat **`GoalPosition`** for arrival / replan checks; waypoint sequence is the **local navigation spine**.

### Architectural note

The helper may grow to coordinate **path state + flocking + `Humanoid:Move` + jump transitions** (“fat helper”). Alternative: keep **`BoidsHelper`** purely **steering math** and place waypoint advancement in **`MovementService`**—either shape is acceptable if boundaries stay documented.

---

## Section C — Applying steering incrementally (forces)

### Meaning of “forces”

Steering **forces** are **blended direction vectors** (seek toward waypoint / path tangent, separation from neighbors, optional cohesion-alignment), **clamped and smoothed**, then applied as **`Humanoid:Move(direction)`** each tick—not Physics **`BodyForce`**, and not necessarily **`MoveTo`** every frame to a newly invented position.

### Incremental waypoint behavior

- Units **approach** each waypoint **over time**; motion is **generally toward** the corridor and the active waypoint, but **not always** a geometric straight line each frame because lateral separation curves the trace.
- **Advance** to the next waypoint when horizontal (or polyline) proximity thresholds are met; treat **`Jump`** waypoints explicitly so lookahead does **not** skip required jump actions.

### Replanning triggers (explicit)

**SimplePath does not automatically recompute** the full route when the goal moves or when geometry changes. **`ComputeAsync`** runs **once per planning invocation** (today: inside **`Run`**). Vendored **`SimplePath`** listens to **`Path.Blocked`** and may **jump** / surface **`Blocked`**—that is **not** a substitute for full dynamic replanning.

Product expectation for this system:

- Detect **goal delta**, **path failure**, **prolonged stall**, or **large deviation from corridor** and **invoke compute-only planning again**, refreshing waypoint arrays and resetting per-entity indices safely.

---

## Success criteria (draft)

- Multiple enemies with **`MovementMode`** suitable for grouping can navigate **around static obstacles** toward a moving base goal without **exclusive reliance** on post-hoc stuck jumps for primary routing.
- Units exhibit **visible spacing** (separation) without **permanent** stall in typical lane widths when weights are tuned.
- Jump waypoints from **`PathfindingService`** are honored at least at parity with current **`SimplePath:Run`** behavior for comparable agents.

## Out of scope (initial PRD)

- **ORCA / RVO**-class optimal reciprocal avoidance at massive scale.
- Client-side replication specifics beyond existing combat movement contracts.
- Replacing **`PathfindingService`** with a custom planner.

---

## References

- [`SimplePath.lua`](../../src/ReplicatedStorage/Utilities/SimplePath.lua)
- [`PathfindingHelper.lua`](../../src/ReplicatedStorage/Utilities/PathfindingHelper.lua)
- [`BoidsHelper.lua`](../../src/ReplicatedStorage/Utilities/BoidsHelper.lua)
- [`MovementService.lua`](../../src/ServerScriptService/Contexts/Combat/Infrastructure/Services/MovementService.lua)
