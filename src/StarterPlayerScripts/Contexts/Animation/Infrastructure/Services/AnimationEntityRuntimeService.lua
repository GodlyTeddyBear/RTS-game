--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimationProfileRegistry = require(ReplicatedStorage.Contexts.Animation.Config.AnimationProfileRegistry)
local AnimationSetCompiler = require(ReplicatedStorage.Contexts.Animation.Config.AnimationSetCompiler)
local RenderAssetAccess = require(ReplicatedStorage.Contexts.Render.RenderAssetAccess)
local SimpleAnimate = require(ReplicatedStorage.Utilities.SimpleAnimate)

local AnimationProfileComponentIdentity = require(script.Parent.Parent.AnimationProfileComponentIdentity)
local AnimationRigResolver = require(script.Parent.Parent.AnimationRigResolver)
local EntityAnimationStateAdapter = require(script.Parent.Parent.EntityAnimationStateAdapter)
local IKControlAimRuntime = require(script.Parent.Parent.IKControlAimRuntime)
local LeanSystem = require(script.Parent.Parent.LeanSystem)
local Motor6DAimRuntime = require(script.Parent.Parent.Motor6DAimRuntime)

local AnimationEntityRuntimeService = {}
AnimationEntityRuntimeService.__index = AnimationEntityRuntimeService

local CORE_PRIORITY = Enum.AnimationPriority.Core
local DEFAULT_CHANNEL = "FullBody"
local LOCOMOTION_SPEED_DIVISOR = 12

local function _GetMoveSpeed(model: Model): number
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	end
	return 0
end

local function _MergeFeaturePolicy(profileFeatures: any, overrides: any): any
	local merged = {}
	if type(profileFeatures) == "table" then
		for key, value in pairs(profileFeatures) do
			merged[key] = value
		end
	end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			merged[key] = value
		end
	end
	return merged
end

local function _IsEnabledFeature(feature: any): boolean
	if type(feature) ~= "table" then
		return false
	end
	if feature.Enabled == false then
		return false
	end
	return true
end

function AnimationEntityRuntimeService.new(animationController: any, entityController: any)
	return setmetatable({
		_animationController = animationController,
		_entityController = entityController,
		_runtimeByEntity = {},
		_localRevision = 0,
	}, AnimationEntityRuntimeService)
end

function AnimationEntityRuntimeService:Reconcile()
	local records = self._entityController:GetByTag("Animation.EnabledTag")

	local activeEntities = {}
	for _, record in ipairs(records) do
		activeEntities[record.Entity] = true
		self:_EnsureRuntime(record)
	end

	for entity, runtime in pairs(self._runtimeByEntity) do
		if activeEntities[entity] ~= true or runtime.Model.Parent == nil then
			self:Remove(entity)
		end
	end
end

function AnimationEntityRuntimeService:Setup()
	for _, runtime in pairs(self._runtimeByEntity) do
		if runtime.State == "Pending" then
			self:_SetupRuntime(runtime)
		end
	end
end

function AnimationEntityRuntimeService:LoadClips()
	for _, runtime in pairs(self._runtimeByEntity) do
		if runtime.State == "Ready" then
			self:_LoadRequiredClips(runtime)
		end
	end
end

function AnimationEntityRuntimeService:UpdateLocomotion()
	for _, runtime in pairs(self._runtimeByEntity) do
		if runtime.State == "Ready" and runtime.EntityStateAdapter ~= nil then
			self:_UpdateEntityStateAdapter(runtime)
		end
	end
end

function AnimationEntityRuntimeService:UpdateActions()
	for _, runtime in pairs(self._runtimeByEntity) do
		if runtime.State == "Ready" then
			self:_UpdateActionChannels(runtime)
		end
	end
end

function AnimationEntityRuntimeService:UpdateProcedural()
	for _, runtime in pairs(self._runtimeByEntity) do
		if runtime.State == "Ready" then
			self:_EnsureAim(runtime)
		end
	end
end

function AnimationEntityRuntimeService:UpdateRender()
	for _, runtime in pairs(self._runtimeByEntity) do
		if runtime.State == "Ready" then
			self:_EnsureLean(runtime)
		end
	end
end

function AnimationEntityRuntimeService:Cleanup()
	for entity, runtime in pairs(self._runtimeByEntity) do
		if self._entityController:GetEntity(entity) == nil or runtime.Model.Parent == nil then
			self:Remove(entity)
		end
	end
end

