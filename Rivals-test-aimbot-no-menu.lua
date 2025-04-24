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

-- ESP Configuration
local ESP_ENABLED = true -- Toggle ESP features
local ESP_BOX_THICKNESS = 2 -- Thickness of ESP boxes
local ESP_PLAYER_COLOR = Color3.fromRGB(255, 0, 0) -- Red color for non-targeted players
local ESP_TARGET_COLOR = Color3.fromRGB(0, 255, 0) -- Green color for targeted player
local ESP_TEXT_SIZE = 14 -- Size of ESP text
local ESP_TEXT_COLOR = Color3.fromRGB(255, 255, 255) -- White color for ESP text
local BONE_ESP_ENABLED = true -- Toggle bone ESP feature
local BONE_ESP_THICKNESS = 2.5 -- Thickness of bone lines
local MAX_ESP_DISTANCE = 500 -- Maximum distance in studs to show ESP

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
snapLine.Thickness = 3.0
snapLine.Color = SNAPLINE_COLOR

local headCircle = Drawing.new("Circle")
headCircle.Visible = false
headCircle.Transparency = 0.7
headCircle.Color = HEAD_CIRCLE_COLOR
headCircle.Thickness = 2
headCircle.NumSides = 30
headCircle.Radius = HEAD_CIRCLE_RADIUS
headCircle.Filled = false

-- Table to store ESP drawing objects for each player
local espDrawings = {}

-- Set default to only show bone ESP (disabling other ESP types)
local DISPLAY_BOX_ESP = false
local DISPLAY_NAME_ESP = false 
local DISPLAY_TRACER_ESP = false

-- Function to check if a player is within ESP distance
local function isPlayerWithinDistance(player)
    if not player or not player.Character or not localPlayer or not localPlayer.Character then
        return false
    end
    
    -- Get character root parts
    local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not playerRoot or not localRoot then
        return false
    end
    
    -- Calculate distance
    local distance = (playerRoot.Position - localRoot.Position).Magnitude
    
    -- Return true if within range
    return distance <= MAX_ESP_DISTANCE
end

-- Function to check if a player is visible (not behind walls)
local function isPlayerBehindWall(player)
    if not player or not player.Character or not localPlayer or not localPlayer.Character then
        return true -- If no character, consider behind wall
    end
    
    -- Get character root parts
    local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not playerRoot or not localRoot then
        return true -- If no root part, consider behind wall
    end
    
    -- Calculate distance
    local distance = (playerRoot.Position - localRoot.Position).Magnitude
    
    -- Use ray casting to check visibility
    local direction = (playerRoot.Position - camera.CFrame.Position).Unit
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {localPlayer.Character, player.Character} -- Ignore self and target
    
    local raycastResult = workspace:Raycast(camera.CFrame.Position, direction * distance, rayParams)
    
    -- If the ray hit something, the player is behind a wall
    return raycastResult ~= nil
end

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

-- Define common bones for character rigs
local boneConnections = {
    -- Torso to limbs
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    -- Arms
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    -- Legs
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    -- R15 compatibility
    {"Head", "Torso"},
    {"Torso", "Right Arm"},
    {"Right Arm", "Right Hand"},
    {"Torso", "Left Arm"},
    {"Left Arm", "Left Hand"},
    {"Torso", "Right Leg"},
    {"Right Leg", "Right Foot"},
    {"Torso", "Left Leg"},
    {"Left Leg", "Left Foot"}
}

-- Initialize or get ESP drawings for a player
local function getPlayerESP(player)
    if not espDrawings[player] then
        espDrawings[player] = {
            box = Drawing.new("Square"),
            name = Drawing.new("Text"),
            tracer = Drawing.new("Line"),
            bones = {}
        }
        
        local box = espDrawings[player].box
        box.Visible = false
        box.Transparency = 0.7
        box.Color = ESP_PLAYER_COLOR
        box.Thickness = ESP_BOX_THICKNESS
        box.Filled = false
        
        local name = espDrawings[player].name
        name.Visible = false
        name.Transparency = 1
        name.Color = ESP_TEXT_COLOR
        name.Size = ESP_TEXT_SIZE
        name.Center = true
        name.Outline = true
        name.OutlineColor = Color3.fromRGB(0, 0, 0)
        name.Text = player.Name
        
        local tracer = espDrawings[player].tracer
        tracer.Visible = false
        tracer.Transparency = 0.7
        tracer.Color = ESP_PLAYER_COLOR
        tracer.Thickness = 1
        
        -- Initialize bone lines
        for _, _ in pairs(boneConnections) do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = BONE_ESP_THICKNESS
            line.Transparency = 0.6
            line.Color = ESP_PLAYER_COLOR
            table.insert(espDrawings[player].bones, line)
        end
    end
    
    return espDrawings[player]
end

