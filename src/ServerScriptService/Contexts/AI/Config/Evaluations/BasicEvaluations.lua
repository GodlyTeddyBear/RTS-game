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

	HasAttackTarget = {
		EvaluationId = "HasAttackTarget",
		Evaluate = function(context: any): boolean
			return type(context) == "table"
				and type(context.Facts) == "table"
				and type(context.Facts.AttackTargetKind) == "string"
		end,
		Metadata = {
			Description = "Passes when facts include an attack target kind.",
		},
	},

	IsOperational = {
		EvaluationId = "IsOperational",
		Evaluate = function(context: any): boolean
			return type(context) == "table"
				and type(context.Facts) == "table"
				and (context.Facts.IsOperational == true or context.Facts.StructureOperational == true)
		end,
		Metadata = {
			Description = "Passes when facts mark the entity as operational.",
		},
	},

	CanAttack = {
		EvaluationId = "CanAttack",
		Evaluate = function(context: any): boolean
			return type(context) == "table"
				and type(context.Facts) == "table"
				and (context.Facts.IsOperational == true or context.Facts.StructureOperational == true)
				and type(context.Facts.TargetEntity) == "number"
		end,
		Metadata = {
			Description = "Passes when an operational entity has a numeric target entity.",
		},
	},

	HasGoalTarget = {
		EvaluationId = "HasGoalTarget",
		Evaluate = function(context: any): boolean
			return type(context) == "table"
				and type(context.Facts) == "table"
				and context.Facts.HasGoalTarget == true
		end,
		Metadata = {
			Description = "Passes when facts include a valid movement goal.",
		},
	},

	HasBuildableTarget = {
		EvaluationId = "HasBuildableTarget",
		Evaluate = function(context: any): boolean
			return type(context) == "table"
				and type(context.Facts) == "table"
				and type(context.Facts.BuildTargetEntity) == "number"
		end,
		Metadata = {
			Description = "Passes when facts include a buildable target entity.",
		},
	},

	HasEnemyTarget = {
		EvaluationId = "HasEnemyTarget",
		Evaluate = function(context: any): boolean
			return type(context) == "table"
				and type(context.Facts) == "table"
				and context.Facts.HasEnemyTarget == true
		end,
		Metadata = {
			Description = "Passes when facts include an enemy target.",
		},
	},
}

return table.freeze(BasicEvaluations)
