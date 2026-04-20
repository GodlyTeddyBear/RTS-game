--!strict

local NPCCommandTypes = require(script.Parent.Parent.Parent.Types.NPCCommandTypes)
export type TNPCEntry = NPCCommandTypes.TNPCEntry
export type TOrderEntry = NPCCommandTypes.TOrderEntry

-- Class → accent color mapping derived from combat NPC UI design
-- These mirror ColorTokens.NPC values
local CLASS_ACCENT: { [string]: Color3 } = {
	Warrior = Color3.fromRGB(255, 180, 172),
	Scout = Color3.fromRGB(233, 195, 73),
	Archer = Color3.fromRGB(255, 180, 172),
}

local DEFAULT_ACCENT = Color3.fromRGB(168, 162, 158)

local NPCEntryViewModel = {}

--[[
	Build a TNPCEntry from a selected NPC model and its selection index.
]]
-- Map LastCommand attribute to a stance string
local COMMAND_TO_STANCE: { [string]: string } = {
	MoveToPosition = "MOVING",
	AttackTarget = "ATTACKING",
	AttackNearest = "ATTACKING",
	HoldPosition = "HOLDING",
}

function NPCEntryViewModel.fromModel(npcId: string, model: Model, index: number, isSelected: boolean): TNPCEntry
	local npcType = model:GetAttribute("NPCType") :: string? or "NPC"
	local controlMode = model:GetAttribute("ControlMode") :: string? or "Auto"

	local hpPercent = 1.0
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MaxHealth > 0 then
		hpPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	end

	local accentColor = CLASS_ACCENT[npcType] or DEFAULT_ACCENT

	-- Derive stance from LastCommand attribute
	local lastCommand = model:GetAttribute("LastCommand") :: string?
	local stance = if lastCommand then (COMMAND_TO_STANCE[lastCommand] or "IDLE") else "IDLE"

	-- Read target name for attack commands
	local targetName = model:GetAttribute("TargetName") :: string?

	return table.freeze({
		NPCId = npcId,
		DisplayName = npcType,
		Class = string.upper(npcType),
		HPPercent = hpPercent,
		Mode = if controlMode == "Manual" then "MANUAL" else "AUTO",
		Stance = stance :: any,
		TargetName = targetName,
		AccentColor = accentColor,
		LayoutOrder = index,
		isSelected = isSelected,
	} :: TNPCEntry)
end

--[[
	Build an ordered array of TNPCEntry from the full roster and selection state.
	rosterModels: all live adventurer NPCs { [npcId]: Model }
	selectedIds: currently selected NPC ids { [npcId]: boolean }
]]
function NPCEntryViewModel.buildList(
	rosterModels: { [string]: Model },
	selectedIds: { [string]: boolean }
): { TNPCEntry }
	local entries = {}
	local index = 1
	for npcId, model in rosterModels do
		if model and model.Parent then
			table.insert(entries, NPCEntryViewModel.fromModel(npcId, model, index, selectedIds[npcId] == true))
			index += 1
		end
	end
	return entries
end

--[[
	Format a recent order timestamp (seconds since issuedAt) as a short label.
]]
function NPCEntryViewModel.formatTimestamp(issuedAt: number): string
	local elapsed = math.floor(os.clock() - issuedAt)
	if elapsed < 60 then
		return elapsed .. "s ago"
	else
		return math.floor(elapsed / 60) .. "m ago"
	end
end

return NPCEntryViewModel
