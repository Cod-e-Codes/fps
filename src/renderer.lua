-- Renderer.lua - Wall rendering, sprite billboarding, and HUD
-- Handles all rendering operations for the raycasting engine

local Renderer = {}
Renderer.__index = Renderer

-- Constants
local CEILING_COLOR = {0.3, 0.3, 0.35}     -- Slightly bluish ceiling
local FLOOR_COLOR = {0.18, 0.18, 0.2}      -- Slightly bluish floor
local WALL_COLOR_BRIGHT = {0.85, 0.85, 0.9}
local WALL_COLOR_DARK = {0.65, 0.65, 0.7}
local CROSSHAIR_COLOR = {1.0, 1.0, 1.0}    -- White crosshair
local HUD_COLOR = {1.0, 1.0, 1.0}          -- White HUD text

-- Toon shading helpers
local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function quantize(value, steps)
    steps = steps or 3
    local v = clamp01(value)
    return math.ceil(v * steps) / steps
end

local function applyToonColor(baseColor, shade, steps)
    local q = quantize(shade, steps)
    return baseColor[1] * q, baseColor[2] * q, baseColor[3] * q
end

function Renderer:new()
    local self = setmetatable({}, Renderer)
    
    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()
    self.halfHeight = self.screenHeight / 2
    
    -- Create font for HUD
    self.font = love.graphics.newFont(16)
    self.smallFont = love.graphics.newFont(12)
    
    return self
end

function Renderer:onResize(w, h)
    self.screenWidth = w
    self.screenHeight = h
    self.halfHeight = h / 2
end

-- Main world rendering function
function Renderer:drawWorld(rays, player)
    -- Clear screen
    love.graphics.clear(0.1, 0.1, 0.1, 1.0)
    
    -- Draw ceiling and floor
    self:drawCeilingFloor(player)
    
    -- Draw walls
    self:drawWalls(rays, player)
end

-- Draw ceiling and floor (split screen)
function Renderer:drawCeilingFloor(player)
    -- Calculate height offset for consistent view
    local heightOffset = (player.height - 1.6) * 100

    -- Simple fake light direction effect via vertical gradient then quantize
    local steps = 4
    -- Ceiling
    local ceilingShade = 0.85
    local r, g, b = applyToonColor(CEILING_COLOR, ceilingShade, steps)
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", 0, heightOffset, self.screenWidth, self.halfHeight)

    -- Floor
    local floorShade = 0.75
    r, g, b = applyToonColor(FLOOR_COLOR, floorShade, steps)
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", 0, self.halfHeight + heightOffset, self.screenWidth, self.halfHeight)
end

-- Draw walls using ray data
function Renderer:drawWalls(rays, player)
    for i, ray in ipairs(rays) do
        if ray.hit then
            -- Base color varies by wall side
            local wallColor = (ray.side == 1) and WALL_COLOR_DARK or WALL_COLOR_BRIGHT
            -- Distance-based brightness (fake N·L proxy), then toon quantize
            local brightness = math.max(0.15, 1.0 - (ray.distance / 15.0))
            local r, g, b = applyToonColor(wallColor, brightness, 4)
            love.graphics.setColor(r, g, b)
            
            -- Apply height offset only for wall rendering
            local heightOffset = (player.height - 1.6) * 100
            local wallTop = math.max(0, ray.originalWallTop + heightOffset)
            local wallBottom = math.min(self.screenHeight, ray.originalWallBottom + heightOffset)
            local wallHeight = wallBottom - wallTop
            
            love.graphics.rectangle("fill", ray.screenX, wallTop, 1, wallHeight)
        end
    end
end

-- Draw enemies as billboards with proper depth sorting
function Renderer:drawEnemies(enemies, player, map, rays, enemyImage)
    -- Sort enemies by distance (back to front) for proper depth sorting
    local sortedEnemies = {}
    for _, enemy in ipairs(enemies) do
        local distance = player:getDistanceTo(enemy.x, enemy.y)
        table.insert(sortedEnemies, {enemy = enemy, distance = distance})
    end
    
    -- Sort by distance (farthest first, closest last)
    table.sort(sortedEnemies, function(a, b) return a.distance > b.distance end)
    
    -- Draw each enemy (farthest to closest for proper depth)
    for _, data in ipairs(sortedEnemies) do
        local enemy = data.enemy
        self:drawBillboard(enemy, player, map, rays, enemyImage)
    end
end

