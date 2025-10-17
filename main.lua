-- FPS - Main Game Loop
-- Entry point and system orchestration

local Player = require("src.player")
local Map = require("src.map")
local Raycaster = require("src.raycaster")
local Renderer = require("src.renderer")
local Input = require("src.input")
local Weapon = require("src.weapon")
local Enemy = require("src.enemy")

-- Game state
local game = {
    player = nil,
    map = nil,
    raycaster = nil,
    renderer = nil,
    weapon = nil,
    enemies = {},
    input = nil,
    debug = false,
    fps = 0,
    frameTime = 0,
    lastTime = 0,
    paused = false,
    state = "menu" -- menu | playing | paused | dead | win
}

-- Global debug flag for gating console output
_G.DEBUG = false

function love.load()
    if DEBUG then print("Loading FPS...") end
    
    -- Load weapon images
    local arms = love.graphics.newImage("assets/arms.png")
    
    -- Load enemy image
    local enemyImage = love.graphics.newImage("assets/enemy.png")
    
    -- Initialize systems
    game.map = Map:new()
    game.player = Player:new(1.5, 1.5, 0)  -- Start position and angle
    game.raycaster = Raycaster:new(game.map)
    game.renderer = Renderer:new()
    game.weapon = Weapon:new()
    game.input = Input:new()
    
    -- Store weapon images and enemy image
    game.weaponImages = {
        arms = arms,
    }
    game.enemyImage = enemyImage
    
    -- Spawn enemies in open areas where they can move
    game.enemies = {}
    
    -- Spawn enemies at validated positions
    local spawnPositions = {
        {2.5, 2.5},  -- Near player
        {6.5, 6.5},  -- Center area
        {10.5, 10.5} -- Far corner
    }
    
    for _, pos in ipairs(spawnPositions) do
        if game.map:isValidSpawnPosition(pos[1], pos[2], 0.3) then
            table.insert(game.enemies, Enemy:new(pos[1], pos[2], game.player))
            if DEBUG then print("Spawned enemy at (" .. pos[1] .. ", " .. pos[2] .. ")") end
        else
            if DEBUG then print("Invalid spawn position (" .. pos[1] .. ", " .. pos[2] .. ") - skipping") end
        end
    end
    
    -- Add health to player
    game.player.health = 100
    
    -- Start in menu (do not grab mouse yet)
    love.mouse.setRelativeMode(false)
    love.mouse.setGrabbed(false)
    
    -- Initialize timing
    game.lastTime = love.timer.getTime()
    
    if DEBUG then
        print("Game loaded successfully!")
        print("Controls:")
        print("  WASD / Arrow Keys - Move")
        print("  Mouse - Look around")
        print("  Left Click - Shoot")
        print("  F3 - Toggle debug info")
        print("  ESC - Pause")
        print("  Q - Quit game")
    end
end

