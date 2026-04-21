--!strict

local LogCommandTypes = {}

export type CommandParam = {
	name: string,
	label: string,
	default: string?,
}

export type CommandExecutionResult = {
	success: boolean,
	message: string,
}

export type CommandManifestEntry = {
	name: string,
	context: string,
	description: string?,
	params: { CommandParam }?,
}

export type RegisteredLogCommand = CommandManifestEntry & {
	handler: (params: { [string]: string }) -> (boolean, string),
}

return table.freeze(LogCommandTypes)
