--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local AnimationEntitySchema = require(script.Parent.Infrastructure.Entity.AnimationEntitySchema)

local AnimationContext = Knit.CreateService({
	Name = "AnimationContext",
	Client = {},
	Modules = {},
	ExternalServices = {
		{ Name = "EntityContext", CacheAs = "_entityContext" },
	},
	Teardown = {},
})

local AnimationBaseContext = BaseContext.new(AnimationContext)

function AnimationContext:KnitInit()
	AnimationBaseContext:KnitInit()
end

function AnimationContext:KnitStart()
	AnimationBaseContext:KnitStart()
	local result = self._entityContext:RegisterFeatureSchema("Animation", AnimationEntitySchema)
	local completionResult = self._entityContext:CompleteRegistration(self.Name, result)
	if not completionResult.success then
		error(("AnimationContext failed to complete Entity registration: [%s] %s"):format(
			tostring(completionResult.type),
			tostring(completionResult.message)
		))
	end
end

function AnimationContext:SetupEntity(entity: number, profile: any, aimProfile: any?): Result.Result<boolean>
	return Result.Catch(function()
		local profileResult = self._entityContext:Set(entity, "Profile", profile, "Animation")
		if not profileResult.success then
			return profileResult
		end
		local actionResult = self._entityContext:Set(entity, "ActionState", {
			State = "",
			Looping = true,
			Revision = 0,
		}, "Animation")
		if not actionResult.success then
			return actionResult
		end
		if aimProfile ~= nil then
			local aimResult = self._entityContext:Set(entity, "AimProfile", aimProfile, "Animation")
			if not aimResult.success then
				return aimResult
			end
		end
		return self._entityContext:Add(entity, "EnabledTag", "Animation")
	end, "Animation:SetupEntity")
end

return AnimationContext
