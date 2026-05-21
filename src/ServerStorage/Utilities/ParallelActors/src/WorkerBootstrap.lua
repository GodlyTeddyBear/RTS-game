--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ParallelLogistics = require(ServerStorage.Utilities.ParallelLogistics)
local PayloadCodec = require(ServerStorage.Utilities.ParallelRunner.src.PayloadCodec)
local Sera = require(ReplicatedStorage.Utilities.Sera)

local Protocol = require(script.Parent.Protocol)

type TCompiledJob = ParallelLogistics.TCompiledJob

type TActorJobState = {
	CompiledJob: TCompiledJob,
	PayloadCodec: any?,
	ManagerPayloadCodec: any?,
	WorkerModule: ModuleScript,
	ManagerModule: ModuleScript?,
	WorkerExport: { Execute: (request: { [string]: any }) -> any },
	ManagerExport: { BuildDispatch: (request: { [string]: any }) -> any }?,
	SharedMemory: SharedTable?,
	WorkerPayload: { [string]: any }?,
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

local function _BuildCompiledJob(
	jobName: string,
	version: number,
	argsSchemaDescriptor: { [string]: string },
	resultSchemaDescriptor: { [string]: string }
): TCompiledJob
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

local function _BuildWorkerPayloadBuffer(jobState: TActorJobState, jobName: string, workerPayload: any): buffer?
	if workerPayload == nil then
		return nil
	end

	local payloadCodec = jobState.PayloadCodec
	assert(payloadCodec ~= nil, _BuildWrappedWorkerError("ParallelRunnerManagerEncodeError", jobName, "worker payload schema is missing"))

	local encodedPayload, encodeError = payloadCodec:Encode(workerPayload)
	assert(encodedPayload ~= nil, _BuildWrappedWorkerError("ParallelRunnerManagerEncodeError", jobName, encodeError :: string))
	return encodedPayload
end

local function _DecodeManagerPayload(jobState: TActorJobState, jobName: string, managerPayloadBuffer: buffer?): { [string]: any }?
	if managerPayloadBuffer == nil then
		return nil
	end

	local payloadCodec = jobState.ManagerPayloadCodec
	assert(
		payloadCodec ~= nil,
		_BuildWrappedWorkerError(
			"ParallelRunnerManagerPayloadDecodeError",
			jobName,
			"manager payload buffer was provided without a manager payload schema"
		)
	)

	local decodedPayload, _, decodeError = payloadCodec:Decode(managerPayloadBuffer)
	assert(
		decodedPayload ~= nil,
		_BuildWrappedWorkerError("ParallelRunnerManagerPayloadDecodeError", jobName, decodeError :: string)
	)

	return decodedPayload
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
		payloadSchemaDescriptor: { [string]: any }?,
		managerPayloadSchemaDescriptor: { [string]: any }?,
		workerModule: ModuleScript,
		managerModule: ModuleScript?
	)
		local workerExport = require(workerModule)
		assert(type(workerExport) == "table", `ParallelActors worker "{jobName}" module must return a table`)
		assert(type((workerExport :: any).Execute) == "function", `ParallelActors worker "{jobName}" module must export Execute(request)`)

		local managerExport = nil
		if managerModule ~= nil then
			local managerValue = require(managerModule)
			assert(type(managerValue) == "table", `ParallelActors manager "{jobName}" module must return a table`)
			assert(
				type((managerValue :: any).BuildDispatch) == "function",
				`ParallelActors manager "{jobName}" module must export BuildDispatch(request)`
			)
			managerExport = managerValue
		end

		jobsByName[jobName] = {
			CompiledJob = _BuildCompiledJob(jobName, version, argsSchemaDescriptor, resultSchemaDescriptor),
			PayloadCodec = if payloadSchemaDescriptor ~= nil
				then PayloadCodec.CompileDescriptor(jobName, version, payloadSchemaDescriptor :: any)
				else nil,
			ManagerPayloadCodec = if managerPayloadSchemaDescriptor ~= nil
				then PayloadCodec.CompileDescriptor(jobName, version, managerPayloadSchemaDescriptor :: any)
				else nil,
			WorkerModule = workerModule,
			ManagerModule = managerModule,
			WorkerExport = workerExport,
			ManagerExport = managerExport,
			SharedMemory = nil,
			WorkerPayload = nil,
		}
	end)

	actor:BindToMessage(Protocol.SetSharedMemory, function(jobName: string, sharedMemory: SharedTable?)
		local jobState = jobsByName[jobName]
		if jobState == nil then
			return
		end

		jobState.SharedMemory = sharedMemory
	end)

	actor:BindToMessage(Protocol.SetWorkerPayload, function(jobName: string, workerPayloadBuffer: buffer?)
		local jobState = jobsByName[jobName]
		if jobState == nil then
			return
		end

		if workerPayloadBuffer == nil then
			jobState.WorkerPayload = nil
			return
		end

		local payloadCodec = jobState.PayloadCodec
		assert(payloadCodec ~= nil, `ParallelActors worker "{jobName}" received worker payload without a payload schema`)

		local decodedPayload, _, decodeError = payloadCodec:Decode(workerPayloadBuffer)
		assert(decodedPayload ~= nil, decodeError)
		jobState.WorkerPayload = decodedPayload
	end)

	actor:BindToMessageParallel(Protocol.RunManager, function(
		runId: number,
		jobName: string,
		argsBuffer: buffer,
		bindable: BindableEvent,
		sharedMemory: SharedTable?,
		managerPayloadBuffer: buffer?
	)
		task.desynchronize()

		if busy then
			bindable:Fire(actorId, runId, jobName, nil, nil, nil, "ParallelActors actor is already busy")
			return
		end

		busy = true

		local function finish(
			logicalWorkCount: number?,
			batchSize: number?,
			workerPayloadBuffer: buffer?,
			errorMessage: string?
		)
			busy = false
			bindable:Fire(actorId, runId, jobName, logicalWorkCount, batchSize, workerPayloadBuffer, errorMessage)
		end

		local jobState = jobsByName[jobName]
		if jobState == nil then
			finish(nil, nil, nil, `ParallelActors manager missing registered job "{jobName}"`)
			return
		end

		local managerExport = jobState.ManagerExport
		if managerExport == nil then
			finish(
				nil,
				nil,
				nil,
				_BuildWrappedWorkerError("ParallelRunnerManagerModuleError", jobName, "manager module is not registered")
			)
			return
		end

		local decodedArgs, _, decodeError = jobState.CompiledJob:DecodeArgs(argsBuffer)
		if decodedArgs == nil then
			finish(nil, nil, nil, _BuildWrappedWorkerError("ParallelRunnerWorkerDecodeError", jobName, decodeError :: string))
			return
		end

		local ok, dispatchOrError = pcall(function()
			return managerExport.BuildDispatch({
				RunId = runId,
				JobName = jobName,
				Args = decodedArgs,
				SharedMemory = if sharedMemory ~= nil then sharedMemory else jobState.SharedMemory,
				ManagerPayload = _DecodeManagerPayload(jobState, jobName, managerPayloadBuffer),
			})
		end)
		if not ok then
			finish(nil, nil, nil, _BuildWrappedWorkerError("ParallelRunnerManagerExecuteError", jobName, tostring(dispatchOrError)))
			return
		end

		local dispatch = dispatchOrError
		if type(dispatch) ~= "table" then
			finish(
				nil,
				nil,
				nil,
				_BuildWrappedWorkerError("ParallelRunnerManagerModuleError", jobName, "manager BuildDispatch(request) must return a table")
			)
			return
		end

		local logicalWorkCount = dispatch.LogicalWorkCount
		local batchSize = dispatch.BatchSize
		if type(logicalWorkCount) ~= "number" or logicalWorkCount < 0 or logicalWorkCount % 1 ~= 0 then
			finish(
				nil,
				nil,
				nil,
				_BuildWrappedWorkerError(
					"ParallelRunnerManagerModuleError",
					jobName,
					"manager BuildDispatch(request) must return a non-negative integer LogicalWorkCount"
				)
			)
			return
		end
		if batchSize ~= nil and (type(batchSize) ~= "number" or batchSize <= 0 or batchSize % 1 ~= 0) then
			finish(
				nil,
				nil,
				nil,
				_BuildWrappedWorkerError(
					"ParallelRunnerManagerModuleError",
					jobName,
					"manager BuildDispatch(request) BatchSize must be a positive integer when provided"
				)
			)
			return
		end

		local okPayload, workerPayloadBufferOrError = pcall(function()
			return _BuildWorkerPayloadBuffer(jobState, jobName, dispatch.WorkerPayload)
		end)
		if not okPayload then
			finish(nil, nil, nil, tostring(workerPayloadBufferOrError))
			return
		end

		finish(logicalWorkCount, batchSize, workerPayloadBufferOrError, nil)
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
		sharedMemory: SharedTable?,
		workerPayloadBuffer: buffer?
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

		local resolvedWorkerPayload = jobState.WorkerPayload
		if workerPayloadBuffer ~= nil then
			local payloadCodec = jobState.PayloadCodec
			if payloadCodec == nil then
				finish(
					nil,
					_BuildWrappedWorkerError(
						"ParallelRunnerWorkerPayloadDecodeError",
						jobName,
						"worker payload buffer was provided without a payload schema"
					)
				)
				return
			end

			local decodedPayload, _, workerPayloadDecodeError = payloadCodec:Decode(workerPayloadBuffer)
			if decodedPayload == nil then
				finish(
					nil,
					_BuildWrappedWorkerError(
						"ParallelRunnerWorkerPayloadDecodeError",
						jobName,
						workerPayloadDecodeError :: string
					)
				)
				return
			end

			resolvedWorkerPayload = decodedPayload
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
			WorkerPayload = resolvedWorkerPayload,
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
