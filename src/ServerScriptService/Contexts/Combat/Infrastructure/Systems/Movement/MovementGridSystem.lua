--!strict

local MovementGridSystem = {}
MovementGridSystem.__index = MovementGridSystem

function MovementGridSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MovementGridSystem)
	self._entityFactory = entityFactory
	self._movementGridService = dependencies.MovementGridService
	self._worldContext = dependencies.WorldContext
	return self
end

function MovementGridSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE]
	-- WRITES: Movement.FlowGridState [AUTHORITATIVE]
	local queryResult = self._entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "MoveIntent" },
	})
	if not queryResult.success or #queryResult.value == 0 then
		return
	end

	local isReady, revision = self._movementGridService:EnsureConfigured(self._worldContext)
	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self._entityFactory:Set(entity, "FlowGridState", {
			Revision = revision,
			Ready = isReady,
			UpdatedAt = now,
			FailureReason = if isReady then nil else "FastFlowGridUnavailable",
		}, "Movement")
	end
end

return MovementGridSystem
