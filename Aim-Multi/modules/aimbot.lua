--[[
    Enhanced Rivals - Aimbot Module
    Handles all aimbot functionality including FOV circle and target acquisition
]]

local Aimbot = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Dependencies
local Settings = require(script.Parent.settings)
local Utils = require(script.Parent.Utils)

-- Local variables
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local TargetPlayer = nil
local IsAimbotActive = false
local LastClickTime = 0
local DrawingObjects = {}

-- Initialize all drawing objects
function Aimbot.InitializeDrawings()
    -- FOV Circle
    DrawingObjects.FOVCircle = Drawing.new("Circle")
    DrawingObjects.FOVCircle.Visible = false
    DrawingObjects.FOVCircle.Transparency = 0.7
    DrawingObjects.FOVCircle.Color = Settings.Current.Colors.FOV
    DrawingObjects.FOVCircle.Thickness = 2
    DrawingObjects.FOVCircle.NumSides = 64
    DrawingObjects.FOVCircle.Radius = Settings.Current.FOVRadius
    DrawingObjects.FOVCircle.Filled = false
    
    -- Snapline to target
    DrawingObjects.SnapLine = Drawing.new("Line")
    DrawingObjects.SnapLine.Visible = false
    DrawingObjects.SnapLine.Thickness = 3.0
    DrawingObjects.SnapLine.Color = Settings.Current.Colors.Snapline
    
    -- Head circle for target
    DrawingObjects.HeadCircle = Drawing.new("Circle")
    DrawingObjects.HeadCircle.Visible = false
    DrawingObjects.HeadCircle.Transparency = 0.7
    DrawingObjects.HeadCircle.Color = Settings.Current.Colors.HeadCircle
    DrawingObjects.HeadCircle.Thickness = 2
    DrawingObjects.HeadCircle.NumSides = 30
    DrawingObjects.HeadCircle.Radius = Settings.Current.HeadCircleRadius
    DrawingObjects.HeadCircle.Filled = false
end

-- Get the closest player within FOV
function Aimbot.GetClosestPlayerInFOV()
    local closestPlayer = nil
    local shortestDistance = Settings.Current.FOVRadius
    local mousePosition = UserInputService:GetMouseLocation()
    
    for _, player in ipairs(Players:GetPlayers()) do
        -- Skip if it's the local player
        if player == LocalPlayer then continue end
        
        -- Skip if player is not alive
        if not Utils.IsPlayerAlive(player) then continue end
        
        -- Team check if enabled
        if Settings.Current.AimbotTeamCheck and Utils.IsTeammate(player) then continue end
        
        -- Try to find the target hitbox
        local hitboxPart = player.Character:FindFirstChild(Settings.Current.TargetHitbox)
        if not hitboxPart then
            -- Fallback to Head if specified hitbox doesn't exist
            hitboxPart = player.Character:FindFirstChild("Head")
            if not hitboxPart then
                -- Last resort - try HumanoidRootPart
                hitboxPart = player.Character:FindFirstChild("HumanoidRootPart")
                if not hitboxPart then continue end -- No valid target part
            end
        end
        
        -- Get screen position
        local hitboxPosition, onScreen = Camera:WorldToViewportPoint(hitboxPart.Position)
        
        -- Skip if not on screen
        if not onScreen or hitboxPosition.Z <= 0 then continue end
        
        -- Visibility check if enabled
        if Settings.Current.AimbotVisibilityCheck and not Utils.IsPlayerVisible(player) then continue end
        
        -- Calculate distance to mouse
        local screenPosition = Vector2.new(hitboxPosition.X, hitboxPosition.Y)
        local distance = (screenPosition - mousePosition).Magnitude
        
        -- Check if within FOV and closer than previous target
        if distance < shortestDistance then
            closestPlayer = player
            shortestDistance = distance
        end
    end
    
    return closestPlayer
end

-- Lock onto the current target
function Aimbot.LockOntoTarget()
    if not TargetPlayer or not TargetPlayer.Character or not IsAimbotActive then return end
    
    -- Try to find the target hitbox
    local hitboxPart = TargetPlayer.Character:FindFirstChild(Settings.Current.TargetHitbox)
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
        -- Different methods for aiming
        if Settings.Current.AimbotMethod == "Mouse" then
            -- Calculate the delta between target position and mouse position
            local mousePosition = UserInputService:GetMouseLocation()
            local targetScreenPos = Vector2.new(targetPosition.X, targetPosition.Y)
            local delta = targetScreenPos - mousePosition
            
            -- Apply smoothing to the movement
            delta = delta * Settings.Current.AimbotSmoothness
            
            -- Move the mouse
            if mousemoverel then
                mousemoverel(delta.X, delta.Y)
            elseif Input and Input.MouseMove then -- Alternative for some executors
                Input.MouseMove(delta)
            end
        elseif Settings.Current.AimbotMethod == "Camera" then
            -- Direct camera manipulation for smoother aim
            local currentCameraCFrame = Camera.CFrame
            local targetCFrame = CFrame.new(currentCameraCFrame.Position, hitboxPart.Position)
            
            -- Apply smoothing
            local smoothCFrame = currentCameraCFrame:Lerp(targetCFrame, Settings.Current.AimbotSmoothness)
            Camera.CFrame = smoothCFrame
        end
        
        -- Auto click if enabled
        if Settings.Current.AutoClickEnabled and tick() - LastClickTime >= Settings.Current.ClickInterval then
            LastClickTime = tick()
            
            -- Use the appropriate click function based on executor
            if mouse1click then
                mouse1click()
            elseif Input and Input.LeftClick then
                Input.LeftClick()
            end
        end
    end
