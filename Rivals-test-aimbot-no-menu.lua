local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Configuration (easily customizable)
local FOV_RADIUS = 200 -- FOV circle radius (adjust with [ and ] keys)
local FOV_COLOR = Color3.fromRGB(255, 255, 255) -- White FOV circle
local SNAPLINE_COLOR = Color3.fromRGB(255, 0, 0) -- Red snapline
local HEAD_CIRCLE_COLOR = Color3.fromRGB(0, 255, 0) -- Green head circle
local HEAD_CIRCLE_RADIUS = 10 -- Size of circle around target's head
local AIMBOT_SMOOTHNESS = 0.25 -- Mouse movement smoothness (0.1-0.5 recommended, lower = faster)

-- State variables
local targetPlayer = nil
local isAimbotActive = false
local isRightMouseDown = false
local autoClickConnection = nil
local lastClickTime = 0 -- Track the last time we clicked
local scriptActive = true
local targetHitbox = "Head" -- Target hitbox (Head, HumanoidRootPart, etc.)

-- Drawing objects
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Transparency = 0.7
fovCircle.Color = FOV_COLOR
fovCircle.Thickness = 2
fovCircle.NumSides = 64
fovCircle.Radius = FOV_RADIUS
fovCircle.Filled = false

local snapLine = Drawing.new("Line")
snapLine.Visible = false
snapLine.Thickness = 1.5
snapLine.Color = SNAPLINE_COLOR

local headCircle = Drawing.new("Circle")
headCircle.Visible = false
headCircle.Transparency = 0.7
headCircle.Color = HEAD_CIRCLE_COLOR
headCircle.Thickness = 2
headCircle.NumSides = 30
headCircle.Radius = HEAD_CIRCLE_RADIUS
headCircle.Filled = false

-- Helper functions
-- Check if in lobby (customize based on your game)
local function isLobbyVisible()
    -- Try-catch for compatibility with different games
    local success, result = pcall(function()
        if localPlayer.PlayerGui:FindFirstChild("MainGui") then
            return localPlayer.PlayerGui.MainGui.MainFrame.Lobby.Currency.Visible == true
        end
        return false
    end)
    
    return success and result
end

local function getClosestPlayerInFOV()
    local closestPlayer = nil
    local shortestDistance = FOV_RADIUS
    local mousePosition = UserInputService:GetMouseLocation()
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            -- Try to find the target hitbox (Head, HumanoidRootPart, etc.)
            local hitboxPart = player.Character:FindFirstChild(targetHitbox)
            if not hitboxPart then
                -- Fallback to Head if specified hitbox doesn't exist
                hitboxPart = player.Character:FindFirstChild("Head")
                if not hitboxPart then
                    -- Last resort - try HumanoidRootPart
                    hitboxPart = player.Character:FindFirstChild("HumanoidRootPart")
                end
            end
            
            if hitboxPart then
                local hitboxPosition, onScreen = camera:WorldToViewportPoint(hitboxPart.Position)
                
                if onScreen and hitboxPosition.Z > 0 then
                    local screenPosition = Vector2.new(hitboxPosition.X, hitboxPosition.Y)
                    local distance = (screenPosition - mousePosition).Magnitude
                    
                    if distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local function lockOntoTarget()
    if not targetPlayer or not targetPlayer.Character or not isAimbotActive then return end
    
    -- Try to find the target hitbox (Head, HumanoidRootPart, etc.)
    local hitboxPart = targetPlayer.Character:FindFirstChild(targetHitbox)
    if not hitboxPart then
        -- Fallback to Head if specified hitbox doesn't exist
        hitboxPart = targetPlayer.Character:FindFirstChild("Head")
        if not hitboxPart then
            -- Last resort - try HumanoidRootPart
            hitboxPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hitboxPart then return end -- No valid target part
        end
    end
    
    -- Get the target's position on screen
    local targetPosition, onScreen = camera:WorldToViewportPoint(hitboxPart.Position)
    
    if onScreen and targetPosition.Z > 0 then
        -- Calculate the delta between target position and screen center
        local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        local targetScreenPos = Vector2.new(targetPosition.X, targetPosition.Y)
        local delta = targetScreenPos - screenCenter
        
        -- Apply smoothing to the movement
        delta = delta * AIMBOT_SMOOTHNESS
        
        -- Move the mouse instead of changing camera CFrame
        mousemoverel(delta.X, delta.Y)
    end
end

