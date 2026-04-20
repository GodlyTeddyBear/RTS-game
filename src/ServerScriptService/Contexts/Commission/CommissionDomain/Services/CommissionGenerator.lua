--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommissionPoolConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionPoolConfig)
local CommissionRewardConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionRewardConfig)

--[=[
	@class CommissionGenerator
	Pure domain service for generating commission boards with no side effects or state mutations.
	@server
]=]
local CommissionGenerator = {}
CommissionGenerator.__index = CommissionGenerator

--[=[
	Construct a new CommissionGenerator.
	@within CommissionGenerator
	@return CommissionGenerator
]=]
function CommissionGenerator.new()
	return setmetatable({}, CommissionGenerator)
end

--[=[
	Generate a full board of commissions for a player.
	@within CommissionGenerator
	@param currentTier number -- Highest tier the player has unlocked
	@param boardSize number -- Number of board slots to fill
	@param existingActive { any } -- Currently active commissions (excluded to avoid duplicates)
	@return { any } -- Array of `TBoardCommission` entries
]=]
function CommissionGenerator:GenerateBoard(currentTier: number, boardSize: number, existingActive: { any }): { any }
	-- Filter pool by tier and return empty board if no valid entries exist
	local pool = self:_FilterPoolByTier(currentTier)
	if #pool == 0 then
		return {}
	end

	-- Shuffle pool and exclude currently active commissions to avoid duplicates
	local shuffled = self:_Shuffle(pool)
	local excludedIds = self:_BuildActiveIdSet(existingActive)

	-- Select unique entries from pool (skip if already active or on board)
	local board = self:_SelectEntries(shuffled, boardSize, excludedIds, {})

	-- Fallback: if pool was mostly active, allow duplicates to fill remaining slots
	if #board < boardSize then
		board = self:_SelectEntries(shuffled, boardSize, {}, board)
	end

	return board
end

--[=[
	Generate one visitor-originated commission offer for a target player.
	@within CommissionGenerator
	@param currentTier number -- Highest tier the target player has unlocked
	@param existingActive { any } -- Active commissions excluded to avoid duplicates
	@param villagerId string -- Runtime villager offering the commission
	@param targetUserId number -- Player receiving the offer
	@return any? -- Visitor board commission, or nil if no pool entry is available
]=]
function CommissionGenerator:GenerateVisitorOffer(
	currentTier: number,
	existingActive: { any },
	villagerId: string,
	targetUserId: number
): any?
	local generated = self:GenerateBoard(currentTier, 1, existingActive)
	local offer = generated[1]
	if not offer then
		return nil
	end

	local mutableOffer = table.clone(offer)
	mutableOffer.Source = "Visitor"
	mutableOffer.VillagerId = villagerId
	mutableOffer.TargetUserId = targetUserId
	return table.freeze(mutableOffer)
end

function CommissionGenerator:_FilterPoolByTier(currentTier: number): { any }
	local pool = {}
	for _, entry in ipairs(CommissionPoolConfig) do
		if entry.Tier <= currentTier then
			table.insert(pool, entry)
		end
	end
	return pool
end

function CommissionGenerator:_Shuffle(pool: { any }): { any }
	local shuffled = table.clone(pool)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

function CommissionGenerator:_BuildActiveIdSet(existingActive: { any }): { [string]: boolean }
	local ids: { [string]: boolean } = {}
	for _, active in ipairs(existingActive) do
		ids[active.PoolId] = true
	end
	return ids
end

function CommissionGenerator:_SelectEntries(
	shuffled: { any },
	boardSize: number,
	excludedIds: { [string]: boolean },
	existingBoard: { any }
): { any }
	local board = table.clone(existingBoard)
	local now = os.time()

	-- Fill board up to boardSize, skipping excluded IDs and duplicates
	for _, entry in ipairs(shuffled) do
		if #board >= boardSize then
			break
		end

		-- Skip if in excluded set or already on board
		if not excludedIds[entry.PoolId] and not self:_IsPoolIdOnBoard(board, entry.PoolId) then
			table.insert(board, self:_BuildCommission(entry, now))
		end
	end

	return board
end

function CommissionGenerator:_IsPoolIdOnBoard(board: { any }, poolId: string): boolean
	for _, bc in ipairs(board) do
		if bc.PoolId == poolId then
			return true
		end
	end
	return false
end

function CommissionGenerator:_BuildCommission(entry: any, now: number): any
	local qty = math.random(entry.MinQty, entry.MaxQty)
	local goldReward, tokenReward = self:_ComputeRewards(entry, qty)

	return table.freeze({
		Id = HttpService:GenerateGUID(false),
		PoolId = entry.PoolId,
		Tier = entry.Tier,
		Requirement = table.freeze({
			ItemId = entry.ItemId,
			Quantity = qty,
		}),
		Reward = table.freeze({
			Gold = goldReward,
			Tokens = tokenReward,
			Items = nil,
		}),
		ExpiresAt = now + CommissionRewardConfig.REFRESH_INTERVAL,
	})
end

function CommissionGenerator:_ComputeRewards(entry: any, qty: number): (number, number)
	local gold = math.floor(entry.BaseGold * qty * CommissionRewardConfig.GOLD_PER_QTY_MULT)
	local tokens = math.max(1, math.floor(entry.BaseTkn * qty * CommissionRewardConfig.TOKEN_PER_QTY_MULT))
	return gold, tokens
end

return CommissionGenerator
