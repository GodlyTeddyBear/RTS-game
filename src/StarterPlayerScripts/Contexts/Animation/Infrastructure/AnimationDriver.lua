--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SimpleAnimateCore = require(ReplicatedStorage.Utilities.SimpleAnimate.Core)
local SimpleAnimateAction = require(ReplicatedStorage.Utilities.SimpleAnimate.Action)
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Promise = require(ReplicatedStorage.Packages.Promise)

local AnimationClipLoader = require(script.Parent.AnimationClipLoader)
local AnimationRigResolver = require(script.Parent.AnimationRigResolver)
local AnimationStatePlayer = require(script.Parent.AnimationStatePlayer)
local EmoteCommandBinder = require(script.Parent.EmoteCommandBinder)
local LeanSystem = require(script.Parent.LeanSystem)
local Types = require(script.Parent.AnimationTypes)

type TAnimationPreset = Types.TAnimationPreset
type TActionEntry = Types.TActionEntry

local AnimationDriver = {}

local function _Log(preset: TAnimationPreset, ...)
	if preset.Debug ~= true then
		return
	end
	print(preset.Tag, ...)
end

local function _GetVariant(model: Model, preset: TAnimationPreset): string
	local defaultVariant = preset.DefaultVariant or "Default"
	if not preset.VariantAttribute then
		return defaultVariant
	end

	local variant = model:GetAttribute(preset.VariantAttribute)
	if type(variant) ~= "string" or variant == "" or variant == "Undecided" then
		return defaultVariant
	end

	return variant
end

local function _BuildKeyMap(entries: { TActionEntry }): { [string]: boolean }
	local keyMap: { [string]: boolean } = {}
	for _, entry in entries do
		keyMap[entry.Action] = true
	end
	return keyMap
end

local function _BuildCoreKeyMap(coreAnimations: { [string]: { any } }): { [string]: boolean }
	local keyMap: { [string]: boolean } = {}
	for poseName in coreAnimations do
		keyMap[poseName] = true
	end
	return keyMap
end

local function _BuildAllKeys(actions: { TActionEntry }, emotes: { TActionEntry }): { string }
	local keys: { string } = {}
	for _, entry in actions do
		table.insert(keys, entry.Action)
	end
	for _, entry in emotes do
		table.insert(keys, entry.Action)
	end
	return keys
end

local function _RegisterActions(action: any, entries: { TActionEntry })
	for _, entry in entries do
		action:CreateAction(entry.Action, entry.AnimInfos, false, Enum.AnimationPriority.Action, false)
	end
end

local function _AttachCleanup(janitor: any, core: any, action: any, allKeys: { string })
	janitor:Add(core, "Destroy")
	janitor:Add(function()
		for _, key in allKeys do
			if action:GetAction(key) then
				action:RemoveAction(key)
			end
		end
	end, true)
end

local function _CleanupJanitor(janitor: any)
	if not janitor then
		return
	end

	local cleanupMethod = janitor.Cleanup
	if typeof(cleanupMethod) == "function" then
		cleanupMethod(janitor)
		return
	end

	local destroyMethod = janitor.Destroy
	if typeof(destroyMethod) == "function" then
		destroyMethod(janitor)
	end
end

local function _LoadVariant(
	model: Model,
	registry: any,
	animator: Animator,
	animationsFolder: Folder,
	controllerJanitor: any,
	context: any,
	preset: TAnimationPreset
)
	local variant = _GetVariant(model, preset)
	_Log(preset, model.Name, "- Loading animations for variant:", variant)

	_CleanupJanitor(controllerJanitor)

	local loaded = AnimationClipLoader.Load(model, registry, variant, animator, animationsFolder, preset)
	if not next(loaded.CoreAnimations) then
		warn(preset.Tag, model.Name, "- No core animations found for variant:", variant)
		return
	end

	local ok, err = pcall(function()
		local core = SimpleAnimateCore.new(model, loaded.CoreAnimations)
		local action = SimpleAnimateAction.new(core.PoseController, model, {})

		for _, pose in preset.AllPoses do
			if not loaded.CoreAnimations[pose] then
				core.PoseController:SetPoseEnabled(pose, false)
			end
		end

		_RegisterActions(action, loaded.Actions)
		_RegisterActions(action, loaded.Emotes)

		_AttachCleanup(controllerJanitor, core, action, _BuildAllKeys(loaded.Actions, loaded.Emotes))
		AnimationStatePlayer.Bind(
			model,
			controllerJanitor,
			action,
			_BuildKeyMap(loaded.Actions),
			core,
			_BuildCoreKeyMap(loaded.CoreAnimations),
			context,
			preset
		)

		if preset.EnableEmotes == true then
			EmoteCommandBinder.Bind(model, controllerJanitor, action, core, _BuildKeyMap(loaded.Emotes))
		end
	end)

	if not ok then
		warn(preset.Tag, model.Name, "- Error setting up controllers:", err)
	end
end

local function _ResolveAnimationsFolder(model: Model, preset: TAnimationPreset)
	if preset.UseDirectAnimationsFolder == true then
		return AnimationRigResolver.ResolveDirectAnimationsFolder(model, preset.AnimationsFolder :: Folder, preset.Tag)
	end
	return AnimationRigResolver.ResolveObjectValueAnimationsFolder(model, preset.Tag)
end

function AnimationDriver.setup(model: Model, preset: TAnimationPreset, context: any)
	local ctx = context or {}
	ctx.Model = model
	ctx = table.freeze(ctx)

	return Promise.all({
		AnimationRigResolver.ResolveRig(model, preset.Tag),
		_ResolveAnimationsFolder(model, preset),
	})
		:andThen(function(results)
			local rig = results[1]
			local animationsFolder = results[2] :: Folder

			return AnimationRigResolver.WaitForHierarchyReplication(model, animationsFolder, preset.Tag):andThen(function()
				return rig, animationsFolder
			end)
		end)
		:andThen(function(rig, animationsFolder: Folder)
			local registry = AssetFetcher.CreateAnimationRegistry(animationsFolder)
			local lifetimeJanitor = Janitor.new()
			local controllerJanitor = Janitor.new()

			lifetimeJanitor:Add(LeanSystem.start(model), true)

			lifetimeJanitor:Add(function()
				_CleanupJanitor(controllerJanitor)
			end, true)
			lifetimeJanitor:Add(
				model.AncestryChanged:Connect(function()
					if not model.Parent then
						_CleanupJanitor(lifetimeJanitor)
					end
				end),
				"Disconnect"
			)

			if preset.ReloadOnVariantChanged == true and preset.VariantAttribute then
				lifetimeJanitor:Add(
					model:GetAttributeChangedSignal(preset.VariantAttribute):Connect(function()
						_LoadVariant(model, registry, rig.Animator, animationsFolder, controllerJanitor, ctx, preset)
					end),
					"Disconnect"
				)
			end

			_LoadVariant(model, registry, rig.Animator, animationsFolder, controllerJanitor, ctx, preset)

			return function()
				_CleanupJanitor(lifetimeJanitor)
			end
		end)
		:catch(function(err)
			warn(preset.Tag, model.Name, "- Setup failed:", tostring(err))
		end)
end

return AnimationDriver
