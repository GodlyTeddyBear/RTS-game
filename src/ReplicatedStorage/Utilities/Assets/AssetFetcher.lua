--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderAssetAccess = require(ReplicatedStorage.Contexts.Render.RenderAssetAccess)

local AssetFetcher = {}

local function _CreateAnimationRegistryAdapter(folder: Folder)
	return {
		Get = function(_self, actionType: string, class: string?): Animation
			local animation = RenderAssetAccess.GetAnimationClip(actionType, class, {
				Root = folder,
			})
			assert(animation ~= nil, "Animation not found: " .. actionType .. "/" .. tostring(class or "Default"))
			return animation
		end,
		Exists = function(_self, actionType: string, class: string?): boolean
			return RenderAssetAccess.AnimationClipExists(actionType, class, {
				Root = folder,
			})
		end,
		GetAll = function(_self, actionType: string): { [string]: Animation }
			return RenderAssetAccess.GetAllAnimationClips(actionType, {
				Root = folder,
			})
		end,
	}
end

local function _CreateEffectRegistryAdapter(folder: Folder)
	return {
		GetSkillEffect = function(_self, effectKey: string): Folder | Model
			local effect = RenderAssetAccess.GetSkillEffect(effectKey, {
				Root = folder,
			})
			assert(effect ~= nil, "Skill effect not found: " .. effectKey)
			return effect
		end,
		SkillEffectExists = function(_self, effectKey: string): boolean
			return RenderAssetAccess.SkillEffectExists(effectKey, {
				Root = folder,
			})
		end,
		GetStatusEffect = function(_self, effectKey: string): Folder | Model
			local effect = RenderAssetAccess.GetStatusEffect(effectKey, {
				Root = folder,
			})
			assert(effect ~= nil, "Status effect not found: " .. effectKey)
			return effect
		end,
		StatusEffectExists = function(_self, effectKey: string): boolean
			return RenderAssetAccess.StatusEffectExists(effectKey, {
				Root = folder,
			})
		end,
	}
end

local function _CreateSoundRegistryAdapter(folder: Folder)
	return {
		GetCombatSound = function(_self, soundPath: string): Sound
			local sound = RenderAssetAccess.GetCombatSound(soundPath, {
				Root = folder,
			})
			assert(sound ~= nil, "Combat sound not found: " .. soundPath)
			return sound
		end,
		CombatSoundExists = function(_self, soundPath: string): boolean
			return RenderAssetAccess.CombatSoundExists(soundPath, {
				Root = folder,
			})
		end,
		GetUISound = function(_self, soundPath: string): Sound
			local sound = RenderAssetAccess.GetUISound(soundPath, {
				Root = folder,
			})
			assert(sound ~= nil, "UI sound not found: " .. soundPath)
			return sound
		end,
		UISoundExists = function(_self, soundPath: string): boolean
			return RenderAssetAccess.UISoundExists(soundPath, {
				Root = folder,
			})
		end,
	}
end

local function _CreateStructureRegistryAdapter(folder: Folder)
	return {
		GetStructureModel = function(_self, structureType: string): Model?
			return RenderAssetAccess.GetStructureModel(structureType, {
				Root = folder,
			})
		end,
		StructureModelExists = function(_self, structureType: string): boolean
			return RenderAssetAccess.StructureModelExists(structureType, {
				Root = folder,
			})
		end,
	}
end

local function _CreateEquipmentRegistryAdapter(folder: Folder, familyId: "ToolModel" | "ArmorModel" | "AccessoryModel")
	local getterName = if familyId == "ToolModel"
		then "GetToolModel"
		elseif familyId == "ArmorModel"
			then "GetArmorModel"
			else "GetAccessoryModel"
	local existsName = if familyId == "ToolModel"
		then "ToolModelExists"
		elseif familyId == "ArmorModel"
			then "ArmorModelExists"
			else "AccessoryModelExists"

	return {
		[getterName] = function(_self, assetId: string): Model?
			return RenderAssetAccess[getterName](assetId, {
				Root = folder,
			})
		end,
		[existsName] = function(_self, assetId: string): boolean
			return RenderAssetAccess[existsName](assetId, {
				Root = folder,
			})
		end,
	}
end

function AssetFetcher.CreateAnimationRegistry(folder: Folder)
	return _CreateAnimationRegistryAdapter(folder)
end

function AssetFetcher.CreateEntityRegistry(folder: Folder)
	local EntityRegistry = require(script.Parent.EntityRegistry)
	return EntityRegistry.new(folder)
end

function AssetFetcher.CreateEnemyRegistry(folder: Folder)
	local EnemyRegistry = require(script.Parent.EnemyRegistry)
	return EnemyRegistry.new(folder)
end

function AssetFetcher.CreateUnitRegistry(folder: Folder)
	local UnitRegistry = require(script.Parent.UnitRegistry)
	return UnitRegistry.new(folder)
end

function AssetFetcher.CreateEffectRegistry(folder: Folder)
	return _CreateEffectRegistryAdapter(folder)
end

function AssetFetcher.CreateSoundRegistry(folder: Folder)
	return _CreateSoundRegistryAdapter(folder)
end

function AssetFetcher.CreateWorkerRegistry(folder: Folder)
	local WorkerRegistry = require(script.Parent.WorkerRegistry)
	return WorkerRegistry.new(folder)
end

function AssetFetcher.CreateLotRegistry(folder: Folder)
	local LotRegistry = require(script.Parent.LotRegistry)
	return LotRegistry.new(folder)
end

function AssetFetcher.CreateToolRegistry(folder: Folder)
	return _CreateEquipmentRegistryAdapter(folder, "ToolModel")
end

function AssetFetcher.CreateArmorRegistry(folder: Folder)
	return _CreateEquipmentRegistryAdapter(folder, "ArmorModel")
end

function AssetFetcher.CreateAccessoryRegistry(folder: Folder)
	return _CreateEquipmentRegistryAdapter(folder, "AccessoryModel")
end

function AssetFetcher.CreateBuildingRegistry(folder: Folder)
	local BuildingRegistry = require(script.Parent.BuildingRegistry)
	return BuildingRegistry.new(folder)
end

function AssetFetcher.CreateStructureRegistry(folder: Folder)
	return _CreateStructureRegistryAdapter(folder)
end

return AssetFetcher
