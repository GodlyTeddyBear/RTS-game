--!strict

--[[
   MuchachoHitbox v2.0
   Spatial query hitbox module by SushiMaster

   Ported to ReplicatedStorage/Utilities - requires via script.Parent references.
]]

--[=[
	@class MuchachoHitbox
	Spatial query hitbox system for detecting collisions via workspace raycasting and overlap queries.
	Supports multiple detection modes, velocity prediction, and visualization debugging.
	@server
	@client
]=]

local rs = game:GetService("RunService")
local hs = game:GetService("HttpService")

local GoodSignal = require(script.GoodSignal)
local DictDiff = require(script.DictDiff)
local Types = require(script.Types)

local muchacho_hitbox = {}
muchacho_hitbox.__index = muchacho_hitbox


local get_CFrame = {
	["Instance"] = function(point)
		return point.CFrame
	end,

	["CFrame"] = function(point)
		return point
	end,
}

local hitboxes = {}

--[=[
	@function CreateHitbox
	@within MuchachoHitbox
	Creates and initializes a new hitbox instance with default detection mode and disabled visualizer.
	@return Hitbox -- A new hitbox object configured with default settings
]=]
function muchacho_hitbox.CreateHitbox()
	local self = setmetatable({}, muchacho_hitbox) :: Types.Hitbox
	-- Detection and lifecycle configuration
	self.DetectionMode = "Default"
	self.AutoDestroy = true

	-- Visualizer settings for debugging spatial queries
	self.Visualizer = true
	self.VisualizerColor = Color3.fromRGB(255, 0, 0)
	self.VisualizerTransparency = 0.8

	-- Velocity prediction for moving hitboxes
	self.VelocityPrediction = false
	self.VelocityPredictionTime = 0.1

	-- Roblox spatial query configuration
	self.OverlapParams = OverlapParams.new()

	-- Hitbox geometry
	self.Size = Vector3.new(0, 0, 0)
	self.Shape = Enum.PartType.Block
	self.CFrame = CFrame.new(0, 0, 0)
	self.Offset = CFrame.new(0, 0, 0)

	-- Unique identifier for tracking active hitboxes
	self.Key = hs:GenerateGUID(false)

	-- Hit tracking for different detection modes
	self.HitList = {}
	self.TouchingParts = {}

	-- Collision event signals
	self.Touched = GoodSignal.new()
	self.TouchEnded = GoodSignal.new()

	return self
end

--[=[
	@deprecated 2.0.0 -- Use direct hitbox references instead
	@within MuchachoHitbox
	@param key string -- The unique hitbox identifier
	@return Hitbox? -- The hitbox with the given key, or nil if not found
]=]
function muchacho_hitbox:FindHitbox(key) -- deprecated
	if hitboxes[key] then
		return hitboxes[key]
	else
		return nil
	end
end

--[=[
	@method Start
	@within MuchachoHitbox
	Activates the hitbox and begins spatial queries on every Heartbeat. Registers the hitbox globally for lifecycle tracking.
	@error string -- Thrown if a hitbox with this key is already active
]=]
function muchacho_hitbox.Start(self: Types.Hitbox)
	-- Guard against duplicate activation using the same key
	if hitboxes[self.Key] then
		error("A hitbox with this Key has already been started. Change the key if you want to start this hitbox.")
	end

	-- Register hitbox globally for tracking
	hitboxes[self.Key] = self

	-- Spawn heartbeat loop for continuous spatial queries
	task.spawn(function()
		self._Connection = rs.Heartbeat:Connect(function()
			self:_visualize()
			self:_cast()
		end)
	end)
end

--[=[
	@method Stop
	@within MuchachoHitbox
	Halts spatial queries and disconnects the heartbeat loop. Optionally cleans up signals if `AutoDestroy` is enabled.
	@error string -- Thrown if the hitbox is not currently active
]=]
function muchacho_hitbox.Stop(self: Types.Hitbox)
	-- Verify hitbox is registered and active
	local hitbox = muchacho_hitbox:FindHitbox(self.Key)

	if not hitbox then
		error("Hitbox has already been stopped")
	end

	-- Clear heartbeat connection and hit tracking
	self:_clear()

	-- Optionally clean up event signals if configured
	if not self.AutoDestroy then
		return
	end

	self.Touched:DisconnectAll()
	self.TouchEnded:DisconnectAll()