-- Draw a billboard sprite (always faces player)
function Renderer:drawBillboard(enemy, player, map, rays, enemyImage)
    local enemyX, enemyY = enemy.x, enemy.y
    local playerX, playerY = player.x, player.y
    local playerAngle = player.angle
    
    -- Calculate vector from player to enemy
    local dx = enemyX - playerX
    local dy = enemyY - playerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Calculate angle from player to enemy (FIXED: proper math.atan2)
    local angleToEnemy = math.atan(dy, dx)
    local angleDiff = angleToEnemy - playerAngle
    
    -- Normalize angle difference to [-π, π]
    while angleDiff > math.pi do angleDiff = angleDiff - math.pi * 2 end
    while angleDiff < -math.pi do angleDiff = angleDiff + math.pi * 2 end
    
    -- Field of view check
    local fov = math.pi / 3  -- 60 degree field of view
    if math.abs(angleDiff) > fov / 2 or distance > 15 then
        return  -- Enemy not in view
    end
    
    -- Calculate screen X position (FIXED: proper FOV mapping)
    local screenX = self.screenWidth / 2 + (angleDiff / fov) * self.screenWidth
    
    -- Check if enemy is behind a wall by comparing with ray distance at this screen position
    local rayIndex = math.floor(screenX) + 1
    if rayIndex >= 1 and rayIndex <= #rays and rays[rayIndex] then
        local ray = rays[rayIndex]
        if ray.hit and ray.distance < distance - 0.5 then
            return  -- Enemy is behind a wall, don't render
        end
    end
    
    -- Calculate sprite size based on distance
    local spriteSize = math.max(20, 150 / distance)  -- Larger base size for image
    local spriteHeight = spriteSize * 2.2  -- Adjust height ratio for image proportions
    
    -- Calculate vertical position (center on ground level)
    local heightOffset = (player.height - 1.6) * 100
    local screenY = self.halfHeight + heightOffset + (self.halfHeight / distance) - spriteHeight / 2
    
    -- Draw enemy image instead of circle
    if enemyImage then
        -- Get image dimensions
        local imageWidth = enemyImage:getWidth()
        local imageHeight = enemyImage:getHeight()
        
        -- Calculate scale; make enemies slightly wider for better readability
        local scaleX = (spriteSize / imageWidth) * 1.08  -- +8% width
        local scaleY = spriteHeight / imageHeight
        
        -- Draw the enemy image
        love.graphics.setColor(1.0, 1.0, 1.0)  -- White (no tinting)
        love.graphics.draw(enemyImage, screenX, screenY + spriteHeight / 2, 0, scaleX, scaleY, imageWidth / 2, imageHeight)
    else
        -- Fallback to circle if image not loaded
        love.graphics.setColor(1.0, 0.0, 0.0)
        love.graphics.circle("fill", screenX, screenY + spriteHeight / 2, spriteSize / 2)
        
        -- Draw enemy outline
        love.graphics.setColor(1.0, 1.0, 1.0)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", screenX, screenY + spriteHeight / 2, spriteSize / 2)
        love.graphics.setLineWidth(1)
    end
    
    -- Draw health bar above enemy
    if enemy.health < enemy.maxHealth then
        local barWidth = spriteSize
        local barHeight = 4
        local barX = screenX - barWidth / 2
        local barY = screenY - 10
        
        love.graphics.setColor(0.3, 0.0, 0.0)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        
        local healthPercent = enemy.health / enemy.maxHealth
        love.graphics.setColor(1.0, 0.0, 0.0)
        love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
    end
end

