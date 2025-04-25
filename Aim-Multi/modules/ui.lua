--[[
    Enhanced Rivals - UI Module
    Creates and manages the modern, animated user interface
]]

local UI = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")

-- Local variables
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local DrawingObjects = {}
local ActiveToggles = {}
local ActiveSliders = {}
local ActiveDropdowns = {}
local ActiveColorPickers = {}
local ActiveNotifications = {}
local UIVisible = true
local DraggingUI = false
local DragOffset = Vector2.new(0, 0)
local CurrentTab = "Aimbot"
local AnimationTweens = {}
local LastMousePos = Vector2.new(0, 0)
local UIScale = 1
local TabButtons = {}
local ModuleReferences = {}
local SettingsChanged = false
local UICreated = false

-- Constants
local UI_WIDTH = 350
local UI_HEIGHT = 450
local HEADER_HEIGHT = 40
local TAB_HEIGHT = 30
local UI_ROUNDING = 8
local UI_ANIMATION_SPEED = 0.3
local UI_PADDING = 10
local BUTTON_HEIGHT = 30
local SLIDER_HEIGHT = 45
local DROPDOWN_HEIGHT = 70
local TOGGLE_HEIGHT = 35
local COLOR_PICKER_HEIGHT = 180
local SECTION_SPACING = 15
local CONTROL_SPACING = 8
local NOTIFICATION_WIDTH = 250
local NOTIFICATION_HEIGHT = 60
local NOTIFICATION_DURATION = 3

-- UI Sections and Controls
local Sections = {
    Aimbot = {
        title = "Aimbot Settings",
        controls = {}
    },
    ESP = {
        title = "ESP Settings",
        controls = {}
    },
    Visuals = {
        title = "Visual Settings",
        controls = {}
    },
    Advanced = {
        title = "Advanced Settings",
        controls = {}
    }
}

-- Initialize drawing object
local function createDrawingObject(type, properties)
    local obj = Drawing.new(type)
    
    if properties then
        for prop, value in pairs(properties) do
            obj[prop] = value
        end
    end
    
    return obj
end

-- Create UI elements
local function createUIElements()
    -- Background
    DrawingObjects.Background = createDrawingObject("Square", {
        Size = Vector2.new(UI_WIDTH, UI_HEIGHT),
        Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20, 100),
        Color = ModuleReferences.Settings.Current.Colors.UIBackground,
        Filled = true,
        Visible = false,
        Transparency = ModuleReferences.Settings.Current.UITransparency
    })
    
    -- Border
    DrawingObjects.Border = createDrawingObject("Square", {
        Size = Vector2.new(UI_WIDTH, UI_HEIGHT),
        Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20, 100),
        Color = ModuleReferences.Settings.Current.Colors.UIBorder,
        Filled = false,
        Thickness = 2,
        Visible = false,
        Transparency = ModuleReferences.Settings.Current.UITransparency
    })
    
    -- Header background
    DrawingObjects.HeaderBackground = createDrawingObject("Square", {
        Size = Vector2.new(UI_WIDTH, HEADER_HEIGHT),
        Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20, 100),
        Color = ModuleReferences.Settings.Current.Colors.UIHeaderBackground,
        Filled = true,
        Visible = false,
        Transparency = ModuleReferences.Settings.Current.UITransparency
    })
    
    -- Title text
    DrawingObjects.TitleText = createDrawingObject("Text", {
        Text = "Enhanced Rivals v2.0",
        Size = 18,
        Center = false,
        Outline = true,
        Color = ModuleReferences.Settings.Current.Colors.UIText,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20 + 10, 100 + 11),
        Visible = false
    })
    
    -- Close button
    DrawingObjects.CloseButton = createDrawingObject("Square", {
        Size = Vector2.new(20, 20),
        Position = Vector2.new(Camera.ViewportSize.X - 20 - 30, 100 + 10),
        Color = Color3.fromRGB(255, 80, 80),
        Filled = true,
        Visible = false,
        Transparency = 0.8
    })
    
    DrawingObjects.CloseX = createDrawingObject("Text", {
        Text = "×",
        Size = 20,
        Center = true,
        Outline = true,
        Color = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Position = Vector2.new(Camera.ViewportSize.X - 20 - 20, 100 + 9),
        Visible = false
    })
    
    -- Tab bar background
    DrawingObjects.TabBackground = createDrawingObject("Square", {
        Size = Vector2.new(UI_WIDTH, TAB_HEIGHT),
        Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20, 100 + HEADER_HEIGHT),
        Color = ModuleReferences.Settings.Current.Colors.UIHeaderBackground,
        Filled = true,
        Visible = false,
        Transparency = ModuleReferences.Settings.Current.UITransparency * 0.8
    })
    
    -- Tab buttons
    local tabNames = {"Aimbot", "ESP", "Visuals", "Advanced"}
    local tabWidth = UI_WIDTH / #tabNames
    
    for i, tabName in ipairs(tabNames) do
        local tabButton = {
            background = createDrawingObject("Square", {
                Size = Vector2.new(tabWidth, TAB_HEIGHT),
                Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20 + (i-1) * tabWidth, 100 + HEADER_HEIGHT),
                Color = (tabName == CurrentTab) and ModuleReferences.Settings.Current.Colors.UIAccent or ModuleReferences.Settings.Current.Colors.UIHeaderBackground,
                Filled = true,
                Visible = false,
                Transparency = (tabName == CurrentTab) and 0.7 or 0.3
            }),
            text = createDrawingObject("Text", {
                Text = tabName,
                Size = 16,
                Center = true,
                Outline = true,
                Color = ModuleReferences.Settings.Current.Colors.UIText,
                OutlineColor = Color3.fromRGB(0, 0, 0),
                Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20 + (i-1) * tabWidth + tabWidth/2, 100 + HEADER_HEIGHT + 7),
                Visible = false
            })
        }
        
        DrawingObjects["Tab_" .. tabName .. "_BG"] = tabButton.background
        DrawingObjects["Tab_" .. tabName .. "_Text"] = tabButton.text
        
        TabButtons[tabName] = {
            name = tabName,
            background = tabButton.background,
            text = tabButton.text,
            position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20 + (i-1) * tabWidth, 100 + HEADER_HEIGHT),
            size = Vector2.new(tabWidth, TAB_HEIGHT)
        }
    end
    
    -- Content area background
    DrawingObjects.ContentBackground = createDrawingObject("Square", {
        Size = Vector2.new(UI_WIDTH - UI_PADDING * 2, UI_HEIGHT - HEADER_HEIGHT - TAB_HEIGHT - UI_PADDING),
        Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20 + UI_PADDING, 100 + HEADER_HEIGHT + TAB_HEIGHT + UI_PADDING / 2),
        Color = ModuleReferences.Settings.Current.Colors.UIBackground,
        Filled = true,
        Visible = false,
        Transparency = ModuleReferences.Settings.Current.UITransparency * 0.8
    })
    
    -- Content border
    DrawingObjects.ContentBorder = createDrawingObject("Square", {
        Size = Vector2.new(UI_WIDTH - UI_PADDING * 2, UI_HEIGHT - HEADER_HEIGHT - TAB_HEIGHT - UI_PADDING),
        Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20 + UI_PADDING, 100 + HEADER_HEIGHT + TAB_HEIGHT + UI_PADDING / 2),
        Color = ModuleReferences.Settings.Current.Colors.UIBorder,
        Filled = false,
        Thickness = 1,
        Visible = false,
        Transparency = ModuleReferences.Settings.Current.UITransparency
    })
    
    -- Notification container
    DrawingObjects.NotificationContainer = {
        notifications = {}  -- Will store active notifications
    }
    
    -- Save button
    DrawingObjects.SaveButton = createDrawingObject("Square", {
        Size = Vector2.new(80, 30),
        Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20 + UI_WIDTH - 90, 100 + UI_HEIGHT - 40),
        Color = ModuleReferences.Settings.Current.Colors.UISuccess,
        Filled = true,
        Visible = false,
        Transparency = 0.8
    })
    
    DrawingObjects.SaveText = createDrawingObject("Text", {
        Text = "Save",
        Size = 16,
        Center = true,
        Outline = true,
        Color = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Position = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20 + UI_WIDTH - 50, 100 + UI_HEIGHT - 33),
        Visible = false
    })
    
    -- Content items will be created dynamically based on the current tab
    DrawingObjects.ContentItems = {}
end

