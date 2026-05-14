--!strict

export type ItemId = "Scrap" | "Alloy" | "Circuit" | "PowerCore" | "RelicShard" | "DefaultTool" | "DefaultArmor" | "DefaultAccessory"

return table.freeze({
	Scrap = "Scrap" :: "Scrap",
	Alloy = "Alloy" :: "Alloy",
	Circuit = "Circuit" :: "Circuit",
	PowerCore = "PowerCore" :: "PowerCore",
	RelicShard = "RelicShard" :: "RelicShard",
	DefaultTool = "DefaultTool" :: "DefaultTool",
	DefaultArmor = "DefaultArmor" :: "DefaultArmor",
	DefaultAccessory = "DefaultAccessory" :: "DefaultAccessory",
})
