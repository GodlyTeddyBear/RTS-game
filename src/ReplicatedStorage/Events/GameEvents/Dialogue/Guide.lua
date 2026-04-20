--!strict

--[=[
	@class GuideEvents
	Event registry for guide/quest trigger events consumed by the Dialogue context.
	@server
]=]

--[=[
	@prop ShopOpened string
	@within GuideEvents
	Fired when the shop is opened. Emitted with: `(userId: number)`
]=]

--[=[
	@prop MinerHired string
	@within GuideEvents
	Fired when a miner worker is hired. Emitted with: `(userId: number)`
]=]

--[=[
	@prop LumberjackHired string
	@within GuideEvents
	Fired when a lumberjack worker is hired. Emitted with: `(userId: number)`
]=]

--[=[
	@prop CharcoalCrafted string
	@within GuideEvents
	Fired when charcoal is crafted. Emitted with: `(userId: number)`
]=]

--[=[
	@prop SmelterAffordable string
	@within GuideEvents
	Fired when the player can afford a smelter. Emitted with: `(userId: number)`
]=]

--[=[
	@prop SmelterPlaced string
	@within GuideEvents
	Fired when a smelter is placed. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch2IntroReady string
	@within GuideEvents
	Fired when Chapter 2 intro sequence is ready. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch2ExpeditionLaunched string
	@within GuideEvents
	Fired when a Chapter 2 expedition begins. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch2OutcomeVictory string
	@within GuideEvents
	Fired when a Chapter 2 expedition ends in victory. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch2OutcomeDefeat string
	@within GuideEvents
	Fired when a Chapter 2 expedition ends in defeat. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch2OutcomeFled string
	@within GuideEvents
	Fired when a Chapter 2 expedition ends with the party fleeing. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch3IntroReady string
	@within GuideEvents
	Fired when Chapter 3 intro sequence is ready. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch3BrewerHired string
	@within GuideEvents
	Fired when the brewer worker is hired. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch3ExpeditionLaunched string
	@within GuideEvents
	Fired when a Chapter 3 expedition begins. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch3OutcomeVictory string
	@within GuideEvents
	Fired when a Chapter 3 expedition ends in victory. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch3OutcomeDefeat string
	@within GuideEvents
	Fired when a Chapter 3 expedition ends in defeat. Emitted with: `(userId: number)`
]=]

--[=[
	@prop Ch3OutcomeFled string
	@within GuideEvents
	Fired when a Chapter 3 expedition ends with the party fleeing. Emitted with: `(userId: number)`
]=]

local events = table.freeze({
	ShopOpened = "Guide.ShopOpened",
	MinerHired = "Guide.MinerHired",
	LumberjackHired = "Guide.LumberjackHired",
	CharcoalCrafted = "Guide.CharcoalCrafted",
	SmelterAffordable = "Guide.SmelterAffordable",
	SmelterPlaced = "Guide.SmelterPlaced",
	Ch2IntroReady = "Guide.Ch2IntroReady",
	Ch2ExpeditionLaunched = "Guide.Ch2ExpeditionLaunched",
	Ch2OutcomeVictory = "Guide.Ch2OutcomeVictory",
	Ch2OutcomeDefeat = "Guide.Ch2OutcomeDefeat",
	Ch2OutcomeFled = "Guide.Ch2OutcomeFled",
	Ch3IntroReady = "Guide.Ch3IntroReady",
	Ch3BrewerHired = "Guide.Ch3BrewerHired",
	Ch3ExpeditionLaunched = "Guide.Ch3ExpeditionLaunched",
	Ch3OutcomeVictory = "Guide.Ch3OutcomeVictory",
	Ch3OutcomeDefeat = "Guide.Ch3OutcomeDefeat",
	Ch3OutcomeFled = "Guide.Ch3OutcomeFled",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.ShopOpened] = { "number" },
	[events.MinerHired] = { "number" },
	[events.LumberjackHired] = { "number" },
	[events.CharcoalCrafted] = { "number" },
	[events.SmelterAffordable] = { "number" },
	[events.SmelterPlaced] = { "number" },
	[events.Ch2IntroReady] = { "number" },
	[events.Ch2ExpeditionLaunched] = { "number" },
	[events.Ch2OutcomeVictory] = { "number" },
	[events.Ch2OutcomeDefeat] = { "number" },
	[events.Ch2OutcomeFled] = { "number" },
	[events.Ch3IntroReady] = { "number" },
	[events.Ch3BrewerHired] = { "number" },
	[events.Ch3ExpeditionLaunched] = { "number" },
	[events.Ch3OutcomeVictory] = { "number" },
	[events.Ch3OutcomeDefeat] = { "number" },
	[events.Ch3OutcomeFled] = { "number" },
}

return { events = events, schemas = schemas }
