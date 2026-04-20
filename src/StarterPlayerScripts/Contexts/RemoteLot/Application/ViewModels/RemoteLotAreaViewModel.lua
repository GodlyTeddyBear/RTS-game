--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteLotAreaConfig = require(ReplicatedStorage.Contexts.RemoteLot.Config.RemoteLotAreaConfig)

export type TRemoteLotAreaRow = {
	AreaId: string,
	TargetId: string,
	DisplayName: string,
	Description: string,
	Cost: number,
	IsUnlocked: boolean,
	CanAfford: boolean,
	RequirementText: string,
	StatusText: string,
	ButtonText: string,
	SortOrder: number,
}

local RemoteLotAreaViewModel = {}

local function _BuildRequirementText(conditions: any): string
	local parts = {}
	if conditions.Chapter then
		table.insert(parts, "Chapter " .. tostring(conditions.Chapter))
	end
	if conditions.CommissionTier then
		table.insert(parts, "Commission Tier " .. tostring(conditions.CommissionTier))
	end
	if conditions.QuestsCompleted then
		table.insert(parts, tostring(conditions.QuestsCompleted) .. " quests")
	end
	if conditions.WorkerCount then
		table.insert(parts, tostring(conditions.WorkerCount) .. " workers")
	end
	if conditions.SmelterPlaced then
		table.insert(parts, "Smelter placed")
	end
	if conditions.Ch2FirstVictory then
		table.insert(parts, "Chapter 2 victory")
	end
	if #parts == 0 then
		return "No progression requirement"
	end
	return table.concat(parts, " | ")
end

function RemoteLotAreaViewModel.fromState(unlockState: { [string]: boolean }, gold: number): { TRemoteLotAreaRow }
	local rows = {}

	for _, areaDef in RemoteLotAreaConfig do
		local cost = areaDef.Conditions.Gold or 0
		local isUnlocked = unlockState[areaDef.TargetId] == true
		local canAfford = gold >= cost

		table.insert(rows, {
			AreaId = areaDef.AreaId,
			TargetId = areaDef.TargetId,
			DisplayName = areaDef.DisplayName,
			Description = areaDef.Description,
			Cost = cost,
			IsUnlocked = isUnlocked,
			CanAfford = canAfford,
			RequirementText = _BuildRequirementText(areaDef.Conditions),
			StatusText = if isUnlocked then "Unlocked" else "Locked",
			ButtonText = if isUnlocked then "Unlocked" elseif cost > 0 then "Unlock for " .. tostring(cost) .. " gold" else "Unlock",
			SortOrder = areaDef.SortOrder,
		})
	end

	table.sort(rows, function(a: TRemoteLotAreaRow, b: TRemoteLotAreaRow)
		return a.SortOrder < b.SortOrder
	end)

	return table.freeze(rows)
end

return RemoteLotAreaViewModel
