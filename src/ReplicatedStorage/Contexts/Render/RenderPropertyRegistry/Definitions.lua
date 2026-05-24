--!strict

export type TRenderPropertyDefinition = {
	DesiredValue: any?,
}

export type TRenderPropertyDefinitions = {
	[string]: TRenderPropertyDefinition,
}

local PropertyDefinitions: TRenderPropertyDefinitions = {
	CastShadow = {
		DesiredValue = false,
	},
	Color = {
		--DesiredValue = Color3.fromRGB(128, 128, 128),
	},
	Material = {
		DesiredValue = Enum.Material.SmoothPlastic,
	},
	MaterialVariant = {
		DesiredValue = "",
	},
	Reflectance = {
		DesiredValue = 0,
	},
	Transparency = {
		DesiredValue = 0,
	},
}

return PropertyDefinitions
