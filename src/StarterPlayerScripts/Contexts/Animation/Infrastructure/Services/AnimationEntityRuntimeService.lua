--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimationProfileRegistry = require(ReplicatedStorage.Contexts.Animation.Config.AnimationProfileRegistry)
local AnimationSetCompiler = require(ReplicatedStorage.Contexts.Animation.Config.AnimationSetCompiler)
local RenderAssetAccess = require(ReplicatedStorage.Contexts.Render.RenderAssetAccess)
local PoseController = require(ReplicatedStorage.Utilities.SimpleAnimate.Core.PoseController)

local IKControlAimRuntime = require(script.Parent.Parent.IKControlAimRuntime)
local LeanSystem = require(script.Parent.Parent.LeanSystem)
local Motor6DAimRuntime = require(script.Parent.Parent.Motor6DAimRuntime)

local AnimationEntityRuntimeService = {}
AnimationEntityRuntimeService.__index = AnimationEntityRuntimeService

local DEBUG_PREFIX = "[AnimationPipeline]"
local CORE_PRIORITY = Enum.AnimationPriority.Core
local DEFAULT_CHANNEL = "FullBody"

local function _FindAnimator(model: Model): Animator?
	return model:FindFirstChildWhichIsA("Animator", true)
end

local function _FindHumanoid(model: Model): Humanoid?
	return model:FindFirstChildOfClass("Humanoid")
end

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
		_debugOnce = {},
		_lastReconcileCount = nil,
	}, AnimationEntityRuntimeService)
end

function AnimationEntityRuntimeService:Reconcile()
	local records = self._entityController:GetByTag("Animation.EnabledTag")
	local recordCount = #records
	if self._lastReconcileCount ~= recordCount then
		self._lastReconcileCount = recordCount
		warn(DEBUG_PREFIX, "reconcile animation records", recordCount)
	end

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
		if runtime.State == "Ready" and runtime.PoseController ~= nil then
			self:_UpdatePose(runtime)
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
	if runtime.PoseController ~= nil then
		runtime.PoseController:Destroy()
	end
	self._runtimeByEntity[entity] = nil
end

function AnimationEntityRuntimeService:Destroy()
	for entity in pairs(self._runtimeByEntity) do
		self:Remove(entity)
	end
end

function AnimationEntityRuntimeService:_DebugOnce(key: string, ...: any)
	if self._debugOnce[key] == true then
		return
	end
	self._debugOnce[key] = true
	warn(DEBUG_PREFIX, ...)
end

function AnimationEntityRuntimeService:_WarnOnce(key: string, ...: any)
	if self._debugOnce[key] == true then
		return
	end
	self._debugOnce[key] = true
	warn(DEBUG_PREFIX, ...)
end

function AnimationEntityRuntimeService:_EnsureRuntime(record: any)
	local profileComponent = record.Components["Animation.Profile"]
	if type(profileComponent) ~= "table" then
		self:_WarnOnce(("missing-profile:%s"):format(tostring(record.Entity)), "missing Animation.Profile", "entity", record.Entity)
		return
	end

	local model = self._entityController:FindInstanceByEntity(record.Entity)
	if model == nil or not model:IsA("Model") then
		self:_WarnOnce(
			("missing-model:%s"):format(tostring(record.Entity)),
			"missing model",
			"entity",
			record.Entity,
			"profile",
			profileComponent.ProfileId,
			"set",
			profileComponent.AnimationSetId,
			"variant",
			profileComponent.VariantId
		)
		return
	end

	local existing = self._runtimeByEntity[record.Entity]
	if existing ~= nil then
		if existing.Model == model and existing.ProfileComponent == profileComponent then
			existing.Record = record
			return
		end
		self:Remove(record.Entity)
	end

	self:_DebugOnce(
		("runtime-created:%s"):format(tostring(record.Entity)),
		"runtime created",
		"entity",
		record.Entity,
		"profile",
		profileComponent.ProfileId,
		"set",
		profileComponent.AnimationSetId,
		"variant",
		profileComponent.VariantId,
		"model",
		model:GetFullName()
	)
	self._runtimeByEntity[record.Entity] = {
		Entity = record.Entity,
		Record = record,
		Model = model,
		ProfileComponent = profileComponent,
		Profile = nil,
		CompiledSet = nil,
		Animator = nil,
		Humanoid = nil,
		PoseController = nil,
		TracksBySlot = {},
		ActiveChannels = {},
		LocalChannels = {},
		Cleanups = {},
		State = "Pending",
		FailedReason = nil,
	}
end

