--!strict

local BasicEvaluations = {
	AlwaysTrue = {
		EvaluationId = "AlwaysTrue",
		Evaluate = function(_context: any): boolean
			return true
		end,
		Metadata = {
			Description = "Template condition that always passes.",
		},
	},

	AlwaysFalse = {
		EvaluationId = "AlwaysFalse",
		Evaluate = function(_context: any): boolean
			return false
		end,
		Metadata = {
			Description = "Template condition that always fails.",
		},
	},

	HasTargetEntity = {
		EvaluationId = "HasTargetEntity",
		Evaluate = function(context: any): boolean
			return type(context) == "table"
				and type(context.Facts) == "table"
				and type(context.Facts.TargetEntity) == "number"
		end,
		Metadata = {
			Description = "Passes when facts include a numeric TargetEntity.",
		},
	},
}

return table.freeze(BasicEvaluations)
