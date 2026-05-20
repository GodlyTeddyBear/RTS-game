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
			WallPackedKeys = {},
		},
	},
	PayloadSchema = {
		EntityCount = ParallelRunner.Arg.u32(),
		DeltaTime = ParallelRunner.Arg.f32(),
		GoalGroupCellRecordStartIndex = { ParallelRunner.Arg.u32() },
		GoalGroupCellRecordCount = { ParallelRunner.Arg.u32() },
		GoalGroupCellWidthStuds = { ParallelRunner.Arg.f32() },
		GroupCellX = { ParallelRunner.Arg.i32() },
		GroupCellY = { ParallelRunner.Arg.i32() },
		CellPackedKey = { ParallelRunner.Arg.u32() },
		CellMemberStartIndex = { ParallelRunner.Arg.u32() },
		CellMemberCount = { ParallelRunner.Arg.u32() },
		CellMemberEntityIndex = { ParallelRunner.Arg.u32() },
		FlatPositionX = { ParallelRunner.Arg.f32() },
		FlatPositionY = { ParallelRunner.Arg.f32() },
		Radius = { ParallelRunner.Arg.f32() },
		FlowVelocityX = { ParallelRunner.Arg.f32() },
		FlowVelocityY = { ParallelRunner.Arg.f32() },
		PreviousVelocityX = { ParallelRunner.Arg.f32() },
		PreviousVelocityY = { ParallelRunner.Arg.f32() },
		WalkSpeed = { ParallelRunner.Arg.f32() },
		VelAlpha = { ParallelRunner.Arg.f32() },
		IsSettled = { ParallelRunner.Arg.boolean() },
	},
})

return FlowSeparationSolveOperation