function AnimationEntityRuntimeService:_SetupRuntime(runtime: any)
	self:_DebugOnce(
		("setup-start:%s"):format(tostring(runtime.Entity)),
		"setup start",
		"entity",
		runtime.Entity,
		"profile",
		runtime.ProfileComponent.ProfileId,
		"set",
		runtime.ProfileComponent.AnimationSetId,
		"variant",
		runtime.ProfileComponent.VariantId
	)

	local ok, profile = pcall(AnimationProfileRegistry.Get, runtime.ProfileComponent.ProfileId)
	if not ok then
		runtime.State = "Failed"
		runtime.FailedReason = tostring(profile)
		self:_WarnOnce(
			("profile-failed:%s"):format(tostring(runtime.Entity)),
			"profile resolve failed",
			"entity",
			runtime.Entity,
			"reason",
			runtime.FailedReason
		)
		warn("[AnimationEntityRuntime]", runtime.Entity, runtime.FailedReason)
		return
	end
	self:_DebugOnce(("profile-ok:%s"):format(tostring(runtime.Entity)), "profile resolved", "entity", runtime.Entity, "profile", profile.Id)

	local setId = runtime.ProfileComponent.AnimationSetId or profile.DefaultSetId
	local compileOk, compiledSet = pcall(AnimationSetCompiler.Compile, setId, runtime.ProfileComponent.VariantId)
	if not compileOk then
		runtime.State = "Failed"
		runtime.FailedReason = tostring(compiledSet)
		self:_WarnOnce(
			("set-failed:%s"):format(tostring(runtime.Entity)),
			"set compile failed",
			"entity",
			runtime.Entity,
			"set",
			setId,
			"variant",
			runtime.ProfileComponent.VariantId,
			"reason",
			runtime.FailedReason
		)
		warn("[AnimationEntityRuntime]", runtime.Entity, runtime.FailedReason)
		return
	end
	self:_DebugOnce(
		("set-ok:%s"):format(tostring(runtime.Entity)),
		"set compiled",
		"entity",
		runtime.Entity,
		"set",
		compiledSet.SetId,
		"variant",
		compiledSet.VariantId
	)

	if profile.DisableDefaultAnimate == true then
		local defaultAnimate = runtime.Model:FindFirstChild("Animate")
		if defaultAnimate ~= nil then
			defaultAnimate:Destroy()
			self:_DebugOnce(("animate-removed:%s"):format(tostring(runtime.Entity)), "default Animate removed", "entity", runtime.Entity)
		else
			self:_DebugOnce(("animate-missing:%s"):format(tostring(runtime.Entity)), "default Animate already missing", "entity", runtime.Entity)
		end
	end

	local animator = _FindAnimator(runtime.Model)
	if animator == nil then
		runtime.State = "Failed"
		runtime.FailedReason = "Animator not found"
		self:_WarnOnce(
			("animator-missing:%s"):format(tostring(runtime.Entity)),
			"animator missing",
			"entity",
			runtime.Entity,
			"model",
			runtime.Model:GetFullName()
		)
		warn("[AnimationEntityRuntime] Animator not found for", runtime.Model:GetFullName())
		return
	end
	self:_DebugOnce(("animator-ok:%s"):format(tostring(runtime.Entity)), "animator found", "entity", runtime.Entity, "animator", animator:GetFullName())

	runtime.Profile = profile
	runtime.CompiledSet = compiledSet
	runtime.Animator = animator
	runtime.Humanoid = _FindHumanoid(runtime.Model)
	runtime.Features = _MergeFeaturePolicy(profile.Features, runtime.ProfileComponent.FeatureOverrides)
	runtime.State = "Ready"
	self:_DebugOnce(("ready:%s"):format(tostring(runtime.Entity)), "runtime ready", "entity", runtime.Entity)
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

	self:_EnsurePoseController(runtime)
	runtime.HasLoadedRequiredClips = true
end

function AnimationEntityRuntimeService:_EnsurePoseController(runtime: any)
	if runtime.PoseController ~= nil or runtime.Profile.LocomotionProvider == "None" then
		return
	end

	local coreAnimations = {}
	for poseName, slotId in pairs(runtime.Profile.CorePoseSlots or {}) do
		local track = self:_GetTrack(runtime, slotId, CORE_PRIORITY)
		if track ~= nil then
			coreAnimations[poseName] = {
				{
					id = slotId,
					weight = 1,
					anim = track,
				},
			}
		end
	end

	local ok, controller = pcall(PoseController.new, runtime.Model, coreAnimations)
	if ok then
		runtime.PoseController = controller
		local poseCount = 0
		for _ in pairs(coreAnimations) do
			poseCount += 1
		end
		self:_DebugOnce(("pose-controller:%s"):format(tostring(runtime.Entity)), "pose controller created", "entity", runtime.Entity, "poses", poseCount)
	else
		self:_WarnOnce(
			("pose-controller-failed:%s"):format(tostring(runtime.Entity)),
			"pose controller failed",
			"entity",
			runtime.Entity,
			"reason",
			tostring(controller)
		)
		warn("[AnimationEntityRuntime] PoseController failed:", tostring(controller))
	end
