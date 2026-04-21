--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)
local CommanderConfig = require(ReplicatedStorage.Contexts.Commander.Config.CommanderConfig)
local CommandRegistry = require(ReplicatedStorage.Contexts.Log.CommandRegistry)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local BlinkServer = require(ReplicatedStorage.Network.Generated.CommanderSyncServer)

local CommanderSyncService = require(script.Parent.Infrastructure.Persistence.CommanderSyncService)
local AbilityService = require(script.Parent.CommanderDomain.Services.AbilityService)
local CooldownService = require(script.Parent.CommanderDomain.Services.CooldownService)
local UseAbilityCommand = require(script.Parent.Application.Commands.UseAbilityCommand)
local GetCommanderStateQuery = require(script.Parent.Application.Queries.GetCommanderStateQuery)
local GetCooldownQuery = require(script.Parent.Application.Queries.GetCooldownQuery)
local Errors = require(script.Parent.Errors)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure
local fromNilable = Result.fromNilable

type CommanderState = CommanderTypes.CommanderState
type SlotKey = CommanderTypes.SlotKey

local DEVELOPER_USER_ID = 205423638

--[=[
	@class CommanderContext
	Owns the authoritative commander state, ability execution, and death signaling.
	@server
]=]
local CommanderContext = Knit.CreateService({
	Name = "CommanderContext",
	Client = {},
})

--[=[
	Initializes the commander sync service, commands, and queries.
	@within CommanderContext
]=]
function CommanderContext:KnitInit()
	-- Register the commander stack before any player joins can trigger hydration.
	local registry = Registry.new("Server")
	registry:Register("BlinkServer", BlinkServer)
	registry:Register("CommanderSyncService", CommanderSyncService.new(), "Infrastructure")
	registry:Register("AbilityService", AbilityService.new(), "Domain")
	registry:Register("CooldownService", CooldownService.new(), "Domain")
	registry:Register("UseAbilityCommand", UseAbilityCommand.new(), "Application")
	registry:Register("GetCommanderStateQuery", GetCommanderStateQuery.new(), "Application")
	registry:Register("GetCooldownQuery", GetCooldownQuery.new(), "Application")
	registry:InitAll()

	self._syncService = registry:Get("CommanderSyncService")
	self._useAbilityCommand = registry:Get("UseAbilityCommand")
	self._getCommanderStateQuery = registry:Get("GetCommanderStateQuery")
	self._getCooldownQuery = registry:Get("GetCooldownQuery")
	self._playerAddedConnection = nil
	self._playerRemovingConnection = nil

	self:_RegisterDeveloperLogCommands()
end

local function _parseUserId(rawValue: string?): number
	local parsed = tonumber(rawValue)
	if parsed == nil then
		return DEVELOPER_USER_ID
	end

	return math.floor(parsed)
end

local function _isValidSlot(slotKey: string): boolean
	for _, slot in CommanderConfig.SLOTS do
		if slot.key == slotKey then
			return true
		end
	end

	return false
end

function CommanderContext:_RegisterDeveloperLogCommands()
	CommandRegistry.Register({
		name = "Commander.GetStateSummary",
		context = "Commander",
		description = "Shows HP and active cooldown count for a commander user id.",
		params = {
			{ name = "userId", label = "User ID", default = tostring(DEVELOPER_USER_ID) },
		},
		handler = function(params: { [string]: string }): (boolean, string)
			local userId = _parseUserId(params.userId)
			local state = self._getCommanderStateQuery:Execute(userId)
			if state == nil then
				return false, string.format("No commander state found for user %d", userId)
			end

			local cooldownCount = 0
			for _, cooldown in pairs(state.cooldowns) do
				if cooldown ~= nil then
					cooldownCount += 1
				end
			end

			return true, string.format(
				"userId=%d hp=%d/%d activeCooldowns=%d",
				userId,
				state.hp,
				state.maxHp,
				cooldownCount
			)
		end,
	})

	CommandRegistry.Register({
		name = "Commander.GetCooldownRemaining",
		context = "Commander",
		description = "Returns remaining cooldown in seconds for a commander slot.",
		params = {
			{ name = "userId", label = "User ID", default = tostring(DEVELOPER_USER_ID) },
			{ name = "slotKey", label = "Slot Key", default = "Mobility" },
		},
		handler = function(params: { [string]: string }): (boolean, string)
			local userId = _parseUserId(params.userId)
			local slotKey = params.slotKey or "Mobility"
			if not _isValidSlot(slotKey) then
				return false, string.format("Invalid slotKey '%s'", slotKey)
			end

			local remaining = self._getCooldownQuery:Execute(userId, slotKey :: SlotKey)
			return true, string.format("userId=%d slot=%s remaining=%.2fs", userId, slotKey, remaining)
		end,
	})
