--!strict

--[[
	ChapterConfig — Defines the auto-advancement conditions for each chapter.

	When a player meets all conditions for the next chapter, they advance automatically.
	Chapter 1 is the starting chapter — no entry needed here.

	FIELDS:
	  Chapter       — The chapter number being unlocked
	  DisplayName   — Human-readable chapter name shown in UI
	  Description   — Short flavour text about what this chapter opens up
	  Conditions    — All thresholds must be met to advance to this chapter
	    CommissionTier  — Player's current commission tier must be >= this value
	    QuestsCompleted — Player's completed quest count must be >= this value
	    WorkerCount     — Player's total hired worker count must be >= this value

	TRIGGER FIELDS:
	  Chapter advancement is re-evaluated whenever CommissionTier, QuestsCompleted,
	  or WorkerCount changes — the same triggers that drive ProcessAutoUnlocks.
]]

export type TChapterConditions = {
	CommissionTier: number?,
	QuestsCompleted: number?,
	WorkerCount: number?,
	SmelterPlaced: boolean?,
	Ch2FirstVictory: boolean?,
}

export type TChapterEntry = {
	Chapter: number,
	DisplayName: string,
	Description: string,
	Conditions: TChapterConditions,
	IntroEvent: string?,
	IntroSeenFlag: string?,
}

return table.freeze({
	[2] = {
		Chapter = 2,
		DisplayName = "The Forge Awakens",
		Description = "New crafting roles and resources become available.",
		Conditions = { SmelterPlaced = true },
		IntroEvent = "Guide.Ch2IntroReady",
		IntroSeenFlag = "Ch2_IntroSeen",
	} :: TChapterEntry,

	[3] = {
		Chapter = 3,
		DisplayName = "Masters of Trade",
		Description = "Advanced roles and rare materials open up.",
		Conditions = { Ch2FirstVictory = true },
		IntroEvent = "Guide.Ch3IntroReady",
		IntroSeenFlag = "Ch3_IntroSeen",
	} :: TChapterEntry,
}) :: { [number]: TChapterEntry }
