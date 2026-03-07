--[[
    MeerlyUI95.lua
    ---------------------------------------------------------------------
    A Windows 95-inspired Luau UI library for Roblox scripts.

    Design goals:
      * Reliable, lightweight, and self-contained.
      * "Single entry-point" API for quickly wiring features.
      * Strong cleanup/kill flow that attempts to reverse runtime changes.
      * Unified config store for theme + runtime settings.

    Typical usage:

      local UI95 = loadstring(readfile("MeerlyUI95.lua"))()
      local app = UI95.new({
          ToggleKey = Enum.KeyCode.Semicolon,
          KeygateKey = "1234",
          KeygateLink = "https://example.com/get-key",
      })

      app:Build() -- Creates keygate splash, then the main GUI after unlock.
      app:Log("INFO", "Library started.", "BOOT")

    Notes:
      * Some controls call exploit/runtime-dependent APIs when available
        (writefile/readfile/isfile/setfpscap/queue_on_teleport/etc.).
      * All such calls are guarded with feature checks to prevent hard crashes.
]]

local UI95 = {}
UI95.__index = UI95

--// Services ---------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Helpers ----------------------------------------------------------------
local function safeCall(fn)
    local ok, result = pcall(fn)
    if ok then
        return true, result
    end
    return false, result
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function deepCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end

--// Theme presets ----------------------------------------------------------
local THEME_PRESETS = {
    {
        Name = "Windows95",
        Colors = { rgb(0, 0, 128), rgb(192, 192, 192), rgb(255, 255, 255), rgb(128, 128, 128), rgb(0, 0, 0) },
        Theme = {
            Accent = rgb(0, 0, 128),
            Background = rgb(58, 110, 165),
            Panel = rgb(192, 192, 192),
            PanelDark = rgb(128, 128, 128),
            Border = rgb(0, 0, 0),
            Text = rgb(0, 0, 0),
            SubText = rgb(32, 32, 32),
        },
    },
    { Name = "Storm", Colors = { rgb(63, 81, 181), rgb(48, 63, 159), rgb(255, 193, 7), rgb(224, 224, 224), rgb(33, 33, 33) }, Theme = { Accent = rgb(63, 81, 181), Background = rgb(18, 24, 39), Panel = rgb(28, 36, 56), PanelDark = rgb(20, 26, 42), Border = rgb(66, 75, 99), Text = rgb(235, 239, 245), SubText = rgb(170, 179, 196) } },
    { Name = "Forest", Colors = { rgb(46, 125, 50), rgb(102, 187, 106), rgb(200, 230, 201), rgb(56, 142, 60), rgb(27, 94, 32) }, Theme = { Accent = rgb(76, 175, 80), Background = rgb(13, 35, 23), Panel = rgb(23, 53, 35), PanelDark = rgb(18, 42, 28), Border = rgb(55, 97, 70), Text = rgb(230, 245, 235), SubText = rgb(170, 205, 181) } },
    { Name = "Rose", Colors = { rgb(233, 30, 99), rgb(244, 143, 177), rgb(255, 240, 246), rgb(194, 24, 91), rgb(136, 14, 79) }, Theme = { Accent = rgb(233, 30, 99), Background = rgb(46, 16, 31), Panel = rgb(76, 23, 49), PanelDark = rgb(56, 17, 36), Border = rgb(122, 48, 84), Text = rgb(255, 232, 244), SubText = rgb(235, 178, 205) } },
    { Name = "Amber", Colors = { rgb(255, 193, 7), rgb(255, 224, 130), rgb(255, 248, 225), rgb(255, 160, 0), rgb(255, 111, 0) }, Theme = { Accent = rgb(255, 193, 7), Background = rgb(49, 34, 8), Panel = rgb(75, 53, 14), PanelDark = rgb(58, 41, 10), Border = rgb(130, 93, 24), Text = rgb(255, 242, 210), SubText = rgb(230, 198, 127) } },
    { Name = "Neon", Colors = { rgb(0, 255, 255), rgb(255, 0, 255), rgb(57, 255, 20), rgb(20, 20, 20), rgb(240, 240, 240) }, Theme = { Accent = rgb(0, 255, 255), Background = rgb(12, 12, 16), Panel = rgb(20, 20, 28), PanelDark = rgb(14, 14, 20), Border = rgb(0, 204, 204), Text = rgb(240, 240, 240), SubText = rgb(176, 176, 186) } },
    { Name = "Slate", Colors = { rgb(96, 125, 139), rgb(120, 144, 156), rgb(207, 216, 220), rgb(69, 90, 100), rgb(38, 50, 56) }, Theme = { Accent = rgb(96, 125, 139), Background = rgb(23, 30, 35), Panel = rgb(39, 49, 56), PanelDark = rgb(29, 37, 43), Border = rgb(84, 101, 110), Text = rgb(227, 234, 238), SubText = rgb(168, 182, 189) } },
    { Name = "Terminal", Colors = { rgb(0, 255, 0), rgb(0, 160, 0), rgb(15, 15, 15), rgb(40, 40, 40), rgb(180, 255, 180) }, Theme = { Accent = rgb(0, 255, 0), Background = rgb(8, 15, 8), Panel = rgb(14, 26, 14), PanelDark = rgb(10, 20, 10), Border = rgb(0, 145, 0), Text = rgb(180, 255, 180), SubText = rgb(110, 190, 110) } },
    { Name = "Ocean", Colors = { rgb(3, 169, 244), rgb(2, 136, 209), rgb(129, 212, 250), rgb(225, 245, 254), rgb(1, 87, 155) }, Theme = { Accent = rgb(3, 169, 244), Background = rgb(8, 27, 43), Panel = rgb(15, 43, 66), PanelDark = rgb(11, 33, 51), Border = rgb(35, 95, 134), Text = rgb(216, 242, 255), SubText = rgb(146, 194, 225) } },
    { Name = "Mono", Colors = { rgb(15, 15, 15), rgb(50, 50, 50), rgb(110, 110, 110), rgb(190, 190, 190), rgb(245, 245, 245) }, Theme = { Accent = rgb(225, 225, 225), Background = rgb(18, 18, 18), Panel = rgb(30, 30, 30), PanelDark = rgb(24, 24, 24), Border = rgb(92, 92, 92), Text = rgb(235, 235, 235), SubText = rgb(160, 160, 160) } },
}

