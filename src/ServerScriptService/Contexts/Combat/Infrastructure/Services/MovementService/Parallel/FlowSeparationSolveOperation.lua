--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelRunner = require(ReplicatedStorage.Utilities.ParallelRunner)

local FlowSeparationSolveOperation = ParallelRunner.DefineJob({
	Name = "FlowSeparationSolve",
	Version = 1,
	Args = {
		TickId = ParallelRunner.Arg.u32(),
	},
	Results = {
		EntityIndex = ParallelRunner.Result.u32(),
		VelocityX = 0,
		VelocityY = 0,
		TouchedSettledNeighbor = false,
	},
	SharedSchema = {
		Scalars = {
			EntityCount = {},
			DeltaTime = {},
			CellWidthStuds = {},
			OriginX = {},
			OriginY = {},
			WallGridHalfSize = {},
			KForce = {},
			MinSeparationDistance = {},
			WallCollisionEnabled = {},
			WallCollisionAxisClampEnabled = {},
			WallCollisionCornerClampEnabled = {},
			WallCollisionUseUnitRadiusPadding = {},
			WallCollisionCellProbePaddingStuds = {},
			WallCollisionVelocityEpsilon = {},
			ClumpTouchPaddingStuds = {},
		},
		Arrays = {
			GoalGroupId = {},
			GoalGroupCellRecordStartIndex = {},
			GoalGroupCellRecordCount = {},
			GoalGroupCellWidthStuds = {},
			GroupCellX = {},
			GroupCellY = {},
			CellPackedKey = {},
			CellMemberStartIndex = {},
			CellMemberCount = {},
			CellMemberEntityIndex = {},
			FlatPositionX = {},
			FlatPositionY = {},
			Radius = {},
			FlowVelocityX = {},
			FlowVelocityY = {},
			PreviousVelocityX = {},
			PreviousVelocityY = {},
			WalkSpeed = {},
			VelAlpha = {},
			IsSettled = {},
			WallPackedKeys = {},
		},
	},
})

return FlowSeparationSolveOperation
