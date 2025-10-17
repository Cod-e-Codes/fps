-- Weapon.lua - Pistol mechanics, firing, and hit detection
-- Handles weapon state, animations, and shooting logic

local Weapon = {}
Weapon.__index = Weapon

-- Constants
local FIRE_RATE = 0.2  -- Seconds between shots
local MUZZLE_FLASH_DURATION = 0.1  -- Seconds
local RECOIL_INTENSITY = 0.5
local RECOIL_DECAY = 8.0
local MAX_AMMO = 50
local DAMAGE = 25

function Weapon:new()
    local self = setmetatable({}, Weapon)
    
    -- Weapon state
    self.currentAmmo = MAX_AMMO
    self.maxAmmo = MAX_AMMO
    self.lastFireTime = 0
    self.isReloading = false
    self.reloadTime = 0
    self.reloadDuration = 2.0
    
    -- Animation state
    self.recoilTime = 0
    self.recoilIntensity = 0
    self.muzzleFlashTime = 0
    
    -- Firing state
    self.firing = false
    self.fireCooldown = 0
    
    return self
end

function Weapon:update(dt, input)
    -- Update recoil animation
    if self.recoilTime > 0 then
        self.recoilTime = self.recoilTime - dt * RECOIL_DECAY
        self.recoilIntensity = self.recoilIntensity * 0.9
    end
    
    -- Update muzzle flash
    if self.muzzleFlashTime > 0 then
        self.muzzleFlashTime = self.muzzleFlashTime - dt
    end
    
    -- Update fire cooldown
    if self.fireCooldown > 0 then
        self.fireCooldown = self.fireCooldown - dt
    end
    
    -- Check for firing input
    if input:isMouseButtonDown(1) and self:canFire() then
        self.firing = true
    else
        self.firing = false
    end
    
    -- Handle reloading
    if self.isReloading then
        self.reloadTime = self.reloadTime + dt
        if self.reloadTime >= self.reloadDuration then
            self.isReloading = false
            self.reloadTime = 0
            self.currentAmmo = self.maxAmmo
        end
    end
end

-- Check if weapon can fire
function Weapon:canFire()
    return self.currentAmmo > 0 and 
           self.fireCooldown <= 0 and 
           not self.isReloading
end

-- Fire weapon
function Weapon:fire(player, enemies, map)
    if not self:canFire() then
        return false
    end
    
    -- Firing weapon
    
    -- Consume ammo
    self.currentAmmo = self.currentAmmo - 1
    
    -- Set fire cooldown
    self.fireCooldown = FIRE_RATE
    
    -- Start recoil animation
    self.recoilTime = 0.3
    self.recoilIntensity = RECOIL_INTENSITY
    
    -- Start muzzle flash
    self.muzzleFlashTime = MUZZLE_FLASH_DURATION
    
    -- Add camera shake
    player:addCameraShake(0.3)
    
    -- Cast ray for hit detection
    local hitResult = self:castShot(player, enemies, map)
    
    -- Hit detection complete
    
    -- Handle hit
    if hitResult.hit and hitResult.hitEnemy then
        local enemy = hitResult.hitEnemy
        if enemy and enemy.takeDamage then
            enemy:takeDamage(DAMAGE)
            print("Hit enemy for " .. DAMAGE .. " damage!")
        end
    end
    
    return true
end

-- Cast a shot ray for hit detection
function Weapon:castShot(player, enemies, map)
    -- Get player's shooting direction and position
    local shootAngle = player.angle
    local startX = player.x
    local startY = player.y
    
    -- Cast ray to find what we hit
    local maxDistance = 20.0
    local hitDistance = maxDistance
    local hitEnemy = nil
    local hitWall = false
    
    -- Check for enemy hits first using actual raycasting
    for _, enemy in ipairs(enemies) do
        local distance = self:getDistanceToEnemy(startX, startY, enemy.x, enemy.y)
        if distance < maxDistance then
            -- Check if enemy is in line of sight using raycasting
            local rayHit = self:castRayToEnemy(startX, startY, shootAngle, enemy, map, maxDistance)
            if rayHit then
                if distance < hitDistance then
                    hitDistance = distance
                    hitEnemy = enemy
                end
            end
        end
    end
    
    -- Check for wall hits if no enemy was hit
    if not hitEnemy then
        local wallHit = self:castRayToWall(startX, startY, shootAngle, map, maxDistance)
        if wallHit.hit then
            hitDistance = wallHit.distance
            hitWall = true
        end
    end
    
    return {
        hit = hitEnemy ~= nil or hitWall,
        distance = hitDistance,
        hitEnemy = hitEnemy,
        hitWall = hitWall
    }
