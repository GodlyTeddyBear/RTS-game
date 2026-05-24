--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)

type IssueMoveOrderRequest = UnitTypes.IssueMoveOrderRequest

local UnitRemoteClient = {}
UnitRemoteClient.__index = UnitRemoteClient

function UnitRemoteClient.new()
	local self = setmetatable({}, UnitRemoteClient)
	self._unitContext = nil
	return self
end

function UnitRemoteClient:Start()
	self._unitContext = Knit.GetService("UnitContext")
end

function UnitRemoteClient:IssueMoveOrder(request: IssueMoveOrderRequest): boolean
	assert(self._unitContext ~= nil, "UnitRemoteClient missing UnitContext")
	return self._unitContext:IssueMoveOrder(request)
end

return UnitRemoteClient
