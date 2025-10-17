-- Input.lua - Input handling with delta time smoothing
-- Manages keyboard and mouse input for FPS controls

local Input = {}
Input.__index = Input

-- Constants
local MOUSE_SENSITIVITY_X = 0.002
local MOUSE_SENSITIVITY_Y = 0.003  -- Slightly higher for vertical
local KEY_REPEAT_DELAY = 0.2  -- Seconds before key repeat starts

function Input:new()
    local self = setmetatable({}, Input)
    
    -- Mouse state
    self.mouseDeltaX = 0
    self.mouseDeltaY = 0
    self.mouseLookEnabled = true
    
    -- Keyboard state
    self.keysDown = {}
    self.keysPressed = {}
    self.lastKeyPress = {}
    
    -- Movement state
    self.moveForward = false
    self.moveBackward = false
    self.moveLeft = false
    self.moveRight = false
    
    return self
end

function Input:update()
    -- Clear single-frame key presses at the END of update, not the beginning
    -- This allows them to be checked during the update cycle
    
    -- Update movement keys (WASD + Arrow keys)
    self.moveForward = love.keyboard.isDown("w") or love.keyboard.isDown("up")
    self.moveBackward = love.keyboard.isDown("s") or love.keyboard.isDown("down")
    self.moveLeft = love.keyboard.isDown("a") or love.keyboard.isDown("left")
    self.moveRight = love.keyboard.isDown("d") or love.keyboard.isDown("right")
    
    -- Update key down state
    self.keysDown = {
        w = self.moveForward,
        s = self.moveBackward,
        a = self.moveLeft,
        d = self.moveRight,
        space = love.keyboard.isDown("space"),
        shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift"),
        f3 = love.keyboard.isDown("f3")
    }
    
    -- Handle mouse sensitivity smoothing
    self.mouseDeltaX = self.mouseDeltaX * 0.8  -- Dampen mouse movement
    self.mouseDeltaY = self.mouseDeltaY * 0.8
end

function Input:endUpdate()
    -- Clear single-frame key presses at the END of update cycle
    self.keysPressed = {}
end

function Input:onMouseMoved(dx, dy)
    if self.mouseLookEnabled then
        self.mouseDeltaX = self.mouseDeltaX + dx * MOUSE_SENSITIVITY_X
        self.mouseDeltaY = self.mouseDeltaY + dy * MOUSE_SENSITIVITY_Y
    end
end

function Input:onKeyPressed(key)
    self.keysPressed[key] = true
    self.keysDown[key] = true
    self.lastKeyPress[key] = love.timer.getTime()
    
    -- Debug output for F3 key
    if key == "f3" or key == "F3" then
        if DEBUG then print("F3 key pressed: " .. key) end
    end
end

-- Check if key should repeat (for continuous actions)
function Input:shouldKeyRepeat(key)
    if not self:isKeyDown(key) then
        return false
    end
    
    local lastPress = self.lastKeyPress[key]
    if not lastPress then
        return true  -- First press
    end
    
    local currentTime = love.timer.getTime()
    return (currentTime - lastPress) >= KEY_REPEAT_DELAY
end

function Input:onKeyReleased(key)
    self.keysDown[key] = false
end

-- Get mouse look delta
function Input:getMouseLookDelta()
    local deltaX = self.mouseDeltaX
    local deltaY = self.mouseDeltaY
    
    -- Reset deltas after reading
    self.mouseDeltaX = 0
    self.mouseDeltaY = 0
    
    return deltaX, deltaY
end

-- Check if a key was just pressed this frame
function Input:isKeyPressed(key)
    return self.keysPressed[key] == true
end

-- Check if a key is currently held down
function Input:isKeyDown(key)
    return self.keysDown[key] == true
end

-- Get movement vector based on current input
function Input:getMovementVector()
    local moveX = 0
    local moveY = 0
    
    if self.moveForward then moveY = moveY - 1 end
    if self.moveBackward then moveY = moveY + 1 end
    if self.moveLeft then moveX = moveX - 1 end
    if self.moveRight then moveX = moveX + 1 end
    
    -- Normalize diagonal movement
    if moveX ~= 0 and moveY ~= 0 then
        local length = math.sqrt(moveX * moveX + moveY * moveY)
        moveX = moveX / length
        moveY = moveY / length
    end
    
    return moveX, moveY
end

-- Check if player is running (shift held)
function Input:isRunning()
    return self:isKeyDown("shift")
end

-- Check if player wants to jump (space pressed)
function Input:isJumping()
    return self:isKeyPressed("space")
end

-- Enable/disable mouse look
function Input:setMouseLookEnabled(enabled)
    self.mouseLookEnabled = enabled
    if enabled then
        love.mouse.setRelativeMode(true)
        love.mouse.setGrabbed(true)
    else
        love.mouse.setRelativeMode(false)
        love.mouse.setGrabbed(false)
    end
end

-- Get mouse button states
function Input:isMouseButtonDown(button)
    return love.mouse.isDown(button)
end

function Input:isMouseButtonPressed(button)
    -- This would need to be tracked frame by frame
    -- For now, just return current state
    return love.mouse.isDown(button)
end

return Input