end

-- Check if enemy is in line of sight
function Weapon:isEnemyInLineOfSight(player, enemy, map)
    local dx = enemy.x - player.x
    local dy = enemy.y - player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 20 then  -- Max shooting range
        return false
    end
    
    -- Cast ray to enemy
    local steps = math.floor(distance * 20)  -- High precision
    for i = 1, steps do
        local t = i / steps
        local checkX = player.x + dx * t
        local checkY = player.y + dy * t
        
        if map:checkCollision(checkX, checkY) then
            return false
        end
    end
    
    return true
end

-- Cast ray to wall for wall hit detection
function Weapon:castRayToWall(startX, startY, shootAngle, map, maxDistance)
    local stepSize = 0.1
    local rayDirX = math.cos(shootAngle)
    local rayDirY = math.sin(shootAngle)
    
    local distance = 0
    while distance < maxDistance do
        local checkX = startX + rayDirX * distance
        local checkY = startY + rayDirY * distance
        
        if map:checkCollision(checkX, checkY) then
            return {
                hit = true,
                distance = distance,
                x = checkX,
                y = checkY
            }
        end
        
        distance = distance + stepSize
    end
    
    return {
        hit = false,
        distance = maxDistance
    }
end

-- Cast ray to specific enemy for hit detection
function Weapon:castRayToEnemy(startX, startY, shootAngle, enemy, map, maxDistance)
    -- Calculate angle to enemy
    local dx = enemy.x - startX
    local dy = enemy.y - startY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > maxDistance then
        return false
    end
    
    local enemyAngle = math.atan(dy, dx)
    local angleDiff = enemyAngle - shootAngle
    
    -- Normalize angle difference
    while angleDiff > math.pi do angleDiff = angleDiff - math.pi * 2 end
    while angleDiff < -math.pi do angleDiff = angleDiff + math.pi * 2 end
    angleDiff = math.abs(angleDiff)
    
    -- Check if enemy is within narrow shooting cone (crosshair accuracy)
    local hitCone = 0.05  -- Very narrow cone for accurate shooting
    if angleDiff > hitCone then
        return false
    end
    
    -- Line of sight check to enemy
    local steps = math.floor(distance * 10)
    for i = 1, steps do
        local t = i / steps
        local checkX = startX + dx * t
        local checkY = startY + dy * t
        
        if map:checkCollision(checkX, checkY) then
            return false  -- Wall blocks shot
        end
    end
    
    return true
end

-- Get distance to enemy
function Weapon:getDistanceToEnemy(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Check if weapon is currently firing
function Weapon:isFiring()
    return self.firing
end

-- Check if weapon is reloading
function Weapon:isReloading()
    return self.isReloading
end

-- Start reload
function Weapon:reload()
    if not self.isReloading and self.currentAmmo < self.maxAmmo then
        self.isReloading = true
        self.reloadTime = 0
    end
end

-- Get ammo info
function Weapon:getAmmoInfo()
    return {
        current = self.currentAmmo,
        max = self.maxAmmo,
        isReloading = self.isReloading,
        reloadProgress = self.reloadTime / self.reloadDuration
    }
end

-- Get weapon state for rendering
function Weapon:getRenderState()
    return {
        recoilTime = self.recoilTime,
        recoilIntensity = self.recoilIntensity,
        muzzleFlashTime = self.muzzleFlashTime,
        isReloading = self.isReloading
    }
end

return Weapon
