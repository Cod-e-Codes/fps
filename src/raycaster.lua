-- Raycaster.lua - DDA (Digital Differential Analyzer) raycasting engine
-- Implements the core raycasting algorithm for wall detection

local Raycaster = {}
Raycaster.__index = Raycaster

-- Constants
local FOV = math.pi / 3  -- 60 degrees field of view
local MAX_RAY_DISTANCE = 20.0

function Raycaster:new(map)
    local self = setmetatable({}, Raycaster)
    
    self.map = map
    self.rays = {}  -- Pre-allocate ray data table
    
    return self
end

-- Main raycasting function - casts rays for each screen column
function Raycaster:castRays(player)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local rays = {}
    
    -- Player data
    local playerX = player.x
    local playerY = player.y
    local playerAngle = player.angle
    
    -- Cast ray for each screen column
    for x = 0, screenWidth - 1 do
        -- Calculate ray angle (offset from player's facing direction)
        local rayAngle = playerAngle - FOV/2 + (x / screenWidth) * FOV
        
        -- Cast single ray
        local ray = self:castSingleRay(playerX, playerY, rayAngle, playerAngle)
        ray.screenX = x
        
        -- Store original wall positions (height offset will be applied in renderer)
        ray.originalWallTop = ray.wallTop
        ray.originalWallBottom = ray.wallBottom
        
        rays[x + 1] = ray
    end
    
    return rays
end

-- Cast a single ray using DDA algorithm
function Raycaster:castSingleRay(startX, startY, rayAngle, playerAngle)
    local rayDirX = math.cos(rayAngle)
    local rayDirY = math.sin(rayAngle)
    
    -- Current position
    local mapX, mapY = self.map:worldToGrid(startX, startY)
    local posX, posY = startX, startY
    
    -- Step size for each axis
    local deltaDistX = math.abs(1 / rayDirX) if rayDirX == 0 then deltaDistX = math.huge end
    local deltaDistY = math.abs(1 / rayDirY) if rayDirY == 0 then deltaDistY = math.huge end
    
    -- Initial step direction and distance
    local stepX, stepY
    local sideDistX, sideDistY
    
    if rayDirX < 0 then
        stepX = -1
        sideDistX = (posX - mapX + 1) * deltaDistX
    else
        stepX = 1
        sideDistX = (mapX + 1 - posX) * deltaDistX
    end
    
    if rayDirY < 0 then
        stepY = -1
        sideDistY = (posY - mapY + 1) * deltaDistY
    else
        stepY = 1
        sideDistY = (mapY + 1 - posY) * deltaDistY
    end
    
    -- DDA loop
    local hit = false
    local side = 0  -- 0 = X-side, 1 = Y-side
    local wallType = 1
    local distance = 0
    local wallX = 0  -- Position on wall for texture coordinate
    
    while not hit and distance < MAX_RAY_DISTANCE do
        -- Jump to next map square, either in X-direction or Y-direction
        if sideDistX < sideDistY then
            sideDistX = sideDistX + deltaDistX
            mapX = mapX + stepX
            side = 0
        else
            sideDistY = sideDistY + deltaDistY
            mapY = mapY + stepY
            side = 1
        end
        
        -- Check if ray hit a wall
        if self.map:isWall(mapX, mapY) then
            hit = true
            wallType = self.map:getWallType(mapX, mapY)
        end
    end
    
    -- Calculate distance (perpendicular distance to prevent fisheye)
    if side == 0 then
        distance = sideDistX - deltaDistX
        wallX = posY + distance * rayDirY
    else
        distance = sideDistY - deltaDistY
        wallX = posX + distance * rayDirX
    end
    
    -- Fix fisheye effect with proper distance calculation
    local perpDistance = distance * math.cos(rayAngle - playerAngle)
    
    -- Calculate wall height on screen (fixed perspective)
    local wallHeight = love.graphics.getHeight() / perpDistance
    local wallTop = (love.graphics.getHeight() - wallHeight) / 2
    local wallBottom = wallTop + wallHeight
    
    -- Calculate texture coordinate (0.0 to 1.0)
    local texX = wallX - math.floor(wallX)
    if side == 0 and rayDirX > 0 then
        texX = 1 - texX
    elseif side == 1 and rayDirY < 0 then
        texX = 1 - texX
    end
    
    return {
        distance = perpDistance,  -- Use corrected distance
        wallType = wallType,
        side = side,
        wallHeight = wallHeight,
        wallTop = wallTop,
        wallBottom = wallBottom,
        texX = texX,
        hit = hit,
        rayAngle = rayAngle
    }
end

-- Cast a single ray for shooting/hit detection
function Raycaster:castRayForShooting(startX, startY, rayAngle, maxDistance)
    local rayDirX = math.cos(rayAngle)
    local rayDirY = math.sin(rayAngle)
    
    local distance = 0
    local stepSize = 0.05  -- Smaller steps for accuracy
    local currentX, currentY = startX, startY
    
    while distance < maxDistance do
        currentX = startX + rayDirX * distance
        currentY = startY + rayDirY * distance
        
        if self.map:checkCollision(currentX, currentY) then
            return {
                hit = true,
                distance = distance,
                x = currentX,
                y = currentY,
                hitWall = true
            }
        end
        
        distance = distance + stepSize
    end
    
    return {
        hit = false,
        distance = maxDistance,
        x = currentX,
        y = currentY,
        hitWall = false
    }
end

-- Get ray data for a specific screen position (for enemy visibility)
function Raycaster:getRayAtScreenX(player, screenX)
    local screenWidth = love.graphics.getWidth()
    local rayAngle = player.angle - FOV/2 + (screenX / screenWidth) * FOV
    
    return self:castSingleRay(player.x, player.y, rayAngle)
end


return Raycaster
