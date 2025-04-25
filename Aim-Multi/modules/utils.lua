--[[
    Enhanced Rivals - Utilities Module
    General utilities and helper functions
]]

local Utils = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Create a smoothing lerp function
function Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

-- Vector2 lerp
function Utils.LerpVector2(a, b, t)
    return Vector2.new(
        Utils.Lerp(a.X, b.X, t),
        Utils.Lerp(a.Y, b.Y, t)
    )
end

-- Color3 lerp
function Utils.LerpColor3(a, b, t)
    return Color3.new(
        Utils.Lerp(a.R, b.R, t),
        Utils.Lerp(a.G, b.G, t),
        Utils.Lerp(a.B, b.B, t)
    )
end

-- Check if a player is a teammate
function Utils.IsTeammate(player)
    if not player or not LocalPlayer then return false end
    
    -- Team check based on Team property
    if player.Team and LocalPlayer.Team then
        return player.Team == LocalPlayer.Team
    end
    
    -- Some games use TeamColor
    if player.TeamColor and LocalPlayer.TeamColor then
        return player.TeamColor == LocalPlayer.TeamColor
    end
    
    -- Some games use a Value object
    local playerCharacter = player.Character
    local localCharacter = LocalPlayer.Character
    
    if playerCharacter and localCharacter then
        -- Check for team values in character
        local playerTeam = playerCharacter:FindFirstChild("Team")
        local localTeam = localCharacter:FindFirstChild("Team")
        
        if playerTeam and localTeam and playerTeam:IsA("StringValue") then
            return playerTeam.Value == localTeam.Value
        end
    end
    
    return false
end

-- Check if a player is alive
function Utils.IsPlayerAlive(player)
    if not player or not player.Character then
        return false
    end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- Check if a player is within distance
function Utils.IsPlayerWithinDistance(player, maxDistance)
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
    return distance <= maxDistance
end

-- Check if a player is visible (not behind walls)
function Utils.IsPlayerVisible(player)
    if not player or not player.Character or not LocalPlayer or not LocalPlayer.Character then
        return false -- If no character, consider not visible
    end
    
    -- Get character root parts
    local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not playerRoot or not localRoot then
        return false -- If no root part, consider not visible
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
    return raycastResult == nil
end

-- Check if in lobby (customize based on your game)
function Utils.IsInLobby()
    -- Try-catch for compatibility with different games
    local success, result = pcall(function()
        -- Check for specific lobby indicators in the game
        if workspace:FindFirstChild("LobbyFolder") or workspace:FindFirstChild("Lobby") then
            return true
        end
        
        -- Check player state
        if LocalPlayer:FindFirstChild("InLobby") and LocalPlayer.InLobby.Value then
            return true
        end
        
        -- Check for common lobby attributes
        local status = LocalPlayer:FindFirstChild("Status") or LocalPlayer:FindFirstChild("PlayerStatus")
        if status and (status.Value == "Lobby" or status.Value == "Intermission") then
            return true
        end
        
        -- If no specific indicator found, assume not in lobby
        return false
    end)
    
    if not success then
        -- In case of error, assume not in lobby for safety
        return false
    end
    
    return result
end

-- Get the player's health as a percentage
function Utils.GetPlayerHealth(player)
    if not player or not player.Character then return 0 end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return 0 end
    
    return humanoid.Health / humanoid.MaxHealth
end

-- Create a tween function for Drawing objects
function Utils.TweenDrawingProperty(drawingObj, property, targetValue, duration, callback)
    if not drawingObj then return end
    
    local startValue = drawingObj[property]
    local startTime = tick()
    
    -- For color tweening
    if typeof(startValue) == "Color3" then
        local connection
        connection = RunService.RenderStepped:Connect(function()
            local elapsed = tick() - startTime
            local progress = math.min(elapsed / duration, 1)
            
            -- Sine easing
            local easedProgress = -(math.cos(math.pi * progress) - 1) / 2
            
            local newColor = Utils.LerpColor3(startValue, targetValue, easedProgress)
            drawingObj[property] = newColor
            
            if progress >= 1 then
                connection:Disconnect()
                if callback then callback() end
            end
        end)
        return connection
    end
    
    -- For numeric tweening
    if type(startValue) == "number" then
        local connection
        connection = RunService.RenderStepped:Connect(function()
            local elapsed = tick() - startTime
            local progress = math.min(elapsed / duration, 1)
            
            -- Sine easing
            local easedProgress = -(math.cos(math.pi * progress) - 1) / 2
            
            local newValue = Utils.Lerp(startValue, targetValue, easedProgress)
            drawingObj[property] = newValue
            
            if progress >= 1 then
                connection:Disconnect()
                if callback then callback() end
            end
        end)
        return connection
    end
    
    -- For vector2 tweening
    if typeof(startValue) == "Vector2" then
        local connection
        connection = RunService.RenderStepped:Connect(function()
            local elapsed = tick() - startTime
            local progress = math.min(elapsed / duration, 1)
            
            -- Sine easing
            local easedProgress = -(math.cos(math.pi * progress) - 1) / 2
            
            local newVector = Utils.LerpVector2(startValue, targetValue, easedProgress)
            drawingObj[property] = newVector
            
            if progress >= 1 then
                connection:Disconnect()
                if callback then callback() end
            end
        end)
        return connection
    end
