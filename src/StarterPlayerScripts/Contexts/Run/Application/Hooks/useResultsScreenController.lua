--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Knit = require(ReplicatedStorage.Packages.Knit)

local useEffect = React.useEffect
local useRunState = require(script.Parent.useRunState)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)

local useMemo = React.useMemo
local useRef = React.useRef
local useState = React.useState

export type TResultScreenController = {
	waveNumber: number,
	score: number,
	isRestarting: boolean,
	playAgainText: string,
	onPlayAgain: () -> (),
}

local PHASE1_SCORE = 0
local GAME_SCREEN = "Game"

local function _RequestRestartRun(): boolean
	local runContext = Knit.GetService("RunContext")
	local ok, didRestart = pcall(function()
		return runContext:RequestRestartRun()
	end)

	if not ok or not didRestart then
		warn("[ResultsScreen] Failed to request run restart")
		return false
	end

	return true
end

local function _CreatePlayAgainHandler(
	isRestartingRef: { current: boolean },
	setIsRestarting: (boolean) -> ()
): () -> ()
	return function()
		if isRestartingRef.current then
			return
		end

		setIsRestarting(true)

		local didRestart = _RequestRestartRun()
		if not didRestart then
			setIsRestarting(false)
		end
	end
end

local function useResultsScreenController(): TResultScreenController
	local runState = useRunState()
	local navigationActions = useNavigationActions()
	local isRestarting, setIsRestarting = useState(false)
	local isRestartingRef = useRef(isRestarting)

	isRestartingRef.current = isRestarting

	useEffect(function()
		if runState.state == "RunEnd" then
			return
		end

		navigationActions.reset(GAME_SCREEN)
	end, { runState.state })

	local onPlayAgain = useMemo(function()
		return _CreatePlayAgainHandler(isRestartingRef, setIsRestarting)
	end, { setIsRestarting })

	return {
		waveNumber = runState.waveNumber,
		score = PHASE1_SCORE,
		isRestarting = isRestarting,
		playAgainText = if isRestarting then "Restarting..." else "Play Again",
		onPlayAgain = onPlayAgain,
	}
end

return useResultsScreenController
