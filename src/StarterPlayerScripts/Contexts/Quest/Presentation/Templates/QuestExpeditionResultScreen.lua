--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local useQuestState = require(script.Parent.Parent.Parent.Application.Hooks.useQuestState)
local useQuestActions = require(script.Parent.Parent.Parent.Application.Hooks.useQuestActions)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useQuestResultModalController = require(script.Parent.Parent.Parent.Application.Hooks.useQuestResultModalController)

local ExpeditionViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.ExpeditionViewModel)
local QuestExpeditionResultScreenView = require(script.Parent.QuestExpeditionResultScreenView)

local function QuestExpeditionResultScreen()
	local questState = useQuestState()
	local questActions = useQuestActions()
	local navActions = useNavigationActions()
	local modal = useQuestResultModalController()

	local expedition = questState and questState.ActiveExpedition or nil
	local viewModel = React.useMemo(function()
		return ExpeditionViewModel.fromExpeditionState(expedition)
	end, { expedition })

	React.useEffect(function()
		if questState and questState.ActiveExpedition == nil then
			navActions.reset("Game")
		end
	end, { questState, navActions })

	return e(QuestExpeditionResultScreenView, {
		backdropRef = modal.backdropRef,
		cardRef = modal.cardRef,
		scaleRef = modal.scaleRef,
		viewModel = viewModel,
		onReturnToGuild = function()
			questActions.acknowledgeExpedition()
		end,
	})
end

return QuestExpeditionResultScreen
