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
}

return table.freeze(CategoryConfig)
