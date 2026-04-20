--!strict

export type TTaskStatus = "Active" | "Claimable" | "Claimed"

export type TTaskObjectiveKind = "CraftItem" | "KillNPC"

export type TTaskObjectiveDefinition = {
	Id: string,
	Kind: TTaskObjectiveKind,
	TargetId: string,
	Required: number,
	Description: string,
}

export type TTaskRewardItem = {
	ItemId: string,
	Quantity: number,
}

export type TTaskRewards = {
	Gold: number?,
	Items: { TTaskRewardItem }?,
	Unlocks: { string }?,
	Flags: { [string]: boolean | string | number }?,
}

export type TTaskUnlockConditions = {
	Chapter: number?,
	Unlocks: { string }?,
	CompletedTaskIds: { string }?,
	ExpeditionsCompleted: number?,
	Flags: { [string]: boolean | string | number }?,
}

export type TTaskDefinition = {
	Id: string,
	Title: string,
	Description: string,
	UnlockConditions: TTaskUnlockConditions?,
	Objectives: { TTaskObjectiveDefinition },
	Rewards: TTaskRewards?,
	Repeatable: boolean?,
}

export type TTaskObjectiveProgress = {
	Amount: number,
}

export type TPlayerTaskProgress = {
	TaskId: string,
	Status: TTaskStatus,
	Objectives: { [string]: TTaskObjectiveProgress },
	StartedAt: number,
	ClaimableAt: number?,
	ClaimedAt: number?,
}

export type TTaskState = {
	Tasks: { [string]: TPlayerTaskProgress },
}

export type TTaskProgressInput = {
	UserId: number,
	Kind: TTaskObjectiveKind,
	TargetId: string,
	Amount: number,
}

export type TClaimTaskRewardResult = {
	TaskId: string,
	Status: TTaskStatus,
	Rewards: TTaskRewards?,
}

return {}
