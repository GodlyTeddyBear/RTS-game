--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type LogEntry = {
	id: number,
	timestamp: number,
	level: string,
	category: string,
	context: string,
	service: string,
	milestone: string?,
	message: string,
	errType: string?,
	traceback: string?,
	data: string?,
}

--- Server atom: global log buffer (not per-player — logs are developer-only)
local function CreateServerAtom()
	return Charm.atom({} :: { LogEntry })
end

--- Client atom: same shape — full log list for the developer client
local function CreateClientAtom()
	return Charm.atom({} :: { LogEntry })
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}
