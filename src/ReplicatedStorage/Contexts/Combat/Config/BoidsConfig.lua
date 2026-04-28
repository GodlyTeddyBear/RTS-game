--!strict

--[=[
	@class BoidsConfig
	Defines Combat-owned steering tuning for grouped enemy advance movement.
	@server
	@client
]=]
return table.freeze({
	-- Range: 0+ studs. Larger values make enemies push away from farther neighbors.
	SeparationRadius = 2,
	-- Range: 0+ studs. Larger values make cohesion and alignment sample a wider group.
	NeighborRadius = 2,

	-- Range: 0+. 0 disables push-away; higher values reduce stacking more aggressively.
	SeparationWeight = 1,
	-- Range: 0+. 0 disables grouping pull; higher values tighten the local swarm.
	CohesionWeight = 0.2,
	-- Range: 0+. 0 disables direction matching; higher values copy nearby movement more strongly.
	AlignmentWeight = 0,
	-- Range: 0+. Higher values make the shared goal dominate neighbor forces.
	TargetWeight = 2.0,

	-- Range: 0-1 for Humanoid:Move input. Higher values allow full-speed steering.
	MaxSpeed = 1,
	-- Range: 0-MaxSpeed. Keep below smoothed output or boids may never begin moving.
	MinSpeed = 0.1,
	-- Range: 0+. Lower values soften turns; higher values allow sharper direction changes.
	MaxForce = 1,
	-- Range: 0-1. Lower values smooth more; higher values respond faster but can jitter.
	Smoothing = 0.15,

	-- Range: 0+ studs. Lower values require enemies to get closer before advance succeeds.
	ArrivalThreshold = 2,
	-- Range: 1+ enemies. Minimum compatible group size before boids should be selected.
	MinGroupSize = 2,
})
