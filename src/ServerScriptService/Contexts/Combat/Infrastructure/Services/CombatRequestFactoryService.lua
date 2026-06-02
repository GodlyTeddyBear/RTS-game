--!strict

local CombatRequestFactoryService = {}
CombatRequestFactoryService.__index = CombatRequestFactoryService

function CombatRequestFactoryService.new()
	return setmetatable({}, CombatRequestFactoryService)
end

function CombatRequestFactoryService:Create(entityFactory: any, archetypeName: string, componentKey: string, payload: any)
	local request = table.clone(payload)
	request.CreatedAt = if type(request.CreatedAt) == "number" then request.CreatedAt else os.clock()
	return entityFactory:CreateFromArchetype(archetypeName, {
		[componentKey] = request,
	})
end

return CombatRequestFactoryService