end

function AnimationEntityRuntimeService:_GetTrack(runtime: any, slotId: string, priority: Enum.AnimationPriority): AnimationTrack?
	local existing = runtime.TracksBySlot[slotId]
	if existing ~= nil then
		return existing
	end

	local clipKey = runtime.CompiledSet.Slots[slotId]
	if type(clipKey) ~= "string" or clipKey == "" then
		self:_WarnOnce(
			("slot-empty:%s:%s"):format(tostring(runtime.Entity), slotId),
			"slot has no clip key",
			"entity",
			runtime.Entity,
			"slot",
			slotId
		)
		return nil
	end
	self:_DebugOnce(
		("slot-key:%s:%s"):format(tostring(runtime.Entity), slotId),
		"slot resolving",
		"entity",
		runtime.Entity,
		"slot",
		slotId,
		"clipKey",
		clipKey,
		"variant",
		runtime.CompiledSet.VariantId
	)

	local animation = RenderAssetAccess.GetAnimationClip(clipKey, runtime.CompiledSet.VariantId, nil)
	if animation == nil then
		animation = RenderAssetAccess.GetAnimationClip(clipKey, "Default", nil)
	end
	if animation == nil then
		self:_WarnOnce(
			("clip-missing:%s:%s"):format(tostring(runtime.Entity), slotId),
			"clip missing",
			"entity",
			runtime.Entity,
			"slot",
			slotId,
			"clipKey",
			clipKey,
			"variant",
			runtime.CompiledSet.VariantId
		)
		return nil
	end
	self:_DebugOnce(
		("clip-ok:%s:%s"):format(tostring(runtime.Entity), slotId),
		"clip resolved",
		"entity",
		runtime.Entity,
		"slot",
		slotId,
		"clipKey",
		clipKey,
		"animation",
		animation:GetFullName()
	)

	local ok, track = pcall(function()
		return runtime.Animator:LoadAnimation(animation)
	end)
	if not ok then
		self:_WarnOnce(
			("track-failed:%s:%s"):format(tostring(runtime.Entity), slotId),
			"track load failed",
			"entity",
			runtime.Entity,
			"slot",
			slotId,
			"clipKey",
			clipKey,
			"reason",
			tostring(track)
		)
		warn("[AnimationEntityRuntime] failed to load clip", clipKey, tostring(track))
		return nil
	end

	track.Priority = priority
	runtime.TracksBySlot[slotId] = track
	self:_DebugOnce(
		("track-ok:%s:%s"):format(tostring(runtime.Entity), slotId),
		"track loaded",
		"entity",
		runtime.Entity,
		"slot",
		slotId,
		"priority",
		tostring(priority)
	)
	return track
end

function AnimationEntityRuntimeService:_UpdatePose(runtime: any)
	local pose = "Idle"
	local speed = 1
	local humanoid = runtime.Humanoid

	if runtime.Profile.LocomotionProvider == "HumanoidState" and humanoid ~= nil then
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Jumping then
			pose = "Jumping"
		elseif state == Enum.HumanoidStateType.Freefall then
			pose = "Freefall"
		elseif state == Enum.HumanoidStateType.Climbing then
			pose = "Climbing"
		elseif state == Enum.HumanoidStateType.Seated then
			pose = "Seated"
		elseif humanoid.MoveDirection.Magnitude > 0.05 then
			local moveSpeed = _GetMoveSpeed(runtime.Model)
			pose = if moveSpeed > 17 then "Run" else "Walk"
			speed = math.max(moveSpeed / 12, 0.1)
		end
	elseif runtime.Profile.LocomotionProvider == "EntityMovement" then
		local applyResult = runtime.Record.Components["Movement.ApplyResult"]
		if type(applyResult) == "table" and applyResult.IsMoving == true then
			pose = "Walk"
			speed = math.max(_GetMoveSpeed(runtime.Model) / 12, 0.1)
		end
	end

	runtime.PoseController:ChangePose(pose, speed, true)
	if runtime.LastDebugPose ~= pose then
		runtime.LastDebugPose = pose
		self:_DebugOnce(("pose:%s:%s"):format(tostring(runtime.Entity), pose), "pose changed", "entity", runtime.Entity, "pose", pose, "speed", speed)
	end
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
