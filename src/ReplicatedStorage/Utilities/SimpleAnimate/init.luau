--!optimize 2
--!nonstrict

--SimpleAnimate.luau

local RunService = game:GetService('RunService')

local Core = require(script.Core)
local Action = require(script.Action)
local DefaultAnims = require(script.DefaultAnims)
local Types = require(script.Types)

local Preload = require(script.Utility.Preload)
local LoadPackage = require(script.Utility.LoadPackage)

local animationControllers = {}
local waitingForController = {}

export type AnimationsList = Types.AnimationsList
export type StateMachine = Types.StateMachine

local function deepCopy(tbl)
	local r = {}

	for i, v in tbl do
		if type(v) == "table" then
			r[i] = deepCopy(v)
			continue
		end
		r[i] = v
	end

	return r
end

local AnimationController = {}
AnimationController.__index = AnimationController

--[[
    Destroys the AnimationController instance and cleans up resources.
    Removes the controller from the global registry.
    
    @param self The AnimationController instance
]]
function AnimationController:Destroy()
	self.Action:Destroy()
	self.Core:Destroy()
	
	self._destroying:Disconnect()
	
	animationControllers[self._rig] = nil
	
	setmetatable(self, nil)
	table.clear(self::any)
end

export type AnimationController = typeof(AnimationController) & {
	Core: Core.Core,
	Action: Action.Action,
}

--[[
    Creates a new AnimationController instance.
    
    @param rig The character model
    @param doPreload Whether to preload the animations (default: true)
    @param coreAnimations Optional custom core animations list (defaults to DefaultAnims.R15)
    @param emoteAnimations Optional custom emote animations list (defaults to DefaultAnims.EmoteAnims)
    @param stateMachine Optional state machine (defaults to Humanoid)
    @return A new AnimationController instance
]]
local function new(rig: Model, doPreload: boolean?, coreAnimations: AnimationsList?, emoteAnimations: AnimationsList?, stateMachine: Types.StateMachine?): AnimationController
	doPreload = if doPreload == nil then true else doPreload
	
	local animator = rig:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		error(`Animator not found for rig {rig}`)
	end
	
	local humanoid = rig:FindFirstChildWhichIsA("Humanoid")
	
	local humanoidAnims, humanoidEmotes
	if coreAnimations then
		humanoidAnims = coreAnimations
	elseif humanoid then
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			humanoidAnims = deepCopy(DefaultAnims.R15.Animations)
		elseif humanoid.RigType == Enum.HumanoidRigType.R6 then
			humanoidAnims = deepCopy(DefaultAnims.R6.Animations)
		end
	else
		humanoidAnims = deepCopy(DefaultAnims.R15.Animations)
	end
	if emoteAnimations then
		humanoidEmotes = emoteAnimations
	elseif humanoid then
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			humanoidEmotes = deepCopy(DefaultAnims.R15.Emotes)
		elseif humanoid.RigType == Enum.HumanoidRigType.R6 then
			humanoidEmotes = deepCopy(DefaultAnims.R6.Emotes)
		end
	else
		humanoidEmotes = deepCopy(DefaultAnims.R15.Emotes)
	end
	
	humanoidAnims = doPreload and Preload.preloadAnimList(animator, humanoidAnims, "core", Enum.AnimationPriority.Core, true) or humanoidAnims
	humanoidEmotes = doPreload and Preload.preloadAnimList(animator, humanoidEmotes, "emote", Enum.AnimationPriority.Action, false) or humanoidEmotes
	
	local core = Core.new(rig, humanoidAnims, stateMachine)
	local action = Action.new(core.PoseController, rig, humanoidEmotes, stateMachine)
	
	local controller = setmetatable({
		Core = core,
		Action = action,
		
		_rig = rig,
	}, AnimationController)
	
	-- Self destruct when rig destroys
	controller._destroying = rig.Destroying:Connect(function()
		controller:Destroy()
	end)
	
	animationControllers[rig] = controller
	
	local waiting = waitingForController[rig]
	if waiting then
		for _, thread in waiting do
			task.spawn(thread, controller)
		end
	end
	
	return controller
end

--[[
    Gets an existing AnimationController for the specified rig.
    
    @param rig The character model to get the controller for
    @return The existing AnimationController or nil if none exists
]]
local function fromExisting(rig: Model): AnimationController?
	return animationControllers[rig]
end

