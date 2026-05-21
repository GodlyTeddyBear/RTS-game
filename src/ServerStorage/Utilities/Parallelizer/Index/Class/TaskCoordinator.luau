--!native
--!optimize 2
local Types = require(script.Parent.Parent.types)

local Deserializer = require(script.Parent.Parent.Utils.Deserializer)
local Serializer = require(script.Parent.Parent.Utils.Serializer)

local TaskCoordinator = {}

local function _RemoveArrayValue(list: { any }, value: any)
	local index = table.find(list, value)
	if index ~= nil then
		table.remove(list, index)
	end
end

function TaskCoordinator.DefineTask(
	self: Types.TaskCoordinator, 
	taskName: string, 
	taskMetaData: Types.TaskMetaData
): Types.Task
	assert(not taskName:match('%-parallelizer%-internal%-def$'), 'Task name cannot end with "-parallelizer-internal"')
	assert(not taskName:match('%-parallelizer%-internal%-mem$'), 'Task name cannot end with "-parallelizer-internal-mem"')

	--> Serialize Packet Definition
	local packetDef = taskMetaData.packet

	local defSize = 8
	local packetBytesSize = #packetDef * 4
	local defBuf = buffer.create(defSize)
	local packetBytesBuf = buffer.create(packetBytesSize)

	local defCursor = 0
	local packetBytesCursor = 0

	local bytesNeeded = 0

	for _, dataType in packetDef do
		local dataTypeLiteral = dataType[1]
		local bytes = tonumber(dataType[2]) :: number

		bytesNeeded += bytes

		defBuf, defCursor, defSize = Serializer.SerializeToBuffer(dataTypeLiteral, 'str', defCursor, defBuf, defSize, #dataTypeLiteral+4)
		packetBytesBuf, packetBytesCursor, packetBytesSize = Serializer.SerializeToBuffer(bytes, 'u32', packetBytesCursor, packetBytesBuf, packetBytesSize, 4)
	end

	task.defer(function()
		for _, actor: Actor in self.actors do
			actor:SendMessage(`{taskName}-parallelizer-internal-def`, defBuf, packetBytesBuf, #packetDef, bytesNeeded)
			actor:SendMessage(`{taskName}-parallelizer-internal-mem`, taskMetaData.localMemory)
		end
	end)

	return { taskName = taskName, packetDef = packetDef, packetBytesNeeded = bytesNeeded }
end

function TaskCoordinator.SetTaskLocalMemory(
	self: Types.TaskCoordinator,
	taskObject: Types.Task,
	newLocalMemory: SharedTable
): ()
	for _, actor: Actor in self.actors do
		actor:SendMessage(`{taskObject.taskName}-parallelizer-internal-mem`, newLocalMemory)
	end
end

function TaskCoordinator.DispatchTaskEqually(
	self: Types.TaskCoordinator,
	taskObject: Types.Task,
	threadCount: number,
	callback: (any) -> nil,
	returnMergedBuffer: boolean?,
	...: Types.SharedTableValues
): ()
	self:DispatchTask(taskObject, threadCount, threadCount // self.actorCount, callback, returnMergedBuffer, ...)
end

function TaskCoordinator.DispatchTask(
	self: Types.TaskCoordinator,
	taskObject: Types.Task,
	threadCount: number,
	batchSize: number,
	callback: (any) -> nil,
	returnMergedBuffer: boolean?,
	...: Types.SharedTableValues
)
	batchSize = math.max(batchSize, 1)
	assert(
		threadCount % batchSize == 0,
		`Parallelizer task "{taskObject.taskName}" requires threadCount ({threadCount}) to be divisible by batchSize ({batchSize})`
	)

	local expectedBatchCount = threadCount // batchSize
	local expectedBatchBytes = taskObject.packetBytesNeeded * batchSize
	local data: buffer | {any} = if returnMergedBuffer then buffer.create(taskObject.packetBytesNeeded * threadCount) else {}
	local bindable = Instance.new("BindableEvent")
	local connection: RBXScriptConnection?
	local count = 0
	local settled = false
	local cancelled = false

	table.insert(self.resultBindables, bindable)

	local function cleanup(destroyBindable: boolean)
		if settled then
			return
		end

		settled = true

		if connection ~= nil then
			connection:Disconnect()
			_RemoveArrayValue(self.connections, connection)
			connection = nil
		end

		if destroyBindable then
			_RemoveArrayValue(self.resultBindables, bindable)
			bindable:Destroy()
		end
	end

	-- TODO: try to find a faster way to do this
	connection = bindable.Event:Connect(function(index: number, batchBufferResult: buffer)
		if cancelled then
			return
		end

		count += 1
		assert(
			count <= expectedBatchCount,
			`Parallelizer task "{taskObject.taskName}" received more batch results than expected ({expectedBatchCount})`
		)
		assert(
			buffer.len(batchBufferResult) == expectedBatchBytes,
			`Parallelizer task "{taskObject.taskName}" batch starting at {index} returned {buffer.len(batchBufferResult)} bytes; expected {expectedBatchBytes}`
		)

		if returnMergedBuffer then
			buffer.copy(data :: buffer, (index - 1) * taskObject.packetBytesNeeded, batchBufferResult)
		else
			local cursor = 0
			local batchData = table.create(batchSize * #taskObject.packetDef)

			-- for all batches/chunks in the batch
			for batch = 1, batchSize do
				-- for all data elements in bufferBatch within the batches/chunks
				for i, dataType in taskObject.packetDef do
					cursor = Deserializer.deserializeToTable(batchBufferResult, cursor, dataType[1], batchData)
				end
			end
			assert(
				cursor == expectedBatchBytes,
				`Parallelizer task "{taskObject.taskName}" batch starting at {index} decoded {cursor} bytes; expected {expectedBatchBytes}`
			)

			table.move(batchData, 1, #batchData, (index - 1) * #taskObject.packetDef + 1, data)
		end

		if count == expectedBatchCount then
			cleanup(true)
			callback(data)
		end
	end)

	table.insert(self.connections, connection)

	task.defer(function(...)
		local actorIndex = 1

		for taskId = 1, threadCount, batchSize do
			if cancelled then
				break
			end

			self.actors[actorIndex]:SendMessage(taskObject.taskName, taskId, threadCount, batchSize, bindable, ...)

			actorIndex = (actorIndex % self.actorCount) + 1
		end
	end, ...)

	return table.freeze({
		Cancel = function()
			if cancelled then
				return
			end

			cancelled = true
			cleanup(false)
		end,
	})
end

function TaskCoordinator.Destroy(self: Types.TaskCoordinator)
	for _, connection in self.connections do
		connection:Disconnect()
	end

	for _, bindable in self.resultBindables do
		bindable:Destroy()
	end

	for _, actor in self.actors do
		actor:Destroy()
	end

	table.clear(self.actors)
	table.clear(self.connections)
	table.clear(self.resultBindables)
end

return TaskCoordinator :: Types.TaskCoordinator
