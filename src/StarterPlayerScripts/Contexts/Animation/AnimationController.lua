--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)

local GetAnimationPresetCommand = require(script.Parent.Application.Commands.GetAnimationPresetCommand)
local SetupAnimationCommand = require(script.Parent.Application.Commands.SetupAnimationCommand)
local SetupAimCommand = require(script.Parent.Application.Commands.SetupAimCommand)
local AnimationEntityRuntimeService = require(script.Parent.Infrastructure.Services.AnimationEntityRuntimeService)
local AnimationBindingSystem = require(script.Parent.Infrastructure.Systems.AnimationBindingSystem)

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
	self._runtimeService = nil
	self._bindingSystem = nil
end

function AnimationController:KnitStart()
	local entityController = Knit.GetController("EntityController")
	self._runtimeService = AnimationEntityRuntimeService.new(self, entityController)
	self._bindingSystem = AnimationBindingSystem.new(entityController, self._runtimeService)
	entityController:RegisterSystem("AnimationBindingSystem", self._bindingSystem)
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
	return self._setupAnimationCommand:Execute(model, preset, context, options)
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

function AnimationController:Destroy()
	if self._runtimeService ~= nil then
		self._runtimeService:Destroy()
		self._runtimeService = nil
	end
end

return AnimationController