function AnimationEntityRuntimeService:RequestLocalAction(entity: number, actionId: string, channelId: string?): boolean
	local runtime = self._runtimeByEntity[entity]
	if runtime == nil or runtime.State ~= "Ready" then
		return false
	end

	local resolvedChannelId = channelId or DEFAULT_CHANNEL
	local channel = runtime.Profile.Channels[resolvedChannelId]
	if type(channel) ~= "table" or channel.AllowLocalRequests ~= true then
		return false
	end

	self._localRevision += 1
	runtime.LocalChannels[resolvedChannelId] = {
		ActionId = actionId,
		Revision = self._localRevision,
		StartedAt = Workspace:GetServerTimeNow(),
		PlaybackSpeed = 1,
	}
	return true
end

function AnimationEntityRuntimeService:CancelLocalAction(entity: number, channelId: string?): boolean
	local runtime = self._runtimeByEntity[entity]
	if runtime == nil then
		return false
	end
	runtime.LocalChannels[channelId or DEFAULT_CHANNEL] = nil
	return true
end

function AnimationEntityRuntimeService:Remove(entity: number)
	local runtime = self._runtimeByEntity[entity]
	if runtime == nil then
		return
	end

	for _, cleanup in ipairs(runtime.Cleanups) do
		cleanup()
	end
	for _, channelState in pairs(runtime.ActiveChannels) do
		if channelState.Track ~= nil then
			channelState.Track:Stop(0)
		end
	end
	if runtime.SimpleAnimateController ~= nil and type(runtime.SimpleAnimateController.Destroy) == "function" then
		runtime.SimpleAnimateController:Destroy()
	end
	if runtime.EntityStateAdapter ~= nil then
		runtime.EntityStateAdapter:Destroy()
	end
	self._runtimeByEntity[entity] = nil
end

function AnimationEntityRuntimeService:Destroy()
	for entity in pairs(self._runtimeByEntity) do
		self:Remove(entity)
	end
end

function AnimationEntityRuntimeService:_EnsureRuntime(record: any)
	local profileComponent = record.Components["Animation.Profile"]
	if type(profileComponent) ~= "table" then
		return
	end

	local model = self._entityController:FindInstanceByEntity(record.Entity)
	if model == nil or not model:IsA("Model") then
		return
	end

	local existing = self._runtimeByEntity[record.Entity]
	if existing ~= nil then
		if existing.Model == model and AnimationProfileComponentIdentity.Matches(existing.ProfileComponentSnapshot, profileComponent) then
			existing.Record = record
			existing.ProfileComponent = profileComponent
			return
		end
		self:Remove(record.Entity)
	end

	self._runtimeByEntity[record.Entity] = {
		Entity = record.Entity,
		Record = record,
		Model = model,
		ProfileComponent = profileComponent,
		ProfileComponentSnapshot = AnimationProfileComponentIdentity.Snapshot(profileComponent),
		Profile = nil,
		CompiledSet = nil,
		Animator = nil,
		Humanoid = nil,
		SimpleAnimateController = nil,
		EntityStateAdapter = nil,
		TracksBySlot = {},
		ActiveChannels = {},
		LocalChannels = {},
		Cleanups = {},
		State = "Pending",
		FailedReason = nil,
	}
end

function AnimationEntityRuntimeService:_SetupRuntime(runtime: any)
	local ok, profile = pcall(AnimationProfileRegistry.Get, runtime.ProfileComponent.ProfileId)
	if not ok then
		runtime.State = "Failed"
		runtime.FailedReason = tostring(profile)
		warn("[AnimationEntityRuntime]", runtime.Entity, runtime.FailedReason)
		return
	end

	local setId = runtime.ProfileComponent.AnimationSetId or profile.DefaultSetId
	local compileOk, compiledSet = pcall(AnimationSetCompiler.Compile, setId, runtime.ProfileComponent.VariantId)
	if not compileOk then
		runtime.State = "Failed"
		runtime.FailedReason = tostring(compiledSet)
		warn("[AnimationEntityRuntime]", runtime.Entity, runtime.FailedReason)
		return
	end

	if profile.DisableDefaultAnimate == true then
		local defaultAnimate = runtime.Model:FindFirstChild("Animate")
		if defaultAnimate ~= nil then
			defaultAnimate:Destroy()
		end
	end

	local rig = AnimationRigResolver.Resolve(runtime.Model, profile.RigAdapter)
	if rig == nil then
		runtime.State = "Failed"
		runtime.FailedReason = ("Animation rig '%s' not found"):format(profile.RigAdapter)
		warn("[AnimationEntityRuntime]", runtime.FailedReason, "for", runtime.Model:GetFullName())
		return
	end

	runtime.Profile = profile
	runtime.CompiledSet = compiledSet
	runtime.Animator = rig.Animator
	runtime.Humanoid = rig.Humanoid or runtime.Model:FindFirstChildWhichIsA("Humanoid", true)
	runtime.Features = _MergeFeaturePolicy(profile.Features, runtime.ProfileComponent.FeatureOverrides)
	runtime.State = "Ready"
