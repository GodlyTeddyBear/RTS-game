--!strict

--[[
	WorkerSpecs — Re-export shim.

	Merges AssignmentSpecs and TickSpecs into a single table for backwards
	compatibility. Policies that import WorkerSpecs do not need to change.

	Prefer importing the specific file directly in new code:
	  AssignmentSpecs — hire, role, target/recipe assignment checks
	  TickSpecs       — per-tick production eligibility checks
]]

local AssignmentSpecs = require(script.Parent.AssignmentSpecs)
local TickSpecs = require(script.Parent.TickSpecs)

-- Re-export candidate types from all modules
export type THireCandidate = AssignmentSpecs.THireCandidate
export type TAssignRoleCandidate = AssignmentSpecs.TAssignRoleCandidate
export type TAssignMinerOreCandidate = AssignmentSpecs.TAssignMinerOreCandidate
export type TAssignForgeRecipeCandidate = AssignmentSpecs.TAssignForgeRecipeCandidate
export type TAssignBreweryRecipeCandidate = AssignmentSpecs.TAssignBreweryRecipeCandidate
export type TAssignTailoringRecipeCandidate = AssignmentSpecs.TAssignTailoringRecipeCandidate
export type TAssignLumberjackTargetCandidate = AssignmentSpecs.TAssignLumberjackTargetCandidate
export type TAssignHerbalistTargetCandidate = AssignmentSpecs.TAssignHerbalistTargetCandidate
export type TAssignFarmerTargetCandidate = AssignmentSpecs.TAssignFarmerTargetCandidate
export type TMiningTickCandidate = TickSpecs.TMiningTickCandidate
export type TProductionTickCandidate = TickSpecs.TProductionTickCandidate
export type TForgeTickCandidate = TickSpecs.TForgeTickCandidate
export type TBreweryTickCandidate = TickSpecs.TBreweryTickCandidate
export type TTailoringTickCandidate = TickSpecs.TTailoringTickCandidate
export type THarvestTickCandidate = TickSpecs.THarvestTickCandidate

local merged = table.clone(AssignmentSpecs)
for k, v in TickSpecs do
	merged[k] = v
end

return table.freeze(merged)
