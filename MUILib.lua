--[[
    Meerly UI Library (MUILib)
    Compact Roblox/Luau UI framework with tabs, controls, themes, console logging,
    pop-out console, kill callbacks, semicolon minimize keybind, and universal config storage.

    Usage:
        local MUILib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ItsMeerly/MeerlyPEv3.3/main/MUILib.lua"))()
        local UI = MUILib.new({ Title = "Meerly", Console = true })
]]

local MUILib = {}
MUILib.Version = "0.1.1"
MUILib.ConfigFile = "MeerlyUniversalConfig.json"

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
local unpackArgs = table.unpack or unpack

local function getEnvironment()
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            return env
        end
    end

    if type(getfenv) == "function" then
        local ok, env = pcall(getfenv)
        if ok and type(env) == "table" then
            return env
        end
    end

    return _G
end

local function hasFunction(name)
    return type(getEnvironment()[name]) == "function"
end

local function readLocalFile(path)
    if hasFunction("isfile") and hasFunction("readfile") and isfile(path) then
        return readfile(path)
    end

    return nil
end

local function writeLocalFile(path, content)
    if hasFunction("writefile") then
        writefile(path, content)
        return true
    end

    return false
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local output = {}
    for key, child in pairs(value) do
        output[deepCopy(key)] = deepCopy(child)
    end

    return output
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function roundToIncrement(value, increment)
    increment = increment or 1
    if increment <= 0 then
        return value
    end

    return math.floor((value / increment) + 0.5) * increment
end

local function make(className, props, children)
    local instance = Instance.new(className)
    for key, value in pairs(props or {}) do
        instance[key] = value
    end

    for _, child in ipairs(children or {}) do
        child.Parent = instance
    end

    return instance
end

local function safeCallback(callback, logger, source, ...)
    if type(callback) ~= "function" then
        return
    end

    local args = { ... }
    task.spawn(function()
        local ok, err = pcall(function()
            callback(unpackArgs(args))
        end)

        if not ok and logger then
            logger:Error(tostring(err), source or "Callback")
        end
    end)
end

local function colorToTable(color)
    return {
        R = math.floor(color.R * 255 + 0.5),
        G = math.floor(color.G * 255 + 0.5),
        B = math.floor(color.B * 255 + 0.5),
    }
end

local function tableToColor(value, fallback)
    if typeof(value) == "Color3" then
        return value
    end

    if type(value) == "table" and value.R and value.G and value.B then
        return Color3.fromRGB(value.R, value.G, value.B)
    end

    return fallback or Color3.fromRGB(255, 255, 255)
end

local function serializeTheme(theme)
    local output = {}
    for key, value in pairs(theme or {}) do
        if typeof(value) == "Color3" then
            output[key] = colorToTable(value)
        else
            output[key] = value
        end
    end

    return output
end

local function hydrateTheme(theme, fallback)
    local output = deepCopy(fallback or {})
    for key, value in pairs(theme or {}) do
        if type(value) == "table" and value.R and value.G and value.B then
            output[key] = tableToColor(value, output[key])
        else
            output[key] = value
        end
    end

    return output
end

MUILib.Themes = {
    MeerlyDark = {
        Background = Color3.fromRGB(14, 17, 25),
        Topbar = Color3.fromRGB(21, 25, 36),
        Panel = Color3.fromRGB(24, 29, 41),
        PanelAlt = Color3.fromRGB(31, 37, 52),
        Control = Color3.fromRGB(36, 43, 60),
        ControlHover = Color3.fromRGB(45, 54, 74),
        Border = Color3.fromRGB(51, 60, 82),
        Accent = Color3.fromRGB(224, 42, 91),
        AccentDark = Color3.fromRGB(142, 28, 60),
        Text = Color3.fromRGB(235, 238, 245),
        MutedText = Color3.fromRGB(150, 156, 170),
        Success = Color3.fromRGB(87, 215, 126),
        Warning = Color3.fromRGB(245, 185, 65),
        Error = Color3.fromRGB(242, 76, 76),
        Debug = Color3.fromRGB(125, 170, 255),
        Transparency = 0,
        Blur = 0,
    },
    MeerlyBlue = {
        Background = Color3.fromRGB(13, 18, 29),
        Topbar = Color3.fromRGB(19, 27, 43),
        Panel = Color3.fromRGB(23, 33, 52),
        PanelAlt = Color3.fromRGB(30, 43, 67),
        Control = Color3.fromRGB(35, 49, 75),
        ControlHover = Color3.fromRGB(44, 62, 92),
        Border = Color3.fromRGB(55, 72, 100),
        Accent = Color3.fromRGB(67, 139, 255),
        AccentDark = Color3.fromRGB(35, 84, 165),
        Text = Color3.fromRGB(235, 240, 250),
        MutedText = Color3.fromRGB(148, 161, 180),
        Success = Color3.fromRGB(87, 215, 126),
        Warning = Color3.fromRGB(245, 185, 65),
        Error = Color3.fromRGB(242, 76, 76),
        Debug = Color3.fromRGB(125, 170, 255),
        Transparency = 0,
        Blur = 0,
    },
    ClassicDark = {
        Background = Color3.fromRGB(18, 18, 18),
        Topbar = Color3.fromRGB(28, 28, 28),
        Panel = Color3.fromRGB(32, 32, 32),
        PanelAlt = Color3.fromRGB(40, 40, 40),
        Control = Color3.fromRGB(48, 48, 48),
        ControlHover = Color3.fromRGB(58, 58, 58),
        Border = Color3.fromRGB(70, 70, 70),
        Accent = Color3.fromRGB(210, 55, 75),
        AccentDark = Color3.fromRGB(135, 35, 48),
        Text = Color3.fromRGB(235, 235, 235),
        MutedText = Color3.fromRGB(165, 165, 165),
        Success = Color3.fromRGB(87, 215, 126),
        Warning = Color3.fromRGB(245, 185, 65),
        Error = Color3.fromRGB(242, 76, 76),
        Debug = Color3.fromRGB(125, 170, 255),
        Transparency = 0,
        Blur = 0,
    },
}

