--!strict

--[[
    SelectionStateService - Owns NPC selection state and atom mutations.

    Responsibilities:
    - Track which NPCs are selected (ids, models, health connections)
    - Mutate SelectionAtom and RecentOrdersAtom (centralized atom writes)
    - Coordinate with SelectionVisualService for highlight lifecycle
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

local SelectionConfig = require(script.Parent.Parent.Config.SelectionConfig)
local NPCCommandTypes = require(script.Parent.Parent.Types.NPCCommandTypes)

local MAX_RECENT_ORDERS = 5

local SelectionStateService = {}
SelectionStateService.__index = SelectionStateService

export type TSelectionStateService = typeof(setmetatable({} :: {
	_SelectedNPCIds: { [string]: boolean },
	_SelectedModels: { [string]: Model },
	_HealthConnections: { [string]: RBXScriptConnection },
	_SelectionAtom: any,
	_RecentOrdersAtom: any,
	_VisualService: any,
	_RosterService: any,
}, SelectionStateService))

function SelectionStateService.new(): TSelectionStateService
	local self = setmetatable({}, SelectionStateService)
	self._SelectedNPCIds = {}
	self._SelectedModels = {}
	self._HealthConnections = {}
	self._SelectionAtom = Charm.atom({} :: { [string]: boolean })
	self._RecentOrdersAtom = Charm.atom({} :: { NPCCommandTypes.TRecentOrder })
	self._VisualService = nil :: any
	return self
end

function SelectionStateService:Init(registry: any, _name: string)
	self._VisualService = registry:Get("SelectionVisualService")
	self._RosterService = registry:Get("RosterStateService")
end

function SelectionStateService:Select(npcId: string, model: Model)
	if self._SelectedNPCIds[npcId] then
		return
	end

	self._SelectedNPCIds[npcId] = true
	self._SelectedModels[npcId] = model
	self._VisualService:ShowSelection(npcId, model)

	local snapshot = table.clone(self._SelectionAtom())
	snapshot[npcId] = true
	self._SelectionAtom(snapshot)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self._HealthConnections[npcId] = humanoid.HealthChanged:Connect(function()
			local s = table.clone(self._SelectionAtom())
			self._SelectionAtom(s)
		end)
	end
end

function SelectionStateService:Deselect(npcId: string)
	if not self._SelectedNPCIds[npcId] then
		return
	end

	self._SelectedNPCIds[npcId] = nil
	self._SelectedModels[npcId] = nil
	self._VisualService:HideSelection(npcId)

	local conn = self._HealthConnections[npcId]
	if conn then
		conn:Disconnect()
		self._HealthConnections[npcId] = nil
	end

	local snapshot = table.clone(self._SelectionAtom())
	snapshot[npcId] = nil
	self._SelectionAtom(snapshot)
end

function SelectionStateService:Clear()
	for npcId, _ in self._SelectedNPCIds do
		self:Deselect(npcId)
	end
end

function SelectionStateService:IsSelected(npcId: string): boolean
	return self._SelectedNPCIds[npcId] == true
end

function SelectionStateService:GetSelectedIds(): { string }
	local ids = {}
	for npcId, _ in self._SelectedNPCIds do
		table.insert(ids, npcId)
	end
	return ids
end

function SelectionStateService:GetSelectedModels(): { [string]: Model }
	return self._SelectedModels
end

function SelectionStateService:GetSelectionAtom()
	return self._SelectionAtom
end

function SelectionStateService:GetRecentOrdersAtom()
	return self._RecentOrdersAtom
end

function SelectionStateService:SelectAll()
	local allNPCs = CollectionService:GetTagged(SelectionConfig.NPCTag)
	for _, instance in allNPCs do
		if instance:IsA("Model") then
			local npcTeam = instance:GetAttribute("Team") :: string?
			local npcId = instance:GetAttribute("NPCId") :: string?
			if npcTeam == "Adventurer" and npcId then
				self:Select(npcId, instance)
			end
		end
	end
end

-- Toggle selection for a roster unit (additive — does not clear other selections)
function SelectionStateService:ToggleRosterUnit(npcId: string)
	if self:IsSelected(npcId) then
		self:Deselect(npcId)
		return
	end
	local model = self._SelectedModels[npcId]
	if not model and self._RosterService then
		local roster = self._RosterService:GetRosterAtom()()
		model = roster[npcId]
	end
	if model then
		self:Select(npcId, model)
	end
end

function SelectionStateService:SelectOnly(npcId: string)
	local model = self._SelectedModels[npcId]
	if not model and self._RosterService then
		local roster = self._RosterService:GetRosterAtom()()
		model = roster[npcId]
	end
	if not model then
		return
	end
	self:Clear()
	self:Select(npcId, model)
end

function SelectionStateService:RecordRecentOrder(commandType: string)
	local npcType = "NPC"
	for id, _ in self._SelectedNPCIds do
		local model = self._SelectedModels[id]
		if model then
			npcType = model:GetAttribute("NPCType") :: string? or "NPC"
			break
		end
	end

	local orders = table.clone(self._RecentOrdersAtom())
	table.insert(orders, 1, {
		NPCType = npcType,
		CommandType = commandType,
		IssuedAt = os.clock(),
	})
	while #orders > MAX_RECENT_ORDERS do
		table.remove(orders, #orders)
	end
	self._RecentOrdersAtom(orders)
end

return SelectionStateService
