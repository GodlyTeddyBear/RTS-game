--!strict

--[=[
	@class SpawnAdventurerParty
	Application service orchestrating adventurer party spawn (validation, entity creation, model spawn).
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try
local fromPcall = Result.fromPcall
local MentionSuccess = Result.MentionSuccess

--[[
    SpawnAdventurerParty - Application Service

    Orchestrates: validate -> create JECS entities -> create R6 models -> link model refs
    Returns a mapping of adventurerId -> JECS entity for Combat context to use.
]]

local SpawnAdventurerParty = {}
SpawnAdventurerParty.__index = SpawnAdventurerParty

export type TSpawnAdventurerParty = typeof(setmetatable({}, SpawnAdventurerParty))

function SpawnAdventurerParty.new(): TSpawnAdventurerParty
	local self = setmetatable({}, SpawnAdventurerParty)
	return self
end

--[=[
	Initialize service with policies and factories.
	@within SpawnAdventurerParty
	@param registry any -- Registry with `:Get()` for policies and factories
]=]
function SpawnAdventurerParty:Init(registry: any)
	self.AdventurerSpawnPolicy = registry:Get("AdventurerSpawnPolicy")
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
	self.NPCModelFactory = registry:Get("NPCModelFactory")
end

--[=[
	Spawn an entire adventurer party as ECS entities and R6 models in the dungeon.
	@within SpawnAdventurerParty
	@param userId number -- Player ID who owns this party
	@param adventurers { [adventurerId]: any } -- Map of adventurer data from Guild context
	@param spawnPoints { any } -- Array of spawn locations from Dungeon Start
	@return Result.Result<{ [string]: any }> -- Map of adventurerId -> entity ID, or error
	@error string -- Validation failure or entity/model creation failure
]=]
function SpawnAdventurerParty:Execute(
	userId: number,
	adventurers: { [string]: any },
	spawnPoints: { any }
): Result.Result<{ [string]: any }>
	-- Validate spawn parameters against domain policy
	Try(self.AdventurerSpawnPolicy:Check(userId, adventurers, spawnPoints))

	-- Create all adventurer entities and models in Workspace
	local entityMap = self:_SpawnAllAdventurers(userId, adventurers, spawnPoints)
	if not next(entityMap) then
		return Err("EntityCreationFailed", Errors.ENTITY_CREATION_FAILED, { userId = userId })
	end

	-- Log success with spawn count
	local adventurerCount = 0
	for _ in pairs(entityMap) do
		adventurerCount += 1
	end
	MentionSuccess("NPC:SpawnAdventurerParty:Execute", "Spawned adventurer party entities for combat", {
		userId = userId,
		adventurerCount = adventurerCount,
	})
	return Ok(entityMap)
end

-- Spawn all adventurers in the party, round-robin across spawn points.
function SpawnAdventurerParty:_SpawnAllAdventurers(
	userId: number,
	adventurers: { [string]: any },
	spawnPoints: { any }
): { [string]: any }
	local entityMap: { [string]: any } = {}
	local spawnIndex = 1

	-- Iterate adventurers and spawn each one at round-robin spawn point
	for adventurerId, adventurer in pairs(adventurers) do
		local entity = self:_SpawnSingleAdventurer(userId, adventurerId, adventurer, spawnPoints, spawnIndex)
		if entity then
			entityMap[adventurerId] = entity
		end
		spawnIndex += 1
	end
	return entityMap
end

-- Spawn a single adventurer: resolve stats, create entity, create model, link refs.
function SpawnAdventurerParty:_SpawnSingleAdventurer(
	userId: number,
	adventurerId: string,
	adventurer: any,
	spawnPoints: { any },
	spawnIndex: number
): any?
	-- Compute effective stats from base + equipment bonuses
	local displayName = adventurer.DisplayName or adventurer.Type
	local effectiveHP, effectiveATK, effectiveDEF = self:_ResolveEffectiveStats(adventurer)
	local weaponCategory = self:_ResolveWeaponCategory(adventurer)
	local spawnPosition = self:_PickSpawnPosition(spawnPoints, spawnIndex)

	-- Create JECS entity with combat components
	local entity = self.NPCEntityFactory:CreateAdventurer(
		userId, adventurerId, adventurer.Type, displayName,
		effectiveHP, effectiveATK, effectiveDEF,
		spawnPosition, weaponCategory
	)
	if not entity then return nil end

	-- Create R6 model and link to entity (model ref component)
	fromPcall("ModelCreationFailed", function()
		return self.NPCModelFactory:CreateAdventurerModel(
			adventurer.Type,
			adventurerId,
			userId,
			displayName,
			effectiveHP,
			adventurer.Equipment
		)
	end):andThen(function(model)
		self.NPCModelFactory:UpdatePosition(model, CFrame.new(spawnPosition))
		self.NPCEntityFactory:SetModelRef(entity, model)
		return Ok(nil)
	end)

	return entity
end

-- Calculate effective stats by summing base + equipment bonuses.
function SpawnAdventurerParty:_ResolveEffectiveStats(adventurer: any): (number, number, number)
	-- Load base stats
	local hp = adventurer.BaseHP or 0
	local atk = adventurer.BaseATK or 0
	local def = adventurer.BaseDEF or 0

	-- Sum equipment bonuses across all equipped slots (weapon, armor, etc.)
	if adventurer.Equipment then
		for _, slot in pairs(adventurer.Equipment) do
			if slot then
				hp += (slot.BonusHP or 0)
				atk += (slot.BonusATK or 0)
				def += (slot.BonusDEF or 0)
			end
		end
	end
	return hp, atk, def
end

-- Resolve weapon category from equipped weapon item ID (used for animation selection).
function SpawnAdventurerParty:_ResolveWeaponCategory(adventurer: any): string?
	-- Guard against missing equipment or weapon slot
	if not adventurer.Equipment or not adventurer.Equipment.Weapon then return nil end

	-- Look up weapon type from ItemConfig
	local weaponItemId = adventurer.Equipment.Weapon.ItemId
	if not weaponItemId then return nil end
	local itemData = ItemConfig[weaponItemId]
	if itemData and itemData.WeaponType then
		return itemData.WeaponType
	end
	return nil
end

-- Pick a spawn point using round-robin; wrap around if spawnIndex > #spawnPoints.
function SpawnAdventurerParty:_PickSpawnPosition(spawnPoints: { any }, spawnIndex: number): Vector3
	-- Round-robin formula: ((index - 1) % count) + 1 gives 1-based index within bounds
	local spawnPoint = spawnPoints[((spawnIndex - 1) % #spawnPoints) + 1]
	return spawnPoint.Position or Vector3.new(0, 5, 0)
end

return SpawnAdventurerParty
