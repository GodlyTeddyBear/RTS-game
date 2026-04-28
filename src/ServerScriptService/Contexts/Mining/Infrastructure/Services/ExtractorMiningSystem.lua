--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

--[=[
    @class ExtractorMiningSystem
    Advances mining extractor timers and grants output to online owners on the combat tick.
    @server
]=]
local ExtractorMiningSystem = {}
ExtractorMiningSystem.__index = ExtractorMiningSystem

-- Creates the extractor mining system wrapper.
--[=[
    Creates the extractor mining system wrapper.
    @within ExtractorMiningSystem
    @return ExtractorMiningSystem -- The new system instance.
]=]
function ExtractorMiningSystem.new()
	return setmetatable({}, ExtractorMiningSystem)
end

-- Resolves the mining entity factory during system initialization.
--[=[
    Resolves the mining entity factory during system initialization.
    @within ExtractorMiningSystem
    @param registry any -- The dependency registry for this context.
    @param _name string -- The registered module name.
]=]
function ExtractorMiningSystem:Init(registry: any, _name: string)
	self._factory = registry:Get("MiningEntityFactory")
end

-- Resolves the economy context after external services are available.
--[=[
    Resolves the economy context after external services are available.
    @within ExtractorMiningSystem
    @param registry any -- The dependency registry for this context.
    @param _name string -- The registered module name.
]=]
function ExtractorMiningSystem:Start(registry: any, _name: string)
	self._economyContext = registry:Get("EconomyContext")
end

-- Advances every active extractor using the current scheduler delta time.
--[=[
    Advances every active extractor using the supplied delta time.
    @within ExtractorMiningSystem
    @param dt number -- The scheduler delta time.
]=]
function ExtractorMiningSystem:Tick(dt: number)
	-- Reads the active extractor set and forwards each entity to the per-extractor updater.
	for _, entity in ipairs(self._factory:QueryActiveEntities()) do
		self:_TickExtractor(entity, dt)
	end
end

-- Applies one extractor update, carrying excess time into the next cycle.
--[=[
    Applies one extractor update for a single active entity.
    @within ExtractorMiningSystem
    @param entity number -- The entity id to advance.
    @param dt number -- The scheduler delta time.
]=]
function ExtractorMiningSystem:_TickExtractor(entity: number, dt: number)
	local owner = self._factory:GetOwner(entity)
	local resource = self._factory:GetResource(entity)
	local timing = self._factory:GetTiming(entity)
	if owner == nil or resource == nil or timing == nil then
		return
	end

	local elapsedSeconds = timing.ElapsedSeconds + dt
	if elapsedSeconds < timing.IntervalSeconds then
		self._factory:SetElapsedSeconds(entity, elapsedSeconds)
		return
	end

	local cycles = math.floor(elapsedSeconds / timing.IntervalSeconds)
	local remainingSeconds = elapsedSeconds - cycles * timing.IntervalSeconds
	self._factory:SetElapsedSeconds(entity, remainingSeconds)

	local player = Players:GetPlayerByUserId(owner.UserId)
	if player == nil then
		return
	end

	local amount = resource.AmountPerCycle * cycles
	local grantResult = self._economyContext:AddResource(player, resource.ResourceType, amount)
	if grantResult.success then
		return
	end

	Result.MentionError("Mining:ExtractorProduction", "Failed to grant extractor resources", {
		UserId = owner.UserId,
		ResourceType = resource.ResourceType,
		Amount = amount,
		CauseType = grantResult.type,
		CauseMessage = grantResult.message,
	}, grantResult.type)
end

return ExtractorMiningSystem
