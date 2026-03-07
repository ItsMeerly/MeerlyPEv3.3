--[[
    MeerlyWin95UILibrary.lua

    Purpose:
      A reusable, robust LU(A)U UI foundation inspired by the Windows 95 visual style.
      This library is designed for quick GUI assembly and future expansion.

    Design goals addressed:
      - Configurable main hide/show key (default ';').
      - Windows 95 style shell + taskbar icon page switcher.
      - Floating windows with per-window hide behavior.
      - Theme system with 10 presets + swatch previews.
      - Theme page (default) with transparency/blur/settings.
      - Red kill "X" button that always remains red.
      - Unified config store with 5 renameable save slots + color preview.
      - Splash/key-gate prior to full UI load.
      - Color-coded, filterable console with memory-safe capped log lines.
      - "Roblox Settings" page with requested feature controls.

    Notes:
      - Some settings (FPS cap/rejoin/3D rendering) depend on executor capabilities.
      - Every risky operation is wrapped to avoid hard failures.
]]

local MeerlyWin95 = {}
MeerlyWin95.__index = MeerlyWin95

-- // Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

-- // -------------------------------------------------------------------------
-- // Hardcoded keygate constants (easy to manually change)
-- // -------------------------------------------------------------------------
local HARDCODED_KEY = "MEERLY-ACCESS-KEY"
local KEY_LINK = "https://example.com/get-key"

-- // -------------------------------------------------------------------------
-- // Internal shared config storage (unified file-ish table)
-- // -------------------------------------------------------------------------
_G.__MEERLY_UI_CONFIGS = _G.__MEERLY_UI_CONFIGS or {
    activeSlot = 1,
    slots = {
        [1] = { name = "Config 1", data = nil },
        [2] = { name = "Config 2", data = nil },
        [3] = { name = "Config 3", data = nil },
        [4] = { name = "Config 4", data = nil },
        [5] = { name = "Config 5", data = nil },
    }
}

-- // -------------------------------------------------------------------------
-- // Theme definitions (10 presets)
-- // -------------------------------------------------------------------------
local THEMES = {
    {
        name = "Classic95",
        swatches = { Color3.fromRGB(192, 192, 192), Color3.fromRGB(0, 0, 128), Color3.fromRGB(0, 128, 128), Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0) },
        base = {
            shell = Color3.fromRGB(192, 192, 192),
            window = Color3.fromRGB(220, 220, 220),
            panel = Color3.fromRGB(201, 201, 201),
            titleA = Color3.fromRGB(0, 0, 128),
            titleB = Color3.fromRGB(16, 16, 160),
            text = Color3.fromRGB(0, 0, 0),
            subtle = Color3.fromRGB(40, 40, 40),
            bevelLight = Color3.fromRGB(255, 255, 255),
            bevelDark = Color3.fromRGB(90, 90, 90),
            taskbar = Color3.fromRGB(196, 196, 196),
            accent = Color3.fromRGB(0, 0, 160),
        }
    },
    {
        name = "Night95",
        swatches = { Color3.fromRGB(28, 28, 33), Color3.fromRGB(78, 111, 255), Color3.fromRGB(42, 180, 255), Color3.fromRGB(220, 220, 230), Color3.fromRGB(14, 14, 16) },
        base = {
            shell = Color3.fromRGB(28, 28, 33), window = Color3.fromRGB(36, 36, 42), panel = Color3.fromRGB(31, 31, 36),
            titleA = Color3.fromRGB(78, 111, 255), titleB = Color3.fromRGB(42, 180, 255), text = Color3.fromRGB(232, 232, 236), subtle = Color3.fromRGB(170, 170, 180),
            bevelLight = Color3.fromRGB(64, 64, 73), bevelDark = Color3.fromRGB(18, 18, 22), taskbar = Color3.fromRGB(33, 33, 38), accent = Color3.fromRGB(120, 180, 255)
        }
    },
    {
        name = "Forest95",
        swatches = { Color3.fromRGB(35, 52, 40), Color3.fromRGB(77, 117, 68), Color3.fromRGB(163, 208, 118), Color3.fromRGB(235, 241, 230), Color3.fromRGB(20, 30, 20) },
        base = {
            shell = Color3.fromRGB(35, 52, 40), window = Color3.fromRGB(47, 67, 52), panel = Color3.fromRGB(43, 62, 48),
            titleA = Color3.fromRGB(77, 117, 68), titleB = Color3.fromRGB(163, 208, 118), text = Color3.fromRGB(235, 241, 230), subtle = Color3.fromRGB(188, 200, 180),
            bevelLight = Color3.fromRGB(76, 98, 79), bevelDark = Color3.fromRGB(24, 34, 25), taskbar = Color3.fromRGB(42, 64, 47), accent = Color3.fromRGB(163, 208, 118)
        }
    },
    {
        name = "Ruby95",
        swatches = { Color3.fromRGB(58, 28, 35), Color3.fromRGB(163, 43, 82), Color3.fromRGB(244, 103, 141), Color3.fromRGB(246, 233, 236), Color3.fromRGB(28, 12, 17) },
        base = {
            shell = Color3.fromRGB(58, 28, 35), window = Color3.fromRGB(71, 33, 43), panel = Color3.fromRGB(65, 30, 39),
            titleA = Color3.fromRGB(163, 43, 82), titleB = Color3.fromRGB(244, 103, 141), text = Color3.fromRGB(246, 233, 236), subtle = Color3.fromRGB(220, 180, 190),
            bevelLight = Color3.fromRGB(96, 44, 60), bevelDark = Color3.fromRGB(30, 13, 19), taskbar = Color3.fromRGB(64, 29, 38), accent = Color3.fromRGB(244, 103, 141)
        }
    },
    {
        name = "Amber95",
        swatches = { Color3.fromRGB(64, 44, 17), Color3.fromRGB(217, 148, 28), Color3.fromRGB(252, 209, 97), Color3.fromRGB(255, 245, 223), Color3.fromRGB(31, 21, 8) },
        base = {
            shell = Color3.fromRGB(64, 44, 17), window = Color3.fromRGB(80, 55, 22), panel = Color3.fromRGB(73, 50, 20),
            titleA = Color3.fromRGB(217, 148, 28), titleB = Color3.fromRGB(252, 209, 97), text = Color3.fromRGB(255, 245, 223), subtle = Color3.fromRGB(228, 205, 156),
            bevelLight = Color3.fromRGB(103, 75, 33), bevelDark = Color3.fromRGB(29, 20, 7), taskbar = Color3.fromRGB(74, 52, 20), accent = Color3.fromRGB(252, 209, 97)
        }
    },
    {
        name = "Ocean95",
        swatches = { Color3.fromRGB(20, 41, 60), Color3.fromRGB(48, 129, 193), Color3.fromRGB(96, 199, 255), Color3.fromRGB(230, 245, 255), Color3.fromRGB(10, 21, 31) },
        base = {
            shell = Color3.fromRGB(20, 41, 60), window = Color3.fromRGB(26, 52, 74), panel = Color3.fromRGB(24, 47, 68),
            titleA = Color3.fromRGB(48, 129, 193), titleB = Color3.fromRGB(96, 199, 255), text = Color3.fromRGB(230, 245, 255), subtle = Color3.fromRGB(170, 205, 228),
            bevelLight = Color3.fromRGB(44, 70, 92), bevelDark = Color3.fromRGB(12, 25, 37), taskbar = Color3.fromRGB(24, 49, 70), accent = Color3.fromRGB(96, 199, 255)
        }
    },
    {
        name = "Mint95",
        swatches = { Color3.fromRGB(29, 58, 53), Color3.fromRGB(70, 176, 151), Color3.fromRGB(155, 240, 220), Color3.fromRGB(232, 251, 247), Color3.fromRGB(13, 27, 25) },
        base = {
            shell = Color3.fromRGB(29, 58, 53), window = Color3.fromRGB(37, 74, 67), panel = Color3.fromRGB(34, 67, 61),
            titleA = Color3.fromRGB(70, 176, 151), titleB = Color3.fromRGB(155, 240, 220), text = Color3.fromRGB(232, 251, 247), subtle = Color3.fromRGB(183, 223, 214),
            bevelLight = Color3.fromRGB(55, 90, 83), bevelDark = Color3.fromRGB(16, 31, 29), taskbar = Color3.fromRGB(34, 69, 63), accent = Color3.fromRGB(155, 240, 220)
        }
    },
    {
        name = "Violet95",
        swatches = { Color3.fromRGB(40, 31, 67), Color3.fromRGB(122, 91, 212), Color3.fromRGB(191, 166, 255), Color3.fromRGB(241, 236, 255), Color3.fromRGB(18, 14, 32) },
        base = {
            shell = Color3.fromRGB(40, 31, 67), window = Color3.fromRGB(52, 40, 85), panel = Color3.fromRGB(47, 36, 77),
            titleA = Color3.fromRGB(122, 91, 212), titleB = Color3.fromRGB(191, 166, 255), text = Color3.fromRGB(241, 236, 255), subtle = Color3.fromRGB(202, 190, 232),
            bevelLight = Color3.fromRGB(73, 57, 109), bevelDark = Color3.fromRGB(20, 16, 36), taskbar = Color3.fromRGB(49, 38, 82), accent = Color3.fromRGB(191, 166, 255)
        }
    },
    {
        name = "Mono95",
        swatches = { Color3.fromRGB(30, 30, 30), Color3.fromRGB(80, 80, 80), Color3.fromRGB(140, 140, 140), Color3.fromRGB(230, 230, 230), Color3.fromRGB(10, 10, 10) },
        base = {
            shell = Color3.fromRGB(30, 30, 30), window = Color3.fromRGB(39, 39, 39), panel = Color3.fromRGB(35, 35, 35),
            titleA = Color3.fromRGB(80, 80, 80), titleB = Color3.fromRGB(140, 140, 140), text = Color3.fromRGB(230, 230, 230), subtle = Color3.fromRGB(180, 180, 180),
            bevelLight = Color3.fromRGB(63, 63, 63), bevelDark = Color3.fromRGB(12, 12, 12), taskbar = Color3.fromRGB(34, 34, 34), accent = Color3.fromRGB(140, 140, 140)
        }
    },
    {
        name = "Sunset95",
        swatches = { Color3.fromRGB(56, 29, 25), Color3.fromRGB(214, 86, 68), Color3.fromRGB(255, 161, 111), Color3.fromRGB(255, 236, 224), Color3.fromRGB(26, 12, 10) },
        base = {
            shell = Color3.fromRGB(56, 29, 25), window = Color3.fromRGB(72, 36, 31), panel = Color3.fromRGB(65, 33, 28),
            titleA = Color3.fromRGB(214, 86, 68), titleB = Color3.fromRGB(255, 161, 111), text = Color3.fromRGB(255, 236, 224), subtle = Color3.fromRGB(233, 196, 178),
            bevelLight = Color3.fromRGB(96, 52, 43), bevelDark = Color3.fromRGB(29, 14, 12), taskbar = Color3.fromRGB(67, 34, 29), accent = Color3.fromRGB(255, 161, 111)
        }
    },
}

