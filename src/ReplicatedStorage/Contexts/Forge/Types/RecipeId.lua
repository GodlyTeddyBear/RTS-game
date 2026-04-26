--!strict

export type RecipeId = "Alloy" | "Circuit" | "PowerCore"

return table.freeze({
	Alloy = "Alloy" :: "Alloy",
	Circuit = "Circuit" :: "Circuit",
	PowerCore = "PowerCore" :: "PowerCore",
})
