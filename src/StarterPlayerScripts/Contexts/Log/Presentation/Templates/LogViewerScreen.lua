--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useLogs = require(script.Parent.Parent.Parent.Application.Hooks.useLogs)
local LogViewerViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.LogViewerViewModel)
local LogViewerScreenView = require(script.Parent.LogViewerScreenView)
local CommandsScreen = require(script.Parent.CommandsScreen)

type Props = {
	logsAtom: () -> { any },
	onClearAll: (sourceFilter: string) -> (),
	onClearFiltered: (filters: { source: string, context: string?, category: string? }) -> (),
}

type TFilterOption = LogViewerViewModel.TFilterOption

local function hasOption(options: { TFilterOption }, value: string): boolean
	for _, option in ipairs(options) do
		if option.value == value then
			return true
		end
	end
	return false
end

local function LogViewerScreen(props: Props)
	local logs = useLogs(props.logsAtom)
	local activePage, setActivePage = React.useState("logs")
	local activeLevel, setActiveLevel = React.useState("all")
	local activeCategory, setActiveCategory = React.useState("all")
	local activeSource, setActiveSource = React.useState("all")
	local activeContext, setActiveContext = React.useState("all")

	local viewData = React.useMemo(function()
		return LogViewerViewModel.build(logs, {
			level = activeLevel,
			category = activeCategory,
			source = activeSource,
			context = activeContext,
		})
	end, { logs, activeLevel, activeCategory, activeSource, activeContext })

	React.useEffect(function()
		if not hasOption(viewData.levelOptions, activeLevel) then
			setActiveLevel("all")
		end
	end, { viewData.levelOptions, activeLevel })

	React.useEffect(function()
		if not hasOption(viewData.categoryOptions, activeCategory) then
			setActiveCategory("all")
		end
	end, { viewData.categoryOptions, activeCategory })

	React.useEffect(function()
		if not hasOption(viewData.sourceOptions, activeSource) then
			setActiveSource("all")
		end
	end, { viewData.sourceOptions, activeSource })

	React.useEffect(function()
		if not hasOption(viewData.contextOptions, activeContext) then
			setActiveContext("all")
		end
	end, { viewData.contextOptions, activeContext })

	return e(LogViewerScreenView, {
		viewData = viewData,
		activePage = activePage,
		activeLevel = activeLevel,
		activeCategory = activeCategory,
		activeSource = activeSource,
		activeContext = activeContext,
		onPageChange = setActivePage,
		onSelectLevel = setActiveLevel,
		onSelectCategory = setActiveCategory,
		onSelectSource = setActiveSource,
		onSelectContext = setActiveContext,
		commandsContent = e(CommandsScreen),
		onClearAll = function()
			setActiveLevel("all")
			setActiveCategory("all")
			setActiveSource("all")
			setActiveContext("all")
			props.onClearAll(activeSource)
		end,
		onClearFiltered = function()
			local contextFilter = if activeContext == "all" then nil else activeContext
			local categoryFilter = if activeCategory == "all" then nil else activeCategory
			props.onClearFiltered({
				source = activeSource,
				context = contextFilter,
				category = categoryFilter,
			})
		end,
	})
end

return LogViewerScreen
