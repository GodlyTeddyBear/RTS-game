--!strict

local EntityAIActionStateService = {}
EntityAIActionStateService.__index = EntityAIActionStateService

function EntityAIActionStateService.new()
	return setmetatable({}, EntityAIActionStateService)
end

function EntityAIActionStateService:Init(_registry: any, _name: string)
	return
end

function EntityAIActionStateService:BuildDefault(timestamp: number): any
	return {
		Status = "Idle",
		ActionName = nil,
		StartedAt = nil,
		UpdatedAt = timestamp,
		ErrorCode = nil,
	}
end

function EntityAIActionStateService:MapFromCombatState(combatActionState: any, timestamp: number): any
	if type(combatActionState) ~= "table" then
		return self:BuildDefault(timestamp)
	end

	return {
		Status = combatActionState.ActionState or "Idle",
		ActionName = combatActionState.CurrentActionId or combatActionState.PendingActionId,
		StartedAt = combatActionState.StartedAt,
		UpdatedAt = timestamp,
		ErrorCode = nil,
	}
end

return EntityAIActionStateService