end

-- Shake animation for Drawing objects
function Utils.ShakeDrawing(drawingObj, property, intensity, duration)
    if not drawingObj then return end
    
    local originalValue = drawingObj[property]
    local startTime = tick()
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        local progress = elapsed / duration
        
        if progress < 1 then
            local shakeIntensity = intensity * (1 - progress) -- Reduce intensity over time
            
            if typeof(originalValue) == "Vector2" then
                drawingObj[property] = originalValue + Vector2.new(
                    (math.random() - 0.5) * 2 * shakeIntensity,
                    (math.random() - 0.5) * 2 * shakeIntensity
                )
            elseif type(originalValue) == "number" then
                drawingObj[property] = originalValue + (math.random() - 0.5) * 2 * shakeIntensity
            end
        else
            drawingObj[property] = originalValue
            connection:Disconnect()
        end
    end)
    
    return connection
end

-- Find a bone part in a character
function Utils.FindBonePart(character, boneName)
    if not character then return nil end
    
    -- Direct match
    local part = character:FindFirstChild(boneName)
    if part then return part end
    
    -- Some games use different naming conventions
    local alternativeNames = {
        ["Head"] = {"Head"},
        ["UpperTorso"] = {"UpperTorso", "Torso", "HumanoidRootPart"},
        ["LowerTorso"] = {"LowerTorso", "Torso", "HumanoidRootPart"},
        ["RightUpperArm"] = {"RightUpperArm", "Right Arm"},
        ["RightLowerArm"] = {"RightLowerArm", "Right Arm"},
        ["RightHand"] = {"RightHand", "Right Hand"},
        ["LeftUpperArm"] = {"LeftUpperArm", "Left Arm"},
        ["LeftLowerArm"] = {"LeftLowerArm", "Left Arm"},
        ["LeftHand"] = {"LeftHand", "Left Hand"},
        ["RightUpperLeg"] = {"RightUpperLeg", "Right Leg"},
        ["RightLowerLeg"] = {"RightLowerLeg", "Right Leg"},
        ["RightFoot"] = {"RightFoot", "Right Foot"},
        ["LeftUpperLeg"] = {"LeftUpperLeg", "Left Leg"},
        ["LeftLowerLeg"] = {"LeftLowerLeg", "Left Leg"},
        ["LeftFoot"] = {"LeftFoot", "Left Foot"}
    }
    
    if alternativeNames[boneName] then
        for _, name in ipairs(alternativeNames[boneName]) do
            part = character:FindFirstChild(name)
            if part then return part end
        end
    end
    
    return nil
end

-- Safely get a player's bone position in world and screen space
function Utils.GetBonePosition(player, boneName)
    if not player or not player.Character then
        return nil, nil, false
    end
    
    local bone = Utils.FindBonePart(player.Character, boneName)
    if not bone then
        return nil, nil, false
    end
    
    local worldPosition = bone.Position
    local screenPosition, isOnScreen = Camera:WorldToViewportPoint(worldPosition)
    
    return worldPosition, Vector2.new(screenPosition.X, screenPosition.Y), isOnScreen and screenPosition.Z > 0
end

-- Clean up a Drawing object safely
function Utils.SafeRemoveDrawing(drawingObj)
    if drawingObj and typeof(drawingObj) == "table" and drawingObj.Remove then
        pcall(function()
            drawingObj:Remove()
        end)
        return true
    end
    return false
end

-- Detect and handle external executor type
function Utils.GetExecutorType()
    local executorInfo = {
        name = "Unknown",
        supportsDrawingLibrary = true,
        supportsFileSystem = false,
        supportsMouse = true
    }
    
    -- Detect executor based on available globals
    if (syn and syn.mouse1click) or (SENTINEL_LOADED) then
        executorInfo.name = "Synapse X / Sentinel"
        executorInfo.supportsFileSystem = true
    elseif KRNL_LOADED then
        executorInfo.name = "KRNL"
        executorInfo.supportsFileSystem = true
    elseif is_sirhurt_closure then
        executorInfo.name = "SirHurt"
        executorInfo.supportsFileSystem = true
    elseif fluxus then
        executorInfo.name = "Fluxus"
        executorInfo.supportsFileSystem = true
    elseif EvoV2 then
        executorInfo.name = "Evon"
        executorInfo.supportsFileSystem = true
    elseif hookfunction or hookfunc then
        executorInfo.name = "Script-Ware"
        executorInfo.supportsFileSystem = true
    end
    
    -- Feature detection
    if not Drawing or not Drawing.new then
        executorInfo.supportsDrawingLibrary = false
    end
    
    if not mousemoverel and not (Input and Input.MouseMove) then
        executorInfo.supportsMouse = false
    end
    
    if readfile and writefile and isfile and isfolder then
        executorInfo.supportsFileSystem = true
    end
    
    return executorInfo
end

-- Format number with commas
function Utils.FormatNumber(number)
    local formatted = tostring(math.floor(number))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- Format distance with units
function Utils.FormatDistance(distance)
    if distance < 10 then
        return string.format("%.1f m", distance)
    else
        return string.format("%d m", math.floor(distance))
    end
end

return Utils