-- Draw weapon using image
function Renderer:drawWeapon(weapon, weaponImages)
    local weaponX = self.screenWidth / 2.5  -- Moved left
    local weaponY = self.screenHeight * 0.675  -- Position in lower portion of screen
    
    -- Weapon recoil animation
    local recoilOffset = math.sin(weapon.recoilTime * 20) * weapon.recoilIntensity * 10
    weaponY = weaponY + recoilOffset
    
    -- Get weapon image
    local weaponImage = weaponImages.arms
    
    -- Calculate image dimensions to fit screen (maintaining aspect ratio)
    local imageWidth = weaponImage:getWidth()
    local imageHeight = weaponImage:getHeight()
    
    -- Scale image to fill more of the screen - use 80% of screen height
    local scale = (self.screenHeight * 0.8) / imageHeight
    local scaledWidth = imageWidth * scale
    local scaledHeight = imageHeight * scale
    
    -- Center the image both horizontally and vertically
    local drawX = weaponX - scaledWidth / 2
    local drawY = weaponY - scaledHeight / 2
    
    -- Draw weapon image
    love.graphics.setColor(1.0, 1.0, 1.0)  -- White color (no tinting)
    love.graphics.draw(weaponImage, drawX, drawY, 0, scale, scale)
    
    -- Realistic muzzle flash effect
    if weapon.muzzleFlashTime > 0 then
        local flashIntensity = weapon.muzzleFlashTime / 0.1  -- Fade out over duration
        
        -- Position muzzle flash at the tip of the pistol (adjusted for left shift)
        local flashX = weaponX + scaledWidth * 0.15  -- Adjusted for left shift
        local flashY = weaponY - scaledHeight * 0.35  -- Higher up for barrel position
        
        -- Multi-layer muzzle flash for realism
        -- Outer bright flash
        love.graphics.setColor(1.0, 1.0, 0.3, flashIntensity * 0.8)
        local outerSize = 40 * scale * flashIntensity
        love.graphics.circle("fill", flashX, flashY, outerSize)
        
        -- Middle orange flash
        love.graphics.setColor(1.0, 0.6, 0.1, flashIntensity * 0.9)
        local middleSize = 25 * scale * flashIntensity
        love.graphics.circle("fill", flashX, flashY, middleSize)
        
        -- Inner white hot flash
        love.graphics.setColor(1.0, 1.0, 1.0, flashIntensity)
        local innerSize = 15 * scale * flashIntensity
        love.graphics.circle("fill", flashX, flashY, innerSize)
        
        -- Barrel smoke effect
        love.graphics.setColor(0.8, 0.8, 0.8, flashIntensity * 0.4)
        love.graphics.ellipse("fill", flashX + 20 * scale, flashY, 15 * scale, 8 * scale)
    end
end

-- Draw HUD (health, ammo, etc.)
function Renderer:drawHUD(player, weapon, debugMode)
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(HUD_COLOR)

    -- Minimal text-only HUD in top-left
    local x, y = 10, 10
    local health = math.max(0, math.floor(player.health or 100))
    love.graphics.print("HP " .. health, x, y)

    -- Thin accent bar for HP
    local hpw = 120
    love.graphics.setColor(0.2, 0.9, 0.3, 0.9)
    love.graphics.rectangle("fill", x, y + 14, hpw * math.min(1, health / 100), 3)

    -- Ammo line
    love.graphics.setColor(HUD_COLOR)
    if weapon.getAmmoInfo then
        local info = weapon:getAmmoInfo()
        local ammoText = string.format("AMMO %d/%d | %d", info.inMag or 0, info.magSize or 0, info.reserve or 0)
        love.graphics.print(ammoText, x, y + 24)
        if info.isReloading then
            love.graphics.setColor(1.0, 1.0, 0.0)
            love.graphics.print("Reloading...", x + 150, y + 24)
        end
    end

    -- Small FPS top-right
    if love.timer then
        local fps = love.timer.getFPS()
        local text = "FPS: " .. fps
        local tw = self.smallFont:getWidth(text)
        love.graphics.setColor(1, 1, 0.3)
        love.graphics.print(text, self.screenWidth - tw - 10, 10)
    end

    -- Debug tag (top-right under FPS)
    if debugMode then
        local tag = "DEBUG"
        local tw = self.smallFont:getWidth(tag)
        love.graphics.setColor(1.0, 1.0, 0.0)
        love.graphics.print(tag, self.screenWidth - tw - 10, 26)
        love.graphics.setColor(HUD_COLOR)
    end
end

-- Draw crosshair
function Renderer:drawCrosshair()
    local centerX = self.screenWidth / 2
    local centerY = self.screenHeight / 2
    
    love.graphics.setColor(CROSSHAIR_COLOR)
    
    -- Draw crosshair lines
    love.graphics.line(centerX - 10, centerY, centerX + 10, centerY)
    love.graphics.line(centerX, centerY - 10, centerX, centerY + 10)
    
    -- Draw center dot
    love.graphics.circle("fill", centerX, centerY, 2)
end

-- Draw pause overlay
function Renderer:drawPauseOverlay()
    local w, h = self.screenWidth, self.screenHeight
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.font)
    local msg = "Paused"
    local sub = "Press ESC to resume"
    local msgW = self.font:getWidth(msg)
    local msgH = self.font:getHeight()
    love.graphics.print(msg, (w - msgW) / 2, h * 0.4)
    love.graphics.setFont(self.smallFont)
    local subW = self.smallFont:getWidth(sub)
    love.graphics.print(sub, (w - subW) / 2, h * 0.4 + msgH + 10)
end

-- Draw start/menu overlay
function Renderer:drawStartOverlay()
    local w, h = self.screenWidth, self.screenHeight
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.font)
    local title = "FPS"
    local tW = self.font:getWidth(title)
    local tH = self.font:getHeight()
    love.graphics.print(title, (w - tW) / 2, h * 0.35)
    love.graphics.setFont(self.smallFont)
    local msg = "Press Enter to Start"
    local mW = self.smallFont:getWidth(msg)
    love.graphics.print(msg, (w - mW) / 2, h * 0.35 + tH + 12)