local LEVEL_COLORS = {
    INFO = Color3.fromRGB(170, 215, 255),
    WARN = Color3.fromRGB(255, 210, 120),
    ERROR = Color3.fromRGB(255, 130, 130),
    DEBUG = Color3.fromRGB(190, 255, 190),
    EVENT = Color3.fromRGB(220, 190, 255),
}

local function safeCall(tag, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn(string.format("[MeerlyWin95][%s] %s", tostring(tag), tostring(err)))
    end
    return ok, err
end

local function deepCopy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    local out = {}
    for k, v in pairs(tbl) do
        out[k] = deepCopy(v)
    end
    return out
end

local function make(className, props)
    local inst = Instance.new(className)
    local parent = nil

    for k, v in pairs(props or {}) do
        if k == "Parent" then
            parent = v
        else
            local ok, err = pcall(function()
                inst[k] = v
            end)
            if not ok then
                warn(string.format("[MeerlyWin95][make:%s] Failed property '%s': %s", className, tostring(k), tostring(err)))
            end
        end
    end

    if parent ~= nil then
        local ok, err = pcall(function()
            inst.Parent = parent
        end)
        if not ok then
            warn(string.format("[MeerlyWin95][make:%s] Failed to set Parent: %s", className, tostring(err)))
        end
    end

    return inst
end

-- Generic drag helper used by main shell, console, and floating windows.
-- Keeps the interaction lightweight and reusable.
local function clampFrameToViewport(frame, boundsTarget, padding)
    if not frame or not boundsTarget then
        return
    end

    local inset = padding or 8
    local parentSize = boundsTarget.AbsoluteSize
    local frameSize = frame.AbsoluteSize

    if parentSize.X <= 0 or parentSize.Y <= 0 then
        return
    end

    local maxX = math.max(inset, parentSize.X - frameSize.X - inset)
    local maxY = math.max(inset, parentSize.Y - frameSize.Y - inset)

    local clampedX = math.clamp(frame.Position.X.Offset, inset, maxX)
    local clampedY = math.clamp(frame.Position.Y.Offset, inset, maxY)
    frame.Position = UDim2.fromOffset(clampedX, clampedY)
end

local function makeDraggable(dragHandle, target, boundsTarget)
    local dragging = false
    local dragStart
    local startPos

    local function clampToBounds(pos)
        if not boundsTarget then
            return pos
        end

        local parentSize = boundsTarget.AbsoluteSize
        local targetSize = target.AbsoluteSize
        local x = math.clamp(pos.X.Offset, 0, math.max(0, parentSize.X - targetSize.X))
        local y = math.clamp(pos.Y.Offset, 0, math.max(0, parentSize.Y - targetSize.Y))
        return UDim2.fromOffset(x, y)
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            local nextPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            target.Position = clampToBounds(nextPos)
        end
    end)
end

-- Windows 95-ish bevel border helper.
local function applyBevel(frame, lightColor, darkColor)
    local top = make("Frame", { Parent = frame, BorderSizePixel = 0, BackgroundColor3 = lightColor, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 0), ZIndex = frame.ZIndex + 1 })
    local left = make("Frame", { Parent = frame, BorderSizePixel = 0, BackgroundColor3 = lightColor, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(0, 0), ZIndex = frame.ZIndex + 1 })
    local bottom = make("Frame", { Parent = frame, BorderSizePixel = 0, BackgroundColor3 = darkColor, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), ZIndex = frame.ZIndex + 1 })
    local right = make("Frame", { Parent = frame, BorderSizePixel = 0, BackgroundColor3 = darkColor, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), ZIndex = frame.ZIndex + 1 })
    return { top = top, left = left, bottom = bottom, right = right }
end

