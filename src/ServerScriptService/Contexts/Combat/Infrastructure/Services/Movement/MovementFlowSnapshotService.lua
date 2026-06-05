--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local FlowFrameState = require(script.Parent.FlowFrameState)

local MovementFlowSnapshotService = {}
MovementFlowSnapshotService.__index = MovementFlowSnapshotService

function MovementFlowSnapshotService.new()
	local self = setmetatable({}, MovementFlowSnapshotService)
	self._gridService = nil
	self._recycler = nil
	self._frameState = nil
	return self
end

function MovementFlowSnapshotService:Init(registry: any, _name: string)
	self._gridService = registry:Get("MovementGridService")
	assert(self._gridService ~= nil, "MovementFlowSnapshotService missing MovementGridService in Init")
end

function MovementFlowSnapshotService:BuildWallGridSnapshot(): ({ boolean }, number, number)
	if self._gridService == nil then
		return {}, 0, 0
	end
	return self._gridService:BuildWallGridSnapshot()
end

function MovementFlowSnapshotService:GetOrCreateFrameState(): any
	if self._frameState ~= nil then
		return self._frameState
	end
	self._recycler = TableRecycler.new({
		Strict = true,
		DebugName = "CombatMovement.FlowSnapshot",
	})
	self._frameState = FlowFrameState.new(self._recycler)
	return self._frameState
end

function MovementFlowSnapshotService:Reset()
	if self._frameState ~= nil then
		self._frameState:Reset()
	end
end

function MovementFlowSnapshotService:Destroy()
	if self._frameState ~= nil then
		self._frameState:Destroy()
		self._frameState = nil
	end
	if self._recycler ~= nil then
		self._recycler:Destroy()
		self._recycler = nil
	end
end

return MovementFlowSnapshotService
