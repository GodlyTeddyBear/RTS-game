--!strict

local UnitIdleExecutor = require(script.UnitIdleExecutor)

return table.freeze({
	["Unit.Idle"] = table.freeze({
		ActionId = "Unit.Idle",
		CreateExecutor = UnitIdleExecutor.new,
	}),
})