local DEFAULTS = {
    ToggleKey = Enum.KeyCode.Semicolon,
    KeygateKey = "1234",
    KeygateLink = "https://example.com/get-key",
    ConfigFile = "MeerlyUI95_Config.json",
    MaxConsoleEntries = 250,
    DefaultTheme = "Windows95",
}

function UI95.new(options)
    options = options or {}
    local self = setmetatable({}, UI95)

    self.Options = {}
    for k, v in pairs(DEFAULTS) do
        self.Options[k] = v
    end
    for k, v in pairs(options) do
        self.Options[k] = v
    end

    self.Destroyed = false
    self.Ready = false
    self.Hidden = false
    self.Connections = {}
    self.ThemeBindings = {}
    self.PageButtons = {}
    self.Pages = {}
    self.FloatWindows = {}
    self.ConsoleEntries = {}
    self.ConsoleFilter = { INFO = true, WARN = true, ERROR = true, DEBUG = true, SYSTEM = true }

    self.Runtime = {
        BlurAmount = 8,
        Transparency = 0,
        ZoomUnlock = false,
        FPSCounter = false,
        GraphicsMode = "default",
        FXCulling = "Medium",
        StreamingOptimizations = false,
        BackgroundSurvival = false,
        AntiAFK = false,
        Watchdog = false,
        FPSCap = 60,
        MemoryGuard = "Off",
        MemoryGuardGB = 5,
        Disable3D = false,
        AFKCamera = false,
    }

    self.Theme = deepCopy(THEME_PRESETS[1].Theme)
    self.Slots = {
        { Name = "Slot 1", Data = nil },
        { Name = "Slot 2", Data = nil },
        { Name = "Slot 3", Data = nil },
        { Name = "Slot 4", Data = nil },
        { Name = "Slot 5", Data = nil },
    }

    self._original = {
        CameraMinZoom = LocalPlayer.CameraMinZoomDistance,
        CameraMaxZoom = LocalPlayer.CameraMaxZoomDistance,
        RenderingState = true,
    }

    self:LoadUnifiedConfig()
    return self
end

function UI95:_track(connection)
    if connection then
        table.insert(self.Connections, connection)
    end
    return connection
end

function UI95:_bindTheme(obj, prop, key)
    table.insert(self.ThemeBindings, { Obj = obj, Prop = prop, Key = key })
end

function UI95:ApplyTheme(themeData)
    self.Theme = deepCopy(themeData)

    for _, bind in ipairs(self.ThemeBindings) do
        local obj = bind.Obj
        if obj and obj.Parent then
            local value = self.Theme[bind.Key or bind.Prop]
            if value ~= nil then
                obj[bind.Prop] = value
            end
        end
    end

    for _, pageButton in pairs(self.PageButtons) do
        pageButton.BackgroundColor3 = self.Theme.Panel
        pageButton.TextColor3 = self.Theme.Text
    end

    if self.ActivePage and self.PageButtons[self.ActivePage] then
        self.PageButtons[self.ActivePage].BackgroundColor3 = self.Theme.PanelDark
        self.PageButtons[self.ActivePage].TextColor3 = self.Theme.Accent
    end

    if self.BlurEffect then
        self.BlurEffect.Size = self.Runtime.BlurAmount
    end

    if self.Root then
        self.Root.BackgroundTransparency = self.Runtime.Transparency
    end

    self:RefreshConfigUI()
end

function UI95:FindPresetByName(name)
    for _, preset in ipairs(THEME_PRESETS) do
        if preset.Name == name then
            return preset
        end
    end
    return THEME_PRESETS[1]
end

function UI95:SaveUnifiedConfig()
    local config = {
        Theme = self.Theme,
        ThemeName = self.CurrentThemeName or self.Options.DefaultTheme,
        Runtime = self.Runtime,
        Slots = self.Slots,
    }

    local canSave = (typeof(writefile) == "function") and (typeof(HttpService.JSONEncode) == "function")
    if canSave then
        local ok, err = safeCall(function()
            writefile(self.Options.ConfigFile, HttpService:JSONEncode(config))
        end)
        if ok then
            self:Log("INFO", "Unified config saved.", "CONFIG")
            return true
        end
        self:Log("ERROR", "Failed to save config: " .. tostring(err), "CONFIG")
        return false
    end

    self:Log("WARN", "writefile unavailable in this environment.", "CONFIG")
    return false
end

