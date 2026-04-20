--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCConfig = require(ServerScriptService.Contexts.NPC.Config.NPCConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class StartCombat
	Application command that validates and starts a combat session.

	Orchestration order: validate via policy → set BehaviorConfig on all
	entities → apply weapon profiles to adventurers → assign behavior trees
	→ register the session with `CombatLoopService`.
	@server
]=]
local StartCombat = {}
StartCombat.__index = StartCombat

export type TStartCombat = typeof(setmetatable({}, StartCombat))

function StartCombat.new(): TStartCombat
	return setmetatable({}, StartCombat)
end

function StartCombat:Init(registry: any, _name: string)
	self.Registry = registry
	self.StartCombatPolicy = registry:Get("StartCombatPolicy")
	self.BehaviorTreeFactory = registry:Get("BehaviorTreeFactory")
	self.CombatLoopService = registry:Get("CombatLoopService")
	self.TargetSelector = registry:Get("TargetSelector")
	self.WeaponProfileResolver = registry:Get("WeaponProfileResolver")
end

function StartCombat:Start()
	self.NPCEntityFactory = self.Registry:Get("NPCEntityFactory")
	self.World = self.Registry:Get("World")
	self.Components = self.Registry:Get("Components")
end

--[=[
	Start a combat session for a user.
	@within StartCombat
	@param userId number
	@param adventurerEntities { [string]: any } -- Map of adventurerId → entity
	@param enemyEntities { any } -- Array of enemy entities
	@param zoneId string
	@param totalWaves number
	@param onComplete ((status: string, deadAdventurerIds: { string }) -> ())? -- Completion callback
	@return Result.Result<nil>
]=]
function StartCombat:Execute(
	userId: number,
	adventurerEntities: { [string]: any },
	enemyEntities: { any },
	zoneId: string,
	totalWaves: number,
	onComplete: ((string, { string }) -> ())?
): Result.Result<nil>
	-- Step 1: Flatten adventurer map to list for validation
	local adventurerList = self:_FlattenAdventurerMap(adventurerEntities)

	-- Step 2: Validate preconditions (valid user, non-empty parties, no active combat)
	Try(self.StartCombatPolicy:Check(userId, adventurerList, enemyEntities))

	-- Step 3: Prepare all entities (set defaults, apply weapon profiles, assign BTs)
	local allEntities = self:_CombineEntityLists(adventurerList, enemyEntities)
	self:_PrepareAllEntities(allEntities)

	-- Step 4: Register session with combat loop (wave 1 of totalWaves)
	self.CombatLoopService:StartCombat(userId, zoneId, 1, totalWaves, onComplete)

	MentionSuccess(
		"Combat:StartCombat:Validation",
		"userId: " .. userId .. " - Combat started in zone " .. zoneId
			.. " with " .. #adventurerList .. " adventurers, " .. #enemyEntities .. " enemies, " .. totalWaves .. " waves"
	)

	return Ok(nil)
end

--- @within StartCombat
--- @private
function StartCombat:_FlattenAdventurerMap(adventurerEntities: { [string]: any }): { any }
	local list = {}
	for _, entity in pairs(adventurerEntities) do
		table.insert(list, entity)
	end
	return list
end

--- @within StartCombat
--- @private
function StartCombat:_CombineEntityLists(adventurerList: { any }, enemyEntities: { any }): { any }
	local combined = table.clone(adventurerList)
	for _, entity in ipairs(enemyEntities) do
		table.insert(combined, entity)
	end
	return combined
end

--- @within StartCombat
--- @private
function StartCombat:_PrepareAllEntities(allEntities: { any })
	for _, entity in ipairs(allEntities) do
		local identity = self.NPCEntityFactory:GetIdentity(entity)
		if not identity then
			continue
		end

		self.NPCEntityFactory:SetBehaviorConfigFromDefaults(entity, identity.NPCType)

		if identity.IsAdventurer then
			self:_ApplyWeaponProfile(entity)
		end

		self:_AssignBehaviorTree(entity, identity.NPCType, identity.IsAdventurer)
	end
end

--- @within StartCombat
--- @private
function StartCombat:_ApplyWeaponProfile(entity: any)
	local weaponComp = self.NPCEntityFactory:GetWeaponCategory(entity)
	local category = weaponComp and weaponComp.Category or "Punch"
	local weaponProfile = self.WeaponProfileResolver:Resolve(category)

	local currentConfig = self.NPCEntityFactory:GetBehaviorConfig(entity)
	if currentConfig then
		local merged = table.clone(currentConfig)
		merged.AttackEnterRange = weaponProfile.AttackEnterRange
		merged.AttackExitRange = weaponProfile.AttackExitRange
		merged.MinAttackRange = weaponProfile.MinAttackRange
		merged.MaxAttackRange = weaponProfile.MaxAttackRange
		merged.IsRanged = weaponProfile.IsRanged
		merged.FleeEnabled = weaponProfile.FleeEnabled
		self.NPCEntityFactory:SetBehaviorConfig(entity, merged)
	end

	local cooldownComp = self.NPCEntityFactory:GetAttackCooldown(entity)
	if cooldownComp then
		local updatedCooldown = table.clone(cooldownComp)
		updatedCooldown.Cooldown = weaponProfile.Cooldown
		self.World:set(entity, self.Components.AttackCooldownComponent, updatedCooldown)
	end
end

--- @within StartCombat
--- @private
function StartCombat:_AssignBehaviorTree(entity: any, npcType: string, isAdventurer: boolean)
	local tickInterval = NPCConfig.BT_TICK_MIN_INTERVAL
		+ math.random() * (NPCConfig.BT_TICK_MAX_INTERVAL - NPCConfig.BT_TICK_MIN_INTERVAL)

	local tree = self.BehaviorTreeFactory:CreateTree(npcType, isAdventurer)
	if tree then
		self.NPCEntityFactory:SetBehaviorTree(entity, tree, tickInterval)
	end
end

return StartCombat
