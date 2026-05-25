--!strict

--[=[
    @class IssueUnitMoveOrderCommand
    Issues a move-order request after resolving a valid destination and filtering out detached unit roots.

    Owns the client-side request orchestration only; does not own destination math or unit movement execution.
    @client
]=]

local UnitTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitTypes)

type IssueMoveOrderRequest = UnitTypes.IssueMoveOrderRequest
export type TIssuedMoveOrderPreview = {
	Destination: Vector3,
	UnitGuids: { string },
	RootsByGuid: { [string]: Instance },
}

local IssueUnitMoveOrderCommand = {}
IssueUnitMoveOrderCommand.__index = IssueUnitMoveOrderCommand

-- Creates a command that can turn the current selection into an authoritative move order request.
function IssueUnitMoveOrderCommand.new()
	local self = setmetatable({}, IssueUnitMoveOrderCommand)
	return self
end

-- Keeps only the selected roots that still exist so the server never receives stale unit handles.
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

-- Resolves the click destination, sends the move request, and returns the preview payload when the request succeeds.
function IssueUnitMoveOrderCommand:Execute(deps: any, mouseSnapshot: any): TIssuedMoveOrderPreview?
	-- Resolve the world hit first; without a destination there is no order to send.
	local destination = deps.resolveMoveOrderDestinationQuery:Execute(deps.runtimeService, mouseSnapshot)
	if destination == nil then
		return nil
	end

	-- Convert the current selection into unit GUIDs that are valid for movement.
	local selectionState = deps.selectionAtom()
	local unitGuids = deps.buildMoveOrderUnitGuidsQuery:Execute(selectionState)
	if #unitGuids == 0 then
		return nil
	end

	local trackedUnitGuids, rootsByGuid = _BuildRootsByGuid(selectionState, unitGuids)
	if #trackedUnitGuids == 0 then
		return nil
	end

	-- Send the authoritative move request only after the local preview has been reduced to live roots.
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
