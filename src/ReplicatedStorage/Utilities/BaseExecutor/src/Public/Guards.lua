--!strict

return function(BaseExecutor)
	--[=[
		@within BaseExecutor
		Runs an ordered guard list until one fails and returns its reason.
		@param entity number -- Entity id being processed.
		@param services any -- Shared executor services for the current tick.
		@param guards { TGuard } -- Ordered predicate list to evaluate.
		@return boolean -- Whether all guards passed.
		@return string? -- First failure reason, if any guard failed.
	]=]
	function BaseExecutor:RunGuards(entity: number, services: any, guards: { any }): (boolean, string?)
		for _, guard in ipairs(guards) do
			if not guard.Check(entity, services) then
				self._lastFailureReason[entity] = guard.Reason
				return false, guard.Reason
			end
		end

		return true, nil
	end
end
