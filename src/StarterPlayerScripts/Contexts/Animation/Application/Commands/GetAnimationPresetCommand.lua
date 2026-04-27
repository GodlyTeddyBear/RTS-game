--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)
local AnimationPresetRegistry = require(ReplicatedStorage.Contexts.Animation.Config.AnimationPresetRegistry)

type TPresetId = Types.TPresetId
type TAnimationPreset = Types.TAnimationPreset
type TAnimationPresetOptions = Types.TAnimationPresetOptions

local GetAnimationPresetCommand = {}
GetAnimationPresetCommand.__index = GetAnimationPresetCommand

local function _ClonePreset(preset: TAnimationPreset): TAnimationPreset
	local clone = {}
	for key, value in preset do
		clone[key] = value
	end
	return clone :: TAnimationPreset
end

function GetAnimationPresetCommand.new()
	return setmetatable({}, GetAnimationPresetCommand)
end

function GetAnimationPresetCommand:Execute(presetId: TPresetId, options: TAnimationPresetOptions?): TAnimationPreset
	local preset = _ClonePreset(AnimationPresetRegistry.Get(presetId))
	local resolvedOptions = options or {}

	if resolvedOptions.AnimationsFolder ~= nil then
		preset.AnimationsFolder = resolvedOptions.AnimationsFolder
		preset.UseDirectAnimationsFolder = true
	end

	if preset.Id == "Player" then
		assert(
			preset.AnimationsFolder ~= nil,
			"GetAnimationPresetCommand: Player preset requires AnimationsFolder via SetupWithFolder or options.AnimationsFolder"
		)
		preset.UseDirectAnimationsFolder = true
	end

	return table.freeze(preset)
end

return GetAnimationPresetCommand
