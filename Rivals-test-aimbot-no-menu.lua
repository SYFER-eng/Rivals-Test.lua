--[[
    ENHANCED RIVALS AIMBOT
    Improved aimbot with smooth physics-based dragging
    
    FEATURES:
    - Physics-based smooth mouse movement (not snapping)
    - Hold right mouse button to aim at closest player's head
    - Press End key to completely unload the script
    
    HOW TO USE:
    1. Copy this entire script
    2. Paste it into your Roblox executor
    3. Join a Roblox game
    4. Execute the script
    5. Hold right mouse button to activate aimbot
]]

-- Check if already loaded
if _G.AimbotLoaded then
    return
end

-- Mark as loaded
_G.AimbotLoaded = true

-- Settings (can be changed)
_G.AimbotSettings = {
    FOV = 200,                -- Field of view circle size (smaller as requested)
    AimPart = "Head",         -- Part to aim at (Head, HumanoidRootPart, Torso)
    TeamCheck = false,        -- Don't aim at teammates
    Prediction = 0,           -- No prediction as requested
    Smoothness = 0.3,         -- Lower = faster aim (0.01-1) - slower aiming
    VisibleCheck = false,     -- Only target visible players
    ShowFOV = true,           -- Show FOV circle
    MaxSpeed = 14,            -- Maximum mouse movement speed (reduced for slower aim)
    AimKey = Enum.UserInputType.MouseButton2,  -- Right mouse button
    DragFactor = 0.9,         -- Physics drag (lower = more drag) - increased drag for slower aim
    Jitter = 0.02,            -- Random movement for human-like aim (reduced)
    JitterEnabled = true,     -- Enable random jitter
    
    -- Snap line settings
    ShowSnapLine = true,      -- Show line from center to target
    SnapLineColor = Color3.fromRGB(0, 255, 0), -- Green snap line
    SnapLineThickness = 1.5,  -- Thickness of snap line
    
    -- Always move mouse (even when not aiming)
    AlwaysTrack = false       -- Only track when holding right mouse button
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local FOVCircle
local SnapLine
local CurrentTarget = nil
local Aiming = false
local AimStart = 0         -- Time when aim button was pressed
local AimDelay = 0.3       -- Delay in seconds before aimbot activates
local Connection
local CurrentVelocity = Vector2.new(0, 0)

-- Create FOV circle and snap line
local function CreateDrawings()
    -- Remove existing drawings
    if FOVCircle then
        FOVCircle:Remove()
    end
    
    if SnapLine then
        SnapLine:Remove()
    end
    
    -- Create FOV circle
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = _G.AimbotSettings.ShowFOV
    FOVCircle.Filled = false
    FOVCircle.Thickness = 2
    FOVCircle.Transparency = 1
    FOVCircle.Color = Color3.fromRGB(255, 0, 0)
    FOVCircle.Radius = _G.AimbotSettings.FOV
    
    -- Create snap line
    SnapLine = Drawing.new("Line")
    SnapLine.Visible = _G.AimbotSettings.ShowSnapLine
    SnapLine.Color = _G.AimbotSettings.SnapLineColor
    SnapLine.Thickness = _G.AimbotSettings.SnapLineThickness
    SnapLine.Transparency = 1
    SnapLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    SnapLine.To = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

-- Find closest player to mouse
local function GetClosestPlayer()
    local MaxDistance = _G.AimbotSettings.FOV
    local Target = nil
    
    -- Update FOV circle position to center of screen
    if FOVCircle then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
    
    -- Loop through all players
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        
        -- Team check
        if _G.AimbotSettings.TeamCheck and Player.Team == LocalPlayer.Team then continue end
        
        -- Character check
        local Character = Player.Character
        if not Character then continue end
        
        -- Target part check
        local TargetPart = Character:FindFirstChild(_G.AimbotSettings.AimPart)
        if not TargetPart then continue end
        
        -- Humanoid check
        local Humanoid = Character:FindFirstChild("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then continue end
        
        -- Visibility check
        if _G.AimbotSettings.VisibleCheck then
            local Ray = Ray.new(Camera.CFrame.Position, (TargetPart.Position - Camera.CFrame.Position).Unit * 1000)
            local Hit, _ = Workspace:FindPartOnRayWithIgnoreList(Ray, {LocalPlayer.Character, Camera})
            if Hit and not Hit:IsDescendantOf(Character) then continue end
        end
        
        -- On screen check
        local TargetPos, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
        if not OnScreen then continue end
        
        -- Distance check from center of screen (not mouse position)
        local ScreenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local Distance = (Vector2.new(TargetPos.X, TargetPos.Y) - ScreenCenter).Magnitude
        
        -- Check if closest within FOV
        if Distance < MaxDistance then
            MaxDistance = Distance
            Target = TargetPart
        end
    end
    
    return Target
end

-- Handle input
UserInputService.InputBegan:Connect(function(Input)
    if Input.UserInputType == _G.AimbotSettings.AimKey then
        -- We're pressing the aim button, but not aiming yet
        -- Record the time when the button was pressed
        AimStart = tick()
        -- Aiming flag will be set in the Update function after delay
    end
    
    if Input.KeyCode == Enum.KeyCode.End then
        UnloadAimbot()
    end
end)

UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == _G.AimbotSettings.AimKey then
        -- Stop aiming immediately when button is released
        Aiming = false
        -- Reset velocity immediately for instant stop
        CurrentVelocity = Vector2.new(0, 0)
    end
end)

-- Aimbot update function
local function Update()
    -- Check if we should start aiming (after delay has passed)
    local CurrentTime = tick()
    if not Aiming and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        -- If button is down and we've passed the delay time, set Aiming to true
        if CurrentTime - AimStart >= AimDelay then
            Aiming = true
        end
    end
    
    -- Get target whether aiming or not (for snap line)
    local Target = GetClosestPlayer()
    CurrentTarget = Target  -- Store current target globally
    
    -- Update snap line
    if SnapLine and _G.AimbotSettings.ShowSnapLine then
        -- Update from position to the center of the screen
        SnapLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        
        -- Update to position (target or same as from if no target)
        if Target then
            local TargetPos = Camera:WorldToViewportPoint(Target.Position)
            SnapLine.To = Vector2.new(TargetPos.X, TargetPos.Y)
            SnapLine.Visible = true
        else
            -- If no target, keep line invisible or make it a point
            if _G.AimbotSettings.ShowSnapLine then
                SnapLine.To = SnapLine.From
                SnapLine.Visible = false  -- Hide line when no target
            end
        end
    end
    
    -- Only change mouse movement when aiming or always track setting is on
    if Aiming or _G.AimbotSettings.AlwaysTrack then
        -- If we have a target
        if Target then
            -- Get target position with prediction
            local TargetPos = Camera:WorldToViewportPoint(
                Target.Position + 
                (Target.AssemblyLinearVelocity or Vector3.new(0,0,0)) * _G.AimbotSettings.Prediction
            )
            
            -- Calculate direction to target
            local MousePos = UserInputService:GetMouseLocation()
            local TargetVector = Vector2.new(TargetPos.X, TargetPos.Y)
            local Direction = (TargetVector - MousePos)
            local Distance = Direction.Magnitude
            
            -- Calculate target velocity based on distance
            local TargetSpeed = math.min(Distance * 1.5, _G.AimbotSettings.MaxSpeed)
            local TargetVelocity = Direction.Unit * TargetSpeed
            
            -- Apply smoothness via drag factor
            CurrentVelocity = CurrentVelocity:Lerp(TargetVelocity, _G.AimbotSettings.Smoothness)
            
            -- Apply drag
            CurrentVelocity = CurrentVelocity * _G.AimbotSettings.DragFactor
            
            -- Add jitter for human-like aim
            if _G.AimbotSettings.JitterEnabled then
                local jitterX = (math.random() - 0.5) * _G.AimbotSettings.Jitter * 10
                local jitterY = (math.random() - 0.5) * _G.AimbotSettings.Jitter * 10
                CurrentVelocity = CurrentVelocity + Vector2.new(jitterX, jitterY)
            end
            
            -- Move mouse
            local NewPosition = MousePos + CurrentVelocity
            mousemoveabs(NewPosition.X, NewPosition.Y)
        else
            -- Decelerate if no target
            CurrentVelocity = CurrentVelocity * 0.8
            
            if CurrentVelocity.Magnitude > 0.1 then
                local MousePos = UserInputService:GetMouseLocation()
                local NewPosition = MousePos + CurrentVelocity
                mousemoveabs(NewPosition.X, NewPosition.Y)
            else
                CurrentVelocity = Vector2.new(0, 0)
            end
        end
    else
        -- Decelerate when not aiming for smooth release
        CurrentVelocity = CurrentVelocity * 0.8
        
        if CurrentVelocity.Magnitude > 0.1 then
            local MousePos = UserInputService:GetMouseLocation()
            local NewPosition = MousePos + CurrentVelocity
            mousemoveabs(NewPosition.X, NewPosition.Y)
        else
            CurrentVelocity = Vector2.new(0, 0)
        end
    end
end

-- Function to unload aimbot
function UnloadAimbot()
    if Connection then 
        Connection:Disconnect()
    end
    
    if FOVCircle then
        FOVCircle:Remove()
    end
    
    if SnapLine then
        SnapLine:Remove()
    end
    
    _G.AimbotLoaded = false
    
    -- Notify user
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Aimbot Unloaded",
        Text = "Enhanced aimbot has been unloaded",
        Duration = 3
    })
end

-- Create FOV circle and snap line
CreateDrawings()

-- Connect update function
Connection = RunService.RenderStepped:Connect(Update)

-- Notify on load
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Enhanced Aimbot",
    Text = "Successfully loaded! Hold right click to aim",
    Duration = 5
})

-- Return confirmation
return "ENHANCED AIMBOT LOADED"
