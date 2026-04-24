--!strict

local Types = require(script.Parent.Parent.Types)

return function(BaseExecutor)
	--[=[
		@within BaseExecutor
		Creates a new executor with the supplied action metadata.
		@param config TExecutorConfig -- Executor metadata used by subclasses.
		@return BaseExecutor -- Base executor instance.
	]=]
	function BaseExecutor.new(config: Types.TExecutorConfig)
		local self = setmetatable({}, BaseExecutor)
		self.Config = config
		self._entityState = {}
		self._trackedAsyncResources = {}
		self._lastFailureReason = {}
		return self
	end

	--[=[
		@within BaseExecutor
		Performs start-time validation before `OnStart` executes.
		@param _entity number -- Entity id being processed.
		@param _data any? -- Action payload supplied by the behavior tree.
		@param _services any -- Shared executor services for the current tick.
		@return boolean -- Whether the action can start.
		@return string? -- Optional failure reason when the action cannot start.
	]=]
	function BaseExecutor:CanStart(_entity: number, _data: any?, _services: any): (boolean, string?)
		return true, nil
	end

	--[=[
		@within BaseExecutor
		Runs post-validation start logic for the action.
		@param _entity number -- Entity id being processed.
		@param _data any? -- Action payload supplied by the behavior tree.
		@param _services any -- Shared executor services for the current tick.
	]=]
	function BaseExecutor:OnStart(_entity: number, _data: any?, _services: any)
	end

	--[=[
		@within BaseExecutor
		Performs tick-time validation before `OnTick` executes.
		@param _entity number -- Entity id being processed.
		@param _services any -- Shared executor services for the current tick.
		@return boolean -- Whether the action can continue ticking.
		@return string? -- Optional failure reason when the action cannot continue.
	]=]
	function BaseExecutor:CanContinue(_entity: number, _services: any): (boolean, string?)
		return true, nil
	end

	--[=[
		@within BaseExecutor
		Runs one action tick after tick-time validation succeeds.
		@param _entity number -- Entity id being processed.
		@param _dt number -- Frame delta time for the current tick.
		@param _services any -- Shared executor services for the current tick.
		@return string -- Current action status.
	]=]
	function BaseExecutor:OnTick(_entity: number, _dt: number, _services: any): string
		return self:Running()
	end

	--[=[
		@within BaseExecutor
		Runs action-specific cancellation logic before tracked state cleanup.
		@param _entity number -- Entity id being processed.
		@param _services any -- Shared executor services for the current tick.
	]=]
	function BaseExecutor:OnCancel(_entity: number, _services: any)
	end

	--[=[
		@within BaseExecutor
		Runs action-specific completion logic before optional tracked state cleanup.
		@param _entity number -- Entity id being processed.
		@param _services any -- Shared executor services for the current tick.
	]=]
	function BaseExecutor:OnComplete(_entity: number, _services: any)
	end

	--[=[
		@within BaseExecutor
		Starts an action and reports whether execution can continue.
		@param _entity number -- Enemy entity id being processed.
		@param _data any? -- Action payload supplied by the behavior tree.
		@param _services any -- Shared executor services for the current tick.
		@return boolean -- Whether the action can start.
		@return string? -- Optional failure reason when the action cannot start.
	]=]
	function BaseExecutor:Start(_entity: number, _data: any?, _services: any): (boolean, string?)
		local canStart, failureReason = self:CanStart(_entity, _data, _services)
		if not canStart then
			if failureReason ~= nil then
				self._lastFailureReason[_entity] = failureReason
			end
			return false, failureReason
		end

		self:OnStart(_entity, _data, _services)
		return true, nil
	end

	--[=[
		@within BaseExecutor
		Advances an action by one tick and returns the current execution status.
		@param _entity number -- Enemy entity id being processed.
		@param _dt number -- Frame delta time for the current tick.
		@param _services any -- Shared executor services for the current tick.
		@return string -- Current action status.
	]=]
	function BaseExecutor:Tick(_entity: number, _dt: number, _services: any): string
		local canContinue, failureReason = self:CanContinue(_entity, _services)
		if not canContinue then
			return self:Fail(_entity, failureReason)
		end

		return self:OnTick(_entity, _dt, _services)
	end

	--[=[
		@within BaseExecutor
		Cancels any in-flight state associated with the action.
		@param _entity number -- Enemy entity id being processed.
		@param _services any -- Shared executor services for the current tick.
	]=]
	function BaseExecutor:Cancel(_entity: number, _services: any)
		self:OnCancel(_entity, _services)
		self:CancelTrackedTasks(_entity)
		self:ClearEntityState(_entity)
	end

	--[=[
		@within BaseExecutor
		Finalizes the action after a successful completion.
		@param _entity number -- Enemy entity id being processed.
		@param _services any -- Shared executor services for the current tick.
	]=]
	function BaseExecutor:Complete(_entity: number, _services: any)
		self:OnComplete(_entity, _services)
		if self.Config.AutoCleanupOnComplete then
			self:CancelTrackedTasks(_entity)
			self:ClearEntityState(_entity)
		end
	end
end
