--!strict

local BaseCommand = require(script.BaseCommand)
local BaseQuery = require(script.BaseQuery)

export type TDependencyMap = BaseCommand.TDependencyMap
export type TBaseCommand = BaseCommand.TBaseCommand
export type TBaseQuery = BaseQuery.TBaseQuery

return table.freeze({
	BaseCommand = BaseCommand,
	BaseQuery = BaseQuery,
})