--[[
    Waits for an AnimationController to be created for the specified rig.
    Yields the current thread until a controller is available or timeout occurs.
    
    @param rig The character model to wait for
    @param timeOut Optional timeout in seconds (default: 5)
    @return The AnimationController when available or nil if timeout occurs
]]
local function awaitController(rig: Model, timeOut: number?): AnimationController?
	if animationControllers[rig] then
		return animationControllers[rig]
	end
	timeOut = timeOut or 5
	
	waitingForController[rig] = waitingForController[rig] or {}
	local waitlist = waitingForController[rig]
	
	local running = coroutine.running()
	
	waitlist[#waitlist + 1] = running
	
	task.delay(timeOut, function()
		if coroutine.status(running) ~= "suspended" then return end
		table.remove(waitlist, table.find(waitlist, running))
		warn(`Infinite yield possible while waiting for {rig} controller.`)
	end)
	
	return coroutine.yield()
end

--[[
    Gets a deep copy of a default animation list by name.
    
    @param name The name of the default animation list to copy
    @param specifier The list you want to retrieve (Animations or Emotes)
    @return A deep copy of the requested animation list
    @throws Error if the requested animation list doesn't exist
]]
local function getCopyOfAnimsList(name: "R6" | "R15", specifier: "Animations" | "Emotes"): Types.AnimationsList
	local module = DefaultAnims[name]
	if not module then error(`{name} is not a valid default animation list.`) end
	
	local list = module[specifier]
	if not list then error(`{specifier} is not a valid default animation list specifier.`) end
	
	return deepCopy(list)
end

--[[
    Gets a deep copy of both default animation lists (Animations and Emotes) by name.
    
    @param name The name of the default animation list to copy
    @return A deep copy of the requested animation list
    @throws Error if the requested animation list doesn't exist
]]
local function getCopyOfAnims(name: "R6" | "R15"): (Types.AnimationsList, Types.AnimationsList)
	local module = DefaultAnims[name]
	if not module then error(`{name} is not a valid default animation list.`) end
	
	return deepCopy(module.Animations), deepCopy(module.Emotes)
end

--[[
	<em><strong>*Yields*</strong></em>
	<em><strong>*R15 Only*</strong></em>
	
	Fetches a player's animation package from the cloud.
	
	@param player The player who owns the animation package, should be nil if this function is called from the client.
	@param defaultPoseSourceIfUnavailable The AnimationsList to fall back on incase a pose is missing from the package, such as Jumping.
	@return The new AnimationsList containing the player's currently equipped animation package
]]
local function getAnimPackageAsync(player: Player?, defaultPoseSourceIfUnavailable: Types.AnimationsList?): Types.AnimationsList
	if typeof(player) ~= "Instance" and RunService:IsServer() then
		error("When calling getAnimPackageAsync from the server, the first argument must be a player.")
	end
	
	local defaultPoseSourceIfUnavailable = defaultPoseSourceIfUnavailable or deepCopy(DefaultAnims.R15.Animations)
	
	local list = if RunService:IsClient() then script.Async:WaitForChild("LoadAnimPackage"):InvokeServer() else LoadPackage.getPlayerAnimPackage(player)

	for name, animations in defaultPoseSourceIfUnavailable do
		if list[name] ~= nil then continue end

		list[name] = animations
	end

	return list
end

--[[
	<em><strong>*Yields*</strong></em>
	<em><strong>*R15 Only*</strong></em>
	
	Fetches a player's emote package from the cloud.
	
	@param player The player who owns the emote package, should be nil if this function is called from the client.
	@param defaultPoseSourceIfUnavailable The AnimationsList to fall back on incase an emote is missing from the package, such as Wave.
	@return The new AnimationsList containing the player's currently equipped emote package
]]
local function getEmotePackageAsync(player: Player?, defaultEmoteSourceIfUnavailable: Types.AnimationsList?): Types.AnimationsList
	if typeof(player) ~= "Instance" and RunService:IsServer() then
		error("When calling getEmotePackageAsync from the server, the first argument must be a player.")
	end
	local defaultEmoteSourceIfUnavailable = defaultEmoteSourceIfUnavailable or deepCopy(DefaultAnims.R15.Animations)
	
	local list = if RunService:IsClient() then script.Async:WaitForChild("LoadEmotePackage"):InvokeServer() else LoadPackage.getPlayerEmotePackage(player)
	
	for name, animations in defaultEmoteSourceIfUnavailable do
		if list[name] ~= nil then continue end
		
		list[name] = animations
	end
	
	return list
end

return {
	new = new,
	fromExisting = fromExisting,
	awaitController = awaitController,
	getCopyOfAnimsList = getCopyOfAnimsList,
	getCopyOfAnims = getCopyOfAnims,
	
	getAnimPackageAsync = getAnimPackageAsync,
	getEmotePackageAsync = getEmotePackageAsync,
	
	Preload = Preload,
	default = DefaultAnims
}