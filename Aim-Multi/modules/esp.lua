--[[
    Enhanced Rivals - ESP Module
    Handles all ESP functionality for player highlighting
]]

local ESP = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Dependencies
local Settings = require(script.Parent.settings)
local Utils = require(script.Parent.Utils)

-- Locals
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local ESPDrawings = {}
local DynamicWrappers = {}

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

-- Initialize or get ESP drawings for a player
function ESP.GetPlayerESP(player)
    if not ESPDrawings[player] then
        ESPDrawings[player] = {
            box = Drawing.new("Square"),
            name = Drawing.new("Text"),
            distance = Drawing.new("Text"),
            health = Drawing.new("Line"),
            healthText = Drawing.new("Text"),
            tracer = Drawing.new("Line"),
            outOfViewArrow = Drawing.new("Triangle"),
            bones = {},
            lastUpdate = 0
        }
        
        -- Box ESP
        local box = ESPDrawings[player].box
        box.Visible = false
        box.Transparency = 0.7
        box.Color = Settings.Current.Colors.ESPPlayer
        box.Thickness = Settings.Current.ESPBoxThickness
        box.Filled = false
        
        -- Name ESP
        local name = ESPDrawings[player].name
        name.Visible = false
        name.Transparency = 1
        name.Color = Settings.Current.Colors.ESPText
        name.Size = Settings.Current.ESPTextSize
        name.Center = true
        name.Outline = true
        name.OutlineColor = Color3.fromRGB(0, 0, 0)
        name.Text = player.Name
        
        -- Distance ESP
        local distance = ESPDrawings[player].distance
        distance.Visible = false
        distance.Transparency = 1
        distance.Color = Settings.Current.Colors.ESPText
        distance.Size = Settings.Current.ESPTextSize - 2
        distance.Center = true
        distance.Outline = true
        distance.OutlineColor = Color3.fromRGB(0, 0, 0)
        
        -- Health bar
        local health = ESPDrawings[player].health
        health.Visible = false
        health.Transparency = 1
        health.Color = Color3.fromRGB(0, 255, 0)
        health.Thickness = 2
        
        -- Health text
        local healthText = ESPDrawings[player].healthText
        healthText.Visible = false
        healthText.Transparency = 1
        healthText.Color = Settings.Current.Colors.ESPText
        healthText.Size = Settings.Current.ESPTextSize - 2
        healthText.Center = false
        healthText.Outline = true
        healthText.OutlineColor = Color3.fromRGB(0, 0, 0)
        
        -- Tracer
        local tracer = ESPDrawings[player].tracer
        tracer.Visible = false
        tracer.Transparency = 0.7
        tracer.Color = Settings.Current.Colors.ESPPlayer
        tracer.Thickness = Settings.Current.TracerThickness
        
        -- Out of view arrow
        local arrow = ESPDrawings[player].outOfViewArrow
        arrow.Visible = false
        arrow.Transparency = 0.7
        arrow.Color = Settings.Current.Colors.ESPPlayer
        arrow.Thickness = 1
        arrow.Filled = true
        
        -- Initialize bone lines
        for i = 1, #BoneConnections do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = Settings.Current.BoneESPThickness
            line.Transparency = 0.6
            line.Color = Settings.Current.Colors.ESPPlayer
            ESPDrawings[player].bones[i] = line
        end
    end
    
    return ESPDrawings[player]
end

-- Clean up ESP drawings for a player
function ESP.CleanupPlayerESP(player)
    if ESPDrawings[player] then
        -- Remove standard ESP drawings
        local drawings = {"box", "name", "distance", "health", "healthText", "tracer", "outOfViewArrow"}
        for _, drawingName in ipairs(drawings) do
            if ESPDrawings[player][drawingName] then
                Utils.SafeRemoveDrawing(ESPDrawings[player][drawingName])
                ESPDrawings[player][drawingName] = nil
            end
        end
        
        -- Remove bone lines
        if ESPDrawings[player].bones then
            for i, bone in pairs(ESPDrawings[player].bones) do
                Utils.SafeRemoveDrawing(bone)
                ESPDrawings[player].bones[i] = nil
            end
            ESPDrawings[player].bones = nil
        end
        
        ESPDrawings[player] = nil
    end
end

