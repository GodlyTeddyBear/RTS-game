--!strict

local RunFailureRequestSystem = {}
RunFailureRequestSystem.__index = RunFailureRequestSystem

function RunFailureRequestSystem.new(entityFactory: any, runContext: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_runContext = runContext,
	}, RunFailureRequestSystem)
end

function RunFailureRequestSystem:Run()
	local result = self._entityFactory:Query({ FeatureName = "Run", Keys = { "FailureRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function RunFailureRequestSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "FailureRequest", "Run")
	if type(request) ~= "table" then
		self:_Processed(requestEntity)
		return
	end

	if self._runContext ~= nil and type(self._runContext.NotifyRunFailed) == "function" then
		self._runContext:NotifyRunFailed()
	end

	self:_Processed(requestEntity)
end

function RunFailureRequestSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function RunFailureRequestSystem:_Processed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Run")
	self._entityFactory:MarkEntityForDestruction(entity)
end

return RunFailureRequestSystem
