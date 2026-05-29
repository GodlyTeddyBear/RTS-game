--!strict

local function cloneTable(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = cloneTable(nestedValue)
	end
	return clone
end

local BasicActions = {
	Idle = {
		ActionId = "Idle",
		ProduceIntent = function(_context: any): any
			return {
				Data = {
					Reason = "Idle",
				},
			}
		end,
		Metadata = {
			Description = "Template action that emits an idle intent.",
		},
	},

	Attack = {
		ActionId = "Attack",
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				TargetEntity = if type(facts.TargetEntity) == "number" then facts.TargetEntity else nil,
				Data = cloneTable(facts.AttackData),
			}
		end,
		Metadata = {
			Description = "Template action that emits an attack intent from target facts.",
		},
	},

	Advance = {
		ActionId = "Advance",
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				Data = cloneTable(facts.AdvanceData),
			}
		end,
		Metadata = {
			Description = "Template action that emits movement or advance intent data.",
		},
	},

	ManualMove = {
		ActionId = "ManualMove",
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				Data = cloneTable(facts.MoveData),
			}
		end,
		Metadata = {
			Description = "Template action that emits manual movement intent data.",
		},
	},

	BuildStructure = {
		ActionId = "BuildStructure",
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				TargetEntity = facts.BuildTargetEntity,
				Data = cloneTable(facts.BuildData),
			}
		end,
		Metadata = {
			Description = "Template action that emits builder construction intent data.",
		},
	},

	Extract = {
		ActionId = "Extract",
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				Data = cloneTable(facts.ExtractData),
			}
		end,
		Metadata = {
			Description = "Template action that emits extraction intent data.",
		},
	},

	Stasis = {
		ActionId = "Stasis",
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				Data = cloneTable(facts.StasisData),
			}
		end,
		Metadata = {
			Description = "Template action that emits stasis intent data.",
		},
	},

	EngageEnemy = {
		ActionId = "EngageEnemy",
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				TargetEntity = facts.TargetEntity,
				Data = {
					TargetPosition = facts.TargetPosition,
				},
			}
		end,
		Metadata = {
			Description = "Template action that emits enemy engagement intent data.",
		},
	},
}

return table.freeze(BasicActions)
