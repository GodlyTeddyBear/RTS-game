--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SimpleAnimateCore = require(ReplicatedStorage.Utilities.SimpleAnimate.Core)
local SimpleAnimateAction = require(ReplicatedStorage.Utilities.SimpleAnimate.Action)

local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)
local EmoteCommandBinder = require(script.Parent.Parent.Parent.Infrastructure.EmoteCommandBinder)
local BindAnimationStateCommand = require(script.Parent.BindAnimationStateCommand)
local AnimationClipLoader = require(script.Parent.Parent.Parent.Infrastructure.AnimationClipLoader)
local AnimationPoseFilter = require(script.Parent.Parent.Parent.Infrastructure.AnimationPoseFilter)

type TAnimationPreset = Types.TAnimationPreset
type TActionEntry = Types.TActionEntry

local LoadAnimationVariantCommand = {}
LoadAnimationVariantCommand.__index = LoadAnimationVariantCommand

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

function LoadAnimationVariantCommand.new()
	local self = setmetatable({}, LoadAnimationVariantCommand)
	self._bindAnimationStateCommand = BindAnimationStateCommand.new()
	return self
end

function LoadAnimationVariantCommand:Execute(
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
			local isAllowed = AnimationPoseFilter.IsPoseAllowed(preset, pose)
			local isEnabled = isAllowed and loaded.CoreAnimations[pose] ~= nil
			core.PoseController:SetPoseEnabled(pose, isEnabled)
		end

		_RegisterActions(action, loaded.Actions)
		_RegisterActions(action, loaded.Emotes)

		_AttachCleanup(controllerJanitor, core, action, _BuildAllKeys(loaded.Actions, loaded.Emotes))
		self._bindAnimationStateCommand:Execute(
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

return LoadAnimationVariantCommand
