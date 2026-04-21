--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LogCommandTypes = require(ReplicatedStorage.Contexts.Log.Types.LogCommandTypes)

type RegisteredLogCommand = LogCommandTypes.RegisteredLogCommand
type CommandManifestEntry = LogCommandTypes.CommandManifestEntry

local CommandRegistry = {}

local _commandsByName: { [string]: RegisteredLogCommand } = {}

local function _assertServer()
	assert(RunService:IsServer(), "CommandRegistry can only be used on the server")
end

local function _validateCommand(command: RegisteredLogCommand)
	assert(type(command) == "table", "CommandRegistry.Register requires a command table")
	assert(type(command.name) == "string" and command.name ~= "", "Command name is required")
	assert(type(command.context) == "string" and command.context ~= "", "Command context is required")
	assert(type(command.handler) == "function", "Command handler must be a function")
end

local function _copyParams(params: { LogCommandTypes.CommandParam }?): { LogCommandTypes.CommandParam }?
	if params == nil then
		return nil
	end

	local copied = table.create(#params)
	for _, param in ipairs(params) do
		table.insert(copied, {
			name = param.name,
			label = param.label,
			default = param.default,
		})
	end
	return copied
end

function CommandRegistry.Register(command: RegisteredLogCommand)
	_assertServer()
	_validateCommand(command)

	if _commandsByName[command.name] ~= nil then
		warn(string.format("[CommandRegistry] Duplicate command '%s' registered. Overwriting.", command.name))
	end

	_commandsByName[command.name] = command
end

function CommandRegistry.GetAll(): { CommandManifestEntry }
	_assertServer()

	local manifest: { CommandManifestEntry } = {}
	for _, command in pairs(_commandsByName) do
		table.insert(manifest, {
			name = command.name,
			context = command.context,
			description = command.description,
			params = _copyParams(command.params),
		})
	end

	table.sort(manifest, function(a, b)
		return a.name < b.name
	end)

	return manifest
end

function CommandRegistry.GetByName(name: string): RegisteredLogCommand?
	_assertServer()
	return _commandsByName[name]
end

return table.freeze(CommandRegistry)
