--!strict

local SummonIdleExecutor = require(script.SummonIdleExecutor)

return table.freeze({
	["Summon.Idle"] = table.freeze({
		ActionId = "Summon.Idle",
		CreateExecutor = SummonIdleExecutor.new,
	}),
})
