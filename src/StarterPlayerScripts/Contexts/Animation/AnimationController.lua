--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)

local GetAnimationPresetCommand = require(script.Parent.Application.Commands.GetAnimationPresetCommand)
local SetupAnimationCommand = require(script.Parent.Application.Commands.SetupAnimationCommand)
local SetupAimCommand = require(script.Parent.Application.Commands.SetupAimCommand)

type TPresetId = Types.TPresetId
type TAnimationPreset = Types.TAnimationPreset
type TAnimationPresetOptions = Types.TAnimationPresetOptions
type TSetupAimRequest = Types.TSetupAimRequest

local AnimationController = Knit.CreateController({
	Name = "AnimationController",
})

function AnimationController:KnitInit()
	self._getAnimationPresetCommand = GetAnimationPresetCommand.new()
	self._setupAnimationCommand = SetupAnimationCommand.new()
	self._setupAimCommand = SetupAimCommand.new()
end

function AnimationController:GetPreset(presetId: TPresetId, options: TAnimationPresetOptions?): TAnimationPreset
	return self._getAnimationPresetCommand:Execute(presetId, options)
end

function AnimationController:Setup(
	model: Model,
	presetId: TPresetId,
	context: any?,
	options: TAnimationPresetOptions?
)
	local preset = self:GetPreset(presetId, options)
	return self._setupAnimationCommand:Execute(model, preset, context)
end

function AnimationController:SetupWithFolder(
	model: Model,
	presetId: TPresetId,
	animationsFolder: Folder,
	context: any?,
	options: TAnimationPresetOptions?
)
	local resolvedOptions = {}
	if options ~= nil then
		for key, value in options do
			resolvedOptions[key] = value
		end
	end
	resolvedOptions.AnimationsFolder = animationsFolder

	return self:Setup(model, presetId, context, resolvedOptions :: TAnimationPresetOptions)
end

function AnimationController:SetupAim(request: TSetupAimRequest): (() -> ())?
	return self._setupAimCommand:Execute(request)
end

return AnimationController