function UI95:LoadUnifiedConfig()
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
        return
    end
    if not isfile(self.Options.ConfigFile) then
        return
    end

    local ok, data = safeCall(function()
        return HttpService:JSONDecode(readfile(self.Options.ConfigFile))
    end)

    if not ok or type(data) ~= "table" then
        return
    end

    if type(data.Theme) == "table" then
        self.Theme = data.Theme
    end
    if type(data.ThemeName) == "string" then
        self.CurrentThemeName = data.ThemeName
    end
    if type(data.Runtime) == "table" then
        for k, v in pairs(data.Runtime) do
            self.Runtime[k] = v
        end
    end
    if type(data.Slots) == "table" then
        self.Slots = data.Slots
    end
end

function UI95:Log(level, message, source)
    level = level or "INFO"
    message = tostring(message or "")
    source = source or "SYSTEM"

    local entry = {
        Time = os.date("%H:%M:%S"),
        Level = level,
        Message = message,
        Source = source,
    }

    table.insert(self.ConsoleEntries, entry)
    if #self.ConsoleEntries > self.Options.MaxConsoleEntries then
        table.remove(self.ConsoleEntries, 1)
    end

    if self.ConsoleContainer then
        self:RenderConsole()
    end
end

function UI95:RenderConsole()
    if not self.ConsoleContainer then return end

    self.ConsoleContainer:ClearAllChildren()

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 3)
    list.Parent = self.ConsoleContainer

    local colors = {
        INFO = rgb(235, 235, 235),
        WARN = rgb(255, 220, 120),
        ERROR = rgb(255, 120, 120),
        DEBUG = rgb(150, 210, 255),
        SYSTEM = rgb(170, 255, 170),
    }

    for _, entry in ipairs(self.ConsoleEntries) do
        if self.ConsoleFilter[entry.Level] then
            local line = Instance.new("TextLabel")
            line.Size = UDim2.new(1, -8, 0, 18)
            line.BackgroundTransparency = 1
            line.TextXAlignment = Enum.TextXAlignment.Left
            line.Font = Enum.Font.Code
            line.TextSize = 14
            line.TextColor3 = colors[entry.Level] or self.Theme.Text
            line.Text = string.format("[%s][%s][%s] %s", entry.Time, entry.Level, entry.Source, entry.Message)
            line.Parent = self.ConsoleContainer
        end
    end
end

function UI95:CreateButton(parent, text, onClick)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 140, 0, 24)
    button.BackgroundColor3 = self.Theme.Panel
    button.TextColor3 = self.Theme.Text
    button.Font = Enum.Font.Arial
    button.TextSize = 14
    button.Text = text
    button.BorderColor3 = self.Theme.Border
    button.Parent = parent

    self:_bindTheme(button, "BackgroundColor3", "Panel")
    self:_bindTheme(button, "TextColor3", "Text")
    self:_bindTheme(button, "BorderColor3", "Border")

    self:_track(button.MouseButton1Click:Connect(function()
        if self.Destroyed then return end
        onClick()
    end))

    return button
end

function UI95:CreateCheckbox(parent, text, key)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -8, 0, 24)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0, 22, 0, 22)
    box.Position = UDim2.new(0, 0, 0, 1)
    box.Text = self.Runtime[key] and "✓" or ""
    box.TextSize = 18
    box.Font = Enum.Font.ArialBold
    box.BackgroundColor3 = self.Theme.Panel
    box.TextColor3 = self.Theme.Text
    box.BorderColor3 = self.Theme.Border
    box.Parent = holder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -26, 1, 0)
    label.Position = UDim2.new(0, 26, 0, 0)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.TextColor3 = self.Theme.Text
    label.Font = Enum.Font.Arial
    label.TextSize = 14
    label.Parent = holder

    self:_bindTheme(box, "BackgroundColor3", "Panel")
    self:_bindTheme(box, "TextColor3", "Text")
    self:_bindTheme(box, "BorderColor3", "Border")
    self:_bindTheme(label, "TextColor3", "Text")

    self:_track(box.MouseButton1Click:Connect(function()
        self.Runtime[key] = not self.Runtime[key]
        box.Text = self.Runtime[key] and "✓" or ""
        self:ApplyRuntimeOptions()
        self:SaveUnifiedConfig()
    end))

    return holder
end

function UI95:CreateSlider(parent, labelText, minValue, maxValue, runtimeKey, onUpdate)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, -8, 0, 44)
    wrap.BackgroundTransparency = 1
    wrap.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Arial
    label.TextSize = 14
    label.TextColor3 = self.Theme.Text
    label.Text = string.format("%s: %s", labelText, tostring(self.Runtime[runtimeKey]))
    label.Parent = wrap

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 14)
    bar.Position = UDim2.new(0, 0, 0, 24)
    bar.BackgroundColor3 = self.Theme.PanelDark
    bar.BorderColor3 = self.Theme.Border
    bar.Parent = wrap

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((self.Runtime[runtimeKey] - minValue) / (maxValue - minValue), 0, 1, 0)
    fill.BackgroundColor3 = self.Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar

    self:_bindTheme(label, "TextColor3", "Text")
    self:_bindTheme(bar, "BackgroundColor3", "PanelDark")
    self:_bindTheme(bar, "BorderColor3", "Border")
    self:_bindTheme(fill, "BackgroundColor3", "Accent")

    local dragging = false

    local function setFromX(x)
        local ratio = clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local value = math.floor(minValue + ((maxValue - minValue) * ratio) + 0.5)
        self.Runtime[runtimeKey] = value
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        label.Text = string.format("%s: %d", labelText, value)
        if onUpdate then onUpdate(value) end
    end

    self:_track(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromX(input.Position.X)
        end
    end))

    self:_track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end))

    self:_track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            self:ApplyRuntimeOptions()
            self:SaveUnifiedConfig()
        end
    end))

    return wrap