-- Clean up ESP drawings for a player
local function cleanupPlayerESP(player)
    if espDrawings[player] then
        -- Remove standard ESP drawings
        if espDrawings[player].box then 
            espDrawings[player].box:Remove() 
            espDrawings[player].box = nil
        end
        
        if espDrawings[player].name then 
            espDrawings[player].name:Remove() 
            espDrawings[player].name = nil
        end
        
        if espDrawings[player].tracer then 
            espDrawings[player].tracer:Remove() 
            espDrawings[player].tracer = nil
        end
        
        -- Remove bone lines
        if espDrawings[player].bones then
            for i, bone in pairs(espDrawings[player].bones) do
                if bone then 
                    bone:Remove() 
                    espDrawings[player].bones[i] = nil
                end
            end
            espDrawings[player].bones = nil
        end
        
        espDrawings[player] = nil
    end
end

-- Function to clear all bone ESP drawings (hide them)
local function clearAllBoneESP()
    for _, playerESP in pairs(espDrawings) do
        if playerESP and playerESP.bones then
            for _, bone in pairs(playerESP.bones) do
                if bone then
                    bone.Visible = false
                end
            end
        end
    end
end

-- Update ESP visuals for all players
local function updateESP()
    -- Clean up ESP for players who left
    for player, _ in pairs(espDrawings) do
        if not Players:FindFirstChild(player.Name) then
            cleanupPlayerESP(player)
        end
    end
    
    -- Don't show ESP in lobby
    if isLobbyVisible() then
        clearAllBoneESP() -- Hide all bone ESP when in lobby
        
        for _, drawings in pairs(espDrawings) do
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.tracer then drawings.tracer.Visible = false end
        end
        return
    end
    
    -- First ensure all bone ESP are hidden by default
    -- They will only be shown if conditions are met below
    clearAllBoneESP()
    
    -- Update ESP for each player
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local esp = getPlayerESP(player)
            local humanoidRootPart = player.Character.HumanoidRootPart
            
            -- Determine if player is the target
            local isTarget = (player == targetPlayer)
            
            -- Check if player is within distance
            local isWithinDistance = isPlayerWithinDistance(player)
            
            -- Check if any part of player is on screen
            local rootPosition, onScreen = camera:WorldToViewportPoint(humanoidRootPart.Position)
            
            -- Only proceed if player is on screen and within distance
            if onScreen and rootPosition.Z > 0 and ESP_ENABLED and isWithinDistance then
                -- Always hide box ESP
                if esp.box then esp.box.Visible = false end
                
                -- Always hide name ESP
                if esp.name then esp.name.Visible = false end
                
                -- Always hide tracer ESP
                if esp.tracer then esp.tracer.Visible = false end
                
                -- Draw bone ESP if enabled
                if BONE_ESP_ENABLED and esp.bones then
                    local boneIndex = 1
                    
                    for _, connection in pairs(boneConnections) do
                        if boneIndex <= #esp.bones then
                            local bone = esp.bones[boneIndex]
                            if bone then
                                local part1 = player.Character:FindFirstChild(connection[1])
                                local part2 = player.Character:FindFirstChild(connection[2])
                                
                                if part1 and part2 then
                                    local p1, onScreen1 = camera:WorldToViewportPoint(part1.Position)
                                    local p2, onScreen2 = camera:WorldToViewportPoint(part2.Position)
                                    
                                    if onScreen1 and onScreen2 and p1.Z > 0 and p2.Z > 0 then
                                        bone.From = Vector2.new(p1.X, p1.Y)
                                        bone.To = Vector2.new(p2.X, p2.Y)
                                        bone.Visible = true
                                        bone.Color = isTarget and ESP_TARGET_COLOR or ESP_PLAYER_COLOR
                                    else
                                        bone.Visible = false
                                    end
                                else
                                    bone.Visible = false
                                end
                            end
                        end
                        
                        boneIndex = boneIndex + 1
                    end
                end
            else
                -- Hide ESP if player is off screen or out of range
                if esp.box then esp.box.Visible = false end
                if esp.name then esp.name.Visible = false end
                if esp.tracer then esp.tracer.Visible = false end
                
                -- Hide all bones for this player
                if esp.bones then
                    for _, bone in pairs(esp.bones) do
                        if bone then
                            bone.Visible = false
                        end
                    end
                end
            end
        end
    end
end

local function updateDrawings()
    -- Update FOV circle
    local mousePosition = UserInputService:GetMouseLocation()
    fovCircle.Position = mousePosition
    fovCircle.Visible = scriptActive and not isLobbyVisible()
    
    -- Update snapline and head circle
    -- Always show snapline to closest player (not just when aiming)
    if not isLobbyVisible() then
        -- Get closest player for snapline (if not already targeting someone)
        local snapLineTarget = targetPlayer
        if not snapLineTarget then
            snapLineTarget = getClosestPlayerInFOV()
        end
        
        if snapLineTarget and snapLineTarget.Character then
            -- Try to find the target hitbox (Head, HumanoidRootPart, etc.)
            local targetPart = snapLineTarget.Character:FindFirstChild(targetHitbox)
            if not targetPart then
                targetPart = snapLineTarget.Character:FindFirstChild("Head")
                if not targetPart then
                    targetPart = snapLineTarget.Character:FindFirstChild("HumanoidRootPart")
                end
            end
            
            if targetPart then
                local partPosition, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen and partPosition.Z > 0 then
                    -- Check if player is within distance (ignore wall check for snap line)
                    local isWithinDistance = isPlayerWithinDistance(snapLineTarget)
                    
                    -- Update snapline - only check distance, not walls
                    snapLine.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                    snapLine.To = Vector2.new(partPosition.X, partPosition.Y) 
                    snapLine.Visible = isWithinDistance
                    
                    -- Update head circle - only visible when actually targeting
                    headCircle.Position = Vector2.new(partPosition.X, partPosition.Y)
                    headCircle.Visible = isWithinDistance and (snapLineTarget == targetPlayer) and isAimbotActive
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
    else
        snapLine.Visible = false
        headCircle.Visible = false
    end
    
    -- Update ESP for all players
    updateESP()
