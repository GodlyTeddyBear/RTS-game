--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Utilities.SimpleAnimate.Utility.SimpleSignal)

local EntityAnimationStateAdapter = {}
EntityAnimationStateAdapter.__index = EntityAnimationStateAdapter

local DEFAULT_WALK_SPEED = 16
local MIN_MOVING_SPEED = 1.2
local SPEED_EPSILON = 0.05

function EntityAnimationStateAdapter.new()
	return setmetatable({
		Running = Signal.new(),
		Climbing = Signal.new(),
		Swimming = Signal.new(),
		StateChanged = Signal.new(),
		Jumping = Signal.new(),
		WalkSpeed = DEFAULT_WALK_SPEED,
		_lastRunningSpeed = nil,
	}, EntityAnimationStateAdapter)
end

function EntityAnimationStateAdapter:UpdateRunning(isMoving: boolean, speed: number)
	local runningSpeed = if isMoving then math.max(speed, MIN_MOVING_SPEED) else 0
	local lastRunningSpeed = self._lastRunningSpeed
	if lastRunningSpeed ~= nil and math.abs(lastRunningSpeed - runningSpeed) < SPEED_EPSILON then
		return
	end

	self._lastRunningSpeed = runningSpeed
	self.Running:Fire(runningSpeed)
end

function EntityAnimationStateAdapter:Destroy()
	self.Running:Destroy()
	self.Climbing:Destroy()
	self.Swimming:Destroy()
	self.StateChanged:Destroy()
	self.Jumping:Destroy()
	setmetatable(self, nil)
	table.clear(self)
end

return EntityAnimationStateAdapter
