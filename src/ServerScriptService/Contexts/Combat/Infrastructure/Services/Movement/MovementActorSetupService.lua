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
		Result.Ensure(
			profile.GoalDistanceMode == nil
				or profile.GoalDistanceMode == "Horizontal"
				or profile.GoalDistanceMode == "ThreeDimensional",
			"InvalidGoalDistanceMode",
			"Movement actor goal distance mode is invalid"
		)
		Result.Ensure(
			profile.GroundGoals == nil or type(profile.GroundGoals) == "boolean",
			"InvalidGroundGoals",
			"Movement actor GroundGoals must be a boolean"
		)

		local isHumanoid = profile.ApplyMode == "Humanoid"
		if isHumanoid then
			local binding = Result.Try(entityContext:Get(entity, "ModelBinding", "Entity"))
			Result.Ensure(
				type(binding) == "table" and binding.SetupProfileId == "HumanoidActor",
				"InvalidHumanoidMovementBinding",
				"Humanoid movement actors require the HumanoidActor model binding profile"
			)
		end

		Result.Try(entityContext:Set(entity, "ActorProfile", {
			ApplyMode = profile.ApplyMode,
			GoalReachedDistance = profile.GoalReachedDistance or 4,
			GoalDistanceMode = profile.GoalDistanceMode or (if isHumanoid then "Horizontal" else "ThreeDimensional"),
			GroundGoals = if profile.GroundGoals ~= nil then profile.GroundGoals == true else isHumanoid,
			AgentParams = profile.AgentParams,
		}, "Movement"))
		Result.Try(entityContext:Set(entity, "SpeedState", {
			BaseSpeed = profile.MoveSpeed,
			CurrentSpeed = profile.MoveSpeed,
		}, "Movement"))
		Result.Try(entityContext:Set(entity, "TransformProjection", {
			Enabled = not isHumanoid,
		}, "Entity"))
		Result.Try(entityContext:Set(entity, "TransformPoll", {
			Enabled = isHumanoid,
		}, "Entity"))
		return Result.Ok(true)
	end, "Combat:SetupMovementActor")
end

return MovementActorSetupService