-- Update box ESP for a player
function ESP.UpdateBoxESP(player, playerESP)
    if not Settings.Current.BoxESP then
        playerESP.box.Visible = false
        return
    end
    
    -- Get character and humanoid
    local character = player.Character
    if not character then
        playerESP.box.Visible = false
        return
    end
    
    -- Get root part
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        playerESP.box.Visible = false
        return
    end
    
    -- Get corners of the bounding box
    local head = character:FindFirstChild("Head")
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local legs = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
    
    if not head or not torso or not legs then
        playerESP.box.Visible = false
        return
    end
    
    -- Calculate the corners of the bounding box
    local hrp = root.Position
    local size = root.Size * Vector3.new(2, 3, 0)
    local cf = root.CFrame
    
    local tl = cf * CFrame.new(-size.X/2, size.Y/2, 0)
    local tr = cf * CFrame.new(size.X/2, size.Y/2, 0)
    local bl = cf * CFrame.new(-size.X/2, -size.Y/2, 0)
    local br = cf * CFrame.new(size.X/2, -size.Y/2, 0)
    
    local tlv, ontl = Camera:WorldToViewportPoint(tl.Position)
    local trv, ontr = Camera:WorldToViewportPoint(tr.Position)
    local blv, onbl = Camera:WorldToViewportPoint(bl.Position)
    local brv, onbr = Camera:WorldToViewportPoint(br.Position)
    
    -- Check if any part is on screen
    if not (ontl or ontr or onbl or onbr) or (tlv.Z < 0 and trv.Z < 0 and blv.Z < 0 and brv.Z < 0) then
        playerESP.box.Visible = false
        return
    end
    
    -- Calculate box dimensions
    local minX = math.min(tlv.X, trv.X, blv.X, brv.X)
    local maxX = math.max(tlv.X, trv.X, blv.X, brv.X)
    local minY = math.min(tlv.Y, trv.Y, blv.Y, brv.Y)
    local maxY = math.max(tlv.Y, trv.Y, blv.Y, brv.Y)
    
    -- Update box drawing
    playerESP.box.Visible = true
    playerESP.box.Position = Vector2.new(minX, minY)
    playerESP.box.Size = Vector2.new(maxX - minX, maxY - minY)
    
    -- Update color based on if this is the aimbot target
    if player == Aimbot and Aimbot.TargetPlayer then
        playerESP.box.Color = Settings.Current.Colors.ESPTarget
    else
        -- Set color based on team
        if Settings.Current.ESPTeamCheck and Utils.IsTeammate(player) then
            playerESP.box.Color = Settings.Current.Colors.ESPTeammate
        else
            playerESP.box.Color = Settings.Current.Colors.ESPPlayer
        end
    end
    
    -- Update text positions
    if Settings.Current.NameESP then
        playerESP.name.Visible = true
        playerESP.name.Position = Vector2.new((minX + maxX) / 2, minY - playerESP.name.TextBounds.Y - 5)
    else
        playerESP.name.Visible = false
    end
    
    -- Update health bar
    if Settings.Current.HealthESP then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            
            playerESP.health.Visible = true
            playerESP.health.From = Vector2.new(minX - 5, minY)
            playerESP.health.To = Vector2.new(minX - 5, minY + (maxY - minY) * healthPercent)
            
            -- Color gradient based on health
            local healthColor
            if healthPercent > 0.75 then
                healthColor = Color3.fromRGB(0, 255, 0)
            elseif healthPercent > 0.4 then
                healthColor = Color3.fromRGB(255, 255, 0)
            else
                healthColor = Color3.fromRGB(255, 0, 0)
            end
            playerESP.health.Color = healthColor
            
            -- Health text
            playerESP.healthText.Visible = true
            playerESP.healthText.Text = string.format("%d HP", math.floor(humanoid.Health))
            playerESP.healthText.Position = Vector2.new(minX - 5 - playerESP.healthText.TextBounds.X - 3, minY)
        else
            playerESP.health.Visible = false
            playerESP.healthText.Visible = false
        end
    else
        playerESP.health.Visible = false
        playerESP.healthText.Visible = false
    end
    
    -- Update distance
    if Settings.Current.DistanceESP then
        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        playerESP.distance.Visible = true
        playerESP.distance.Text = Utils.FormatDistance(dist)
        playerESP.distance.Position = Vector2.new((minX + maxX) / 2, maxY + 5)
    else
        playerESP.distance.Visible = false
    end
    
    -- Update tracer
    if Settings.Current.TracerESP then
        playerESP.tracer.Visible = true
        playerESP.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 50)
        playerESP.tracer.To = Vector2.new((minX + maxX) / 2, maxY)
        
        -- Set color based on team or target
        if player == Aimbot and Aimbot.TargetPlayer then
            playerESP.tracer.Color = Settings.Current.Colors.ESPTarget
        elseif Settings.Current.ESPTeamCheck and Utils.IsTeammate(player) then
            playerESP.tracer.Color = Settings.Current.Colors.ESPTeammate
        else
            playerESP.tracer.Color = Settings.Current.Colors.ESPPlayer
        end
    else
        playerESP.tracer.Visible = false
    end
end

