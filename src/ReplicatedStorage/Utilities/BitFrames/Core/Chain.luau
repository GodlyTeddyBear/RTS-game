--!strict
--[[
    =========  CHAIN  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

    Method chaining system for sequencing animations.
]]

--[[
    =========  MODULES  =========
]]
local Types = require(script.Parent.Types)

--[[
    =========  TYPES  =========
]]
type QueuedEffect = { effectFn: () -> Types.EffectController, duration: number }

export type ChainClassImpl = {
    _instance: GuiObject,
    _queue: { QueuedEffect },
    _isPlaying: boolean,
    _currentController: Types.EffectController?,
    _delayThread: thread?,
    _addEffect: (self: ChainClassImpl, effectFn: () -> Types.EffectController, duration: number) -> ChainClassImpl,
    delay: (self: ChainClassImpl, seconds: number) -> ChainClassImpl,
    play: (self: ChainClassImpl, onComplete: (() -> ())?) -> Types.EffectController,
    stop: (self: ChainClassImpl) -> (),
}

--[[
    =========  CHAIN CLASS  =========
]]
local ChainClass = {} :: ChainClassImpl & { __index: ChainClassImpl, _new: (instance: GuiObject) -> ChainClassImpl }
ChainClass.__index = ChainClass :: ChainClassImpl

function ChainClass._new(instance: GuiObject): ChainClassImpl
    local self = setmetatable({
        _instance = instance,
        _queue = {} :: { QueuedEffect },
        _isPlaying = false,
        _currentController = nil :: Types.EffectController?,
        _delayThread = nil :: thread?,
    }, ChainClass :: any)
    return self :: ChainClassImpl
end

function ChainClass._addEffect(self: ChainClassImpl, effectFn: () -> Types.EffectController, duration: number): ChainClassImpl
    table.insert(self._queue, { effectFn = effectFn, duration = duration })
    return self
end

function ChainClass.delay(self: ChainClassImpl, seconds: number): ChainClassImpl
    return self:_addEffect(function()
        return { stop = function() end, pause = function() end, resume = function() end }
    end, seconds)
end

function ChainClass.play(self: ChainClassImpl, onComplete: (() -> ())?): Types.EffectController
    local function stopChain()
        self._isPlaying = false
        if self._currentController then
            self._currentController.stop()
            self._currentController = nil
        end
        table.clear(self._queue)
    end

    if self._isPlaying then
        return { stop = stopChain, pause = function() end, resume = function() end }
    end

    self._isPlaying = true
    local queueCopy = table.clone(self._queue)
    local currentIndex = 0
    local stopped = false

    local controller: Types.EffectController = {
        stop = function()
            stopped = true
            self._isPlaying = false
            if self._delayThread then
                task.cancel(self._delayThread)
                self._delayThread = nil
            end
            if self._currentController then self._currentController.stop() end
        end,
        pause = function()
            if self._currentController then self._currentController.pause() end
        end,
        resume = function()
            if self._currentController then self._currentController.resume() end
        end,
    }

    local function playNext()
        if stopped then return end
        currentIndex += 1
        if currentIndex > #queueCopy then
            self._isPlaying = false
            self._currentController = nil
            if onComplete then onComplete() end
            return
        end
        local effect = queueCopy[currentIndex]
        self._currentController = effect.effectFn()
        self._delayThread = task.delay(effect.duration, playNext)
    end

    task.spawn(playNext)
    return controller
end

function ChainClass.stop(self: ChainClassImpl)
    self._isPlaying = false
    if self._delayThread then
        task.cancel(self._delayThread)
        self._delayThread = nil
    end
    if self._currentController then
        self._currentController.stop()
        self._currentController = nil
    end
    table.clear(self._queue)
end

return ChainClass
