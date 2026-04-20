--!strict

--[=[
	@class Errors
	Frozen table of error message string constants for the Commission context.
	@server
]=]

--[=[
	@prop PLAYER_NOT_FOUND string
	@within Errors
	Error message returned when the player's commission state cannot be found.
]=]

--[=[
	@prop COMMISSION_NOT_FOUND string
	@within Errors
	Error message returned when the requested commission does not exist on the board.
]=]

--[=[
	@prop COMMISSION_NOT_ACTIVE string
	@within Errors
	Error message returned when the requested commission is not in the active list.
]=]

--[=[
	@prop MAX_ACTIVE_REACHED string
	@within Errors
	Error message returned when the player already has the maximum number of active commissions.
]=]

--[=[
	@prop INSUFFICIENT_ITEMS string
	@within Errors
	Error message returned when the player does not have enough items to deliver the commission.
]=]

--[=[
	@prop INSUFFICIENT_TOKENS string
	@within Errors
	Error message returned when the player does not have enough commission tokens.
]=]

--[=[
	@prop TIER_ALREADY_MAX string
	@within Errors
	Error message returned when the player is already at the maximum commission tier.
]=]

--[=[
	@prop INVALID_COMMISSION_ID string
	@within Errors
	Error message returned when the provided commission ID is nil or empty.
]=]

--[=[
	@prop INVENTORY_NOT_FOUND string
	@within Errors
	Error message returned when the player's inventory state cannot be retrieved.
]=]

--[=[
	@prop DELIVER_FAILED string
	@within Errors
	Error message returned when item removal fails during commission delivery.
]=]

--[=[
	@prop REWARD_FAILED string
	@within Errors
	Error message returned when reward granting fails during commission delivery.
]=]

return table.freeze({
	TIER_LOCKED = "This commission tier is not yet available in your current chapter",
	PLAYER_NOT_FOUND = "Player not found",
	COMMISSION_NOT_FOUND = "Commission not found on board",
	COMMISSION_NOT_ACTIVE = "Commission is not in active list",
	MAX_ACTIVE_REACHED = "Maximum active commissions reached",
	INSUFFICIENT_ITEMS = "Not enough items to deliver",
	INSUFFICIENT_TOKENS = "Not enough commission tokens",
	TIER_ALREADY_MAX = "Already at maximum commission tier",
	INVALID_COMMISSION_ID = "Invalid commission ID",
	INVENTORY_NOT_FOUND = "Could not retrieve inventory",
	DELIVER_FAILED = "Failed to deliver commission items",
	REWARD_FAILED = "Failed to grant commission rewards",
	VISITOR_OFFER_NOT_FOUND = "Visitor offer not found",
	VISITOR_OFFER_ALREADY_PENDING = "A visitor offer is already pending",
})
