--!strict

local Validation = {}

function Validation.AssertRunnerConfig(config: { [string]: any })
	assert(type(config) == "table", "ParallelRunner.new requires a config table")
	assert(
		type(config.ActorCount) == "number" and config.ActorCount > 0 and config.ActorCount % 1 == 0,
		"ParallelRunner.new requires ActorCount to be a positive integer"
	)
	if config.Name ~= nil then
		assert(type(config.Name) == "string" and config.Name ~= "", "ParallelRunner Name must be a non-empty string")
	end
	if config.DefaultBatchSize ~= nil then
		assert(
			type(config.DefaultBatchSize) == "number" and config.DefaultBatchSize > 0 and config.DefaultBatchSize % 1 == 0,
			"ParallelRunner DefaultBatchSize must be a positive integer when provided"
		)
	end
end

function Validation.AssertDefineJobConfig(config: { [string]: any })
	assert(type(config) == "table", "ParallelRunner.DefineJob requires a config table")
	assert(type(config.Name) == "string" and config.Name ~= "", "ParallelRunner.DefineJob requires Name")
	assert(
		type(config.Version) == "number" and config.Version > 0 and config.Version % 1 == 0,
		"ParallelRunner.DefineJob requires Version to be a positive integer"
	)
	assert(type(config.Args) == "table", `ParallelRunner.DefineJob("{tostring(config.Name)}") requires Args`)
	assert(type(config.Results) == "table", `ParallelRunner.DefineJob("{tostring(config.Name)}") requires Results`)
	if config.SharedSchema ~= nil then
		assert(
			type(config.SharedSchema) == "table",
			`ParallelRunner.DefineJob("{config.Name}") SharedSchema must be a table when provided`
		)
	end
end

function Validation.AssertJobRegistration(config: { [string]: any })
	assert(type(config) == "table", "ParallelRunner:RegisterJob requires a config table")
	assert(type(config.Job) == "table", "ParallelRunner:RegisterJob requires Job")
	assert(type(config.Job.GetName) == "function", "ParallelRunner:RegisterJob Job must be a compiled ParallelLogistics job")
	assert(
		type(config.Job.EncodeArgs) == "function" and type(config.Job.DecodeResultBatch) == "function",
		"ParallelRunner:RegisterJob Job must expose ParallelLogistics encode/decode methods"
	)
	assert(
		typeof(config.WorkerModule) == "Instance" and config.WorkerModule:IsA("ModuleScript"),
		"ParallelRunner:RegisterJob requires WorkerModule to be a ModuleScript"
	)
	if config.DefaultLogicalWorkCount ~= nil then
		assert(
			type(config.DefaultLogicalWorkCount) == "number"
				and config.DefaultLogicalWorkCount >= 0
				and config.DefaultLogicalWorkCount % 1 == 0,
			"ParallelRunner RegisterJob DefaultLogicalWorkCount must be a non-negative integer when provided"
		)
	end
	if config.DefaultBatchSize ~= nil then
		assert(
			type(config.DefaultBatchSize) == "number" and config.DefaultBatchSize > 0 and config.DefaultBatchSize % 1 == 0,
			"ParallelRunner RegisterJob DefaultBatchSize must be a positive integer when provided"
		)
	end
end

function Validation.AssertRunRequest(request: { [string]: any })
	assert(type(request) == "table", "ParallelRunner:Run requires a request table")
	assert(type(request.JobName) == "string" and request.JobName ~= "", "ParallelRunner:Run requires JobName")
	assert(type(request.Args) == "table", `ParallelRunner:Run("{tostring(request.JobName)}") requires Args`)
	if request.LogicalWorkCount ~= nil then
		assert(
			type(request.LogicalWorkCount) == "number"
				and request.LogicalWorkCount >= 0
				and request.LogicalWorkCount % 1 == 0,
			`ParallelRunner:Run("{request.JobName}") LogicalWorkCount must be a non-negative integer when provided`
		)
	end
	if request.BatchSize ~= nil then
		assert(
			type(request.BatchSize) == "number" and request.BatchSize > 0 and request.BatchSize % 1 == 0,
			`ParallelRunner:Run("{request.JobName}") BatchSize must be a positive integer when provided`
		)
	end
	if request.SharedMemory ~= nil then
		assert(
			typeof(request.SharedMemory) == "SharedTable",
			`ParallelRunner:Run("{request.JobName}") SharedMemory must be a SharedTable when provided`
		)
	end
end

function Validation.AssertSetSharedMemory(jobName: any, sharedMemory: any)
	assert(type(jobName) == "string" and jobName ~= "", "ParallelRunner:SetSharedMemory requires a non-empty jobName")
	if sharedMemory ~= nil then
		assert(
			typeof(sharedMemory) == "SharedTable",
			`ParallelRunner:SetSharedMemory("{tostring(jobName)}") SharedMemory must be a SharedTable when provided`
		)
	end
end

function Validation.AssertManagedJobConfig(runner: { [string]: any }, config: { [string]: any })
	assert(type(config) == "table", "ParallelRunner:CreateManagedJob requires a config table")
	assert(type(config.JobName) == "string" and config.JobName ~= "", "Managed job requires JobName")
	assert(
		type(config.BuildSharedMemory) == "function",
		`ParallelRunner:CreateManagedJob("{tostring(config.JobName)}") requires BuildSharedMemory`
	)
	assert(
		type(config.BuildRunRequest) == "function",
		`ParallelRunner:CreateManagedJob("{tostring(config.JobName)}") requires BuildRunRequest`
	)
	if config.GetSessionToken ~= nil then
		assert(
			type(config.GetSessionToken) == "function",
			`ParallelRunner:CreateManagedJob("{config.JobName}") GetSessionToken must be a function when provided`
		)
	end
	if config.MaxInFlightSeconds ~= nil then
		assert(
			type(config.MaxInFlightSeconds) == "number" and config.MaxInFlightSeconds > 0,
			`ParallelRunner:CreateManagedJob("{config.JobName}") MaxInFlightSeconds must be a positive number when provided`
		)
	end
	assert(
		runner._registeredJobs[config.JobName] ~= nil,
		`ParallelRunner:CreateManagedJob("{config.JobName}") requires a registered job`
	)
	local registeredJob = runner._registeredJobs[config.JobName]
	assert(
		registeredJob.Job:GetSchemas().Shared ~= nil,
		`ParallelRunner:CreateManagedJob("{config.JobName}") requires the registered job to define SharedSchema`
	)
end

function Validation.AssertManagedSharedPacket(jobName: string, packet: any)
	assert(
		type(packet) == "table",
		`ParallelRunner managed job "{jobName}" BuildSharedMemory must return a SharedPlus packet table`
	)
end

function Validation.AssertManagedRunRequest(jobName: string, request: { [string]: any })
	assert(type(request) == "table", `ParallelRunner managed job "{jobName}" BuildRunRequest must return a table`)
	assert(type(request.Args) == "table", `ParallelRunner managed job "{jobName}" BuildRunRequest requires Args`)
	assert(
		type(request.LogicalWorkCount) == "number"
			and request.LogicalWorkCount >= 0
			and request.LogicalWorkCount % 1 == 0,
		`ParallelRunner managed job "{jobName}" BuildRunRequest LogicalWorkCount must be a non-negative integer`
	)
	if request.BatchSize ~= nil then
		assert(
			type(request.BatchSize) == "number" and request.BatchSize > 0 and request.BatchSize % 1 == 0,
			`ParallelRunner managed job "{jobName}" BuildRunRequest BatchSize must be a positive integer when provided`
		)
	end
end

return table.freeze(Validation)
