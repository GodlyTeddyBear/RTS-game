--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local LogCommandTypes = require(ReplicatedStorage.Contexts.Log.Types.LogCommandTypes)
local CommandSyncClient = require(script.Parent.Parent.Parent.Infrastructure.CommandSyncClient)

type CommandManifestEntry = LogCommandTypes.CommandManifestEntry

local function useCommands(): { CommandManifestEntry }
	return ReactCharm.useAtom(CommandSyncClient.commandsAtom) or {}
end

return useCommands
