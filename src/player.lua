-- Player.lua - Player controller with smooth movement and collision
-- Handles player state, movement, camera, and physics

local Player = {}
Player.__index = Player

-- Constants
local MOVE_SPEED = 3.0
local RUN_SPEED_MULTIPLIER = 1.5
local ROTATION_SPEED = 2.0  -- Radians per second
local PLAYER_RADIUS = 0.2
local PLAYER_HEIGHT = 1.6

function Player:new(startX, startY, startAngle)
    local self = setmetatable({}, Player)
    
    -- Position and orientation
    self.x = startX
    self.y = startY
    self.angle = startAngle
    self.height = PLAYER_HEIGHT
    
    -- Movement state
    self.velocityX = 0
    self.velocityY = 0
    self.isMoving = false
    
    -- Physics
    self.onGround = true
    self.gravity = -20.0  -- Negative for downward gravity
    self.jumpVelocity = 8.0
    self.verticalVelocity = 0
    
    -- Camera shake for weapon feedback
    self.cameraShakeX = 0
    self.cameraShakeY = 0
    self.shakeDecay = 0.9
    
    return self
end

function Player:update(dt, map, input)
    -- Handle mouse look with rotation speed
    local mouseX, mouseY = input:getMouseLookDelta()
    self.angle = self.angle + mouseX * ROTATION_SPEED
    self.height = math.max(0.5, math.min(2.5, self.height - mouseY * 2.0))
    
    -- Normalize angle
    while self.angle < 0 do self.angle = self.angle + math.pi * 2 end
    while self.angle >= math.pi * 2 do self.angle = self.angle - math.pi * 2 end
    
    -- Get movement input
    local moveX, moveY = input:getMovementVector()
    local isRunning = input:isRunning()
    
    -- Calculate movement speed
    local speed = MOVE_SPEED
    if isRunning then
        speed = speed * RUN_SPEED_MULTIPLIER
    end
    
    -- Calculate forward and right vectors
    local forwardX = math.cos(self.angle)
    local forwardY = math.sin(self.angle)
    local rightX = math.cos(self.angle + math.pi/2)
    local rightY = math.sin(self.angle + math.pi/2)
    
    -- Calculate desired velocity (fixed movement direction)
    local desiredVelX = (forwardX * -moveY + rightX * moveX) * speed
    local desiredVelY = (forwardY * -moveY + rightY * moveX) * speed
    
    -- Smooth velocity changes
    local accel = 15.0  -- Acceleration rate
    self.velocityX = self.velocityX + (desiredVelX - self.velocityX) * accel * dt
    self.velocityY = self.velocityY + (desiredVelY - self.velocityY) * accel * dt
    
    -- Handle jumping
    if input:isJumping() and self.onGround then
        self.verticalVelocity = self.jumpVelocity
        self.onGround = false
    end
    
    -- Apply gravity
    if not self.onGround then
        self.verticalVelocity = self.verticalVelocity + self.gravity * dt
    end
    
    -- Move player with collision detection
    self:moveWithCollision(dt, map)
    
    -- Update camera shake
    self.cameraShakeX = self.cameraShakeX * self.shakeDecay
    self.cameraShakeY = self.cameraShakeY * self.shakeDecay
    
    -- Update movement state
    self.isMoving = math.abs(moveX) > 0.1 or math.abs(moveY) > 0.1
end

function Player:moveWithCollision(dt, map)
    -- Calculate new position
    local newX = self.x + self.velocityX * dt
    local newY = self.y + self.velocityY * dt
    
    -- Check horizontal collision (no sliding - just stop)
    if not map:checkRectCollision(newX, self.y, PLAYER_RADIUS) then
        self.x = newX
    else
        self.velocityX = 0
    end
    
    -- Check vertical collision (no sliding - just stop)
    if not map:checkRectCollision(self.x, newY, PLAYER_RADIUS) then
        self.y = newY
    else
        self.velocityY = 0
    end
    
    -- Apply vertical movement (jumping/falling) - only if not controlled by mouse
    if self.verticalVelocity ~= 0 then
        local newHeight = self.height + self.verticalVelocity * dt
        
        -- Ground collision - only when falling due to gravity
        if newHeight <= PLAYER_HEIGHT and self.verticalVelocity < 0 then
            newHeight = PLAYER_HEIGHT
            self.verticalVelocity = 0
            self.onGround = true
        else
            self.onGround = false
        end
        
        self.height = newHeight
    else
        -- If not jumping/falling, allow mouse control of height without ground collision
        self.onGround = true
    end
end

-- Add camera shake for weapon feedback
function Player:addCameraShake(intensity)
    self.cameraShakeX = self.cameraShakeX + (math.random() - 0.5) * intensity
    self.cameraShakeY = self.cameraShakeY + (math.random() - 0.5) * intensity
end

-- Get player's view data for rendering
function Player:getViewData()
    return {
        x = self.x,
        y = self.y,
        angle = self.angle,
        height = self.height,
        shakeX = self.cameraShakeX,
        shakeY = self.cameraShakeY
    }
end

-- Get player's position
function Player:getPosition()
    return self.x, self.y
end

-- Get player's angle
function Player:getAngle()
    return self.angle
end

-- Check if player is moving
function Player:isMoving()
    return self.isMoving
end

-- Get player's forward direction vector
function Player:getForwardVector()
    return math.cos(self.angle), math.sin(self.angle)
end

-- Get distance to another entity
function Player:getDistanceTo(x, y)
    local dx = self.x - x
    local dy = self.y - y
    return math.sqrt(dx * dx + dy * dy)
end

-- Check if player can see a point (basic line-of-sight)
function Player:canSee(x, y, map)
    local dx = x - self.x
    local dy = y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 15 then  -- Max visibility range
        return false
    end
    
    -- Simple line-of-sight check
    local steps = math.floor(distance * 10)
    for i = 1, steps do
        local t = i / steps
        local checkX = self.x + dx * t
        local checkY = self.y + dy * t
        
        if map:checkCollision(checkX, checkY) then
            return false
        end
    end
    
    return true
end

-- Take damage from enemies
function Player:takeDamage(damage)
    self.health = (self.health or 100) - damage
    if self.health <= 0 then
        self.health = 0
        print("Player died!")
        -- Could add game over logic here
    else
        print("Player took " .. damage .. " damage! Health: " .. self.health)
    end
end

return Player
