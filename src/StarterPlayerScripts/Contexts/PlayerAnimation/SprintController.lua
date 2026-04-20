--!strict

--[[
	SprintController - Knit controller for sprint mechanic.

	Press X to toggle sprint (increases WalkSpeed), press again to walk.
	SimpleAnimate's RunThreshold (17) handles animation switching automatically:
	  - WalkSpeed 16 → Walk animation
	  - WalkSpeed 28 → Run animation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local WALK_SPEED = 16
local SPRINT_SPEED = 28

local SprintController = Knit.CreateController({
	Name = "SprintController",
})

function SprintController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	self._CharConnections = {} :: { RBXScriptConnection }
	self._IsSprinting = false

	registry:InitAll()
end

function SprintController:KnitStart()
	local registry = self.Registry
	local player = Players.LocalPlayer

	-- Resolve cross-context dependencies
	local PlayerInput = Knit.GetController("PlayerInputController")
	registry:Register("PlayerInputController", PlayerInput)

	local function _GetHumanoid(): Humanoid?
		local character = player.Character
		return character and character:FindFirstChildWhichIsA("Humanoid")
	end

	local function _SetSpeed(speed: number)
		local humanoid = _GetHumanoid()
		if humanoid then
			humanoid.WalkSpeed = speed
		end
	end

	local function _ResetSprint()
		self._IsSprinting = false
		_SetSpeed(WALK_SPEED)
	end

	local function _CleanupCharConnections()
		for _, conn in self._CharConnections do
			conn:Disconnect()
		end
		table.clear(self._CharConnections)
	end

	local function _SetupCharacter(character: Model)
		_CleanupCharConnections()
		_ResetSprint()

		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end

		-- Reset sprint on death
		table.insert(self._CharConnections, humanoid.Died:Connect(function()
			_ResetSprint()
		end))
	end

	-- Input handling via PlayerInputController
	PlayerInput:BindAction("Sprint", function(gameProcessed: boolean, _data: any)
		if gameProcessed then
			return
		end
		self._IsSprinting = not self._IsSprinting
		_SetSpeed(if self._IsSprinting then SPRINT_SPEED else WALK_SPEED)
	end)

	-- Character lifecycle
	if player.Character then
		task.spawn(_SetupCharacter, player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		_SetupCharacter(character)
	end)

	player.CharacterRemoving:Connect(function()
		_CleanupCharConnections()
		self._IsSprinting = false
	end)

	registry:StartOrdered({})
end

return SprintController
