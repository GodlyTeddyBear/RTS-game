--!strict

export type CategorySettings = {
	maxStack: number,
	totalCapacity: number,
	displayOrder: number,
}

local CategoryConfig: { [string]: CategorySettings } = {
	Material = {
		maxStack = 100,
		totalCapacity = 200,
		displayOrder = 1,
	},
}

return table.freeze(CategoryConfig)