local MemoryConfig = {}

function MUILib.LoadUniversalConfig()
    local raw = readLocalFile(MUILib.ConfigFile)
    if raw then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(raw)
        end)

        if ok and type(decoded) == "table" then
            MemoryConfig = decoded
        end
    end

    MemoryConfig["UI Library Config"] = MemoryConfig["UI Library Config"] or {}
    MemoryConfig["Last Launcher Key Input"] = MemoryConfig["Last Launcher Key Input"] or { Key = "" }
    return MemoryConfig
end

function MUILib.SaveUniversalConfig(config)
    MemoryConfig = config or MemoryConfig or {}
    local encoded = HttpService:JSONEncode(MemoryConfig)
    return writeLocalFile(MUILib.ConfigFile, encoded)
end

function MUILib.GetGameConfigKey(gameId)
    return "Game Id_" .. tostring(gameId or "Unknown")
end

local UIClass = {}
UIClass.__index = UIClass

local TabClass = {}
TabClass.__index = TabClass

local SectionClass = {}
SectionClass.__index = SectionClass

local LoggerClass = {}
LoggerClass.__index = LoggerClass

function LoggerClass.new(owner)
    return setmetatable({
        Owner = owner,
        History = {},
        MaxHistory = 500,
        Sinks = {},
        Level = "Debug",
    }, LoggerClass)
end

function LoggerClass:_push(level, message, source)
    local entry = {
        Time = os.date("%H:%M:%S"),
        Level = level,
        Source = source or "System",
        Message = tostring(message),
    }

    table.insert(self.History, entry)
    while #self.History > self.MaxHistory do
        table.remove(self.History, 1)
    end

    for _, sink in ipairs(self.Sinks) do
        safeCallback(sink, nil, nil, entry)
    end

    return entry
end

function LoggerClass:Info(message, source)
    return self:_push("INFO", message, source)
end

function LoggerClass:Warn(message, source)
    return self:_push("WARN", message, source)
end

function LoggerClass:Error(message, source)
    return self:_push("ERROR", message, source)
end

function LoggerClass:Debug(message, source)
    return self:_push("DEBUG", message, source)
end

function LoggerClass:Clear()
    self.History = {}
    for _, sink in ipairs(self.Sinks) do
        safeCallback(sink, nil, nil, { Clear = true })
    end
end

function LoggerClass:GetHistory()
    return deepCopy(self.History)
end

function LoggerClass:Connect(sink)
    table.insert(self.Sinks, sink)
    return function()
        for index, value in ipairs(self.Sinks) do
            if value == sink then
                table.remove(self.Sinks, index)
                break
            end
        end
    end
end

function UIClass:_track(instance, role, prop)
    table.insert(self.Tracked, { Instance = instance, Role = role, Prop = prop or "BackgroundColor3" })
    self:_applyTo(instance, role, prop or "BackgroundColor3")
    return instance
end

function UIClass:_applyTo(instance, role, prop)
    if not instance then
        return
    end

    local value = self.Theme[role]
    if value ~= nil then
        instance[prop] = value
    end

    if prop == "BackgroundColor3" and instance:IsA("GuiObject") then
        local transparentRoles = { Background = true, Panel = true, PanelAlt = true, Topbar = true, Control = true }
        if transparentRoles[role] then
            instance.BackgroundTransparency = self.Theme.Transparency or 0
        end
    end
end

