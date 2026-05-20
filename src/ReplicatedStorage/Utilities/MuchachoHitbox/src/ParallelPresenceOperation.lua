--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelRunner = require(ReplicatedStorage.Utilities.ParallelRunner)

local OPERATION_NAME = "MuchachoHitboxPresence"

local ParallelPresenceOperation = ParallelRunner.DefineJob({
	Name = OPERATION_NAME,
	Version = 1,
	Args = {
		DispatchSerial = ParallelRunner.Arg.u32(),
	},
	Results = {
		HitboxIndex = ParallelRunner.Result.u32(),
		HasAny = false,
	},
	PayloadSchema = {
		QueryCFrames = { ParallelRunner.Arg.lossyCFrame() },
		Sizes = { ParallelRunner.Arg.vector3() },
		ShapeIds = { ParallelRunner.Arg.u32() },
		FilterTokens = { ParallelRunner.Arg.string16() },
	},
})

return table.freeze(ParallelPresenceOperation)
