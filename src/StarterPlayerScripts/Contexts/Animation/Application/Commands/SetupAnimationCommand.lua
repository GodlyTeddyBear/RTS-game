--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Promise = require(ReplicatedStorage.Packages.Promise)

local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)
local LeanSystem = require(script.Parent.Parent.Parent.Infrastructure.LeanSystem)
local AnimationRigResolver = require(script.Parent.Parent.Parent.Infrastructure.AnimationRigResolver)
local LoadAnimationVariantCommand = require(script.Parent.LoadAnimationVariantCommand)

type TAnimationPreset = Types.TAnimationPreset

local SetupAnimationCommand = {}
SetupAnimationCommand.__index = SetupAnimationCommand

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

local function _ResolveAnimationsFolder(model: Model, preset: TAnimationPreset)
	if preset.UseDirectAnimationsFolder == true then
		return AnimationRigResolver.ResolveDirectAnimationsFolder(model, preset.AnimationsFolder :: Folder, preset.Tag)
	end
	return AnimationRigResolver.ResolveObjectValueAnimationsFolder(model, preset.Tag)
end

function SetupAnimationCommand.new()
	local self = setmetatable({}, SetupAnimationCommand)
	self._loadAnimationVariantCommand = LoadAnimationVariantCommand.new()
	return self
end

function SetupAnimationCommand:Execute(model: Model, preset: TAnimationPreset, context: any)
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
						self._loadAnimationVariantCommand:Execute(
							model,
							registry,
							rig.Animator,
							animationsFolder,
							controllerJanitor,
							ctx,
							preset
						)
					end),
					"Disconnect"
				)
			end

			self._loadAnimationVariantCommand:Execute(model, registry, rig.Animator, animationsFolder, controllerJanitor, ctx, preset)

			return function()
				_CleanupJanitor(lifetimeJanitor)
			end
		end)
		:catch(function(err)
			warn(preset.Tag, model.Name, "- Setup failed:", tostring(err))
		end)
end

return SetupAnimationCommand
