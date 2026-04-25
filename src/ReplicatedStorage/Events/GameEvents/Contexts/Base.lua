--!strict

local Base = {}

local events = table.freeze({
	BaseDestroyed = "Base.BaseDestroyed",
})

local schemas: { [string]: { string } } = {
	[events.BaseDestroyed] = {},
}

Base.events = events
Base.schemas = schemas

return Base