function MeerlyWin95.new(options)
    local self = setmetatable({}, MeerlyWin95)

    options = options or {}

    self.settings = {
        title = options.title or "Meerly Win95 UI",
        toggleKey = options.toggleKey or Enum.KeyCode.Semicolon,
        maxConsoleLines = options.maxConsoleLines or 300,
        defaultThemeIndex = options.defaultThemeIndex or 1,
        uiTransparency = 0,
        blurAmount = 0,
        allowBlur = true,
    }

    self.state = {
        alive = true,
        unlocked = false,
        visible = true,
        selectedPage = nil,
        configSlot = _G.__MEERLY_UI_CONFIGS.activeSlot or 1,
        logs = {},
        logFilter = { INFO = true, WARN = true, ERROR = true, DEBUG = true, EVENT = true },
        floatingWindows = {},
        connections = {},
        themeIndex = self.settings.defaultThemeIndex,
        fpsCap = 60,
        antiAfk = false,
        watchdog = false,
        memGuardMode = "Off",
        memGuardGb = 8,
        disable3D = false,
        performanceMode = "Default",
        fxCulling = "Medium",
        streamOptimized = false,
        backgroundSurvival = false,
        zoomUnlock = false,
        fpsCounter = false,
    }

    self.theme = deepCopy(THEMES[self.state.themeIndex].base)

    self:_buildUI()
    self:_buildDefaultPages()
    self:_wireCoreBindings()
    self:_applyTheme()
    self:log("INFO", "UI initialized")
    self:log("EVENT", "Waiting for key-gate unlock")

    return self
end

function MeerlyWin95:_connect(signal, fn)
    local conn = signal:Connect(fn)
    table.insert(self.state.connections, conn)
    return conn
end

function MeerlyWin95:log(level, message)
    if not self.state.alive then
        return
    end
    level = LEVEL_COLORS[level] and level or "INFO"
    local stamp = os.date("%H:%M:%S")
    local entry = string.format("[%s][%s] %s", stamp, level, tostring(message))

    table.insert(self.state.logs, { level = level, text = entry })
    if #self.state.logs > self.settings.maxConsoleLines then
        -- Memory culling policy: keep only newest lines.
        table.remove(self.state.logs, 1)
    end

    self:_renderConsole()
end

function MeerlyWin95:_renderConsole()
    -- Render to embedded console page list when available.
    if self.consoleList then
        for _, child in ipairs(self.consoleList:GetChildren()) do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end

        local shown = 0
        for _, row in ipairs(self.state.logs) do
            if self.state.logFilter[row.level] then
                local line = make("TextLabel", {
                    Parent = self.consoleList,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -8, 0, 18),
                    Font = Enum.Font.Code,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    Text = row.text,
                    TextColor3 = LEVEL_COLORS[row.level] or self.theme.text,
                    ZIndex = 14,
                })
                shown += 1
            end
        end

        if shown == 0 then
            make("TextLabel", {
                Parent = self.consoleList,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -8, 0, 18),
                Font = Enum.Font.Code,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                Text = "(no console entries for current filters)",
                TextColor3 = self.theme.subtle,
                ZIndex = 14,
            })
        end

        self.consoleList.CanvasPosition = Vector2.new(0, math.max(0, self.consoleLayout.AbsoluteContentSize.Y - self.consoleList.AbsoluteSize.Y))
        return
    end

end

