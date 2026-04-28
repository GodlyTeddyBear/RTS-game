--!strict

--[=[
	@class BoidsConfig
	Defines Combat-owned steering tuning for grouped enemy advance movement.
	@server
	@client
]=]
return table.freeze({
	SeparationRadius = 10,
	NeighborRadius = 16,

	SeparationWeight = 3.0,
	CohesionWeight = 0.2,
	AlignmentWeight = 0.8,
	TargetWeight = 2.0,

	MaxSpeed = 1,
	MinSpeed = 0.1,
	MaxForce = 1,
	Smoothing = 0.15,

	ArrivalThreshold = 4,
	MinGroupSize = 2,
})