end

--[=[
	Starts commander hydration for current and future players.
	@within CommanderContext
]=]
function CommanderContext:KnitStart()
	-- Hydrate late joiners so they receive the commander atom immediately on spawn.
	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player: Player)
		self._syncService:LoadPlayer(player.UserId)
		self._syncService:HydratePlayer(player)
	end)

	-- Remove per-player commander state as soon as the player leaves the server.
	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		self._syncService:RemovePlayer(player.UserId)
	end)

	-- Backfill players already in the server before Knit finished starting.
	for _, player in Players:GetPlayers() do
		self._syncService:LoadPlayer(player.UserId)
		self._syncService:HydratePlayer(player)
	end
end

--[=[
	Applies damage to the commander and emits the commander-death event if lethal.
	@within CommanderContext
	@param player Player -- The player whose commander should take damage.
	@param amount number -- The amount of damage to apply.
	@return Result.Result<number> -- The remaining HP after damage is applied.
]=]
function CommanderContext:ApplyDamage(player: Player, amount: number): Result.Result<number>
	return Catch(function()
		-- Validate the request before touching authoritative state.
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(amount > 0, "InvalidDamageAmount", Errors.INVALID_DAMAGE_AMOUNT, { amount = amount })

		-- Read the current HP first so lethal transitions only fire once.
		local previousState = Try(fromNilable(
			self._getCommanderStateQuery:Execute(player.UserId),
			"CommanderNotFound",
			Errors.COMMANDER_NOT_FOUND,
			{ userId = player.UserId }
		)) :: CommanderState

		-- Apply damage through the sync service so client replication stays centralized.
		local nextHp = self._syncService:ApplyDamage(player.UserId, amount)

		-- Emit the shared death event only on the first lethal transition.
		if previousState.hp > 0 and nextHp <= 0 then
			GameEvents.Bus:Emit(GameEvents.Events.Commander.CommanderDied, player)
		end

		return Ok(nextHp)
	end, "Commander:ApplyDamage")
end

--[=[
	Reads the current commander state for a player.
	@within CommanderContext
	@param userId number -- The player user id to read.
	@return Result.Result<CommanderState?> -- The cloned commander state, or `nil` if uninitialized.
]=]
function CommanderContext:GetCommanderState(userId: number): Result.Result<CommanderState?>
	return Catch(function()
		return Ok(self._getCommanderStateQuery:Execute(userId))
	end, "Commander:GetCommanderState")
end

--[=[
	Reads the remaining cooldown time for a commander ability slot.
	@within CommanderContext
	@param userId number -- The player user id to read.
	@param slotKey SlotKey -- The ability slot key to inspect.
	@return Result.Result<number> -- The remaining cooldown time in seconds.
]=]
function CommanderContext:GetCooldownRemaining(userId: number, slotKey: SlotKey): Result.Result<number>
	return Catch(function()
		return Ok(self._getCooldownQuery:Execute(userId, slotKey))
	end, "Commander:GetCooldownRemaining")
end

--[=[
	Uses a commander ability for the supplied player.
	@within CommanderContext
	@param player Player -- The player using the ability.
	@param slotKey SlotKey -- The ability slot key to activate.
	@return Result.Result<{ slotKey: SlotKey }> -- The accepted slot key.
]=]
function CommanderContext:UseAbility(player: Player, slotKey: SlotKey): Result.Result<{ slotKey: SlotKey }>
	return Catch(function()
		-- Validate the caller before delegating to the command layer.
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		return self._useAbilityCommand:Execute(player, slotKey)
	end, "Commander:UseAbility")
end

--[=[
	Invokes the commander ability remote from the client.
	@within CommanderContext
	@param player Player -- The calling player.
	@param slotKey SlotKey -- The ability slot key to activate.
	@return Result.Result<{ slotKey: SlotKey }> -- The accepted slot key.
]=]
function CommanderContext.Client:UseAbility(player: Player, slotKey: SlotKey)
	return self.Server:UseAbility(player, slotKey)
end

--[=[
	Disconnects commander lifecycle listeners and tears down sync state.
	@within CommanderContext
]=]
function CommanderContext:Destroy()
	if self._syncService then
		self._syncService:Destroy()
	end

	if self._playerAddedConnection then
		self._playerAddedConnection:Disconnect()
	end

	if self._playerRemovingConnection then
		self._playerRemovingConnection:Disconnect()
	end
end

WrapContext(CommanderContext, "Commander")

return CommanderContext