function MeerlyWin95:_applyTheme()
    local t = self.theme
    if not t or not self.shell then
        return
    end

    self.shell.BackgroundColor3 = t.shell
    self.window.BackgroundColor3 = t.window
    self.titleBar.BackgroundColor3 = t.titleA
    self.taskbar.BackgroundColor3 = t.taskbar
    self.titleLabel.TextColor3 = t.text

    for _, page in pairs(self.pages) do
        page.BackgroundColor3 = t.panel
    end

    for _, child in ipairs(self.taskbar:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = t.panel
            child.TextColor3 = t.text
        end
    end

    for _, item in ipairs(self.dynamicThemeParts) do
        safeCall("ThemeRefresh", function()
            item.apply(t)
        end)
    end

    self.screenGui.IgnoreGuiInset = false

    if self.settings.allowBlur then
        safeCall("ApplyBlur", function()
            local blur = Lighting:FindFirstChild("MeerlyWin95Blur")
            if not blur then
                blur = Instance.new("BlurEffect")
                blur.Name = "MeerlyWin95Blur"
                blur.Parent = Lighting
            end
            blur.Size = self.settings.blurAmount
        end)
    end
end

function MeerlyWin95:_taskbarResize()
    local host = self.taskbarButtonsHost or self.taskbar
    if not host then
        return
    end

    local buttons = {}
    for _, c in ipairs(host:GetChildren()) do
        if c:IsA("TextButton") and c.Name == "PageButton" then
            table.insert(buttons, c)
        end
    end

    local count = #buttons
    if count == 0 then
        return
    end

    table.sort(buttons, function(a, b)
        return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
    end)

    local maxHeight = 28
    local minHeight = 14
    local gap = 4
    local insetX = 4

    local hostWidth = math.max(0, host.AbsoluteSize.X - (insetX * 2))
    if hostWidth <= 0 and self.taskbar then
        hostWidth = math.max(0, self.taskbar.AbsoluteSize.X - 16)
    end
    if hostWidth <= 0 and self.window then
        hostWidth = math.max(0, self.window.AbsoluteSize.X - 28)
    end

    local hostHeight = math.max(0, host.AbsoluteSize.Y)
    if hostHeight <= 0 and self.taskbar then
        hostHeight = math.max(0, self.taskbar.AbsoluteSize.Y - 6)
    end

    if hostWidth <= 0 or hostHeight <= 0 then
        task.defer(function()
            if self.state and self.state.alive then
                self:_taskbarResize()
            end
        end)
        return
    end

    local totalGap = gap * math.max(0, count - 1)
    local widthEach = math.floor((hostWidth - totalGap) / count)
    local size = math.max(minHeight, math.min(maxHeight, widthEach))

    local totalWidth = (size * count) + totalGap
    local startX = math.floor((hostWidth - totalWidth) / 2) + insetX
    local y = math.max(0, math.floor((hostHeight - size) / 2))

    local x = startX
    for _, b in ipairs(buttons) do
        b.Size = UDim2.fromOffset(size, size)
        b.Position = UDim2.fromOffset(x, y)
        b.TextSize = math.max(10, math.min(18, size - 6))
        x = x + size + gap
    end
end

function MeerlyWin95:_refreshResponsiveLayout()
    if not self.screenGui or not self.shell then
        return
    end

    -- Can be called very early by size-change events; guard partial construction.
    if not self.taskbar then
        return
    end

    local viewport = self.screenGui.AbsoluteSize
    if viewport.X <= 0 or viewport.Y <= 0 then
        return
    end

    local margin = 20
    local shellW = math.clamp(760, 420, math.max(420, viewport.X - margin))
    local shellH = math.clamp(520, 300, math.max(300, viewport.Y - margin))
    self.shell.Size = UDim2.fromOffset(shellW, shellH)

    if not self.state.shellPositionInitialized then
        self.shell.Position = UDim2.fromOffset(math.floor((viewport.X - shellW) / 2), math.floor((viewport.Y - shellH) / 2))
        self.state.shellPositionInitialized = true
    else
        clampFrameToViewport(self.shell, self.screenGui, 8)
    end


    self:_taskbarResize()
end

function MeerlyWin95:_buildUI()
    self.pages = {}
    self.pageOrder = {}
    self.dynamicThemeParts = {}

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local existingGui = playerGui:FindFirstChild("MeerlyWin95Lib")
    if existingGui then
        existingGui:Destroy()
    end

    self.screenGui = make("ScreenGui", {
        Name = "MeerlyWin95Lib",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        Parent = playerGui
    })

    self.shell = make("Frame", {
        Parent = self.screenGui,
        Size = UDim2.fromOffset(760, 520),
        Position = UDim2.fromOffset(20, 20),
        BorderSizePixel = 0,
        BackgroundTransparency = self.settings.uiTransparency,
        ZIndex = 4,
    })
    applyBevel(self.shell, self.theme.bevelLight, self.theme.bevelDark)

    self.window = make("Frame", {
        Parent = self.shell,
        Size = UDim2.new(1, -10, 1, -10),
        Position = UDim2.fromOffset(5, 5),
        BorderSizePixel = 0,
        BackgroundTransparency = self.settings.uiTransparency,
        ClipsDescendants = true,
        ZIndex = 5,
    })
    applyBevel(self.window, self.theme.bevelLight, self.theme.bevelDark)

    self.titleBar = make("Frame", {
        Parent = self.window,
        Size = UDim2.new(1, -8, 0, 30),
        Position = UDim2.fromOffset(4, 4),
        BorderSizePixel = 0,
        ZIndex = 6,
    })

    self.titleLabel = make("TextLabel", {
        Parent = self.titleBar,
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Code,
        TextSize = 16,
        Text = self.settings.title,
        ZIndex = 7,
    })
    makeDraggable(self.titleBar, self.shell, self.screenGui)

    -- Red kill button: always red regardless of selected theme.
    self.killButton = make("TextButton", {
        Parent = self.titleBar,
        Size = UDim2.fromOffset(24, 22),
        Position = UDim2.new(1, -28, 0.5, -11),
        BorderSizePixel = 0,
        Text = "x",
        Font = Enum.Font.Code,
        TextSize = 16,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = Color3.fromRGB(180, 30, 30),
        ZIndex = 8,
    })
    applyBevel(self.killButton, Color3.fromRGB(255, 130, 130), Color3.fromRGB(80, 10, 10))

    self.content = make("Frame", {
        Parent = self.window,
        Size = UDim2.new(1, -8, 1, -74),
        Position = UDim2.fromOffset(4, 36),
        BorderSizePixel = 0,
        BackgroundTransparency = self.settings.uiTransparency,
        ZIndex = 6,
    })

    self.taskbar = make("Frame", {
        Parent = self.window,
        Size = UDim2.new(1, -8, 0, 34),
        Position = UDim2.new(0, 4, 1, -38),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 80,
    })
    applyBevel(self.taskbar, self.theme.bevelLight, self.theme.bevelDark)

    -- Dedicated host rebuilt for taskbar buttons to avoid border/bevel overlap issues.
    self.taskbarButtonsHost = make("Frame", {
        Parent = self.taskbar,
        Size = UDim2.new(1, -8, 1, -6),
        Position = UDim2.fromOffset(4, 3),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ZIndex = 81,
    })

    self:_connect(self.taskbarButtonsHost:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:_taskbarResize()
    end)
    self:_connect(self.taskbar:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:_taskbarResize()
    end)

    -- Keygate splash: blocks access until key is validated.
    self.keyGate = make("Frame", {
        Parent = self.content,
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BorderSizePixel = 0,
        ZIndex = 30,
    })
    applyBevel(self.keyGate, self.theme.bevelLight, self.theme.bevelDark)

    local kgTitle = make("TextLabel", {
        Parent = self.keyGate,
        Text = "Security Gate",
        Font = Enum.Font.Code,
        TextSize = 20,
        Size = UDim2.new(1, -20, 0, 34),
        Position = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 31,
    })

    local kgInfo = make("TextLabel", {
        Parent = self.keyGate,
        Text = "Enter access key to load UI features.\nKey link: " .. KEY_LINK,
        Font = Enum.Font.Code,
        TextSize = 14,
        Size = UDim2.new(1, -20, 0, 60),
        Position = UDim2.fromOffset(10, 48),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 31,
    })

    local keyInput = make("TextBox", {
        Parent = self.keyGate,
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.fromOffset(10, 120),
        Text = "",
        PlaceholderText = "Enter key...",
        Font = Enum.Font.Code,
        TextSize = 14,
        ClearTextOnFocus = false,
        BorderSizePixel = 0,
        ZIndex = 31,
    })
    applyBevel(keyInput, self.theme.bevelLight, self.theme.bevelDark)

    local unlock = make("TextButton", {
        Parent = self.keyGate,
        Text = "Unlock",
        Font = Enum.Font.Code,
        TextSize = 14,
        Size = UDim2.new(0, 120, 0, 30),
        Position = UDim2.fromOffset(10, 160),
        BorderSizePixel = 0,
        ZIndex = 31,
    })
    applyBevel(unlock, self.theme.bevelLight, self.theme.bevelDark)

    local status = make("TextLabel", {
        Parent = self.keyGate,
        Text = "Locked",
        Font = Enum.Font.Code,
        TextSize = 14,
        Size = UDim2.new(1, -20, 0, 26),
        Position = UDim2.fromOffset(10, 198),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 31,
    })

    self:_connect(unlock.MouseButton1Click, function()
        if keyInput.Text == HARDCODED_KEY then
            self.state.unlocked = true
            self.keyGate.Visible = false
            status.Text = "Access granted"
            self:_taskbarResize()
            if self.state.selectedPage then
                self:selectPage(self.state.selectedPage)
            end
            self:log("EVENT", "Keygate unlocked")
        else
            status.Text = "Invalid key"
            self:log("WARN", "Invalid key attempt")
        end
    end)

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            kgTitle.TextColor3 = theme.text
            kgInfo.TextColor3 = theme.subtle
            keyInput.BackgroundColor3 = theme.panel
            keyInput.TextColor3 = theme.text
            keyInput.PlaceholderColor3 = theme.subtle
            unlock.BackgroundColor3 = theme.accent
            unlock.TextColor3 = theme.text
            status.TextColor3 = theme.text
            self.keyGate.BackgroundColor3 = theme.window
        end,
    })

    self:_connect(self.killButton.MouseButton1Click, function()
        self:log("EVENT", "Kill button clicked")
        self:destroy()
    end)

    -- Bind resize handling only after all core widgets exist.
    self:_connect(self.screenGui:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:_refreshResponsiveLayout()
    end)

    self:_refreshResponsiveLayout()
end

function MeerlyWin95:addPage(name, icon)
    if self.pages[name] then
        return self.pages[name]
    end

    local page = make("ScrollingFrame", {
        Parent = self.content,
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        ScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 10,
    })
    -- Ensure page widgets are rendered above the page surface.
    local function elevateDescendantZIndex(guiObj)
        if guiObj:IsA("GuiObject") and guiObj.ZIndex < (page.ZIndex + 1) then
            guiObj.ZIndex = page.ZIndex + 1
        end
    end

    for _, descendant in ipairs(page:GetDescendants()) do
        elevateDescendantZIndex(descendant)
    end
    self:_connect(page.DescendantAdded, elevateDescendantZIndex)

    local pagePadding = make("UIPadding", {
        Parent = page,
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 14),
    })

    local button = make("TextButton", {
        Name = "PageButton",
        Parent = self.taskbarButtonsHost,
        Text = icon or "■",
        Font = Enum.Font.Code,
        TextSize = 18,
        LayoutOrder = #self.pageOrder + 1,
        BorderSizePixel = 0,
        ZIndex = 82,
    })
    applyBevel(button, self.theme.bevelLight, self.theme.bevelDark)

    self:_connect(button.MouseButton1Click, function()
        self:selectPage(name)
    end)

    self.pages[name] = page
    table.insert(self.pageOrder, name)

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            page.BackgroundColor3 = theme.panel
            button.BackgroundColor3 = theme.panel
            button.TextColor3 = theme.text
        end,
    })

    self:_taskbarResize()

    if not self.state.selectedPage then
        self:selectPage(name)
    end

    return page, pagePadding
end