end

function UI95:CreatePage(name, icon)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -12, 1, -80)
    page.Position = UDim2.new(0, 6, 0, 30)
    page.BackgroundColor3 = self.Theme.Panel
    page.BorderColor3 = self.Theme.Border
    page.ScrollBarThickness = 8
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    page.Parent = self.Root

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 6)
    list.Parent = page

    self.Pages[name] = page

    self:_bindTheme(page, "BackgroundColor3", "Panel")
    self:_bindTheme(page, "BorderColor3", "Border")

    local tab = Instance.new("TextButton")
    tab.Name = name .. "Tab"
    tab.Text = icon or "□"
    tab.Font = Enum.Font.SourceSansBold
    tab.TextSize = 20
    tab.BackgroundColor3 = self.Theme.Panel
    tab.TextColor3 = self.Theme.Text
    tab.BorderColor3 = self.Theme.Border
    tab.Parent = self.Taskbar
    self.PageButtons[name] = tab

    self:_bindTheme(tab, "BackgroundColor3", "Panel")
    self:_bindTheme(tab, "TextColor3", "Text")
    self:_bindTheme(tab, "BorderColor3", "Border")

    self:_track(tab.MouseButton1Click:Connect(function()
        self:ShowPage(name)
    end))

    self:UpdateTaskbarButtonSizing()
    return page
end

function UI95:UpdateTaskbarButtonSizing()
    local count = 0
    for _ in pairs(self.PageButtons) do
        count = count + 1
    end
    if count == 0 then return end

    local maxHeight = 30
    local width = math.floor((self.Taskbar.AbsoluteSize.X - 6) / count)
    local height = clamp(maxHeight, 24, maxHeight)

    for _, button in pairs(self.PageButtons) do
        button.Size = UDim2.new(0, math.max(36, width - 2), 0, height)
    end
end

function UI95:ShowPage(name)
    self.ActivePage = name
    for pageName, page in pairs(self.Pages) do
        page.Visible = (pageName == name)
    end
    for pageName, tab in pairs(self.PageButtons) do
        local active = (pageName == name)
        tab.BackgroundColor3 = active and self.Theme.PanelDark or self.Theme.Panel
        tab.TextColor3 = active and self.Theme.Accent or self.Theme.Text
    end
end

function UI95:ToggleVisible()
    self.Hidden = not self.Hidden
    self.Root.Visible = not self.Hidden

    for _, float in ipairs(self.FloatWindows) do
        if float and float.Window and float.Window.Parent then
            if float.HideWithMain then
                float.Window.Visible = not self.Hidden
            else
                float.Window.Visible = true
            end
        end
    end
end

function UI95:CreateFloatingWindow(title, hideWithMain, size)
    local window = Instance.new("Frame")
    window.Size = size or UDim2.new(0, 240, 0, 120)
    window.Position = UDim2.new(0, 40 + (#self.FloatWindows * 20), 0, 40 + (#self.FloatWindows * 20))
    window.BackgroundColor3 = self.Theme.Panel
    window.BorderColor3 = self.Theme.Border
    window.Parent = self.ScreenGui

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 22)
    titleBar.BackgroundColor3 = self.Theme.Accent
    titleBar.BorderColor3 = self.Theme.Border
    titleBar.Parent = window

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -8, 1, 0)
    titleLabel.Position = UDim2.new(0, 4, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.ArialBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = rgb(255, 255, 255)
    titleLabel.Parent = titleBar

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, -6, 1, -28)
    body.Position = UDim2.new(0, 3, 0, 25)
    body.BackgroundTransparency = 1
    body.Parent = window

    self:_bindTheme(window, "BackgroundColor3", "Panel")
    self:_bindTheme(window, "BorderColor3", "Border")
    self:_bindTheme(titleBar, "BackgroundColor3", "Accent")

    local info = { Window = window, Body = body, HideWithMain = hideWithMain ~= false }
    table.insert(self.FloatWindows, info)
    return info
end

function UI95:ApplyRuntimeOptions()
    -- Transparency/blur controls
    if self.Root then
        self.Root.BackgroundTransparency = self.Runtime.Transparency
    end
    if self.BlurEffect then
        self.BlurEffect.Size = self.Runtime.BlurAmount
    end

    -- Zoom unlock
    if self.Runtime.ZoomUnlock then
        LocalPlayer.CameraMinZoomDistance = 0
        LocalPlayer.CameraMaxZoomDistance = 1000
    else
        LocalPlayer.CameraMinZoomDistance = self._original.CameraMinZoom
        LocalPlayer.CameraMaxZoomDistance = self._original.CameraMaxZoom
    end

    -- FPS cap (if supported)
    if typeof(setfpscap) == "function" then
        safeCall(function()
            setfpscap(clamp(self.Runtime.FPSCap, 10, 240))
        end)
    end

    -- 3D rendering toggle
    safeCall(function()
        RunService:Set3dRenderingEnabled(not self.Runtime.Disable3D)
        self._original.RenderingState = not self.Runtime.Disable3D
    end)

    -- AFK camera
    local cam = workspace.CurrentCamera
    if cam then
        if self.Runtime.AFKCamera then
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CFrame = CFrame.new(0, 100000, 0)
        else
            cam.CameraType = Enum.CameraType.Custom
        end
    end
end

