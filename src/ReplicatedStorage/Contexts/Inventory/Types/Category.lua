--!strict

export type Category = "Material" | "Tool" | "Armor" | "Accessory"

return table.freeze({
	Material = "Material" :: "Material",
	Tool = "Tool" :: "Tool",
	Armor = "Armor" :: "Armor",
	Accessory = "Accessory" :: "Accessory",
})
