--!optimize 2
--PoseController.luau

local utility = script.Parent.Parent.Utility
local parent = script.Parent.Parent

local Types = require(parent.Types)
local Signal = require(parent.Utility.SimpleSignal)
local Preload = require(parent.Utility.Preload)
local Switch = require(parent.Utility.Switch)
local randomWeighted = require(parent.Utility.RandomWeighted)

type PoseType = Types.PoseType

local function isAction(track: AnimationTrack)
	local priority = track.Priority

	return priority.Name:find("Action") ~= nil
end

local PoseController = {}
PoseController.__index = PoseController

--[[
    Sets whether the internal core state can play animations.
    @param value boolean - Whether core animations should be active
]]
function PoseController:SetCoreCanPlayAnims(value: boolean)
	self._playAnims = value
end

--[[
    Gets whether the internal core state can play animations.
    @return boolean - Whether core animations should be active
]]
function PoseController:GetCoreCanPlayAnims(): boolean
	return self._playAnims
end

--[[
    Sets whether the internal core state is automatically changed.
    @param value boolean - Whether core state should be active
]]
function PoseController:SetCoreActive(value: boolean): ()
	self._active = value
end

--[[
    Gets whether the internal core state is automatically changed.
    @return boolean - Whether core state is active
]]
function PoseController:GetCoreActive(): boolean
	return self._active
end

--[[
    Gets the currently playing animation track.
    @return AnimationTrack - The current animation track
]]
function PoseController:GetCurrentTrack(): AnimationTrack
	return self._track
end

--[[
    Gets the current pose type.
    @return PoseType - The current pose
]]
function PoseController:GetPose(): PoseType?
	return self._lastPose
end

--[[
    Enables or disables a specific pose.
    @param pose PoseType - The pose to enable/disable
    @param enabled boolean - Whether the pose should be enabled
]]
function PoseController:SetPoseEnabled(pose: PoseType, enabled: boolean): ()
	self._disabled[pose] = not enabled
end

--[[
    Gets the animation information for a specific pose.
    @param pose PoseType - The pose to get animations for
    @return {Types.AnimInfo} - Array of animation info for the pose
]]
function PoseController:GetCoreAnimInfos(pose: PoseType): {Types.AnimInfo}
	return self._anims[pose]
end

--[[
    Changes a core animation for a specific pose.
    
    @param pose PoseType - The pose to change
    @param index number - The index of the animation to change
    @param new Animation | string | AnimationTrack | Types.AnimInfo - The new animation
        Can be a table (<code>Types.AnimInfo</code>), a string (AnimationId), 
        an <code>Animation</code> instance, or an <code>AnimationTrack</code>
    @return AnimationTrack - The new animation track (if created)
]]
function PoseController:ChangeCoreAnim(pose: PoseType, index: number, new: Animation | string | AnimationTrack | Types.AnimInfo): AnimationTrack
	local track: AnimationTrack

	if type(new) == "table" then
		self._anims[pose][index] = new
		
		track = assert(new.anim)
	elseif type(new) == "string" then
		local animation = Instance.new("Animation")
		animation.AnimationId = new

		track = self._animator:LoadAnimation(animation)
		track.Name = "core"
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Core

		self._anims[pose][index].anim = track
	elseif typeof(new) == "Instance" and new:IsA("Animation") then
		track = self._animator:LoadAnimation(new)
		track.Name = "core"
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Core

		self._anims[pose][index].anim = track
	elseif typeof(new) == "Instance" and new:IsA("AnimationTrack") then
		track = new

		self._anims[pose][index].anim = track
	else
		error(`Invalid value for :ChangeCoreAnim ({new})`)
	end

	if self._lastPose == pose then
		self._track:Stop()
		self:PlayCoreAnimation(pose)
	end

	return track
end

--[[
    Gets a random animation track for the specified pose, weighted by the
    animation weights in the pose's animation info.
    
    @param pose PoseType - The pose to get an animation for
    @return AnimationTrack - A randomly selected animation track for the pose
]]
function PoseController:GetRandomCoreAnim(pose: PoseType): AnimationTrack
	return randomWeighted(self._anims[pose])
end

--[[
    Stops all currently playing core animations.
    
    @param fadeTime number? - Optional fade time for stopping animations
]]
function PoseController:StopCoreAnimations(fadeTime: number?)
	if not self._animator then return end
	for i, v: AnimationTrack in self._animator:GetPlayingAnimationTracks() do
		if isAction(v) and v.Name ~= "emote" then
			continue
		end
		v:Stop(fadeTime)
	end
end

--[[
    Plays an animation for the specified pose.
    
    @param pose PoseType - The pose to play an animation for
    @param speed number? - Optional playback speed (defaults to 1)
    @param fadeTime number? - Optional fade time for animation transitions
]]
function PoseController:PlayCoreAnimation(pose: PoseType, looped: boolean?, speed: number?, fadeTime: number?): ()
	if not self._animator then return end

	speed = speed or 1
	looped = if looped == nil then true else looped

	local newTrack, numInfo, info = self:GetRandomCoreAnim(pose)
	self:StopCoreAnimations(self._lastInfo.stopFadeTime or 0.1)

	newTrack:Play(info.fadeTime or 0.1, 1, info.speed or speed)

	self._track = newTrack

	-- Playing a new animation every loop
	if numInfo > 1 and looped then
		newTrack.DidLoop:Once(function()
			if self._active and self._lastPose == pose then
				self:PlayCoreAnimation(pose, speed)
			end
		end)
	end
	return info
end

--[[
    Cleans up and destroys the <code>PoseController</code> instance.
]]
function PoseController:Destroy(): ()
	self:StopCoreAnimations()
	self.PoseChanged:Destroy()
	self._active = false

	setmetatable(self, nil)
	table.clear(self)
end

--[[
    Changes the character's pose.
    
    @param pose PoseType - The pose to change to
    @param speed number? - Optional playback speed
    @param isCore boolean? - Whether this is a core pose change
        If <strong>true</strong> and core animations are disabled, the pose won't change
]]
function PoseController:ChangePose(pose: PoseType, speed: number?, isCore: boolean?): ()
	if self._disabled[pose] then return end
	if isCore and not self._active then return end

	self._switch:Switch(pose, speed or 1)
end

export type PoseController = typeof(PoseController) & {
	PoseChanged		: Signal.RBXScriptSignal<PoseType, PoseType, AnimationTrack>
}

--[[
    Creates a new <code>PoseController</code> instance.
    
    @param rig Model - The character model with an Animator
    @param coreAnimations Types.AnimationsList - List of animations for each pose type
    @return PoseController - A new pose controller instance
    
    @error If no Animator is found in the rig
]]
local function new(rig: Model, coreAnimations: Types.AnimationsList) : PoseController
	local animator = rig:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		error(`Animator not found for rig {rig}`)
	end

	local controller = setmetatable({
		_animator = animator,
		_anims = coreAnimations,
		_rig = rig,

		_active = true,
		_playAnims = true,
		_lastPose = "",
		_lastInfo = {},
		_track = false,

		_disabled = {},

		PoseChanged = Signal.new()
	}, PoseController)
	
	controller._switch = Switch.new("", function(pose, speed: number?)
		local lastPose = controller._lastPose
		local info
		if controller._playAnims then
			info = controller:PlayCoreAnimation(pose, speed)
		end
		
		controller.PoseChanged:Fire(lastPose, pose, controller._track)
		
		controller._lastPose = pose
		controller._lastInfo = info or {}
	end)

	-- Initialize pose to idle
	controller:ChangePose("Idle")

	return controller
end

return {
	new = new
}