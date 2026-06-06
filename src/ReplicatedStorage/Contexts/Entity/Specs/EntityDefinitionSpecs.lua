--!strict

local EntityDefinitionSpecs = {}

local function _IsPositiveFiniteNumber(value: any): boolean
	return type(value) == "number" and value > 0 and value == value and value < math.huge
end

function EntityDefinitionSpecs.IsValid(definition: any): boolean
	if type(definition) ~= "table" then
		return false
	end
	if type(definition.DefinitionId) ~= "string" or definition.DefinitionId == "" then
		return false
	end
	if type(definition.DisplayName) ~= "string" or definition.DisplayName == "" then
		return false
	end
	if definition.Health ~= nil then
		if type(definition.Health) ~= "table" or not _IsPositiveFiniteNumber(definition.Health.Max) then
			return false
		end
	end
	if definition.AI ~= nil then
		if type(definition.AI) ~= "table" or type(definition.AI.ProfileId) ~= "string" or definition.AI.ProfileId == "" then
			return false
		end
	end
	if definition.Movement ~= nil then
		if type(definition.Movement) ~= "table" then
			return false
		end
		if not _IsPositiveFiniteNumber(definition.Movement.Speed) then
			return false
		end
		local mode = definition.Movement.Mode
		if mode ~= "Path" and mode ~= "Boids" and mode ~= "Any" and mode ~= "Direct" then
			return false
		end
	end
	return true
end

return table.freeze(EntityDefinitionSpecs)
