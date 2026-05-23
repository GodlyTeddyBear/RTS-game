--!strict

local RenderTypes = {}

export type TRenderId = string

export type TRenderRegistryServerSoA = {
	Count: number,
	IndexById: { [TRenderId]: number },
	IdsByIndex: { TRenderId },
	InstancesByIndex: { Instance },
	CastShadowByIndex: { [number]: boolean? },
	ColorByIndex: { [number]: Color3? },
	MaterialByIndex: { [number]: EnumItem? },
	MaterialVariantByIndex: { [number]: string? },
	ReflectanceByIndex: { [number]: number? },
	TransparencyByIndex: { [number]: number? },
}

export type TRenderRegistryClientSoA = {
	Count: number,
	IndexById: { [TRenderId]: number },
	IdsByIndex: { TRenderId },
	InstancesByIndex: { Instance? },
	CastShadowByIndex: { [number]: boolean? },
	ColorByIndex: { [number]: Color3? },
	MaterialByIndex: { [number]: EnumItem? },
	MaterialVariantByIndex: { [number]: string? },
	ReflectanceByIndex: { [number]: number? },
	TransparencyByIndex: { [number]: number? },
}

export type TRenderRegistryBootstrapChunk = {
	Version: number?,
	ChunkIndex: number,
	ChunkCount: number,
	Count: number,
	IdsByIndex: { TRenderId },
	CastShadowByIndex: { [number]: boolean? },
	ColorByIndex: { [number]: Color3? },
	MaterialByIndex: { [number]: EnumItem? },
	MaterialVariantByIndex: { [number]: string? },
	ReflectanceByIndex: { [number]: number? },
	TransparencyByIndex: { [number]: number? },
}

export type TRenderRegistryDelta = {
	Version: number?,
	AddedCount: number?,
	AddedIdsByIndex: { TRenderId }?,
	AddedCastShadowByIndex: { [number]: boolean? }?,
	AddedColorByIndex: { [number]: Color3? }?,
	AddedMaterialByIndex: { [number]: EnumItem? }?,
	AddedMaterialVariantByIndex: { [number]: string? }?,
	AddedReflectanceByIndex: { [number]: number? }?,
	AddedTransparencyByIndex: { [number]: number? }?,
	RemovedIds: { TRenderId }?,
}

return table.freeze(RenderTypes)