-- Update bone ESP for a player
function ESP.UpdateBoneESP(player, playerESP)
    if not Settings.Current.BoneESP then
        -- Hide all bones
        for _, bone in pairs(playerESP.bones) do
            bone.Visible = false
        end
        return
    end
    
    -- Get character
    local character = player.Character
    if not character then
        for _, bone in pairs(playerESP.bones) do
            bone.Visible = false
        end
        return
    end
    
    -- Determine bone color
    local boneColor
    if player == Aimbot and Aimbot.TargetPlayer then
        boneColor = Settings.Current.Colors.ESPTarget
    elseif Settings.Current.ESPTeamCheck and Utils.IsTeammate(player) then
        boneColor = Settings.Current.Colors.ESPTeammate
    else
        boneColor = Settings.Current.Colors.ESPPlayer
    end
    
    -- Update each bone connection
    for i, connection in ipairs(BoneConnections) do
        local bone = playerESP.bones[i]
        if not bone then continue end
        
        -- Get the bone positions
        local startWorldPos, startScreenPos, startOnScreen = Utils.GetBonePosition(player, connection[1])
        local endWorldPos, endScreenPos, endOnScreen = Utils.GetBonePosition(player, connection[2])
        
        -- Show the bone line if both parts are visible on screen
        if startWorldPos and endWorldPos and (startOnScreen or endOnScreen) then
            bone.Visible = true
            bone.From = startScreenPos
            bone.To = endScreenPos
            bone.Color = boneColor
            bone.Thickness = Settings.Current.BoneESPThickness
        else
            bone.Visible = false
        end
    end
end

-- Update out-of-view arrows
function ESP.UpdateOutOfViewArrows(player, playerESP)
    if not Settings.Current.OutOfViewArrows then
        playerESP.outOfViewArrow.Visible = false
        return
    end
    
    -- Get character and root
    local character = player.Character
    if not character then
        playerESP.outOfViewArrow.Visible = false
        return
    end
    
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        playerESP.outOfViewArrow.Visible = false
        return
    end
    
    -- Get root position on screen
    local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
    
    -- Only show arrows for off-screen players
    if onScreen and rootPos.Z > 0 then
        playerESP.outOfViewArrow.Visible = false
        return
    end
    
    -- Calculate direction to off-screen player
    local viewportSize = Camera.ViewportSize
    local viewportCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local screenPos = Vector2.new(rootPos.X, rootPos.Y)
    
    -- Get direction from center to player (even if off-screen)
    local direction = (screenPos - viewportCenter).Unit
    
    -- Calculate position at the edge of the screen
    local edgeRadius = math.min(viewportSize.X, viewportSize.Y) * 0.45
    local edgePos = viewportCenter + direction * edgeRadius
    
    -- Calculate arrow rotation based on direction
    local angle = math.atan2(direction.Y, direction.X)
    
    -- Calculate triangle vertices
    local size = Settings.Current.OutOfViewArrowSize
    local v1 = edgePos
    local v2 = edgePos - Vector2.new(math.cos(angle + math.rad(30)), math.sin(angle + math.rad(30))) * size
    local v3 = edgePos - Vector2.new(math.cos(angle - math.rad(30)), math.sin(angle - math.rad(30))) * size
    
    -- Update arrow
    playerESP.outOfViewArrow.Visible = true
    playerESP.outOfViewArrow.PointA = v1
    playerESP.outOfViewArrow.PointB = v2
    playerESP.outOfViewArrow.PointC = v3
    
    -- Color based on team or target
    if player == Aimbot and Aimbot.TargetPlayer then
        playerESP.outOfViewArrow.Color = Settings.Current.Colors.ESPTarget
    elseif Settings.Current.ESPTeamCheck and Utils.IsTeammate(player) then
        playerESP.outOfViewArrow.Color = Settings.Current.Colors.ESPTeammate
    else
        playerESP.outOfViewArrow.Color = Settings.Current.Colors.ESPPlayer
    end
end

