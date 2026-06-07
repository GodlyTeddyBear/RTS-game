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

local function _NormalizeProfile(profile: any): any
	assert(type(profile) == "table", "Animation profile payload is required")

	local profileId = profile.ProfileId
	assert(type(profileId) == "string" and profileId ~= "", "Animation ProfileId is required")

	local animationSetId = profile.AnimationSetId
	assert(type(animationSetId) == "string" and animationSetId ~= "", "Animation AnimationSetId is required")

	return {
		ProfileId = profileId,
		AnimationSetId = animationSetId,
		VariantId = if type(profile.VariantId) == "string" and profile.VariantId ~= "" then profile.VariantId else "Default",
		FeatureOverrides = profile.FeatureOverrides,
	}
end

function AnimationContext:SetupEntity(entity: number, profile: any): Result.Result<boolean>
	return Result.Catch(function()
		local profileResult = self._entityContext:Set(entity, "Profile", _NormalizeProfile(profile), "Animation")
		if not profileResult.success then
			return profileResult
		end
		local actionResult = self._entityContext:Set(entity, "ActionChannels", {}, "Animation")
		if not actionResult.success then
			return actionResult
		end
		return self._entityContext:Add(entity, "EnabledTag", "Animation")
	end, "Animation:SetupEntity")
end

return AnimationContext
