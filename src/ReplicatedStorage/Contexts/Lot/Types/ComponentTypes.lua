--!strict

--[[
	Component type definitions for Lot ECS system.
	These types define the shape of component data stored in JECS world.
]]

export type TLotComponent = {
	LotId: string,  -- Unique lot identifier
	UserId: number, -- Owner player ID
}

export type TPositionComponent = {
	CFrameValue: CFrame,
}

export type TGameObjectComponent = {
	Instance: Model, -- Reference to Roblox model in workspace
}

export type TZoneComponent = {
	ZoneName: string, -- e.g. "Production"
	Instance: Folder, -- Reference to Lot.Zones.[ZoneName] folder
}

export type TMinesComponent = {
	Instance: Folder, -- Reference to Lot.Zones.Production.Mines folder
}

export type TFarmComponent = {
	Instance: Folder, -- Reference to Lot.Zones.Production.Farm folder
}

export type TGardenComponent = {
	Instance: Folder, -- Reference to Lot.Zones.Production.Garden folder
}

export type TForestComponent = {
	Instance: Folder, -- Reference to Lot.Zones.Production.Forest folder
}

export type TForgeComponent = {
	Instance: Folder, -- Reference to Lot.Zones.Production.Forge folder
}

export type TBreweryComponent = {
	Instance: Folder, -- Reference to Lot.Zones.Production.Brewery folder
}

export type TTailorShopComponent = {
	Instance: Folder, -- Reference to Lot.Zones.Production.TailorShop folder
}

-- Tags (components with no data, used for filtering)
export type TDirtyTag = boolean -- Marks entity as needing GameObject sync

return {}
