--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCConfig = require(ReplicatedStorage.Contexts.NPC.Config.NPCConfig)

--[[
	NPC Discovery Service

	Discovers NPC models in the workspace via CollectionService "NPC" tag.
	Resolves NPCId from model attributes and validates against NPCConfig.
	Provides callbacks for NPC added/removed events (supports dynamic spawns).
]]

local NPC_TAG = "NPC"

local NPCDiscoveryService = {}
NPCDiscoveryService.__index = NPCDiscoveryService

function NPCDiscoveryService.new()
	local self = setmetatable({}, NPCDiscoveryService)
	self._connections = {}
	return self
end

--[=[
	Gets the NPCId for a model.
	Checks model attribute "NPCId" first, falls back to model.Name.

	@param model Model - The NPC model
	@return string? - The NPCId or nil if not found in config
]=]
function NPCDiscoveryService:GetNPCId(model: Model): string?
	local npcId = model:GetAttribute("NPCId")
	if npcId and type(npcId) == "string" and NPCConfig[npcId] then
		return npcId
	end

	-- Fallback to model name
	if NPCConfig[model.Name] then
		return model.Name
	end

	return nil
end

--[=[
	Discovers all existing NPCs and listens for new ones.
	Calls onNPCAdded for each NPC found and any future ones.
	Calls onNPCRemoved when an NPC is removed.

	@param onNPCAdded (model: Model, npcId: string) -> () - Callback for each NPC
	@param onNPCRemoved (model: Model) -> () - Callback when NPC removed
]=]
function NPCDiscoveryService:Start(
	onNPCAdded: (model: Model, npcId: string) -> (),
	onNPCRemoved: (model: Model) -> ()
)
	-- Process existing tagged instances
	for _, instance in ipairs(CollectionService:GetTagged(NPC_TAG)) do
		if instance:IsA("Model") then
			local npcId = self:GetNPCId(instance)
			if npcId then
				onNPCAdded(instance, npcId)
			else
				warn("[NPCDiscovery] NPC model has no valid NPCId:", instance:GetFullName())
			end
		end
	end

	-- Listen for new NPCs (dynamic spawns)
	local addedConn = CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			local npcId = self:GetNPCId(instance)
			if npcId then
				onNPCAdded(instance, npcId)
			else
				warn("[NPCDiscovery] NPC model has no valid NPCId:", instance:GetFullName())
			end
		end
	end)
	table.insert(self._connections, addedConn)

	-- Listen for NPC removals
	local removedConn = CollectionService:GetInstanceRemovedSignal(NPC_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			onNPCRemoved(instance)
		end
	end)
	table.insert(self._connections, removedConn)
end

function NPCDiscoveryService:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
end

return NPCDiscoveryService