function love.update(dt)
    -- Smooth frame time calculation
    game.frameTime = game.frameTime * 0.9 + dt * 0.1
    game.fps = 1 / game.frameTime
    
    -- Handle input
    game.input:update()
    
    -- State transitions
    if game.state == "menu" then
        if game.input:isKeyPressed("return") or game.input:isKeyPressed("enter") then
            game.state = "playing"
            game.paused = false
            game.input:setMouseLookEnabled(true)
        end
        game.input:endUpdate()
        return
    end

    if game.state == "dead" or game.state == "win" then
        if game.input:isKeyPressed("q") then
            love.event.quit()
            return
        end
        if game.input:isKeyPressed("r") then
            -- Restart: reinitialize player/enemies/weapon
            game.map = Map:new()
            game.player = Player:new(1.5, 1.5, 0)
            game.weapon = Weapon:new()
            game.enemies = {}
            local spawnPositions = {
                {2.5, 2.5},
                {6.5, 6.5},
                {10.5, 10.5}
            }
            for _, pos in ipairs(spawnPositions) do
                if game.map:isValidSpawnPosition(pos[1], pos[2], 0.3) then
                    table.insert(game.enemies, Enemy:new(pos[1], pos[2], game.player))
                end
            end
            game.player.health = 100
            game.state = "playing"
            game.input:setMouseLookEnabled(true)
        end
        game.input:endUpdate()
        return
    end

    -- Pause toggle while playing or paused
    if (game.state == "playing" or game.state == "paused") and game.input:isKeyPressed("escape") then
        if game.state == "playing" then
            game.paused = true
            game.state = "paused"
            game.input:setMouseLookEnabled(false)
        else
            game.paused = false
            game.state = "playing"
            game.input:setMouseLookEnabled(true)
        end
    end

    if game.state == "paused" then
        -- Allow restart and quit while paused
        if game.input:isKeyPressed("r") then
            game.map = Map:new()
            game.player = Player:new(1.5, 1.5, 0)
            game.weapon = Weapon:new()
            game.enemies = {}
            local spawnPositions = {
                {2.5, 2.5},
                {6.5, 6.5},
                {10.5, 10.5}
            }
            for _, pos in ipairs(spawnPositions) do
                if game.map:isValidSpawnPosition(pos[1], pos[2], 0.3) then
                    table.insert(game.enemies, Enemy:new(pos[1], pos[2], game.player))
                end
            end
            game.player.health = 100
            game.paused = false
            game.state = "playing"
            game.input:setMouseLookEnabled(true)
        elseif game.input:isKeyPressed("q") then
            love.event.quit()
            return
        end
        game.input:endUpdate()
        return
    end

    -- Update game systems
    game.player:update(dt, game.map, game.input)
    game.weapon:update(dt, game.input)
    
    -- Update enemies
    for i = #game.enemies, 1, -1 do
        local enemy = game.enemies[i]
        enemy:update(dt, game.map, game.player)
        
        -- Remove dead enemies
        if enemy:isDead() then
            table.remove(game.enemies, i)
        end
    end
    
    -- Handle shooting
    if game.weapon:isFiring() then
        game.weapon:fire(game.player, game.enemies, game.map)
    end
    
    -- Handle debug toggle
    if game.input:isKeyPressed("f3") then
        game.debug = not game.debug
        _G.DEBUG = game.debug
        if DEBUG then print("Debug mode toggled: " .. tostring(game.debug)) end
    end
    
    -- (ESC is handled for pause toggle above)

    -- Death detection
    if (game.player.health or 100) <= 0 then
        game.state = "dead"
        game.paused = false
        game.input:setMouseLookEnabled(false)
    end

    -- Win detection (all enemies defeated)
    if #game.enemies == 0 then
        game.state = "win"
        game.input:setMouseLookEnabled(false)
        game.input:endUpdate()
        return
    end
    
    -- End input update cycle
    game.input:endUpdate()
end

function love.draw()
    -- Get raycaster data
    local rays = game.raycaster:castRays(game.player)
    
    -- Get player view data for rendering
    local playerView = game.player:getViewData()
    
    -- Render world
    game.renderer:drawWorld(rays, playerView)
    
    -- Render enemies as billboards (pass rays for depth checking)
    game.renderer:drawEnemies(game.enemies, game.player, game.map, rays, game.enemyImage)
    
    -- Render weapon
    game.renderer:drawWeapon(game.weapon, game.weaponImages)
    
    -- Overlays based on state
    if game.state == "menu" then
        if game.renderer.drawStartOverlay then game.renderer:drawStartOverlay() end
        return
    end

    -- Render HUD
    game.renderer:drawHUD(game.player, game.weapon, game.debug)

    -- Pause overlay
    if game.state == "paused" then
        if game.renderer.drawPauseOverlay then
            game.renderer:drawPauseOverlay()
        end
        return
    end

    if game.state == "dead" then
        if game.renderer.drawDeathOverlay then game.renderer:drawDeathOverlay() end
        return
    end
    if game.state == "win" then
        if game.renderer.drawWinOverlay then game.renderer:drawWinOverlay() end
        return
    end
    
    -- Render debug info
    if game.debug then
        game.renderer:drawDebug(game.player, game.fps, #game.enemies, game.enemies)
    end
    
    -- Render crosshair
    game.renderer:drawCrosshair()
end

function love.mousemoved(x, y, dx, dy)
    -- Pass mouse movement to input system
    game.input:onMouseMoved(dx, dy)
end

function love.keypressed(key)
    -- Handle quit key
    if key == "q" or key == "Q" then
        love.event.quit()
        return
    end
    
    -- Handle key presses for input system
    game.input:onKeyPressed(key)
end

function love.mousepressed(x, y, button)
    -- Ignore recapture while not playing
    if game.state ~= "playing" then return end
    -- Re-capture mouse when the user clicks inside the window after releasing it
    if not love.mouse.getRelativeMode() or not love.mouse.isGrabbed() then
        game.input:setMouseLookEnabled(true)
    end
end

function love.resize(w, h)
    -- Update renderer for new window size
    if game.renderer then
        game.renderer:onResize(w, h)
    end
end
