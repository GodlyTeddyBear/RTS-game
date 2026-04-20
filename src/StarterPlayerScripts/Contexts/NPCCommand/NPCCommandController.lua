--!strict

--[[
    NPCCommandController - Client-side Knit controller for RTS-style NPC selection
    and command input.

    Thin orchestrator that delegates to infrastructure services:
    - SelectionStateService: selection state + atom mutations
    - SelectionVisualService: highlight and ground circle visuals
    - SelectionService: raycasting for NPC/ground hits
    - CommandInputService: right-click command handling
    - DragBoxService: drag-selection rectangle UI
    - PickTargetService: pick-target mode (hover + confirm)

    Selection state is purely client-side — the server never knows which NPCs
    are "selected", only what commands the player issues.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local SelectionService = require(script.Parent.Infrastructure.SelectionService)
local SelectionVisualService = require(script.Parent.Infrastructure.SelectionVisualService)
local SelectionStateService = require(script.Parent.Infrastructure.SelectionStateService)
local RosterStateService = require(script.Parent.Infrastructure.RosterStateService)
local CommandInputService = require(script.Parent.Infrastructure.CommandInputService)
local DragBoxService = require(script.Parent.Infrastructure.DragBoxService)
local PickTargetService = require(script.Parent.Infrastructure.PickTargetService)

local DRAG_THRESHOLD = 5

-- Strategy table: panel command type → server command type
local COMMAND_MAP: { [string]: string } = {
	ATTACK = "AttackNearest",
	MOVE = "MoveToPosition",
	HOLD = "HoldPosition",
}

local NPCCommandController = Knit.CreateController({
	Name = "NPCCommandController",
})

function NPCCommandController:KnitInit()
	-- Drag state (kept here since it's input-routing concern)
	self._IsDragging = false
	self._DragStart = nil :: Vector2?

	-- Registry for local sub-services
	self._Registry = Registry.new("Client")
	self._Registry:Register("SelectionService", SelectionService.new(), "Infrastructure")
	self._Registry:Register("SelectionVisualService", SelectionVisualService.new(), "Infrastructure")
	self._Registry:Register("SelectionStateService", SelectionStateService.new(), "Infrastructure")
	self._Registry:Register("RosterStateService", RosterStateService.new(), "Infrastructure")
	self._Registry:Register("DragBoxService", DragBoxService.new(), "Infrastructure")
	self._Registry:Register("PickTargetService", PickTargetService.new(), "Application")
	self._Registry:Register("CommandInputService", CommandInputService.new(), "Application")

	-- Init all (wires inter-service dependencies)
	self._Registry:InitAll()

	-- Cache refs
	self._SelectionService = self._Registry:Get("SelectionService")
	self._SelectionVisualService = self._Registry:Get("SelectionVisualService")
	self._SelectionState = self._Registry:Get("SelectionStateService")
	self._RosterState = self._Registry:Get("RosterStateService")
	self._DragBoxService = self._Registry:Get("DragBoxService")
	self._PickTargetService = self._Registry:Get("PickTargetService")
	self._CommandInputService = self._Registry:Get("CommandInputService")

	-- Active input mode (set by UI option selection)
	self._ActiveMode = nil :: string?

	-- Cross-context deps (populated in KnitStart)
	self._PlayerCommandService = nil :: any
	self._QuestStateAtom = nil :: any
	self._WasInCombat = false
end

function NPCCommandController:KnitStart()
	-- Resolve cross-context deps
	self._PlayerCommandService = Knit.GetService("PlayerCommandContext")

	local QuestController = Knit.GetController("QuestController")
	self._QuestStateAtom = QuestController and QuestController:GetQuestStateAtom() or nil

	-- Start sub-services in category order (Application runs after Infrastructure)
	self._Registry:StartOrdered({ "Infrastructure", "Application" })

	-- Wire death events for deselection
	local CombatNPCController = Knit.GetController("CombatNPCController")
	local dispatcher = CombatNPCController and CombatNPCController:GetEventDispatcher()
	if dispatcher then
		dispatcher:OnEvent("Died", function(event: any, _model: Model)
			local npcId = event.TargetNPCId
			if npcId and self._SelectionState:IsSelected(npcId) then
				self._SelectionState:Deselect(npcId)
			end
		end)
	end

	self:_BindInput()
	self:_WatchExpeditionEnd()

	print("[NPCCommandController] Started")
end

---
-- Input Binding
---

function NPCCommandController:_BindInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Always track drag start when the panel is active (active mode set)
			-- or when in combat for normal selection
			if self._ActiveMode or self:_IsInCombat() then
				self._DragStart = UserInputService:GetMouseLocation()
				self._IsDragging = false
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			if self._ActiveMode == "MOVE_RIGHTCLICK" and self:_IsInCombat() then
				local screenPos = UserInputService:GetMouseLocation()
				self._CommandInputService:HandleRightClick(screenPos)
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self._DragStart then
			local currentPos = UserInputService:GetMouseLocation()
			local delta = (currentPos - self._DragStart).Magnitude

			if delta >= DRAG_THRESHOLD then
				self._IsDragging = true
				self._DragBoxService:Update(self._DragStart, currentPos)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local endPos = UserInputService:GetMouseLocation()

		if self._IsDragging and self._DragStart then
			if self:_IsInCombat() then
				self:_FinishBoxSelect(self._DragStart, endPos)
			end
		elseif self._DragStart then
			if self._ActiveMode == "ATTACK_FOCUS" then
				self:_ConfirmPickTarget()
			elseif self:_IsInCombat() then
				self:_HandleClickSelect(endPos)
			end
		end

		self._DragStart = nil
		self._IsDragging = false
		self._DragBoxService:Hide()
	end)
end

---
-- Input Handlers
---

function NPCCommandController:_IsInCombat(): boolean
	local questState = self._QuestStateAtom and self._QuestStateAtom()
	local expedition = questState and questState.ActiveExpedition
	return expedition and expedition.Status == "InCombat"
end

function NPCCommandController:_WatchExpeditionEnd()
	if not self._QuestStateAtom then
		return
	end

	task.spawn(function()
		while true do
			task.wait(0.5)
			local inCombat = self:_IsInCombat()

			if self._WasInCombat and not inCombat then
				self:ClearSelection()
				self._RosterState:Clear()
				if self._PickTargetService:IsActive() then
					self._PickTargetService:Exit()
				end
				self._ActiveMode = nil
			end

			self._WasInCombat = inCombat
		end
	end)
end

function NPCCommandController:_HandleClickSelect(screenPosition: Vector2)
	local npcId, model, team = self._SelectionService:RaycastForNPC(screenPosition)
	if npcId and model and team == "Adventurer" then
		if self._SelectionState:IsSelected(npcId) then
			self._SelectionState:Deselect(npcId)
		else
			self._SelectionState:Select(npcId, model)
		end
	end
end

function NPCCommandController:_FinishBoxSelect(startPos: Vector2, endPos: Vector2)
	local results = self._SelectionService:BoxSelect(startPos, endPos)
	if #results > 0 then
		self._SelectionState:Clear()
		self._SelectionVisualService:ClearMoveMarker()
		for _, result in results do
			self._SelectionState:Select(result.NPCId, result.Model)
		end
	end
end

function NPCCommandController:_ConfirmPickTarget()
	local screenPos = UserInputService:GetMouseLocation()
	local npcId, model, team = self._SelectionService:RaycastForNPC(screenPos)

	if not npcId or team ~= "Enemy" then
		return
	end

	local selectedIds = self._SelectionState:GetSelectedIds()

	if #selectedIds == 0 then
		self._PickTargetService:Exit()
		self._ActiveMode = nil
		return
	end

	if model then
		self._SelectionVisualService:ShowTargetedHighlight(npcId, model)
	end

	if self._PlayerCommandService then
		self._PlayerCommandService.PlayerCommand:Fire({
			CommandType = "AttackTarget",
			NPCIds = selectedIds,
			Data = { TargetNPCId = npcId },
		})
	end
	self._SelectionState:RecordRecentOrder("ATTACK")
	self._PickTargetService:Exit()
	self._ActiveMode = nil
end

---
-- Public API (pass-through to services)
---

function NPCCommandController:GetSelectionAtom()
	return self._SelectionState:GetSelectionAtom()
end

function NPCCommandController:GetRosterAtom()
	return self._RosterState:GetRosterAtom()
end

function NPCCommandController:GetRecentOrdersAtom()
	return self._SelectionState:GetRecentOrdersAtom()
end

function NPCCommandController:GetSelectedModels(): { [string]: Model }
	return self._SelectionState:GetSelectedModels()
end

function NPCCommandController:GetPickTargetAtom()
	return self._PickTargetService:GetPickTargetAtom()
end

function NPCCommandController:ClearSelection()
	self._SelectionState:Clear()
	self._SelectionVisualService:ClearMoveMarker()
end

function NPCCommandController:DeselectNPC(npcId: string)
	self._SelectionState:Deselect(npcId)
end

function NPCCommandController:SelectAll()
	self._SelectionState:SelectAll()
end

function NPCCommandController:SelectOnly(npcId: string)
	self._SelectionState:SelectOnly(npcId)
end

function NPCCommandController:ToggleRosterUnit(npcId: string)
	self._SelectionState:ToggleRosterUnit(npcId)
end

function NPCCommandController:SetActiveMode(key: string?)
	self._ActiveMode = key
	if key == "ATTACK_FOCUS" then
		self._PickTargetService:Enter()
	else
		if self._PickTargetService:IsActive() then
			self._PickTargetService:Exit()
		end
	end
end

function NPCCommandController:ClearTargetedHighlights()
	self._SelectionVisualService:ClearAllTargetedHighlights()
end

function NPCCommandController:SwitchModeForAll()
	self._CommandInputService:ToggleMode()
end

function NPCCommandController:IssueCommand(commandType: string)
	local selectedIds = self._SelectionState:GetSelectedIds()
	if #selectedIds == 0 then
		return
	end

	local serverCommand = COMMAND_MAP[commandType]
	if serverCommand and self._PlayerCommandService then
		self._PlayerCommandService.PlayerCommand:Fire({
			CommandType = serverCommand,
			NPCIds = selectedIds,
			Data = {},
		})
	end

	self._SelectionState:RecordRecentOrder(commandType)
end

return NPCCommandController
