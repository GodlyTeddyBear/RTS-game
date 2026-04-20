--!strict

export type TDungeonStatus = "Generating" | "Active" | "WaveClearing" | "Complete"

export type TDungeonState = {
	ZoneId: string,
	CurrentWave: number,
	TotalWaves: number,
	Status: TDungeonStatus,
}

export type TSpawnPoint = {
	Position: Vector3,
	SpawnPartSize: Vector3,
	SpawnPartCFrame: CFrame,
}

return {}