function UI95:BuildThemePage()
    local page = self:CreatePage("Theme", "🎨")

    local presetHeader = Instance.new("TextLabel")
    presetHeader.Size = UDim2.new(1, -8, 0, 18)
    presetHeader.BackgroundTransparency = 1
    presetHeader.TextXAlignment = Enum.TextXAlignment.Left
    presetHeader.Text = "Theme Presets (10 with swatches):"
    presetHeader.TextColor3 = self.Theme.Text
    presetHeader.Font = Enum.Font.ArialBold
    presetHeader.TextSize = 14
    presetHeader.Parent = page
    self:_bindTheme(presetHeader, "TextColor3", "Text")

    for _, preset in ipairs(THEME_PRESETS) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 30)
        row.BackgroundColor3 = self.Theme.PanelDark
        row.BorderColor3 = self.Theme.Border
        row.Parent = page

        self:_bindTheme(row, "BackgroundColor3", "PanelDark")
        self:_bindTheme(row, "BorderColor3", "Border")

        local useButton = self:CreateButton(row, preset.Name, function()
            self.CurrentThemeName = preset.Name
            self:ApplyTheme(preset.Theme)
            self:SaveUnifiedConfig()
            self:Log("SYSTEM", "Theme applied: " .. preset.Name, "THEME")
        end)
        useButton.Position = UDim2.new(0, 2, 0, 2)
        useButton.Size = UDim2.new(0, 112, 0, 24)

        for i = 1, 5 do
            local swatch = Instance.new("Frame")
            swatch.Size = UDim2.new(0, 18, 0, 18)
            swatch.Position = UDim2.new(0, 120 + ((i - 1) * 22), 0, 6)
            swatch.BackgroundColor3 = preset.Colors[i] or rgb(255, 255, 255)
            swatch.BorderColor3 = rgb(0, 0, 0)
            swatch.Parent = row
        end
    end

    self:CreateSlider(page, "Transparency", 0, 100, "Transparency", function(value)
        self.Runtime.Transparency = value / 100
    end)

    self:CreateSlider(page, "Blur", 0, 24, "BlurAmount", function(value)
        self.Runtime.BlurAmount = value
    end)

    self:CreateCheckbox(page, "Enable FPS Counter", "FPSCounter")
end

function UI95:BuildConfigPage()
    local page = self:CreatePage("Config", "💾")
    self.ConfigPage = page

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -8, 0, 18)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Unified Config Slots (rename/save/load/delete)"
    title.TextColor3 = self.Theme.Text
    title.Font = Enum.Font.ArialBold
    title.TextSize = 14
    title.Parent = page
    self:_bindTheme(title, "TextColor3", "Text")

    self.ConfigRows = {}
    for idx = 1, 5 do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 62)
        row.BackgroundColor3 = self.Theme.PanelDark
        row.BorderColor3 = self.Theme.Border
        row.Parent = page

        self:_bindTheme(row, "BackgroundColor3", "PanelDark")
        self:_bindTheme(row, "BorderColor3", "Border")

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0, 120, 0, 24)
        box.Position = UDim2.new(0, 4, 0, 4)
        box.BackgroundColor3 = self.Theme.Panel
        box.TextColor3 = self.Theme.Text
        box.BorderColor3 = self.Theme.Border
        box.Font = Enum.Font.Arial
        box.TextSize = 14
        box.Text = self.Slots[idx].Name or ("Slot " .. idx)
        box.Parent = row

        self:_bindTheme(box, "BackgroundColor3", "Panel")
        self:_bindTheme(box, "TextColor3", "Text")
        self:_bindTheme(box, "BorderColor3", "Border")

        self:_track(box.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                self.Slots[idx].Name = box.Text
                self:SaveUnifiedConfig()
                self:Log("INFO", "Renamed slot " .. idx .. " to '" .. box.Text .. "'.", "CONFIG")
            end
        end))

        local swatch = Instance.new("Frame")
        swatch.Size = UDim2.new(0, 22, 0, 22)
        swatch.Position = UDim2.new(0, 128, 0, 5)
        swatch.BackgroundColor3 = self.Theme.Accent
        swatch.BorderColor3 = rgb(0, 0, 0)
        swatch.Parent = row

        local saveBtn = self:CreateButton(row, "Save", function()
            self.Slots[idx].Data = {
                Theme = deepCopy(self.Theme),
                ThemeName = self.CurrentThemeName,
                Runtime = deepCopy(self.Runtime),
            }
            self:SaveUnifiedConfig()
            self:RefreshConfigUI()
            self:Log("SYSTEM", "Saved slot " .. idx .. ".", "CONFIG")
        end)
        saveBtn.Position = UDim2.new(0, 156, 0, 4)
        saveBtn.Size = UDim2.new(0, 70, 0, 24)

        local loadBtn = self:CreateButton(row, "Load", function()
            local data = self.Slots[idx].Data
            if not data then
                self:Log("WARN", "Slot " .. idx .. " is empty.", "CONFIG")
                return
            end
            if data.Theme then self:ApplyTheme(data.Theme) end
            if data.ThemeName then self.CurrentThemeName = data.ThemeName end
            if data.Runtime then
                for k, v in pairs(data.Runtime) do self.Runtime[k] = v end
                self:ApplyRuntimeOptions()
            end
            self:SaveUnifiedConfig()
            self:RefreshConfigUI()
            self:Log("SYSTEM", "Loaded slot " .. idx .. ".", "CONFIG")
        end)
        loadBtn.Position = UDim2.new(0, 230, 0, 4)
        loadBtn.Size = UDim2.new(0, 70, 0, 24)

        local delBtn = self:CreateButton(row, "Delete", function()
            self.Slots[idx].Data = nil
            self:SaveUnifiedConfig()
            self:RefreshConfigUI()
            self:Log("WARN", "Deleted slot " .. idx .. ".", "CONFIG")
        end)
        delBtn.Position = UDim2.new(0, 304, 0, 4)
        delBtn.Size = UDim2.new(0, 70, 0, 24)

        self.ConfigRows[idx] = { Box = box, Swatch = swatch }
    end

    self:RefreshConfigUI()
