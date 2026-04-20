local UIEvent = {}

--[[
    =========  TYPES  =========
]]

export type BindConfig = {
    guiObject: GuiObject,
    callback: () -> (),
    debounce: number?,
}

export type TooltipConfig = {
    guiObject: GuiObject,
    onEnter: () -> (),
    onLeave: (() -> ())?,
    debounce: number?,
}

--[[
    =========  VARIABLE  =========
]]

local debounceStates: { [GuiObject]: { [string]: boolean } } = {}

--[[
    =========  HELPER FUNCTION  =========
]]

local function getDebounceState(guiObject: GuiObject, eventName: string): boolean
    if not debounceStates[guiObject] then
        debounceStates[guiObject] = {}
    end
    return debounceStates[guiObject][eventName] or false
end

local function setDebounceState(guiObject: GuiObject, eventName: string, state: boolean)
    if not debounceStates[guiObject] then
        debounceStates[guiObject] = {}
    end
    debounceStates[guiObject][eventName] = state
end

local function wrapWithDebounce(guiObject: GuiObject, eventName: string, callback: () -> (), debounceTime: number?): () -> ()
    if not debounceTime or debounceTime <= 0 then
        return callback
    end

    return function()
        if getDebounceState(guiObject, eventName) then
            return
        end
        setDebounceState(guiObject, eventName, true)
        callback()
        task.delay(debounceTime, function()
            setDebounceState(guiObject, eventName, false)
        end)
    end
end

--[[
    =========  PUBLIC FUNCTION  =========
]]

function UIEvent.BindClick(config: BindConfig): RBXScriptConnection
    local wrappedCallback = wrapWithDebounce(config.guiObject, "Click", config.callback, config.debounce)
    return (config.guiObject :: GuiButton).Activated:Connect(wrappedCallback)
end

function UIEvent.BindEnter(config: BindConfig): RBXScriptConnection
    local wrappedCallback = wrapWithDebounce(config.guiObject, "Enter", config.callback, config.debounce)
    return config.guiObject.MouseEnter:Connect(wrappedCallback)
end

function UIEvent.BindLeave(config: BindConfig): RBXScriptConnection
    local wrappedCallback = wrapWithDebounce(config.guiObject, "Leave", config.callback, config.debounce)
    return config.guiObject.MouseLeave:Connect(wrappedCallback)
end

function UIEvent.BindPressDown(config: BindConfig): RBXScriptConnection
    local wrappedCallback = wrapWithDebounce(config.guiObject, "PressDown", config.callback, config.debounce)
    return config.guiObject.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            wrappedCallback()
        end
    end)
end

function UIEvent.BindPressUp(config: BindConfig): RBXScriptConnection
    local wrappedCallback = wrapWithDebounce(config.guiObject, "PressUp", config.callback, config.debounce)
    return config.guiObject.InputEnded:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            wrappedCallback()
        end
    end)
end

function UIEvent.BindTooltip(config: TooltipConfig): { enter: RBXScriptConnection, leave: RBXScriptConnection? }
    local wrappedEnter = wrapWithDebounce(config.guiObject, "TooltipEnter", config.onEnter, config.debounce)
    local connections: { enter: RBXScriptConnection, leave: RBXScriptConnection? } = {
        enter = config.guiObject.MouseEnter:Connect(wrappedEnter),
        leave = nil,
    }

    if config.onLeave then
        local wrappedLeave = wrapWithDebounce(config.guiObject, "TooltipLeave", config.onLeave, config.debounce)
        connections.leave = config.guiObject.MouseLeave:Connect(wrappedLeave)
    end 

    return connections
end

return UIEvent