--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local BuildRuntimeSnapshotQuery = {}
BuildRuntimeSnapshotQuery.__index = BuildRuntimeSnapshotQuery
setmetatable(BuildRuntimeSnapshotQuery, BaseQuery)

function BuildRuntimeSnapshotQuery.new()
	local self = BaseQuery.new("Entity", "BuildRuntimeSnapshot")
	return setmetatable(self, BuildRuntimeSnapshotQuery)
end
function BuildRuntimeSnapshotQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_runtimeSnapshotBuilder = "EntityRuntimeSnapshotBuilder",
	})
end

function BuildRuntimeSnapshotQuery:Execute(entity: number): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "BuildRuntimeSnapshot", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._runtimeSnapshotBuilder:BuildSnapshot(entity)
	end, self:_Label())
end

return BuildRuntimeSnapshotQuery