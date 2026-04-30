--!strict

local ActorAdapterHook = {}

function ActorAdapterHook:Use(entity: number, hookContext: any): any?
	local registryService = hookContext.Services.CombatActorRegistryService
	if registryService == nil then
		return nil
	end

	local currentTime = hookContext.FrameContext.CurrentTime
	local services = registryService:BuildServices(entity, currentTime)
	services.ActionState = hookContext.ActionState

	return {
		Facts = registryService:BuildFacts(entity, currentTime),
		Services = services,
	}
end

return table.freeze(ActorAdapterHook)