function UIClass:_applyTheme()
    for _, item in ipairs(self.Tracked) do
        self:_applyTo(item.Instance, item.Role, item.Prop)
    end

    if self.BlurEffect then
        self.BlurEffect.Size = self.Theme.Blur or 0
        self.BlurEffect.Enabled = (self.Theme.Blur or 0) > 0
    end

    if self.ActiveTab then
        self:SelectTab(self.ActiveTab)
    end
end

function UIClass:RegisterTheme(name, theme)
    MUILib.Themes[name] = hydrateTheme(theme, MUILib.Themes.MeerlyDark)
end

function UIClass:SetTheme(theme)
    if type(theme) == "string" then
        self.ThemeName = theme
        self.Theme = deepCopy(MUILib.Themes[theme] or MUILib.Themes.MeerlyDark)
    elseif type(theme) == "table" then
        self.ThemeName = "Custom"
        self.Theme = hydrateTheme(theme, self.Theme)
    end

    self:_applyTheme()
    self:SaveUIConfig()
end

function UIClass:SetThemeValue(key, value)
    self.Theme[key] = value
    self.ThemeName = "Custom"
    self:_applyTheme()
    self:SaveUIConfig()
end

function UIClass:SaveUIConfig()
    self.Config["UI Library Config"] = self.Config["UI Library Config"] or {}
    self.Config["UI Library Config"].ThemeName = self.ThemeName
    self.Config["UI Library Config"].Theme = serializeTheme(self.Theme)
    self.Config["UI Library Config"].Size = {
        X = self.Window.Size.X.Offset,
        Y = self.Window.Size.Y.Offset,
    }
    self.Config["UI Library Config"].Position = {
        XScale = self.Window.Position.X.Scale,
        XOffset = self.Window.Position.X.Offset,
        YScale = self.Window.Position.Y.Scale,
        YOffset = self.Window.Position.Y.Offset,
    }

    local saved = MUILib.SaveUniversalConfig(self.Config)
    if not saved and self.Logger then
        self.Logger:Warn("Local file save unavailable; using in-memory config for this session.", "Config")
    end
end

function UIClass:GetGameConfig(gameId)
    local key = MUILib.GetGameConfigKey(gameId)
    self.Config[key] = self.Config[key] or {}
    return self.Config[key]
end

function UIClass:SetGameConfig(gameId, data)
    self.Config[MUILib.GetGameConfigKey(gameId)] = data or {}
    self:SaveUIConfig()
end

function UIClass:SetVisible(visible)
    self.Gui.Enabled = visible and true or false
end

function UIClass:Toggle()
    self.Gui.Enabled = not self.Gui.Enabled
end

function UIClass:SetTitle(title)
    self.Title = title
    self.TitleLabel.Text = title
end

function UIClass:SetMinimized(minimized)
    self.Minimized = minimized and true or false
    self.Content.Visible = not self.Minimized
    self.TabBar.Visible = not self.Minimized
    self.ResizeGrip.Visible = not self.Minimized

    if self.Minimized then
        self.StoredSize = self.Window.Size
        self.Window.Size = UDim2.fromOffset(self.StoredSize.X.Offset, 24)
        self.MinimizeButton.Text = "+"
    else
        self.Window.Size = self.StoredSize or self.DefaultSize
        self.MinimizeButton.Text = "-"
    end
end

function UIClass:ToggleMinimized()
    self:SetMinimized(not self.Minimized)
end

function UIClass:OnKill(callback)
    table.insert(self.KillCallbacks, callback)
    return function()
        for index, value in ipairs(self.KillCallbacks) do
            if value == callback then
                table.remove(self.KillCallbacks, index)
                break
            end
        end
    end
end

function UIClass:Kill()
    if self.Killed then
        return
    end

    self.Killed = true
    self.Logger:Warn("Kill requested; running registered revert callbacks.", "UI")

    for _, callback in ipairs(self.KillCallbacks) do
        safeCallback(callback, self.Logger, "Kill")
    end

    if self.BlurEffect then
        self.BlurEffect:Destroy()
    end

    if self.Gui then
        self.Gui:Destroy()
    end
end

function UIClass:Destroy()
    self:Kill()
end

