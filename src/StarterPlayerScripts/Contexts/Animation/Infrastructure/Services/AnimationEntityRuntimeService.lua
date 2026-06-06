--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderAssetAccess = require(ReplicatedStorage.Contexts.Render.RenderAssetAccess)

local AnimationEntityRuntimeService = {}
AnimationEntityRuntimeService.__index = AnimationEntityRuntimeService

local function _BuildStateSource(entityController: any, entity: number)
	local function getActionState()
		local record = entityController:GetEntity(entity)
		return if record ~= nil then record.Components["Animation.ActionState"] else nil
	end

	local function observe(callback: () -> ())
		local connection = entityController:ObserveStateChanged(callback)
		return function()
			connection:Disconnect()
		end
	end

	return table.freeze({
		GetState = function()
			local state = getActionState()
			return if type(state) == "table" then state.State else nil
		end,
		GetLooping = function()
			local state = getActionState()
			return if type(state) == "table" then state.Looping else true
		end,
		GetRevision = function()
			local state = getActionState()
			return if type(state) == "table" then state.Revision else nil
		end,
		GetActionAnimation = function()
			return getActionState()
		end,
		ObserveStateChanged = observe,
		ObserveLoopingChanged = observe,
		ObserveRevisionChanged = observe,
		ObserveActionAnimationChanged = observe,
	})
end

function AnimationEntityRuntimeService.new(animationController: any, entityController: any)
	return setmetatable({
		_animationController = animationController,
		_entityController = entityController,
		_runtimeByEntity = {},
		_pendingByEntity = {},
	}, AnimationEntityRuntimeService)
end

function AnimationEntityRuntimeService:Ensure(entity: number, profile: any)
	local model = self._entityController:FindInstanceByEntity(entity)
	if model == nil or not model:IsA("Model") then
		return
	end

	local runtime = self._runtimeByEntity[entity]
	if runtime ~= nil then
		if runtime.Model == model then
			return
		end
		self:Remove(entity)
	end
	if self._pendingByEntity[entity] == model then
		return
	end

	local presetId = profile.PresetId
	if type(presetId) ~= "string" or presetId == "" then
		return
	end

	self._pendingByEntity[entity] = model
	local record = self._entityController:GetEntity(entity)
	local identity = if record ~= nil then record.Identity else nil
	local context = {
		Model = model,
		ActorId = if type(identity) == "table" then identity.EntityId else tostring(entity),
		ActorKind = if type(identity) == "table" then identity.EntityKind else record and record.FeatureName,
		GetTargetWorldPosition = function()
			local currentRecord = self._entityController:GetEntity(entity)
			local target = currentRecord and currentRecord.Target
			local targetEntity = if type(target) == "table" then target.TargetEntity else nil
			if type(targetEntity) ~= "number" then
				return nil
			end
			local targetModel = self._entityController:FindInstanceByEntity(targetEntity)
			return if targetModel ~= nil and targetModel:IsA("Model") then targetModel:GetPivot().Position else nil
		end,
	}
	local options = {
		StateSource = _BuildStateSource(self._entityController, entity),
	}
	if profile.DisableDefaultAnimate == true then
		local defaultAnimate = model:FindFirstChild("Animate")
		if defaultAnimate ~= nil then
			defaultAnimate:Destroy()
		end
	end
	local setupPromise
	if profile.AssetSource == "SharedAnimations" then
		local assetsRoot = RenderAssetAccess.GetAssetsRoot()
		local animationsFolder = assetsRoot and assetsRoot:FindFirstChild("Animations")
		if animationsFolder == nil or not animationsFolder:IsA("Folder") then
			self._pendingByEntity[entity] = nil
			return
		end
		setupPromise = self._animationController:SetupWithFolder(model, presetId, animationsFolder, context, options)
	else
		setupPromise = self._animationController:Setup(model, presetId, context, options)
	end

	setupPromise
		:andThen(function(cleanup)
			if self._pendingByEntity[entity] == model then
				self._pendingByEntity[entity] = nil
			end
			if self._entityController:GetEntity(entity) == nil or self._entityController:FindInstanceByEntity(entity) ~= model then
				if cleanup ~= nil then
					cleanup()
				end
				return
			end
			local aimCleanup = nil
			local currentRecord = self._entityController:GetEntity(entity)
			local aimProfile = currentRecord and currentRecord.Components["Animation.AimProfile"]
			if type(aimProfile) == "table" and type(aimProfile.RigConfig) == "table" then
				aimCleanup = self._animationController:SetupAim({
					Model = model,
					Strategy = aimProfile.RigConfig.Strategy,
					GetTargetWorldPosition = context.GetTargetWorldPosition,
					RigConfig = aimProfile.RigConfig,
					Context = context,
				})
			end
			self._runtimeByEntity[entity] = {
				Model = model,
				Profile = profile,
				Cleanup = function()
					if aimCleanup ~= nil then
						aimCleanup()
					end
					if cleanup ~= nil then
						cleanup()
					end
				end,
			}
		end)
		:catch(function(err)
			if self._pendingByEntity[entity] == model then
				self._pendingByEntity[entity] = nil
			end
			warn("[AnimationEntityRuntime]", entity, tostring(err))
		end)
end

function AnimationEntityRuntimeService:CleanupMissing(activeEntities: { [number]: boolean })
	for entity, runtime in pairs(self._runtimeByEntity) do
		if activeEntities[entity] == true and runtime.Model.Parent ~= nil then
			continue
		end
		self:Remove(entity)
	end
end

function AnimationEntityRuntimeService:Remove(entity: number)
	local runtime = self._runtimeByEntity[entity]
	if runtime ~= nil and runtime.Cleanup ~= nil then
		runtime.Cleanup()
	end
	self._runtimeByEntity[entity] = nil
	self._pendingByEntity[entity] = nil
end

function AnimationEntityRuntimeService:Destroy()
	for entity in pairs(self._runtimeByEntity) do
		self:Remove(entity)
	end
	table.clear(self._pendingByEntity)
end

return AnimationEntityRuntimeService
