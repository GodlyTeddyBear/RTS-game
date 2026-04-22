--[[
	AssetFetcher - Main Factory for Creating Asset Registries

	Provides factory methods for creating specialized asset registries:
	- AnimationRegistry: Load animations with class-specific fallback
	- EnemyRegistry: Load enemy models with Default fallback
	- EntityRegistry: Load player/enemy models with Default fallback
	- WorkerRegistry: Load worker models with Default fallback
	- LotRegistry: Load lot models with Default fallback
	- DungeonRegistry: Load dungeon room models
	- EffectRegistry: Load visual effects for skills and status effects
	- SoundRegistry: Load sound effects for combat and UI
	- DialogueRegistry: Load dialogue tree ModuleScripts with variant fallback
	- ArmorRegistry: Load armor models by ID with Default fallback
	- AccessoryRegistry: Load accessory models by ID with Default fallback

	Usage:
		local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
		local animationRegistry = AssetFetcher.CreateAnimationRegistry(Assets.Animations)
		local entityRegistry = AssetFetcher.CreateEntityRegistry(Assets.Entities)
		local lotRegistry = AssetFetcher.CreateLotRegistry(Assets.Lots)
]]

local AssetFetcher = {}

--[=[
	Creates an AnimationRegistry for loading class-specific animations with Default fallback.

	@param folder Folder - The root Animations folder
	@return AnimationRegistry - Registry instance for loading animations

	Example:
		local animationRegistry = AssetFetcher.CreateAnimationRegistry(Assets.Animations)
		local warriorSlash = animationRegistry:Get("Skills/Slash", "Warrior")
]=]
function AssetFetcher.CreateAnimationRegistry(folder: Folder)
	local AnimationRegistry = require(script.Parent.AnimationRegistry)
	return AnimationRegistry.new(folder)
end

--[=[
	Creates an EntityRegistry for loading player/enemy models with Default fallback.

	@param folder Folder - The root Entities folder
	@return EntityRegistry - Registry instance for loading entity models

	Example:
		local entityRegistry = AssetFetcher.CreateEntityRegistry(Assets.Entities)
		local warriorModel = entityRegistry:GetPlayerModel("Warrior")
]=]
function AssetFetcher.CreateEntityRegistry(folder: Folder)
	local EntityRegistry = require(script.Parent.EntityRegistry)
	return EntityRegistry.new(folder)
end

--[=[
	Creates an EnemyRegistry for loading enemy models with Default fallback.

	@param folder Folder - The root Enemies folder
	@return EnemyRegistry - Registry instance for loading enemy models

	Example:
		local enemyRegistry = AssetFetcher.CreateEnemyRegistry(Assets.Enemies)
		local swarmModel = enemyRegistry:GetEnemyModel("swarm")
]=]
function AssetFetcher.CreateEnemyRegistry(folder: Folder)
	local EnemyRegistry = require(script.Parent.EnemyRegistry)
	return EnemyRegistry.new(folder)
end

--[=[
	Creates an EffectRegistry for loading visual effects for skills and status effects.

	@param folder Folder - The root Effects folder
	@return EffectRegistry - Registry instance for loading visual effects

	Example:
		local effectRegistry = AssetFetcher.CreateEffectRegistry(Assets.Effects)
		local slashEffect = effectRegistry:GetSkillEffect("Slash")
]=]
function AssetFetcher.CreateEffectRegistry(folder: Folder)
	local EffectRegistry = require(script.Parent.EffectRegistry)
	return EffectRegistry.new(folder)
end

--[=[
	Creates a SoundRegistry for loading sound effects for combat and UI.

	@param folder Folder - The root Sounds folder
	@return SoundRegistry - Registry instance for loading sound effects

	Example:
		local soundRegistry = AssetFetcher.CreateSoundRegistry(Assets.Sounds)
		local slashSound = soundRegistry:GetCombatSound("BasicAttack")
]=]
function AssetFetcher.CreateSoundRegistry(folder: Folder)
	local SoundRegistry = require(script.Parent.SoundRegistry)
	return SoundRegistry.new(folder)
end

--[=[
	Creates a WorkerRegistry for loading worker models with Default fallback.

	@param folder Folder - The root Workers folder
	@return WorkerRegistry - Registry instance for loading worker models

	Example:
		local workerRegistry = AssetFetcher.CreateWorkerRegistry(Assets.Entities.Workers)
		local basicModel = workerRegistry:GetWorkerModel("Basic")
]=]
function AssetFetcher.CreateWorkerRegistry(folder: Folder)
	local WorkerRegistry = require(script.Parent.WorkerRegistry)
	return WorkerRegistry.new(folder)
