--[[
    Enhanced Rivals - Settings Module
    Handles all configurable settings and their persistence
]]

local Settings = {}

-- Default settings
Settings.Default = {
    -- Aimbot Settings
    AimbotEnabled = false,
    AutoClickEnabled = false,
    ShowFOV = true,
    FOVRadius = 200,
    AimbotSmoothness = 0.25,
    ClickInterval = 0.05,
    TargetHitbox = "Head", -- "Head", "HumanoidRootPart", "Torso"
    AimbotMethod = "Camera", -- "Camera" or "Mouse"
    AimbotVisibilityCheck = true,
    AimbotTeamCheck = false,
    AimbotActivationKey = Enum.KeyCode.E,
    AimbotTriggerType = "Hold", -- "Hold", "Toggle", "Always"
    
    -- ESP Settings
    ESPEnabled = true,
    BoxESP = false,
    NameESP = false,
    TracerESP = false,
    BoneESP = true,
    HealthESP = false,
    DistanceESP = false,
    MaxESPDistance = 500,
    ESPVisibilityCheck = false,
    ESPTeamCheck = false,
    OutOfViewArrows = false,
    
    -- Visual Settings
    UITheme = "Dark", -- "Dark", "Light", "Matrix", "Retrowave"
    UIScale = 1,
    UICorner = "TopRight", -- "TopRight", "TopLeft", "BottomRight", "BottomLeft"
    UITransparency = 0.9,
    
    -- Colors (using table format for easier color management)
    Colors = {
        FOV = Color3.fromRGB(255, 255, 255),
        Snapline = Color3.fromRGB(255, 0, 0),
        HeadCircle = Color3.fromRGB(0, 255, 0),
        ESPPlayer = Color3.fromRGB(255, 0, 0),
        ESPTarget = Color3.fromRGB(0, 255, 0),
        ESPText = Color3.fromRGB(255, 255, 255),
        ESPTeammate = Color3.fromRGB(0, 255, 0),
        UIBackground = Color3.fromRGB(25, 25, 35),
        UIText = Color3.fromRGB(255, 255, 255),
        UIAccent = Color3.fromRGB(0, 170, 255),
        UIBorder = Color3.fromRGB(60, 60, 80),
        UIHeaderBackground = Color3.fromRGB(40, 40, 60),
        UISuccess = Color3.fromRGB(0, 255, 128),
        UIWarning = Color3.fromRGB(255, 175, 0),
        UIDanger = Color3.fromRGB(255, 50, 50)
    },
    
    -- Size settings
    HeadCircleRadius = 8,
    ESPTextSize = 14,
    ESPBoxThickness = 2,
    BoneESPThickness = 2.5,
    TracerThickness = 1.5,
    OutOfViewArrowSize = 25,
    
    -- Animation Settings
    UIAnimations = true,
    UIAnimationSpeed = 0.3,
    ESPSmoothness = true,
    
    -- Advanced
    DrawingQuality = "High", -- "High", "Medium", "Low"
    PerformanceMode = false,
    MemoryOptimized = true,
    DebugMode = false,
    
    -- Keybinds
    ToggleUIKey = Enum.KeyCode.Insert,
    UnloadScriptKey = Enum.KeyCode.End,
    ToggleAimbotKey = Enum.KeyCode.RightAlt
}

-- Active settings (gets overwritten by saved)
Settings.Current = {}

-- Copy default settings to current
for key, value in pairs(Settings.Default) do
    if type(value) == "table" then
        Settings.Current[key] = {}
        for subKey, subValue in pairs(value) do
            Settings.Current[key][subKey] = subValue
        end
    else
        Settings.Current[key] = value
    end
end

-- Theme presets
Settings.ThemePresets = {
    Dark = {
        UIBackground = Color3.fromRGB(25, 25, 35),
        UIText = Color3.fromRGB(255, 255, 255),
        UIAccent = Color3.fromRGB(0, 170, 255),
        UIBorder = Color3.fromRGB(60, 60, 80),
        UIHeaderBackground = Color3.fromRGB(40, 40, 60)
    },
    Light = {
        UIBackground = Color3.fromRGB(240, 240, 245),
        UIText = Color3.fromRGB(50, 50, 50),
        UIAccent = Color3.fromRGB(0, 120, 215),
        UIBorder = Color3.fromRGB(200, 200, 210),
        UIHeaderBackground = Color3.fromRGB(220, 220, 230)
    },
    Matrix = {
        UIBackground = Color3.fromRGB(10, 20, 10),
        UIText = Color3.fromRGB(0, 255, 0),
        UIAccent = Color3.fromRGB(0, 200, 0),
        UIBorder = Color3.fromRGB(0, 100, 0),
        UIHeaderBackground = Color3.fromRGB(0, 40, 0)
    },
    Retrowave = {
        UIBackground = Color3.fromRGB(20, 10, 30),
        UIText = Color3.fromRGB(255, 210, 255),
        UIAccent = Color3.fromRGB(255, 0, 255),
        UIBorder = Color3.fromRGB(128, 0, 128),
        UIHeaderBackground = Color3.fromRGB(40, 20, 60)
    }
}

-- Generate a unique ID for this client to use for saved settings
local function generateUniqueId()
    local id = ""
    for i = 1, 16 do
        id = id .. string.char(math.random(97, 122))
    end
    return id
end

-- Save settings to the file system (using gethui)
function Settings.Save()
    if writefile and isfolder and not isfolder("EnhancedRivals") then
        pcall(function()
            makefolder("EnhancedRivals")
        end)
    end
    
    if writefile then
        local success, result = pcall(function()
            local json = game:GetService("HttpService"):JSONEncode(Settings.Current)
            writefile("EnhancedRivals/settings.json", json)
            return true
        end)
        
        return success
    end
    
    return false
end

-- Load settings from the file system
function Settings.Load()
    if readfile and isfile and isfile("EnhancedRivals/settings.json") then
        local success, result = pcall(function()
            local json = readfile("EnhancedRivals/settings.json")
            local decoded = game:GetService("HttpService"):JSONDecode(json)
            
            -- Merge loaded settings with defaults (to add any new settings)
            for key, value in pairs(decoded) do
                if type(value) == "table" and type(Settings.Current[key]) == "table" then
                    for subKey, subValue in pairs(value) do
                        Settings.Current[key][subKey] = subValue
                    end
                else
                    Settings.Current[key] = value
                end
            end
            
            return true
        end)
        
        return success
    end
    
    return false
end

-- Apply theme from presets
function Settings.ApplyTheme(themeName)
    if Settings.ThemePresets[themeName] then
        for key, color in pairs(Settings.ThemePresets[themeName]) do
            Settings.Current.Colors[key] = color
        end
        Settings.Current.UITheme = themeName
    end
end

-- Update a single setting
function Settings.Update(category, setting, value)
    if category == "Colors" then
        if Settings.Current.Colors[setting] ~= nil then
            Settings.Current.Colors[setting] = value
            return true
        end
    else
        if Settings.Current[setting] ~= nil then
            Settings.Current[setting] = value
            return true
        end
    end
    return false
end

-- Reset settings to default
function Settings.Reset()
    for key, value in pairs(Settings.Default) do
        if type(value) == "table" then
            Settings.Current[key] = {}
            for subKey, subValue in pairs(value) do
                Settings.Current[key][subKey] = subValue
            end
        else
            Settings.Current[key] = value
        end
    end
    
    -- Save the reset settings
    Settings.Save()
    return true
end

-- Load settings on initialization
Settings.Load()

return Settings
