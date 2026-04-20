--!strict

--[[
	PlayerInputController - Knit controller that wraps OmrezKeyBind.

	Centralizes all keybind management. Other controllers bind to named actions
	instead of using raw UserInputService.

	Usage from another controller:
	  local PlayerInput = Knit.GetController("PlayerInputController")
	  local unbind = PlayerInput:BindAction("Sprint", function(gameProcessed, data)
	      -- handle sprint
	  end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local OmrezKeyBind = require(ReplicatedStorage.Packages.OmrezKeyBind)

local InputActions = require(script.Parent.Config.InputActions)

type Callback = (gameProcessed: boolean, data: any) -> ()

local PlayerInputController = Knit.CreateController({
	Name = "PlayerInputController",
})

function PlayerInputController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	OmrezKeyBind.CreateContexts(InputActions)

	registry:InitAll()
end

function PlayerInputController:KnitStart()
	self.Registry:StartOrdered({})
end

--- Bind a callback to an action's activation (key pressed).
--- Returns an unbind function.
function PlayerInputController:BindAction(actionName: string, callback: Callback): () -> ()
	return OmrezKeyBind.BindToActionActivated(actionName, callback)
end

--- Bind a callback to an action's deactivation (key released).
--- Returns an unbind function.
function PlayerInputController:BindActionDeactivated(actionName: string, callback: Callback): () -> ()
	return OmrezKeyBind.BindToActionDeactivated(actionName, callback)
end

--- Enable or disable an entire context (e.g., "Movement", "Combat").
function PlayerInputController:ToggleContext(contextName: string, state: boolean)
	OmrezKeyBind.ToggleContext(contextName, state)
end

--- Enable or disable a single action within its context.
function PlayerInputController:ToggleAction(actionName: string, state: boolean)
	OmrezKeyBind.ToggleAction(actionName, state)
end

--- Get the current keybind for an action.
function PlayerInputController:GetActionKeybind(actionName: string): (Enum.KeyCode | Enum.UserInputType | string)?
	return OmrezKeyBind.GetActionKeybind(actionName)
end

--- Rebind an action to a new key at runtime.
function PlayerInputController:SetActionKeybind(
	actionName: string,
	newBinding: Enum.KeyCode | Enum.UserInputType | string
)
	OmrezKeyBind.SetActionKeybind(actionName, newBinding)
end

--- Reset all keybinds to their defaults from InputActions.
function PlayerInputController:ResetKeybinds()
	OmrezKeyBind.ResetActionKeybinds()
end

--- Get all current custom keybinds (for serialization/saving).
function PlayerInputController:GetCustomKeybinds(): { [string]: Enum.KeyCode | Enum.UserInputType | string }
	return OmrezKeyBind.GetCustomKeybinds()
end

--- Load previously saved custom keybinds.
function PlayerInputController:LoadCustomKeybinds(
	customKeybinds: { [string]: Enum.KeyCode | Enum.UserInputType | string }
)
	OmrezKeyBind.LoadCustomKeybinds(customKeybinds)
end

--- Bind a UI button to fire an action.
function PlayerInputController:BindButtonToAction(actionName: string, button: TextButton | ImageButton)
	OmrezKeyBind.BindActionToButton(actionName, button)
end

--- Unbind a UI button from an action.
function PlayerInputController:UnbindActionButton(actionName: string)
	OmrezKeyBind.UnbindActionButton(actionName)
end

return PlayerInputController