function UIClass:_makeButton(parent, text, width)
    local button = make("TextButton", {
        Size = UDim2.new(0, width or 56, 1, 0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = text,
        TextSize = 12,
        Font = Enum.Font.Code,
        AutoButtonColor = false,
    })

    self:_track(button, "Control")
    self:_track(button, "Text", "TextColor3")
    button.Parent = parent
    return button
end

function UIClass:_createBase(config)
    local parent = config.Parent or PlayerGui or CoreGui
    local uiConfig = self.Config["UI Library Config"] or {}
    local sizeData = uiConfig.Size
    local posData = uiConfig.Position

    self.Gui = make("ScreenGui", {
        Name = "MeerlyUILibrary",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    self.Gui.Parent = parent

    self.BlurEffect = make("BlurEffect", {
        Name = "MeerlyUIBlur",
        Enabled = false,
        Size = 0,
    })
    self.BlurEffect.Parent = Lighting

    self.DefaultSize = UDim2.fromOffset(
        sizeData and sizeData.X or (config.Size and config.Size.X.Offset) or 560,
        sizeData and sizeData.Y or (config.Size and config.Size.Y.Offset) or 380
    )

    self.MinSize = config.MinSize or Vector2.new(420, 280)

    self.Window = make("Frame", {
        Name = "Window",
        Size = self.DefaultSize,
        Position = posData and UDim2.new(posData.XScale or 0.5, posData.XOffset or -280, posData.YScale or 0.5, posData.YOffset or -190) or UDim2.fromScale(0.5, 0.5),
        AnchorPoint = posData and Vector2.new(0, 0) or Vector2.new(0.5, 0.5),
        BorderSizePixel = 1,
        Active = true,
    })
    self:_track(self.Window, "Background")
    self:_track(self.Window, "Border", "BorderColor3")
    self.Window.Parent = self.Gui

    self.TitleBar = make("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 24),
        BorderSizePixel = 0,
        Active = true,
    })
    self:_track(self.TitleBar, "Topbar")
    self.TitleBar.Parent = self.Window

    self.TitleLabel = make("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -84, 1, 0),
        Text = self.Title,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 13,
        Font = Enum.Font.Code,
    })
    self:_track(self.TitleLabel, "Text", "TextColor3")
    self.TitleLabel.Parent = self.TitleBar

    local titleButtons = make("Frame", {
        Name = "TitleButtons",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(72, 20),
        Position = UDim2.new(1, -76, 0, 2),
    }, {
        make("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 3),
        }),
    })
    titleButtons.Parent = self.TitleBar

    self.MinimizeButton = self:_makeButton(titleButtons, "-", 32)
    self.KillButton = self:_makeButton(titleButtons, "X", 32)
    self:_track(self.KillButton, "Error")

    self.TabBar = make("Frame", {
        Name = "TabBar",
        Position = UDim2.fromOffset(0, 24),
        Size = UDim2.new(1, 0, 0, 25),
        BorderSizePixel = 0,
    })
    self:_track(self.TabBar, "Panel")
    self.TabBar.Parent = self.Window

    self.TabList = make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
    })
    self.TabList.Parent = self.TabBar

    self.Content = make("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(4, 53),
        Size = UDim2.new(1, -8, 1, -58),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    })
    self.Content.Parent = self.Window

    self.ResizeGrip = make("TextButton", {
        Name = "ResizeGrip",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -2, 1, -2),
        Size = UDim2.fromOffset(14, 14),
        Text = "/",
        TextSize = 10,
        Font = Enum.Font.Code,
        AutoButtonColor = false,
        BorderSizePixel = 0,
    })
    self:_track(self.ResizeGrip, "Control")
    self:_track(self.ResizeGrip, "MutedText", "TextColor3")
    self.ResizeGrip.Parent = self.Window

    self.MinimizeButton.MouseButton1Click:Connect(function()
        self:ToggleMinimized()
    end)

    self.KillButton.MouseButton1Click:Connect(function()
        self:Kill()
    end)

    self:_wireDrag()
    self:_wireResize()
    self:_wireKeybinds()
end

function UIClass:_wireDrag()
    local dragging = false
    local dragStart = nil
    local startPos = nil

    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = self.Window.Position
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            self:SaveUIConfig()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            self.Window.AnchorPoint = Vector2.new(0, 0)
            self.Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function UIClass:_wireResize()
    local resizing = false
    local resizeStart = nil
    local startSize = nil

    self.ResizeGrip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resizeStart = input.Position
            startSize = self.Window.Size
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and resizing then
            resizing = false
            self:SaveUIConfig()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - resizeStart
            local newX = math.max(self.MinSize.X, startSize.X.Offset + delta.X)
            local newY = math.max(self.MinSize.Y, startSize.Y.Offset + delta.Y)
            self.Window.Size = UDim2.fromOffset(newX, newY)
        end
    end)
end

function UIClass:_wireKeybinds()
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end

        if input.KeyCode == Enum.KeyCode.Semicolon then
            self:ToggleMinimized()
        end
    end)
end