end

--[=[
	Creates a LotRegistry for loading lot models with Default fallback.

	@param folder Folder - The root Lots folder
	@return LotRegistry - Registry instance for loading lot models

	Example:
		local lotRegistry = AssetFetcher.CreateLotRegistry(Assets.Lots)
		local basicModel = lotRegistry:GetLotModel("Basic")
]=]
function AssetFetcher.CreateLotRegistry(folder: Folder)
	local LotRegistry = require(script.Parent.LotRegistry)
	return LotRegistry.new(folder)
end

--[=[
	Creates a DialogueRegistry for loading NPC dialogue tree ModuleScripts with variant fallback.

	@param folder Folder - The root Dialogues folder
	@return DialogueRegistry - Registry instance for loading dialogue trees

	Example:
		local dialogueRegistry = AssetFetcher.CreateDialogueRegistry(DialoguesFolder)
		local treeDef = dialogueRegistry:Get("Eldric")
		local treeDef = dialogueRegistry:Get("Eldric", "QuestComplete")
]=]
--function AssetFetcher.CreateDialogueRegistry(folder: Folder)
--local DialogueRegistry = require(script.Parent.DialogueRegistry)
--return DialogueRegistry.new(folder)
--end

--[=[
	Creates a ToolRegistry for loading tool models by ID.

	@param folder Folder - The root Tools folder (Assets/Items/Tools)
	@return ToolRegistry - Registry instance for loading tool models

	Example:
		local toolRegistry = AssetFetcher.CreateToolRegistry(Assets.Items.Tools)
		local pickaxe = toolRegistry:GetToolModel("Pickaxe")
]=]
function AssetFetcher.CreateToolRegistry(folder: Folder)
	local ToolRegistry = require(script.Parent.ToolRegistry)
	return ToolRegistry.new(folder)
end

--[=[
	Creates an ArmorRegistry for loading armor models by ID.

	@param folder Folder - The root Armor folder (Assets/Items/Armor)
	@return ArmorRegistry - Registry instance for loading armor models

	Example:
		local armorRegistry = AssetFetcher.CreateArmorRegistry(Assets.Items.Armor)
		local armor = armorRegistry:GetArmorModel("LeatherArmor")
]=]
function AssetFetcher.CreateArmorRegistry(folder: Folder)
	local ArmorRegistry = require(script.Parent.ArmorRegistry)
	return ArmorRegistry.new(folder)
end

--[=[
	Creates an AccessoryRegistry for loading accessory models by ID.

	@param folder Folder - The root Accessories folder (Assets/Items/Accessories)
	@return AccessoryRegistry - Registry instance for loading accessory models

	Example:
		local accessoryRegistry = AssetFetcher.CreateAccessoryRegistry(Assets.Items.Accessories)
		local accessory = accessoryRegistry:GetAccessoryModel("LuckyRing")
]=]
function AssetFetcher.CreateAccessoryRegistry(folder: Folder)
	local AccessoryRegistry = require(script.Parent.AccessoryRegistry)
	return AccessoryRegistry.new(folder)
end

--[=[
	Creates a BuildingRegistry for loading building and companion models by zone.

	@param folder Folder - The root Buildings folder (Assets/Buildings)
	@return BuildingRegistry - Registry instance for loading building models

	Example:
		local buildingRegistry = AssetFetcher.CreateBuildingRegistry(Assets.Buildings)
		local model = buildingRegistry:GetBuildingModel("Forge", "Anvil")
]=]
function AssetFetcher.CreateBuildingRegistry(folder: Folder)
	local BuildingRegistry = require(script.Parent.BuildingRegistry)
	return BuildingRegistry.new(folder)
end

--[=[
	Creates a StructureRegistry for loading structure models with Default fallback.

	@param folder Folder - The root Structures folder (Assets/Structures)
	@return StructureRegistry - Registry instance for loading structure models

	Example:
		local structureRegistry = AssetFetcher.CreateStructureRegistry(Assets.Structures)
		local model = structureRegistry:GetStructureModel("turret")
]=]
function AssetFetcher.CreateStructureRegistry(folder: Folder)
	local StructureRegistry = require(script.Parent.StructureRegistry)
	return StructureRegistry.new(folder)
end

return AssetFetcher