function MeerlyWin95:selectPage(name)
    if not self.pages[name] then
        return
    end
    self.state.selectedPage = name

    for n, p in pairs(self.pages) do
        p.Visible = (n == name)
    end
end

function MeerlyWin95:addFloatingWindow(title, hideWithMain)
    local float = make("Frame", {
        Parent = self.screenGui,
        Size = UDim2.fromOffset(260, 110),
        Position = UDim2.new(1, -280, 0, 60 + (#self.state.floatingWindows * 120)),
        BorderSizePixel = 0,
        ZIndex = 40,
    })
    applyBevel(float, self.theme.bevelLight, self.theme.bevelDark)

    local bar = make("Frame", {
        Parent = float,
        Size = UDim2.new(1, -6, 0, 22),
        Position = UDim2.fromOffset(3, 3),
        BorderSizePixel = 0,
        ZIndex = 41,
    })
    makeDraggable(bar, float, self.screenGui)

    local lbl = make("TextLabel", {
        Parent = bar,
        Text = title or "Floating Window",
        Size = UDim2.new(1, -8, 1, 0),
        Position = UDim2.fromOffset(4, 0),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Code,
        TextSize = 14,
        ZIndex = 42,
    })

    local body = make("TextLabel", {
        Parent = float,
        Text = "Attach custom status widgets here.",
        Size = UDim2.new(1, -10, 1, -34),
        Position = UDim2.fromOffset(5, 28),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Font = Enum.Font.Code,
        TextSize = 13,
        ZIndex = 42,
    })

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            float.BackgroundColor3 = theme.panel
            bar.BackgroundColor3 = theme.titleA
            lbl.TextColor3 = theme.text
            body.TextColor3 = theme.subtle
        end,
    })

    table.insert(self.state.floatingWindows, {
        frame = float,
        hideWithMain = hideWithMain ~= false,
    })

    return float, body
end

