--!strict
export type CategorySettings = {
	maxStack: number,
	totalCapacity: number,
	displayOrder: number,
}

local CategoryConfig: { [string]: CategorySettings } = {
	Weapon = {
		maxStack = 1,
		totalCapacity = 50,
		displayOrder = 1,
	},
	Armor = {
		maxStack = 1,
		totalCapacity = 50,
		displayOrder = 2,
	},
	Consumable = {
		maxStack = 100,
		totalCapacity = 100,
		displayOrder = 3,
	},
	Material = {
		maxStack = 100,
		totalCapacity = 200,
		displayOrder = 4,
	},
	Quest = {
		maxStack = 1,
		totalCapacity = 50,
		displayOrder = 5,
	},
}

table.freeze(CategoryConfig)
return CategoryConfig
