--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MasterDebug = require(ReplicatedStorage.Config.DebugConfig)
local NPCDebug = require(script.Parent.DebugConfig)

--[[
	Debug Logger

	Helper to simplify debug logging checks across the NPC context.
	Checks master flag, context flag, service flag, and milestone flag before logging.
]]

local DebugLogger = {}
DebugLogger.__index = DebugLogger

function DebugLogger.new()
	local self = setmetatable({}, DebugLogger)
	return self
end

--[[
	Logs a debug message if all flags are enabled.

	@param service - The service name (e.g., "SetFlag", "GetFlags")
	@param milestone - The milestone type (e.g., "Validation", "Persistence")
	@param message - The message to log (e.g., "userId: 123 - Validation passed")
]]
function DebugLogger:Log(service: string, milestone: string, message: string)
	-- Check master flag
	if not MasterDebug.ENABLED then
		return
	end

	-- Check context-level flag
	if not NPCDebug.NPC_ENABLED then
		return
	end

	-- Check service-level flag (convert to SCREAMING_SNAKE_CASE)
	local serviceKey = service:gsub("([A-Z])", "_%1"):upper():sub(2)
	if not NPCDebug[serviceKey] then
		return
	end

	-- Check milestone-level flag (convert to SCREAMING_SNAKE_CASE)
	local milestoneKey = milestone:gsub("([A-Z])", "_%1"):upper():sub(2)
	if not NPCDebug[milestoneKey] then
		return
	end

	-- All checks passed - log the message
	print("[NPC:" .. service .. "] " .. message)
end

return DebugLogger
