--!strict

--[[
	BoidsConfig - Tuning parameters for grouped MoveToPosition locomotion.

	Used by BoidsHelper to calculate server-side Vector3 steering forces that
	are applied through Humanoid:Move().
]]

return table.freeze({
	-- Radii
	SeparationRadius = 10,
	NeighborRadius = 16,

	-- Force weights
	SeparationWeight = 3.0,
	CohesionWeight = 0.2,
	AlignmentWeight = 0.8,
	TargetWeight = 2.0,

	-- Movement
	MaxSpeed = 1,
	MinSpeed = 0.1,
	MaxForce = 1,
	Smoothing = 0.15,

	-- Arrival
	ArrivalThreshold = 4,

	-- Group threshold: below this count, use SimplePath instead
	MinGroupSize = 2,
})
