--!optimize 2
--!nonstrict

--Action.luau

local utility = script.Parent.Utility
local Types = require(script.Parent.Types)

local Preload = require(utility.Preload)
local randomWeighted = require(utility.RandomWeighted)

local function resume(self, endTriggers, track: AnimationTrack)
	track:Stop()
	for _, v in endTriggers do
		v:Disconnect()
	end
	table.clear(endTriggers)
	
	local PoseController = self._controller
	
	if PoseController:GetCoreCanPlayAnims() then return end

	PoseController:SetCoreCanPlayAnims(true)
end

local function setupAnimEndTrigger(self, track: AnimationTrack)
	local endTriggers = self._endTriggers
	-- If the player moves or the emote ends resume core activity
	table.insert(endTriggers, track.Stopped:Once(function()
		resume(self, endTriggers, track)
	end))
	table.insert(endTriggers, self._humanoid.StateChanged:Once(function()
		resume(self, endTriggers, track)
	end))
	table.insert(endTriggers, self._humanoid.Running:Once(function()
		resume(self, endTriggers, track)
	end))
end

local Action = {}
Action.__index = Action

--[[
    Creates a new action animation and adds it to the actions collection.
    
    @param self The Action instance
    @param key The key of the action (can be anything)
    @param template Table of animation information
    @param doPreload Whether to preload the animations (default: true)
    @param priority Animation priority level (default: Enum.AnimationPriority.Action)
    @return The preloaded animation information table
]]
function Action:CreateAction(key: any, template: {Types.AnimInfo}, doPreload: boolean?, priority: Enum.AnimationPriority?, looped: boolean?): {Types.AnimInfo}
	local doPreload = if doPreload == nil then true else doPreload
	local priority = priority or Enum.AnimationPriority.Action
	local looped = if looped == nil then false else looped
	
	local anims = doPreload and Preload.preloadAnimArray(self._animator, template, key, priority, looped) or template
	
	self._actions[key] = anims
	
	return anims
end

--[[
    Creates multiple actions at once from a list.
    
    @param self The Action instance
    @param animsList The list of animations to create
    @param doPreload Whether to preload the animations (default: true)
    @param priority Animation priority level (default: Enum.AnimationPriority.Action)
    @return Array of preloaded animation information tables
]]
function Action:BulkCreateAction(animsList: Types.AnimationsList, doPreload: boolean?, priority: Enum.AnimationPriority?, looped: boolean?): Types.AnimationsList
	local anims = {}
	for key, list in animsList do
		anims[key] = self:CreateAction(key, list, doPreload, priority, looped)
	end
	return anims
end

--[[
    Removes and destroys an action by key.
    
    @param self The Action instance
    @param key The key of the action to remove
]]
function Action:RemoveAction(key: any): ()
	local list: {Types.AnimInfo} = self._actions[key]
	
	if not list then 
		error(`Action {key} has not been created yet. (:RemoveAction)`)
		return
	end
	
	for _, info in list do
		info.anim:Stop()
		info.anim:Destroy()
	end
	
	self._actions[key] = nil
end

--[[
    Stops all animations for a specific action.
    
    @param self The Action instance
    @param key The key of the action to stop
]]
function Action:StopAction(key: any, fadeTime: number?): ()
	local list: {Types.AnimInfo} = self._actions[key]

	if not list then 
		error(`Action {key} has not been created yet. (:StopAllActions)`)
		return
	end
	
	for _, info in list do
		info.anim:Stop(fadeTime)
	end
end

--[[
    Gets an action (an array of animation infos) by name.
    
    @param self The Action instance
    @param key The key of the action to get
    @return The animation information table or nil if not found
]]
function Action:GetAction(key: any): {Types.AnimInfo}?
	return self._actions[key]
end

--[[
    Gets a random animation from an action's animations.
    
    @param self The Action instance
    @param key The key of the action to get a random animation from
    @return A random animation track from the action
]]
function Action:GetRandomActionAnim(key: any): AnimationTrack
	local list: {Types.AnimInfo} = self._actions[key]

	if not list then 
		error(`Action {key} has not been created yet. (:GetRandomActionAnim)`)
	end
	
	local track = randomWeighted(list)
	
	return track
end

--[[
	Plays a random animation from an action's animations and returns it.
	
	@param self The Action instance
	@param key The key of the action to play a random animation from
	@return A random animation track from the action
]]
function Action:PlayRandomActionAnim(key: any): AnimationTrack
	local track = self:GetRandomActionAnim(key)
	track:Play()
	return track
end

Action.PlayAction = Action.PlayRandomActionAnim :: typeof(
	--[[
		A shorter alias for <code>Action:PlayRandomActionAnim()</code>.
	]]
	function(self: Action, key: any): AnimationTrack return nil::any end
)

--[[
    Sets up the emote bindable function for handling emote animations.
    
    @param self The Action instance
    @param e The bindable function to set up
]]
function Action:SetEmoteBindable(e: BindableFunction)
	function e.OnInvoke(emote: string | Animation)
		for _, v in self._endTriggers do
			v:Disconnect()
		end
		table.clear(self._endTriggers)
		
		local PoseController = self._controller
		
		if PoseController:GetPose() ~= "Idle" then
			return false
		end
		
		PoseController:SetCoreCanPlayAnims(false)
		local name = typeof(emote) == "Instance" and emote.Name or emote
		
		if self._emotes[name] ~= nil then
			local emoteAnim: AnimationTrack, _, info = randomWeighted(self._emotes[name])
			PoseController:StopCoreAnimations(info.fadeTime or 0.1)
			
			emoteAnim:Play(0.1, 1, info.speed or 1)
			setupAnimEndTrigger(self, emoteAnim)

			return true, emoteAnim
		elseif typeof(emote) == "Instance" and emote:IsA("Animation") then
			PoseController:StopCoreAnimations()
			
			local track = self._animator:LoadAnimation(emote)
			track.Looped = false
			track.Priority = Enum.AnimationPriority.Action2
			track:Play(0.1, 1, 1)
			
			setupAnimEndTrigger(self, track)
			
			self._emotes[emote.Name] = {
				id = emote.AnimationId,
				weight = 10,
				anim = track
			}
			
			return true, track
		end
		
		return false
	end
end

--[[
    Cleans up and destroys the Action instance.
    
    @param self The Action instance
]]
function Action:Destroy()
	for _, track in self._actions do
		track:Destroy()
	end
	
	setmetatable(self, nil)
	table.clear(self)
	self = nil
end

export type Action = typeof(Action)

--[[
    Creates a new Action instance.
    
    @param PoseController The pose controller to use
    @param rig The character rig model
    @param emoteAnimations The list of emote animations
    @param stateMachine Optional state machine (defaults to Humanoid)
    @return A new Action instance
]]
local function new(PoseController, rig: Model, emoteAnimations: Types.AnimationsList, stateMachine: Types.StateMachine?) : Action
	local animator = rig:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		error(`Animator not found for rig {rig}`)
	end
	
	local humanoid = stateMachine or rig:FindFirstChildWhichIsA("Humanoid", true)
	if not humanoid then
		error(`Humanoid not found for rig {rig}`)
	end
	
	return setmetatable({
		_controller = PoseController,
		_animator = animator,
		_humanoid = humanoid,
		_emotes = emoteAnimations,
		_actions = {},
		_endTriggers = {},
	}, Action) :: any
end

return {
	new = new
}