end

--[=[
	@method Destroy
	@within MuchachoHitbox
	Completely destroys the hitbox: stops queries, disconnects signals, and cleans up the visualizer part.
	@error string -- Thrown if the hitbox is not currently active
]=]
function muchacho_hitbox:Destroy()
	-- Verify hitbox is registered before destruction
	local hitbox: Types.Hitbox = muchacho_hitbox:FindHitbox(self.Key)

	if not hitbox then
		error("Hitbox has already been destroyed")
	end

	-- Disconnect heartbeat loop and unregister globally
	self:_clear()

	-- Fully clean up event signals
	self.Touched:DisconnectAll()
	self.TouchEnded:DisconnectAll()
end

-- Performs a spatial query using Roblox's workspace overlap methods. Optionally applies velocity prediction
-- to the query position before casting to account for fast-moving hitboxes.
function muchacho_hitbox._CastSpatialQuery(self: Types.Hitbox): { BasePart }?
	-- Resolve the source CFrame: either a part instance or direct CFrame
	local point_type: CFrame | string = typeof(self.CFrame)
	-- Apply velocity prediction if enabled, otherwise use the current CFrame
	local point_cframe: CFrame = self:_PredictVelocity() or get_CFrame[point_type](self.CFrame)

	-- Apply local offset to the hitbox position
	local hitboxCFrame: CFrame = point_cframe * self.Offset

	-- Cast the appropriate spatial query shape
	local parts
	if self.Shape == Enum.PartType.Block then
		parts = workspace:GetPartBoundsInBox(hitboxCFrame, self.Size, self.OverlapParams)
	elseif self.Shape == Enum.PartType.Ball then
		parts = workspace:GetPartBoundsInRadius(hitboxCFrame.Position, self.Size, self.OverlapParams)
	else
		error("Part type: " .. self.Shape .. " isn't compatible with muchachoHitbox")
	end

	return parts
end

-- Performs the core hitbox detection logic: casts a spatial query, processes results based on the detection mode,
-- and fires Touched/TouchEnded events. Handles four distinct detection modes with different behavior.
function muchacho_hitbox._cast(self: Types.Hitbox, part: BasePart)
	local mode = self.DetectionMode
	-- Step 1: Get all parts currently overlapping the hitbox
	local parts = self:_CastSpatialQuery()

	-- Step 2: Detect parts that were touching but are no longer in the query
	self:_FindTouchEnded(parts)

	-- Step 3: Process each hit part according to the active detection mode
	for _, hit in pairs(parts) do
		-- Resolve the character model and humanoid from the hit part
		local character: Model = hit:FindFirstAncestorOfClass("Model") or hit.Parent
		local humanoid: Humanoid? = character:FindFirstChildOfClass("Humanoid")

		-- Dispatch to the appropriate detection mode handler
		if mode == "Default" then
			-- Fire Touched only once per unique humanoid
			if humanoid and not table.find(self.HitList, humanoid) then
				table.insert(self.HitList, humanoid)
				self:_InsertTouchingParts(hit)
				self.Touched:Fire(hit, humanoid)
			end
		elseif mode == "ConstantDetection" then
			-- Fire Touched every frame for all humanoids, even if already hit
			if humanoid then
				self:_InsertTouchingParts(hit)
				self.Touched:Fire(hit, humanoid)
			end
		elseif mode == "HitOnce" then
			-- Fire Touched once on first humanoid hit, then immediately destroy
			if humanoid then
				self:_InsertTouchingParts(hit)
				self.Touched:Fire(hit, humanoid)
				self.TouchEnded:Fire(hit)
				self:Destroy()
				break
			end
		elseif mode == "HitParts" then
			-- Fire Touched for all parts regardless of humanoid (used for non-character detection)
			self:_InsertTouchingParts(hit)
			self.Touched:Fire(hit, nil)
		end
	end
end