end

-- Update visual elements (FOV circle, snap line, head circle)
function Aimbot.UpdateVisuals()
    -- Update FOV circle
    if DrawingObjects.FOVCircle then
        DrawingObjects.FOVCircle.Visible = Settings.Current.ShowFOV
        DrawingObjects.FOVCircle.Position = UserInputService:GetMouseLocation()
        DrawingObjects.FOVCircle.Radius = Settings.Current.FOVRadius
        DrawingObjects.FOVCircle.Color = Settings.Current.Colors.FOV
    end
    
    -- Update target visuals
    if TargetPlayer and TargetPlayer.Character and IsAimbotActive then
        local headPart = TargetPlayer.Character:FindFirstChild("Head")
        
        if headPart then
            local headPosition, onScreen = Camera:WorldToViewportPoint(headPart.Position)
            
            if onScreen and headPosition.Z > 0 then
                -- Show head circle on target
                if DrawingObjects.HeadCircle then
                    DrawingObjects.HeadCircle.Visible = true
                    DrawingObjects.HeadCircle.Position = Vector2.new(headPosition.X, headPosition.Y)
                    DrawingObjects.HeadCircle.Color = Settings.Current.Colors.HeadCircle
                    DrawingObjects.HeadCircle.Radius = Settings.Current.HeadCircleRadius
                end
                
                -- Show snapline from screen center to target
                if DrawingObjects.SnapLine then
                    DrawingObjects.SnapLine.Visible = true
                    DrawingObjects.SnapLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    DrawingObjects.SnapLine.To = Vector2.new(headPosition.X, headPosition.Y)
                    DrawingObjects.SnapLine.Color = Settings.Current.Colors.Snapline
                end
                
                -- Use Utils to animate the head circle for a "locked on" effect
                Utils.ShakeDrawing(DrawingObjects.HeadCircle, "Radius", 1, 0.5)
            else
                if DrawingObjects.HeadCircle then DrawingObjects.HeadCircle.Visible = false end
                if DrawingObjects.SnapLine then DrawingObjects.SnapLine.Visible = false end
            end
        else
            if DrawingObjects.HeadCircle then DrawingObjects.HeadCircle.Visible = false end
            if DrawingObjects.SnapLine then DrawingObjects.SnapLine.Visible = false end
        end
    else
        if DrawingObjects.HeadCircle then DrawingObjects.HeadCircle.Visible = false end
        if DrawingObjects.SnapLine then DrawingObjects.SnapLine.Visible = false end
    end
end

-- Toggle aimbot on/off
function Aimbot.Toggle(state)
    if state ~= nil then
        Settings.Current.AimbotEnabled = state
    else
        Settings.Current.AimbotEnabled = not Settings.Current.AimbotEnabled
    end
    
    -- Animate FOV circle on toggle
    if Settings.Current.AimbotEnabled and Settings.Current.ShowFOV then
        Utils.TweenDrawingProperty(DrawingObjects.FOVCircle, "Radius", Settings.Current.FOVRadius * 1.3, 0.3, function()
            Utils.TweenDrawingProperty(DrawingObjects.FOVCircle, "Radius", Settings.Current.FOVRadius, 0.2)
        end)
    end
    
    return Settings.Current.AimbotEnabled
end

-- Handle aimbot activation based on trigger type
function Aimbot.HandleActivation()
    if not Settings.Current.AimbotEnabled then
        IsAimbotActive = false
        return
    end
    
    -- Different activation methods
    if Settings.Current.AimbotTriggerType == "Always" then
        IsAimbotActive = true
    elseif Settings.Current.AimbotTriggerType == "Hold" then
        -- Check if the activation key is being held
        IsAimbotActive = UserInputService:IsKeyDown(Settings.Current.AimbotActivationKey)
    elseif Settings.Current.AimbotTriggerType == "Toggle" and UserInputService:IsKeyDown(Settings.Current.AimbotActivationKey) then
        -- This requires separate toggle logic in the input handler
    end
    
    -- Update target player when active
    if IsAimbotActive then
        TargetPlayer = Aimbot.GetClosestPlayerInFOV()
    else
        TargetPlayer = nil
    end
end

-- Clean up all drawing objects
function Aimbot.Cleanup()
    for _, drawingObj in pairs(DrawingObjects) do
        Utils.SafeRemoveDrawing(drawingObj)
    end
    DrawingObjects = {}
end

-- Initialize the module
function Aimbot.Initialize()
    Aimbot.InitializeDrawings()
    
    -- Main update loop
    RunService:BindToRenderStep("AimbotUpdate", 1, function()
        if not Settings.Current.AimbotEnabled or Utils.IsInLobby() then
            if DrawingObjects.FOVCircle then DrawingObjects.FOVCircle.Visible = false end
            if DrawingObjects.HeadCircle then DrawingObjects.HeadCircle.Visible = false end
            if DrawingObjects.SnapLine then DrawingObjects.SnapLine.Visible = false end
            return
        end
        
        -- Handle aimbot activation
        Aimbot.HandleActivation()
        
        -- Update visuals
        Aimbot.UpdateVisuals()
        
        -- Lock onto target if active
        if IsAimbotActive and TargetPlayer then
            Aimbot.LockOntoTarget()
        end
    end)
    
    return true
end

return Aimbot
