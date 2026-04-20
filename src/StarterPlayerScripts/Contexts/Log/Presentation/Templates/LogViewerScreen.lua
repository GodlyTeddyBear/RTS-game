--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local Knit = require(ReplicatedStorage.Packages.Knit)

local useLogs = require(script.Parent.Parent.Parent.Application.Hooks.useLogs)
local LogViewerViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.LogViewerViewModel)
local LogViewerScreenView = require(script.Parent.LogViewerScreenView)

type Props = {
	logsAtom: () -> { any },
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
	local activeLevel, setActiveLevel = React.useState("all")
	local activeCategory, setActiveCategory = React.useState("all")
	local activeContext, setActiveContext = React.useState("all")

	local viewData = React.useMemo(function()
		return LogViewerViewModel.build(logs, {
			level = activeLevel,
			category = activeCategory,
			context = activeContext,
		})
	end, { logs, activeLevel, activeCategory, activeContext })

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
		if not hasOption(viewData.contextOptions, activeContext) then
			setActiveContext("all")
		end
	end, { viewData.contextOptions, activeContext })

	return e(LogViewerScreenView, {
		viewData = viewData,
		activeLevel = activeLevel,
		activeCategory = activeCategory,
		activeContext = activeContext,
		onSelectLevel = setActiveLevel,
		onSelectCategory = setActiveCategory,
		onSelectContext = setActiveContext,
		onClearAll = function()
			local logContext = Knit.GetService("LogContext")
			setActiveLevel("all")
			setActiveCategory("all")
			setActiveContext("all")
			logContext:ClearLogs()
		end,
		onClearFiltered = function()
			local logContext = Knit.GetService("LogContext")
			local contextFilter = if activeContext == "all" then nil else activeContext
			local categoryFilter = if activeCategory == "all" then nil else activeCategory
			logContext:ClearLogsByScope(contextFilter, categoryFilter)
		end,
	})
end

return LogViewerScreen
