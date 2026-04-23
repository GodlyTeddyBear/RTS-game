--!strict

--[=[
    @class ActionStateTransitionSpec
    Shared specification that describes which BehaviorSystem action-state transitions are allowed.
    @server
    @client
]=]

local ActionStateTransitionSpec = {}

--[=[
    Checks whether a pending action can start from the current action-state label.
    @within ActionStateTransitionSpec
    @param actionState any -- Current action-state label
    @return boolean -- Whether the start transition is allowed
    @return string? -- Blocking reason when the transition is disallowed
]=]
function ActionStateTransitionSpec.CanStartFromActionState(actionState: any): (boolean, string?)
	if actionState == nil then
		return true, nil
	end

	if actionState == "Committed" then
		return false, "Committed"
	end

	return true, nil
end

--[=[
    Checks whether a start result should be committed into the owning action-state table.
    @within ActionStateTransitionSpec
    @param status any -- Start result status
    @return boolean -- Whether the result can be committed
]=]
function ActionStateTransitionSpec.IsStartResultCommittable(status: any): boolean
	return status == "Started" or status == "Replaced"
end

--[=[
    Checks whether a tick result is terminal and can be resolved.
    @within ActionStateTransitionSpec
    @param status any -- Tick result status
    @return boolean -- Whether the result is terminal
]=]
function ActionStateTransitionSpec.IsTickResultTerminal(status: any): boolean
	return status == "Success" or status == "Fail" or status == "MissingAction"
end

return table.freeze(ActionStateTransitionSpec)