-- Create tab content based on the current tab
local function createTabContent()
    -- Clear existing content items
    for _, item in pairs(DrawingObjects.ContentItems) do
        if typeof(item) == "table" then
            for _, subItem in pairs(item) do
                ModuleReferences.Utils.SafeRemoveDrawing(subItem)
            end
        else
            ModuleReferences.Utils.SafeRemoveDrawing(item)
        end
    end
    DrawingObjects.ContentItems = {}
    
    -- Get content base position
    local contentBaseX = DrawingObjects.ContentBackground.Position.X
    local contentBaseY = DrawingObjects.ContentBackground.Position.Y
    local contentWidth = DrawingObjects.ContentBackground.Size.X
    
    -- Add section title
    DrawingObjects.ContentItems.SectionTitle = createDrawingObject("Text", {
        Text = Sections[CurrentTab].title,
        Size = 18,
        Center = false,
        Outline = true,
        Color = ModuleReferences.Settings.Current.Colors.UIAccent,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Position = Vector2.new(contentBaseX + 5, contentBaseY + 10),
        Visible = UIVisible
    })
    
    -- Add section divider
    DrawingObjects.ContentItems.SectionDivider = createDrawingObject("Line", {
        From = Vector2.new(contentBaseX, contentBaseY + 35),
        To = Vector2.new(contentBaseX + contentWidth, contentBaseY + 35),
        Color = ModuleReferences.Settings.Current.Colors.UIBorder,
        Thickness = 1,
        Visible = UIVisible,
        Transparency = 0.7
    })
    
    -- Current Y position for adding controls
    local currentY = contentBaseY + 45
    
    -- Create controls based on the current tab
    if CurrentTab == "Aimbot" then
        -- Toggle for enabling/disabling aimbot
        createToggle("AimbotEnabled", "Enable Aimbot", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.AimbotEnabled)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Toggle for showing FOV circle
        createToggle("ShowFOV", "Show FOV Circle", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.ShowFOV)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- FOV Radius slider
        createSlider("FOVRadius", "FOV Radius", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.FOVRadius, 50, 500, 1)
        currentY = currentY + SLIDER_HEIGHT + CONTROL_SPACING
        
        -- Aimbot smoothness slider
        createSlider("AimbotSmoothness", "Aimbot Smoothness", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.AimbotSmoothness, 0.01, 1, 0.01)
        currentY = currentY + SLIDER_HEIGHT + CONTROL_SPACING
        
        -- Target hitbox dropdown
        createDropdown("TargetHitbox", "Target Hitbox", contentBaseX, currentY, contentWidth,
            ModuleReferences.Settings.Current.TargetHitbox, {"Head", "HumanoidRootPart", "Torso"})
        currentY = currentY + DROPDOWN_HEIGHT + CONTROL_SPACING
        
        -- Aimbot method dropdown
        createDropdown("AimbotMethod", "Aimbot Method", contentBaseX, currentY, contentWidth,
            ModuleReferences.Settings.Current.AimbotMethod, {"Camera", "Mouse"})
        currentY = currentY + DROPDOWN_HEIGHT + CONTROL_SPACING
        
        -- Toggle for team check
        createToggle("AimbotTeamCheck", "Team Check", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.AimbotTeamCheck)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Toggle for visibility check
        createToggle("AimbotVisibilityCheck", "Visibility Check", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.AimbotVisibilityCheck)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Toggle for auto-clicking
        createToggle("AutoClickEnabled", "Auto Click", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.AutoClickEnabled)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Auto-click interval slider
        if ModuleReferences.Settings.Current.AutoClickEnabled then
            createSlider("ClickInterval", "Click Interval", contentBaseX, currentY, contentWidth, 
                ModuleReferences.Settings.Current.ClickInterval, 0.01, 0.5, 0.01)
            currentY = currentY + SLIDER_HEIGHT + CONTROL_SPACING
        end
        
    elseif CurrentTab == "ESP" then
        -- Toggle for enabling/disabling ESP
        createToggle("ESPEnabled", "Enable ESP", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.ESPEnabled)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- ESP Feature toggles
        createToggle("BoxESP", "Box ESP", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.BoxESP)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        createToggle("NameESP", "Name ESP", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.NameESP)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        createToggle("TracerESP", "Tracer ESP", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.TracerESP)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        createToggle("BoneESP", "Bone ESP", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.BoneESP)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        createToggle("HealthESP", "Health ESP", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.HealthESP)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        createToggle("DistanceESP", "Distance ESP", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.DistanceESP)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        createToggle("OutOfViewArrows", "Off-Screen Arrows", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.OutOfViewArrows)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Max ESP distance slider
        createSlider("MaxESPDistance", "ESP Distance", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.MaxESPDistance, 100, 2000, 50)
        currentY = currentY + SLIDER_HEIGHT + CONTROL_SPACING
        
        -- Toggle for team check
        createToggle("ESPTeamCheck", "Team Check", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.ESPTeamCheck)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Toggle for visibility check
        createToggle("ESPVisibilityCheck", "Visibility Check", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.ESPVisibilityCheck)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
    elseif CurrentTab == "Visuals" then
        -- Theme dropdown
        createDropdown("UITheme", "UI Theme", contentBaseX, currentY, contentWidth,
            ModuleReferences.Settings.Current.UITheme, {"Dark", "Light", "Matrix", "Retrowave"})
        currentY = currentY + DROPDOWN_HEIGHT + CONTROL_SPACING
        
        -- UI Scale slider
        createSlider("UIScale", "UI Scale", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.UIScale, 0.8, 1.5, 0.05)
        currentY = currentY + SLIDER_HEIGHT + CONTROL_SPACING
        
        -- UI Transparency slider
        createSlider("UITransparency", "UI Transparency", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.UITransparency, 0.5, 1, 0.05)
        currentY = currentY + SLIDER_HEIGHT + CONTROL_SPACING
        
        -- UI Animations toggle
        createToggle("UIAnimations", "UI Animations", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.UIAnimations)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- ESP Smoothness toggle
        createToggle("ESPSmoothness", "Smooth ESP Updates", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.ESPSmoothness)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Color section divider
        DrawingObjects.ContentItems.ColorDivider = createDrawingObject("Line", {
            From = Vector2.new(contentBaseX, currentY),
            To = Vector2.new(contentBaseX + contentWidth, currentY),
            Color = ModuleReferences.Settings.Current.Colors.UIBorder,
            Thickness = 1,
            Visible = UIVisible,
            Transparency = 0.7
        })
        currentY = currentY + 15
        
        -- Color section title
        DrawingObjects.ContentItems.ColorTitle = createDrawingObject("Text", {
            Text = "Color Settings",
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIAccent,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(contentBaseX + 5, currentY),
            Visible = UIVisible
        })
        currentY = currentY + 25
        
        -- Color pickers for various elements
        createColorPicker("FOV", "FOV Circle Color", contentBaseX, currentY, contentWidth,
            ModuleReferences.Settings.Current.Colors.FOV)
        currentY = currentY + COLOR_PICKER_HEIGHT + CONTROL_SPACING
        
        createColorPicker("ESPPlayer", "Enemy ESP Color", contentBaseX, currentY, contentWidth,
            ModuleReferences.Settings.Current.Colors.ESPPlayer)
        currentY = currentY + COLOR_PICKER_HEIGHT + CONTROL_SPACING
        
        createColorPicker("ESPTarget", "Target ESP Color", contentBaseX, currentY, contentWidth,
            ModuleReferences.Settings.Current.Colors.ESPTarget)
        currentY = currentY + COLOR_PICKER_HEIGHT + CONTROL_SPACING
        
    elseif CurrentTab == "Advanced" then
        -- Drawing quality dropdown
        createDropdown("DrawingQuality", "Drawing Quality", contentBaseX, currentY, contentWidth,
            ModuleReferences.Settings.Current.DrawingQuality, {"Low", "Medium", "High"})
        currentY = currentY + DROPDOWN_HEIGHT + CONTROL_SPACING
        
        -- Toggle for performance mode
        createToggle("PerformanceMode", "Performance Mode", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.PerformanceMode)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Toggle for memory optimization
        createToggle("MemoryOptimized", "Memory Optimization", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.MemoryOptimized)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Toggle for debug mode
        createToggle("DebugMode", "Debug Mode", contentBaseX, currentY, contentWidth, 
            ModuleReferences.Settings.Current.DebugMode)
        currentY = currentY + TOGGLE_HEIGHT + CONTROL_SPACING
        
        -- Keybind section divider
        DrawingObjects.ContentItems.KeybindDivider = createDrawingObject("Line", {
            From = Vector2.new(contentBaseX, currentY),
            To = Vector2.new(contentBaseX + contentWidth, currentY),
            Color = ModuleReferences.Settings.Current.Colors.UIBorder,
            Thickness = 1,
            Visible = UIVisible,
            Transparency = 0.7
        })
        currentY = currentY + 15
        
        -- Keybind section title
        DrawingObjects.ContentItems.KeybindTitle = createDrawingObject("Text", {
            Text = "Keybinds",
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIAccent,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(contentBaseX + 5, currentY),
            Visible = UIVisible
        })
        currentY = currentY + 25
        
        -- Keybind descriptions
        DrawingObjects.ContentItems.ToggleUIKeyText = createDrawingObject("Text", {
            Text = "Toggle UI: Insert",
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIText,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(contentBaseX + 10, currentY),
            Visible = UIVisible
        })
        currentY = currentY + 25
        
        DrawingObjects.ContentItems.UnloadKeyText = createDrawingObject("Text", {
            Text = "Unload Script: End",
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIText,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(contentBaseX + 10, currentY),
            Visible = UIVisible
        })
        currentY = currentY + 25
        
        DrawingObjects.ContentItems.AimbotKeyText = createDrawingObject("Text", {
            Text = "Toggle Aimbot: Right Alt",
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIText,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(contentBaseX + 10, currentY),
            Visible = UIVisible
        })
        currentY = currentY + 25
        
        -- Credits
        DrawingObjects.ContentItems.CreditsDivider = createDrawingObject("Line", {
            From = Vector2.new(contentBaseX, currentY + 10),
            To = Vector2.new(contentBaseX + contentWidth, currentY + 10),
            Color = ModuleReferences.Settings.Current.Colors.UIBorder,
            Thickness = 1,
            Visible = UIVisible,
            Transparency = 0.7
        })
        currentY = currentY + 25
        
        DrawingObjects.ContentItems.CreditsText = createDrawingObject("Text", {
            Text = "Enhanced Rivals v2.0",
            Size = 16,
            Center = true,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIAccent,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(contentBaseX + contentWidth/2, currentY),
            Visible = UIVisible
        })
        
        -- Reset button
        DrawingObjects.ContentItems.ResetButton = createDrawingObject("Square", {
            Size = Vector2.new(120, 30),
            Position = Vector2.new(contentBaseX + contentWidth/2 - 60, currentY + 30),
            Color = ModuleReferences.Settings.Current.Colors.UIDanger,
            Filled = true,
            Visible = UIVisible,
            Transparency = 0.8
        })
        
        DrawingObjects.ContentItems.ResetText = createDrawingObject("Text", {
            Text = "Reset Settings",
            Size = 16,
            Center = true,
            Outline = true,
            Color = Color3.fromRGB(255, 255, 255),
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(contentBaseX + contentWidth/2, currentY + 37),
            Visible = UIVisible
        })
    end
