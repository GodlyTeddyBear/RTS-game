--!strict

local UnitTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitTypes)

type IssueMoveOrderRequest = UnitTypes.IssueMoveOrderRequest
export type TIssuedMoveOrderPreview = {
	Destination: Vector3,
	UnitGuids: { string },
	RootsByGuid: { [string]: Instance },
}

local IssueUnitMoveOrderCommand = {}
IssueUnitMoveOrderCommand.__index = IssueUnitMoveOrderCommand

function IssueUnitMoveOrderCommand.new()
	local self = setmetatable({}, IssueUnitMoveOrderCommand)
	return self
end

local function _BuildRootsByGuid(selectionState: any, unitGuids: { string }): ({ string }, { [string]: Instance })
	local trackedUnitGuids = table.create(#unitGuids)
	local rootsByGuid = {}

	for _, unitGuid in ipairs(unitGuids) do
		local root = selectionState.SelectedRootsByGuid[unitGuid]
		if root ~= nil and root.Parent ~= nil then
			trackedUnitGuids[#trackedUnitGuids + 1] = unitGuid
			rootsByGuid[unitGuid] = root
		end
	end

	return trackedUnitGuids, rootsByGuid
end

function IssueUnitMoveOrderCommand:Execute(deps: any, mouseSnapshot: any): TIssuedMoveOrderPreview?
	local destination = deps.resolveMoveOrderDestinationQuery:Execute(mouseSnapshot)
	if destination == nil then
		return nil
	end

	local selectionState = deps.selectionAtom()
	local unitGuids = deps.buildMoveOrderUnitGuidsQuery:Execute(selectionState)
	if #unitGuids == 0 then
		return nil
	end

	local trackedUnitGuids, rootsByGuid = _BuildRootsByGuid(selectionState, unitGuids)
	if #trackedUnitGuids == 0 then
		return nil
	end

	local request: IssueMoveOrderRequest = {
		UnitGuids = trackedUnitGuids,
		Destination = destination,
	}
	if not deps.unitContext:IssueMoveOrder(request):await() then
		return nil
	end

	return {
		Destination = destination,
		UnitGuids = trackedUnitGuids,
		RootsByGuid = rootsByGuid,
	}
end

return IssueUnitMoveOrderCommand
