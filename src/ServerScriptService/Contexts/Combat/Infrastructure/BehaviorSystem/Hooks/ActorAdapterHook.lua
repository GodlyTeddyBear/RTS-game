--!strict

local ActorAdapterHook = {}

function ActorAdapterHook:Use(entity: number, hookContext: any): any?
	local registryService = hookContext.Services.CombatActorRegistryService
	if registryService == nil then
		return nil
	end

	local currentTime = hookContext.FrameContext.CurrentTime

	return {
		Facts = registryService:BuildFacts(entity, currentTime),
		Services = registryService:BuildServices(entity, currentTime),
	}
end

return table.freeze(ActorAdapterHook)