end

function AnimationEntityRuntimeService:_LoadRequiredClips(runtime: any)
	if runtime.HasLoadedRequiredClips == true then
		return
	end

	local requiredSlots = runtime.Profile.RequiredSlots or {}
	for _, slotId in ipairs(requiredSlots) do
		if self:_GetTrack(runtime, slotId, CORE_PRIORITY) == nil then
			warn(("[AnimationEntityRuntime] required animation slot '%s' missing for entity %s"):format(slotId, runtime.Entity))
		end
	end

	self:_EnsureSimpleAnimateController(runtime)
	runtime.HasLoadedRequiredClips = true
end

function AnimationEntityRuntimeService:_EnsureSimpleAnimateController(runtime: any)
	if runtime.SimpleAnimateController ~= nil then
		return
	end

	local coreAnimations = {}
	for poseName, slotId in pairs(runtime.Profile.CorePoseSlots or {}) do
		local track = self:_GetTrack(runtime, slotId, CORE_PRIORITY)
		if track ~= nil then
			track.Looped = true
			coreAnimations[poseName] = {
				{
					id = slotId,
					weight = 1,
					anim = track,
				},
			}
		end
	end

	local stateMachine = self:_ResolveStateMachine(runtime)
	local ok, controller = pcall(SimpleAnimate.new, runtime.Model, false, coreAnimations, {}, stateMachine, runtime.Animator)
	if ok then
		runtime.SimpleAnimateController = controller
		self:_ConfigureSimpleAnimateController(controller, runtime.Profile)
	else
		if runtime.EntityStateAdapter ~= nil then
			runtime.EntityStateAdapter:Destroy()
			runtime.EntityStateAdapter = nil
		end
		warn("[AnimationEntityRuntime] SimpleAnimate controller failed:", tostring(controller))
	end
end

function AnimationEntityRuntimeService:_ResolveStateMachine(runtime: any): any
	if runtime.Profile.LocomotionProvider == "HumanoidState" and runtime.Humanoid ~= nil then
		return runtime.Humanoid
	end

	local stateAdapter = EntityAnimationStateAdapter.new()
	runtime.EntityStateAdapter = stateAdapter
	return stateAdapter
end

function AnimationEntityRuntimeService:_ConfigureSimpleAnimateController(controller: any, profile: any)
	controller.Core.PoseController:SetPoseFallbacks(profile.CorePoseFallbacks or {})

	local connections = controller.Core.Connections
	connections.AutoAdjustSpeedMultipliers = false
	connections.UseWalkSpeedForAnimSpeed = false
	connections.MoveAnimationSpeedMultiplier = 1 / LOCOMOTION_SPEED_DIVISOR
	connections.ClimbAnimationSpeedMultiplier = 1 / LOCOMOTION_SPEED_DIVISOR
	connections.SwimAnimationSpeedMultiplier = 1 / LOCOMOTION_SPEED_DIVISOR
end

function AnimationEntityRuntimeService:_GetTrack(runtime: any, slotId: string, priority: Enum.AnimationPriority): AnimationTrack?
	local existing = runtime.TracksBySlot[slotId]
	if existing ~= nil then
		return existing
	end

	local clipKey = runtime.CompiledSet.Slots[slotId]
	if type(clipKey) ~= "string" or clipKey == "" then
		return nil
	end

	local animation = RenderAssetAccess.GetAnimationClip(clipKey, runtime.CompiledSet.VariantId, nil)
	if animation == nil then
		animation = RenderAssetAccess.GetAnimationClip(clipKey, "Default", nil)
	end
	if animation == nil then
		return nil
	end

	local ok, track = pcall(function()
		return runtime.Animator:LoadAnimation(animation)
	end)
	if not ok then
		warn("[AnimationEntityRuntime] failed to load clip", clipKey, tostring(track))
		return nil
	end

	track.Priority = priority
	runtime.TracksBySlot[slotId] = track
	return track
end

function AnimationEntityRuntimeService:_UpdateEntityStateAdapter(runtime: any)
	if runtime.Profile.LocomotionProvider == "None" then
		return
	end

	local applyResult = runtime.Record.Components["Movement.ApplyResult"]
	local isMoving = type(applyResult) == "table" and applyResult.IsMoving == true
	runtime.EntityStateAdapter:UpdateRunning(isMoving, _GetMoveSpeed(runtime.Model))
end

