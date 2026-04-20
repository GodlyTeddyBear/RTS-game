--!strict

--[[
	UpgradeTypes — Shared type definitions for the Upgrade bounded context.
]]

-- Per-player upgrade levels: maps upgradeId -> level.
-- Absence of a key means level 0.
export type TUpgradeLevels = { [string]: number }

return {}
