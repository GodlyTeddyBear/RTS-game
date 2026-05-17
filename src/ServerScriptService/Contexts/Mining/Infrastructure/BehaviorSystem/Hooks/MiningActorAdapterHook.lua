--!strict

local MiningActorAdapterHook = {}

function MiningActorAdapterHook:Use(entity: number, hookContext: any): any?
	local registryService = hookContext.Services.MiningActorRegistryService
	if registryService == nil then
		return nil
	end

	local currentTime = hookContext.FrameContext.CurrentTime
	local tickId = hookContext.FrameContext.TickId
	local services = registryService:BuildServices(entity, currentTime, tickId)
	services.ActionState = hookContext.ActionState

	return {
		Facts = registryService:BuildFacts(entity, currentTime),
		Services = services,
	}
end

return table.freeze(MiningActorAdapterHook)
