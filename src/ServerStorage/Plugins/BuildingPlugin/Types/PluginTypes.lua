--!strict

export type TPluginTab = "Building" | "Settings" | "Assets"

export type TPluginStatusTone = "Info" | "Success" | "Error"

export type TPluginStatus = {
	Message: string,
	Tone: TPluginStatusTone,
}

export type TSelectionSummary = {
	Count: number,
	Names: { string },
}

export type TAssetEntry = {
	Name: string,
	Path: string,
	Instance: Instance,
}

export type TPluginActionResult = {
	Success: boolean,
	ChangedCount: number,
	SkippedCount: number,
	Message: string,
	Path: string?,
}

export type TPluginSettings = {
	AssetRootName: string,
	FolderPresets: { string },
	RecentAssets: { string },
}

return table.freeze({})
