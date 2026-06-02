--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local MovementActorSetupService = {}
MovementActorSetupService.__index = MovementActorSetupService

function MovementActorSetupService.new()
	return setmetatable({}, MovementActorSetupService)
end

function MovementActorSetupService:Setup(entityContext: any, entity: number, profile: any): Result.Result<boolean>
	return Result.Catch(function()
		Result.Ensure(type(entity) == "number", "InvalidMovementEntity", "Movement actor entity must be a number")
		Result.Ensure(type(profile) == "table", "InvalidMovementProfile", "Movement actor profile must be a table")
		Result.Ensure(profile.ApplyMode == "Humanoid" or profile.ApplyMode == "Kinematic", "InvalidMovementApplyMode", "Movement actor apply mode is invalid")
		Result.Ensure(type(profile.MoveSpeed) == "number" and profile.MoveSpeed >= 0, "InvalidMovementSpeed", "Movement actor speed must be non-negative")

		Result.Try(entityContext:Set(entity, "ActorProfile", {
			ApplyMode = profile.ApplyMode,
			DefaultMode = profile.DefaultMode or "Path",
			GoalReachedDistance = profile.GoalReachedDistance or 4,
			AgentParams = profile.AgentParams,
		}, "Movement"))
		Result.Try(entityContext:Set(entity, "SpeedState", {
			BaseSpeed = profile.MoveSpeed,
			CurrentSpeed = profile.MoveSpeed,
		}, "Movement"))
		return Result.Ok(true)
	end, "Combat:SetupMovementActor")
end

return MovementActorSetupService