end

function UI95:RefreshConfigUI()
    if not self.ConfigRows then return end
    for idx, row in ipairs(self.ConfigRows) do
        local slot = self.Slots[idx]
        row.Box.Text = slot.Name or ("Slot " .. idx)
        if slot.Data and slot.Data.Theme and slot.Data.Theme.Accent then
            row.Swatch.BackgroundColor3 = slot.Data.Theme.Accent
        else
            row.Swatch.BackgroundColor3 = rgb(60, 60, 60)
        end
    end
end

function UI95:BuildConsolePage()
    local page = self:CreatePage("Console", "🖥")

    local controls = Instance.new("Frame")
    controls.Size = UDim2.new(1, -8, 0, 28)
    controls.BackgroundTransparency = 1
    controls.Parent = page

    local levels = { "INFO", "WARN", "ERROR", "DEBUG", "SYSTEM" }
    for i, level in ipairs(levels) do
        local btn = self:CreateButton(controls, level, function()
            self.ConsoleFilter[level] = not self.ConsoleFilter[level]
            self:RenderConsole()
        end)
        btn.Position = UDim2.new(0, (i - 1) * 74, 0, 2)
        btn.Size = UDim2.new(0, 70, 0, 24)
    end

    local clearBtn = self:CreateButton(controls, "Clear", function()
        self.ConsoleEntries = {}
        self:RenderConsole()
    end)
    clearBtn.Position = UDim2.new(1, -72, 0, 2)
    clearBtn.Size = UDim2.new(0, 70, 0, 24)

    local console = Instance.new("ScrollingFrame")
    console.Size = UDim2.new(1, -8, 1, -42)
    console.Position = UDim2.new(0, 0, 0, 34)
    console.BackgroundColor3 = rgb(10, 10, 10)
    console.BorderColor3 = self.Theme.Border
    console.AutomaticCanvasSize = Enum.AutomaticSize.Y
    console.CanvasSize = UDim2.new(0, 0, 0, 0)
    console.ScrollBarThickness = 8
    console.Parent = page

    self.ConsoleContainer = console
    self:_bindTheme(console, "BorderColor3", "Border")

    self:Log("SYSTEM", "Console initialized.", "BOOT")
    self:RenderConsole()
end

function UI95:BuildRobloxSettingsPage()
    local page = self:CreatePage("Roblox", "⚙")

    local section = Instance.new("TextLabel")
    section.Size = UDim2.new(1, -8, 0, 18)
    section.BackgroundTransparency = 1
    section.TextXAlignment = Enum.TextXAlignment.Left
    section.Font = Enum.Font.ArialBold
    section.TextSize = 14
    section.TextColor3 = self.Theme.Text
    section.Text = "Quick Settings"
    section.Parent = page
    self:_bindTheme(section, "TextColor3", "Text")

    self:CreateCheckbox(page, "Zoom Unlock", "ZoomUnlock")

    local rejoin = self:CreateButton(page, "Rejoin Server", function()
        local placeId, jobId = game.PlaceId, game.JobId
        self:Log("WARN", "Rejoining server...", "ROBLOX")
        TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
    end)
    rejoin.Size = UDim2.new(0, 160, 0, 24)

    local graphicsHeader = section:Clone()
    graphicsHeader.Text = "Performance Settings"
    graphicsHeader.Parent = page

    local graphicsModes = { "Super low", "Low", "Default", "Extremely high" }
    local index = 3
    local gBtn = self:CreateButton(page, "Graphics: Default", function()
        index = index + 1
        if index > #graphicsModes then index = 1 end
        local mode = graphicsModes[index]
        gBtn.Text = "Graphics: " .. mode
        self.Runtime.GraphicsMode = mode
        self:Log("INFO", "Graphics mode set to " .. mode, "ROBLOX")
    end)
    gBtn.Size = UDim2.new(0, 220, 0, 24)

    self:CreateCheckbox(page, "Streaming Optimizations", "StreamingOptimizations")
    self:CreateCheckbox(page, "Background Survival Mode", "BackgroundSurvival")

    local afkHeader = section:Clone()
    afkHeader.Text = "AFK Settings"
    afkHeader.Parent = page

    self:CreateCheckbox(page, "Anti-AFK (10s SPACE loop)", "AntiAFK")
    self:CreateCheckbox(page, "Watchdog (heartbeat watcher)", "Watchdog")
    self:CreateCheckbox(page, "Disable 3D Rendering", "Disable3D")
    self:CreateCheckbox(page, "AFK Camera", "AFKCamera")

    self:CreateSlider(page, "FPS Cap", 10, 240, "FPSCap")
    self:CreateSlider(page, "Memory Guard GB", 1, 32, "MemoryGuardGB")

    local memModeBtn = self:CreateButton(page, "Memory Guard: Off", function()
        local cycle = { "Off", "AutoRejoin", "AutoQuit" }
        local idx = table.find(cycle, self.Runtime.MemoryGuard) or 1
        idx = (idx % #cycle) + 1
        self.Runtime.MemoryGuard = cycle[idx]
        memModeBtn.Text = "Memory Guard: " .. self.Runtime.MemoryGuard
        self:SaveUnifiedConfig()
    end)
    memModeBtn.Size = UDim2.new(0, 220, 0, 24)

    local statsWindow = self:CreateFloatingWindow("Memory Stats", false, UDim2.new(0, 240, 0, 84))
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(1, -6, 1, -6)
    statsLabel.Position = UDim2.new(0, 3, 0, 3)
    statsLabel.BackgroundTransparency = 1
    statsLabel.TextXAlignment = Enum.TextXAlignment.Left
    statsLabel.TextYAlignment = Enum.TextYAlignment.Top
    statsLabel.Font = Enum.Font.Code
    statsLabel.TextSize = 14
    statsLabel.TextColor3 = self.Theme.Text
    statsLabel.Text = "Memory stats loading..."
    statsLabel.Parent = statsWindow.Body
    self:_bindTheme(statsLabel, "TextColor3", "Text")

    self:_track(RunService.Heartbeat:Connect(function(dt)
        if self.Destroyed then return end

        -- FPS counter update in title
        if self.Runtime.FPSCounter and self.TitleLabel then
            local fps = math.floor(1 / math.max(dt, 0.001))
            self.TitleLabel.Text = string.format("Meerly UI95 | %d FPS", fps)
        elseif self.TitleLabel then
            self.TitleLabel.Text = "Meerly UI95"
        end

        -- Memory stats floating UI
        local mb = Stats:GetTotalMemoryUsageMb()
        local luaMb = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Script)
        statsLabel.Text = string.format("LUA: %.2f MB\nTotal: %.2f MB\nGuard: %s @ %.1f GB", luaMb, mb, self.Runtime.MemoryGuard, self.Runtime.MemoryGuardGB)

        -- Memory guard logic
        if self.Runtime.MemoryGuard ~= "Off" then
            local gb = mb / 1024
            if gb >= self.Runtime.MemoryGuardGB then
                if self.Runtime.MemoryGuard == "AutoRejoin" then
                    self:Log("ERROR", "Memory guard triggered rejoin.", "GUARD")
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                elseif self.Runtime.MemoryGuard == "AutoQuit" then
                    self:Log("ERROR", "Memory guard triggered kick.", "GUARD")
                    LocalPlayer:Kick("Memory guard threshold reached")
                end
            end
        end
    end))

    self:_track(RunService.Stepped:Connect(function()
        if self.Destroyed then return end
        if self.Runtime.AntiAFK then
            if math.floor(os.clock() * 10) % 100 == 0 then
                safeCall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
            end
        end
    end))
