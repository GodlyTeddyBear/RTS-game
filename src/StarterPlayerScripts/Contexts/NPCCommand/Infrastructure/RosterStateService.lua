--!strict

--[[
    RosterStateService - Tracks all live adventurer NPCs available to the player.

    Responsibilities:
    - Maintain a RosterAtom: { [string]: Model } of all tagged adventurer NPCs
    - Seed from CollectionService on Start, then listen for added/removed events
    - Clear the roster on demand (called by controller when combat ends)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

local SelectionConfig = require(script.Parent.Parent.Config.SelectionConfig)

local RosterStateService = {}
RosterStateService.__index = RosterStateService

export type TRosterStateService = typeof(setmetatable({} :: {
	_RosterAtom: any,
	_AddedConn: RBXScriptConnection?,
	_RemovedConn: RBXScriptConnection?,
}, RosterStateService))

function RosterStateService.new(): TRosterStateService
	local self = setmetatable({}, RosterStateService)
	self._RosterAtom = Charm.atom({} :: { [string]: Model })
	self._AddedConn = nil :: RBXScriptConnection?
	self._RemovedConn = nil :: RBXScriptConnection?
	return self
end

function RosterStateService:Init(_registry: any, _name: string) end

function RosterStateService:Start()
	-- Seed from existing tagged instances
	for _, instance in CollectionService:GetTagged(SelectionConfig.NPCTag) do
		self:_TryAddNPC(instance)
	end

	-- Watch for new NPCs spawning
	self._AddedConn = CollectionService:GetInstanceAddedSignal(SelectionConfig.NPCTag):Connect(function(instance)
		self:_TryAddNPC(instance)
	end)

	-- Watch for NPCs being removed
	self._RemovedConn = CollectionService:GetInstanceRemovedSignal(SelectionConfig.NPCTag):Connect(function(instance)
		if not instance:IsA("Model") then
			return
		end
		local npcId = instance:GetAttribute("NPCId") :: string?
		if npcId then
			self:_RemoveNPC(npcId)
		end
	end)
end

function RosterStateService:_TryAddNPC(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local npcTeam = instance:GetAttribute("Team") :: string?
	local npcId = instance:GetAttribute("NPCId") :: string?
	if npcTeam ~= "Adventurer" or not npcId then
		return
	end
	local snapshot = table.clone(self._RosterAtom())
	snapshot[npcId] = instance :: Model
	self._RosterAtom(snapshot)
end

function RosterStateService:_RemoveNPC(npcId: string)
	local snapshot = table.clone(self._RosterAtom())
	snapshot[npcId] = nil
	self._RosterAtom(snapshot)
end

function RosterStateService:Clear()
	self._RosterAtom({})
end

function RosterStateService:GetRosterAtom()
	return self._RosterAtom
end

return RosterStateService
