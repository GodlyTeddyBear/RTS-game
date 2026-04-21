--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Knit = require(ReplicatedStorage.Packages.Knit)
local LogCommandTypes = require(ReplicatedStorage.Contexts.Log.Types.LogCommandTypes)

type CommandManifestEntry = LogCommandTypes.CommandManifestEntry

local CommandSyncClient = {}

local commandsAtom = Charm.atom({} :: { CommandManifestEntry })

function CommandSyncClient.Initialize()
	local logContext = Knit.GetService("LogContext")
	local ok, manifest = pcall(function()
		return logContext:GetCommands()
	end)

	if not ok or type(manifest) ~= "table" then
		commandsAtom({} :: { CommandManifestEntry })
		return
	end

	commandsAtom(manifest :: { CommandManifestEntry })
end

CommandSyncClient.commandsAtom = commandsAtom

return table.freeze(CommandSyncClient)
