--!strict

--[=[
	@class Chapters
	Index module exporting all chapter milestone modules.
	@server
]=]

local Chapter1 = require(script.Chapter1)
local Chapter2 = require(script.Chapter2)
local Chapter3 = require(script.Chapter3)

return table.freeze({
	Chapter1,
	Chapter2,
	Chapter3,
})
