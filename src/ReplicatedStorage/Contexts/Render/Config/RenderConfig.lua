--!strict

local RenderConfig = {}

RenderConfig.ShadowStateAttributeName = "RenderAuthoredCastShadow"

RenderConfig.ServerProfile = table.freeze({
	Lighting = table.freeze({
		GlobalShadows = false,
	}),
})

RenderConfig.ClientProfile = table.freeze({
	Lighting = table.freeze({
		GlobalShadows = true,
	}),
})

return table.freeze(RenderConfig)