end

-- Create a button control
local function createButton(id, text, x, y, width, color)
    local button = {
        background = createDrawingObject("Square", {
            Size = Vector2.new(width, BUTTON_HEIGHT),
            Position = Vector2.new(x, y),
            Color = color or ModuleReferences.Settings.Current.Colors.UIAccent,
            Filled = true,
            Visible = UIVisible,
            Transparency = 0.8
        }),
        text = createDrawingObject("Text", {
            Text = text,
            Size = 16,
            Center = true,
            Outline = true,
            Color = Color3.fromRGB(255, 255, 255),
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(x + width/2, y + BUTTON_HEIGHT/2 - 8),
            Visible = UIVisible
        })
    }
    
    DrawingObjects.ContentItems[id .. "_Button"] = button.background
    DrawingObjects.ContentItems[id .. "_Text"] = button.text
    
    return button
end

-- Create a toggle control
local function createToggle(id, text, x, y, width, value)
    local toggle = {
        text = createDrawingObject("Text", {
            Text = text,
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIText,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(x + 5, y + 5),
            Visible = UIVisible
        }),
        background = createDrawingObject("Square", {
            Size = Vector2.new(20, 20),
            Position = Vector2.new(x + width - 30, y + 5),
            Color = value and ModuleReferences.Settings.Current.Colors.UISuccess or ModuleReferences.Settings.Current.Colors.UIDanger,
            Filled = true,
            Visible = UIVisible,
            Transparency = 0.8
        }),
        checkmark = createDrawingObject("Text", {
            Text = value and "✓" or "✗",
            Size = 16,
            Center = true,
            Outline = true,
            Color = Color3.fromRGB(255, 255, 255),
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(x + width - 20, y + 5),
            Visible = UIVisible
        })
    }
    
    DrawingObjects.ContentItems[id .. "_Text"] = toggle.text
    DrawingObjects.ContentItems[id .. "_BG"] = toggle.background
    DrawingObjects.ContentItems[id .. "_Check"] = toggle.checkmark
    
    -- Store toggle data for interaction
    ActiveToggles[id] = {
        id = id,
        value = value,
        background = toggle.background,
        checkmark = toggle.checkmark,
        position = Vector2.new(x + width - 30, y + 5),
        size = Vector2.new(20, 20)
    }
    
    return toggle
end

-- Create a slider control
local function createSlider(id, text, x, y, width, value, min, max, step)
    local valueText = string.format("%.2f", value)
    if step >= 1 then
        valueText = string.format("%d", value)
    end
    
    local sliderWidth = width - 20
    local fillWidth = (value - min) / (max - min) * sliderWidth
    
    local slider = {
        text = createDrawingObject("Text", {
            Text = text .. ": " .. valueText,
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIText,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(x + 5, y + 5),
            Visible = UIVisible
        }),
        background = createDrawingObject("Square", {
            Size = Vector2.new(sliderWidth, 8),
            Position = Vector2.new(x + 10, y + 30),
            Color = Color3.fromRGB(50, 50, 60),
            Filled = true,
            Visible = UIVisible,
            Transparency = 0.8
        }),
        fill = createDrawingObject("Square", {
            Size = Vector2.new(fillWidth, 8),
            Position = Vector2.new(x + 10, y + 30),
            Color = ModuleReferences.Settings.Current.Colors.UIAccent,
            Filled = true,
            Visible = UIVisible,
            Transparency = 0.8
        }),
        knob = createDrawingObject("Square", {
            Size = Vector2.new(10, 16),
            Position = Vector2.new(x + 10 + fillWidth - 5, y + 30 - 4),
            Color = Color3.fromRGB(255, 255, 255),
            Filled = true,
            Visible = UIVisible,
            Transparency = 0.9
        })
    }
    
    DrawingObjects.ContentItems[id .. "_Text"] = slider.text
    DrawingObjects.ContentItems[id .. "_BG"] = slider.background
    DrawingObjects.ContentItems[id .. "_Fill"] = slider.fill
    DrawingObjects.ContentItems[id .. "_Knob"] = slider.knob
    
    -- Store slider data for interaction
    ActiveSliders[id] = {
        id = id,
        value = value,
        min = min,
        max = max,
        step = step,
        text = slider.text,
        background = slider.background,
        fill = slider.fill,
        knob = slider.knob,
        position = Vector2.new(x + 10, y + 30),
        size = Vector2.new(sliderWidth, 8),
        dragging = false,
        formatString = step >= 1 and "%d" or "%.2f"
    }
    
    return slider
end

