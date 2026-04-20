--!strict

export type TCommissionRequirement = {
	ItemId: string,
	Quantity: number,
}

export type TRewardItem = {
	ItemId: string,
	Quantity: number,
}

export type TCommissionReward = {
	Gold: number,
	Tokens: number,
	Items: { TRewardItem }?,
}

export type TCommissionSource = "Board" | "Visitor"

export type TBoardCommission = {
	Id: string,
	PoolId: string,
	Tier: number,
	Requirement: TCommissionRequirement,
	Reward: TCommissionReward,
	ExpiresAt: number,
	Source: TCommissionSource?,
	VillagerId: string?,
	TargetUserId: number?,
}

export type TActiveCommission = {
	Id: string,
	PoolId: string,
	Tier: number,
	Requirement: TCommissionRequirement,
	Reward: TCommissionReward,
	AcceptedAt: number,
	Source: TCommissionSource?,
	VillagerId: string?,
	TargetUserId: number?,
}

export type TCommissionState = {
	Board: { TBoardCommission },
	Active: { TActiveCommission },
	Tokens: number,
	CurrentTier: number,
	LastRefreshTime: number,
}

return {}
