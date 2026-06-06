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
		CanStart = function(_context: any): boolean
			return false
		end,
		ProduceIntent = function(_context: any): any
			return {
				Data = {
					Reason = "Idle",
				},
			}
		end,
		Metadata = {
			Description = "Template action that emits an idle intent.",
			AllowsMovement = false,
		},
	},

	Attack = {
		ActionId = "Attack",
		StartsComponent = {
			FeatureName = "Combat",
			Key = "AttackState",
		},
		CanStart = function(context: any): boolean
			local data = if type(context.ActionIntent) == "table" and type(context.ActionIntent.Data) == "table"
				then context.ActionIntent.Data
				else nil
			return type(data) == "table" and type(data.AbilityId) == "string"
		end,
		BuildInitialState = function(context: any): any
			local intent = if type(context.ActionIntent) == "table" then context.ActionIntent else {}
			local data = if type(intent.Data) == "table" then intent.Data else {}

			return {
				ActionId = "Attack",
				AbilityId = data.AbilityId,
				SourceEntity = context.Entity,
				TargetEntity = intent.TargetEntity,
				TargetKind = data.TargetKind,
				Phase = "Startup",
				Elapsed = 0,
				Damage = data.Damage,
				Cooldown = data.Cooldown,
				Range = data.Range,
				TargetPosition = data.TargetPosition,
				RequestedAt = intent.RequestedAt,
				StartedAt = context.Now,
				UpdatedAt = context.Now,
				HasEmittedRequest = false,
			}
		end,
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				TargetEntity = if type(facts.TargetEntity) == "number" then facts.TargetEntity else nil,
				Data = cloneTable(facts.AttackData),
			}
		end,
		Metadata = {
			Description = "Template action that emits an attack intent from target facts.",
			AllowsMovement = false,
			Interrupts = {
				Advance = true,
			},
		},
	},

	Advance = {
		ActionId = "Advance",
		StartsComponent = {
			FeatureName = "Movement",
			Key = "MoveIntent",
		},
		BuildInitialState = function(context: any): any
			local intent = if type(context.ActionIntent) == "table" then context.ActionIntent else {}
			local data = if type(intent.Data) == "table" then intent.Data else {}

			return {
				ActionId = "Advance",
				SourceEntity = context.Entity,
				GoalPosition = data.GoalPosition,
				MovementMode = data.MovementMode or "Any",
				Reason = "Advance",
				RequestedAt = intent.RequestedAt,
				Status = "Requested",
			}
		end,
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				Data = cloneTable(facts.AdvanceData),
			}
		end,
		Metadata = {
			Description = "Template action that emits movement or advance intent data.",
			MovementAction = true,
			AllowsMovement = true,
		},
	},

	ManualMove = {
		ActionId = "ManualMove",
		StartsComponent = {
			FeatureName = "Movement",
			Key = "MoveIntent",
		},
		BuildInitialState = function(context: any): any
			local intent = if type(context.ActionIntent) == "table" then context.ActionIntent else {}
			local data = if type(intent.Data) == "table" then intent.Data else {}

			return {
				ActionId = "ManualMove",
				SourceEntity = context.Entity,
				GoalPosition = data.GoalPosition,
				MovementMode = data.MovementMode or "Path",
				Reason = "ManualMove",
				RequestedAt = intent.RequestedAt,
				Status = "Requested",
			}
		end,
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				Data = cloneTable(facts.MoveData),
			}
		end,
		Metadata = {
			Description = "Template action that emits manual movement intent data.",
			MovementAction = true,
			AllowsMovement = true,
		},
	},

	BuildStructure = {
		ActionId = "BuildStructure",
		StartsComponent = {
			FeatureName = "Structure",
			Key = "BuildContributionState",
		},
		BuildInitialState = function(context: any): any
			local intent = if type(context.ActionIntent) == "table" then context.ActionIntent else {}
			local data = if type(intent.Data) == "table" then intent.Data else {}

			return {
				ActionId = "BuildStructure",
				SourceEntity = context.Entity,
				TargetStructureEntity = if type(intent.TargetEntity) == "number" then intent.TargetEntity else data.TargetStructureEntity,
				RequestedAt = intent.RequestedAt,
				StartedAt = context.Now,
				UpdatedAt = context.Now,
			}
		end,
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				TargetEntity = facts.BuildTargetEntity,
				Data = cloneTable(facts.BuildData),
			}
		end,
		Metadata = {
			Description = "Template action that emits builder construction intent data.",
			AllowsMovement = true,
		},
	},

	Extract = {
		ActionId = "Extract",
		StartsComponent = {
			FeatureName = "Structure",
			Key = "ExtractState",
		},
		BuildInitialState = function(context: any): any
			local intent = if type(context.ActionIntent) == "table" then context.ActionIntent else {}
			local data = if type(intent.Data) == "table" then intent.Data else {}

			return {
				ActionId = "Extract",
				SourceEntity = context.Entity,
				InstanceId = data.InstanceId,
				RequestedAt = intent.RequestedAt,
				StartedAt = context.Now,
				UpdatedAt = context.Now,
			}
		end,
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				Data = cloneTable(facts.ExtractData),
			}
		end,
		Metadata = {
			Description = "Template action that emits extraction intent data.",
			AllowsMovement = false,
		},
	},

	Stasis = {
		ActionId = "Stasis",
		StartsComponent = {
			FeatureName = "Combat",
			Key = "StatusAuraState",
		},
		BuildInitialState = function(context: any): any
			local intent = if type(context.ActionIntent) == "table" then context.ActionIntent else {}
			local data = if type(intent.Data) == "table" then intent.Data else {}

			return {
				ActionId = "Stasis",
				SourceEntity = context.Entity,
				AuraType = "StasisField",
				StructureEntity = data.StructureEntity or context.Entity,
				RequestedAt = intent.RequestedAt,
				StartedAt = context.Now,
				UpdatedAt = context.Now,
			}
		end,
		ProduceIntent = function(context: any): any
			local facts = if type(context) == "table" and type(context.Facts) == "table" then context.Facts else {}

			return {
				Data = cloneTable(facts.StasisData),
			}
		end,
		Metadata = {
			Description = "Template action that emits stasis intent data.",
			AllowsMovement = false,
		},
	},

}

return table.freeze(BasicActions)
