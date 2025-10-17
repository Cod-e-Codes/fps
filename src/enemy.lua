-- Enemy.lua - Enemy entity with billboard rendering and basic chase AI
-- Handles enemy state, AI behavior, and collision

local Enemy = {}
Enemy.__index = Enemy

-- Constants
local ENEMY_SPEED = 1.5
local ENEMY_DETECTION_RANGE = 8.0
local ENEMY_ATTACK_RANGE = 1.5
local ENEMY_ATTACK_DAMAGE = 10
local ENEMY_ATTACK_COOLDOWN = 1.0
local ENEMY_HEALTH = 100
local ENEMY_RADIUS = 0.3

-- Enemy states
local STATE_IDLE = "idle"
local STATE_CHASE = "chase"
local STATE_ATTACK = "attack"
local STATE_DEAD = "dead"

function Enemy:new(startX, startY, player)
    local self = setmetatable({}, Enemy)
    
    -- Position and state
    self.x = startX
    self.y = startY
    self.state = STATE_IDLE
    self.player = player
    
    -- Health
    self.health = ENEMY_HEALTH
    self.maxHealth = ENEMY_HEALTH
    
    -- AI state
    self.lastAttackTime = 0
    self.targetX = startX
    self.targetY = startY
    
    -- Movement
    self.velocityX = 0
    self.velocityY = 0
    
    -- Animation
    self.animationTime = 0
    
    return self
end

function Enemy:update(dt, map, player)
    -- Update player reference
    self.player = player
    self.animationTime = self.animationTime + dt
    
    -- Skip update if dead
    if self.state == STATE_DEAD then
        return
    end
    
    -- Calculate distance to player
    local distanceToPlayer = self:getDistanceToPlayer()
    
    -- State machine
    local oldState = self.state
    if distanceToPlayer <= ENEMY_ATTACK_RANGE then
        self.state = STATE_ATTACK
        self:handleAttack(dt)
    elseif distanceToPlayer <= ENEMY_DETECTION_RANGE and self:canSeePlayer(map) then
        self.state = STATE_CHASE
        self:handleChase(dt, map)
    else
        self.state = STATE_IDLE
        self:handleIdle(dt)
    end
    
    -- Debug output for enemy movement
    if oldState ~= self.state then
        print("Enemy at (" .. string.format("%.2f", self.x) .. ", " .. string.format("%.2f", self.y) .. ") changed state from " .. oldState .. " to " .. self.state)
    end
    
    -- Apply movement
    self:moveWithCollision(dt, map)
end

-- Handle idle state
function Enemy:handleIdle(dt)
    -- Simple wandering behavior
    self.velocityX = self.velocityX * 0.9
    self.velocityY = self.velocityY * 0.9
    
    -- Occasionally move in random direction
    if math.random() < 0.01 then  -- 1% chance per frame
        local angle = math.random() * math.pi * 2
        self.velocityX = math.cos(angle) * 0.5
        self.velocityY = math.sin(angle) * 0.5
    end
end

-- Handle chase state
function Enemy:handleChase(dt, map)
    local playerX, playerY = self.player:getPosition()
    
    -- Calculate direction to player
    local dx = playerX - self.x
    local dy = playerY - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0.1 then
        -- Normalize direction
        dx = dx / distance
        dy = dy / distance
        
        -- Set velocity towards player
        self.velocityX = dx * ENEMY_SPEED
        self.velocityY = dy * ENEMY_SPEED
        
    else
        self.velocityX = 0
        self.velocityY = 0
    end
end

-- Handle attack state
function Enemy:handleAttack(dt)
    -- Stop moving when attacking
    self.velocityX = self.velocityX * 0.8
    self.velocityY = self.velocityY * 0.8
    
    -- Attack player if cooldown is ready
    local currentTime = love.timer.getTime()
    if currentTime - self.lastAttackTime >= ENEMY_ATTACK_COOLDOWN then
        self:attackPlayer()
        self.lastAttackTime = currentTime
    end
end

-- Attack the player
function Enemy:attackPlayer()
    -- Deal damage to player
    if self.player.takeDamage then
        self.player:takeDamage(ENEMY_ATTACK_DAMAGE)
        print("Enemy attacked player for " .. ENEMY_ATTACK_DAMAGE .. " damage!")
    end
end

-- Move enemy with collision detection
function Enemy:moveWithCollision(dt, map)
    local newX = self.x + self.velocityX * dt
    local newY = self.y + self.velocityY * dt
    
    -- Check horizontal collision
    if not map:checkRectCollision(newX, self.y, ENEMY_RADIUS) then
        self.x = newX
    else
        self.velocityX = 0
    end
    
    -- Check vertical collision
    if not map:checkRectCollision(self.x, newY, ENEMY_RADIUS) then
        self.y = newY
    else
        self.velocityY = 0
    end
end

-- Check if enemy can see the player
function Enemy:canSeePlayer(map)
    local playerX, playerY = self.player:getPosition()
    
    -- Simple line-of-sight check
    local dx = playerX - self.x
    local dy = playerY - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > ENEMY_DETECTION_RANGE then
        return false
    end
    
    -- Cast ray to player
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

-- Get distance to player
function Enemy:getDistanceToPlayer()
    local playerX, playerY = self.player:getPosition()
    local dx = self.x - playerX
    local dy = self.y - playerY
    return math.sqrt(dx * dx + dy * dy)
end

-- Take damage
function Enemy:takeDamage(damage)
    self.health = self.health - damage
    print("Enemy took " .. damage .. " damage! Health: " .. self.health .. "/" .. self.maxHealth)
    
    if self.health <= 0 then
        self:die()
    end
end

-- Die
function Enemy:die()
    self.state = STATE_DEAD
    print("Enemy died!")
end

-- Check if enemy is dead
function Enemy:isDead()
    return self.state == STATE_DEAD
end

-- Get enemy position
function Enemy:getPosition()
    return self.x, self.y
end

-- Get enemy state
function Enemy:getState()
    return self.state
end

-- Get enemy health
function Enemy:getHealth()
    return self.health
end

-- Get enemy max health
function Enemy:getMaxHealth()
    return self.maxHealth
end

return Enemy