-- Creates or updates a debug visualization part that represents the hitbox's current size, shape, and position.
-- The visualization part is non-collidable and CanQuery=false so it doesn't interfere with game physics.
function muchacho_hitbox._visualize(self: Types.Hitbox)
	-- Early exit if visualization is disabled
	if not self.Visualizer then
		return
	end

	-- Resolve the hitbox position with optional velocity prediction
	local predictedCFrame = self:_PredictVelocity()
	local point_type: string = typeof(self.CFrame)
	local point_cframe: CFrame = predictedCFrame or get_CFrame[point_type](self.CFrame)

	-- Step 1: Initialize the visualization part on first frame
	if not self._Box then
		-- Create or reuse the "Hitboxes" debug folder
		local existing = workspace:FindFirstChild("Hitboxes")
		local folder: Folder
		if existing and existing:IsA("Folder") then
			folder = existing :: Folder
		else
			folder = Instance.new("Folder")
			folder.Name = "Hitboxes"
			folder.Parent = workspace
		end

		-- Create the debug visualization part with non-interactive properties
		local part = Instance.new("Part")
		part.Name = "Visualizer"
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Color = self.VisualizerColor
		part.Transparency = self.VisualizerTransparency
		part.CFrame = point_cframe * self.Offset

		-- Configure the shape: ball (radius) or block (box)
		if self.Shape == Enum.PartType.Ball then
			part.Shape = Enum.PartType.Ball
			-- For balls, Size represents the radius; multiply by 2 to get the diameter
			part.Size = Vector3.new(self.Size * 2, self.Size * 2, self.Size * 2)
		else
			part.Shape = Enum.PartType.Block
			part.Size = self.Size
		end

		part.Parent = folder
		self._Box = part
	else
		-- Step 2: Update the visualization part's position each frame
		self._Box.CFrame = point_cframe * self.Offset
	end
end

-- Extrapolates the hitbox's future position based on the source part's current velocity and a prediction time offset.
-- This prevents fast-moving hitboxes from "tunneling" through obstacles by catching them a frame ahead.
function muchacho_hitbox._PredictVelocity(self: Types.Hitbox): CFrame | nil
	if self.VelocityPrediction then
		local PredictionTime: number = self.VelocityPredictionTime
		local part: BasePart = self.CFrame

		if PredictionTime > 0 and typeof(part) == "Instance" then
			-- Sample the part's current velocity from the physics engine
			local Velocity = part.AssemblyLinearVelocity
			-- Project forward to estimate where the part will be at PredictionTime seconds from now
			local PredictedPosition = part.Position + Velocity * PredictionTime
			-- Preserve the part's rotation, only updating position
			local PredictedCFrame = CFrame.new(PredictedPosition) * (part.CFrame - part.Position)

			return PredictedCFrame
		end
	end

	return nil
end

-- Completely cleans up the hitbox's internal state: clears hit tracking, disconnects the heartbeat loop,
-- unregisters from the global hitbox registry, and destroys the debug visualization part.
function muchacho_hitbox:_clear()
	-- Clear the accumulated hit list
	self.HitList = {}

	-- Disconnect the heartbeat loop
	if self._Connection then
		self._Connection:Disconnect()
	end

	-- Remove from global hitbox registry
	if self.Key then
		hitboxes[self.Key] = nil
	end

	-- Destroy the debug visualization part
	if self._Box then
		self._Box:Destroy()
		self._Box = nil
	end
end

-- Adds a part to the TouchingParts list if it is not already there. Used to track which parts are
-- currently touching for TouchEnded event detection in the next _FindTouchEnded call.
function muchacho_hitbox._InsertTouchingParts(self: Types.Hitbox, part)
	-- Guard against duplicates in the touching list
	if table.find(self.TouchingParts, part) then
		return
	end

	table.insert(self.TouchingParts, part)
end

-- Detects parts that were previously touching but are no longer in the current spatial query.
-- Fires TouchEnded for each departed part and removes it from the TouchingParts list.
function muchacho_hitbox._FindTouchEnded(self: Types.Hitbox, parts: { BasePart }?)
	-- Early exit if no parts are being tracked
	if #self.TouchingParts == 0 then
		return
	end

	-- Find all parts that were touching but are no longer in the query
	local differences = DictDiff.difference(self.TouchingParts, parts)

	-- Fire TouchEnded signal for each departed part and remove from tracking
	if differences then
		for _, diff in ipairs(differences) do
			self.TouchEnded:Fire(diff)
			table.remove(self.TouchingParts, table.find(self.TouchingParts, diff))
		end
	end
end

return muchacho_hitbox