function UIClass:CreateTab(name)
    if self.Tabs[name] then
        return self.Tabs[name]
    end

    local tab = setmetatable({
        UI = self,
        Name = name,
        Sections = {},
    }, TabClass)

    tab.Button = make("TextButton", {
        Name = name .. "TabButton",
        Size = UDim2.fromOffset(math.max(72, (#name * 7) + 18), 25),
        BorderSizePixel = 0,
        Text = name,
        TextSize = 12,
        Font = Enum.Font.Code,
        AutoButtonColor = false,
    })
    self:_track(tab.Button, "Control")
    self:_track(tab.Button, "Text", "TextColor3")
    tab.Button.Parent = self.TabBar

    tab.Page = make("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 4,
        BorderSizePixel = 0,
        Visible = false,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    tab.Page.Parent = self.Content

    tab.Layout = make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
    })
    tab.Layout.Parent = tab.Page

    make("UIPadding", {
        PaddingTop = UDim.new(0, 1),
        PaddingLeft = UDim.new(0, 1),
        PaddingRight = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
    }).Parent = tab.Page

    tab.Button.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)

    self.Tabs[name] = tab
    table.insert(self.TabOrder, name)

    if not self.ActiveTab then
        self:SelectTab(name)
    end

    return tab
end

function UIClass:SelectTab(name)
    local selectedTab = self.Tabs[name]
    if not selectedTab then
        return nil
    end

    self.ActiveTab = name
    for tabName, tab in pairs(self.Tabs) do
        local selected = tabName == name
        tab.Page.Visible = selected
        tab.Button.BackgroundColor3 = selected and self.Theme.AccentDark or self.Theme.Control
        tab.Button.TextColor3 = selected and self.Theme.Text or self.Theme.MutedText
    end

    return selectedTab
end

function TabClass:CreateSection(title)
    local ui = self.UI
    local section = setmetatable({ UI = ui, Tab = self, Title = title }, SectionClass)

    section.Frame = make("Frame", {
        Name = title .. "Section",
        Size = UDim2.new(1, 0, 0, 28),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 1,
    })
    ui:_track(section.Frame, "Panel")
    ui:_track(section.Frame, "Border", "BorderColor3")
    section.Frame.Parent = self.Page

    section.Header = make("TextLabel", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.fromOffset(6, 0),
        Text = title,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        Font = Enum.Font.Code,
    })
    ui:_track(section.Header, "Text", "TextColor3")
    section.Header.Parent = section.Frame

    section.Body = make("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(5, 22),
        Size = UDim2.new(1, -10, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    section.Body.Parent = section.Frame

    make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    }).Parent = section.Body

    table.insert(self.Sections, section)
    return section
end

function TabClass:CreateLabel(text)
    return self:CreateSection("Info"):CreateLabel(text)
end

function TabClass:CreateButton(config)
    config = config or {}
    return self:CreateSection(config.Section or "Main"):CreateButton(config)
end

function TabClass:CreateToggle(config)
    config = config or {}
    return self:CreateSection(config.Section or "Main"):CreateToggle(config)
end

function TabClass:CreateSlider(config)
    config = config or {}
    return self:CreateSection(config.Section or "Main"):CreateSlider(config)
end

function TabClass:CreateDropdown(config)
    config = config or {}
    return self:CreateSection(config.Section or "Main"):CreateDropdown(config)
end

function TabClass:CreateTextbox(config)
    config = config or {}
    return self:CreateSection(config.Section or "Main"):CreateTextbox(config)
end

function SectionClass:_row(height)
    local row = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or 22),
    })
    row.Parent = self.Body
    return row
end

function SectionClass:CreateLabel(text)
    local row = self:_row(18)
    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        Font = Enum.Font.Code,
    })
    self.UI:_track(label, "MutedText", "TextColor3")
    label.Parent = row
    return label
end

function SectionClass:CreateButton(config)
    config = config or {}
    local row = self:_row(22)
    local button = make("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 1,
        Text = config.Text or config.Label or "Button",
        TextSize = 12,
        Font = Enum.Font.Code,
        AutoButtonColor = false,
    })
    self.UI:_track(button, "Control")
    self.UI:_track(button, "Border", "BorderColor3")
    self.UI:_track(button, "Text", "TextColor3")
    button.Parent = row

    button.MouseButton1Click:Connect(function()
        safeCallback(config.Callback, self.UI.Logger, config.Text or "Button")
    end)

    return button
end

function SectionClass:CreateToggle(config)
    config = config or {}
    local row = self:_row(22)
    local state = config.Default and true or false
    local box = make("TextButton", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(0, 2),
        BorderSizePixel = 1,
        Text = state and "X" or "",
        TextSize = 12,
        Font = Enum.Font.Code,
        AutoButtonColor = false,
    })
    self.UI:_track(box, state and "Accent" or "Control")
    self.UI:_track(box, "Border", "BorderColor3")
    self.UI:_track(box, "Text", "TextColor3")
    box.Parent = row

    local label = make("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(25, 0),
        Size = UDim2.new(1, -25, 1, 0),
        Text = config.Text or config.Label or "Toggle",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        Font = Enum.Font.Code,
        AutoButtonColor = false,
    })
    self.UI:_track(label, "Text", "TextColor3")
    label.Parent = row

    local function set(value, silent)
        state = value and true or false
        box.Text = state and "X" or ""
        box.BackgroundColor3 = state and self.UI.Theme.Accent or self.UI.Theme.Control
        if not silent then
            safeCallback(config.Callback, self.UI.Logger, config.Text or "Toggle", state)
        end
    end

    box.MouseButton1Click:Connect(function()
        set(not state)
    end)
    label.MouseButton1Click:Connect(function()
        set(not state)
    end)

    return { Set = set, Get = function() return state end, Instance = row }
