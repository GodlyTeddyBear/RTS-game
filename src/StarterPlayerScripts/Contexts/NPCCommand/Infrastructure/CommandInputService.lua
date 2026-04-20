--!strict

--[[
    CommandInputService - Handles right-click-to-command input.

    Right-click on ground → MoveToPosition for all selected NPCs.
    Right-click on enemy → AttackTarget for all selected NPCs.

    Sends commands to PlayerCommandContext via Knit service proxy.
]]

local CommandInputService = {}
CommandInputService.__index = CommandInputService

export type TCommandInputService = typeof(setmetatable({} :: {
	PlayerCommandService: any,
	SelectionService: any,
	SelectionVisualService: any,
	GetSelectedNPCIds: () -> { string },
}, CommandInputService))

function CommandInputService.new(): TCommandInputService
	local self = setmetatable({}, CommandInputService)
	self.PlayerCommandService = nil :: any
	self.SelectionService = nil :: any
	self.SelectionVisualService = nil :: any
	self.GetSelectedNPCIds = nil :: any
	return self
end

function CommandInputService:Init(registry: any, _name: string)
	self.SelectionService = registry:Get("SelectionService")
	self.SelectionVisualService = registry:Get("SelectionVisualService")
	local selectionState = registry:Get("SelectionStateService")
	self.GetSelectedNPCIds = function()
		return selectionState:GetSelectedIds()
	end
end

function CommandInputService:Start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Knit = require(ReplicatedStorage.Packages.Knit)
	self.PlayerCommandService = Knit.GetService("PlayerCommandContext")
end

--[[
    Handle a right-click at the given screen position.
    Determines whether to issue a MoveToPosition or AttackTarget command.
]]
function CommandInputService:HandleRightClick(screenPosition: Vector2)
	local selectedIds = self.GetSelectedNPCIds()
	if #selectedIds == 0 then
		return
	end

	-- Check if right-clicked on an enemy NPC
	local npcId, _, team = self.SelectionService:RaycastForNPC(screenPosition)
	if npcId and team == "Enemy" then
		-- Issue AttackTarget command
		self.PlayerCommandService.PlayerCommand:Fire({
			CommandType = "AttackTarget",
			NPCIds = selectedIds,
			Data = { TargetNPCId = npcId },
		})
		return
	end

	-- Otherwise, raycast for ground position
	local groundPos = self.SelectionService:RaycastForGround(screenPosition)
	if groundPos then
		self.PlayerCommandService.PlayerCommand:Fire({
			CommandType = "MoveToPosition",
			NPCIds = selectedIds,
			Data = { Position = groundPos },
		})

		-- Show move marker ping
		self.SelectionVisualService:ShowMoveMarker(groundPos)
	end
end

--[[
    Toggle control mode for all selected NPCs.
]]
function CommandInputService:ToggleMode()
	local selectedIds = self.GetSelectedNPCIds()
	if #selectedIds == 0 then
		return
	end

	self.PlayerCommandService.ToggleMode:Fire({
		NPCIds = selectedIds,
	})
end

return CommandInputService
