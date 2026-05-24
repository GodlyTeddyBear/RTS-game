--!strict

local UnitTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitTypes)

type IssueMoveOrderRequest = UnitTypes.IssueMoveOrderRequest

local IssueUnitMoveOrderCommand = {}
IssueUnitMoveOrderCommand.__index = IssueUnitMoveOrderCommand

function IssueUnitMoveOrderCommand.new()
	local self = setmetatable({}, IssueUnitMoveOrderCommand)
	return self
end

function IssueUnitMoveOrderCommand:Execute(deps: any, mouseSnapshot: any): boolean
	local destination = deps.resolveMoveOrderDestinationQuery:Execute(mouseSnapshot)
	if destination == nil then
		return false
	end

	local unitGuids = deps.buildMoveOrderUnitGuidsQuery:Execute(deps.selectionAtom())
	if #unitGuids == 0 then
		return false
	end

	local request: IssueMoveOrderRequest = {
		UnitGuids = unitGuids,
		Destination = destination,
	}
	return deps.unitRemoteClient:IssueMoveOrder(request)
end

return IssueUnitMoveOrderCommand
