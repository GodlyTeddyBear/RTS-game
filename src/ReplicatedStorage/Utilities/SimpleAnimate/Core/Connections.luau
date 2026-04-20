--!optimize 2
--Connections.luau

local RunService = game:GetService('RunService')
local parent = script.Parent.Parent

local utility = script.Parent.Parent.Utility

local Types = require(parent.Types)
local ItemGroup = require(parent.Utility.ItemGroup)

local NOT_STATE_HANDLED = {
	Running = true,
	Climbing = true,
	Swimming = true,
	
	Freefall = true,
	Jumping = true
}

local function stateChanged(self, old, new)
	local name = new.Name
	
	if NOT_STATE_HANDLED[name] then
		self._pose = name
		return
	end
	
	self._controller:ChangePose(name, 1, true)
end

local function jumping(self)
	self._jumpTimer = self.JumpDuration
	
	self._controller:ChangePose("Jumping", 1, true)
end

-- Movement Change Pose
local function movementChPose(self, pose: Types.PoseType, speed: number)
	local currentTrack = self._controller:GetCurrentTrack()
	if currentTrack then
		currentTrack:AdjustSpeed(speed)
	end
	
	self._controller:ChangePose(pose, speed, true)
end

local function climbing(self: Connections, speed: number)
	local mult = self.ClimbAnimationSpeedMultiplier
	movementChPose(self, "Climbing", 
		self.UseWalkSpeedForAnimSpeed and self.WalkSpeed * mult or speed * mult
	)
end

local function swimming(self: Connections, speed: number)
	local pose = 
		if speed <= self.SwimIdleThreshold then "SwimIdle"
	else "Swimming"
	
	local mult = self.SwimAnimationSpeedMultiplier
	movementChPose(self, pose, pose == "SwimIdle" and self.SwimIdleAnimationSpeed 
		or (self.UseWalkSpeedForAnimSpeed and self.WalkSpeed * mult or speed * mult)
	)
end

local function running(self: Connections, speed: number)
	local lastPose = self._controller:GetPose()
	
	-- ugly i know :(
	local pose = 
		if (speed == 0 or lastPose == "Landed" or lastPose == "Jumping" or lastPose == "Freefall") then "Idle"
		elseif	(speed <= self.RunThreshold) then "Walk"
	else	"Run"

	local mult = self.MoveAnimationSpeedMultiplier
	
	movementChPose(
		self, pose, pose == "Idle" and self.IdleAnimationSpeed 
			or (self.UseWalkSpeedForAnimSpeed and self.WalkSpeed * mult or speed * mult)
	)
end

local Connections = {}
Connections.__index = Connections

--[[
    Cleans up all connections and destroys the instance.
    
    @param self The Connections instance
]]
function Connections:Destroy(): ()
	self._trash:free()
	
	setmetatable(self, nil)
	table.clear(self)
	self = nil
end

export type Connections = typeof(Connections) & {
	JumpDuration: number,
	
	SwimIdleAnimationSpeed: number,
	IdleAnimationSpeed: number,
	
	RunThreshold: number,
	SwimIdleThreshold: number,
	
	MoveAnimationSpeedMultiplier: number,
	ClimbAnimationSpeedMultiplier: number,
	SwimAnimationSpeedMultiplier: number,
	
	WalkSpeed: number,
	
	AutoAdjustSpeedMultipliers: boolean,
	UseWalkSpeedForAnimSpeed: boolean,
}

local function new(PoseController, rig: Model, stateMachine: Types.StateMachine?) : Connections
	local humanoid: Types.StateMachine = stateMachine or rig:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		error(`Humanoid not found for rig {rig}`)
	end
	assert(
		humanoid.Running
		and humanoid.Jumping
		and humanoid.WalkSpeed
		and humanoid.Climbing
		and humanoid.StateChanged
		and humanoid.Swimming,
		"StateMachine fields incomplete"
	)
	local trash = ItemGroup.create(ItemGroup.cleanup.disconnect)

	local connections = setmetatable({
		_jumpTimer = 0,
		_controller = PoseController,
		_trash = trash,
		
		_pose = PoseController:GetPose(),
		
		JumpDuration = 0.2,
		
		SwimIdleAnimationSpeed = 1,
		SwimIdleThreshold = 2,
		
		RunThreshold = 17,
		
		IdleAnimationSpeed = 1,
		
		MoveAnimationSpeedMultiplier = 1,
		ClimbAnimationSpeedMultiplier = 1,
		SwimAnimationSpeedMultiplier = 1,
		
		WalkSpeed = humanoid.WalkSpeed,
		
		AutoAdjustSpeedMultipliers = true,
		UseWalkSpeedForAnimSpeed = true
	}, Connections)
	
	trash:add_many({
		RunService.Heartbeat:Connect(function()
			if not connections.AutoAdjustSpeedMultipliers then return end
			
			local speed = 1/connections.WalkSpeed
			connections.MoveAnimationSpeedMultiplier = speed
			connections.ClimbAnimationSpeedMultiplier = speed
			connections.SwimAnimationSpeedMultiplier = speed
		end),
		humanoid.Running:Connect(function(speed)
			running(connections, speed)
		end),
		humanoid.Climbing:Connect(function(speed)
			climbing(connections, speed)	
		end),
		humanoid.Swimming:Connect(function(speed)
			swimming(connections, speed)
		end),
		humanoid.StateChanged:Connect(function(old, new)
			stateChanged(connections, old, new)
		end),
		humanoid.Jumping:Connect(function()
			jumping(connections)
		end),
		RunService.Heartbeat:Connect(function(dt)
			connections._jumpTimer = math.max(connections._jumpTimer - dt, 0)
			local lastPose = PoseController:GetPose()
			
			if connections._pose == "Freefall" and (lastPose == "Run" or lastPose == "Walk") then
				PoseController:ChangePose("FellOff", 1, true)
			end
			if connections._pose == "Freefall" and connections._jumpTimer <= 0 then
				PoseController:ChangePose("Freefall", 1, true)
			end
		end)
	})
	
	return connections
end

return {
	new = new
}