end

function UI95:CreateMainUI()
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "MeerlyUI95"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.ScreenGui.Parent = PlayerGui

    self.BlurEffect = Instance.new("BlurEffect")
    self.BlurEffect.Size = self.Runtime.BlurAmount
    self.BlurEffect.Parent = Lighting

    self.Root = Instance.new("Frame")
    self.Root.Size = UDim2.new(0, 680, 0, 480)
    self.Root.Position = UDim2.new(0.5, -340, 0.5, -240)
    self.Root.BackgroundColor3 = self.Theme.Background
    self.Root.BorderColor3 = self.Theme.Border
    self.Root.Parent = self.ScreenGui

    self:_bindTheme(self.Root, "BackgroundColor3", "Background")
    self:_bindTheme(self.Root, "BorderColor3", "Border")

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, -4, 0, 24)
    titleBar.Position = UDim2.new(0, 2, 0, 2)
    titleBar.BackgroundColor3 = self.Theme.Accent
    titleBar.BorderColor3 = self.Theme.Border
    titleBar.Parent = self.Root

    self:_bindTheme(titleBar, "BackgroundColor3", "Accent")
    self:_bindTheme(titleBar, "BorderColor3", "Border")

    self.TitleLabel = Instance.new("TextLabel")
    self.TitleLabel.Size = UDim2.new(1, -48, 1, 0)
    self.TitleLabel.Position = UDim2.new(0, 6, 0, 0)
    self.TitleLabel.BackgroundTransparency = 1
    self.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.TitleLabel.Text = "Meerly UI95"
    self.TitleLabel.TextColor3 = rgb(255, 255, 255)
    self.TitleLabel.Font = Enum.Font.ArialBold
    self.TitleLabel.TextSize = 14
    self.TitleLabel.Parent = titleBar

    local killButton = Instance.new("TextButton")
    killButton.Size = UDim2.new(0, 28, 0, 20)
    killButton.Position = UDim2.new(1, -30, 0, 2)
    killButton.Text = "X"
    killButton.Font = Enum.Font.ArialBold
    killButton.TextSize = 14
    killButton.TextColor3 = rgb(255, 255, 255)
    killButton.BackgroundColor3 = rgb(220, 20, 20) -- Always red (theme-independent)
    killButton.BorderColor3 = rgb(0, 0, 0)
    killButton.Parent = titleBar

    self:_track(killButton.MouseButton1Click:Connect(function()
        self:Log("ERROR", "Kill button invoked.", "SYSTEM")
        self:Destroy()
    end))

    self.Taskbar = Instance.new("Frame")
    self.Taskbar.Size = UDim2.new(1, -12, 0, 34)
    self.Taskbar.Position = UDim2.new(0, 6, 1, -40)
    self.Taskbar.BackgroundColor3 = self.Theme.Panel
    self.Taskbar.BorderColor3 = self.Theme.Border
    self.Taskbar.Parent = self.Root

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = self.Taskbar

    self:_bindTheme(self.Taskbar, "BackgroundColor3", "Panel")
    self:_bindTheme(self.Taskbar, "BorderColor3", "Border")

    self:_track(self.Taskbar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:UpdateTaskbarButtonSizing()
    end))

    self:BuildThemePage()
    self:BuildConfigPage()
    self:BuildConsolePage()
    self:BuildRobloxSettingsPage()

    self:ShowPage("Theme")
    self:ApplyTheme(self.Theme)
    self:ApplyRuntimeOptions()

    -- Main hide toggle (default ';')
    self:_track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or self.Destroyed then return end
        if input.KeyCode == self.Options.ToggleKey then
            self:ToggleVisible()
        end
    end))
