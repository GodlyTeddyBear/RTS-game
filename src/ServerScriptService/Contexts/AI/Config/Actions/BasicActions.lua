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
}

return table.freeze(BasicActions)