end

function SectionClass:CreateSlider(config)
    config = config or {}
    local minValue = config.Min or 0
    local maxValue = config.Max or 100
    local increment = config.Increment or 1
    local range = math.max(1, maxValue - minValue)
    local value = clamp(config.Default or minValue, minValue, maxValue)
    local row = self:_row(36)

    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -52, 0, 16),
        Text = config.Text or config.Label or "Slider",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        Font = Enum.Font.Code,
    })
    self.UI:_track(label, "Text", "TextColor3")
    label.Parent = row

    local valueLabel = make("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(48, 16),
        Text = tostring(value),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = 12,
        Font = Enum.Font.Code,
    })
    self.UI:_track(valueLabel, "MutedText", "TextColor3")
    valueLabel.Parent = row

    local bar = make("TextButton", {
        Position = UDim2.fromOffset(0, 20),
        Size = UDim2.new(1, 0, 0, 12),
        BorderSizePixel = 1,
        Text = "",
        AutoButtonColor = false,
    })
    self.UI:_track(bar, "Control")
    self.UI:_track(bar, "Border", "BorderColor3")
    bar.Parent = row

    local fill = make("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.fromScale((value - minValue) / range, 1),
    })
    self.UI:_track(fill, "Accent")
    fill.Parent = bar

    local dragging = false

    local function setValue(nextValue, silent)
        value = clamp(roundToIncrement(nextValue, increment), minValue, maxValue)
        valueLabel.Text = tostring(value)
        fill.Size = UDim2.fromScale((value - minValue) / range, 1)

        if not silent then
            safeCallback(config.Callback, self.UI.Logger, config.Text or "Slider", value)
        end
    end

    local function setFromX(x, silent)
        local alpha = clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        setValue(minValue + (range * alpha), silent)
    end

    bar.MouseButton1Down:Connect(function(x)
        dragging = true
        setFromX(x)
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end)

    return { Set = setValue, Get = function() return value end, Instance = row }
end