end

function UI95:BuildKeygate()
    local gate = Instance.new("ScreenGui")
    gate.Name = "MeerlyUI95_Keygate"
    gate.ResetOnSpawn = false
    gate.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 420, 0, 180)
    frame.Position = UDim2.new(0.5, -210, 0.5, -90)
    frame.BackgroundColor3 = rgb(192, 192, 192)
    frame.BorderColor3 = rgb(0, 0, 0)
    frame.Parent = gate

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 26)
    title.BackgroundColor3 = rgb(0, 0, 128)
    title.TextColor3 = rgb(255, 255, 255)
    title.Font = Enum.Font.ArialBold
    title.TextSize = 14
    title.Text = "Meerly UI95 Access"
    title.Parent = frame

    local prompt = Instance.new("TextLabel")
    prompt.Size = UDim2.new(1, -12, 0, 36)
    prompt.Position = UDim2.new(0, 6, 0, 38)
    prompt.BackgroundTransparency = 1
    prompt.TextXAlignment = Enum.TextXAlignment.Left
    prompt.TextYAlignment = Enum.TextYAlignment.Top
    prompt.Font = Enum.Font.Arial
    prompt.TextSize = 14
    prompt.TextColor3 = rgb(0, 0, 0)
    prompt.Text = "Enter key to continue.\nGet key: " .. tostring(self.Options.KeygateLink)
    prompt.Parent = frame

    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1, -12, 0, 24)
    keyBox.Position = UDim2.new(0, 6, 0, 86)
    keyBox.BackgroundColor3 = rgb(255, 255, 255)
    keyBox.BorderColor3 = rgb(0, 0, 0)
    keyBox.TextColor3 = rgb(0, 0, 0)
    keyBox.Font = Enum.Font.Arial
    keyBox.TextSize = 14
    keyBox.PlaceholderText = "Hardcoded key in script (edit Options.KeygateKey)"
    keyBox.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -12, 0, 20)
    status.Position = UDim2.new(0, 6, 0, 112)
    status.BackgroundTransparency = 1
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextColor3 = rgb(200, 0, 0)
    status.Font = Enum.Font.Arial
    status.TextSize = 14
    status.Text = ""
    status.Parent = frame

    local unlock = Instance.new("TextButton")
    unlock.Size = UDim2.new(0, 96, 0, 24)
    unlock.Position = UDim2.new(1, -102, 1, -30)
    unlock.BackgroundColor3 = rgb(192, 192, 192)
    unlock.BorderColor3 = rgb(0, 0, 0)
    unlock.TextColor3 = rgb(0, 0, 0)
    unlock.Font = Enum.Font.ArialBold
    unlock.TextSize = 14
    unlock.Text = "Unlock"
    unlock.Parent = frame

    local resolved = false
    local bind
    bind = unlock.MouseButton1Click:Connect(function()
        if keyBox.Text == tostring(self.Options.KeygateKey) then
            resolved = true
            bind:Disconnect()
            gate:Destroy()
            self:Log("SYSTEM", "Keygate accepted.", "AUTH")
            self:CreateMainUI()
            self.Ready = true
        else
            status.Text = "Invalid key."
        end
    end)

    self:_track(bind)

    task.spawn(function()
        local timeout = os.clock() + 600
        while not resolved and not self.Destroyed and os.clock() < timeout do
            task.wait(0.25)
        end
        if not resolved and gate and gate.Parent and not self.Destroyed then
            status.Text = "Keygate timed out."
        end
    end)
end

function UI95:Build()
    if self.Destroyed then return end

    self.CurrentThemeName = self.CurrentThemeName or self.Options.DefaultTheme
    local preset = self:FindPresetByName(self.CurrentThemeName)
    if preset and preset.Theme then
        self.Theme = deepCopy(preset.Theme)
    end

    self:BuildKeygate()
end

function UI95:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    -- Disconnect signal handlers safely.
    for _, connection in ipairs(self.Connections) do
        safeCall(function() connection:Disconnect() end)
    end
    self.Connections = {}

    -- Attempt to restore runtime states.
    safeCall(function()
        LocalPlayer.CameraMinZoomDistance = self._original.CameraMinZoom
        LocalPlayer.CameraMaxZoomDistance = self._original.CameraMaxZoom
        RunService:Set3dRenderingEnabled(true)
    end)

    -- Remove blur payload.
    if self.BlurEffect and self.BlurEffect.Parent then
        self.BlurEffect:Destroy()
    end

    -- Destroy GUI tree.
    if self.ScreenGui and self.ScreenGui.Parent then
        self.ScreenGui:Destroy()
    end

    self:Log("SYSTEM", "UI destroyed and payloads reversed.", "KILL")
end

return UI95
