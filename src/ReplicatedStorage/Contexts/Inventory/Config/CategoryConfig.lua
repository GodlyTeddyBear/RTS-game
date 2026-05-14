--!strict

export type CategorySettings = {
	MaxStack: number,
	TotalCapacity: number,
	DisplayOrder: number,
}

local CategoryConfig: { [string]: CategorySettings } = {
	Material = {
		MaxStack = 100,
		TotalCapacity = 200,
		DisplayOrder = 1,
	},
	Tool = {
		MaxStack = 1,
		TotalCapacity = 50,
		DisplayOrder = 2,
	},
	Armor = {
		MaxStack = 1,
		TotalCapacity = 50,
		DisplayOrder = 3,
	},
	Accessory = {
		MaxStack = 1,
		TotalCapacity = 50,
		DisplayOrder = 4,
	},
}

return table.freeze(CategoryConfig)
