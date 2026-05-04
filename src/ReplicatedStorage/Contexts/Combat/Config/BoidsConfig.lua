--!strict

--[=[
	@class BoidsConfig
	Tuning for combat boids-style advance: path waypoints + flock separation, corridor lanes, per-entity arrival ring.
	Each field below notes Increase vs Decrease tradeoffs. See ReplicatedStorage.Utilities.BoidsHelper for application.

	@server
	@client
]=]
return table.freeze({
	-- SeparationRadius (studs, 0+): XZ distance within which another session member contributes repulsion.
	-- Increase: repulsion starts farther away, wider personal bubble, less packing (can crowd narrow nav).
	-- Decrease: only very close agents push apart, tighter squads, more overlap risk.
	SeparationRadius = 4,

	-- NeighborRadius (studs, 0+): Only for cohesion/alignment sampling. No effect while both CohesionWeight and AlignmentWeight are 0.
	-- Increase: (if those weights > 0) larger flock used for center and velocity averaging.
	-- Decrease: (if those weights > 0) only nearer agents count.
	NeighborRadius = 5,

	-- SeparationMinDistanceEpsilon (studs, 0+): Under this XZ gap, separation uses a seeded direction (avoids singularity at zero distance).
	-- Increase: overlap handling activates at larger separations; seeded push magnitude scales roughly as 1/eps (so larger eps often means gentler overlap nudge).
	-- Decrease: geometric repulsion is used until agents are closer; very small values can make overlap pushes stronger when the seeded branch triggers.
	SeparationMinDistanceEpsilon = 0.1,

	-- CorridorLaneOffsetStuds (studs, 0+): Peak lateral offset from path; seek aims here. Separation/min-forward use waypoint/tangent.
	-- Increase: wider side-by-side formation along route; risk clipping tight corners on navmesh.
	-- Decrease: closer to centerline; 0 = no lateral offset, walk waypoint spine.
	CorridorLaneOffsetStuds = 5,

	-- GoalSlotRingRadius (studs, 0+): arrivalPosition = goal + random point on XZ circle of this radius (per entity).
	-- Increase: finish farther from nominal goal, more spacing between end positions.
	-- Decrease: end cluster tighter around goal; 0 = everyone targets exact goal (no ring).
	GoalSlotRingRadius = 10,

	-- SeparationWeight (0+): Perpendicular separation strength in the weighted blend.
	-- Increase: harder anti-stack, more side-stepping and neighbor chain reactions; tune with TargetWeight.
	-- Decrease: weaker dodge, smoother ranks, more stacking.
	SeparationWeight = 6,

	-- CohesionWeight (0+): Pull toward neighborhood center (NeighborRadius). 0 = off.
	-- Increase: swarm tightens toward local average position; fights separation/spread.
	-- Decrease: weaker clumping pull.
	CohesionWeight = 0,

	-- AlignmentWeight (0+): Match neighbors' velocities (NeighborRadius). 0 = off.
	-- Increase: headings sync more; can amplify group waves.
	-- Decrease: less velocity matching.
	AlignmentWeight = 0,

	-- TargetWeight (0+): Seek strength toward steeringTarget (offset waypoint or arrival slot).
	-- Increase: path/goal pursuit dominates, separation relatively weaker in blend.
	-- Decrease: seek weaker; risk drift or slow approach if too low versus separation.
	TargetWeight = 2,

	-- SeparationFalloffExponent (0+): Edge-softening for separation; contribution scales as "(1 - dist/radius)^exponent". 0 = uniform inside radius (legacy).
	-- Increase: gentler pushes until agents are very close; reduces ping-pong in packed groups.
	-- Decrease: flatter response toward the separation radius; 0 disables falloff.
	SeparationFalloffExponent = 2,

	-- SeparationLateralRawCap (0+): Cap magnitude of averaged lateral separation direction before steering smoothing. 0 = no cap.
	-- Increase: allows stronger sideways dodge impulse before cap.
	-- Decrease: limits lateral separation impulse; helps stop orbit loops when combined with TargetWeight.
	SeparationLateralRawCap = 1,

	-- OrbitEscapeEnabled: After OrbitEscapeMinTicks with low forward motion and high lateral motion along the path, blend a forward nudge along path progress.
	OrbitEscapeEnabled = true,

	-- OrbitEscapeMinTicks: Combat ticks of mostly lateral motion before applying escape nudge.
	OrbitEscapeMinTicks = 1,

	-- OrbitEscapeAlongThreshold: Treat forward (along progress) speed as low below this (steering magnitude scale, comparable to MaxSpeed).
	OrbitEscapeAlongThreshold = 0.1,

	-- OrbitEscapeLateralThreshold: Lateral magnitude must exceed this to count as orbiting.
	OrbitEscapeLateralThreshold = 0.1,

	-- OrbitEscapeBiasScale: Forward nudge strength as a fraction of MaxSpeed blended in when escape fires.
	OrbitEscapeBiasScale = 0.8,

	-- MinForwardAlongProgress (0+): Floor on motion along path progress axis after blend (waypoint direction, else tangent). Same scale as MaxSpeed.
	-- Increase: more mandatory forward progress, less pure orbit; can feel rigid. 0 = disabled.
	-- Decrease: allows more lateral-only motion before floor kicks in.
	MinForwardAlongProgress = 0.88,

	-- NoBackwardTowardWaypointEnabled: If true, strip seek-backwards motion (XZ): blended steering cannot move opposite the vector toward steeringTarget (lane offset or waypoint). Mitigates separation-driven orbiting/backpedal.
	NoBackwardTowardWaypointEnabled = true,

	-- MinAlongTowardSeek (0+): After no-backward clamp, minimum forward component along (steeringTarget - position). 0 = only forbid backward (net along >= 0). Small positive values force a little forward creep when neighbors push sideways.
	MinAlongTowardSeek = 0,

	-- MaxSpeed (0-1): Upper bound on blended steering vector magnitude (XZ).
	-- Increase: allows stronger combined steering output per tick (still limited by MaxForce/Humanoid).
	-- Decrease: caps how aggressive the net Move direction can be.
	MaxSpeed = 1,

	-- MinSpeed (0+): Output below this magnitude becomes zero (idle).
	-- Increase: easier to snap to idle, less crawling; too high causes stutter-stop.
	-- Decrease: smaller motions still applied before idle cutoff.
	MinSpeed = 0.08,

	-- MaxForce (0+): Per-tick steering acceleration limit inside steerFromDesired.
	-- Increase: snappier heading corrections each frame.
	-- Decrease: slower turn rate, smoother-looking rotation.
	MaxForce = 0.9,

	-- Smoothing (0-1): Blend new clamped steering toward previous steering.
	-- Increase: follows target behavior faster; can add jitter if inputs oscillate.
	-- Decrease: smoother, heavier inertia, slower to react.
	Smoothing = 0.45,

	-- ArrivalThreshold (studs, 0+): Success when past final waypoint and within this XZ distance of own arrivalPosition (goal + slot).
	-- Increase: declare arrived farther from slot, faster completion, looser end pose.
	-- Decrease: must hug personal slot closer; longer finish shimmy possible.
	ArrivalThreshold = 2.75,

	-- WaypointArrivalThreshold (studs, 0+): Mark current PathWaypoint reached when within this XZ distance (may advance multiple per tick).
	-- Increase: chew through path faster, cut corners, may skip hugging nodes.
	-- Decrease: stay near each waypoint longer, stricter corridor, slower index advancement.
	WaypointArrivalThreshold = 2,

	-- JumpWaypointArrivalThreshold (studs, 0+): Stricter consume + jump approach radius for PathWaypointAction.Jump only.
	-- Larger than WaypointArrivalThreshold helps boids match SimplePath-style clears (jump legs often need a wider XZ gate than Walk).
	-- Omit or 0: falls back to WaypointArrivalThreshold.
	JumpWaypointArrivalThreshold = 5,

	-- JumpWhenStuckEnabled: If true, while the active waypoint is Jump, fire an extra jump after JumpStuckMinTicks with XZ motion below JumpStuckEpsilonStuds (SimplePath JUMP_WHEN_STUCK analogue).
	JumpWhenStuckEnabled = true,

	-- JumpStuckEpsilonStuds (studs, 0+): Max XZ displacement between samples to count as "stuck" for JumpWhenStuck.
	JumpStuckEpsilonStuds = 0.05,

	-- JumpStuckMinTicks: Consecutive stuck samples before triggering JumpWhenStuck (combat ticks, not Heartbeat).
	JumpStuckMinTicks = 3,

	-- JumpUseMoveTo: If true, Jump waypoints use Humanoid:MoveTo(Position) for that leg (jump first, then MoveTo) until MoveToFinished (SimplePath move() parity).
	JumpUseMoveTo = true,

	-- JumpMoveToTimeoutSeconds (0+): Abort a stuck Jump MoveTo leg after this many seconds (disconnect, resume boids Move). 0 = no timeout.
	JumpMoveToTimeoutSeconds = 2,

	-- JumpMoveToStuckEnabled: If true, end Jump MoveTo early when XZ displacement stays below JumpMoveToStuckEpsilonStuds for JumpMoveToStuckMinTicks (crowd blocked).
	JumpMoveToStuckEnabled = true,

	-- JumpMoveToStuckEpsilonStuds (studs, 0+): Max XZ movement between combat ticks to count as stuck during Jump MoveTo.
	JumpMoveToStuckEpsilonStuds = 0.05,

	-- JumpMoveToStuckMinTicks: Consecutive stuck combat ticks before aborting Jump MoveTo.
	JumpMoveToStuckMinTicks = 4,

	-- SeparationCrowdingFactor (0+): Sublinear separation dampening when many session neighbors overlap SeparationRadius; raw separation scales by 1/(1 + factor * (neighborCount - 1)). 0 = off.
	SeparationCrowdingFactor = 0.14,

	-- PathRecomputeGoalDelta (studs, 0+): Min XZ goal movement (after cooldown) to schedule a new path compute.
	-- Increase: replan less often; cheap but path lags moving goals.
	-- Decrease: more reactive replanning; more path compute cost.
	PathRecomputeGoalDelta = 1,

	-- PathRecomputeCooldownSeconds (0+): Per-entity throttle between path recomputes.
	-- Increase: fewer ComputeAsync bursts; path may stay stale longer during motion.
	-- Decrease: fresher routes; more server load spikes.
	PathRecomputeCooldownSeconds = 0.15,

	-- PathRefreshIntervalSeconds (0+): If > 0, schedules an async path refresh at least this often (wall clock since last successful compute), even when the goal barely moves. Uses ComputeWaypointsPromise so combat ticks never yield. 0 = off (only goal-delta / replenish / Blocked / no-waypoint replans).
	PathRefreshIntervalSeconds = 6,

	-- PathReplenishEnabled: If true, after PathReplenishMinTicks with XZ displacement below PathReplenishEpsilonStuds while a path is still active (and not near arrival), clear waypoints and force an immediate replan on the same combat tick.
	PathReplenishEnabled = true,

	-- PathReplenishEpsilonStuds (studs, 0+): Max XZ movement between samples to count as no progress for replenishment.
	PathReplenishEpsilonStuds = 0.2,

	-- PathReplenishMinTicks: Consecutive low-motion combat ticks before replenishing the path.
	PathReplenishMinTicks = 4,

	-- PathReplenishMinArrivalDistance (studs): Radius around each unit's arrival slot (same as BoidsHelper arrivalPosition: goal + personal GoalSlotRing offset) where path replenishment is disabled. Stops "stuck / low XZ motion" replans while agents are finishing the approach, which would thrash paths and goals. Use 0 or omit to apply the built-in default in code: max(1.5 * ArrivalThreshold, 5).
	PathReplenishMinArrivalDistance = 0,

	-- EnginePathBlockedReplanCooldownSeconds (0+): Min seconds between Path.Blocked-driven replans on the boids watch path (throttles burst events).
	EnginePathBlockedReplanCooldownSeconds = 0.12,

	-- MinGroupSize (int, 1+): With MovementMode Any, need at least this many eligible entities to prefer boids over Path.
	-- Increase: small packs use Path only, boids only for bigger groups.
	-- Decrease: smaller groups still get boids flocking.
	MinGroupSize = 2,
})
