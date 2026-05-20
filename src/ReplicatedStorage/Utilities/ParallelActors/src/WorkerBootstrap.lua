--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelLogistics = require(ReplicatedStorage.Utilities.ParallelLogistics)
local Sera = require(ReplicatedStorage.Utilities.Sera)

local Protocol = require(script.Parent.Protocol)

type TCompiledJob = ParallelLogistics.TCompiledJob

type TActorJobState = {
	CompiledJob: TCompiledJob,
	WorkerModule: ModuleScript,
	WorkerExport: { Execute: (request: { [string]: any }) -> any },
	SharedMemory: SharedTable?,
}

local TYPE_MAP = table.freeze({
	Boolean = Sera.Boolean,
	Uint8 = Sera.Uint8,
	Uint16 = Sera.Uint16,
	Uint32 = Sera.Uint32,
	Int8 = Sera.Int8,
	Int16 = Sera.Int16,
	Int32 = Sera.Int32,
	Float32 = Sera.Float32,
	Float64 = Sera.Float64,
	CFrame = Sera.CFrame,
	LossyCFrame = Sera.LossyCFrame,
	Vector3 = Sera.Vector3,
	Color3 = Sera.Color3,
	ColorV3 = Sera.ColorV3,
	String8 = Sera.String8,
	String16 = Sera.String16,
	String32 = Sera.String32,
	Buffer8 = Sera.Buffer8,
	Buffer16 = Sera.Buffer16,
	Buffer32 = Sera.Buffer32,
	Angle8 = Sera.Angle8,
})

local function _BuildWrappedWorkerError(kind: string, jobName: string, message: string): string
	return `[{kind}] {jobName}: {message}`
end

local function _BuildSchema(descriptor: { [string]: string })
	local schemaFields = {}

	for fieldName, typeName in descriptor do
		local seraType = TYPE_MAP[typeName]
		assert(seraType ~= nil, `ParallelActors worker schema field "{fieldName}" uses unsupported Sera type "{typeName}"`)
		schemaFields[fieldName] = seraType
	end

	return Sera.Schema(schemaFields)
end

local function _BuildCompiledJob(jobName: string, version: number, argsSchemaDescriptor: { [string]: string }, resultSchemaDescriptor: { [string]: string }): TCompiledJob
	return ParallelLogistics.DefineJob({
		Name = jobName,
		Version = version,
		ArgsSchema = _BuildSchema(argsSchemaDescriptor),
		ResultSchema = _BuildSchema(resultSchemaDescriptor),
	})
end

local function _WrapRowsResult(rowsResult: any, onRows: ({ { [string]: any } }) -> any): any
	if type(rowsResult) == "table" and type(rowsResult.andThen) == "function" then
		return (rowsResult :: any):andThen(function(rows)
			return onRows(rows)
		end)
	end

	return onRows(rowsResult)
end

local WorkerBootstrap = {}

function WorkerBootstrap.Start(workerScript: Script)
	local actor = workerScript:GetActor()
	assert(actor ~= nil, "ParallelActors worker script must run inside an Actor")
	local actorId = actor:GetAttribute("ParallelActorsActorId")
	assert(type(actorId) == "number", "ParallelActors worker actor is missing ParallelActorsActorId")

	local jobsByName = {} :: { [string]: TActorJobState }
	local busy = false

	actor:BindToMessage(Protocol.RegisterJob, function(
		jobName: string,
		version: number,
		argsSchemaDescriptor: { [string]: string },
		resultSchemaDescriptor: { [string]: string },
		workerModule: ModuleScript
	)
		local workerExport = require(workerModule)
		assert(type(workerExport) == "table", `ParallelActors worker "{jobName}" module must return a table`)
		assert(type((workerExport :: any).Execute) == "function", `ParallelActors worker "{jobName}" module must export Execute(request)`)

		jobsByName[jobName] = {
			CompiledJob = _BuildCompiledJob(jobName, version, argsSchemaDescriptor, resultSchemaDescriptor),
			WorkerModule = workerModule,
			WorkerExport = workerExport,
			SharedMemory = nil,
		}
	end)

	actor:BindToMessage(Protocol.SetSharedMemory, function(jobName: string, sharedMemory: SharedTable?)
		local jobState = jobsByName[jobName]
		if jobState == nil then
			return
		end

		jobState.SharedMemory = sharedMemory
	end)

	actor:BindToMessageParallel(Protocol.RunShard, function(
		runId: number,
		jobName: string,
		shardIndex: number,
		startTaskId: number,
		batchSize: number,
		logicalWorkCount: number,
		argsBuffer: buffer,
		bindable: BindableEvent,
		sharedMemory: SharedTable?
	)
		task.desynchronize()

		if busy then
			bindable:Fire(actorId, runId, jobName, shardIndex, startTaskId, batchSize, nil, "ParallelActors actor is already busy")
			return
		end

		busy = true

		local function finish(resultBuffer: buffer?, errorMessage: string?)
			busy = false
			bindable:Fire(actorId, runId, jobName, shardIndex, startTaskId, batchSize, resultBuffer, errorMessage)
		end

		local jobState = jobsByName[jobName]
		if jobState == nil then
			finish(nil, `ParallelActors worker missing registered job "{jobName}"`)
			return
		end

		local decodedArgs, _, decodeError = jobState.CompiledJob:DecodeArgs(argsBuffer)
		if decodedArgs == nil then
			finish(nil, _BuildWrappedWorkerError("ParallelRunnerWorkerDecodeError", jobName, decodeError :: string))
			return
		end

		local ok, rowsResult = pcall(jobState.WorkerExport.Execute, {
			JobName = jobName,
			RunId = runId,
			ShardIndex = shardIndex,
			StartTaskId = startTaskId,
			BatchSize = batchSize,
			LogicalWorkCount = logicalWorkCount,
			Args = decodedArgs,
			SharedMemory = if sharedMemory ~= nil then sharedMemory else jobState.SharedMemory,
		})

		if not ok then
			finish(nil, _BuildWrappedWorkerError("ParallelRunnerWorkerExecuteError", jobName, tostring(rowsResult)))
			return
		end

		local wrappedResult = _WrapRowsResult(rowsResult, function(rows)
			if type(rows) ~= "table" then
				error(
					_BuildWrappedWorkerError(
						"ParallelRunnerWorkerModuleError",
						jobName,
						"worker Execute(request) must return rows or Promise<rows>"
					),
					0
				)
			end

			local resultBuffer, encodeError = jobState.CompiledJob:EncodeResultBatch(rows)
			if resultBuffer == nil then
				error(_BuildWrappedWorkerError("ParallelRunnerWorkerEncodeError", jobName, encodeError :: string), 0)
			end

			return resultBuffer
		end)

		if type(wrappedResult) == "table" and type(wrappedResult.andThen) == "function" then
			(wrappedResult :: any):andThen(function(resultBuffer: buffer)
				finish(resultBuffer, nil)
			end):catch(function(promiseError)
				finish(nil, tostring(promiseError))
			end)
			return
		end

		finish(wrappedResult, nil)
	end)

	workerScript:SetAttribute("ParallelActorsReady", true)
end

return table.freeze(WorkerBootstrap)
