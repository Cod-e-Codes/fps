-- LÖVE 11.5 Configuration for Raycasting FPS
-- Optimized for performance and smooth gameplay

function love.conf(t)
    -- Window settings
    t.window.title = "FPS"
    t.window.width = 800
    t.window.height = 600
    t.window.resizable = true
    t.window.vsync = 1  -- Adaptive vsync for smooth frame pacing
    t.window.msaa = 4   -- Anti-aliasing for smooth rendering
    
    -- Performance optimizations
    t.accelerometerjoystick = false  -- Disable unused modules
    t.gammacorrect = false          -- Disable for performance
    
    -- Disable unused modules to reduce memory footprint
    t.modules.joystick = false
    t.modules.touch = false
    t.modules.video = false
    t.modules.physics = false       -- Using custom collision for grid-based system
    
    -- Console for debugging (Windows only)
    t.console = true
end
