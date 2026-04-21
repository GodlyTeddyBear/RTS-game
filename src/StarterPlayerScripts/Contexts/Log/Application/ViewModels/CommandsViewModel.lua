--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LogCommandTypes = require(ReplicatedStorage.Contexts.Log.Types.LogCommandTypes)

type CommandManifestEntry = LogCommandTypes.CommandManifestEntry

export type GroupedCommands = {
	contextName: string,
	commands: { CommandManifestEntry },
}

local CommandsViewModel = {}

function CommandsViewModel.build(manifest: { CommandManifestEntry }): { GroupedCommands }
	local groupedByContext: { [string]: { CommandManifestEntry } } = {}

	for _, command in ipairs(manifest) do
		local contextName = command.context
		local commands = groupedByContext[contextName]
		if commands == nil then
			commands = {}
			groupedByContext[contextName] = commands
		end
		table.insert(commands, command)
	end

	local grouped: { GroupedCommands } = {}
	for contextName, commands in pairs(groupedByContext) do
		table.sort(commands, function(a, b)
			return a.name < b.name
		end)
		table.freeze(commands)

		local group: GroupedCommands = {
			contextName = contextName,
			commands = commands,
		}
		table.freeze(group)
		table.insert(grouped, group)
	end

	table.sort(grouped, function(a, b)
		return a.contextName < b.contextName
	end)

	return table.freeze(grouped)
end

return table.freeze(CommandsViewModel)
