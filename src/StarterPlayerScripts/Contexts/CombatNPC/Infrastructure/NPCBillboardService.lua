--!strict

--[[
    NPCBillboardService - Manages per-NPC BillboardGui healthbar lifecycle.

    Each NPC gets one BillboardGui mounted above its head. The HP bar is driven
    by the "CurrentHP" and "MaxHP" model attributes, which the server stamps at
    spawn and updates via NPCGameObjectSyncService on every dirty-entity sync.

    Usage:
        local svc = NPCBillboardService.new()
        svc:Mount(npcId, model, displayName)
        svc:Unmount(npcId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local e = React.createElement

local NPCHealthBillboard = require(script.Parent.Parent.Presentation.NPCHealthBillboard)

local STUDS_OFFSET = Vector3.new(0, 3, 0)
local BILLBOARD_SIZE = UDim2.fromScale(4, 1)

type TBillboardEntry = {
	Gui: BillboardGui,
	Root: any,
	DisplayName: string,
	HPConn: RBXScriptConnection,
}

local NPCBillboardService = {}
NPCBillboardService.__index = NPCBillboardService

export type TNPCBillboardService = typeof(setmetatable({} :: {
	_Entries: { [string]: TBillboardEntry },
}, NPCBillboardService))

function NPCBillboardService.new(): TNPCBillboardService
	local self = setmetatable({}, NPCBillboardService)
	self._Entries = {}
	return self
end

local function findAttachPart(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head :: BasePart
	end
	return model.PrimaryPart
end

local function renderFromAttributes(root: any, displayName: string, model: Model)
	local hp = model:GetAttribute("CurrentHP") :: number? or 0
	local maxHP = model:GetAttribute("MaxHP") :: number? or 1
	root:render(e(NPCHealthBillboard, {
		DisplayName = displayName,
		HP = hp,
		MaxHP = maxHP,
	}))
end

--[[
    Mount a billboard above the NPC model. Idempotent — safe to call again
    if already mounted (no-op). Reads CurrentHP/MaxHP from model attributes
    and re-renders whenever CurrentHP changes.
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

	-- Initial render at spawn HP
	renderFromAttributes(root, displayName, model)

	-- Re-render whenever server syncs a new CurrentHP value
	local conn = model:GetAttributeChangedSignal("CurrentHP"):Connect(function()
		local hp = model:GetAttribute("CurrentHP") :: number? or 0
		gui.Enabled = hp > 0
		renderFromAttributes(root, displayName, model)
	end)

	self._Entries[npcId] = {
		Gui = gui,
		Root = root,
		DisplayName = displayName,
		HPConn = conn,
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

	entry.HPConn:Disconnect()
	entry.Root:unmount()
	entry.Gui:Destroy()
	self._Entries[npcId] = nil
end

return NPCBillboardService