function SectionClass:CreateDropdown(config)
    config = config or {}
    local options = config.Options or {}
    local selected = config.Default or options[1] or ""
    local row = self:_row(24)
    local open = false

    local button = make("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 1,
        Text = (config.Text or config.Label or "Dropdown") .. ": " .. tostring(selected),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        Font = Enum.Font.Code,
        AutoButtonColor = false,
    })
    self.UI:_track(button, "Control")
    self.UI:_track(button, "Border", "BorderColor3")
    self.UI:_track(button, "Text", "TextColor3")
    button.Parent = row

    local arrow = make("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(22, 22),
        BorderSizePixel = 0,
        Text = "v",
        TextSize = 10,
        Font = Enum.Font.Code,
    })
    self.UI:_track(arrow, "Accent")
    self.UI:_track(arrow, "Text", "TextColor3")
    arrow.Parent = button

    local menu = make("Frame", {
        Visible = false,
        Position = UDim2.fromOffset(0, 24),
        Size = UDim2.new(1, 0, 0, #options * 22),
        BorderSizePixel = 1,
        ZIndex = 10,
    })
    self.UI:_track(menu, "PanelAlt")
    self.UI:_track(menu, "Border", "BorderColor3")
    menu.Parent = row

    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }).Parent = menu

    local function set(option, silent)
        selected = option
        button.Text = (config.Text or config.Label or "Dropdown") .. ": " .. tostring(selected)
        menu.Visible = false
        open = false
        row.Size = UDim2.new(1, 0, 0, 24)

        if not silent then
            safeCallback(config.Callback, self.UI.Logger, config.Text or "Dropdown", selected)
        end
    end

    for _, option in ipairs(options) do
        local choice = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 22),
            BorderSizePixel = 0,
            Text = tostring(option),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextSize = 12,
            Font = Enum.Font.Code,
            AutoButtonColor = false,
            ZIndex = 11,
        })
        self.UI:_track(choice, "PanelAlt")
        self.UI:_track(choice, "Text", "TextColor3")
        choice.Parent = menu
        choice.MouseButton1Click:Connect(function()
            set(option)
        end)
    end

    button.MouseButton1Click:Connect(function()
        open = not open
        menu.Visible = open
        row.Size = UDim2.new(1, 0, 0, open and (24 + (#options * 22)) or 24)
    end)

    return { Set = set, Get = function() return selected end, Instance = row }
end

function SectionClass:CreateTextbox(config)
    config = config or {}
    local row = self:_row(24)
    local box = make("TextBox", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 1,
        Text = config.Default or "",
        PlaceholderText = config.Placeholder or config.Text or "Input...",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        Font = Enum.Font.Code,
        ClearTextOnFocus = false,
    })
    self.UI:_track(box, "Control")
    self.UI:_track(box, "Border", "BorderColor3")
    self.UI:_track(box, "Text", "TextColor3")
    box.Parent = row

    box.FocusLost:Connect(function(enterPressed)
        safeCallback(config.Callback, self.UI.Logger, config.Text or "Textbox", box.Text, enterPressed)
    end)

    return box
end

function UIClass:_buildConsole()
    if self.ConsoleTab then
        return self.ConsoleTab
    end

    self.ConsoleTab = self:CreateTab("Console")
    local toolbar = self.ConsoleTab:CreateSection("Console Controls")
    local filter = "ALL"
    local autoScroll = true

    local holder = self.ConsoleTab:CreateSection("Output")
    holder.Frame.Size = UDim2.new(1, 0, 0, 220)
    holder.Body.Size = UDim2.new(1, -10, 0, 190)

    local output = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 190),
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        BorderSizePixel = 1,
    })
    self:_track(output, "Background")
    self:_track(output, "Border", "BorderColor3")
    output.Parent = holder.Body
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }).Parent = output

    local function resetOutput()
        output:ClearAllChildren()
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }).Parent = output
    end

    local function addEntry(entry)
        if entry.Clear then
            resetOutput()
            return
        end

        if filter ~= "ALL" and entry.Level ~= filter then
            return
        end

        local line = make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, 18),
            Text = string.format("[%s] [%s] [%s] %s", entry.Time, entry.Level, entry.Source, entry.Message),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextSize = 11,
            Font = Enum.Font.Code,
        })
        local role = ({ INFO = "Text", WARN = "Warning", ERROR = "Error", DEBUG = "Debug" })[entry.Level] or "Text"
        self:_track(line, role, "TextColor3")
        line.Parent = output

        if autoScroll then
            task.defer(function()
                output.CanvasPosition = Vector2.new(0, math.max(0, output.AbsoluteCanvasSize.Y))
            end)
        end
    end

    toolbar:CreateDropdown({
        Text = "Filter",
        Options = { "ALL", "INFO", "WARN", "ERROR", "DEBUG" },
        Default = "ALL",
        Callback = function(value)
            filter = value
            resetOutput()
            for _, entry in ipairs(self.Logger:GetHistory()) do
                addEntry(entry)
            end
        end,
    })

    toolbar:CreateToggle({
        Text = "Auto-scroll",
        Default = true,
        Callback = function(value)
            autoScroll = value
        end,
    })

    toolbar:CreateButton({
        Text = "Clear Console",
        Callback = function()
            self.Logger:Clear()
        end,
    })

    toolbar:CreateButton({
        Text = "Pop Out Console",
        Callback = function()
            self:PopOutConsole()
        end,
    })

    self.Console = {
        Output = output,
        SetFilter = function(_, value)
            filter = value
        end,
        PopOut = function()
            self:PopOutConsole()
        end,
        Dock = function()
            if self.PopoutWindow then
                self.PopoutWindow:Destroy()
                self.PopoutWindow = nil
            end
        end,
    }

    self.Logger:Connect(addEntry)
    for _, entry in ipairs(self.Logger:GetHistory()) do
        addEntry(entry)
    end

    return self.ConsoleTab
end

