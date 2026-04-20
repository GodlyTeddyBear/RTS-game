--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.NPCFlagSyncServer)

-- Application Services
local SetFlag = require(script.Parent.Application.Services.SetFlag)
local GetFlags = require(script.Parent.Application.Services.GetFlags)

-- Domain Services
local FlagValidator = require(script.Parent.NPCDomain.Services.FlagValidator)

-- Infrastructure Services
local FlagSyncService = require(script.Parent.Infrastructure.Services.FlagSyncService)
local FlagPersistenceService = require(script.Parent.Infrastructure.Services.FlagPersistenceService)

-- Shared Config
local NPCConfig = require(ReplicatedStorage.Contexts.NPC.Config.NPCConfig)

-- Data access
local DataManager = require(game:GetService("ServerScriptService").Data.DataManager)

--[[
	Abstraction for resolving players by userId.
	Allows different implementations (Roblox Players service, test mocks).
]]
export type IPlayerResolver = {
	GetPlayerByUserId: (self: IPlayerResolver, userId: number) -> Player?,
}

--[[
	Creates the default player resolver using Roblox Players service.
	@return IPlayerResolver - Default resolver
]]
local function _CreateDefaultPlayerResolver(): IPlayerResolver
	return {
		GetPlayerByUserId = function(_, userId: number): Player?
			return game:GetService("Players"):GetPlayerByUserId(userId)
		end,
	}
end

--[[
	Resolves a player instance from userId with error handling.
	@param userId number - User ID to resolve
	@param playerResolver IPlayerResolver - Player resolver service
	@return boolean - Success status
	@return Player|string - Player instance on success, error message on failure
]]
local function _ResolvePlayer(userId: number, playerResolver: IPlayerResolver): (boolean, Player | string)
	local player = playerResolver:GetPlayerByUserId(userId)
	if not player then
		return false, "Player not found"
	end
	return true, player
end

local NPCContext = Knit.CreateService({
	Name = "NPCContext",
	Client = {},
})

---
-- Knit Lifecycle
---

function NPCContext:KnitInit()
	-- Infrastructure (no cross-context dependencies)
	self.SyncService = FlagSyncService.new(BlinkServer)
	self.FlagsAtom = self.SyncService:GetFlagsAtom()

	-- Domain (no cross-context dependencies)
	self.Validator = FlagValidator.new()

	-- Persistence (needs DataManager only)
	self.PersistenceService = FlagPersistenceService.new(DataManager)

	-- Player resolution abstraction
	self.PlayerResolver = _CreateDefaultPlayerResolver()

	-- Application services (no cross-context deps needed, init here)
	self.SetFlagService = SetFlag.new(self.Validator, self.SyncService, self.PersistenceService)
	self.GetFlagsService = GetFlags.new(self.SyncService)
end

function NPCContext:KnitStart()
	print("NPCContext Started")
end

---
-- Server Methods (pass-through to application services)
---

function NPCContext:SetFlag(userId: number, flagName: string, flagValue: any): (boolean, string?)
	local success, playerOrError = _ResolvePlayer(userId, self.PlayerResolver)
	if not success then
		return false, playerOrError :: string
	end

	return self.SetFlagService:Execute(playerOrError :: Player, userId, flagName, flagValue)
end

function NPCContext:GetFlags(userId: number): (boolean, { [string]: any } | string)
	return self.GetFlagsService:Execute(userId)
end

--- Validate NPC exists and auto-set HasMet flag
function NPCContext:InteractWithNPC(userId: number, npcId: string): (boolean, string?)
	-- Validate NPC exists in config
	if not NPCConfig[npcId] then
		return false, "NPC does not exist in config: " .. tostring(npcId)
	end

	-- Auto-set HasMet flag
	local hasMetFlag = "HasMet_" .. npcId
	local currentFlags = self.SyncService:GetPlayerFlagsReadOnly(userId)
	if not currentFlags or not currentFlags[hasMetFlag] then
		local setSuccess, setError = self:SetFlag(userId, hasMetFlag, true)
		if not setSuccess then
			warn("[NPC:InteractWithNPC] userId:", userId, "- Failed to set HasMet flag:", setError)
		end
	end

	return true, nil
end

--- Load flags from persistence into atom (used during player data loading)
function NPCContext:LoadPlayerFlags(userId: number, flagsData: { [string]: any })
	self.SyncService:LoadPlayerFlags(userId, flagsData)
end

--- Remove all flags for a player (cleanup on leave)
function NPCContext:RemovePlayerFlags(userId: number)
	self.SyncService:RemovePlayerFlags(userId)
end

--- Hydrate player with current flag state
function NPCContext:HydratePlayer(player: Player)
	self.SyncService:HydratePlayer(player)
end

---
-- Client-callable Methods
---

function NPCContext.Client:SetFlag(player: Player, flagName: string, flagValue: any): (boolean, string?)
	local userId = player.UserId
	return self.Server:SetFlag(userId, flagName, flagValue)
end

function NPCContext.Client:GetFlags(player: Player): (boolean, { [string]: any } | string)
	local userId = player.UserId
	return self.Server:GetFlags(userId)
end

function NPCContext.Client:InteractWithNPC(player: Player, npcId: string): (boolean, string?)
	local userId = player.UserId
	return self.Server:InteractWithNPC(userId, npcId)
end

function NPCContext.Client:RequestFlagState(player: Player): boolean
	self.Server:HydratePlayer(player)
	return true
end

return NPCContext
