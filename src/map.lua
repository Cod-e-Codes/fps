-- Map.lua - Grid-based level data and collision detection
-- Handles the world geometry for raycasting

local Map = {}
Map.__index = Map

-- Constants
local MAP_WIDTH = 12
local MAP_HEIGHT = 12
local CELL_SIZE = 1.0

-- Simple test map (0 = empty, 1+ = wall types)
local TEST_MAP = {
    {1,1,1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,1,1,0,0,1,1,0,0,1},
    {1,0,0,1,1,0,0,1,1,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,1,1,0,0,1,1,0,0,1},
    {1,0,0,1,1,0,0,1,1,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,1},
    {1,1,1,1,1,1,1,1,1,1,1,1}
}

function Map:new()
    local self = setmetatable({}, Map)
    
    self.width = MAP_WIDTH
    self.height = MAP_HEIGHT
    self.cellSize = CELL_SIZE
    self.data = TEST_MAP
    
    return self
end

-- Check if a grid cell contains a wall
function Map:isWall(gridX, gridY)
    -- Bounds checking
    if gridX < 1 or gridX > self.width or gridY < 1 or gridY > self.height then
        return true  -- Treat out-of-bounds as walls
    end
    
    return self.data[gridY][gridX] ~= 0
end

-- Get wall type at grid position
function Map:getWallType(gridX, gridY)
    if gridX < 1 or gridX > self.width or gridY < 1 or gridY > self.height then
        return 1  -- Default wall type for out-of-bounds
    end
    
    return self.data[gridY][gridX]
end

-- Convert world coordinates to grid coordinates
function Map:worldToGrid(worldX, worldY)
    local gridX = math.floor(worldX) + 1
    local gridY = math.floor(worldY) + 1
    return gridX, gridY
end

-- Convert grid coordinates to world coordinates (center of cell)
function Map:gridToWorld(gridX, gridY)
    local worldX = gridX - 0.5
    local worldY = gridY - 0.5
    return worldX, worldY
end

-- Check collision at world position
function Map:checkCollision(worldX, worldY)
    local gridX, gridY = self:worldToGrid(worldX, worldY)
    return self:isWall(gridX, gridY)
end

-- Check collision for a rectangle (for player collision)
function Map:checkRectCollision(x, y, radius)
    -- Check four corners of the player's collision box
    local corners = {
        {x - radius, y - radius},
        {x + radius, y - radius},
        {x - radius, y + radius},
        {x + radius, y + radius}
    }
    
    for _, corner in ipairs(corners) do
        if self:checkCollision(corner[1], corner[2]) then
            return true
        end
    end
    
    return false
end

-- Get map dimensions
function Map:getDimensions()
    return self.width, self.height
end

-- Check if a position is valid for entity spawning (not in a wall)
function Map:isValidSpawnPosition(x, y, radius)
    radius = radius or 0.3  -- Default radius for entities
    
    -- Check if the spawn position and surrounding area is clear
    local corners = {
        {x - radius, y - radius},
        {x + radius, y - radius},
        {x - radius, y + radius},
        {x + radius, y + radius}
    }
    
    for _, corner in ipairs(corners) do
        if self:checkCollision(corner[1], corner[2]) then
            return false
        end
    end
    
    return true
end

-- Find a random valid spawn position in an open area
function Map:findRandomSpawnPosition(radius, maxAttempts)
    radius = radius or 0.3
    maxAttempts = maxAttempts or 100
    
    for i = 1, maxAttempts do
        local x = math.random() * (self.width - 2) + 1.5  -- Keep away from walls
        local y = math.random() * (self.height - 2) + 1.5
        
        if self:isValidSpawnPosition(x, y, radius) then
            return x, y
        end
    end
    
    -- Fallback to a known safe position if random fails
    return 2.5, 2.5
end

-- Ray-march through the map (for raycasting)
function Map:rayMarch(startX, startY, dirX, dirY, maxDistance)
    local distance = 0
    local stepSize = 0.1  -- Smaller steps for accuracy
    local currentX, currentY = startX, startY
    
    while distance < maxDistance do
        currentX = startX + dirX * distance
        currentY = startY + dirY * distance
        
        if self:checkCollision(currentX, currentY) then
            return distance, currentX, currentY
        end
        
        distance = distance + stepSize
    end
    
    return maxDistance, currentX, currentY
end

return Map