function UIClass:PopOutConsole()
    if self.PopoutWindow and self.PopoutWindow.Parent then
        self.PopoutWindow.Visible = true
        return
    end

    local pop = make("Frame", {
        Name = "PopoutConsole",
        Size = UDim2.fromOffset(520, 240),
        Position = UDim2.fromOffset(80, 80),
        BorderSizePixel = 1,
        Active = true,
    })
    self:_track(pop, "Background")
    self:_track(pop, "Border", "BorderColor3")
    pop.Parent = self.Gui
    self.PopoutWindow = pop

    local bar = make("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BorderSizePixel = 0,
        Active = true,
    })
    self:_track(bar, "Topbar")
    bar.Parent = pop

    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(6, 0),
        Size = UDim2.new(1, -34, 1, 0),
        Text = "Meerly Console",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        Font = Enum.Font.Code,
    })
    self:_track(label, "Text", "TextColor3")
    label.Parent = bar

    local close = self:_makeButton(bar, "X", 26)
    close.Position = UDim2.new(1, -28, 0, 1)
    close.Size = UDim2.fromOffset(26, 20)
    self:_track(close, "Error")
    close.Parent = bar
    close.MouseButton1Click:Connect(function()
        pop.Visible = false
    end)

    local output = make("ScrollingFrame", {
        Position = UDim2.fromOffset(4, 26),
        Size = UDim2.new(1, -8, 1, -30),
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        BorderSizePixel = 1,
    })
    self:_track(output, "Panel")
    self:_track(output, "Border", "BorderColor3")
    output.Parent = pop
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }).Parent = output

    local function resetOutput()
        output:ClearAllChildren()
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }).Parent = output
    end

    local function add(entry)
        if entry.Clear then
            resetOutput()
            return
        end

        local line = make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, 18),
            Text = string.format("[%s] [%s] [%s] %s", entry.Time, entry.Level, entry.Source, entry.Message),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextSize = 11,
            Font = Enum.Font.Code,
        })
        local role = ({ INFO = "Text", WARN = "Warning", ERROR = "Error", DEBUG = "Debug" })[entry.Level] or "Text"
        self:_track(line, role, "TextColor3")
        line.Parent = output

        task.defer(function()
            output.CanvasPosition = Vector2.new(0, math.max(0, output.AbsoluteCanvasSize.Y))
        end)
    end

    for _, entry in ipairs(self.Logger:GetHistory()) do
        add(entry)
    end
    self.Logger:Connect(add)

    local dragging = false
    local start = nil
    local startPos = nil

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            start = input.Position
            startPos = pop.Position
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - start
            pop.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function UIClass:CreateThemeTab()
    if self.Tabs.Theme then
        return self.Tabs.Theme
    end

    local tab = self:CreateTab("Theme")
    local colors = tab:CreateSection("Colors")
    local effects = tab:CreateSection("Effects")

    local function colorControl(key)
        local color = self.Theme[key]
        colors:CreateTextbox({
            Text = key .. " RGB",
            Placeholder = "R,G,B",
            Default = string.format("%d,%d,%d", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)),
            Callback = function(text)
                local r, g, b = string.match(text, "(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
                if r and g and b then
                    self:SetThemeValue(key, Color3.fromRGB(clamp(tonumber(r), 0, 255), clamp(tonumber(g), 0, 255), clamp(tonumber(b), 0, 255)))
                    self.Logger:Info("Updated theme color " .. key, "Theme")
                else
                    self.Logger:Warn("Use RGB format like 224,42,91 for " .. key, "Theme")
                end
            end,
        })
    end

    for _, key in ipairs({ "Background", "Topbar", "Panel", "PanelAlt", "Control", "Border", "Accent", "AccentDark", "Text", "MutedText" }) do
        colorControl(key)
    end

    effects:CreateSlider({
        Text = "Transparency",
        Min = 0,
        Max = 0.75,
        Default = self.Theme.Transparency or 0,
        Increment = 0.05,
        Callback = function(value)
            self:SetThemeValue("Transparency", value)
        end,
    })

    effects:CreateSlider({
        Text = "Blur",
        Min = 0,
        Max = 24,
        Default = self.Theme.Blur or 0,
        Increment = 1,
        Callback = function(value)
            self:SetThemeValue("Blur", value)
        end,
    })

    effects:CreateDropdown({
        Text = "Preset",
        Options = { "MeerlyDark", "MeerlyBlue", "ClassicDark" },
        Default = self.ThemeName,
        Callback = function(value)
            self:SetTheme(value)
            self.Logger:Info("Applied theme preset " .. value, "Theme")
        end,
    })

    return tab
end

function MUILib.new(config)
    config = config or {}
    local universalConfig = MUILib.LoadUniversalConfig()
    local uiConfig = universalConfig["UI Library Config"] or {}
    local themeName = config.Theme or uiConfig.ThemeName or "MeerlyDark"
    local baseTheme = MUILib.Themes[themeName] or MUILib.Themes.MeerlyDark
    local theme = hydrateTheme(uiConfig.Theme or {}, baseTheme)

    local self = setmetatable({
        Title = config.Title or "Meerly UI",
        ThemeName = themeName,
        Theme = theme,
        Config = universalConfig,
        Tabs = {},
        TabOrder = {},
        Tracked = {},
        KillCallbacks = {},
        Minimized = false,
        Killed = false,
    }, UIClass)

    self.Logger = LoggerClass.new(self)
    self:_createBase(config)

    if config.ThemeTab ~= false then
        self:CreateThemeTab()
    end

    if config.Console ~= false then
        self:_buildConsole()
    end

    self:_applyTheme()
    self.Logger:Info("MUILib " .. MUILib.Version .. " initialized. Press ; to minimize/restore.", "UI")
    return self
end

return MUILib
