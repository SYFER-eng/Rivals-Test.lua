--[[
    Rivals Aimbot & ESP with UI (External Executor Version)
    Features:
    - Customizable aimbot with FOV circle
    - ESP with box, name, tracer, and bone options
    - Configurable settings through UI with toggle buttons and sliders
    - Key bindings: Insert (toggle UI), End (unload script)
    - Designed for external executors
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Initialize settings
local Settings = {
    -- Aimbot Settings
    AimbotEnabled = false,
    AutoClickEnabled = false,
    ShowFOV = true,
    FOVRadius = 200,
    AimbotSmoothness = 0.25,
    ClickInterval = 0.05,
    TargetHitbox = "Head",
    
    -- ESP Settings
    ESPEnabled = true,
    BoxESP = false,
    NameESP = false,
    TracerESP = false,
    BoneESP = true,
    MaxESPDistance = 500,
    
    -- Visual Settings
    FOVColor = Color3.fromRGB(255, 255, 255),
    SnaplineColor = Color3.fromRGB(255, 0, 0),
    HeadCircleColor = Color3.fromRGB(0, 255, 0),
    HeadCircleRadius = 8,
    ESPPlayerColor = Color3.fromRGB(255, 0, 0),
    ESPTargetColor = Color3.fromRGB(0, 255, 0),
    ESPTextSize = 14,
    ESPTextColor = Color3.fromRGB(255, 255, 255),
    ESPBoxThickness = 2,
    BoneESPThickness = 2.5
}

-- State variables
local TargetPlayer = nil
local IsAimbotActive = false
local IsRightMouseDown = false
local IsLeftMouseDown = false
local AutoClickConnection = nil
local LastClickTime = 0
local ScriptActive = true
local UIVisible = true

-- Drawing objects
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = Settings.ShowFOV
FOVCircle.Transparency = 0.7
FOVCircle.Color = Settings.FOVColor
FOVCircle.Thickness = 2
FOVCircle.NumSides = 64
FOVCircle.Radius = Settings.FOVRadius
FOVCircle.Filled = false

local SnapLine = Drawing.new("Line")
SnapLine.Visible = false
SnapLine.Thickness = 3.0
SnapLine.Color = Settings.SnaplineColor

local HeadCircle = Drawing.new("Circle")
HeadCircle.Visible = false
HeadCircle.Transparency = 0.7
HeadCircle.Color = Settings.HeadCircleColor
HeadCircle.Thickness = 2
HeadCircle.NumSides = 30
HeadCircle.Radius = Settings.HeadCircleRadius
HeadCircle.Filled = false

-- Table to store ESP drawing objects for each player
local ESPDrawings = {}

-- Define common bones for character rigs
local BoneConnections = {
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

-- Function to check if a player is within ESP distance
local function IsPlayerWithinDistance(player)
    if not player or not player.Character or not LocalPlayer or not LocalPlayer.Character then
        return false
    end
    
    -- Get character root parts
    local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not playerRoot or not localRoot then
        return false
    end
    
    -- Calculate distance
    local distance = (playerRoot.Position - localRoot.Position).Magnitude
    
    -- Return true if within range
    return distance <= Settings.MaxESPDistance
end

-- Function to check if a player is visible (not behind walls)
local function IsPlayerBehindWall(player)
    if not player or not player.Character or not LocalPlayer or not LocalPlayer.Character then
        return true -- If no character, consider behind wall
    end
    
    -- Get character root parts
    local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not playerRoot or not localRoot then
        return true -- If no root part, consider behind wall
    end
    
    -- Calculate distance
    local distance = (playerRoot.Position - localRoot.Position).Magnitude
    
    -- Use ray casting to check visibility
    local direction = (playerRoot.Position - Camera.CFrame.Position).Unit
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, player.Character} -- Ignore self and target
    
    local raycastResult = workspace:Raycast(Camera.CFrame.Position, direction * distance, rayParams)
    
    -- If the ray hit something, the player is behind a wall
    return raycastResult ~= nil
end

-- Check if in lobby (customize based on your game)
local function IsInLobby()
    -- Try-catch for compatibility with different games
    local success, result = pcall(function()
        -- Check for specific Rivals UI elements
        if workspace:FindFirstChild("LobbyFolder") then
            return true
        end
        
        -- Check player state
        if LocalPlayer:FindFirstChild("InLobby") and LocalPlayer.InLobby.Value then
            return true
        end
        
        return false
    end)
    
    return success and result
end

local function GetClosestPlayerInFOV()
    local closestPlayer = nil
    local shortestDistance = Settings.FOVRadius
    local mousePosition = UserInputService:GetMouseLocation()
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            -- Try to find the target hitbox
            local hitboxPart = player.Character:FindFirstChild(Settings.TargetHitbox)
            if not hitboxPart then
                -- Fallback to Head if specified hitbox doesn't exist
                hitboxPart = player.Character:FindFirstChild("Head")
                if not hitboxPart then
                    -- Last resort - try HumanoidRootPart
                    hitboxPart = player.Character:FindFirstChild("HumanoidRootPart")
                end
            end
            
            if hitboxPart then
                local hitboxPosition, onScreen = Camera:WorldToViewportPoint(hitboxPart.Position)
                
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

local function LockOntoTarget()
    if not TargetPlayer or not TargetPlayer.Character or not IsAimbotActive then return end
    
    -- Try to find the target hitbox
    local hitboxPart = TargetPlayer.Character:FindFirstChild(Settings.TargetHitbox)
    if not hitboxPart then
        -- Fallback to Head if specified hitbox doesn't exist
        hitboxPart = TargetPlayer.Character:FindFirstChild("Head")
        if not hitboxPart then
            -- Last resort - try HumanoidRootPart
            hitboxPart = TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hitboxPart then return end -- No valid target part
        end
    end
    
    -- Get the target's position on screen
    local targetPosition, onScreen = Camera:WorldToViewportPoint(hitboxPart.Position)
    
    if onScreen and targetPosition.Z > 0 then
        -- Calculate the delta between target position and screen center
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local targetScreenPos = Vector2.new(targetPosition.X, targetPosition.Y)
        local delta = targetScreenPos - screenCenter
        
        -- Apply smoothing to the movement
        delta = delta * Settings.AimbotSmoothness
        
        -- Move the mouse instead of changing camera CFrame
        mousemoverel(delta.X, delta.Y)
    end
end

-- Initialize or get ESP drawings for a player
local function GetPlayerESP(player)
    if not ESPDrawings[player] then
        ESPDrawings[player] = {
            box = Drawing.new("Square"),
            name = Drawing.new("Text"),
            tracer = Drawing.new("Line"),
            bones = {}
        }
        
        local box = ESPDrawings[player].box
        box.Visible = false
        box.Transparency = 0.7
        box.Color = Settings.ESPPlayerColor
        box.Thickness = Settings.ESPBoxThickness
        box.Filled = false
        
        local name = ESPDrawings[player].name
        name.Visible = false
        name.Transparency = 1
        name.Color = Settings.ESPTextColor
        name.Size = Settings.ESPTextSize
        name.Center = true
        name.Outline = true
        name.OutlineColor = Color3.fromRGB(0, 0, 0)
        name.Text = player.Name
        
        local tracer = ESPDrawings[player].tracer
        tracer.Visible = false
        tracer.Transparency = 0.7
        tracer.Color = Settings.ESPPlayerColor
        tracer.Thickness = 1
        
        -- Initialize bone lines
        for _, _ in pairs(BoneConnections) do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = Settings.BoneESPThickness
            line.Transparency = 0.6
            line.Color = Settings.ESPPlayerColor
            table.insert(ESPDrawings[player].bones, line)
        end
    end
    
    return ESPDrawings[player]
end

-- Clean up ESP drawings for a player
local function CleanupPlayerESP(player)
    if ESPDrawings[player] then
        -- Remove standard ESP drawings
        if ESPDrawings[player].box then 
            ESPDrawings[player].box:Remove()
            ESPDrawings[player].box = nil
        end
        
        if ESPDrawings[player].name then 
            ESPDrawings[player].name:Remove()
            ESPDrawings[player].name = nil
        end
        
        if ESPDrawings[player].tracer then 
            ESPDrawings[player].tracer:Remove()
            ESPDrawings[player].tracer = nil
        end
        
        -- Remove bone lines
        if ESPDrawings[player].bones then
            for i, bone in pairs(ESPDrawings[player].bones) do
                if bone then 
                    bone:Remove()
                    ESPDrawings[player].bones[i] = nil
                end
            end
            ESPDrawings[player].bones = nil
        end
        
        ESPDrawings[player] = nil
    end
end

-- Function to clear all bone ESP drawings (hide them)
local function ClearAllBoneESP()
    for _, playerESP in pairs(ESPDrawings) do
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
local function UpdateESP()
    -- Clean up ESP for players who left
    for player, _ in pairs(ESPDrawings) do
        if not Players:FindFirstChild(player.Name) then
            CleanupPlayerESP(player)
        end
    end
    
    -- Don't show ESP in lobby
    if IsInLobby() then
        ClearAllBoneESP() -- Hide all bone ESP when in lobby
        
        for _, drawings in pairs(ESPDrawings) do
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.tracer then drawings.tracer.Visible = false end
        end
        return
    end
    
    -- First ensure all bone ESP are hidden by default
    -- They will only be shown if conditions are met below
    ClearAllBoneESP()
    
    -- Update ESP for each player
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local esp = GetPlayerESP(player)
            local humanoidRootPart = player.Character.HumanoidRootPart
            
            -- Determine if player is the target
            local isTarget = (player == TargetPlayer)
            
            -- Check if player is within distance
            local isWithinDistance = IsPlayerWithinDistance(player)
            
            -- Check if any part of player is on screen
            local rootPosition, onScreen = Camera:WorldToViewportPoint(humanoidRootPart.Position)
            
            -- Only proceed if player is on screen and within distance
            if onScreen and rootPosition.Z > 0 and Settings.ESPEnabled and isWithinDistance then
                -- Box ESP
                if Settings.BoxESP and esp.box then
                    -- Calculate box dimensions
                    local head = player.Character:FindFirstChild("Head")
                    if head then
                        local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                        local legPos = Camera:WorldToViewportPoint(humanoidRootPart.Position - Vector3.new(0, 3, 0))
                        
                        local boxSize = Vector2.new(1000 / rootPosition.Z, headPos.Y - legPos.Y)
                        local boxPosition = Vector2.new(rootPosition.X - boxSize.X / 2, rootPosition.Y - boxSize.Y / 2)
                        
                        esp.box.Size = boxSize
                        esp.box.Position = boxPosition
                        esp.box.Visible = true
                        esp.box.Color = isTarget and Settings.ESPTargetColor or Settings.ESPPlayerColor
                    end
                else
                    esp.box.Visible = false
                end
                
                -- Name ESP
                if Settings.NameESP and esp.name then
                    local head = player.Character:FindFirstChild("Head")
                    if head then
                        local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                        
                        esp.name.Position = Vector2.new(headPos.X, headPos.Y - 20)
                        esp.name.Visible = true
                        esp.name.Color = isTarget and Settings.ESPTargetColor or Settings.ESPTextColor
                        
                        -- Include distance in the name display
                        local distance = math.floor((humanoidRootPart.Position - Camera.CFrame.Position).Magnitude)
                        esp.name.Text = string.format("%s [%dm]", player.Name, distance)
                    end
                else
                    esp.name.Visible = false
                end
                
                -- Tracer ESP
                if Settings.TracerESP and esp.tracer then
                    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    esp.tracer.From = screenCenter
                    esp.tracer.To = Vector2.new(rootPosition.X, rootPosition.Y)
                    esp.tracer.Visible = true
                    esp.tracer.Color = isTarget and Settings.ESPTargetColor or Settings.ESPPlayerColor
                else
                    esp.tracer.Visible = false
                end
                
                -- Bone ESP
                if Settings.BoneESP and esp.bones then
                    local boneIndex = 1
                    
                    for _, connection in pairs(BoneConnections) do
                        if boneIndex <= #esp.bones then
                            local bone = esp.bones[boneIndex]
                            if bone then
                                local part1 = player.Character:FindFirstChild(connection[1])
                                local part2 = player.Character:FindFirstChild(connection[2])
                                
                                if part1 and part2 then
                                    local p1, onScreen1 = Camera:WorldToViewportPoint(part1.Position)
                                    local p2, onScreen2 = Camera:WorldToViewportPoint(part2.Position)
                                    
                                    if onScreen1 and onScreen2 and p1.Z > 0 and p2.Z > 0 then
                                        bone.From = Vector2.new(p1.X, p1.Y)
                                        bone.To = Vector2.new(p2.X, p2.Y)
                                        bone.Visible = true
                                        bone.Color = isTarget and Settings.ESPTargetColor or Settings.ESPPlayerColor
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
                else
                    for _, bone in pairs(esp.bones) do
                        bone.Visible = false
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

local function UpdateDrawings()
    -- Update FOV circle
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Visible = Settings.ShowFOV and ScriptActive and not IsInLobby()
    FOVCircle.Radius = Settings.FOVRadius
    
    -- Update snapline and head circle
    if ScriptActive and not IsInLobby() then
        -- Get closest player for snapline
        local snapLineTarget = TargetPlayer
        if not snapLineTarget then
            snapLineTarget = GetClosestPlayerInFOV()
        end
        
        if snapLineTarget and snapLineTarget.Character then
            -- Try to find the target hitbox
            local targetPart = snapLineTarget.Character:FindFirstChild(Settings.TargetHitbox)
            if not targetPart then
                targetPart = snapLineTarget.Character:FindFirstChild("Head")
                if not targetPart then
                    targetPart = snapLineTarget.Character:FindFirstChild("HumanoidRootPart")
                end
            end
            
            if targetPart then
                local partPosition, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen and partPosition.Z > 0 then
                    -- Check if player is within distance
                    local isWithinDistance = IsPlayerWithinDistance(snapLineTarget)
                    
                    -- Update snapline
                    SnapLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    SnapLine.To = Vector2.new(partPosition.X, partPosition.Y) 
                    SnapLine.Visible = isWithinDistance and Settings.AimbotEnabled
                    
                    -- Update head circle
                    HeadCircle.Position = Vector2.new(partPosition.X, partPosition.Y)
                    HeadCircle.Visible = isWithinDistance and (snapLineTarget == TargetPlayer) and IsAimbotActive
                else
                    SnapLine.Visible = false
                    HeadCircle.Visible = false
                end
            else
                SnapLine.Visible = false
                HeadCircle.Visible = false
            end
        else
            SnapLine.Visible = false
            HeadCircle.Visible = false
        end
    else
        SnapLine.Visible = false
        HeadCircle.Visible = false
    end
    
    -- Update ESP for all players
    UpdateESP()
end

-- AUTOCLICK FUNCTION
local function SetupAutoClick()
    -- Remove any existing connection to avoid duplicates
    if AutoClickConnection then
        AutoClickConnection:Disconnect()
        AutoClickConnection = nil
    end
    
    -- Only set up auto-click if it's enabled
    if Settings.AutoClickEnabled then
        -- Set up a new auto-click connection that runs on every frame
        AutoClickConnection = RunService.RenderStepped:Connect(function()
            -- Only fire if script is active, auto click is enabled, left mouse is held down, and we're not in lobby
            if ScriptActive and Settings.AutoClickEnabled and IsLeftMouseDown and not IsInLobby() then
                -- Calculate time since last click
                local currentTime = tick()
                local timeSinceLastClick = currentTime - LastClickTime
                
                -- Check if enough time has passed to click again based on the click interval
                if timeSinceLastClick >= Settings.ClickInterval then
                    -- Fire the click
                    mouse1click()
                    -- Update the last click time
                    LastClickTime = currentTime
                end
            end
        end)
    end
end

local function CleanupScript()
    print("Cleaning up script...")
    
    -- First hide UI immediately to give user visual feedback
    if MainFrame then
        MainFrame.Visible = false
    end
    
    -- Hide all ESP elements to ensure visual cleanup
    ClearAllBoneESP()
    
    -- Make core visuals invisible immediately
    if FOVCircle then FOVCircle.Visible = false end
    if SnapLine then SnapLine.Visible = false end
    if HeadCircle then HeadCircle.Visible = false end
    
    -- Clean up standard drawings
    if FOVCircle then 
        FOVCircle:Remove()
        FOVCircle = nil
    end
    
    if SnapLine then 
        SnapLine:Remove()
        SnapLine = nil
    end
    
    if HeadCircle then 
        HeadCircle:Remove()
        HeadCircle = nil
    end
    
    -- Clean up ESP drawings
    for player, _ in pairs(ESPDrawings) do
        CleanupPlayerESP(player)
    end
    
    -- Clear the ESP drawings table
    table.clear(ESPDrawings)
    
    -- Disconnect any connections
    if AutoClickConnection then
        AutoClickConnection:Disconnect()
        AutoClickConnection = nil
    end
    
    -- Disconnect RunService connections (needed to fully stop script execution)
    for _, connection in pairs(getconnections(RunService.RenderStepped)) do
        connection:Disconnect()
    end
    
    for _, connection in pairs(getconnections(RunService.Heartbeat)) do
        connection:Disconnect()
    end
    
    -- Disconnect input connections to prevent lingering callbacks
    for _, connection in pairs(getconnections(UserInputService.InputBegan)) do
        connection:Disconnect()
    end
    
    for _, connection in pairs(getconnections(UserInputService.InputEnded)) do
        connection:Disconnect()
    end
    
    -- Remove UI (destroy both notification and main GUI)
    if Gui then
        Gui:Destroy()
        Gui = nil
    end
    
    -- Remove any notification GUI that might be active
    if game:GetService("CoreGui"):FindFirstChild("AimbotNotification") then
        game:GetService("CoreGui").AimbotNotification:Destroy()
    end
    
    -- Reset state
    ScriptActive = false
    IsAimbotActive = false
    UIVisible = false
    
    print("Script cleanup complete - all elements have been removed")
end

-- Create UI
local Gui = Instance.new("ScreenGui")
Gui.Name = "RivalsAimbotUI" 
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Try to use CoreGui for better hiding
local success, err = pcall(function()
    Gui.Parent = game:GetService("CoreGui")
end)

if not success then
    Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Main frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = UIVisible
MainFrame.Parent = Gui

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleText = Instance.new("TextLabel")
TitleText.Name = "Title"
TitleText.Size = UDim2.new(1, -60, 1, 0)
TitleText.Position = UDim2.new(0, 10, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.SourceSansBold
TitleText.Text = "Rivals Aimbot"
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- Close button
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -30, 0, 0)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 16
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.Parent = TitleBar

-- Tab buttons container
local TabContainer = Instance.new("Frame")
TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, 0, 0, 30)
TabContainer.Position = UDim2.new(0, 0, 0, 30)
TabContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame

-- Create tab buttons
local AimbotTab = Instance.new("TextButton")
AimbotTab.Name = "AimbotTab"
AimbotTab.Size = UDim2.new(0.33, 0, 1, 0)
AimbotTab.Position = UDim2.new(0, 0, 0, 0)
AimbotTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
AimbotTab.BorderSizePixel = 0
AimbotTab.Text = "Aimbot"
AimbotTab.TextColor3 = Color3.fromRGB(255, 255, 255)
AimbotTab.TextSize = 14
AimbotTab.Font = Enum.Font.SourceSansBold
AimbotTab.Parent = TabContainer

local ESPTab = Instance.new("TextButton")
ESPTab.Name = "ESPTab"
ESPTab.Size = UDim2.new(0.34, 0, 1, 0)
ESPTab.Position = UDim2.new(0.33, 0, 0, 0)
ESPTab.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
ESPTab.BorderSizePixel = 0
ESPTab.Text = "ESP"
ESPTab.TextColor3 = Color3.fromRGB(255, 255, 255)
ESPTab.TextSize = 14
ESPTab.Font = Enum.Font.SourceSansBold
ESPTab.Parent = TabContainer

local MiscTab = Instance.new("TextButton")
MiscTab.Name = "MiscTab"
MiscTab.Size = UDim2.new(0.33, 0, 1, 0)
MiscTab.Position = UDim2.new(0.67, 0, 0, 0)
MiscTab.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MiscTab.BorderSizePixel = 0
MiscTab.Text = "Misc"
MiscTab.TextColor3 = Color3.fromRGB(255, 255, 255)
MiscTab.TextSize = 14
MiscTab.Font = Enum.Font.SourceSansBold
MiscTab.Parent = TabContainer

-- Create tab content frames
local AimbotContent = Instance.new("Frame")
AimbotContent.Name = "AimbotContent"
AimbotContent.Size = UDim2.new(1, 0, 1, -60)
AimbotContent.Position = UDim2.new(0, 0, 0, 60)
AimbotContent.BackgroundTransparency = 1
AimbotContent.Visible = true
AimbotContent.Parent = MainFrame

local ESPContent = Instance.new("Frame")
ESPContent.Name = "ESPContent"
ESPContent.Size = UDim2.new(1, 0, 1, -60)
ESPContent.Position = UDim2.new(0, 0, 0, 60)
ESPContent.BackgroundTransparency = 1
ESPContent.Visible = false
ESPContent.Parent = MainFrame

local MiscContent = Instance.new("Frame")
MiscContent.Name = "MiscContent"
MiscContent.Size = UDim2.new(1, 0, 1, -60)
MiscContent.Position = UDim2.new(0, 0, 0, 60)
MiscContent.BackgroundTransparency = 1
MiscContent.Visible = false
MiscContent.Parent = MainFrame

-- Function to create toggle buttons
local function CreateToggle(parent, text, position, initialValue, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = text .. "Toggle"
    toggleFrame.Size = UDim2.new(0.9, 0, 0, 30)
    toggleFrame.Position = position
    toggleFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = parent
    
    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Name = "Label"
    toggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    toggleLabel.Position = UDim2.new(0, 10, 0, 0)
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleLabel.TextSize = 14
    toggleLabel.Font = Enum.Font.SourceSans
    toggleLabel.Text = text
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    toggleLabel.Parent = toggleFrame
    
    local toggleButton = Instance.new("Frame")
    toggleButton.Name = "Button"
    toggleButton.Size = UDim2.new(0, 40, 0, 20)
    toggleButton.Position = UDim2.new(0.8, 0, 0.5, -10)
    toggleButton.BackgroundColor3 = initialValue and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = toggleFrame
    
    local uiCornerButton = Instance.new("UICorner")
    uiCornerButton.CornerRadius = UDim.new(1, 0)
    uiCornerButton.Parent = toggleButton
    
    local toggleIndicator = Instance.new("Frame")
    toggleIndicator.Name = "Indicator"
    toggleIndicator.Size = UDim2.new(0, 16, 0, 16)
    toggleIndicator.Position = UDim2.new(initialValue and 0.6 or 0, 2, 0, 2)
    toggleIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggleIndicator.BorderSizePixel = 0
    toggleIndicator.Parent = toggleButton
    
    local uiCornerIndicator = Instance.new("UICorner")
    uiCornerIndicator.CornerRadius = UDim.new(1, 0)
    uiCornerIndicator.Parent = toggleIndicator
    
    local clickArea = Instance.new("TextButton")
    clickArea.Name = "ClickArea"
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.Parent = toggleFrame
    
    clickArea.MouseButton1Click:Connect(function()
        initialValue = not initialValue
        toggleButton.BackgroundColor3 = initialValue and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
        
        local newPosition = initialValue and UDim2.new(0.6, 0, 0, 2) or UDim2.new(0, 2, 0, 2)
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(toggleIndicator, tweenInfo, {Position = newPosition})
        tween:Play()
        
        callback(initialValue)
    end)
    
    -- Return the frame for potential later reference
    return toggleFrame
end

-- Function to create sliders
local function CreateSlider(parent, text, min, max, default, position, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = text .. "Slider"
    sliderFrame.Size = UDim2.new(0.9, 0, 0, 50)
    sliderFrame.Position = position
    sliderFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = parent
    
    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Name = "Label"
    sliderLabel.Size = UDim2.new(1, -20, 0, 20)
    sliderLabel.Position = UDim2.new(0, 10, 0, 5)
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    sliderLabel.TextSize = 14
    sliderLabel.Font = Enum.Font.SourceSans
    sliderLabel.Text = text .. ": " .. default
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    sliderLabel.Parent = sliderFrame
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "Background"
    sliderBg.Size = UDim2.new(0.9, 0, 0, 6)
    sliderBg.Position = UDim2.new(0.05, 0, 0.7, 0)
    sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = sliderFrame
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "Fill"
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    
    local sliderKnob = Instance.new("Frame")
    sliderKnob.Name = "Knob"
    sliderKnob.Size = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position = UDim2.new((default - min) / (max - min), -8, 0, -5)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderKnob.BorderSizePixel = 0
    sliderKnob.Parent = sliderBg
    
    local uiCornerKnob = Instance.new("UICorner")
    uiCornerKnob.CornerRadius = UDim.new(1, 0)
    uiCornerKnob.Parent = sliderKnob
    
    local sliderButton = Instance.new("TextButton")
    sliderButton.Name = "Button"
    sliderButton.Size = UDim2.new(1, 0, 1, 0)
    sliderButton.BackgroundTransparency = 1
    sliderButton.Text = ""
    sliderButton.Parent = sliderBg
    
    local isDragging = false
    local currentValue = default
    
    local function updateSlider(input)
        local sizeX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(sizeX, 0, 1, 0)
        sliderKnob.Position = UDim2.new(sizeX, -8, 0, -5)
        
        currentValue = min + (max - min) * sizeX
        currentValue = math.floor(currentValue * 100) / 100 -- Round to 2 decimal places
        
        sliderLabel.Text = text .. ": " .. currentValue
        callback(currentValue)
    end
    
    sliderButton.MouseButton1Down:Connect(function(input)
        isDragging = true
        updateSlider(input)
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
            updateSlider(input)
        end
    end)
    
    return sliderFrame
end

-- Function to create dropdown
local function CreateDropdown(parent, text, options, default, position, callback)
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Name = text .. "Dropdown"
    dropdownFrame.Size = UDim2.new(0.9, 0, 0, 60)
    dropdownFrame.Position = position
    dropdownFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.Parent = parent
    
    local dropdownLabel = Instance.new("TextLabel")
    dropdownLabel.Name = "Label"
    dropdownLabel.Size = UDim2.new(1, -20, 0, 20)
    dropdownLabel.Position = UDim2.new(0, 10, 0, 5)
    dropdownLabel.BackgroundTransparency = 1
    dropdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownLabel.TextSize = 14
    dropdownLabel.Font = Enum.Font.SourceSans
    dropdownLabel.Text = text
    dropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
    dropdownLabel.Parent = dropdownFrame
    
    local dropdownButton = Instance.new("TextButton")
    dropdownButton.Name = "Button"
    dropdownButton.Size = UDim2.new(0.9, 0, 0, 25)
    dropdownButton.Position = UDim2.new(0.05, 0, 0.55, 0)
    dropdownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    dropdownButton.BorderSizePixel = 0
    dropdownButton.Text = default
    dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownButton.TextSize = 14
    dropdownButton.Font = Enum.Font.SourceSans
    dropdownButton.Parent = dropdownFrame
    
    local dropdownList = Instance.new("Frame")
    dropdownList.Name = "List"
    dropdownList.Size = UDim2.new(0.9, 0, 0, 25 * #options)
    dropdownList.Position = UDim2.new(0.05, 0, 1, 0)
    dropdownList.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    dropdownList.BorderSizePixel = 0
    dropdownList.Visible = false
    dropdownList.ZIndex = 10
    dropdownList.Parent = dropdownFrame
    
    for i, option in ipairs(options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Name = option .. "Option"
        optionButton.Size = UDim2.new(1, 0, 0, 25)
        optionButton.Position = UDim2.new(0, 0, 0, (i-1) * 25)
        optionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        optionButton.BorderSizePixel = 0
        optionButton.Text = option
        optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        optionButton.TextSize = 14
        optionButton.Font = Enum.Font.SourceSans
        optionButton.ZIndex = 10
        optionButton.Parent = dropdownList
        
        optionButton.MouseButton1Click:Connect(function()
            dropdownButton.Text = option
            dropdownList.Visible = false
            callback(option)
        end)
    end
    
    dropdownButton.MouseButton1Click:Connect(function()
        dropdownList.Visible = not dropdownList.Visible
    end)
    
    return dropdownFrame
end

-- Create Aimbot tab content
local aimbotY = 10

-- Enable Aimbot
CreateToggle(AimbotContent, "Enable Aimbot", UDim2.new(0.05, 0, 0, aimbotY), Settings.AimbotEnabled, function(enabled)
    Settings.AimbotEnabled = enabled
end)
aimbotY = aimbotY + 40

-- Show FOV Circle
CreateToggle(AimbotContent, "Show FOV Circle", UDim2.new(0.05, 0, 0, aimbotY), Settings.ShowFOV, function(enabled)
    Settings.ShowFOV = enabled
end)
aimbotY = aimbotY + 40

-- Auto Click
CreateToggle(AimbotContent, "Auto Click", UDim2.new(0.05, 0, 0, aimbotY), Settings.AutoClickEnabled, function(enabled)
    Settings.AutoClickEnabled = enabled
    SetupAutoClick()
end)
aimbotY = aimbotY + 40

-- FOV Radius Slider
CreateSlider(AimbotContent, "FOV Radius", 50, 500, Settings.FOVRadius, UDim2.new(0.05, 0, 0, aimbotY), function(value)
    Settings.FOVRadius = value
end)
aimbotY = aimbotY + 60

-- Aimbot Smoothness
CreateSlider(AimbotContent, "Smoothness", 0.01, 1, Settings.AimbotSmoothness, UDim2.new(0.05, 0, 0, aimbotY), function(value)
    Settings.AimbotSmoothness = value
end)
aimbotY = aimbotY + 60

-- Click Interval
CreateSlider(AimbotContent, "Click Interval", 0.01, 0.5, Settings.ClickInterval, UDim2.new(0.05, 0, 0, aimbotY), function(value)
    Settings.ClickInterval = value
end)
aimbotY = aimbotY + 70

-- Target Hitbox
CreateDropdown(AimbotContent, "Target Hitbox", {"Head", "UpperTorso", "HumanoidRootPart"}, Settings.TargetHitbox, UDim2.new(0.05, 0, 0, aimbotY), function(option)
    Settings.TargetHitbox = option
end)

-- Create ESP tab content
local espY = 10

-- Enable ESP
CreateToggle(ESPContent, "Enable ESP", UDim2.new(0.05, 0, 0, espY), Settings.ESPEnabled, function(enabled)
    Settings.ESPEnabled = enabled
end)
espY = espY + 40

-- Box ESP
CreateToggle(ESPContent, "Box ESP", UDim2.new(0.05, 0, 0, espY), Settings.BoxESP, function(enabled)
    Settings.BoxESP = enabled
end)
espY = espY + 40

-- Name ESP
CreateToggle(ESPContent, "Name ESP", UDim2.new(0.05, 0, 0, espY), Settings.NameESP, function(enabled)
    Settings.NameESP = enabled
end)
espY = espY + 40

-- Tracer ESP
CreateToggle(ESPContent, "Tracer ESP", UDim2.new(0.05, 0, 0, espY), Settings.TracerESP, function(enabled)
    Settings.TracerESP = enabled
end)
espY = espY + 40

-- Bone ESP
CreateToggle(ESPContent, "Bone ESP", UDim2.new(0.05, 0, 0, espY), Settings.BoneESP, function(enabled)
    Settings.BoneESP = enabled
end)
espY = espY + 40

-- ESP Distance
CreateSlider(ESPContent, "ESP Distance", 100, 2000, Settings.MaxESPDistance, UDim2.new(0.05, 0, 0, espY), function(value)
    Settings.MaxESPDistance = value
end)

-- Create Misc tab content
local miscY = 10

-- Unload button
local unloadButton = Instance.new("TextButton")
unloadButton.Name = "UnloadButton"
unloadButton.Size = UDim2.new(0.8, 0, 0, 40)
unloadButton.Position = UDim2.new(0.1, 0, 0, miscY)
unloadButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
unloadButton.BorderSizePixel = 0
unloadButton.Text = "Unload Script"
unloadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadButton.TextSize = 16
unloadButton.Font = Enum.Font.SourceSansBold
unloadButton.Parent = MiscContent
miscY = miscY + 60

-- Information text
local infoText = Instance.new("TextLabel")
infoText.Name = "InfoText"
infoText.Size = UDim2.new(0.9, 0, 0, 100)
infoText.Position = UDim2.new(0.05, 0, 0, miscY)
infoText.BackgroundTransparency = 1
infoText.TextColor3 = Color3.fromRGB(255, 255, 255)
infoText.TextSize = 14
infoText.Font = Enum.Font.SourceSans
infoText.Text = "Keyboard Controls:\n\nInsert - Toggle UI visibility\nEnd - Unload script\n\nRight Mouse Button - Activate aimbot"
infoText.TextWrapped = true
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Top
infoText.Parent = MiscContent

-- Tab button functionality
AimbotTab.MouseButton1Click:Connect(function()
    AimbotTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    ESPTab.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    MiscTab.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    
    AimbotContent.Visible = true
    ESPContent.Visible = false
    MiscContent.Visible = false
end)

ESPTab.MouseButton1Click:Connect(function()
    AimbotTab.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    ESPTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    MiscTab.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    
    AimbotContent.Visible = false
    ESPContent.Visible = true
    MiscContent.Visible = false
end)

MiscTab.MouseButton1Click:Connect(function()
    AimbotTab.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    ESPTab.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    MiscTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    
    AimbotContent.Visible = false
    ESPContent.Visible = false
    MiscContent.Visible = true
end)

-- Close button
CloseButton.MouseButton1Click:Connect(function()
    UIVisible = not UIVisible
    MainFrame.Visible = UIVisible
end)

-- Unload button
unloadButton.MouseButton1Click:Connect(function()
    print("Unload button clicked - starting cleanup")
    
    -- Hide UI immediately for visual feedback
    MainFrame.Visible = false
    
    -- Small delay to ensure the visual change happens before full cleanup
    spawn(function()
        wait(0.1) -- Small delay to ensure UI disappears first
        CleanupScript()
    end)
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end -- Ignore if the game already processed this input
    
    -- Toggle UI with Insert key
    if input.KeyCode == Enum.KeyCode.Insert then
        UIVisible = not UIVisible
        MainFrame.Visible = UIVisible
    end
    
    -- Unload script with End key
    if input.KeyCode == Enum.KeyCode.End then
        print("End key pressed - starting cleanup")
        
        -- Hide UI immediately for visual feedback
        MainFrame.Visible = false
        
        -- Small delay to ensure the visual change happens before full cleanup
        spawn(function()
            wait(0.1) -- Small delay to ensure UI disappears first
            CleanupScript()
        end)
    end
    
    -- Right mouse button for aimbot
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        IsRightMouseDown = true
        if Settings.AimbotEnabled then
            TargetPlayer = GetClosestPlayerInFOV()
            IsAimbotActive = true
        end
    end
    
    -- Left mouse button for auto-click
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        IsLeftMouseDown = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Right mouse button released
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        IsRightMouseDown = false
        IsAimbotActive = false
    end
    
    -- Left mouse button released
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        IsLeftMouseDown = false
    end
end)

-- Set up auto-click
SetupAutoClick()

-- Main loop
RunService.RenderStepped:Connect(function()
    if not ScriptActive then return end
    
    -- Update visuals
    UpdateDrawings()
    
    -- Handle aimbot
    if IsAimbotActive and IsRightMouseDown and TargetPlayer then
        LockOntoTarget()
    end
end)

-- Show notification
local notif = Instance.new("ScreenGui")
notif.Name = "AimbotNotification"
notif.Parent = game:GetService("CoreGui")

local notifFrame = Instance.new("Frame")
notifFrame.Size = UDim2.new(0, 250, 0, 70)
notifFrame.Position = UDim2.new(0.5, -125, 0.8, 0)
notifFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
notifFrame.BorderSizePixel = 0
notifFrame.Parent = notif

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 5)
notifCorner.Parent = notifFrame

local notifText = Instance.new("TextLabel")
notifText.Size = UDim2.new(1, -20, 1, 0)
notifText.Position = UDim2.new(0, 10, 0, 0)
notifText.BackgroundTransparency = 1
notifText.TextColor3 = Color3.fromRGB(255, 255, 255)
notifText.TextSize = 14
notifText.Font = Enum.Font.SourceSansBold
notifText.Text = "Rivals Aimbot loaded!\nPress Insert to toggle UI\nPress End to unload"
notifText.TextWrapped = true
notifText.Parent = notifFrame

-- Fade out notification after 5 seconds
spawn(function()
    wait(5)
    
    for i = 1, 10 do
        notifFrame.BackgroundTransparency = i/10
        notifText.TextTransparency = i/10
        wait(0.05)
    end
    
    notif:Destroy()
end)

print("Rivals Aimbot & ESP script has been loaded successfully!")
print("Press INSERT to toggle UI visibility")
print("Press END to unload the script")