local function updateDrawings()
    -- Update FOV circle
    local mousePosition = UserInputService:GetMouseLocation()
    fovCircle.Position = mousePosition
    fovCircle.Visible = scriptActive and not isLobbyVisible()
    
    -- Update snapline and head circle if target exists
    if targetPlayer and targetPlayer.Character and isAimbotActive then
        -- Try to find the target hitbox (Head, HumanoidRootPart, etc.)
        local targetPart = targetPlayer.Character:FindFirstChild(targetHitbox)
        if not targetPart then
            targetPart = targetPlayer.Character:FindFirstChild("Head")
            if not targetPart then
                targetPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            end
        end
        
        if targetPart then
            local partPosition, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            
            if onScreen and partPosition.Z > 0 then
                -- Update snapline
                snapLine.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                snapLine.To = Vector2.new(partPosition.X, partPosition.Y)
                snapLine.Visible = true
                
                -- Update head circle
                headCircle.Position = Vector2.new(partPosition.X, partPosition.Y)
                headCircle.Visible = true
            else
                snapLine.Visible = false
                headCircle.Visible = false
            end
        else
            snapLine.Visible = false
            headCircle.Visible = false
        end
    else
        snapLine.Visible = false
        headCircle.Visible = false
    end
end

-- IMPROVED AUTOCLICK FUNCTION: This function has been modified to ensure continuous firing
local function setupAutoClick()
    -- Remove any existing connection to avoid duplicates
    if autoClickConnection then
        autoClickConnection:Disconnect()
        autoClickConnection = nil
    end
    
    -- Set up a new auto-click connection that runs on every frame (RenderStepped works better than Heartbeat for this)
    autoClickConnection = RunService.RenderStepped:Connect(function()
        -- Only fire if script is active, left mouse is held down, and we're not in lobby
        if scriptActive and isLeftMouseDown and not isLobbyVisible() then
            -- Calculate time since last click
            local currentTime = tick()
            local timeSinceLastClick = currentTime - lastClickTime
            
            -- Check if enough time has passed to click again based on the click interval
            if timeSinceLastClick >= CLICK_INTERVAL then
                -- Fire the click
                mouse1click()
                -- Update the last click time
                lastClickTime = currentTime
            end
        end
    end)
end

local function cleanupScript()
    -- Clean up drawings
    fovCircle:Remove()
    snapLine:Remove()
    headCircle:Remove()
    
    -- Disconnect any connections
    if autoClickConnection then
        autoClickConnection:Disconnect()
        autoClickConnection = nil
    end
    
    -- Reset state
    scriptActive = false
    isAimbotActive = false
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, isProcessed)
    if not scriptActive then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not isProcessed then
        isLeftMouseDown = true
        -- Initialize the lastClickTime to current time when mouse is first pressed
        lastClickTime = tick() - CLICK_INTERVAL  -- Subtract interval to allow an immediate first click
        setupAutoClick()
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not isProcessed then
        isRightMouseDown = true
        isAimbotActive = true
    elseif input.KeyCode == Enum.KeyCode.End then
        cleanupScript()
    elseif input.KeyCode == Enum.KeyCode.H and not isProcessed then
        -- Toggle hitbox (Head, HumanoidRootPart, Torso)
        if targetHitbox == "Head" then
            targetHitbox = "HumanoidRootPart"
            print("Target: HumanoidRootPart")
        elseif targetHitbox == "HumanoidRootPart" then
            targetHitbox = "Torso" -- Some games use Torso instead of UpperTorso
            print("Target: Torso")
        else
            targetHitbox = "Head"
            print("Target: Head")
        end
    elseif input.KeyCode == Enum.KeyCode.LeftBracket and not isProcessed then
        -- Decrease FOV
        FOV_RADIUS = math.max(50, FOV_RADIUS - 25)
        fovCircle.Radius = FOV_RADIUS
        print("FOV: " .. FOV_RADIUS)
    elseif input.KeyCode == Enum.KeyCode.RightBracket and not isProcessed then
        -- Increase FOV
        FOV_RADIUS = math.min(500, FOV_RADIUS + 25)
        fovCircle.Radius = FOV_RADIUS
        print("FOV: " .. FOV_RADIUS)
    end
end)

UserInputService.InputEnded:Connect(function(input, isProcessed)
    if not scriptActive then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not isProcessed then
        isLeftMouseDown = false
        -- We don't need to disconnect autoClickConnection here,
        -- it will just not fire clicks since isLeftMouseDown is false
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not isProcessed then
        isRightMouseDown = false
        isAimbotActive = false
    end
end)

-- Main update loop
RunService.RenderStepped:Connect(function()
    if not scriptActive then return end
    
    if not isLobbyVisible() then
        if isAimbotActive then
            targetPlayer = getClosestPlayerInFOV()
            if targetPlayer then
                lockOntoTarget() -- Use the new targeting function
            end
        else
            targetPlayer = nil
        end
        
        updateDrawings()
    else
        -- Hide all visual elements in lobby
        fovCircle.Visible = false
        snapLine.Visible = false
        headCircle.Visible = false
    end
end)

-- Print initialization message
print("=== Enhanced Aimbot with Continuous Firing loaded! ===")
print("- Hold left mouse button for continuous auto-fire")
print("- Hold right click to activate aimbot (no auto-fire)")
print("- Press H to toggle target hitbox (Head, HumanoidRootPart, Torso)")
print("- Press [ and ] to adjust FOV size")
print("- Press End to unload script")
