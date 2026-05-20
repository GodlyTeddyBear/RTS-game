--!strict

local Validation = {}

function Validation.AssertWorkplaceConfig(config: { [string]: any })
	assert(type(config) == "table", "ParallelActors.new requires a config table")
	assert(
		type(config.ActorCount) == "number" and config.ActorCount > 0 and config.ActorCount % 1 == 0,
		"ParallelActors.new requires ActorCount to be a positive integer"
	)
	if config.Name ~= nil then
		assert(type(config.Name) == "string" and config.Name ~= "", "ParallelActors workplace Name must be a non-empty string")
	end
	if config.DefaultBatchSize ~= nil then
		assert(
			type(config.DefaultBatchSize) == "number" and config.DefaultBatchSize > 0 and config.DefaultBatchSize % 1 == 0,
			"ParallelActors DefaultBatchSize must be a positive integer when provided"
		)
	end
end

function Validation.AssertJobRegistration(jobName: any, executor: any)
	assert(type(jobName) == "string" and jobName ~= "", "ParallelActors:RegisterJob requires a non-empty jobName")
	assert(type(executor) == "function", `ParallelActors:RegisterJob("{tostring(jobName)}") requires an executor function`)
end

function Validation.AssertCompiledJobRegistration(job: any, workerModule: any)
	assert(type(job) == "table", "ParallelActors:RegisterCompiledJob requires a compiled job")
	assert(type(job.GetName) == "function", "ParallelActors:RegisterCompiledJob requires a compiled ParallelLogistics job")
	assert(
		typeof(workerModule) == "Instance" and workerModule:IsA("ModuleScript"),
		`ParallelActors:RegisterCompiledJob("{tostring(job:GetName())}") requires WorkerModule to be a ModuleScript`
	)
end

function Validation.AssertSharedMemory(jobName: any, sharedMemory: any)
	assert(type(jobName) == "string" and jobName ~= "", "ParallelActors:SetSharedMemory requires a non-empty jobName")
	if sharedMemory ~= nil then
		assert(
			typeof(sharedMemory) == "SharedTable",
			`ParallelActors:SetSharedMemory("{tostring(jobName)}") SharedMemory must be a SharedTable when provided`
		)
	end
end

function Validation.AssertWorkerPayload(jobName: any, workerPayloadBuffer: any)
	assert(type(jobName) == "string" and jobName ~= "", "ParallelActors:SetWorkerPayload requires a non-empty jobName")
	if workerPayloadBuffer ~= nil then
		assert(
			typeof(workerPayloadBuffer) == "buffer",
			`ParallelActors:SetWorkerPayload("{tostring(jobName)}") WorkerPayloadBuffer must be a buffer when provided`
		)
	end
end

function Validation.AssertRunRequest(request: { [string]: any }, jobExists: boolean)
	assert(type(request) == "table", "ParallelActors:Run requires a request table")
	assert(type(request.JobName) == "string" and request.JobName ~= "", "ParallelActors:Run requires JobName")
	assert(jobExists, `ParallelActors:Run("{tostring(request.JobName)}") requires a registered job`)
	assert(
		type(request.LogicalWorkCount) == "number" and request.LogicalWorkCount >= 0 and request.LogicalWorkCount % 1 == 0,
		`ParallelActors:Run("{request.JobName}") requires LogicalWorkCount to be a non-negative integer`
	)
	if request.BatchSize ~= nil then
		assert(
			type(request.BatchSize) == "number" and request.BatchSize > 0 and request.BatchSize % 1 == 0,
			`ParallelActors:Run("{request.JobName}") BatchSize must be a positive integer when provided`
		)
	end
	assert(
		typeof(request.ArgsBuffer) == "buffer",
		`ParallelActors:Run("{request.JobName}") requires ArgsBuffer to be a buffer`
	)
	if request.SharedMemory ~= nil then
		assert(
			typeof(request.SharedMemory) == "SharedTable",
			`ParallelActors:Run("{request.JobName}") SharedMemory must be a SharedTable when provided`
		)
	end
	if request.WorkerPayloadBuffer ~= nil then
		assert(
			typeof(request.WorkerPayloadBuffer) == "buffer",
			`ParallelActors:Run("{request.JobName}") WorkerPayloadBuffer must be a buffer when provided`
		)
	end
end

return table.freeze(Validation)