function AnimationEntityRuntimeService:_UpdateActionChannels(runtime: any)
	local replicatedChannels = runtime.Record.Components["Animation.ActionChannels"]
	local channels = if type(replicatedChannels) == "table" then table.clone(replicatedChannels) else {}
	for channelId, state in pairs(runtime.LocalChannels) do
		channels[channelId] = state
	end

	for channelId, active in pairs(runtime.ActiveChannels) do
		if channels[channelId] == nil then
			active.Track:Stop(active.FadeOut)
			self:_EmitMarker(runtime, {
				ActionId = active.ActionId,
				ChannelId = channelId,
				MarkerName = "ActionStopped",
			})
			runtime.ActiveChannels[channelId] = nil
		end
	end

	for channelId, state in pairs(channels) do
		if type(state) ~= "table" or type(state.ActionId) ~= "string" or state.ActionId == "" then
			continue
		end
		self:_PlayChannelState(runtime, channelId, state)
	end
end

function AnimationEntityRuntimeService:_PlayChannelState(runtime: any, channelId: string, state: any)
	local channel = runtime.Profile.Channels[channelId] or runtime.Profile.Channels[DEFAULT_CHANNEL]
	if type(channel) ~= "table" then
		return
	end

	local slotId = runtime.CompiledSet.Slots[state.ActionId] ~= nil and state.ActionId or channel.SlotId
	local track = self:_GetTrack(runtime, slotId, channel.Priority)
	if track == nil then
		return
	end

	local active = runtime.ActiveChannels[channelId]
	if active ~= nil and active.Track == track and active.Revision == state.Revision and active.ActionId == state.ActionId then
		return
	end
	if active ~= nil then
		active.Track:Stop(active.FadeOut)
	end

	local fadeIn = channel.FadeIn or 0.1
	local playbackSpeed = if type(state.PlaybackSpeed) == "number" then state.PlaybackSpeed else 1
	track.Looped = channel.Looped == true
	track:Play(fadeIn, 1, playbackSpeed)

	if type(state.StartedAt) == "number" and track.Length > 0 then
		local elapsed = math.max(Workspace:GetServerTimeNow() - state.StartedAt, 0)
		if track.Looped then
			track.TimePosition = elapsed % track.Length
		elseif elapsed < track.Length then
			track.TimePosition = elapsed
		end
	end

	runtime.ActiveChannels[channelId] = {
		Track = track,
		ActionId = state.ActionId,
		Revision = state.Revision,
		FadeOut = channel.FadeOut or 0.1,
	}
	self:_EmitMarker(runtime, {
		ActionId = state.ActionId,
		ChannelId = channelId,
		MarkerName = "ActionStarted",
	})
end

function AnimationEntityRuntimeService:_EmitMarker(runtime: any, payload: any)
	if self._animationController == nil or type(self._animationController._EmitMarker) ~= "function" then
		return
	end
	payload.Entity = runtime.Entity
	payload.Model = runtime.Model
	self._animationController:_EmitMarker(payload)
end

function AnimationEntityRuntimeService:_EnsureAim(runtime: any)
	if runtime.AimStarted == true then
		return
	end
	runtime.AimStarted = true

	local aim = runtime.Features and runtime.Features.Aim
	if not _IsEnabledFeature(aim) then
		return
	end

	local aimRuntime = if aim.Strategy == "Motor6D" then Motor6DAimRuntime else IKControlAimRuntime
	local cleanup = aimRuntime.Start({
		Model = runtime.Model,
		Strategy = aim.Strategy or "IKControl",
		RigConfig = aim,
		Context = {
			Entity = runtime.Entity,
		},
		GetTargetWorldPosition = function()
			local record = self._entityController:GetEntity(runtime.Entity)
			local target = if record ~= nil and type(record.Components) == "table"
				then record.Components["Entity.Target"]
				else record and record.Target
			local targetEntity = if type(target) == "table" then target.TargetEntity else nil
			if type(targetEntity) ~= "number" then
				return nil
			end
			local targetModel = self._entityController:FindInstanceByEntity(targetEntity)
			return if targetModel ~= nil and targetModel:IsA("Model") then targetModel:GetPivot().Position else nil
		end,
	})
	if cleanup ~= nil then
		table.insert(runtime.Cleanups, cleanup)
	end
end

function AnimationEntityRuntimeService:_EnsureLean(runtime: any)
	if runtime.LeanStarted == true then
		return
	end
	runtime.LeanStarted = true

	if _IsEnabledFeature(runtime.Features and runtime.Features.Lean) then
		table.insert(runtime.Cleanups, LeanSystem.start(runtime.Model))
	end
end

return AnimationEntityRuntimeService
