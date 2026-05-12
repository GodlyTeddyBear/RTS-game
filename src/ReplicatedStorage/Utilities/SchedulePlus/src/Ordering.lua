--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(script.Parent.Shared)
local Types = require(script.Parent.Types)

local UtilitiesFolder = ReplicatedStorage.Utilities
local Sandwich = require(UtilitiesFolder.Sandwich)

local Ordering = {}

local function _ValidateDependencies<T...>(dependenciesByJob: { [Types.TJob<T...>]: { Types.TJob<T...> } }): (boolean, string?)
	local visiting = {}
	local visited = {}

	local function visit(job: Types.TJob<T...>): (boolean, string?)
		if visiting[job] then
			return false, "Cycle detected in schedule graph"
		end

		if visited[job] then
			return true
		end

		visiting[job] = true

		local dependencies = dependenciesByJob[job]
		if dependencies ~= nil then
			for _, dependency in ipairs(dependencies) do
				if dependenciesByJob[dependency] == nil then
					return false, "Malformed dependency reference in schedule graph"
				end

				local success, message = visit(dependency)
				if not success then
					return false, message
				end
			end
		end

		visiting[job] = nil
		visited[job] = true
		return true
	end

	for job in pairs(dependenciesByJob) do
		local success, message = visit(job)
		if not success then
			return false, message
		end
	end

	return true
end

function Ordering.Schedule<T...>(config: Types.TScheduleConfig<T...>?): Types.TSchedule<T...>
	local function buildLegacySchedule()
		return Sandwich.schedule({
			before = if config then config.Before else nil,
			after = if config then config.After else nil,
		})
	end

	local legacySchedule = buildLegacySchedule()
	local dependenciesByJob = {} :: { [Types.TJob<T...>]: { Types.TJob<T...> } }

	local schedule = {} :: Types.TSchedule<T...>
	schedule.Graph = legacySchedule.graph
	schedule.Jobs = legacySchedule.jobs
	schedule.Before = if config then config.Before else nil
	schedule.After = if config then config.After else nil

	function schedule:Job(callback: Types.TJob<T...>, ...: Types.TJob<T...>): Types.TJob<T...>
		Shared.AssertFunction(callback, "callback")

		local dependencies = { ... }
		for _, dependency in ipairs(dependencies) do
			assert(dependenciesByJob[dependency] ~= nil, "dependency must be a job created by this schedule")
		end

		dependenciesByJob[callback] = dependencies
		return legacySchedule.job(callback, ...)
	end

	function schedule:Run(...: T...)
		local success, message = self:Validate()
		assert(success, message or "invalid schedule")
		legacySchedule.start(...)
	end

	function schedule:Validate(): (boolean, string?)
		return _ValidateDependencies(dependenciesByJob)
	end

	function schedule:Clear()
		table.clear(dependenciesByJob)
		legacySchedule = buildLegacySchedule()
		self.Graph = legacySchedule.graph
		self.Jobs = legacySchedule.jobs
	end

	function schedule:GetJobs(): { Types.TJob<T...> }
		return Shared.ShallowCopy(self.Jobs)
	end

	function schedule:HasJob(callback: Types.TJob<T...>): boolean
		return dependenciesByJob[callback] ~= nil
	end

	return schedule
end

function Ordering.Pipeline<TContext>(config: Types.TPipelineConfig<TContext>?): Types.TPipeline<TContext>
	local stages = if config and config.Stages then Shared.ShallowCopy(config.Stages) else {}
	local stageIndex = {}

	for _, stage in ipairs(stages) do
		stageIndex[stage.Name] = true
	end

	local pipeline = {} :: Types.TPipeline<TContext>

	function pipeline:AddStage(name: string, callback: (context: TContext) -> ())
		assert(type(name) == "string" and name ~= "", "name must be a non-empty string")
		Shared.AssertFunction(callback, "callback")
		assert(not stageIndex[name], "pipeline stage names must be unique")

		stageIndex[name] = true
		table.insert(stages, {
			Name = name,
			Callback = callback,
		})
	end

	function pipeline:Run(context: TContext)
		for _, stage in ipairs(stages) do
			stage.Callback(context)
		end
	end

	function pipeline:Clear()
		table.clear(stages)
		table.clear(stageIndex)
	end

	function pipeline:GetStageNames(): { string }
		local names = table.create(#stages)
		for index, stage in ipairs(stages) do
			names[index] = stage.Name
		end
		return names
	end

	return pipeline
end

function Ordering.Sequence(steps: { Types.TSequenceStep }): Types.TSequence
	local copiedSteps = Shared.ShallowCopy(steps)
	local thread: thread? = nil
	local handle, state = Shared.CreateExecutionHandle({
		OnCancel = function()
			if thread ~= nil then
				task.cancel(thread)
			end
		end,
	})

	local sequence = handle :: Types.TSequence

	function sequence:Start()
		if state.Cancelled or state.Running or state.Completed then
			return
		end

		thread = task.spawn(function()
			for _, step in ipairs(copiedSteps) do
				local delaySeconds = step.DelaySeconds or 0
				Shared.AssertNonNegativeNumber(delaySeconds, "step.DelaySeconds")
				Shared.AssertFunction(step.Callback, "step.Callback")

				if delaySeconds > 0 then
					task.wait(delaySeconds)
				end

				if state.Cancelled then
					return
				end

				state.Pending = false
				state.Running = true
				step.Callback()
				state.Running = false
			end

			if not state.Cancelled then
				state.Completed = true
			end
		end)
	end

	return sequence
end

return Ordering
