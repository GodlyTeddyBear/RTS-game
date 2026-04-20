--[[
	[Cooldowns] The Ultimate Cooldown/Debounce Management Module System
	By @Luacathy - v1.0.1

	--Update Log--
	Fixed
		> Zombie connection issue (cause of Roblox's internal script context lifecycle management) - heartbeat connections now reconnect
		> Return value bugs - Remove() and AdjustDuration() methods (were missing return false)
		> Time scaling calculation - Across all methods that used timeScale

	cooldown = Cooldowns.new(name?) -> CooldownInstance
		> Creates new cooldown instance if it doesn't exist already

	cooldown = Cooldowns.get(name) -> CooldownInstance?
		> Retrieves existing cooldown instance

	--Properties--
    	> useScaledTime (boolean) - When true, durations are automatically scaled by timeScale
    	> timeScale (number) - Current time scaling factor (write via SetTimeScale)

	--Core Methods--
	cooldown:Set(keyName, duration, callback?, ...) -> boolean
		> Always sets, overwrites if exists
		> Duration in seconds, callback fires on completion

	cooldown:Check(keyName, scaled?) -> (boolean, number?)
		> scaled: if true, returns timeLeft scaled by timeScale
		> Returns (doesNotExist: boolean, timeLeft: number?)
		> doesNotExist = false when cooldown active
		> timeLeft = time left when exists

	cooldown:Add(keyName, duration, callback?, ...) -> boolean
		> Only sets if key doesn't exist (non-overwriting)

	cooldown:Remove(keyName) -> boolean
		> Clears specified cooldown

	cooldown:Reset() -> boolean
	    > Clears ALL cooldowns in this instance
	    > Returns true if any cooldowns were removed
	    > For single cooldown removal, use :Remove()

	cooldown:Destroy()
		> Cleans up instance (Maid-compatible)

	--Advanced Methods--
	cooldown:Pause(keyName) -> boolean
		> Freezes cooldown

	cooldown:Resume(keyName) -> boolean
		> Resumes cooldown

	cooldown:SetTimeScale(scale) -> boolean
		> Adjusts speed for all cooldowns (0.5 = 50% speed)

	cooldown:AdjustAllDurations(amount: number, predicate: function?) -> boolean
		> Adjusts all cooldown durations
		> predicate: optional filter function (receives CooldownEntry)

	cooldown:AdjustDuration(keyName: string, amount: number) -> boolean
		> Adjusts specific cooldown duration
		> Returns false if cooldown didn't exist

	Features:
	- Precision timing (auto-optimized near completion)
	- Time scaling (slow-mo/fast-forward/"Player Engagement Booster ;)" support)
	- Thread-safe callbacks
	- Batched processing
	- Predicate filtering for bulk operations

	Notes:
	- Uses Heartbeat for frame-accurate timing
	- Switches to high-precision mode near completion
	- Automatically disconnects when no cooldowns exist
	- Automatically reconnects when new cooldowns are added

	Example Usage:
    local Cooldowns = require(game.ReplicatedStorage.Cooldowns)
    local abilities = Cooldowns.new("PlayerAbilities")

    --Set ability cooldown
    abilities:Set("Fireball", 5, function()
        print("Fireball ready!")
    end)

    --Check if available
    local ready, remaining = abilities:Check("Fireball")
    if ready then
        print("Fireball available!")
    else
        print(string.format("Fireball cooldown: %.1fs", remaining))
    end
--]]

--[=[
	@class Cooldowns
	Precision cooldown and debounce management system with time scaling and frame-accurate timing.
	@server
	@client
]=]

local RunService = game:GetService("RunService")

local Cooldowns = {
	instances = {},
	globalUpdate = nil,
}

local MAX_UPDATES_PER_FRAME = 10000
local PRECISION_FACTOR = 0.01
local MIN_PRECISION_TIME = 0.25
local DEFAULT_TIME_SCALE = 1
local MIN_TIME_SCALE = 0.01

local PrivateMethods = {}

-- Maintain the global Heartbeat connection, reconnecting if it was garbage collected.
-- Roblox's internal lifecycle management can cause the connection to become zombie; this ensures it stays alive.
function PrivateMethods.maintainGlobalUpdate()
	if Cooldowns.globalUpdate and not Cooldowns.globalUpdate.Connected then
		Cooldowns.globalUpdate = nil
	end

	if not Cooldowns.globalUpdate then
		Cooldowns.globalUpdate = RunService.Heartbeat:Connect(function(deltaTime)
			local hasActive = false

			for _, instance in pairs(Cooldowns.instances) do
				if instance.active then
					hasActive = true

					PrivateMethods.update(instance, deltaTime)
				end
			end

			if not hasActive and Cooldowns.globalUpdate then
				Cooldowns.globalUpdate:Disconnect()
				Cooldowns.globalUpdate = nil
			end
		end)
	end
end

-- Update all active cooldowns in this instance for the current frame.
-- Handles precision timing near completion, callbacks, and cleanup of expired cooldowns.
function PrivateMethods.update(self, deltaTime)
	-- Step 1: Create a snapshot of cooldown keys to process
	-- This avoids iterator invalidation if keys are removed during the update loop.
	local scaledDelta = deltaTime * self.timeScale
	local cooldownsToProcess = {}
	for keyName in pairs(self.cooldownData) do
		cooldownsToProcess[#cooldownsToProcess + 1] = keyName
		-- Batch up to MAX_UPDATES_PER_FRAME to avoid frame stalls with many cooldowns
		if #cooldownsToProcess >= MAX_UPDATES_PER_FRAME then
			break
		end
	end

	local isActive = false

	-- Step 2: Update each cooldown entry
	for _, keyName in ipairs(cooldownsToProcess) do
		local entry = self.cooldownData[keyName]
		-- Guard: entry may have been removed by another operation
		if not entry then
			continue
		end

		if not entry.paused then
			-- Switch to precision timing when near completion for accuracy near zero
			-- Uses os.clock() for sub-frame precision instead of accumulating delta time
			local precise = entry.timeLeft <= math.max(MIN_PRECISION_TIME, entry.time * PRECISION_FACTOR)

			if precise then
				-- Use wall-clock delta for precision (avoids floating-point drift)
				entry.timeLeft = math.max(0, entry.time - (os.clock() - entry.startTime) * self.timeScale)
			else
				-- Accumulate scaled delta time for normal timing
				entry.timeLeft = math.max(0, entry.timeLeft - scaledDelta)
			end

			-- Step 3: Fire callback and clean up when cooldown expires
			if entry.timeLeft <= 0 then
				if entry.callback then
					local args = entry.arguments or {}

					-- Spawn callback on a separate thread to avoid blocking the heartbeat if callback errors
					task.spawn(function()
						local success, err = pcall(entry.callback, unpack(args))

						if not success then
							warn("Cooldown callback failed:", err)
						end
					end)
				end

				-- Remove the expired cooldown entry
				self.cooldownData[keyName] = nil
			end
		end

		isActive = true
	end

	-- Step 4: Update active flag (deactivate if no cooldowns remain)
	if next(self.cooldownData) == nil then
		self.active = false
	else
		self.active = isActive
	end
end

local Methods = {}
Methods.__index = Methods

--[=[
	@interface CooldownEntry
	@within Cooldowns
	Internal structure tracking a single active cooldown.
	.time number -- Total duration in seconds
	.startTime number -- Wall-clock time when the cooldown started (from os.clock())
	.timeLeft number -- Remaining time in seconds
	.callback (...any) -> ...any? -- Function to call on completion (optional)
	.arguments { any } -- Arguments to pass to the callback
	.paused boolean -- Whether the cooldown is currently paused
]=]
type CooldownEntry = {
	time: number,
	startTime: number,
	timeLeft: number,
	callback: (...any) -> ...any?,
	arguments: { any },
	paused: boolean,
}

--[=[
	@interface CooldownInstance
	@within Cooldowns
	A cooldown manager instance tracking multiple named cooldowns.
	.name string -- Unique instance name
	.cooldownData { [string]: CooldownEntry }? -- Map of cooldown identifiers to active entries
	.active boolean -- Whether this instance has active cooldowns
	.timeScale number -- Current time scale multiplier (1.0 = normal speed)
	.useScaledTime boolean -- Whether durations are auto-scaled by timeScale (default: true)

	.SetTimeScale (self: CooldownInstance, scale: number) -> boolean -- Set the time scale
	.Set (self: CooldownInstance, keyName: string, duration: number, callback: (...any) -> ...any?, ...any) -> boolean -- Set a cooldown
	.Check (self: CooldownInstance, keyName: string, scaled: boolean?) -> (boolean, number?) -- Check cooldown status
	.Add (self: CooldownInstance, keyName: string, duration: number, callback: (...any) -> ...any?, ...any) -> boolean -- Add if not exists
	.Remove (self: CooldownInstance, keyName: string) -> boolean -- Remove a cooldown
	.Reset (self: CooldownInstance) -> boolean -- Clear all cooldowns
	.Pause (self: CooldownInstance, keyName: string) -> boolean -- Pause a cooldown
	.Resume (self: CooldownInstance, keyName: string) -> boolean -- Resume a paused cooldown
	.AdjustAllDurations (self: CooldownInstance, amount: number, predicate: ((entry: CooldownEntry) -> boolean)?) -> boolean -- Adjust all durations
	.AdjustDuration (self: CooldownInstance, keyName: string, amount: number) -> boolean -- Adjust one duration
	.Destroy (self: CooldownInstance) -> () -- Clean up the instance
]=]
export type CooldownInstance = {
	name: string,
	cooldownData: { [string]: CooldownEntry }?,
	active: boolean,
	timeScale: number,
	useScaledTime: boolean,

	SetTimeScale: (self: CooldownInstance, scale: number) -> boolean,
	Set: (
		self: CooldownInstance,
		keyName: string,
		duration: number,
		callback: (...any) -> ...any?,
		...any
	) -> boolean,
	Check: (self: CooldownInstance, keyName: string, scaled: boolean?) -> (boolean, number?),
	Add: (
		self: CooldownInstance,
		keyName: string,
		duration: number,
		callback: (...any) -> ...any?,
		...any
	) -> boolean,
	Remove: (self: CooldownInstance, keyName: string) -> boolean,
	Reset: (self: CooldownInstance) -> boolean,
	Pause: (self: CooldownInstance, keyName: string) -> boolean,
	Resume: (self: CooldownInstance, keyName: string) -> boolean,
	AdjustAllDurations: (
		self: CooldownInstance,
		amount: number,
		predicate: ((entry: CooldownEntry) -> boolean)?
	) -> boolean,
	AdjustDuration: (self: CooldownInstance, keyName: string, amount: number) -> boolean,
	Destroy: (self: CooldownInstance) -> (),
}

--[=[
	Create a new cooldown instance or retrieve an existing one by name.
	@within Cooldowns
	@param tableName string? -- Optional name for the instance; auto-generated if omitted
	@return CooldownInstance -- The cooldown instance
]=]
function Cooldowns.new(tableName: string?): CooldownInstance
	local name = tableName or "Cooldown_" .. tostring(#Cooldowns.instances + 1)

	local existing = Cooldowns.instances[name]
	if existing and getmetatable(existing) == Methods then
		return existing
	end

	local self = setmetatable({
		name = name,
		cooldownData = {},
		active = false,
		timeScale = math.max(MIN_TIME_SCALE, DEFAULT_TIME_SCALE),
		useScaledTime = true,
	}, Methods)

	Cooldowns.instances[name] = self

	return self
end

--[=[
	Retrieve an existing cooldown instance by name.
	@within Cooldowns
	@param tableName string -- The instance name to retrieve
	@return CooldownInstance? -- The instance if it exists, nil otherwise
]=]
function Cooldowns.get(tableName: string): CooldownInstance?
	return Cooldowns.instances[tableName]
end

--[=[
	Set the time scale factor for all cooldowns in this instance.
	@within Cooldowns
	@param scale number -- Time scale multiplier (0.5 = 50% speed, 2.0 = 200% speed)
	@return boolean -- Always returns true
]=]
function Methods:SetTimeScale(scale: number)
	assert(scale, "Missing scale for cooldowns")

	-- Step 1: Update the time scale and compute the adjustment factor
	local oldScale = self.timeScale
	self.timeScale = math.max(MIN_TIME_SCALE, scale)
	local currentTime = os.clock()

	-- Step 2: Adjust all active cooldowns to account for the new time scale
	-- Must update both timeLeft and startTime to maintain precision and correct callback timing
	for keyName, entry in pairs(self.cooldownData) do
		local scaleFactor = self.timeScale / oldScale
		entry.timeLeft = entry.timeLeft * scaleFactor
		entry.time = entry.time * scaleFactor

		-- For non-paused cooldowns, adjust startTime so elapsed time is recomputed relative to new scale
		if not entry.paused then
			entry.startTime = currentTime - (currentTime - entry.startTime) * (oldScale / self.timeScale)
		end
	end

	return true
end

--[=[
	Set a cooldown, creating it if it doesn't exist or overwriting if it does.
	@within Cooldowns
	@param keyName string -- Unique identifier for this cooldown
	@param duration number -- How long the cooldown lasts, in seconds
	@param callback (...any) -> ...any? -- Optional function to call when cooldown completes
	@return boolean -- Always returns true
	@error string -- Thrown if keyName or duration is missing or duration is negative
]=]
function Methods:Set(keyName: string, duration: number, callback: (...any) -> ...any?, ...: any): boolean
	assert(keyName, "Missing keyName for a cooldown")
	assert(duration, "Missing duration for a [" .. keyName .. "] cooldown")
	assert(duration >= 0, "Duration cannot be negative for [" .. keyName .. "] cooldown")

	-- Step 1: Ensure the global update loop is running
	PrivateMethods.maintainGlobalUpdate()

	-- Step 2: Create the cooldown entry with scaled or raw duration
	local adjustedDuration = self.useScaledTime and (duration * self.timeScale) or duration

	local entry = {
		time = adjustedDuration,
		startTime = os.clock(),
		timeLeft = adjustedDuration,
		callback = callback,
		arguments = { ... },
		paused = false,
	}

	-- Step 3: Store and mark this instance as active
	self.cooldownData[keyName] = entry
	self.active = true

	return true
end

--[=[
	Check if a cooldown exists and retrieve the time remaining.
	@within Cooldowns
	@param keyName string -- The cooldown identifier to check
	@param scaled boolean? -- If true, scale returned time by the current timeScale
	@return boolean -- True if cooldown does not exist (ready), false if active
	@return number? -- Time remaining in seconds (nil if cooldown doesn't exist)
]=]
function Methods:Check(keyName: string, scaled: boolean?): (boolean, number?)
	local entry = self.cooldownData[keyName]
	if not entry then
		return true
	end

	return false, scaled and (entry.timeLeft / self.timeScale) or entry.timeLeft
end

--[=[
	Add a cooldown only if the key doesn't already exist.
	@within Cooldowns
	@param keyName string -- Unique identifier for this cooldown
	@param duration number -- How long the cooldown lasts, in seconds
	@param callback (...any) -> ...any? -- Optional function to call when cooldown completes
	@return boolean -- True if set successfully, false if key already exists
]=]
function Methods:Add(keyName: string, duration: number, callback: (...any) -> ...any?, ...: any): boolean
	if self.cooldownData and self.cooldownData[keyName] then
		return false
	end

	return self:Set(keyName, duration, callback, ...)
end

--[=[
	Remove and clear a specific cooldown.
	@within Cooldowns
	@param keyName string -- The cooldown identifier to remove
	@return boolean -- True if removed, false if cooldown didn't exist
]=]
function Methods:Remove(keyName: string): boolean
	if self:Check(keyName) then
		return false
	end

	self.cooldownData[keyName] = nil

	return true
end

--[=[
	Clear all cooldowns in this instance.
	@within Cooldowns
	@return boolean -- True if any cooldowns existed and were removed, false otherwise
]=]
function Methods:Reset(): boolean
	local hadCooldowns = next(self.cooldownData) ~= nil
	self.cooldownData = {}
	self.active = false

	return hadCooldowns
end

--[=[
	Pause a cooldown, freezing its remaining time.
	@within Cooldowns
	@param keyName string -- The cooldown identifier to pause
	@return boolean -- True if paused, false if cooldown doesn't exist or is already paused
]=]
function Methods:Pause(keyName: string): boolean
	if self:Check(keyName) then
		return false
	end

	local entry = self.cooldownData[keyName]

	-- Guard: already paused
	if entry.paused then
		return false
	end

	-- Freeze the duration to the current remaining time so Resume can restart from here
	entry.time = entry.timeLeft
	entry.paused = true

	return true
end

--[=[
	Resume a paused cooldown.
	@within Cooldowns
	@param keyName string -- The cooldown identifier to resume
	@return boolean -- True if resumed, false if cooldown doesn't exist or isn't paused
]=]
function Methods:Resume(keyName: string): boolean
	if self:Check(keyName) then
		return false
	end

	local entry = self.cooldownData[keyName]

	-- Guard: not paused, nothing to resume
	if not entry.paused then
		return false
	end

	-- Reset startTime so the next update uses the paused timeLeft as the baseline
	entry.startTime = os.clock()
	entry.paused = false

	return true
end

--[=[
	Adjust the duration of all cooldowns, optionally filtered by a predicate.
	@within Cooldowns
	@param amount number -- Duration adjustment in seconds (can be negative)
	@param predicate ((entry: CooldownEntry) -> boolean)? -- Optional filter function; only cooldowns where predicate returns true are adjusted
	@return boolean -- Always returns true
	@error string -- Thrown if amount is missing
]=]
function Methods:AdjustAllDurations(amount: number, predicate: ((entry: CooldownEntry) -> boolean)?): boolean
	assert(amount, "Missing amount adjustment for cooldowns")

	-- Apply time scaling if enabled
	local adjustedAmount = self.useScaledTime and (amount * self.timeScale) or amount

	-- Adjust time and timeLeft for all entries, optionally filtered by predicate
	for _, entry in pairs(self.cooldownData) do
		-- Only adjust if predicate is absent or returns true
		if not predicate or predicate(entry) then
			entry.time = math.max(0, entry.time + adjustedAmount)
			entry.timeLeft = math.max(0, entry.timeLeft + adjustedAmount)
		end
	end

	return true
end

--[=[
	Adjust the duration of a specific cooldown.
	@within Cooldowns
	@param keyName string -- The cooldown identifier to adjust
	@param amount number -- Duration adjustment in seconds (can be negative)
	@return boolean -- True if adjusted, false if cooldown doesn't exist
	@error string -- Thrown if amount is missing
]=]
function Methods:AdjustDuration(keyName: string, amount: number): boolean
	if self:Check(keyName) then
		return false
	end

	assert(amount, "Missing amount adjustment for a [" .. keyName .. "] cooldown")

	-- Apply time scaling if enabled
	local adjustedAmount = self.useScaledTime and (amount * self.timeScale) or amount

	-- Adjust the specific entry's duration and remaining time
	local entry = self.cooldownData[keyName]
	entry.time = math.max(0, entry.time + adjustedAmount)
	entry.timeLeft = math.max(0, entry.timeLeft + adjustedAmount)

	return true
end

--[=[
	Clean up and destroy this cooldown instance. Maid-compatible.
	@within Cooldowns
]=]
function Methods:Destroy()
	-- Remove this instance from the global registry
	if self.name and Cooldowns.instances[self.name] then
		Cooldowns.instances[self.name] = nil
	end

	-- Unset the metatable to prevent further method calls
	setmetatable(self, nil)
end

return Cooldowns
