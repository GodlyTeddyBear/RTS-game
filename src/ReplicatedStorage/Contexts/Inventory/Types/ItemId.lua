--!strict

export type ItemId = "Scrap" | "Alloy" | "Circuit" | "PowerCore" | "RelicShard"

return table.freeze({
	Scrap = "Scrap" :: "Scrap",
	Alloy = "Alloy" :: "Alloy",
	Circuit = "Circuit" :: "Circuit",
	PowerCore = "PowerCore" :: "PowerCore",
	RelicShard = "RelicShard" :: "RelicShard",
})
