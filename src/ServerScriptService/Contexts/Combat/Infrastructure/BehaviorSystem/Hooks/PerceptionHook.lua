--!strict

--[=[
	@class CombatPerceptionHook
	Contributes Combat perception facts to the shared AI runtime.
	@server
]=]

local PerceptionHook = {}

function PerceptionHook:Use(entity: number, hookContext: any): any?
	local perceptionService = hookContext.Services.CombatPerceptionService
	if perceptionService == nil then
		return nil
	end

	local currentTime = hookContext.FrameContext.CurrentTime
	local facts = if hookContext.ActorType == "Structure"
		then perceptionService:BuildStructureSnapshot(entity, currentTime)
		else perceptionService:BuildSnapshot(entity, currentTime)

	return {
		Facts = facts,
	}
end

return table.freeze(PerceptionHook)