end

-- AUTOCLICK FUNCTION
local function setupAutoClick()
    -- Remove any existing connection to avoid duplicates
    if autoClickConnection then
        autoClickConnection:Disconnect()
        autoClickConnection = nil
    end
    
    -- Set up a new auto-click connection that runs on every frame
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
    print("Cleaning up script...")
    
    -- First hide all ESP elements to ensure visual cleanup
    clearAllBoneESP()
    
    -- Make core visuals invisible immediately
    if fovCircle then fovCircle.Visible = false end
    if snapLine then snapLine.Visible = false end
    if headCircle then headCircle.Visible = false end
    
    -- Clean up standard drawings
    if fovCircle then 
        fovCircle:Remove() 
        fovCircle = nil
    end
    
    if snapLine then 
        snapLine:Remove() 
        snapLine = nil
    end
    
    if headCircle then 
        headCircle:Remove() 
        headCircle = nil
    end
    
    -- Clean up ESP drawings - use our enhanced cleanup method
    for player, _ in pairs(espDrawings) do
        cleanupPlayerESP(player)
    end
    
    -- Clear the ESP drawings table
    table.clear(espDrawings)
    
    -- Disconnect any connections
    if autoClickConnection then
        autoClickConnection:Disconnect()
        autoClickConnection = nil
    end
    
    -- Reset state
    scriptActive = false
    isAimbotActive = false
    
    print("Script cleanup complete - all elements have been removed")
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
    elseif input.KeyCode == Enum.KeyCode.E and not isProcessed then
        -- Toggle ESP
        ESP_ENABLED = not ESP_ENABLED
        
        -- Clear all bone ESP immediately when disabling
        if not ESP_ENABLED then
            clearAllBoneESP()
        end
        
        print("ESP: " .. (ESP_ENABLED and "Enabled" or "Disabled"))
    elseif input.KeyCode == Enum.KeyCode.B and not isProcessed then
        -- Toggle Bone ESP
        BONE_ESP_ENABLED = not BONE_ESP_ENABLED
        
        -- Clear all bone ESP immediately when disabling
        if not BONE_ESP_ENABLED then
            clearAllBoneESP()
        end
        
        print("Bone ESP: " .. (BONE_ESP_ENABLED and "Enabled" or "Disabled"))
    elseif input.KeyCode == Enum.KeyCode.Minus and not isProcessed then
        -- Decrease ESP distance
        MAX_ESP_DISTANCE = math.max(100, MAX_ESP_DISTANCE - 100)
        print("ESP Distance: " .. MAX_ESP_DISTANCE .. " studs")
    elseif input.KeyCode == Enum.KeyCode.Equals and not isProcessed then
        -- Increase ESP distance
        MAX_ESP_DISTANCE = math.min(2000, MAX_ESP_DISTANCE + 100)
        print("ESP Distance: " .. MAX_ESP_DISTANCE .. " studs")
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

-- Handle players joining and leaving
Players.PlayerAdded:Connect(function(player)
    -- Initialize ESP for new players
    if player ~= localPlayer then
        getPlayerESP(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    -- Clean up ESP when players leave
    cleanupPlayerESP(player)
end)

-- Main update loop
RunService.RenderStepped:Connect(function()
    if not scriptActive then return end
    
    if not isLobbyVisible() then
        if isAimbotActive then
            targetPlayer = getClosestPlayerInFOV()
            if targetPlayer then
                lockOntoTarget() -- Use the targeting function
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
        
        -- Hide all ESP in lobby
        for _, drawings in pairs(espDrawings) do
            drawings.box.Visible = false
            drawings.name.Visible = false
            drawings.tracer.Visible = false
        end
    end
end)


print("- Hold right click to activate aimbot")
print("- Press H to toggle target hitbox (Head, HumanoidRootPart, Torso)")
print("- Press [ and ] to adjust FOV size")
print("- Press E to toggle all ESP features")
print("- Press B to toggle bone ESP visualization")
print("- Press - and = to adjust ESP distance")
print("- Press End to unload script")
print("- ESP features: ")
print("  • Only shows players within " .. MAX_ESP_DISTANCE .. " studs")
print("  • BONE ESP ONLY - showing player skeletons (thickness 2.5)")
print("  • Snap line thickness increased to 3.0")
print("  • Improved bone ESP rendering & cleanup system")
print("  • Red bones for regular players, green for targets")
