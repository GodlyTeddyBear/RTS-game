--!strict
--[[
    =========  TRANSFORM UTILITIES  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

    Helper functions for pre-made effects that work on any UI element.
]]

--[[
    =========  MODULES  =========
]]
local Check = require(script.Parent.Check)

local assertArg = Check._assertArg

--[[
    =========  MAIN MODULE  =========
]]
local Transform = {}

local OriginalStates = setmetatable({}, { __mode = "k" })

function Transform._prepareAnimation(element: GuiObject, needsUIScale: boolean?)
    assertArg(element, "element", "Instance")
    
    if needsUIScale then
        Transform._removeUIScale(element)
    end
    Transform._clearState(element)
    Transform._saveState(element)
end

function Transform._saveState(element: GuiObject)
    assertArg(element, "element", "Instance")
    
    if OriginalStates[element] then return end
    
    local state = {
        Position = element.Position,
        Size = element.Size,
        Rotation = element.Rotation,
        AnchorPoint = element.AnchorPoint,
        BackgroundTransparency = element.BackgroundTransparency,
        ZIndex = element.ZIndex,
    }
    
    if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
        state.TextTransparency = element.TextTransparency
        state.TextColor3 = element.TextColor3
        state.Text = element.Text
    end
    
    if element:IsA("ImageLabel") or element:IsA("ImageButton") then
        state.ImageTransparency = element.ImageTransparency
        state.ImageColor3 = element.ImageColor3
    end
    
    if element:IsA("CanvasGroup") then
        state.GroupTransparency = element.GroupTransparency
    end
    
    OriginalStates[element] = state
end

function Transform._getOriginal(element: GuiObject): {[string]: any}
    if not OriginalStates[element] then
        Transform._saveState(element)
    end
    return OriginalStates[element]
end

function Transform._restoreState(element: GuiObject)
    local state = OriginalStates[element]
    if not state then return end
    
    element.Position = state.Position
    element.Size = state.Size
    element.Rotation = state.Rotation
    element.AnchorPoint = state.AnchorPoint
    element.BackgroundTransparency = state.BackgroundTransparency
    element.ZIndex = state.ZIndex
    
    if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
        if state.TextTransparency then (element :: any).TextTransparency = state.TextTransparency end
        if state.TextColor3 then (element :: any).TextColor3 = state.TextColor3 end
        if state.Text then (element :: any).Text = state.Text end
    end
    
    if element:IsA("ImageLabel") or element:IsA("ImageButton") then
        if state.ImageTransparency then (element :: any).ImageTransparency = state.ImageTransparency end
        if state.ImageColor3 then (element :: any).ImageColor3 = state.ImageColor3 end
    end
    
    if element:IsA("CanvasGroup") and state.GroupTransparency then
        element.GroupTransparency = state.GroupTransparency
    end
end

function Transform._getUIScale(element: GuiObject): UIScale
    assertArg(element, "element", "Instance")
    
    local existing = element:FindFirstChild("_BitFramesScale")
    if existing and existing:IsA("UIScale") then
        return existing :: UIScale
    end
    
    local uiScale = Instance.new("UIScale")
    uiScale.Name = "_BitFramesScale"
    uiScale.Parent = element
    return uiScale
end

function Transform._removeUIScale(element: GuiObject)
    local existing = element:FindFirstChild("_BitFramesScale")
    if existing then
        existing:Destroy()
    end
end

function Transform._clearState(element: GuiObject)
    OriginalStates[element] = nil
end

return table.freeze(Transform)
