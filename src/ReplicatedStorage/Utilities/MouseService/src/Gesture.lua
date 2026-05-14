--!strict

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Enums = require(script.Parent.Enums)
local Options = require(script.Parent.Options)
local Policies = require(script.Parent.Policies)
local Types = require(script.Parent.Types)

type TMouseButton = Types.TMouseButton
type TMouseGestureButtonState = Types.TMouseGestureButtonState
type TMouseGestureEvent = Types.TMouseGestureEvent
type TMouseGestureRequest = Types.TMouseGestureRequest
type TMouseGestureSnapshot = Types.TMouseGestureSnapshot
type TResolvedMouseGestureRequest = Types.TResolvedMouseGestureRequest
type TMouseSnapshot = Types.TMouseSnapshot

type TGestureSession = {
	Request: TResolvedMouseGestureRequest,
	ButtonStates: { [string]: TMouseGestureButtonState },
	Snapshot: TMouseGestureSnapshot,
}

local Gesture = {}

local function _BuildButtonKey(mouseButton: TMouseButton): string
	return mouseButton.Name
end

local function _ResolveMouseButton(inputObject: InputObject): TMouseButton?
	if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
		return Enums.MouseButton.Left
	end

	if inputObject.UserInputType == Enum.UserInputType.MouseButton2 then
		return Enums.MouseButton.Right
	end

	return nil
end

local function _ResolveScreenPoint(inputObject: InputObject?): Vector2?
	if inputObject == nil then
		return nil
	end

	return Vector2.new(inputObject.Position.X, inputObject.Position.Y)
end

local function _IsButtonEnabled(request: TResolvedMouseGestureRequest, mouseButton: TMouseButton): boolean
	for _, enabledButton in ipairs(request.EnabledButtons) do
		if enabledButton == mouseButton then
			return true
		end
	end

	return false
end

local function _CreateButtonState(mouseButton: TMouseButton): TMouseGestureButtonState
	return {
		Button = mouseButton,
		IsPressed = false,
		PressedAt = nil,
		PressScreenPoint = nil,
		LatestScreenPoint = nil,
		HoldFired = false,
		DragThresholdReached = false,
		LastClickAt = nil,
		LastClickScreenPoint = nil,
		LastReleaseSnapshot = nil,
		LastReleaseTarget = nil,
	}
end

local function _CloneButtonState(buttonState: TMouseGestureButtonState): TMouseGestureButtonState
	return table.freeze({
		Button = buttonState.Button,
		IsPressed = buttonState.IsPressed,
		PressedAt = buttonState.PressedAt,
		PressScreenPoint = buttonState.PressScreenPoint,
		LatestScreenPoint = buttonState.LatestScreenPoint,
		HoldFired = buttonState.HoldFired,
		DragThresholdReached = buttonState.DragThresholdReached,
		LastClickAt = buttonState.LastClickAt,
		LastClickScreenPoint = buttonState.LastClickScreenPoint,
		LastReleaseSnapshot = buttonState.LastReleaseSnapshot,
		LastReleaseTarget = buttonState.LastReleaseTarget,
	})
end

