--!native
--!strict
--[[
    =========  SERVICES  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit
]]
local RunService = game:GetService("RunService")

--[[
    =========  MODULES  =========
]]
local Types = require(script.Parent.Types)

--[[
    =========  TYPES  =========
]]
type Animation = Types.Animation

--[[
    =========  CONSTANTS  =========
]]
local GENERATE_ID_LENGTH = 8
local GENERATE_ID_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

--[[
    =========  VARIABLES  =========
]]
local guiObjectState = setmetatable({}, { __mode = "k" }) -- [guiObject] = { [animationName] = Animation }

local activeAnimations: { [string]: Animation } = {}
local animationCount = 0
local random = Random.new()
local connection: RBXScriptConnection? = nil
local Check = require(script.Parent.Parent.Utils.Check)
local assertArg = Check._assertArg

local function startLoop()
    if connection then return end
    
    connection = RunService.RenderStepped:Connect(function(dt: number)
        local toComplete: { Animation } = {}
        
        for id, animation in activeAnimations do
            if animation.state == "paused" then continue end
            
            local completed = animation:step(dt)
            
            if completed then
                animation.state = "completed"
                activeAnimations[id] = nil
                animationCount -= 1
                table.insert(toComplete, animation)
            end
        end
        
        for _, animation in toComplete do
            animation:_fireComplete()
        end
        
        if animationCount == 0 then
            if connection then
                connection:Disconnect()
                connection = nil
            end
        end
    end)
end

--[[
    =========  MAIN MODULE  =========
]]
local Scheduler = {}

function Scheduler._generateId(): string
    local chars = table.create(GENERATE_ID_LENGTH)
    for i = 1, GENERATE_ID_LENGTH do
        local index = random:NextInteger(1, #GENERATE_ID_CHARS)
        chars[i] = string.sub(GENERATE_ID_CHARS, index, index)
    end
    return table.concat(chars)
end

function Scheduler._add(animation: Animation)
    assertArg(animation, "animation", "table")
    if not animation.id then
        error("Animation must have an id", 2)
    end
    
    
    local target = animation.targetObject
    local animType = animation.animationType
    if target and animType then
        if guiObjectState[target] and guiObjectState[target][animType] then
            local oldAnimation = guiObjectState[target][animType]
            if oldAnimation and oldAnimation.id ~= animation.id then
                Scheduler._stop(oldAnimation)
            end
        end
        
        if not guiObjectState[target] then
            guiObjectState[target] = {}
        end
        guiObjectState[target][animType] = animation
    end
    
    activeAnimations[animation.id] = animation
    animation.state = "playing"
    animationCount += 1
    
    startLoop()
end

function Scheduler._remove(animation: Animation)
    assertArg(animation, "animation", "table")
    if not activeAnimations[animation.id] then return end
    
    activeAnimations[animation.id] = nil
    animationCount -= 1
    
    local target = animation.targetObject
    local animType = animation.animationType
    if target and animType and guiObjectState[target] then
        if guiObjectState[target][animType] == animation then
             guiObjectState[target][animType] = nil
        end
        if next(guiObjectState[target]) == nil then
             guiObjectState[target] = nil
        end
    end

    animation:_fireInterrupt()
end

function Scheduler._pause(animation: Animation)
    assertArg(animation, "animation", "table")
    if activeAnimations[animation.id] then
        animation.state = "paused"
    end
end

function Scheduler._resume(animation: Animation)
    assertArg(animation, "animation", "table")
    if activeAnimations[animation.id] then
        animation.state = "playing"
    end
end

function Scheduler._stop(animation: Animation)
    assertArg(animation, "animation", "table")
    if not activeAnimations[animation.id] then return end
    
    animation.state = "stopped"
    activeAnimations[animation.id] = nil
    animationCount -= 1
    
    local target = animation.targetObject
    local animType = animation.animationType
    if target and animType and guiObjectState[target] then
        if guiObjectState[target][animType] == animation then
             guiObjectState[target][animType] = nil
        end
        if next(guiObjectState[target]) == nil then
             guiObjectState[target] = nil
        end
    end

    animation:_fireInterrupt()
end

return table.freeze(Scheduler)