end

-- Draw death overlay
function Renderer:drawDeathOverlay()
    local w, h = self.screenWidth, self.screenHeight
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 0.2, 0.2, 1)
    love.graphics.setFont(self.font)
    local msg = "You Died"
    local mW = self.font:getWidth(msg)
    local mH = self.font:getHeight()
    love.graphics.print(msg, (w - mW) / 2, h * 0.35)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.smallFont)
    local sub1 = "Press R to Restart"
    local sub2 = "Press Q to Quit"
    local thanks = "Thanks for playing!"
    local y = h * 0.35 + mH + 12
    local sW1 = self.smallFont:getWidth(sub1)
    love.graphics.print(sub1, (w - sW1) / 2, y)
    y = y + 18
    local sW2 = self.smallFont:getWidth(sub2)
    love.graphics.print(sub2, (w - sW2) / 2, y)
    y = y + 24
    local tW = self.smallFont:getWidth(thanks)
    love.graphics.print(thanks, (w - tW) / 2, y)
end

-- Draw win overlay
function Renderer:drawWinOverlay()
    local w, h = self.screenWidth, self.screenHeight
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(0.6, 1, 0.6, 1)
    love.graphics.setFont(self.font)
    local msg = "You Win!"
    local mW = self.font:getWidth(msg)
    local mH = self.font:getHeight()
    love.graphics.print(msg, (w - mW) / 2, h * 0.35)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.smallFont)
    local sub1 = "Press R to Restart"
    local sub2 = "Press Q to Quit"
    local thanks = "Thanks for playing!"
    local y = h * 0.35 + mH + 12
    local sW1 = self.smallFont:getWidth(sub1)
    love.graphics.print(sub1, (w - sW1) / 2, y)
    y = y + 18
    local sW2 = self.smallFont:getWidth(sub2)
    love.graphics.print(sub2, (w - sW2) / 2, y)
    y = y + 24
    local tW = self.smallFont:getWidth(thanks)
    love.graphics.print(thanks, (w - tW) / 2, y)
end

    -- Draw debug information
function Renderer:drawDebug(player, fps, enemyCount, enemies)
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(1.0, 1.0, 1.0)
    
    local debugY = 90  -- Start below HUD elements
    local lineHeight = 15
    
    -- Player position
    love.graphics.print("Pos: (" .. string.format("%.2f", player.x) .. ", " .. string.format("%.2f", player.y) .. ")", 10, debugY)
    debugY = debugY + lineHeight
    
    -- Player angle
    love.graphics.print("Angle: " .. string.format("%.2f", player.angle), 10, debugY)
    debugY = debugY + lineHeight
    
    -- Player height
    love.graphics.print("Height: " .. string.format("%.2f", player.height), 10, debugY)
    debugY = debugY + lineHeight
    
    -- FPS
    love.graphics.print("FPS: " .. string.format("%.1f", fps), 10, debugY)
    debugY = debugY + lineHeight
    
    -- Enemy count
    love.graphics.print("Enemies: " .. enemyCount, 10, debugY)
    debugY = debugY + lineHeight
    
    -- Enemy positions
    for i, enemy in ipairs(enemies) do
        local distance = player:getDistanceTo(enemy.x, enemy.y)
        love.graphics.print("Enemy " .. i .. ": (" .. string.format("%.2f", enemy.x) .. ", " .. string.format("%.2f", enemy.y) .. ") State: " .. enemy.state .. " Dist: " .. string.format("%.2f", distance), 10, debugY)
        debugY = debugY + lineHeight
    end
    
    -- Mouse info
    local mouseX, mouseY = love.mouse.getPosition()
    love.graphics.print("Mouse: (" .. mouseX .. ", " .. mouseY .. ")", 10, debugY)
end

-- Check if there's a clear line of sight between two points (for enemies)
function Renderer:hasLineOfSight(x1, y1, x2, y2, map)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 15 then  -- Max visibility range
        return false
    end
    
    -- Cast ray with steps to check for walls (no height offset for enemy visibility)
    local steps = math.floor(distance * 10)
    for i = 1, steps do
        local t = i / steps
        local checkX = x1 + dx * t
        local checkY = y1 + dy * t
        
        -- Check if ray hits wall (stop raycasting)
        if map and map:checkCollision(checkX, checkY) then
            return false
        end
    end
    
    return true
end

return Renderer