local function _GetActiveButtons(buttonStates: { [string]: TMouseGestureButtonState }): { TMouseButton }
	local activeButtons = {}
	for _, buttonState in pairs(buttonStates) do
		if buttonState.IsPressed then
			activeButtons[#activeButtons + 1] = buttonState.Button
		end
	end

	table.sort(activeButtons, function(left, right)
		return left.Name < right.Name
	end)

	return table.freeze(activeButtons)
end

local function _CloneButtonStates(buttonStates: { [string]: TMouseGestureButtonState }): { [string]: TMouseGestureButtonState }
	local clonedButtonStates = {}
	for buttonKey, buttonState in pairs(buttonStates) do
		clonedButtonStates[buttonKey] = _CloneButtonState(buttonState)
	end

	return table.freeze(clonedButtonStates)
end

local function _BuildGestureSnapshot(
	channelName: string,
	buttonStates: { [string]: TMouseGestureButtonState },
	lastPressedButton: TMouseButton?,
	lastEventPhase: Types.TMouseGesturePhase?,
	lastMouseSnapshot: TMouseSnapshot?,
	lastResolvedTarget: any,
	metadata: { [string]: any }?
): TMouseGestureSnapshot
	return table.freeze({
		Channel = channelName,
		ActiveButtons = _GetActiveButtons(buttonStates),
		LastPressedButton = lastPressedButton,
		LastEventPhase = lastEventPhase,
		LastMouseSnapshot = lastMouseSnapshot,
		LastResolvedTarget = lastResolvedTarget,
		Metadata = metadata,
		ButtonStates = _CloneButtonStates(buttonStates),
	})
end

local function _BuildGestureEvent(
	channelName: string,
	mouseButton: TMouseButton,
	phase: Types.TMouseGesturePhase,
	mouseSnapshot: TMouseSnapshot,
	elapsedTime: number,
	screenDelta: Vector2,
	metadata: { [string]: any }?
): TMouseGestureEvent
	return table.freeze({
		Channel = channelName,
		Button = mouseButton,
		Phase = phase,
		MouseSnapshot = mouseSnapshot,
		ResolvedTarget = mouseSnapshot.ResolvedTarget,
		ElapsedTime = elapsedTime,
		ScreenDelta = screenDelta,
		Metadata = metadata,
	})
end

local function _GetSignal(manager: any, phase: Types.TMouseGesturePhase): any
	if phase == Enums.GesturePhase.Pressed then
		return manager.GesturePressed
	end

	if phase == Enums.GesturePhase.Released then
		return manager.GestureReleased
	end

	if phase == Enums.GesturePhase.Clicked then
		return manager.GestureClicked
	end

	if phase == Enums.GesturePhase.DoubleClicked then
		return manager.GestureDoubleClicked
	end

	if phase == Enums.GesturePhase.Held then
		return manager.GestureHeld
	end

	return manager.GestureDragThresholdReached
end

local function _ResolveMouseSnapshot(
	manager: any,
	request: TResolvedMouseGestureRequest,
	screenPoint: Vector2?
): Result.Result<TMouseSnapshot>
	return manager:ResolveSnapshot({
		ScreenPoint = screenPoint,
		CameraProvider = request.CameraProvider,
		RayLength = request.RayLength,
		ResolveTarget = request.ResolveTarget,
		QueryOptions = request.QueryOptions,
		SelectionOptions = request.SelectionOptions,
		ProjectionPlane = request.ProjectionPlane,
		BaseExclude = request.BaseExclude,
	})
end

local function _CountGestureSessions(manager: any): number
	local count = 0
	for _ in pairs(manager._gestureStateByChannel) do
		count += 1
	end

	return count
end

local function _HasAnyPressedButtons(manager: any): boolean
	for _, session in pairs(manager._gestureStateByChannel) do
		for _, buttonState in pairs(session.ButtonStates) do
			if buttonState.IsPressed then
				return true
			end
		end
	end

	return false
end

local function _StopUpdateLoop(manager: any)
	if manager._gestureUpdateConnection == nil then
		return
	end

	manager._gestureUpdateConnection:Disconnect()
	manager._gestureUpdateConnection = nil
end

local function _EmitGesture(
	manager: any,
	session: TGestureSession,
	channelName: string,
	mouseButton: TMouseButton,
	phase: Types.TMouseGesturePhase,
	mouseSnapshot: TMouseSnapshot,
	elapsedTime: number,
	screenDelta: Vector2
)
	session.Snapshot = _BuildGestureSnapshot(
		channelName,
		session.ButtonStates,
		mouseButton,
		phase,
		mouseSnapshot,
		mouseSnapshot.ResolvedTarget,
		session.Request.Metadata
	)
	manager._gestureStateByChannel[channelName] = session

	local gestureEvent = _BuildGestureEvent(
		channelName,
		mouseButton,
		phase,
		mouseSnapshot,
		elapsedTime,
		screenDelta,
		session.Request.Metadata
	)
	_GetSignal(manager, phase):Fire(channelName, gestureEvent, session.Snapshot)
end

local function _RefreshPassiveSnapshot(
	manager: any,
	session: TGestureSession,
	channelName: string,
	mouseSnapshot: TMouseSnapshot
)
	session.Snapshot = _BuildGestureSnapshot(
		channelName,
		session.ButtonStates,
		session.Snapshot.LastPressedButton,
		session.Snapshot.LastEventPhase,
		mouseSnapshot,
		mouseSnapshot.ResolvedTarget,
		session.Request.Metadata
	)
	manager._gestureStateByChannel[channelName] = session
end

local function _EnsureUpdateLoop(manager: any)
	if manager._gestureUpdateConnection ~= nil or not _HasAnyPressedButtons(manager) then
		return
	end

	manager._gestureUpdateConnection = RunService.RenderStepped:Connect(function()
		local channelNames = {}
		for channelName in pairs(manager._gestureStateByChannel) do
			channelNames[#channelNames + 1] = channelName
		end

		for _, channelName in ipairs(channelNames) do
			local session = manager._gestureStateByChannel[channelName] :: TGestureSession?
			if session == nil then
				continue
			end

			local hasPressedButtons = false
			for _, buttonState in pairs(session.ButtonStates) do
				if buttonState.IsPressed then
					hasPressedButtons = true
					break
				end
			end

			if not hasPressedButtons then
				continue
			end

			local mouseSnapshotResult = _ResolveMouseSnapshot(manager, session.Request, nil)
			if not mouseSnapshotResult.success then
				continue
			end

			local mouseSnapshot = mouseSnapshotResult.value
			local emittedEvent = false
			local now = os.clock()

			for _, buttonState in pairs(session.ButtonStates) do
				if not buttonState.IsPressed or buttonState.PressedAt == nil or buttonState.PressScreenPoint == nil then
					continue
				end

				buttonState.LatestScreenPoint = mouseSnapshot.ScreenPoint
				local elapsedTime = now - buttonState.PressedAt
				local screenDelta = mouseSnapshot.ScreenPoint - buttonState.PressScreenPoint

				if not buttonState.DragThresholdReached and screenDelta.Magnitude >= session.Request.DragStartThreshold then
					buttonState.DragThresholdReached = true
					_EmitGesture(
						manager,
						session,
						channelName,
						buttonState.Button,
						Enums.GesturePhase.DragThresholdReached,
						mouseSnapshot,
						elapsedTime,
						screenDelta
					)
					emittedEvent = true
				end

				if not buttonState.HoldFired and elapsedTime >= session.Request.HoldDuration then
					buttonState.HoldFired = true
					_EmitGesture(
						manager,
						session,
						channelName,
						buttonState.Button,
						Enums.GesturePhase.Held,
						mouseSnapshot,
						elapsedTime,
						screenDelta
					)
					emittedEvent = true
				end
			end

			if not emittedEvent then
				_RefreshPassiveSnapshot(manager, session, channelName, mouseSnapshot)
			end
		end

		if not _HasAnyPressedButtons(manager) then
			_StopUpdateLoop(manager)
		end
	end)
end

local function _StopInputBindings(manager: any)
	if manager._gestureInputBeganConnection ~= nil then
		manager._gestureInputBeganConnection:Disconnect()
		manager._gestureInputBeganConnection = nil
	end

	if manager._gestureInputEndedConnection ~= nil then
		manager._gestureInputEndedConnection:Disconnect()
		manager._gestureInputEndedConnection = nil
	end

	_StopUpdateLoop(manager)
end

local function _HandleInputBegan(manager: any, inputObject: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	local mouseButton = _ResolveMouseButton(inputObject)
	if mouseButton == nil then
		return
	end

	local channelNames = {}
	for channelName in pairs(manager._gestureStateByChannel) do
		channelNames[#channelNames + 1] = channelName
	end

	for _, channelName in ipairs(channelNames) do
		local session = manager._gestureStateByChannel[channelName] :: TGestureSession?
		if session == nil or not _IsButtonEnabled(session.Request, mouseButton) then
			continue
		end

		local buttonKey = _BuildButtonKey(mouseButton)
		local buttonState = session.ButtonStates[buttonKey]
		if buttonState == nil then
			buttonState = _CreateButtonState(mouseButton)
			session.ButtonStates[buttonKey] = buttonState
		end

		if buttonState.IsPressed then
			continue
		end

		local screenPoint = _ResolveScreenPoint(inputObject)
		local mouseSnapshotResult = _ResolveMouseSnapshot(manager, session.Request, screenPoint)
		if not mouseSnapshotResult.success then
			continue
		end

		local mouseSnapshot = mouseSnapshotResult.value
		buttonState.IsPressed = true
		buttonState.PressedAt = os.clock()
		buttonState.PressScreenPoint = mouseSnapshot.ScreenPoint
		buttonState.LatestScreenPoint = mouseSnapshot.ScreenPoint
		buttonState.HoldFired = false
		buttonState.DragThresholdReached = false

		_EmitGesture(
			manager,
			session,
			channelName,
			mouseButton,
			Enums.GesturePhase.Pressed,
			mouseSnapshot,
			0,
			Vector2.zero
		)
	end

	_EnsureUpdateLoop(manager)
end

local function _HandleInputEnded(manager: any, inputObject: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	local mouseButton = _ResolveMouseButton(inputObject)
	if mouseButton == nil then
		return
	end

	local channelNames = {}
	for channelName in pairs(manager._gestureStateByChannel) do
		channelNames[#channelNames + 1] = channelName
	end

	for _, channelName in ipairs(channelNames) do
		local session = manager._gestureStateByChannel[channelName] :: TGestureSession?
		if session == nil then
			continue
		end

		local buttonState = session.ButtonStates[_BuildButtonKey(mouseButton)]
		if buttonState == nil or not buttonState.IsPressed or buttonState.PressedAt == nil or buttonState.PressScreenPoint == nil then
			continue
		end

		local screenPoint = _ResolveScreenPoint(inputObject)
		local mouseSnapshotResult = _ResolveMouseSnapshot(manager, session.Request, screenPoint)
		if not mouseSnapshotResult.success then
			continue
		end

		local mouseSnapshot = mouseSnapshotResult.value
		local elapsedTime = os.clock() - buttonState.PressedAt
		local screenDelta = mouseSnapshot.ScreenPoint - buttonState.PressScreenPoint

		buttonState.IsPressed = false
		buttonState.LatestScreenPoint = mouseSnapshot.ScreenPoint
		buttonState.LastReleaseSnapshot = mouseSnapshot
		buttonState.LastReleaseTarget = mouseSnapshot.ResolvedTarget

		_EmitGesture(
			manager,
			session,
			channelName,
			mouseButton,
			Enums.GesturePhase.Released,
			mouseSnapshot,
			elapsedTime,
			screenDelta
		)

		local canClick = not buttonState.HoldFired
			and not buttonState.DragThresholdReached
			and screenDelta.Magnitude <= session.Request.ClickMaxMovement

		if canClick then
			local isDoubleClick = buttonState.LastClickAt ~= nil
				and buttonState.LastClickScreenPoint ~= nil
				and (os.clock() - buttonState.LastClickAt) <= session.Request.DoubleClickWindow
				and (mouseSnapshot.ScreenPoint - buttonState.LastClickScreenPoint).Magnitude
					<= session.Request.DoubleClickMaxMovement

			buttonState.LastClickAt = os.clock()
			buttonState.LastClickScreenPoint = mouseSnapshot.ScreenPoint

			_EmitGesture(
				manager,
				session,
				channelName,
				mouseButton,
				Enums.GesturePhase.Clicked,
				mouseSnapshot,
				elapsedTime,
				screenDelta
			)

			if isDoubleClick then
				_EmitGesture(
					manager,
					session,
					channelName,
					mouseButton,
					Enums.GesturePhase.DoubleClicked,
					mouseSnapshot,
					elapsedTime,
					screenDelta
				)
			end
		end

		buttonState.PressedAt = nil
		buttonState.PressScreenPoint = nil
		buttonState.LatestScreenPoint = nil
		buttonState.HoldFired = false
		buttonState.DragThresholdReached = false
	end

	if not _HasAnyPressedButtons(manager) then
		_StopUpdateLoop(manager)
	end
end

local function _EnsureInputBindings(manager: any)
	if manager._gestureInputBeganConnection == nil then
		manager._gestureInputBeganConnection = UserInputService.InputBegan:Connect(function(inputObject, gameProcessedEvent)
			_HandleInputBegan(manager, inputObject, gameProcessedEvent)
		end)
	end

	if manager._gestureInputEndedConnection == nil then
		manager._gestureInputEndedConnection = UserInputService.InputEnded:Connect(function(inputObject, gameProcessedEvent)
			_HandleInputEnded(manager, inputObject, gameProcessedEvent)
		end)
	end
end

local function _CreateInitialButtonStates(request: TResolvedMouseGestureRequest): { [string]: TMouseGestureButtonState }
	local buttonStates = {}
	for _, mouseButton in ipairs(request.EnabledButtons) do
		buttonStates[_BuildButtonKey(mouseButton)] = _CreateButtonState(mouseButton)
	end

	return buttonStates
end

function Gesture.BeginGesture(
	manager: any,
	channelName: string,
	request: TMouseGestureRequest?
): Result.Result<TMouseGestureSnapshot>
	local transitionResult = Policies.CheckGestureTransition(channelName, manager._gestureStateByChannel[channelName], "Begin")
	if not transitionResult.success then
		return transitionResult
	end

	local requestResult = Policies.CheckGestureRequest(request)
	if not requestResult.success then
		return requestResult
	end

	local resolvedRequest = Options.ResolveGestureRequest(manager._config, request)
	local buttonStates = _CreateInitialButtonStates(resolvedRequest)
	local snapshot = _BuildGestureSnapshot(channelName, buttonStates, nil, nil, nil, nil, resolvedRequest.Metadata)
	manager._gestureStateByChannel[channelName] = {
		Request = resolvedRequest,
		ButtonStates = buttonStates,
		Snapshot = snapshot,
	}
	_EnsureInputBindings(manager)
	return Result.Ok(snapshot)
end

function Gesture.EndGesture(manager: any, channelName: string): Result.Result<TMouseGestureSnapshot?>
	local transitionResult = Policies.CheckGestureTransition(channelName, manager._gestureStateByChannel[channelName], "End")
	if not transitionResult.success then
		return transitionResult
	end

	local session = manager._gestureStateByChannel[channelName] :: TGestureSession
	local previousSnapshot = session.Snapshot
	manager._gestureStateByChannel[channelName] = nil

	if _CountGestureSessions(manager) == 0 then
		_StopInputBindings(manager)
	elseif not _HasAnyPressedButtons(manager) then
		_StopUpdateLoop(manager)
	end

	return Result.Ok(previousSnapshot)
end

function Gesture.ClearAllGestures(manager: any)
	table.clear(manager._gestureStateByChannel)
	_StopInputBindings(manager)
end

return table.freeze(Gesture)
