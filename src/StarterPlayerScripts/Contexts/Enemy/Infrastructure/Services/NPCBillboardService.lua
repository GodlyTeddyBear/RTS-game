--!strict

--[[
    NPCBillboardService - Manages per-NPC BillboardGui healthbar lifecycle.

    Each NPC gets one BillboardGui mounted above its head. The HP bar is driven
    by the Enemy client replication mirror, keyed by the model's revealed
    `EnemyId` attribute.

    Usage:
        local svc = NPCBillboardService.new(enemyReplicationClient)
        svc:Mount(npcId, model, displayName)
        svc:Unmount(npcId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local e = React.createElement

local NPCHealthBillboard = require(script.Parent.Parent.Parent.Presentation.NPCHealthBillboard)

local STUDS_OFFSET = Vector3.new(0, 3, 0)
local BILLBOARD_SIZE = UDim2.fromScale(4, 1)

type TBillboardEntry = {
	Gui: BillboardGui,
	Root: any,
	DisplayName: string,
	StateConnection: any,
}

local NPCBillboardService = {}
NPCBillboardService.__index = NPCBillboardService

export type TNPCBillboardService = typeof(setmetatable(
	{} :: {
		_Entries: { [string]: TBillboardEntry },
		_EnemyReplicationClient: any,
	},
	NPCBillboardService
))

function NPCBillboardService.new(enemyReplicationClient: any): TNPCBillboardService
	local self = setmetatable({}, NPCBillboardService)
	self._Entries = {}
	self._EnemyReplicationClient = enemyReplicationClient
	return self
end

local function findAttachPart(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head :: BasePart
	end
	return model.PrimaryPart
end

local function renderBillboard(root: any, displayName: string, hp: number, maxHP: number)
	root:render(e(NPCHealthBillboard, {
		DisplayName = displayName,
		HP = hp,
		MaxHP = maxHP,
	}))
end

--[[
    Mount a billboard above the NPC model. Idempotent and safe to call again
    if already mounted (no-op). Reads health from the Enemy replication mirror
    keyed by the model's revealed `EnemyId` and re-renders whenever the
    replicated health state changes.
]]
function NPCBillboardService:Mount(npcId: string, model: Model, displayName: string)
	if self._Entries[npcId] then
		return
	end

	local part = findAttachPart(model)
	if not part then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "NPCHealthBillboard"
	gui.Size = BILLBOARD_SIZE
	gui.StudsOffset = STUDS_OFFSET
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Adornee = part
	gui.Parent = part

	local root = ReactRoblox.createRoot(gui)

	local function rerender()
		local state = self._EnemyReplicationClient:GetEnemyState(npcId)
		local hp = if state ~= nil then state.CurrentHealth else 0
		local maxHP = if state ~= nil and state.MaxHealth > 0 then state.MaxHealth else 1
		gui.Enabled = state ~= nil and state.IsAlive and hp > 0
		renderBillboard(root, displayName, hp, maxHP)
	end

	local stateConnection = self._EnemyReplicationClient:ObserveEnemyStateChanged(function(changedEnemyId: string)
		if changedEnemyId ~= npcId then
			return
		end

		rerender()
	end)

	rerender()

	self._Entries[npcId] = {
		Gui = gui,
		Root = root,
		DisplayName = displayName,
		StateConnection = stateConnection,
	}
end

--[[
    Unmount the billboard for an NPC and clean up all resources.
]]
function NPCBillboardService:Unmount(npcId: string)
	local entry = self._Entries[npcId]
	if not entry then
		return
	end

	entry.StateConnection:Disconnect()
	entry.Root:unmount()
	entry.Gui:Destroy()
	self._Entries[npcId] = nil
end

return NPCBillboardService
