--!strict

--[=[
	@class CommanderContext
	Purpose: Owns the authoritative commander runtime, including state hydration, ability execution, god-mode overrides, and death signaling.
	Used In System: Started by Knit on the server and called by combat, run, and developer log flows that need commander state or mutation.
	High-Level Flow: Initialize registry -> hydrate player state -> service queries and commands -> sync changes and emit death signals.
	Boundaries: Owns orchestration only; does not own commander formulas, sync payload shape, or client presentation.
	@server
]=]
-- [Dependencies]

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

-- [Types]

type CommanderState = CommanderTypes.CommanderState
type SlotKey = CommanderTypes.SlotKey

-- [Constants]

local DEVELOPER_USER_ID = 205423638

local CommanderContext = Knit.CreateService({
	Name = "CommanderContext",
	Client = {},
})

-- [Initialization]

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

	-- Cache the commander services and reset per-user runtime flags.
	self._syncService = registry:Get("CommanderSyncService")
	self._useAbilityCommand = registry:Get("UseAbilityCommand")
	self._getCommanderStateQuery = registry:Get("GetCommanderStateQuery")
	self._getCooldownQuery = registry:Get("GetCooldownQuery")
	self._godModeEnabledByUserId = {}
	self._playerAddedConnection = nil
	self._playerRemovingConnection = nil

	-- Register developer-only log commands after initialization completes.
	self:_RegisterDeveloperLogCommands()
end

-- [Private Helpers]

-- Normalizes a debug command user id so ad-hoc console input always resolves to a safe integer target.
local function _parseUserId(rawValue: string?): number
	local parsed = tonumber(rawValue)
	if parsed == nil then
		return DEVELOPER_USER_ID
	end

	return math.floor(parsed)
end

-- Validates that a debug command slot key matches one of the configured commander abilities.
local function _isValidSlot(slotKey: string): boolean
	for _, slot in CommanderConfig.SLOTS do
		if slot.key == slotKey then
			return true
		end
	end

	return false
end

-- Parses the flexible console toggle syntax used by developer log commands.
local function _parseBooleanDirective(rawValue: string?): boolean?
	if rawValue == nil then
		return nil
	end

	local normalized = string.lower(string.gsub(rawValue, "^%s*(.-)%s*$", "%1"))
	if normalized == "true" or normalized == "1" or normalized == "on" or normalized == "yes" then
		return true
	end
	if normalized == "false" or normalized == "0" or normalized == "off" or normalized == "no" then
		return false
	end

	return nil
end

-- Registers commander-focused developer log commands after the runtime dependencies are ready.
function CommanderContext:_RegisterDeveloperLogCommands()
	-- Register the commander state summary command for quick runtime inspection.
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

	-- Register the cooldown query command for slot-specific debugging.
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

	-- Register the god-mode toggle command for controlled damage testing.
	CommandRegistry.Register({
		name = "Run.SetGodMode",
		context = "Run",
		description = "Enable, disable, or toggle commander god mode for a user id.",
		params = {
			{ name = "userId", label = "User ID", default = tostring(DEVELOPER_USER_ID) },
			{ name = "enabled", label = "Enabled (true/false/toggle)", default = "toggle" },
		},
		handler = function(params: { [string]: string }): (boolean, string)
			local userId = _parseUserId(params.userId)
			local current = self:IsGodModeEnabled(userId)
			local enabledParam = params.enabled
			local nextEnabled: boolean

			if enabledParam == nil or string.lower(enabledParam) == "toggle" then
				nextEnabled = not current
			else
				local parsed = _parseBooleanDirective(enabledParam)
				if parsed == nil then
					return false, string.format("Invalid enabled value '%s'. Use true/false/toggle.", tostring(enabledParam))
				end
				nextEnabled = parsed
			end

			self:SetGodModeEnabled(userId, nextEnabled)
			Result.MentionEvent("CommanderContext:GodMode", "God mode updated", {
				UserId = userId,
				Enabled = nextEnabled,
			})

			return true, string.format("Run.SetGodMode userId=%d enabled=%s", userId, tostring(nextEnabled))
		end,
	})
end

-- [Public API]

--[=[
	Checks whether a user id is temporarily protected from commander damage.
	@within CommanderContext
	@param userId number -- The player user id to read.
	@return boolean -- Whether god mode is currently enabled.
]=]
function CommanderContext:IsGodModeEnabled(userId: number): boolean
	return self._godModeEnabledByUserId[userId] == true
end

-- This stays server-owned so debug state never leaks into the client atom.
--[=[
	Enables or clears the temporary commander damage override for a user id.
	@within CommanderContext
	@param userId number -- The player user id to update.
	@param isEnabled boolean -- Whether the override should stay enabled.
]=]
function CommanderContext:SetGodModeEnabled(userId: number, isEnabled: boolean)
	if isEnabled then
		self._godModeEnabledByUserId[userId] = true
		return
	end

	self._godModeEnabledByUserId[userId] = nil
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
		self:SetGodModeEnabled(player.UserId, false)
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

		if self:IsGodModeEnabled(player.UserId) then
			return Ok(previousState.hp)
		end

		-- Apply damage through the sync service so client replication stays centralized.
		local nextHp = self._syncService:ApplyDamage(player.UserId, amount)

		-- Emit the shared death event only on the first lethal transition.
		if previousState.hp > 0 and nextHp <= 0 then
			Result.MentionEvent("CommanderContext:CommanderDeath", "Commander HP reached zero", {
				UserId = player.UserId,
			})
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