-- Create a dropdown control
local function createDropdown(id, text, x, y, width, value, options)
    local dropdown = {
        text = createDrawingObject("Text", {
            Text = text,
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIText,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(x + 5, y + 5),
            Visible = UIVisible
        }),
        background = createDrawingObject("Square", {
            Size = Vector2.new(width - 10, 30),
            Position = Vector2.new(x + 5, y + 25),
            Color = Color3.fromRGB(40, 40, 50),
            Filled = true,
            Visible = UIVisible,
            Transparency = 0.8
        }),
        valueText = createDrawingObject("Text", {
            Text = value,
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIText,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(x + 15, y + 32),
            Visible = UIVisible
        }),
        arrow = createDrawingObject("Text", {
            Text = "▼",
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIText,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(x + width - 25, y + 32),
            Visible = UIVisible
        }),
        optionsContainer = createDrawingObject("Square", {
            Size = Vector2.new(width - 10, #options * 25),
            Position = Vector2.new(x + 5, y + 55),
            Color = Color3.fromRGB(50, 50, 60),
            Filled = true,
            Visible = false,
            Transparency = 0.9
        }),
        optionItems = {}
    }
    
    for i, option in ipairs(options) do
        dropdown.optionItems[i] = {
            background = createDrawingObject("Square", {
                Size = Vector2.new(width - 10, 25),
                Position = Vector2.new(x + 5, y + 55 + (i-1) * 25),
                Color = option == value and ModuleReferences.Settings.Current.Colors.UIAccent or Color3.fromRGB(50, 50, 60),
                Filled = true,
                Visible = false,
                Transparency = option == value and 0.7 or 0.5
            }),
            text = createDrawingObject("Text", {
                Text = option,
                Size = 16,
                Center = false,
                Outline = true,
                Color = ModuleReferences.Settings.Current.Colors.UIText,
                OutlineColor = Color3.fromRGB(0, 0, 0),
                Position = Vector2.new(x + 15, y + 55 + (i-1) * 25 + 5),
                Visible = false
            })
        }
    end
    
    DrawingObjects.ContentItems[id .. "_Text"] = dropdown.text
    DrawingObjects.ContentItems[id .. "_BG"] = dropdown.background
    DrawingObjects.ContentItems[id .. "_Value"] = dropdown.valueText
    DrawingObjects.ContentItems[id .. "_Arrow"] = dropdown.arrow
    DrawingObjects.ContentItems[id .. "_OptionsBG"] = dropdown.optionsContainer
    
    for i, option in ipairs(dropdown.optionItems) do
        DrawingObjects.ContentItems[id .. "_Option" .. i .. "_BG"] = option.background
        DrawingObjects.ContentItems[id .. "_Option" .. i .. "_Text"] = option.text
    end
    
    -- Store dropdown data for interaction
    ActiveDropdowns[id] = {
        id = id,
        value = value,
        options = options,
        background = dropdown.background,
        valueText = dropdown.valueText,
        arrow = dropdown.arrow,
        optionsContainer = dropdown.optionsContainer,
        optionItems = dropdown.optionItems,
        position = Vector2.new(x + 5, y + 25),
        size = Vector2.new(width - 10, 30),
        optionsPosition = Vector2.new(x + 5, y + 55),
        expanded = false
    }
    
    return dropdown
end

-- Create a color picker control
local function createColorPicker(id, text, x, y, width, color)
    local colorPicker = {
        text = createDrawingObject("Text", {
            Text = text,
            Size = 16,
            Center = false,
            Outline = true,
            Color = ModuleReferences.Settings.Current.Colors.UIText,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(x + 5, y + 5),
            Visible = UIVisible
        }),
        previewBorder = createDrawingObject("Square", {
            Size = Vector2.new(30, 30),
            Position = Vector2.new(x + width - 40, y + 5),
            Color = Color3.fromRGB(255, 255, 255),
            Filled = false,
            Thickness = 1,
            Visible = UIVisible
        }),
        preview = createDrawingObject("Square", {
            Size = Vector2.new(28, 28),
            Position = Vector2.new(x + width - 39, y + 6),
            Color = color,
            Filled = true,
            Visible = UIVisible
        }),
        sliders = {
            -- Red slider
            rText = createDrawingObject("Text", {
                Text = "R: " .. math.floor(color.R * 255),
                Size = 16,
                Center = false,
                Outline = true,
                Color = Color3.fromRGB(255, 100, 100),
                OutlineColor = Color3.fromRGB(0, 0, 0),
                Position = Vector2.new(x + 5, y + 40),
                Visible = UIVisible
            }),
            rBackground = createDrawingObject("Square", {
                Size = Vector2.new(width - 60, 8),
                Position = Vector2.new(x + 10, y + 60),
                Color = Color3.fromRGB(50, 50, 60),
                Filled = true,
                Visible = UIVisible,
                Transparency = 0.8
            }),
            rFill = createDrawingObject("Square", {
                Size = Vector2.new((width - 60) * color.R, 8),
                Position = Vector2.new(x + 10, y + 60),
                Color = Color3.fromRGB(255, 50, 50),
                Filled = true,
                Visible = UIVisible,
                Transparency = 0.8
            }),
            rKnob = createDrawingObject("Square", {
                Size = Vector2.new(10, 16),
                Position = Vector2.new(x + 10 + (width - 60) * color.R - 5, y + 60 - 4),
                Color = Color3.fromRGB(255, 150, 150),
                Filled = true,
                Visible = UIVisible,
                Transparency = 0.9
            }),
            
            -- Green slider
            gText = createDrawingObject("Text", {
                Text = "G: " .. math.floor(color.G * 255),
                Size = 16,
                Center = false,
                Outline = true,
                Color = Color3.fromRGB(100, 255, 100),
                OutlineColor = Color3.fromRGB(0, 0, 0),
                Position = Vector2.new(x + 5, y + 75),
                Visible = UIVisible
            }),
            gBackground = createDrawingObject("Square", {
                Size = Vector2.new(width - 60, 8),
                Position = Vector2.new(x + 10, y + 95),
                Color = Color3.fromRGB(50, 50, 60),
                Filled = true,
                Visible = UIVisible,
                Transparency = 0.8
            }),
            gFill = createDrawingObject("Square", {
                Size = Vector2.new((width - 60) * color.G, 8),
                Position = Vector2.new(x + 10, y + 95),
                Color = Color3.fromRGB(50, 255, 50),
                Filled = true,
                Visible = UIVisible,
                Transparency = 0.8
            }),
            gKnob = createDrawingObject("Square", {
                Size = Vector2.new(10, 16),
                Position = Vector2.new(x + 10 + (width - 60) * color.G - 5, y + 95 - 4),
                Color = Color3.fromRGB(150, 255, 150),
                Filled = true,
                Visible = UIVisible,
                Transparency = 0.9
            }),
            
            -- Blue slider
            bText = createDrawingObject("Text", {
                Text = "B: " .. math.floor(color.B * 255),
                Size = 16,
                Center = false,
                Outline = true,
                Color = Color3.fromRGB(100, 100, 255),
                OutlineColor = Color3.fromRGB(0, 0, 0),
                Position = Vector2.new(x + 5, y + 110),
                Visible = UIVisible
            }),
            bBackground = createDrawingObject("Square", {
                Size = Vector2.new(width - 60, 8),
                Position = Vector2.new(x + 10, y + 130),
                Color = Color3.fromRGB(50, 50, 60),
                Filled = true,
                Visible = UIVisible,
                Transparency = 0.8
            }),
            bFill = createDrawingObject("Square", {
                Size = Vector2.new((width - 60) * color.B, 8),
                Position = Vector2.new(x + 10, y + 130),
                Color = Color3.fromRGB(50, 50, 255),
                Filled = true,
                Visible = UIVisible,
                Transparency = 0.8
            }),
            bKnob = createDrawingObject("Square", {
                Size = Vector2.new(10, 16),
                Position = Vector2.new(x + 10 + (width - 60) * color.B - 5, y + 130 - 4),
                Color = Color3.fromRGB(150, 150, 255),
                Filled = true,
                Visible = UIVisible,
                Transparency = 0.9
            })
        },
        applyButton = createDrawingObject("Square", {
            Size = Vector2.new(80, 25),
            Position = Vector2.new(x + width - 90, y + 150),
            Color = ModuleReferences.Settings.Current.Colors.UISuccess,
            Filled = true,
            Visible = UIVisible,
            Transparency = 0.8
        }),
        applyText = createDrawingObject("Text", {
            Text = "Apply",
            Size = 16,
            Center = true,
            Outline = true,
            Color = Color3.fromRGB(255, 255, 255),
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(x + width - 50, y + 157),
            Visible = UIVisible
        })
    }
    
    -- Add all items to content items
    DrawingObjects.ContentItems[id .. "_Text"] = colorPicker.text
    DrawingObjects.ContentItems[id .. "_PreviewBorder"] = colorPicker.previewBorder
    DrawingObjects.ContentItems[id .. "_Preview"] = colorPicker.preview
    
    DrawingObjects.ContentItems[id .. "_RText"] = colorPicker.sliders.rText
    DrawingObjects.ContentItems[id .. "_RBG"] = colorPicker.sliders.rBackground
    DrawingObjects.ContentItems[id .. "_RFill"] = colorPicker.sliders.rFill
    DrawingObjects.ContentItems[id .. "_RKnob"] = colorPicker.sliders.rKnob
    
    DrawingObjects.ContentItems[id .. "_GText"] = colorPicker.sliders.gText
    DrawingObjects.ContentItems[id .. "_GBG"] = colorPicker.sliders.gBackground
    DrawingObjects.ContentItems[id .. "_GFill"] = colorPicker.sliders.gFill
    DrawingObjects.ContentItems[id .. "_GKnob"] = colorPicker.sliders.gKnob
    
    DrawingObjects.ContentItems[id .. "_BText"] = colorPicker.sliders.bText
    DrawingObjects.ContentItems[id .. "_BBG"] = colorPicker.sliders.bBackground
    DrawingObjects.ContentItems[id .. "_BFill"] = colorPicker.sliders.bFill
    DrawingObjects.ContentItems[id .. "_BKnob"] = colorPicker.sliders.bKnob
    
    DrawingObjects.ContentItems[id .. "_ApplyBG"] = colorPicker.applyButton
    DrawingObjects.ContentItems[id .. "_ApplyText"] = colorPicker.applyText
    
    -- Store color picker data for interaction
    ActiveColorPickers[id] = {
        id = id,
        color = color,
        preview = colorPicker.preview,
        sliders = {
            r = {
                value = color.R,
                text = colorPicker.sliders.rText,
                background = colorPicker.sliders.rBackground,
                fill = colorPicker.sliders.rFill,
                knob = colorPicker.sliders.rKnob,
                position = Vector2.new(x + 10, y + 60),
                size = Vector2.new(width - 60, 8),
                dragging = false
            },
            g = {
                value = color.G,
                text = colorPicker.sliders.gText,
                background = colorPicker.sliders.gBackground,
                fill = colorPicker.sliders.gFill,
                knob = colorPicker.sliders.gKnob,
                position = Vector2.new(x + 10, y + 95),
                size = Vector2.new(width - 60, 8),
                dragging = false
            },
            b = {
                value = color.B,
                text = colorPicker.sliders.bText,
                background = colorPicker.sliders.bBackground,
                fill = colorPicker.sliders.bFill,
                knob = colorPicker.sliders.bKnob,
                position = Vector2.new(x + 10, y + 130),
                size = Vector2.new(width - 60, 8),
                dragging = false
            }
        },
        applyButton = {
            button = colorPicker.applyButton,
            text = colorPicker.applyText,
            position = Vector2.new(x + width - 90, y + 150),
            size = Vector2.new(80, 25)
        }
    }
    
    return colorPicker
end

-- Update UI position during drag
local function updateUIPosition(newPosition)
    local uiX, uiY = newPosition.X, newPosition.Y
    
    -- Update main UI elements
    DrawingObjects.Background.Position = Vector2.new(uiX, uiY)
    DrawingObjects.Border.Position = Vector2.new(uiX, uiY)
    DrawingObjects.HeaderBackground.Position = Vector2.new(uiX, uiY)
    DrawingObjects.TitleText.Position = Vector2.new(uiX + 10, uiY + 11)
    DrawingObjects.CloseButton.Position = Vector2.new(uiX + UI_WIDTH - 30, uiY + 10)
    DrawingObjects.CloseX.Position = Vector2.new(uiX + UI_WIDTH - 20, uiY + 9)
    
    -- Update tab elements
    DrawingObjects.TabBackground.Position = Vector2.new(uiX, uiY + HEADER_HEIGHT)
    
    local tabWidth = UI_WIDTH / #TabButtons
    for tabName, tabButton in pairs(TabButtons) do
        local tabIndex = 0
        for i, name in ipairs({"Aimbot", "ESP", "Visuals", "Advanced"}) do
            if name == tabName then
                tabIndex = i
                break
            end
        end
        
        tabButton.position = Vector2.new(uiX + (tabIndex-1) * tabWidth, uiY + HEADER_HEIGHT)
        tabButton.background.Position = tabButton.position
        tabButton.text.Position = Vector2.new(uiX + (tabIndex-1) * tabWidth + tabWidth/2, uiY + HEADER_HEIGHT + 7)
    end
    
    -- Update content area
    DrawingObjects.ContentBackground.Position = Vector2.new(uiX + UI_PADDING, uiY + HEADER_HEIGHT + TAB_HEIGHT + UI_PADDING / 2)
    DrawingObjects.ContentBorder.Position = Vector2.new(uiX + UI_PADDING, uiY + HEADER_HEIGHT + TAB_HEIGHT + UI_PADDING / 2)
    
    -- Update save button
    DrawingObjects.SaveButton.Position = Vector2.new(uiX + UI_WIDTH - 90, uiY + UI_HEIGHT - 40)
    DrawingObjects.SaveText.Position = Vector2.new(uiX + UI_WIDTH - 50, uiY + UI_HEIGHT - 33)
    
    -- Recreate tab content at new position
    createTabContent()
end

-- Show notification
function UI.ShowNotification(message, color)
    -- Create a notification drawing
    local notif = {
        background = createDrawingObject("Square", {
            Size = Vector2.new(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT),
            Position = Vector2.new(Camera.ViewportSize.X - NOTIFICATION_WIDTH - 20, Camera.ViewportSize.Y - 100 - (#ActiveNotifications * (NOTIFICATION_HEIGHT + 10))),
            Color = color or ModuleReferences.Settings.Current.Colors.UIAccent,
            Filled = true,
            Visible = true,
            Transparency = 0.8
        }),
        border = createDrawingObject("Square", {
            Size = Vector2.new(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT),
            Position = Vector2.new(Camera.ViewportSize.X - NOTIFICATION_WIDTH - 20, Camera.ViewportSize.Y - 100 - (#ActiveNotifications * (NOTIFICATION_HEIGHT + 10))),
            Color = Color3.fromRGB(255, 255, 255),
            Filled = false,
            Thickness = 1,
            Visible = true,
            Transparency = 0.3
        }),
        text = createDrawingObject("Text", {
            Text = message,
            Size = 16,
            Center = false,
            Outline = true,
            Color = Color3.fromRGB(255, 255, 255),
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Position = Vector2.new(Camera.ViewportSize.X - NOTIFICATION_WIDTH - 10, Camera.ViewportSize.Y - 100 - (#ActiveNotifications * (NOTIFICATION_HEIGHT + 10)) + 20),
            Visible = true
        }),
        startTime = tick(),
        duration = NOTIFICATION_DURATION
    }
    
    -- Add animation to notification
    if ModuleReferences.Settings.Current.UIAnimations then
        notif.background.Position = Vector2.new(Camera.ViewportSize.X + 20, notif.background.Position.Y)
        notif.border.Position = Vector2.new(Camera.ViewportSize.X + 20, notif.border.Position.Y)
        notif.text.Position = Vector2.new(Camera.ViewportSize.X + 30, notif.text.Position.Y)
        
        ModuleReferences.Utils.TweenDrawingProperty(notif.background, "Position", Vector2.new(Camera.ViewportSize.X - NOTIFICATION_WIDTH - 20, notif.background.Position.Y), 0.3)
        ModuleReferences.Utils.TweenDrawingProperty(notif.border, "Position", Vector2.new(Camera.ViewportSize.X - NOTIFICATION_WIDTH - 20, notif.border.Position.Y), 0.3)
        ModuleReferences.Utils.TweenDrawingProperty(notif.text, "Position", Vector2.new(Camera.ViewportSize.X - NOTIFICATION_WIDTH - 10, notif.text.Position.Y), 0.3)
    end
    
    -- Add to active notifications
    table.insert(ActiveNotifications, notif)
    
    -- Schedule removal
    delay(NOTIFICATION_DURATION, function()
        local index = table.find(ActiveNotifications, notif)
        if index then
            if ModuleReferences.Settings.Current.UIAnimations then
                -- Animate out
                ModuleReferences.Utils.TweenDrawingProperty(notif.background, "Position", Vector2.new(Camera.ViewportSize.X + 20, notif.background.Position.Y), 0.3)
                ModuleReferences.Utils.TweenDrawingProperty(notif.border, "Position", Vector2.new(Camera.ViewportSize.X + 20, notif.border.Position.Y), 0.3)
                ModuleReferences.Utils.TweenDrawingProperty(notif.text, "Position", Vector2.new(Camera.ViewportSize.X + 30, notif.text.Position.Y), 0.3)
                
                -- Remove after animation
                delay(0.35, function()
                    ModuleReferences.Utils.SafeRemoveDrawing(notif.background)
                    ModuleReferences.Utils.SafeRemoveDrawing(notif.border)
                    ModuleReferences.Utils.SafeRemoveDrawing(notif.text)
                    table.remove(ActiveNotifications, index)
                    UI.UpdateNotificationPositions()
                end)
            else
                -- Remove immediately
                ModuleReferences.Utils.SafeRemoveDrawing(notif.background)
                ModuleReferences.Utils.SafeRemoveDrawing(notif.border)
                ModuleReferences.Utils.SafeRemoveDrawing(notif.text)
                table.remove(ActiveNotifications, index)
                UI.UpdateNotificationPositions()
            end
        end
    end)
    
    return notif
end

-- Update positions of all notifications
function UI.UpdateNotificationPositions()
    for i, notif in ipairs(ActiveNotifications) do
        local targetY = Camera.ViewportSize.Y - 100 - ((i-1) * (NOTIFICATION_HEIGHT + 10))
        
        if ModuleReferences.Settings.Current.UIAnimations then
            ModuleReferences.Utils.TweenDrawingProperty(notif.background, "Position", Vector2.new(notif.background.Position.X, targetY), 0.2)
            ModuleReferences.Utils.TweenDrawingProperty(notif.border, "Position", Vector2.new(notif.border.Position.X, targetY), 0.2)
            ModuleReferences.Utils.TweenDrawingProperty(notif.text, "Position", Vector2.new(notif.text.Position.X, targetY + 20), 0.2)
        else
            notif.background.Position = Vector2.new(notif.background.Position.X, targetY)
            notif.border.Position = Vector2.new(notif.border.Position.X, targetY)
            notif.text.Position = Vector2.new(notif.text.Position.X, targetY + 20)
        end
    end
end

-- Show an error message
function UI.ShowErrorMessage(message)
    return UI.ShowNotification("Error: " .. message, ModuleReferences.Settings.Current.Colors.UIDanger)
end

-- Show a warning message
function UI.ShowWarning(message)
    return UI.ShowNotification("Warning: " .. message, ModuleReferences.Settings.Current.Colors.UIWarning)
end

-- Update the UI theme
function UI.UpdateTheme()
    if not UICreated then return end
    
    -- Update main UI colors
    DrawingObjects.Background.Color = ModuleReferences.Settings.Current.Colors.UIBackground
    DrawingObjects.Border.Color = ModuleReferences.Settings.Current.Colors.UIBorder
    DrawingObjects.HeaderBackground.Color = ModuleReferences.Settings.Current.Colors.UIHeaderBackground
    DrawingObjects.TitleText.Color = ModuleReferences.Settings.Current.Colors.UIText
    DrawingObjects.TabBackground.Color = ModuleReferences.Settings.Current.Colors.UIHeaderBackground
    DrawingObjects.ContentBackground.Color = ModuleReferences.Settings.Current.Colors.UIBackground
    DrawingObjects.ContentBorder.Color = ModuleReferences.Settings.Current.Colors.UIBorder
    
    -- Update tab buttons
    for tabName, tabButton in pairs(TabButtons) do
        tabButton.background.Color = (tabName == CurrentTab) and ModuleReferences.Settings.Current.Colors.UIAccent or ModuleReferences.Settings.Current.Colors.UIHeaderBackground
        tabButton.text.Color = ModuleReferences.Settings.Current.Colors.UIText
    end
    
    -- Update transparency
    DrawingObjects.Background.Transparency = ModuleReferences.Settings.Current.UITransparency
    DrawingObjects.HeaderBackground.Transparency = ModuleReferences.Settings.Current.UITransparency
    DrawingObjects.TabBackground.Transparency = ModuleReferences.Settings.Current.UITransparency * 0.8
    DrawingObjects.ContentBackground.Transparency = ModuleReferences.Settings.Current.UITransparency * 0.8
    
    -- Update content
    createTabContent()
end

-- Update settings UI when settings change
function UI.UpdateSettingsUI()
    createTabContent()
    UI.UpdateTheme()
    
    -- Mark settings as changed
    SettingsChanged = true
    
    -- Show save button with animation
    if DrawingObjects.SaveButton then
        DrawingObjects.SaveButton.Visible = UIVisible
        DrawingObjects.SaveText.Visible = UIVisible
        
        if ModuleReferences.Settings.Current.UIAnimations then
            ModuleReferences.Utils.ShakeDrawing(DrawingObjects.SaveButton, "Position", 2, 0.3)
            ModuleReferences.Utils.TweenDrawingProperty(DrawingObjects.SaveButton, "Transparency", 1, 0.3, function()
                ModuleReferences.Utils.TweenDrawingProperty(DrawingObjects.SaveButton, "Transparency", 0.8, 0.3)
            end)
        end
    end
end

-- Update the toggle button state
function UI.UpdateToggleButton(id, state)
    if not ActiveToggles[id] then return end
    
    ActiveToggles[id].value = state
    ActiveToggles[id].background.Color = state and ModuleReferences.Settings.Current.Colors.UISuccess or ModuleReferences.Settings.Current.Colors.UIDanger
    ActiveToggles[id].checkmark.Text = state and "✓" or "✗"
    
    -- Mark settings as changed
    SettingsChanged = true
end

-- Play intro animation
function UI.PlayIntroAnimation()
    if not ModuleReferences.Settings.Current.UIAnimations then return end
    
    -- Starting position (off-screen)
    local startPos = Vector2.new(Camera.ViewportSize.X + 50, DrawingObjects.Background.Position.Y)
    local targetPos = Vector2.new(Camera.ViewportSize.X - UI_WIDTH - 20, DrawingObjects.Background.Position.Y)
    
    -- Hide UI temporarily
    local wasVisible = UIVisible
    UI.Toggle(false)
    
    -- Set starting positions
    DrawingObjects.Background.Position = startPos
    DrawingObjects.Border.Position = startPos
    DrawingObjects.HeaderBackground.Position = startPos
    DrawingObjects.TitleText.Position = Vector2.new(startPos.X + 10, startPos.Y + 11)
    DrawingObjects.CloseButton.Position = Vector2.new(startPos.X + UI_WIDTH - 30, startPos.Y + 10)
    DrawingObjects.CloseX.Position = Vector2.new(startPos.X + UI_WIDTH - 20, startPos.Y + 9)
    DrawingObjects.TabBackground.Position = Vector2.new(startPos.X, startPos.Y + HEADER_HEIGHT)
    DrawingObjects.ContentBackground.Position = Vector2.new(startPos.X + UI_PADDING, startPos.Y + HEADER_HEIGHT + TAB_HEIGHT + UI_PADDING / 2)
    DrawingObjects.ContentBorder.Position = Vector2.new(startPos.X + UI_PADDING, startPos.Y + HEADER_HEIGHT + TAB_HEIGHT + UI_PADDING / 2)
    DrawingObjects.SaveButton.Position = Vector2.new(startPos.X + UI_WIDTH - 90, startPos.Y + UI_HEIGHT - 40)
    DrawingObjects.SaveText.Position = Vector2.new(startPos.X + UI_WIDTH - 50, startPos.Y + UI_HEIGHT - 33)
    
    -- Update tab buttons
    local tabWidth = UI_WIDTH / #TabButtons
    for tabName, tabButton in pairs(TabButtons) do
        local tabIndex = 0
        for i, name in ipairs({"Aimbot", "ESP", "Visuals", "Advanced"}) do
            if name == tabName then
                tabIndex = i
                break
            end
        end
        
        tabButton.position = Vector2.new(startPos.X + (tabIndex-1) * tabWidth, startPos.Y + HEADER_HEIGHT)
        tabButton.background.Position = tabButton.position
        tabButton.text.Position = Vector2.new(startPos.X + (tabIndex-1) * tabWidth + tabWidth/2, startPos.Y + HEADER_HEIGHT + 7)
    end
    
    -- Make UI visible
    UI.Toggle(true)
    
    -- Create slide-in tween
    local duration = UI_ANIMATION_SPEED * 1.5
    local components = {
        DrawingObjects.Background,
        DrawingObjects.Border,
        DrawingObjects.HeaderBackground,
        DrawingObjects.TabBackground,
        DrawingObjects.ContentBackground,
        DrawingObjects.ContentBorder,
        DrawingObjects.SaveButton
    }
    
    -- Text elements need separate position calculations
    local textPositions = {
        [DrawingObjects.TitleText] = Vector2.new(targetPos.X + 10, targetPos.Y + 11),
        [DrawingObjects.CloseX] = Vector2.new(targetPos.X + UI_WIDTH - 20, targetPos.Y + 9),
        [DrawingObjects.SaveText] = Vector2.new(targetPos.X + UI_WIDTH - 50, targetPos.Y + UI_HEIGHT - 33)
    }
    
    local tabTextPositions = {}
    for tabName, tabButton in pairs(TabButtons) do
        local tabIndex = 0
        for i, name in ipairs({"Aimbot", "ESP", "Visuals", "Advanced"}) do
            if name == tabName then
                tabIndex = i
                break
            end
        end
        tabTextPositions[tabButton.text] = Vector2.new(targetPos.X + (tabIndex-1) * tabWidth + tabWidth/2, targetPos.Y + HEADER_HEIGHT + 7)
    end
    
    -- Start animations
    for _, component in ipairs(components) do
        local newPos
        if component == DrawingObjects.SaveButton then
            newPos = Vector2.new(targetPos.X + UI_WIDTH - 90, targetPos.Y + UI_HEIGHT - 40)
        elseif component == DrawingObjects.ContentBackground or component == DrawingObjects.ContentBorder then
            newPos = Vector2.new(targetPos.X + UI_PADDING, targetPos.Y + HEADER_HEIGHT + TAB_HEIGHT + UI_PADDING / 2)
        elseif component == DrawingObjects.TabBackground then
            newPos = Vector2.new(targetPos.X, targetPos.Y + HEADER_HEIGHT)
        else
            newPos = targetPos
        end
        
        ModuleReferences.Utils.TweenDrawingProperty(component, "Position", newPos, duration)
    end
    
    -- Animate text elements
    for text, pos in pairs(textPositions) do
        ModuleReferences.Utils.TweenDrawingProperty(text, "Position", pos, duration)
    end
    
    -- Animate tab buttons
    for tabName, tabButton in pairs(TabButtons) do
        local tabIndex = 0
        for i, name in ipairs({"Aimbot", "ESP", "Visuals", "Advanced"}) do
            if name == tabName then
                tabIndex = i
                break
            end
        end
        
        local newPos = Vector2.new(targetPos.X + (tabIndex-1) * tabWidth, targetPos.Y + HEADER_HEIGHT)
        ModuleReferences.Utils.TweenDrawingProperty(tabButton.background, "Position", newPos, duration)
        ModuleReferences.Utils.TweenDrawingProperty(tabButton.text, "Position", tabTextPositions[tabButton.text], duration)
    end
    
    -- Recreate content after animation
    delay(duration + 0.05, function()
        createTabContent()
    end)
end

-- Toggle UI visibility
function UI.Toggle(visible)
    UIVisible = visible
    
    -- Toggle main UI elements
    for name, obj in pairs(DrawingObjects) do
        if name ~= "ContentItems" and name ~= "NotificationContainer" then
            if typeof(obj) == "table" and obj.Visible ~= nil then
                obj.Visible = visible
            end
        end
    end
    
    -- Toggle content items
    for _, item in pairs(DrawingObjects.ContentItems) do
        if typeof(item) == "table" and item.Visible ~= nil then
            item.Visible = visible
        end
    end
    
    -- Close any open dropdowns
    for id, dropdown in pairs(ActiveDropdowns) do
        if dropdown.expanded then
            dropdown.expanded = false
            dropdown.optionsContainer.Visible = false
            for _, option in pairs(dropdown.optionItems) do
                option.background.Visible = false
                option.text.Visible = false
            end
        end
    end
end

-- Switch to a different tab
function UI.SwitchTab(tabName)
    if not TabButtons[tabName] then return end
    
    -- Update tab button colors
    for name, button in pairs(TabButtons) do
        button.background.Color = (name == tabName) and ModuleReferences.Settings.Current.Colors.UIAccent or ModuleReferences.Settings.Current.Colors.UIHeaderBackground
        button.background.Transparency = (name == tabName) and 0.7 or 0.3
    end
    
    -- Set current tab
    CurrentTab = tabName
    
    -- Update content
    createTabContent()
    
    return true
end

-- Apply color changes from a color picker
function UI.ApplyColorPickerChanges(id)
    local colorPicker = ActiveColorPickers[id]
    if not colorPicker then return end
    
    local newColor = Color3.new(
        colorPicker.sliders.r.value,
        colorPicker.sliders.g.value,
        colorPicker.sliders.b.value
    )
    
    -- Update the color setting
    ModuleReferences.Settings.Update("Colors", id, newColor)
    
    -- Update UI with new color
    UI.UpdateTheme()
    
    -- Show notification
    UI.ShowNotification(id .. " color updated", newColor)
    
    -- Mark settings as changed
    SettingsChanged = true
}

-- Save settings
function UI.SaveSettings()
    if not SettingsChanged then return end
    
    local success = ModuleReferences.Settings.Save()
    
    if success then
        UI.ShowNotification("Settings saved successfully!", ModuleReferences.Settings.Current.Colors.UISuccess)
    else
        UI.ShowErrorMessage("Failed to save settings")
    end
    
    SettingsChanged = false
}

-- Handle mouse input for UI interaction
function UI.HandleMouseInput()
    -- Get current mouse position
    local mousePosition = UserInputService:GetMouseLocation()
    
    -- Check if mouse is pressed
    local mouseDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    
    -- Update last mouse position for drag calculations
    if mouseDown and DraggingUI then
        local delta = mousePosition - LastMousePos
        if delta.Magnitude > 0 then
            local newPos = Vector2.new(
                DrawingObjects.Background.Position.X + delta.X,
                DrawingObjects.Background.Position.Y + delta.Y
            )
            updateUIPosition(newPos)
        end
    end
    LastMousePos = mousePosition
    
    -- No interaction if UI is hidden
    if not UIVisible then return end
    
    -- Check for UI header dragging
    if mouseDown then
        if not DraggingUI then
            -- Check if mouse is over header
            local headerPos = DrawingObjects.HeaderBackground.Position
            local headerSize = Vector2.new(UI_WIDTH, HEADER_HEIGHT)
            
            if mousePosition.X >= headerPos.X and mousePosition.X <= headerPos.X + headerSize.X and
               mousePosition.Y >= headerPos.Y and mousePosition.Y <= headerPos.Y + headerSize.Y then
                DraggingUI = true
                DragOffset = mousePosition - headerPos
            end
        end
    else
        DraggingUI = false
    end
    
    -- Check for close button click
    if mouseDown and not DraggingUI then
        local closePos = DrawingObjects.CloseButton.Position
        local closeSize = DrawingObjects.CloseButton.Size
        
        if mousePosition.X >= closePos.X and mousePosition.X <= closePos.X + closeSize.X and
           mousePosition.Y >= closePos.Y and mousePosition.Y <= closePos.Y + closeSize.Y then
            -- Close the UI
            UI.Toggle(false)
            return
        end
    end
    
    -- Check for save button click
    if mouseDown and not DraggingUI then
        local savePos = DrawingObjects.SaveButton.Position
        local saveSize = DrawingObjects.SaveButton.Size
        
        if mousePosition.X >= savePos.X and mousePosition.X <= savePos.X + saveSize.X and
           mousePosition.Y >= savePos.Y and mousePosition.Y <= savePos.Y + saveSize.Y then
            -- Save settings
            UI.SaveSettings()
            return
        end
    end
    
    -- Check for tab button clicks
    if mouseDown and not DraggingUI then
        for tabName, tabButton in pairs(TabButtons) do
            if mousePosition.X >= tabButton.position.X and mousePosition.X <= tabButton.position.X + tabButton.size.X and
               mousePosition.Y >= tabButton.position.Y and mousePosition.Y <= tabButton.position.Y + tabButton.size.Y then
                -- Switch to this tab
                UI.SwitchTab(tabName)
                return
            end
        end
    end
    
    -- Handle toggle buttons
    if mouseDown and not DraggingUI then
        for id, toggle in pairs(ActiveToggles) do
            if mousePosition.X >= toggle.position.X and mousePosition.X <= toggle.position.X + toggle.size.X and
               mousePosition.Y >= toggle.position.Y and mousePosition.Y <= toggle.position.Y + toggle.size.Y then
                -- Toggle the setting
                toggle.value = not toggle.value
                toggle.background.Color = toggle.value and ModuleReferences.Settings.Current.Colors.UISuccess or ModuleReferences.Settings.Current.Colors.UIDanger
                toggle.checkmark.Text = toggle.value and "✓" or "✗"
                
                -- Update the setting
                ModuleReferences.Settings.Update("", id, toggle.value)
                
                -- Specific actions for certain toggles
                if id == "AimbotEnabled" then
                    ModuleReferences.Aimbot.Toggle(toggle.value)
                elseif id == "ESPEnabled" then
                    ModuleReferences.ESP.Toggle(toggle.value)
                elseif id == "UIAnimations" then
                    -- Nothing special to do here
                elseif id == "DebugMode" then
                    -- Nothing special to do here
                end
                
                -- Update UI
                createTabContent()
                
                -- Mark settings as changed
                SettingsChanged = true
                
                return
            end
        end
    end
    
    -- Handle sliders
    for id, slider in pairs(ActiveSliders) do
        if mouseDown then
            -- Check if mouse is over slider or already dragging
            local sliderRect = {
                minX = slider.position.X - 10, -- Add some padding for easier grabbing
                maxX = slider.position.X + slider.size.X + 10,
                minY = slider.position.Y - 10,
                maxY = slider.position.Y + 20
            }
            
            if slider.dragging or (
               mousePosition.X >= sliderRect.minX and mousePosition.X <= sliderRect.maxX and
               mousePosition.Y >= sliderRect.minY and mousePosition.Y <= sliderRect.maxY) then
                
                -- Start dragging
                slider.dragging = true
                
                -- Calculate new value based on mouse position
                local relativeX = math.clamp(mousePosition.X - slider.position.X, 0, slider.size.X)
                local progress = relativeX / slider.size.X
                local newValue = slider.min + progress * (slider.max - slider.min)
                
                -- Round to step
                newValue = math.floor(newValue / slider.step + 0.5) * slider.step
                
                -- Clamp value
                newValue = math.clamp(newValue, slider.min, slider.max)
                
                -- Update slider visuals
                local fillWidth = (newValue - slider.min) / (slider.max - slider.min) * slider.size.X
                slider.fill.Size = Vector2.new(fillWidth, slider.fill.Size.Y)
                slider.knob.Position = Vector2.new(slider.position.X + fillWidth - 5, slider.knob.Position.Y)
                
                -- Update text
                slider.text.Text = string.format(id .. ": " .. slider.formatString, newValue)
                
                -- Update setting
                if newValue ~= slider.value then
                    slider.value = newValue
                    ModuleReferences.Settings.Update("", id, newValue)
                    
                    -- Mark settings as changed
                    SettingsChanged = true
                }
            end
        else
            -- Stop dragging
            slider.dragging = false
        }
    end
    
    -- Handle dropdowns
    if mouseDown and not DraggingUI then
        for id, dropdown in pairs(ActiveDropdowns) do
            -- Check if clicking on the dropdown header
            if mousePosition.X >= dropdown.position.X and mousePosition.X <= dropdown.position.X + dropdown.size.X and
               mousePosition.Y >= dropdown.position.Y and mousePosition.Y <= dropdown.position.Y + dropdown.size.Y then
                
                -- Toggle dropdown expansion
                dropdown.expanded = not dropdown.expanded
                dropdown.optionsContainer.Visible = dropdown.expanded and UIVisible
                
                for _, option in pairs(dropdown.optionItems) do
                    option.background.Visible = dropdown.expanded and UIVisible
                    option.text.Visible = dropdown.expanded and UIVisible
                end
                
                -- Close other dropdowns
                for otherId, otherDropdown in pairs(ActiveDropdowns) do
                    if otherId ~= id and otherDropdown.expanded then
                        otherDropdown.expanded = false
                        otherDropdown.optionsContainer.Visible = false
                        
                        for _, option in pairs(otherDropdown.optionItems) do
                            option.background.Visible = false
                            option.text.Visible = false
                        end
                    end
                end
                
                return
            end
            
            -- Check if clicking on an option
            if dropdown.expanded then
                for i, option in ipairs(dropdown.options) do
                    local optionPos = Vector2.new(dropdown.optionsPosition.X, dropdown.optionsPosition.Y + (i-1) * 25)
                    local optionSize = Vector2.new(dropdown.size.X, 25)
                    
                    if mousePosition.X >= optionPos.X and mousePosition.X <= optionPos.X + optionSize.X and
                       mousePosition.Y >= optionPos.Y and mousePosition.Y <= optionPos.Y + optionSize.Y then
                        
                        -- Select this option
                        if option ~= dropdown.value then
                            dropdown.value = option
                            dropdown.valueText.Text = option
                            
                            -- Update option colors
                            for j, _ in ipairs(dropdown.options) do
                                dropdown.optionItems[j].background.Color = (j == i) and ModuleReferences.Settings.Current.Colors.UIAccent or Color3.fromRGB(50, 50, 60)
                                dropdown.optionItems[j].background.Transparency = (j == i) and 0.7 or 0.5
                            end
                            
                            -- Update setting
                            ModuleReferences.Settings.Update("", id, option)
                            
                            -- Special handling for certain dropdowns
                            if id == "UITheme" then
                                ModuleReferences.Settings.ApplyTheme(option)
                                UI.UpdateTheme()
                            end
                            
                            -- Mark settings as changed
                            SettingsChanged = true
                        }
                        
                        -- Close dropdown
                        dropdown.expanded = false
                        dropdown.optionsContainer.Visible = false
                        
                        for _, optItem in pairs(dropdown.optionItems) do
                            optItem.background.Visible = false
                            optItem.text.Visible = false
                        end
                        
                        return
                    end
                end
            end
        end
    end
    
    -- Handle color pickers
    for id, colorPicker in pairs(ActiveColorPickers) do
        -- Handle slider dragging for each color channel
        for channel, slider in pairs(colorPicker.sliders) do
            if mouseDown then
                -- Check if mouse is over slider or already dragging
                local sliderRect = {
                    minX = slider.position.X - 10,
                    maxX = slider.position.X + slider.size.X + 10,
                    minY = slider.position.Y - 10,
                    maxY = slider.position.Y + 20
                }
                
                if slider.dragging or (
                   mousePosition.X >= sliderRect.minX and mousePosition.X <= sliderRect.maxX and
                   mousePosition.Y >= sliderRect.minY and mousePosition.Y <= sliderRect.maxY) then
                    
                    -- Start dragging
                    slider.dragging = true
                    
                    -- Calculate new value based on mouse position
                    local relativeX = math.clamp(mousePosition.X - slider.position.X, 0, slider.size.X)
                    local newValue = relativeX / slider.size.X
                    
                    -- Update slider visuals
                    slider.fill.Size = Vector2.new(slider.size.X * newValue, slider.fill.Size.Y)
                    slider.knob.Position = Vector2.new(slider.position.X + slider.size.X * newValue - 5, slider.knob.Position.Y)
                    
                    -- Update text
                    slider.text.Text = channel:upper() .. ": " .. math.floor(newValue * 255)
                    
                    -- Update color value
                    slider.value = newValue
                    
                    -- Update preview
                    local newColor = Color3.new(
                        colorPicker.sliders.r.value,
                        colorPicker.sliders.g.value,
                        colorPicker.sliders.b.value
                    )
                    colorPicker.preview.Color = newColor
                    
                    -- Don't apply the color yet - that happens when the Apply button is clicked
                }
            else
                -- Stop dragging
                slider.dragging = false
            end
        end
        
        -- Handle apply button click
        if mouseDown and not DraggingUI then
            local applyPos = colorPicker.applyButton.position
            local applySize = colorPicker.applyButton.size
            
            if mousePosition.X >= applyPos.X and mousePosition.X <= applyPos.X + applySize.X and
               mousePosition.Y >= applyPos.Y and mousePosition.Y <= applyPos.Y + applySize.Y then
                -- Apply the color change
                UI.ApplyColorPickerChanges(id)
                return
            end
        end
    end
    
    -- Handle reset button click in Advanced tab
    if CurrentTab == "Advanced" and mouseDown and not DraggingUI and DrawingObjects.ContentItems.ResetButton then
        local resetPos = DrawingObjects.ContentItems.ResetButton.Position
        local resetSize = DrawingObjects.ContentItems.ResetButton.Size
        
        if mousePosition.X >= resetPos.X and mousePosition.X <= resetPos.X + resetSize.X and
           mousePosition.Y >= resetPos.Y and mousePosition.Y <= resetPos.Y + resetSize.Y then
            -- Reset settings
            ModuleReferences.Settings.Reset()
            UI.UpdateTheme()
            UI.ShowNotification("Settings reset to defaults", ModuleReferences.Settings.Current.Colors.UIWarning)
            createTabContent()
            return
        end
    end
}