-- Update ESP for all players
function ESP.UpdateAllESP()
    -- Don't show ESP in lobby
    if Utils.IsInLobby() then
        for _, drawings in pairs(ESPDrawings) do
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.tracer then drawings.tracer.Visible = false end
            if drawings.health then drawings.health.Visible = false end
            if drawings.healthText then drawings.healthText.Visible = false end
            if drawings.distance then drawings.distance.Visible = false end
            if drawings.outOfViewArrow then drawings.outOfViewArrow.Visible = false end
            
            if drawings.bones then
                for _, bone in pairs(drawings.bones) do
                    bone.Visible = false
                end
            end
        end
        return
    end
    
    -- Clean up ESP for players who left
    for player, _ in pairs(ESPDrawings) do
        if not Players:FindFirstChild(player.Name) then
            ESP.CleanupPlayerESP(player)
        end
    end
    
    -- Update ESP for all players
    for _, player in ipairs(Players:GetPlayers()) do
        -- Skip local player
        if player == LocalPlayer then continue end
        
        -- Skip if player is not within max distance
        if not Utils.IsPlayerWithinDistance(player, Settings.Current.MaxESPDistance) then
            -- Hide ESP for this player
            local playerESP = ESPDrawings[player]
            if playerESP then
                if playerESP.box then playerESP.box.Visible = false end
                if playerESP.name then playerESP.name.Visible = false end
                if playerESP.tracer then playerESP.tracer.Visible = false end
                if playerESP.health then playerESP.health.Visible = false end
                if playerESP.healthText then playerESP.healthText.Visible = false end
                if playerESP.distance then playerESP.distance.Visible = false end
                
                for _, bone in pairs(playerESP.bones) do
                    bone.Visible = false
                end
            end
            continue
        end
        
        -- Skip if visibility check is enabled and player is behind wall
        if Settings.Current.ESPVisibilityCheck and not Utils.IsPlayerVisible(player) then
            local playerESP = ESPDrawings[player]
            if playerESP then
                -- Still show out of view arrows
                if Settings.Current.OutOfViewArrows then
                    ESP.UpdateOutOfViewArrows(player, playerESP)
                else
                    if playerESP.outOfViewArrow then
                        playerESP.outOfViewArrow.Visible = false
                    end
                end
                
                -- Hide other ESP elements
                if playerESP.box then playerESP.box.Visible = false end
                if playerESP.name then playerESP.name.Visible = false end
                if playerESP.tracer then playerESP.tracer.Visible = false end
                if playerESP.health then playerESP.health.Visible = false end
                if playerESP.healthText then playerESP.healthText.Visible = false end
                if playerESP.distance then playerESP.distance.Visible = false end
                
                for _, bone in pairs(playerESP.bones) do
                    bone.Visible = false
                end
            end
            continue
        end
        
        -- Skip if team check is enabled and player is on same team
        if Settings.Current.ESPTeamCheck and Utils.IsTeammate(player) and not Settings.Current.ShowTeammates then
            local playerESP = ESPDrawings[player]
            if playerESP then
                -- Hide all ESP for teammates
                if playerESP.box then playerESP.box.Visible = false end
                if playerESP.name then playerESP.name.Visible = false end
                if playerESP.tracer then playerESP.tracer.Visible = false end
                if playerESP.health then playerESP.health.Visible = false end
                if playerESP.healthText then playerESP.healthText.Visible = false end
                if playerESP.distance then playerESP.distance.Visible = false end
                if playerESP.outOfViewArrow then playerESP.outOfViewArrow.Visible = false end
                
                for _, bone in pairs(playerESP.bones) do
                    bone.Visible = false
                end
            end
            continue
        end
        
        -- Get or create ESP for this player
        local playerESP = ESP.GetPlayerESP(player)
        
        -- Throttle updates for performance in low-performance mode
        if Settings.Current.PerformanceMode then
            local now = tick()
            if now - playerESP.lastUpdate < 0.1 then -- Only update 10 times per second
                continue
            end
            playerESP.lastUpdate = now
        end
        
        -- Update different ESP components
        ESP.UpdateBoxESP(player, playerESP)
        ESP.UpdateBoneESP(player, playerESP)
        ESP.UpdateOutOfViewArrows(player, playerESP)
    end
end

-- Toggle ESP on/off
function ESP.Toggle(state)
    if state ~= nil then
        Settings.Current.ESPEnabled = state
    else
        Settings.Current.ESPEnabled = not Settings.Current.ESPEnabled
    end
    
    -- Hide all ESP elements if disabled
    if not Settings.Current.ESPEnabled then
        for _, drawings in pairs(ESPDrawings) do
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.tracer then drawings.tracer.Visible = false end
            if drawings.health then drawings.health.Visible = false end
            if drawings.healthText then drawings.healthText.Visible = false end
            if drawings.distance then drawings.distance.Visible = false end
            if drawings.outOfViewArrow then drawings.outOfViewArrow.Visible = false end
            
            if drawings.bones then
                for _, bone in pairs(drawings.bones) do
                    bone.Visible = false
                end
            end
        end
    end
    
    return Settings.Current.ESPEnabled
end

-- Clean up all ESP drawings
function ESP.Cleanup()
    for player, _ in pairs(ESPDrawings) do
        ESP.CleanupPlayerESP(player)
    end
end

-- Initialize the module
function ESP.Initialize()
    -- Main update loop
    RunService:BindToRenderStep("ESPUpdate", 2, function()
        if not Settings.Current.ESPEnabled then return end
        
        ESP.UpdateAllESP()
    end)
    
    -- Player added/removed events
    Players.PlayerAdded:Connect(function(player)
        -- Pre-create ESP objects for new players
        ESP.GetPlayerESP(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        -- Clean up ESP for players who leave
        ESP.CleanupPlayerESP(player)
    end)
    
    return true
end

return ESP
