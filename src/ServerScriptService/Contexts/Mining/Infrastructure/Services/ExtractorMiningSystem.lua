--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local ExtractorMiningSystem = {}
ExtractorMiningSystem.__index = ExtractorMiningSystem

function ExtractorMiningSystem.new()
	return setmetatable({}, ExtractorMiningSystem)
end

function ExtractorMiningSystem:Init(registry: any, _name: string)
	self._factory = registry:Get("MiningEntityFactory")
end

function ExtractorMiningSystem:Start(registry: any, _name: string)
	self._economyContext = registry:Get("EconomyContext")
end

function ExtractorMiningSystem:Tick(dt: number)
	-- READS: OwnerComponent [AUTHORITATIVE], ResourceComponent [AUTHORITATIVE], TimingComponent [AUTHORITATIVE]
	-- WRITES: TimingComponent [AUTHORITATIVE]
	for _, entity in ipairs(self._factory:QueryActiveEntities()) do
		self:_TickExtractor(entity, dt)
	end
end

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
