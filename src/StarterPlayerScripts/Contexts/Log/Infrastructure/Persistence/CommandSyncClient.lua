--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Knit = require(ReplicatedStorage.Packages.Knit)
local LogCommandTypes = require(ReplicatedStorage.Contexts.Log.Types.LogCommandTypes)

type CommandManifestEntry = LogCommandTypes.CommandManifestEntry

local CommandSyncClient = {}

local commandsAtom = Charm.atom({} :: { CommandManifestEntry })

local function _isPromiseLike(value: any): boolean
	return type(value) == "table" and type(value.andThen) == "function" and type(value.catch) == "function"
end

local function _setCommandsIfValid(manifest: any): boolean
	if type(manifest) ~= "table" then
		return false
	end

	commandsAtom(manifest :: { CommandManifestEntry })
	return true
end

function CommandSyncClient.Initialize()
	local logContext = Knit.GetService("LogContext")
	local ok, response = pcall(function()
		return logContext:GetCommands()
	end)

	if not ok then
		commandsAtom({} :: { CommandManifestEntry })
		return
	end

	if _isPromiseLike(response) then
		response
			:andThen(function(manifest: any)
				if not _setCommandsIfValid(manifest) then
					commandsAtom({} :: { CommandManifestEntry })
				end
			end)
			:catch(function()
				commandsAtom({} :: { CommandManifestEntry })
			end)
		return
	end

	if not _setCommandsIfValid(response) then
		commandsAtom({} :: { CommandManifestEntry })
	end
end

CommandSyncClient.commandsAtom = commandsAtom

return table.freeze(CommandSyncClient)
