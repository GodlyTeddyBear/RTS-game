--!strict

local ActorAdapterHook = {}

function ActorAdapterHook:Use(entity: number, hookContext: any): any?
	local registryService = hookContext.Services.CombatActorRegistryService
	if registryService == nil then
		return nil
	end

	local currentTime = hookContext.FrameContext.CurrentTime
	local runtimeProfile = hookContext.RuntimeProfile
	local services = nil
	if hookContext.NeedsServices then
		local serviceBuildStartedAt = if runtimeProfile ~= nil then os.clock() else nil
		services = registryService:BuildServices(entity, currentTime)
		services.ActionState = hookContext.ActionState
		if runtimeProfile ~= nil then
			runtimeProfile.ServiceBuildCount += 1
			runtimeProfile.ServiceBuildMilliseconds += (os.clock() - serviceBuildStartedAt) * 1000
		end
	end

	local facts = nil
	if hookContext.NeedsFacts then
		local factBuildStartedAt = if runtimeProfile ~= nil then os.clock() else nil
		facts = registryService:BuildFacts(entity, currentTime)
		if runtimeProfile ~= nil then
			runtimeProfile.FactBuildCount += 1
			runtimeProfile.FactBuildMilliseconds += (os.clock() - factBuildStartedAt) * 1000
		end
	end

	return {
		Facts = facts,
		Services = services,
	}
end

return table.freeze(ActorAdapterHook)
