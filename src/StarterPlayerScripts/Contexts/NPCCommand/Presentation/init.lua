--!strict
local NPCCommandScreen = require(script.Templates.NPCCommandScreen)
local ControlAreaPanel = require(script.Organisms.ControlAreaPanel)
local OptionAreaPanel = require(script.Organisms.OptionAreaPanel)
local UnitListPanel = require(script.Organisms.UnitListPanel)

return {
	NPCCommandScreen = NPCCommandScreen,
	ControlAreaPanel = ControlAreaPanel,
	OptionAreaPanel = OptionAreaPanel,
	UnitListPanel = UnitListPanel,
}