function MeerlyWin95:_buildThemePage()
    local page = self:addPage("Theme", "TH")

    local title = make("TextLabel", {
        Parent = page,
        Text = "Theme Manager",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, -16, 0, 26),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local y = 40
    local function addThemeRow(themeDef, index)
        local row = make("Frame", {
            Parent = page,
            Size = UDim2.new(1, -16, 0, 30),
            Position = UDim2.fromOffset(8, y),
            BorderSizePixel = 0,
        })
        applyBevel(row, self.theme.bevelLight, self.theme.bevelDark)

        local selectBtn = make("TextButton", {
            Parent = row,
            Size = UDim2.fromOffset(90, 22),
            Position = UDim2.fromOffset(4, 4),
            BorderSizePixel = 0,
            Text = themeDef.name,
            Font = Enum.Font.Code,
            TextSize = 12,
        })
        applyBevel(selectBtn, self.theme.bevelLight, self.theme.bevelDark)

        self:_connect(selectBtn.MouseButton1Click, function()
            self.state.themeIndex = index
            self.theme = deepCopy(THEMES[index].base)
            self:_applyTheme()
            self:log("EVENT", "Theme changed: " .. themeDef.name)
        end)

        for i, color in ipairs(themeDef.swatches) do
            local sw = make("Frame", {
                Parent = row,
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.fromOffset(100 + ((i - 1) * 20), 7),
                BorderSizePixel = 0,
                BackgroundColor3 = color,
            })
            applyBevel(sw, Color3.fromRGB(255, 255, 255), Color3.fromRGB(35, 35, 35))
        end

        table.insert(self.dynamicThemeParts, {
            apply = function(theme)
                row.BackgroundColor3 = theme.panel
                selectBtn.BackgroundColor3 = theme.window
                selectBtn.TextColor3 = theme.text
            end,
        })

        y = y + 34
    end

    for i, def in ipairs(THEMES) do
        addThemeRow(def, i)
    end

    local transLabel = make("TextLabel", {
        Parent = page,
        Text = "Transparency",
        Font = Enum.Font.Code,
        TextSize = 13,
        Size = UDim2.new(1, -94, 0, 22),
        Position = UDim2.fromOffset(8, y + 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local transValue = make("TextLabel", {
        Parent = page,
        Text = string.format("%.2f", self.settings.uiTransparency),
        Font = Enum.Font.Code,
        TextSize = 13,
        Size = UDim2.fromOffset(70, 22),
        Position = UDim2.new(1, -78, 0, y + 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local transTrack = make("Frame", {
        Parent = page,
        Size = UDim2.new(1, -16, 0, 18),
        Position = UDim2.fromOffset(8, y + 30),
        BorderSizePixel = 0,
    })
    applyBevel(transTrack, self.theme.bevelLight, self.theme.bevelDark)

    local transFill = make("Frame", {
        Parent = transTrack,
        Size = UDim2.new(0, 0, 1, 0),
        BorderSizePixel = 0,
    })

    local transKnob = make("Frame", {
        Parent = transTrack,
        Size = UDim2.fromOffset(8, 18),
        Position = UDim2.fromOffset(0, 0),
        BorderSizePixel = 0,
    })

    local blurLabel = make("TextLabel", {
        Parent = page,
        Text = "Blur",
        Font = Enum.Font.Code,
        TextSize = 13,
        Size = UDim2.new(1, -94, 0, 22),
        Position = UDim2.fromOffset(8, y + 56),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local blurValue = make("TextLabel", {
        Parent = page,
        Text = string.format("%d", self.settings.blurAmount),
        Font = Enum.Font.Code,
        TextSize = 13,
        Size = UDim2.fromOffset(70, 22),
        Position = UDim2.new(1, -78, 0, y + 56),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local blurTrack = make("Frame", {
        Parent = page,
        Size = UDim2.new(1, -16, 0, 18),
        Position = UDim2.fromOffset(8, y + 78),
        BorderSizePixel = 0,
    })
    applyBevel(blurTrack, self.theme.bevelLight, self.theme.bevelDark)

    local blurFill = make("Frame", {
        Parent = blurTrack,
        Size = UDim2.new(0, 0, 1, 0),
        BorderSizePixel = 0,
    })

    local blurKnob = make("Frame", {
        Parent = blurTrack,
        Size = UDim2.fromOffset(8, 18),
        Position = UDim2.fromOffset(0, 0),
        BorderSizePixel = 0,
    })

    local function setTransparencyValue(v)
        self.settings.uiTransparency = math.max(0, math.min(0.5, v))
        local alpha = self.settings.uiTransparency / 0.5
        local width = math.max(1, transTrack.AbsoluteSize.X)
        local knobX = math.floor((width - transKnob.AbsoluteSize.X) * alpha)
        transFill.Size = UDim2.new(alpha, 0, 1, 0)
        transKnob.Position = UDim2.fromOffset(knobX, 0)
        transValue.Text = string.format("%.2f", self.settings.uiTransparency)
        self.shell.BackgroundTransparency = self.settings.uiTransparency
        self.window.BackgroundTransparency = self.settings.uiTransparency
        self.content.BackgroundTransparency = self.settings.uiTransparency
    end

    local function setBlurValue(v)
        self.settings.blurAmount = math.floor(math.max(0, math.min(56, v)) + 0.5)
        local alpha = self.settings.blurAmount / 56
        local width = math.max(1, blurTrack.AbsoluteSize.X)
        local knobX = math.floor((width - blurKnob.AbsoluteSize.X) * alpha)
        blurFill.Size = UDim2.new(alpha, 0, 1, 0)
        blurKnob.Position = UDim2.fromOffset(knobX, 0)
        blurValue.Text = string.format("%d", self.settings.blurAmount)
        self:_applyTheme()
    end

    local function bindSlider(track, setter, minValue, maxValue, eventLabel)
        local dragging = false

        local function applyFromPosition(x)
            local width = math.max(1, track.AbsoluteSize.X)
            local alpha = math.max(0, math.min(1, x / width))
            local value = minValue + (maxValue - minValue) * alpha
            setter(value)
        end

        self:_connect(track.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                local localX = input.Position.X - track.AbsolutePosition.X
                applyFromPosition(localX)
            end
        end)

        self:_connect(track.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    dragging = false
                    self:log("EVENT", eventLabel)
                end
            end
        end)

        self:_connect(UserInputService.InputChanged, function(input)
            if not dragging then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local localX = input.Position.X - track.AbsolutePosition.X
                applyFromPosition(localX)
            end
        end)
    end

    bindSlider(transTrack, setTransparencyValue, 0, 0.5, "Transparency updated")
    bindSlider(blurTrack, setBlurValue, 0, 56, "Blur updated")

    task.defer(function()
        setTransparencyValue(self.settings.uiTransparency)
        setBlurValue(self.settings.blurAmount)
    end)
    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            title.TextColor3 = theme.text
            transLabel.TextColor3 = theme.text
            transValue.TextColor3 = theme.text
            blurLabel.TextColor3 = theme.text
            blurValue.TextColor3 = theme.text
            transTrack.BackgroundColor3 = theme.window
            transFill.BackgroundColor3 = theme.accent
            transKnob.BackgroundColor3 = theme.text
            blurTrack.BackgroundColor3 = theme.window
            blurFill.BackgroundColor3 = theme.accent
            blurKnob.BackgroundColor3 = theme.text
        end,
    })
end

function MeerlyWin95:_snapshotConfig()
    return {
        settings = deepCopy(self.settings),
        state = {
            themeIndex = self.state.themeIndex,
            fpsCap = self.state.fpsCap,
            antiAfk = self.state.antiAfk,
            watchdog = self.state.watchdog,
            memGuardMode = self.state.memGuardMode,
            memGuardGb = self.state.memGuardGb,
            disable3D = self.state.disable3D,
            performanceMode = self.state.performanceMode,
            fxCulling = self.state.fxCulling,
            streamOptimized = self.state.streamOptimized,
            backgroundSurvival = self.state.backgroundSurvival,
            zoomUnlock = self.state.zoomUnlock,
            fpsCounter = self.state.fpsCounter,
        },
        themePreview = THEMES[self.state.themeIndex].swatches[1],
    }
end

function MeerlyWin95:_loadSnapshot(data)
    if type(data) ~= "table" then
        return
    end
    if data.settings then
        for k, v in pairs(data.settings) do
            self.settings[k] = v
        end
    end
    if data.state then
        for k, v in pairs(data.state) do
            self.state[k] = v
        end
    end

    self.theme = deepCopy(THEMES[self.state.themeIndex].base)
    self:_applyTheme()
end

function MeerlyWin95:_buildConfigPage()
    local page = self:addPage("Config", "CF")

    local title = make("TextLabel", {
        Parent = page,
        Text = "Unified Configuration Slots",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, -16, 0, 24),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local y = 36
    for slot = 1, 5 do
        local row = make("Frame", {
            Parent = page,
            Size = UDim2.new(1, -16, 0, 34),
            Position = UDim2.fromOffset(8, y),
            BorderSizePixel = 0,
        })
        applyBevel(row, self.theme.bevelLight, self.theme.bevelDark)

        local nameBox = make("TextBox", {
            Parent = row,
            Text = _G.__MEERLY_UI_CONFIGS.slots[slot].name,
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.fromOffset(140, 24),
            Position = UDim2.fromOffset(4, 5),
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
        })
        applyBevel(nameBox, self.theme.bevelLight, self.theme.bevelDark)

        local preview = make("Frame", {
            Parent = row,
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.fromOffset(150, 8),
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(64, 64, 64),
        })
        applyBevel(preview, Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 20))

        local save = make("TextButton", {
            Parent = row,
            Text = "Save",
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.fromOffset(56, 24),
            Position = UDim2.fromOffset(176, 5),
            BorderSizePixel = 0,
        })
        applyBevel(save, self.theme.bevelLight, self.theme.bevelDark)

        local load = make("TextButton", {
            Parent = row,
            Text = "Load",
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.fromOffset(56, 24),
            Position = UDim2.fromOffset(236, 5),
            BorderSizePixel = 0,
        })
        applyBevel(load, self.theme.bevelLight, self.theme.bevelDark)

        local clear = make("TextButton", {
            Parent = row,
            Text = "Clear",
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.fromOffset(56, 24),
            Position = UDim2.fromOffset(296, 5),
            BorderSizePixel = 0,
        })
        applyBevel(clear, self.theme.bevelLight, self.theme.bevelDark)

        local function refreshPreview()
            local data = _G.__MEERLY_UI_CONFIGS.slots[slot].data
            if data and data.themePreview then
                preview.BackgroundColor3 = data.themePreview
            else
                preview.BackgroundColor3 = Color3.fromRGB(64, 64, 64)
            end
        end

        self:_connect(nameBox.FocusLost, function()
            _G.__MEERLY_UI_CONFIGS.slots[slot].name = nameBox.Text ~= "" and nameBox.Text or ("Config " .. slot)
        end)

        self:_connect(save.MouseButton1Click, function()
            _G.__MEERLY_UI_CONFIGS.activeSlot = slot
            _G.__MEERLY_UI_CONFIGS.slots[slot].name = nameBox.Text ~= "" and nameBox.Text or ("Config " .. slot)
            _G.__MEERLY_UI_CONFIGS.slots[slot].data = self:_snapshotConfig()
            refreshPreview()
            self:log("EVENT", "Saved config slot " .. slot)
        end)

        self:_connect(load.MouseButton1Click, function()
            local data = _G.__MEERLY_UI_CONFIGS.slots[slot].data
            if data then
                _G.__MEERLY_UI_CONFIGS.activeSlot = slot
                self:_loadSnapshot(data)
                self:log("EVENT", "Loaded config slot " .. slot)
            else
                self:log("WARN", "No data in config slot " .. slot)
            end
        end)

        self:_connect(clear.MouseButton1Click, function()
            _G.__MEERLY_UI_CONFIGS.slots[slot].data = nil
            refreshPreview()
            self:log("EVENT", "Cleared config slot " .. slot)
        end)

        refreshPreview()

        table.insert(self.dynamicThemeParts, {
            apply = function(theme)
                row.BackgroundColor3 = theme.panel
                nameBox.BackgroundColor3 = theme.window
                nameBox.TextColor3 = theme.text
                save.BackgroundColor3 = theme.window
                save.TextColor3 = theme.text
                load.BackgroundColor3 = theme.window
                load.TextColor3 = theme.text
                clear.BackgroundColor3 = theme.window
                clear.TextColor3 = theme.text
            end,
        })

        y = y + 38
    end

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            title.TextColor3 = theme.text
        end,
    })
end

function MeerlyWin95:_buildConsolePage()
    local page = self:addPage("Console", "LG")

    local title = make("TextLabel", {
        Parent = page,
        Text = "Console",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, -16, 0, 24),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local x = 8
    local orderedLevels = { "INFO", "WARN", "ERROR", "DEBUG", "EVENT" }
    for _, level in ipairs(orderedLevels) do
        local color = LEVEL_COLORS[level]
        local btn = make("TextButton", {
            Parent = page,
            Text = level,
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.fromOffset(84, 24),
            Position = UDim2.fromOffset(x, 38),
            BorderSizePixel = 0,
            BackgroundColor3 = color,
            TextColor3 = Color3.fromRGB(10, 10, 10),
        })
        applyBevel(btn, Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 40, 40))

        self:_connect(btn.MouseButton1Click, function()
            self.state.logFilter[level] = not self.state.logFilter[level]
            btn.Text = level .. (self.state.logFilter[level] and " ✓" or " ✗")
            btn.BackgroundTransparency = self.state.logFilter[level] and 0 or 0.45
            self:_renderConsole()
        end)

        x = x + 88
    end

    local clear = make("TextButton", {
        Parent = page,
        Text = "Clear Logs",
        Font = Enum.Font.Code,
        TextSize = 13,
        Size = UDim2.fromOffset(110, 24),
        Position = UDim2.fromOffset(8, 70),
        BorderSizePixel = 0,
    })
    applyBevel(clear, self.theme.bevelLight, self.theme.bevelDark)

    self.consoleList = make("ScrollingFrame", {
        Parent = page,
        Size = UDim2.new(1, -16, 1, -110),
        Position = UDim2.fromOffset(8, 100),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ScrollBarThickness = 6,
        ScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 13,
    })
    self.consoleLayout = make("UIListLayout", {
        Parent = self.consoleList,
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    self:_connect(clear.MouseButton1Click, function()
        self.state.logs = {}
        self:_renderConsole()
        self:log("EVENT", "Logs cleared")
    end)

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            title.TextColor3 = theme.text
            clear.BackgroundColor3 = theme.window
            clear.TextColor3 = theme.text
        end,
    })

    self:_renderConsole()
end

function MeerlyWin95:_safeExecutorAction(name, fn)
    local ok, err = pcall(fn)
    if ok then
        self:log("EVENT", name .. " success")
    else
        self:log("WARN", name .. " unsupported/failed: " .. tostring(err))
    end
end

function MeerlyWin95:_buildSettingsPage()
    -- Deprecated by request: keep only Roblox Settings as the Settings page.
end

function MeerlyWin95:_buildPerformancePage()
    local page = self:addPage("Performance", "PF")

    local title = make("TextLabel", {
        Parent = page,
        Text = "Performance Quick Panel",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, -16, 0, 24),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local y = 38
    local function addButton(label, cb)
        local b = make("TextButton", {
            Parent = page,
            Text = label,
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.fromOffset(260, 24),
            Position = UDim2.fromOffset(8, y),
            BorderSizePixel = 0,
        })
        applyBevel(b, self.theme.bevelLight, self.theme.bevelDark)
        self:_connect(b.MouseButton1Click, cb)
        y = y + 28
        table.insert(self.dynamicThemeParts, {
            apply = function(theme)
                b.BackgroundColor3 = theme.window
                b.TextColor3 = theme.text
            end,
        })
    end

    addButton("Graphics: Super Low", function() self.state.performanceMode = "Super Low"; self:log("EVENT", "Graphics mode set: Super Low") end)
    addButton("Graphics: Low", function() self.state.performanceMode = "Low"; self:log("EVENT", "Graphics mode set: Low") end)
    addButton("Graphics: Default", function() self.state.performanceMode = "Default"; self:log("EVENT", "Graphics mode set: Default") end)
    addButton("Graphics: Extremely High", function() self.state.performanceMode = "Extremely High"; self:log("EVENT", "Graphics mode set: Extremely High") end)

    addButton("FX Culling: Extreme", function() self.state.fxCulling = "Extreme"; self:log("EVENT", "FX Culling set: Extreme") end)
    addButton("FX Culling: Strong", function() self.state.fxCulling = "Strong"; self:log("EVENT", "FX Culling set: Strong") end)
    addButton("FX Culling: Medium", function() self.state.fxCulling = "Medium"; self:log("EVENT", "FX Culling set: Medium") end)
    addButton("FX Culling: Low", function() self.state.fxCulling = "Low"; self:log("EVENT", "FX Culling set: Low") end)

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            title.TextColor3 = theme.text
        end,
    })
end

function MeerlyWin95:_buildRobloxSettingsPage()
    local page = self:addPage("Settings", "ST")

    local title = make("TextLabel", {
        Parent = page,
        Text = "Roblox Settings",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, -16, 0, 24),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local y = 38

    local function addSection(sectionTitle)
        local lbl = make("TextLabel", {
            Parent = page,
            Text = sectionTitle,
            Font = Enum.Font.Code,
            TextSize = 14,
            Size = UDim2.new(1, -16, 0, 20),
            Position = UDim2.fromOffset(8, y),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        y = y + 20

        local line = make("Frame", {
            Parent = page,
            Size = UDim2.new(1, -16, 0, 1),
            Position = UDim2.fromOffset(8, y),
            BorderSizePixel = 0,
        })
        y = y + 8

        table.insert(self.dynamicThemeParts, {
            apply = function(theme)
                lbl.TextColor3 = theme.accent
                line.BackgroundColor3 = theme.stroke
            end,
        })
    end

    local function addToggle(label, initial, callback)
        local btn = make("TextButton", {
            Parent = page,
            Text = label .. ": " .. (initial and "ON" or "OFF"),
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.new(1, -16, 0, 24),
            Position = UDim2.fromOffset(8, y),
            BorderSizePixel = 0,
        })
        applyBevel(btn, self.theme.bevelLight, self.theme.bevelDark)
        local state = initial
        self:_connect(btn.MouseButton1Click, function()
            state = not state
            btn.Text = label .. ": " .. (state and "ON" or "OFF")
            callback(state)
        end)
        y = y + 28
        table.insert(self.dynamicThemeParts, {
            apply = function(theme)
                btn.BackgroundColor3 = theme.window
                btn.TextColor3 = theme.text
            end,
        })
        return btn
    end

    local function addButton(label, callback)
        local btn = make("TextButton", {
            Parent = page,
            Text = label,
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.new(1, -16, 0, 24),
            Position = UDim2.fromOffset(8, y),
            BorderSizePixel = 0,
        })
        applyBevel(btn, self.theme.bevelLight, self.theme.bevelDark)
        self:_connect(btn.MouseButton1Click, callback)
        y = y + 28
        table.insert(self.dynamicThemeParts, {
            apply = function(theme)
                btn.BackgroundColor3 = theme.window
                btn.TextColor3 = theme.text
            end,
        })
        return btn
    end

    local function addInput(label, defaultValue, callback)
        local lbl = make("TextLabel", {
            Parent = page,
            Text = label,
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.new(1, -16, 0, 20),
            Position = UDim2.fromOffset(8, y),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        y = y + 20

        local box = make("TextBox", {
            Parent = page,
            Text = tostring(defaultValue),
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.fromOffset(140, 24),
            Position = UDim2.fromOffset(8, y),
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
        })
        applyBevel(box, self.theme.bevelLight, self.theme.bevelDark)

        self:_connect(box.FocusLost, function()
            callback(box.Text)
        end)

        y = y + 30
        table.insert(self.dynamicThemeParts, {
            apply = function(theme)
                lbl.TextColor3 = theme.text
                box.BackgroundColor3 = theme.window
                box.TextColor3 = theme.text
            end,
        })

        return box
    end

    addSection("Quick Settings")
    addToggle("Zoom Unlock", self.state.zoomUnlock, function(v)
        self.state.zoomUnlock = v
        self:_safeExecutorAction("Zoom Unlock", function()
            LocalPlayer.CameraMaxZoomDistance = v and 1000 or 128
        end)
    end)
    addToggle("FPS Counter", self.state.fpsCounter, function(v)
        self.state.fpsCounter = v
        self:log("EVENT", "FPS Counter " .. (v and "enabled" or "disabled"))
    end)
    addButton("Rejoin Server", function()
        self:_safeExecutorAction("Rejoin Server", function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)

    addSection("Performance Settings")
    addButton("Graphics: Super Low", function() self.state.performanceMode = "Super Low"; self:log("EVENT", "Graphics mode set: Super Low") end)
    addButton("Graphics: Low", function() self.state.performanceMode = "Low"; self:log("EVENT", "Graphics mode set: Low") end)
    addButton("Graphics: Default", function() self.state.performanceMode = "Default"; self:log("EVENT", "Graphics mode set: Default") end)
    addButton("Graphics: Extremely High", function() self.state.performanceMode = "Extremely High"; self:log("EVENT", "Graphics mode set: Extremely High") end)
    addButton("FX Culling: Extreme", function() self.state.fxCulling = "Extreme"; self:log("EVENT", "FX Culling set: Extreme") end)
    addButton("FX Culling: Strong", function() self.state.fxCulling = "Strong"; self:log("EVENT", "FX Culling set: Strong") end)
    addButton("FX Culling: Medium", function() self.state.fxCulling = "Medium"; self:log("EVENT", "FX Culling set: Medium") end)
    addButton("FX Culling: Low", function() self.state.fxCulling = "Low"; self:log("EVENT", "FX Culling set: Low") end)
    addToggle("Streaming Optimisations", self.state.streamOptimized, function(v)
        self.state.streamOptimized = v
        self:log("EVENT", "Streaming Optimisations " .. (v and "enabled" or "disabled"))
    end)
    addToggle("Background Survival Mode", self.state.backgroundSurvival, function(v)
        self.state.backgroundSurvival = v
        self:log("EVENT", "Background Survival Mode " .. (v and "enabled" or "disabled"))
    end)

    addSection("AFK Settings")
    addToggle("Anti-AFK (10s space loop)", self.state.antiAfk, function(v)
        self.state.antiAfk = v
        self:log("EVENT", "Anti-AFK " .. (v and "enabled" or "disabled"))
    end)
    addToggle("Watchdog", self.state.watchdog, function(v)
        self.state.watchdog = v
        self:log("EVENT", "Watchdog " .. (v and "enabled" or "disabled"))
    end)
    addInput("FPS Cap (10-240)", self.state.fpsCap, function(text)
        local n = tonumber(text)
        if n then
            self.state.fpsCap = math.clamp(math.floor(n), 10, 240)
            self:_safeExecutorAction("FPS Cap", function()
                if setfpscap then
                    setfpscap(self.state.fpsCap)
                else
                    error("setfpscap unavailable")
                end
            end)
        end
    end)
    addButton("Memory Guard: Off", function() self.state.memGuardMode = "Off"; self:log("EVENT", "Memory Guard Off") end)
    addButton("Memory Guard: AutoRejoin", function() self.state.memGuardMode = "AutoRejoin"; self:log("EVENT", "Memory Guard AutoRejoin") end)
    addButton("Memory Guard: AutoQuit", function() self.state.memGuardMode = "AutoQuit"; self:log("EVENT", "Memory Guard AutoQuit") end)
    addInput("Memory Guard Cap (GB)", self.state.memGuardGb, function(text)
        local n = tonumber(text)
        if n then
            self.state.memGuardGb = math.max(1, n)
            self:log("EVENT", "Memory Guard cap set: " .. self.state.memGuardGb .. " GB")
        end
    end)
    addToggle("Disable 3D Rendering", self.state.disable3D, function(v)
        self.state.disable3D = v
        self:_safeExecutorAction("Disable 3D", function()
            if setRenderingEnabled then
                setRenderingEnabled(not v)
            else
                error("setRenderingEnabled unavailable")
            end
        end)
    end)
    addButton("AFK Camera (move away)", function()
        self:_safeExecutorAction("AFK Camera", function()
            local cam = workspace.CurrentCamera
            cam.CFrame = CFrame.new(0, 100000, 0)
        end)
    end)

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            title.TextColor3 = theme.text
        end,
    })
end

function MeerlyWin95:_buildDefaultPages()
    self:_buildThemePage()
    self:_buildConfigPage()
    self:_buildConsolePage()
    self:_buildRobloxSettingsPage()

    -- Memory stats floating UI (does NOT hide with main by default as requested).
    local memoryWindow, memoryBody = self:addFloatingWindow("Memory Stats", false)
    memoryWindow.Size = UDim2.fromOffset(260, 88)

    self:_connect(RunService.Heartbeat, function()
        if not self.state.alive then
            return
        end
        local totalMb = 0
        safeCall("TotalMem", function()
            totalMb = Stats:GetTotalMemoryUsageMb()
        end)
        local luaMb = collectgarbage("count") / 1024
        memoryBody.Text = string.format("Lua: %.2f MB\nTotal: %.2f MB", luaMb, totalMb)

        local totalGb = totalMb / 1024
        if self.state.memGuardMode ~= "Off" and totalGb >= self.state.memGuardGb then
            self:log("ERROR", string.format("Memory guard threshold exceeded %.2f/%.2f GB", totalGb, self.state.memGuardGb))
            if self.state.memGuardMode == "AutoRejoin" then
                self:_safeExecutorAction("MemoryGuard AutoRejoin", function()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end)
            elseif self.state.memGuardMode == "AutoQuit" then
                self:_safeExecutorAction("MemoryGuard AutoQuit", function()
                    LocalPlayer:Kick("Memory guard triggered")
                end)
            end
        end
    end)

    self:selectPage("Theme")
    self:_taskbarResize()
end

function MeerlyWin95:_wireCoreBindings()
    -- Toggle key: hide/show shell + any floating windows configured to hide.
    self:_connect(UserInputService.InputBegan, function(input, gp)
        if gp then
            return
        end

        if input.KeyCode == self.settings.toggleKey then
            self.state.visible = not self.state.visible
            self.shell.Visible = self.state.visible

            for _, fw in ipairs(self.state.floatingWindows) do
                if fw.hideWithMain then
                    fw.frame.Visible = self.state.visible
                end
            end

            if self.state.visible then
                self:_refreshResponsiveLayout()
            end
            self:log("EVENT", "Main UI " .. (self.state.visible and "shown" or "hidden"))
        end
    end)

    -- Anti-AFK loop, heartbeat watchdog, and periodic status logging.
    self:_connect(RunService.Heartbeat, function(dt)
        if not self.state.alive then
            return
        end

        if self.state.watchdog and dt > 1.0 then
            self:log("WARN", string.format("Watchdog heartbeat lag: %.3f", dt))
        end
    end)

    task.spawn(function()
        while self.state.alive do
            task.wait(10)
            if self.state.antiAfk then
                self:_safeExecutorAction("Anti-AFK pulse", function()
                    local vim = game:GetService("VirtualInputManager")
                    vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.05)
                    vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
            end
        end
    end)
end

function MeerlyWin95:getUnifiedConfig()
    return _G.__MEERLY_UI_CONFIGS
end

function MeerlyWin95:destroy()
    if not self.state.alive then
        return
    end

    self.state.alive = false

    -- Revert payloads / effects best effort.
    safeCall("BlurCleanup", function()
        local blur = Lighting:FindFirstChild("MeerlyWin95Blur")
        if blur then
            blur:Destroy()
        end
    end)

    safeCall("FPSReset", function()
        if setfpscap then
            setfpscap(0)
        end
    end)

    for _, conn in ipairs(self.state.connections) do
        safeCall("Disconnect", function()
            conn:Disconnect()
        end)
    end
    self.state.connections = {}

    safeCall("GuiDestroy", function()
        self.screenGui:Destroy()
    end)

    self:log("EVENT", "UI destroyed")
end

return MeerlyWin95