-- Clean up all drawings
function UI.Cleanup()
    -- Clean up main UI elements
    for name, obj in pairs(DrawingObjects) do
        if name ~= "ContentItems" and name ~= "NotificationContainer" then
            ModuleReferences.Utils.SafeRemoveDrawing(obj)
        end
    end
    
    -- Clean up content items
    for _, item in pairs(DrawingObjects.ContentItems) do
        ModuleReferences.Utils.SafeRemoveDrawing(item)
    end
    
    -- Clean up notifications
    for _, notif in ipairs(ActiveNotifications) do
        ModuleReferences.Utils.SafeRemoveDrawing(notif.background)
        ModuleReferences.Utils.SafeRemoveDrawing(notif.border)
        ModuleReferences.Utils.SafeRemoveDrawing(notif.text)
    end
    
    -- Clear tables
    DrawingObjects = {}
    ActiveToggles = {}
    ActiveSliders = {}
    ActiveDropdowns = {}
    ActiveColorPickers = {}
    ActiveNotifications = {}
    TabButtons = {}
    
    UICreated = false
}

-- Initialize the UI
function UI.Initialize(modules)
    -- Store module references for use across UI functions
    ModuleReferences = modules
    
    -- Create UI elements
    createUIElements()
    UICreated = true
    
    -- Create initial tab content
    createTabContent()
    
    -- Set up input handler
    RunService:BindToRenderStep("UIUpdate", 1, function()
        UI.HandleMouseInput()
    end)
    
    -- Return success
    return true
end

return UI
