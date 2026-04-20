--!strict

--[[
    PickTargetService - Owns pick-target mode lifecycle.

    Responsibilities:
    - Enter/exit pick-target mode
    - Track mouse hover over enemies each frame (red highlight)
    - Confirm target with E (black highlight + fire command)
    - Manage PickTargetAtom for UI reactivity
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

local PickTargetService = {}
PickTargetService.__index = PickTargetService

export type TPickTargetService = typeof(setmetatable({} :: {
	_IsActive: boolean,
	_PickTargetAtom: any,
	_HoverConnection: RBXScriptConnection?,
	_SelectionService: any,
	_VisualService: any,
}, PickTargetService))

function PickTargetService.new(): TPickTargetService
	local self = setmetatable({}, PickTargetService)
	self._IsActive = false
	self._PickTargetAtom = Charm.atom(false)
	self._HoverConnection = nil
	self._SelectionService = nil :: any
	self._VisualService = nil :: any
	return self
end

function PickTargetService:Init(registry: any, _name: string)
	self._SelectionService = registry:Get("SelectionService")
	self._VisualService = registry:Get("SelectionVisualService")
end

function PickTargetService:IsActive(): boolean
	return self._IsActive
end

function PickTargetService:GetPickTargetAtom()
	return self._PickTargetAtom
end

function PickTargetService:Enter()
	if self._IsActive then
		self:Exit()
	end

	self._VisualService:ClearAllTargetedHighlights()

	self._IsActive = true
	self._PickTargetAtom(true)

	if self._HoverConnection then
		self._HoverConnection:Disconnect()
	end
	self._HoverConnection = RunService.RenderStepped:Connect(function()
		self:_UpdateHover()
	end)
end

function PickTargetService:Exit()
	if not self._IsActive then
		return
	end

	self._IsActive = false
	self._PickTargetAtom(false)

	if self._HoverConnection then
		self._HoverConnection:Disconnect()
		self._HoverConnection = nil
	end

	self._VisualService:HideEnemyHighlight()
end

function PickTargetService:_UpdateHover()
	local screenPos = UserInputService:GetMouseLocation()
	local npcId, model, npcTeam = self._SelectionService:RaycastForNPC(screenPos)

	if npcId and model and npcTeam == "Enemy" then
		local currentId = self._VisualService:GetHighlightedEnemyId()
		if currentId ~= npcId then
			self._VisualService:ShowEnemyHighlight(npcId, model)
		end
	else
		self._VisualService:HideEnemyHighlight()
	end
end

--[[
    Confirm the currently hovered enemy as a target.
    Returns (targetNPCId, model) if an enemy is hovered, or (nil, nil) if not.
    Applies the persistent black highlight and clears the hover highlight.
]]
function PickTargetService:ConfirmTarget(): (string?, Model?)
	local targetId = self._VisualService:GetHighlightedEnemyId()
	if not targetId then
		return nil, nil
	end

	local screenPos = UserInputService:GetMouseLocation()
	local _, model, _ = self._SelectionService:RaycastForNPC(screenPos)

	if model then
		self._VisualService:ShowTargetedHighlight(targetId, model)
	end

	self._VisualService:HideEnemyHighlight()
	return targetId, model
end

return PickTargetService
