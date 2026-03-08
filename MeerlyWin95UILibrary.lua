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
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

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

_G.__MEERLY_UI_RUNTIME_STATS = _G.__MEERLY_UI_RUNTIME_STATS or {
    totalAccumulatedSeconds = 0,
    activeInstances = 0,
    sharedStartUnix = nil,
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

local CLICKER_UPGRADES = {
    { id = "Tap", name = "Tap Training", kind = "clickFlat", value = 1, baseCost = 15, growth = 1.22 },
    { id = "Gen", name = "Generator", kind = "passiveFlat", value = 1, baseCost = 40, growth = 1.28 },
    { id = "Over", name = "Overclock", kind = "clickMult", value = 0.12, baseCost = 110, growth = 1.42 },
    { id = "Auto", name = "Automation", kind = "passiveMult", value = 0.14, baseCost = 170, growth = 1.48 },
    { id = "Crit", name = "Crit Routine", kind = "clickMult", value = 0.06, baseCost = 260, growth = 1.36 },
    { id = "Core", name = "Power Core", kind = "passiveMult", value = 0.07, baseCost = 320, growth = 1.38 },
    { id = "Drip", name = "Drip Feed", kind = "passiveFlat", value = 3, baseCost = 520, growth = 1.33 },
    { id = "Grip", name = "Grip Strength", kind = "clickFlat", value = 5, baseCost = 740, growth = 1.31 },
}

local ACHIEVEMENT_TIERS = {
    { name = "Master", color = Color3.fromRGB(255, 120, 220) },
    { name = "Platinum", color = Color3.fromRGB(190, 255, 220) },
    { name = "Diamond", color = Color3.fromRGB(110, 220, 255) },
    { name = "Gold", color = Color3.fromRGB(235, 198, 64) },
    { name = "Silver", color = Color3.fromRGB(170, 170, 178) },
    { name = "Bronze", color = Color3.fromRGB(184, 115, 51) },
    { name = "None", color = Color3.fromRGB(96, 96, 108) },
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

local function formatDurationHM(totalSeconds)
    totalSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
    local h = math.floor(totalSeconds / 3600)
    local m = math.floor((totalSeconds % 3600) / 60)
    return string.format("%dh %02dm", h, m)
end


local function safeWriteFile(path, content)
    if type(writefile) == "function" then
        return pcall(function()
            writefile(path, content)
        end)
    end
    return false, "writefile unavailable"
end

local function safeReadFile(path)
    if type(readfile) == "function" then
        local ok, data = pcall(function()
            return readfile(path)
        end)
        return ok, data
    end
    return false, "readfile unavailable"
end

local function getTierByThreshold(value, bronze, silver, gold, diamond, platinum, master)
    value = tonumber(value) or 0
    if master and value >= master then return "Master" end
    if platinum and value >= platinum then return "Platinum" end
    if diamond and value >= diamond then return "Diamond" end
    if gold and value >= gold then return "Gold" end
    if silver and value >= silver then return "Silver" end
    if bronze and value >= bronze then return "Bronze" end
    return "None"
end

local function getTierColorByName(name)
    for _, tier in ipairs(ACHIEVEMENT_TIERS) do
        if tier.name == name then
            return tier.color
        end
    end
    return ACHIEVEMENT_TIERS[#ACHIEVEMENT_TIERS].color
end

local function clickerUpgradeCost(def, level)
    return math.max(1, math.floor((def.baseCost * (def.growth ^ level)) + 0.5))
end

local function getExecutorGlobal(name)
    local value = rawget(_G, name)
    if value ~= nil then
        return value
    end
    if getgenv then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            return env[name]
        end
    end
    return nil
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
        sessionStartClock = os.clock(),
        statsProviders = {},
        afkConnection = nil,
        clickerHighScoreFile = "clicker_highscore.txt",
        clickerStateFile = "clicker_state.txt",
        clickerStatsFile = "statistics_data.json",
        clickerAutosaveSec = 600,
        clickerLastSave = 0,
        clickerRunning = false,
        clickerScore = 0,
        clickerHighScore = 0,
        clickPower = 1,
        passiveIncomePerSec = 0,
        clickerPassiveCarry = 0,
        clickerShapeVertices = 3,
        clickerShapeCycle = 0,
        clickerShapeProgress = 0,
        clickerShapeMilestone = 25,
        totalClicksOverTime = 0,
        clickerUpgradeLevels = { Tap = 0, Gen = 0, Over = 0, Auto = 0, Crit = 0, Core = 0, Drip = 0, Grip = 0 },
        statisticsData = {
            longestSessionSeconds = 0,
            totalSkillActivations = 0,
            clickerHighScore = 0,
            totalClicksOverTime = 0,
            sessionActive = false,
            sessionStartTime = 0,
            lastSessionReason = "",
        },
        macroFilename = "macro.json",
        macroEvents = {},
        macroRecording = false,
        macroPlaying = false,
        macroLoopEnabled = false,
        macroRecordConnection = nil,
        macroRecordEndConnection = nil,
    }

    self.theme = deepCopy(THEMES[self.state.themeIndex].base)

    self:_buildUI()
    self:_initializeClickerState()
    self:_buildDefaultPages()
    self:_wireCoreBindings()
    self:_applyTheme()
    self:_setupRuntimeStatistics()
    self:_initializeRobloxSettingsRuntime()
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
        ScrollBarInset = Enum.ScrollBarInset.Always,
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
        PaddingRight = UDim.new(0, 20),
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
        Size = UDim2.new(1, -24, 0, 26),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local y = 40
    local function addThemeRow(themeDef, index)
        local row = make("Frame", {
            Parent = page,
            Size = UDim2.new(1, -24, 0, 30),
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
        Size = UDim2.new(1, -24, 0, 18),
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
        Size = UDim2.new(1, -24, 0, 18),
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
            clickerRunning = self.state.clickerRunning,
            totalClicksOverTime = self.state.totalClicksOverTime,
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
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local y = 36
    for slot = 1, 5 do
        local row = make("Frame", {
            Parent = page,
            Size = UDim2.new(1, -24, 0, 34),
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


function MeerlyWin95:_recalcClickerStats()
    local clickFlat = 1
    local passiveFlat = 0
    local clickMult = 1
    local passiveMult = 1

    for _, def in ipairs(CLICKER_UPGRADES) do
        local lv = self.state.clickerUpgradeLevels[def.id] or 0
        if lv > 0 then
            if def.kind == "clickFlat" then
                clickFlat += (def.value * lv)
            elseif def.kind == "passiveFlat" then
                passiveFlat += (def.value * lv)
            elseif def.kind == "clickMult" then
                clickMult *= (1 + (def.value * lv))
            elseif def.kind == "passiveMult" then
                passiveMult *= (1 + (def.value * lv))
            end
        end
    end

    self.state.clickPower = math.max(1, math.floor(clickFlat * clickMult + 0.5))
    self.state.passiveIncomePerSec = math.max(0, math.floor(passiveFlat * passiveMult + 0.5))
end

function MeerlyWin95:_addClickerScore(amount, isManualClick)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then
        return
    end

    self.state.clickerScore += amount
    if self.state.clickerScore > self.state.clickerHighScore then
        self.state.clickerHighScore = self.state.clickerScore
    end

    if isManualClick then
        self.state.totalClicksOverTime += amount
    end

    self.state.clickerShapeProgress += amount
    while self.state.clickerShapeProgress >= self.state.clickerShapeMilestone do
        self.state.clickerShapeProgress -= self.state.clickerShapeMilestone
        self.state.clickerShapeVertices += 1
        if self.state.clickerShapeVertices > 9 then
            self.state.clickerShapeVertices = 3
            self.state.clickerShapeCycle += 1
        end
        self.state.clickerShapeMilestone = math.floor((self.state.clickerShapeMilestone * 1.35) + 5)
    end
end

function MeerlyWin95:_encodeClickerUpgrades()
    local parts = table.create(#CLICKER_UPGRADES)
    for _, def in ipairs(CLICKER_UPGRADES) do
        parts[#parts + 1] = string.format("%s:%d", def.id, self.state.clickerUpgradeLevels[def.id] or 0)
    end
    return table.concat(parts, ";")
end

function MeerlyWin95:_saveStatistics()
    local payload = HttpService:JSONEncode(self.state.statisticsData)
    local ok = safeWriteFile(self.state.clickerStatsFile, payload)
    return ok
end

function MeerlyWin95:_loadStatistics()
    local okRead, raw = safeReadFile(self.state.clickerStatsFile)
    local data = self.state.statisticsData
    if okRead and type(raw) == "string" and #raw > 0 then
        local okDecode, parsed = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if okDecode and type(parsed) == "table" then
            data.longestSessionSeconds = math.max(0, math.floor(tonumber(parsed.longestSessionSeconds) or 0))
            data.totalSkillActivations = math.max(0, math.floor(tonumber(parsed.totalSkillActivations) or 0))
            data.clickerHighScore = math.max(0, math.floor(tonumber(parsed.clickerHighScore) or 0))
            data.totalClicksOverTime = math.max(0, math.floor(tonumber(parsed.totalClicksOverTime) or 0))
            data.sessionActive = parsed.sessionActive == true
            data.sessionStartTime = math.max(0, math.floor(tonumber(parsed.sessionStartTime) or 0))
            data.lastSessionReason = tostring(parsed.lastSessionReason or "")
        end
    end

    if data.sessionActive and data.sessionStartTime > 0 then
        local recoveredSeconds = math.max(0, os.time() - data.sessionStartTime)
        if recoveredSeconds > data.longestSessionSeconds then
            data.longestSessionSeconds = recoveredSeconds
        end
    end

    data.sessionActive = true
    data.sessionStartTime = os.time()
    data.lastSessionReason = "running"
end

function MeerlyWin95:_saveClickerState(force)
    if not force and (os.clock() - self.state.clickerLastSave) < self.state.clickerAutosaveSec then
        return
    end
    self.state.clickerLastSave = os.clock()

    local payload = string.format(
        "%d|%s|%d|%d|%d|%d",
        math.floor(self.state.clickerScore),
        self:_encodeClickerUpgrades(),
        math.floor(self.state.clickerShapeVertices),
        math.floor(self.state.clickerShapeCycle),
        math.floor(self.state.clickerShapeProgress),
        math.floor(self.state.clickerShapeMilestone)
    )
    safeWriteFile(self.state.clickerStateFile, payload)
    safeWriteFile(self.state.clickerHighScoreFile, tostring(math.floor(self.state.clickerHighScore)))

    if self.state.clickerHighScore > self.state.statisticsData.clickerHighScore then
        self.state.statisticsData.clickerHighScore = self.state.clickerHighScore
    end
    self.state.statisticsData.totalClicksOverTime = math.max(self.state.statisticsData.totalClicksOverTime or 0, self.state.totalClicksOverTime)
    self:_saveStatistics()
end

function MeerlyWin95:_loadClickerState()
    local okRead, raw = safeReadFile(self.state.clickerHighScoreFile)
    if okRead then
        local val = tonumber(raw)
        if val then
            self.state.clickerHighScore = math.max(0, math.floor(val))
        end
    end

    local okState, rawState = safeReadFile(self.state.clickerStateFile)
    if okState and type(rawState) == "string" then
        local scorePart, upgradesPart, vPart, cPart, pPart, mPart = rawState:match("^(%-?%d+)|([^|]+)|(%-?%d+)|(%-?%d+)|(%-?%d+)|(%-?%d+)$")
        if not scorePart then
            scorePart, upgradesPart = rawState:match("^(%-?%d+)|(.+)$")
        end

        local parsedScore = tonumber(scorePart)
        if parsedScore then
            self.state.clickerScore = math.max(0, math.floor(parsedScore))
        end

        if type(upgradesPart) == "string" then
            for chunk in string.gmatch(upgradesPart, "[^;]+") do
                local id, lv = chunk:match("^(%a+):(%-?%d+)$")
                if id and lv and self.state.clickerUpgradeLevels[id] ~= nil then
                    self.state.clickerUpgradeLevels[id] = math.max(0, math.floor(tonumber(lv) or 0))
                end
            end
        end

        if vPart and cPart and pPart and mPart then
            self.state.clickerShapeVertices = math.clamp(math.floor(tonumber(vPart) or 3), 3, 9)
            self.state.clickerShapeCycle = math.max(0, math.floor(tonumber(cPart) or 0))
            self.state.clickerShapeProgress = math.max(0, math.floor(tonumber(pPart) or 0))
            self.state.clickerShapeMilestone = math.max(25, math.floor(tonumber(mPart) or 25))
            if self.state.clickerShapeProgress >= self.state.clickerShapeMilestone then
                self.state.clickerShapeProgress = self.state.clickerShapeProgress % self.state.clickerShapeMilestone
            end
        end

        if self.state.clickerScore > self.state.clickerHighScore then
            self.state.clickerHighScore = self.state.clickerScore
        end
    end

    self.state.clickerPassiveCarry = 0
    self:_recalcClickerStats()

    if self.state.clickerHighScore > self.state.statisticsData.clickerHighScore then
        self.state.statisticsData.clickerHighScore = self.state.clickerHighScore
    end
    self.state.totalClicksOverTime = math.max(self.state.totalClicksOverTime or 0, self.state.statisticsData.totalClicksOverTime or 0)
end

function MeerlyWin95:_initializeClickerState()
    self:_loadStatistics()
    self:_loadClickerState()
end

function MeerlyWin95:_finalizeSessionStatistics(reason)
    local elapsed = math.max(0, math.floor(os.clock() - (self.state.sessionStartClock or os.clock())))
    local data = self.state.statisticsData
    if elapsed > data.longestSessionSeconds then
        data.longestSessionSeconds = elapsed
    end
    if self.state.clickerHighScore > data.clickerHighScore then
        data.clickerHighScore = self.state.clickerHighScore
    end
    data.totalClicksOverTime = math.max(data.totalClicksOverTime or 0, self.state.totalClicksOverTime or 0)
    data.sessionActive = false
    data.lastSessionReason = tostring(reason or "session_end")
    self:_saveStatistics()
end

function MeerlyWin95:_buildClickerPage()
    local page = self:addPage("Clicker", "CK")

    local title = make("TextLabel", {
        Parent = page,
        Text = "AFK Mini Clicker",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local toggle = make("TextButton", {
        Parent = page,
        Text = "Mini Game: OFF",
        Font = Enum.Font.Code,
        TextSize = 12,
        Size = UDim2.fromOffset(180, 24),
        Position = UDim2.fromOffset(8, 36),
        BorderSizePixel = 0,
    })
    applyBevel(toggle, self.theme.bevelLight, self.theme.bevelDark)

    local status = make("TextLabel", {
        Parent = page,
        Text = "",
        Font = Enum.Font.Code,
        TextSize = 12,
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.fromOffset(8, 64),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    local upgradesHost = make("ScrollingFrame", {
        Parent = page,
        Size = UDim2.new(1, -24, 1, -188),
        Position = UDim2.fromOffset(8, 104),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ScrollBarThickness = 6,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    })

    local upgradeLayout = make("UIListLayout", {
        Parent = upgradesHost,
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    })

    local footer = make("Frame", {
        Parent = page,
        Size = UDim2.new(1, -24, 0, 68),
        Position = UDim2.new(0, 8, 1, -76),
        BorderSizePixel = 0,
        BackgroundColor3 = self.theme.panel,
    })
    applyBevel(footer, self.theme.bevelLight, self.theme.bevelDark)

    local clickBtn = make("TextButton", {
        Parent = footer,
        Text = "Click",
        Font = Enum.Font.Code,
        TextSize = 12,
        Size = UDim2.fromOffset(90, 24),
        Position = UDim2.fromOffset(8, 8),
        BorderSizePixel = 0,
    })
    applyBevel(clickBtn, self.theme.bevelLight, self.theme.bevelDark)

    local resetBtn = make("TextButton", {
        Parent = footer,
        Text = "Reset",
        Font = Enum.Font.Code,
        TextSize = 12,
        Size = UDim2.fromOffset(90, 24),
        Position = UDim2.fromOffset(106, 8),
        BorderSizePixel = 0,
    })
    applyBevel(resetBtn, self.theme.bevelLight, self.theme.bevelDark)

    local saveBtn = make("TextButton", {
        Parent = footer,
        Text = "Save",
        Font = Enum.Font.Code,
        TextSize = 12,
        Size = UDim2.fromOffset(90, 24),
        Position = UDim2.fromOffset(204, 8),
        BorderSizePixel = 0,
    })
    applyBevel(saveBtn, self.theme.bevelLight, self.theme.bevelDark)

    local footerInfo = make("TextLabel", {
        Parent = footer,
        Text = "",
        Font = Enum.Font.Code,
        TextSize = 11,
        Size = UDim2.new(1, -12, 0, 20),
        Position = UDim2.fromOffset(8, 40),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local upgradeRows = {}
    local function refresh()
        toggle.Text = "Mini Game: " .. (self.state.clickerRunning and "ON" or "OFF")
        status.Text = string.format(
            "Score: %d | High: %d\nClick Power: %d | Passive: %d/s | Total Clicks Over Time: %d",
            self.state.clickerScore,
            self.state.clickerHighScore,
            self.state.clickPower,
            self.state.passiveIncomePerSec,
            self.state.totalClicksOverTime
        )
        footerInfo.Text = string.format("Shape: %d-gon | Cycle: %d", self.state.clickerShapeVertices, self.state.clickerShapeCycle)

        for _, row in ipairs(upgradeRows) do
            local lv = self.state.clickerUpgradeLevels[row.def.id] or 0
            local cost = clickerUpgradeCost(row.def, lv)
            row.button.Text = string.format("%s | Lv %d | Cost %d", row.def.name, lv, cost)
        end
    end

    for _, def in ipairs(CLICKER_UPGRADES) do
        local btn = make("TextButton", {
            Parent = upgradesHost,
            Text = def.name,
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.new(1, -8, 0, 24),
            BorderSizePixel = 0,
            BackgroundColor3 = self.theme.window,
        })
        applyBevel(btn, self.theme.bevelLight, self.theme.bevelDark)
        table.insert(upgradeRows, { def = def, button = btn })
        self:_connect(btn.MouseButton1Click, function()
            if not self.state.clickerRunning then
                return
            end
            local level = self.state.clickerUpgradeLevels[def.id] or 0
            local cost = clickerUpgradeCost(def, level)
            if self.state.clickerScore < cost then
                self:log("EVENT", def.name .. " requires " .. tostring(cost))
                return
            end
            self.state.clickerScore -= cost
            self.state.clickerUpgradeLevels[def.id] = level + 1
            self:_recalcClickerStats()
            refresh()
        end)
    end

    self:_connect(toggle.MouseButton1Click, function()
        self.state.clickerRunning = not self.state.clickerRunning
        refresh()
    end)

    self:_connect(clickBtn.MouseButton1Click, function()
        if not self.state.clickerRunning then
            return
        end
        self:_addClickerScore(self.state.clickPower, true)
        refresh()
    end)

    self:_connect(resetBtn.MouseButton1Click, function()
        self.state.clickerScore = 0
        self.state.clickerUpgradeLevels = { Tap = 0, Gen = 0, Over = 0, Auto = 0, Crit = 0, Core = 0, Drip = 0, Grip = 0 }
        self.state.clickerShapeVertices = 3
        self.state.clickerShapeCycle = 0
        self.state.clickerShapeProgress = 0
        self.state.clickerShapeMilestone = 25
        self.state.clickerPassiveCarry = 0
        self:_recalcClickerStats()
        refresh()
    end)

    self:_connect(saveBtn.MouseButton1Click, function()
        self:_saveClickerState(true)
        self:log("EVENT", "Clicker state saved")
    end)

    self:_connect(RunService.Heartbeat, function(dt)
        if not self.state.alive or not self.state.clickerRunning then
            return
        end
        local add = self.state.passiveIncomePerSec * dt
        self.state.clickerPassiveCarry += add
        if self.state.clickerPassiveCarry >= 1 then
            local whole = math.floor(self.state.clickerPassiveCarry)
            self.state.clickerPassiveCarry -= whole
            self:_addClickerScore(whole, false)
        end
        if self.state.selectedPage == "Clicker" then
            refresh()
        end
        self:_saveClickerState(false)
    end)

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            title.TextColor3 = theme.text
            toggle.BackgroundColor3 = theme.window
            toggle.TextColor3 = theme.text
            status.TextColor3 = theme.text
            footer.BackgroundColor3 = theme.panel
            clickBtn.BackgroundColor3 = theme.window
            clickBtn.TextColor3 = theme.text
            resetBtn.BackgroundColor3 = theme.window
            resetBtn.TextColor3 = theme.text
            saveBtn.BackgroundColor3 = theme.window
            saveBtn.TextColor3 = theme.text
            footerInfo.TextColor3 = theme.subtle
            for _, row in ipairs(upgradeRows) do
                row.button.BackgroundColor3 = theme.window
                row.button.TextColor3 = theme.text
            end
        end,
    })

    refresh()
end

function MeerlyWin95:_buildMacroPage()
    local page = self:addPage("Macro", "MC")

    local title = make("TextLabel", {
        Parent = page,
        Text = "Macro (Declarable Input Capture)",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local status = make("TextLabel", {
        Parent = page,
        Text = "Status: Idle",
        Font = Enum.Font.Code,
        TextSize = 12,
        Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.fromOffset(8, 36),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local function setStatus(t)
        status.Text = "Status: " .. tostring(t)
    end

    local loopBtn = make("TextButton", {
        Parent = page,
        Text = "Loop Playback: OFF",
        Font = Enum.Font.Code,
        TextSize = 12,
        Size = UDim2.fromOffset(170, 24),
        Position = UDim2.fromOffset(8, 58),
        BorderSizePixel = 0,
    })
    applyBevel(loopBtn, self.theme.bevelLight, self.theme.bevelDark)

    local filenameBox = make("TextBox", {
        Parent = page,
        Text = self.state.macroFilename,
        PlaceholderText = "macro.json",
        Font = Enum.Font.Code,
        TextSize = 12,
        Size = UDim2.fromOffset(190, 24),
        Position = UDim2.fromOffset(186, 58),
        BorderSizePixel = 0,
        BackgroundColor3 = self.theme.window,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    applyBevel(filenameBox, self.theme.bevelLight, self.theme.bevelDark)

    local controls = {
        { "Record", UDim2.fromOffset(8, 90) },
        { "Play", UDim2.fromOffset(86, 90) },
        { "Stop", UDim2.fromOffset(164, 90) },
        { "Save", UDim2.fromOffset(242, 90) },
        { "Load", UDim2.fromOffset(320, 90) },
        { "Clear", UDim2.fromOffset(398, 90) },
    }

    local buttons = {}
    for _, def in ipairs(controls) do
        local btn = make("TextButton", {
            Parent = page,
            Text = def[1],
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.fromOffset(72, 24),
            Position = def[2],
            BorderSizePixel = 0,
        })
        applyBevel(btn, self.theme.bevelLight, self.theme.bevelDark)
        buttons[def[1]] = btn
    end

    local notes = make("TextLabel", {
        Parent = page,
        Text = "Records any keyboard input (except Unknown) with down/up timing.",
        Font = Enum.Font.Code,
        TextSize = 11,
        Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.fromOffset(8, 120),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local list = make("ScrollingFrame", {
        Parent = page,
        Size = UDim2.new(1, -24, 1, -152),
        Position = UDim2.fromOffset(8, 144),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ScrollBarThickness = 6,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    })
    local listLayout = make("UIListLayout", {
        Parent = list,
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local function renderEvents()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextLabel") then
                c:Destroy()
            end
        end
        if #self.state.macroEvents == 0 then
            make("TextLabel", {
                Parent = list,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -8, 0, 18),
                Font = Enum.Font.Code,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "(no events)",
                TextColor3 = self.theme.subtle,
            })
            return
        end
        for i, e in ipairs(self.state.macroEvents) do
            make("TextLabel", {
                Parent = list,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -8, 0, 18),
                Font = Enum.Font.Code,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = string.format("%03d | t=%.3f | %s %s", i, tonumber(e.t) or 0, tostring(e.k), (e.d == 1 and "down" or "up")),
                TextColor3 = self.theme.text,
            })
        end
    end

    local recordStart = 0
    local function stopRecording()
        if self.state.macroRecordConnection then
            self.state.macroRecordConnection:Disconnect()
            self.state.macroRecordConnection = nil
        end
        if self.state.macroRecordEndConnection then
            self.state.macroRecordEndConnection:Disconnect()
            self.state.macroRecordEndConnection = nil
        end
        self.state.macroRecording = false
    end

    local function startRecording()
        if self.state.macroPlaying then
            setStatus("Stop playback before recording")
            return
        end
        self.state.macroEvents = {}
        recordStart = os.clock()
        self.state.macroRecording = true
        setStatus("Recording...")
        self.state.macroRecordConnection = UserInputService.InputBegan:Connect(function(input, gp)
            if gp or not self.state.macroRecording then
                return
            end
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                self.state.macroEvents[#self.state.macroEvents + 1] = { t = os.clock() - recordStart, k = input.KeyCode.Name, d = 1 }
                renderEvents()
            end
        end)
        table.insert(self.state.connections, self.state.macroRecordConnection)
        self.state.macroRecordEndConnection = UserInputService.InputEnded:Connect(function(input, gp)
            if gp or not self.state.macroRecording then
                return
            end
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                self.state.macroEvents[#self.state.macroEvents + 1] = { t = os.clock() - recordStart, k = input.KeyCode.Name, d = 0 }
                renderEvents()
            end
        end)
        table.insert(self.state.connections, self.state.macroRecordEndConnection)
    end

    local function playOnce()
        if #self.state.macroEvents == 0 then
            return
        end
        local start = os.clock()
        for _, e in ipairs(self.state.macroEvents) do
            local target = start + (tonumber(e.t) or 0)
            while self.state.alive and self.state.macroPlaying and os.clock() < target do
                task.wait()
            end
            if not self.state.macroPlaying then
                break
            end
            local keyCode = Enum.KeyCode[tostring(e.k)]
            if keyCode then
                VirtualInputManager:SendKeyEvent(e.d == 1, keyCode, false, game)
            end
        end
    end

    self:_connect(loopBtn.MouseButton1Click, function()
        self.state.macroLoopEnabled = not self.state.macroLoopEnabled
        loopBtn.Text = "Loop Playback: " .. (self.state.macroLoopEnabled and "ON" or "OFF")
    end)

    self:_connect(filenameBox.FocusLost, function()
        local t = tostring(filenameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        self.state.macroFilename = (t ~= "" and t or "macro.json")
        filenameBox.Text = self.state.macroFilename
    end)

    self:_connect(buttons.Record.MouseButton1Click, function()
        if self.state.macroRecording then
            stopRecording()
            setStatus("Recorded " .. tostring(#self.state.macroEvents) .. " events")
            return
        end
        startRecording()
    end)

    self:_connect(buttons.Play.MouseButton1Click, function()
        if self.state.macroRecording then
            setStatus("Stop recording first")
            return
        end
        if #self.state.macroEvents == 0 or self.state.macroPlaying then
            return
        end
        self.state.macroPlaying = true
        setStatus("Playing " .. tostring(#self.state.macroEvents) .. " events")
        task.spawn(function()
            while self.state.alive and self.state.macroPlaying do
                playOnce()
                if not self.state.macroLoopEnabled then
                    break
                end
                task.wait(0.1)
            end
            self.state.macroPlaying = false
            setStatus("Idle")
        end)
    end)

    self:_connect(buttons.Stop.MouseButton1Click, function()
        stopRecording()
        self.state.macroPlaying = false
        setStatus("Idle")
    end)

    self:_connect(buttons.Clear.MouseButton1Click, function()
        if self.state.macroRecording or self.state.macroPlaying then
            return
        end
        self.state.macroEvents = {}
        renderEvents()
        setStatus("Cleared")
    end)

    self:_connect(buttons.Save.MouseButton1Click, function()
        local payload = {
            version = 1,
            recordedAt = os.time(),
            events = self.state.macroEvents,
        }
        local ok, err = safeWriteFile(self.state.macroFilename, HttpService:JSONEncode(payload))
        if ok then
            setStatus("Saved " .. self.state.macroFilename)
        else
            setStatus("Save failed: " .. tostring(err))
        end
    end)

    self:_connect(buttons.Load.MouseButton1Click, function()
        if self.state.macroRecording or self.state.macroPlaying then
            return
        end
        local ok, data = safeReadFile(self.state.macroFilename)
        if not ok then
            setStatus("Load failed")
            return
        end
        local decoded
        local okDecode = pcall(function()
            decoded = HttpService:JSONDecode(data)
        end)
        if not okDecode or type(decoded) ~= "table" or type(decoded.events) ~= "table" then
            setStatus("Invalid macro file")
            return
        end
        self.state.macroEvents = decoded.events
        renderEvents()
        setStatus("Loaded " .. tostring(#self.state.macroEvents) .. " events")
    end)

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            title.TextColor3 = theme.text
            status.TextColor3 = theme.subtle
            loopBtn.BackgroundColor3 = theme.window
            loopBtn.TextColor3 = theme.text
            filenameBox.BackgroundColor3 = theme.window
            filenameBox.TextColor3 = theme.text
            filenameBox.PlaceholderColor3 = theme.subtle
            notes.TextColor3 = theme.subtle
            for _, btn in pairs(buttons) do
                btn.BackgroundColor3 = theme.window
                btn.TextColor3 = theme.text
            end
            for _, child in ipairs(list:GetChildren()) do
                if child:IsA("TextLabel") then
                    child.TextColor3 = theme.text
                end
            end
        end,
    })

    renderEvents()
end

function MeerlyWin95:_setupRuntimeStatistics()
    local runtime = _G.__MEERLY_UI_RUNTIME_STATS
    runtime.activeInstances = math.max(0, tonumber(runtime.activeInstances) or 0) + 1
    if not runtime.sharedStartUnix then
        runtime.sharedStartUnix = os.time()
    end

    self.state.runtimeStats = runtime
    self.state.sessionStartClock = os.clock()
    self.state.statsProviders = {}

    self:registerStatisticProvider("Session Time", function()
        local sessionSeconds = math.max(0, math.floor(os.clock() - self.state.sessionStartClock))
        return {
            primary = formatDurationHM(sessionSeconds),
            detail = string.format("%ds", sessionSeconds),
            order = 1,
        }
    end)

    self:registerStatisticProvider("Total Runtime", function()
        local sharedStart = runtime.sharedStartUnix or os.time()
        local totalSeconds = math.max(0, math.floor((tonumber(runtime.totalAccumulatedSeconds) or 0) + (os.time() - sharedStart)))
        return {
            primary = formatDurationHM(totalSeconds),
            detail = string.format("%ds", totalSeconds),
            order = 2,
        }
    end)

    self:registerStatisticProvider("Active UI Instances", function()
        return {
            primary = tostring(math.max(0, tonumber(runtime.activeInstances) or 0)),
            detail = "linked runtime sessions",
            order = 3,
            tier = "None",
        }
    end)

    self:registerStatisticProvider("Clicker High Score", function()
        local best = math.max(self.state.statisticsData.clickerHighScore or 0, self.state.clickerHighScore or 0)
        local tier = getTierByThreshold(best, 10000, 100000, 1000000, 10000000, 50000000, 100000000)
        return {
            primary = tostring(best),
            detail = "Bronze 10k | Silver 100k | Gold 1m | Diamond 10m | Platinum 50m | Master 100m",
            order = 20,
            tier = tier,
        }
    end)

    self:registerStatisticProvider("Clicker Shape Cycle", function()
        local cycle = math.max(0, self.state.clickerShapeCycle or 0)
        local tier = getTierByThreshold(cycle, 2, 4, 6, 8, 10, 12)
        return {
            primary = string.format("C%d", cycle),
            detail = "Bronze C2 | Silver C4 | Gold C6 | Diamond C8 | Platinum C10 | Master C12",
            order = 21,
            tier = tier,
        }
    end)

    self:registerStatisticProvider("Total Clicks Over Time", function()
        local total = math.max(self.state.totalClicksOverTime or 0, self.state.statisticsData.totalClicksOverTime or 0)
        local tier = getTierByThreshold(total, 10000, 100000, 1000000, 10000000, 50000000, 100000000)
        return {
            primary = tostring(total),
            detail = "Tracks total manual click power earned over time",
            order = 22,
            tier = tier,
        }
    end)
end

function MeerlyWin95:registerStatisticProvider(name, providerFn)
    if type(name) ~= "string" or name == "" or type(providerFn) ~= "function" then
        return false
    end

    self.state.statsProviders[name] = providerFn
    if self.state.selectedPage == "Statistics" then
        self:_renderStatisticsPage()
    end
    return true
end

function MeerlyWin95:_collectStatisticsRows()
    local rows = {}
    for name, provider in pairs(self.state.statsProviders or {}) do
        local ok, payload = pcall(provider)
        if ok and type(payload) == "table" then
            rows[#rows + 1] = {
                name = name,
                primary = tostring(payload.primary or "n/a"),
                detail = tostring(payload.detail or ""),
                order = tonumber(payload.order) or 999,
                tier = tostring(payload.tier or "None"),
            }
        else
            rows[#rows + 1] = {
                name = name,
                primary = "error",
                detail = ok and "invalid payload" or tostring(payload),
                order = 1000,
                tier = "None",
            }
        end
    end

    table.sort(rows, function(a, b)
        if a.order == b.order then
            return a.name < b.name
        end
        return a.order < b.order
    end)

    return rows
end

function MeerlyWin95:_renderStatisticsPage()
    if not self.statisticsList then
        return
    end

    for _, child in ipairs(self.statisticsList:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    local rows = self:_collectStatisticsRows()
    if #rows == 0 then
        make("TextLabel", {
            Parent = self.statisticsList,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -8, 0, 20),
            Font = Enum.Font.Code,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "No statistics providers registered",
            ZIndex = 14,
            TextColor3 = self.theme.subtle,
        })
        return
    end

    for _, row in ipairs(rows) do
        local hasDetail = row.detail ~= ""
        local container = make("Frame", {
            Parent = self.statisticsList,
            Size = UDim2.new(1, -8, 0, hasDetail and 48 or 30),
            BorderSizePixel = 0,
            BackgroundColor3 = self.theme.panel,
            BackgroundTransparency = 0,
            ZIndex = 13,
        })
        local tierBorder = make("Frame", {
            Parent = container,
            Size = UDim2.new(0, 3, 1, 0),
            Position = UDim2.fromOffset(0, 0),
            BorderSizePixel = 0,
            BackgroundColor3 = getTierColorByName(row.tier),
            ZIndex = 14,
        })

        make("TextLabel", {
            Parent = container,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -4, 1, 0),
            Position = UDim2.fromOffset(8, 0),
            Font = Enum.Font.Code,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Text = row.name,
            ZIndex = 14,
            TextColor3 = self.theme.text,
        })

        make("TextLabel", {
            Parent = container,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -6, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            Font = Enum.Font.Code,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextYAlignment = Enum.TextYAlignment.Center,
            Text = row.primary,
            ZIndex = 14,
            TextColor3 = self.theme.accent,
        })

        if row.detail ~= "" then
            make("TextLabel", {
                Parent = container,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -12, 0, 12),
                Position = UDim2.fromOffset(6, 20),
                Font = Enum.Font.Code,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = row.detail,
                ZIndex = 14,
                TextColor3 = self.theme.subtle,
            })
        end

    end
end

function MeerlyWin95:_buildStatisticsPage()
    local page = self:addPage("Statistics", "SS")

    local title = make("TextLabel", {
        Parent = page,
        Text = "Statistics",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local refresh = make("TextButton", {
        Parent = page,
        Text = "Refresh Stats",
        Font = Enum.Font.Code,
        TextSize = 12,
        Size = UDim2.fromOffset(120, 24),
        Position = UDim2.fromOffset(8, 36),
        BorderSizePixel = 0,
    })
    applyBevel(refresh, self.theme.bevelLight, self.theme.bevelDark)

    self.statisticsList = make("ScrollingFrame", {
        Parent = page,
        Size = UDim2.new(1, -24, 1, -72),
        Position = UDim2.fromOffset(8, 64),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ScrollBarThickness = 6,
        ScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 13,
    })

    self.statisticsLayout = make("UIListLayout", {
        Parent = self.statisticsList,
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    })

    self:_connect(refresh.MouseButton1Click, function()
        self:_renderStatisticsPage()
        self:log("EVENT", "Statistics page refreshed")
    end)

    self:_connect(RunService.Heartbeat, function()
        if self.state.alive and self.state.selectedPage == "Statistics" then
            self:_renderStatisticsPage()
        end
    end)

    table.insert(self.dynamicThemeParts, {
        apply = function(theme)
            title.TextColor3 = theme.text
            refresh.BackgroundColor3 = theme.window
            refresh.TextColor3 = theme.text
        end,
    })

    self:_renderStatisticsPage()
end

function MeerlyWin95:_initializeRobloxSettingsRuntime()
    local function applyPerformanceMode(mode)
        self:_safeExecutorAction("Graphics " .. tostring(mode), function()
            local quality = {
                ["Super Low"] = Enum.QualityLevel.Level01,
                ["Low"] = Enum.QualityLevel.Level03,
                ["Default"] = Enum.QualityLevel.Automatic,
                ["Extremely High"] = Enum.QualityLevel.Level10,
            }
            local target = quality[mode] or Enum.QualityLevel.Automatic
            pcall(function()
                settings().Rendering.QualityLevel = target
            end)

            local disableVisuals = (mode == "Super Low" or mode == "Low")
            Lighting.GlobalShadows = not disableVisuals
            Lighting.FogEnd = disableVisuals and 1e6 or 100000
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") then
                    v.Enabled = not disableVisuals
                end
            end
        end)
    end

    local function applyFxCulling(mode)
        self:_safeExecutorAction("FX Culling " .. tostring(mode), function()
            local enabled = mode == "Low"
            local ok, descendants = pcall(function()
                return workspace:GetDescendants()
            end)
            if not ok then
                error("workspace unavailable")
            end

            local changed = 0
            for _, inst in ipairs(descendants) do
                if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
                    pcall(function()
                        inst.Enabled = enabled
                        if inst:IsA("ParticleEmitter") then
                            inst.Rate = enabled and inst.Rate or 0
                        end
                    end)
                    changed += 1
                end
            end
            self:log("DEBUG", string.format("FX culling touched %d effects", changed))
        end)
    end

    local function applyStreamingOptimized(enabled)
        self:_safeExecutorAction("Streaming Optimisations", function()
            if enabled then
                pcall(function()
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                end)
                pcall(function()
                    settings().Network.IncomingReplicationLag = 0.1
                end)
            else
                pcall(function()
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
                end)
            end
        end)
    end

    local function applyBackgroundSurvival(enabled)
        self:log("EVENT", enabled and "Background survival enabled — optimized for tabbed-out AFK" or "Background survival disabled")
    end

    local function applyDisable3D(disabled)
        self:_safeExecutorAction("Disable 3D", function()
            if RunService.Set3dRenderingEnabled then
                RunService:Set3dRenderingEnabled(not disabled)
                return
            end
            if type(getExecutorGlobal("setrenderproperty")) == "function" then
                getExecutorGlobal("setrenderproperty")("Enabled", not disabled)
                return
            end
            if type(getExecutorGlobal("setRenderingEnabled")) == "function" then
                getExecutorGlobal("setRenderingEnabled")(not disabled)
                return
            end
            error("render toggle function unavailable")
        end)
    end

    local function ensureAntiAfkConnection()
        if self.state.afkConnection then
            return
        end
        local idledSignal = LocalPlayer and LocalPlayer.Idled
        if idledSignal then
            self.state.afkConnection = idledSignal:Connect(function()
                if not self.state.antiAfk then
                    return
                end
                self:_safeExecutorAction("Anti-AFK pulse", function()
                    local vim = game:GetService("VirtualInputManager")
                    vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end)
            end)
            table.insert(self.state.connections, self.state.afkConnection)
        end
    end

    self.state.settingsActions = {
        applyPerformanceMode = applyPerformanceMode,
        applyFxCulling = applyFxCulling,
        applyStreamingOptimized = applyStreamingOptimized,
        applyBackgroundSurvival = applyBackgroundSurvival,
        applyDisable3D = applyDisable3D,
        ensureAntiAfkConnection = ensureAntiAfkConnection,
    }

    ensureAntiAfkConnection()
end

function MeerlyWin95:_buildConsolePage()
    local page = self:addPage("Console", "LG")

    local title = make("TextLabel", {
        Parent = page,
        Text = "Console",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, -24, 0, 24),
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
        Size = UDim2.new(1, -24, 1, -110),
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
        Size = UDim2.new(1, -24, 0, 24),
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

    local contentInsetX = 8
    local controlWidthOffset = -24

    local title = make("TextLabel", {
        Parent = page,
        Text = "Roblox Settings",
        Font = Enum.Font.Code,
        TextSize = 18,
        Size = UDim2.new(1, controlWidthOffset, 0, 24),
        Position = UDim2.fromOffset(contentInsetX, 8),
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
            Size = UDim2.new(1, controlWidthOffset, 0, 20),
            Position = UDim2.fromOffset(contentInsetX, y),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        y = y + 20

        local line = make("Frame", {
            Parent = page,
            Size = UDim2.new(1, controlWidthOffset, 0, 1),
            Position = UDim2.fromOffset(contentInsetX, y),
            BorderSizePixel = 0,
        })
        y = y + 8

        table.insert(self.dynamicThemeParts, {
            apply = function(theme)
                lbl.TextColor3 = theme.accent
                line.BackgroundColor3 = theme.subtle
            end,
        })
    end

    local function addToggle(label, initial, callback)
        local btn = make("TextButton", {
            Parent = page,
            Text = label .. ": " .. (initial and "ON" or "OFF"),
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.new(1, controlWidthOffset, 0, 24),
            Position = UDim2.fromOffset(contentInsetX, y),
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
            Size = UDim2.new(1, controlWidthOffset, 0, 24),
            Position = UDim2.fromOffset(contentInsetX, y),
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

    local function addCycleSwitch(label, options, initialValue, callback)
        local index = 1
        for i, option in ipairs(options) do
            if option == initialValue then
                index = i
                break
            end
        end

        local btn = make("TextButton", {
            Parent = page,
            Text = label .. ": " .. tostring(options[index]),
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.new(1, controlWidthOffset, 0, 24),
            Position = UDim2.fromOffset(contentInsetX, y),
            BorderSizePixel = 0,
        })
        applyBevel(btn, self.theme.bevelLight, self.theme.bevelDark)

        self:_connect(btn.MouseButton1Click, function()
            index = (index % #options) + 1
            local value = options[index]
            btn.Text = label .. ": " .. tostring(value)
            callback(value)
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

    local function addSlider(label, minValue, maxValue, step, getter, setter, formatter)
        formatter = formatter or function(v)
            return tostring(v)
        end

        local lbl = make("TextLabel", {
            Parent = page,
            Text = label,
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.new(1, controlWidthOffset, 0, 20),
            Position = UDim2.fromOffset(contentInsetX, y),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        y = y + 20

        local valueLabel = make("TextLabel", {
            Parent = page,
            Text = "",
            Font = Enum.Font.Code,
            TextSize = 12,
            Size = UDim2.fromOffset(110, 20),
            Position = UDim2.new(1, -(contentInsetX + 110), 0, y - 20),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Right,
        })

        local track = make("Frame", {
            Parent = page,
            Size = UDim2.new(1, controlWidthOffset, 0, 18),
            Position = UDim2.fromOffset(contentInsetX, y),
            BorderSizePixel = 0,
        })
        applyBevel(track, self.theme.bevelLight, self.theme.bevelDark)

        local fill = make("Frame", {
            Parent = track,
            Size = UDim2.new(0, 0, 1, 0),
            BorderSizePixel = 0,
        })

        local knob = make("Frame", {
            Parent = track,
            Size = UDim2.fromOffset(8, 18),
            Position = UDim2.fromOffset(0, 0),
            BorderSizePixel = 0,
        })

        local function quantize(value)
            local stepped = math.floor(((value - minValue) / step) + 0.5) * step + minValue
            return math.clamp(stepped, minValue, maxValue)
        end

        local function render(value)
            local alpha = (value - minValue) / math.max(1e-6, (maxValue - minValue))
            local width = math.max(1, track.AbsoluteSize.X)
            local knobX = math.floor((width - knob.AbsoluteSize.X) * alpha)
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.fromOffset(knobX, 0)
            valueLabel.Text = formatter(value)
        end

        local function commit(value, fireEvent)
            local quantized = quantize(value)
            setter(quantized, fireEvent)
            render(quantized)
        end

        local dragging = false
        local function fromPosition(posX)
            local width = math.max(1, track.AbsoluteSize.X)
            local alpha = math.clamp((posX - track.AbsolutePosition.X) / width, 0, 1)
            local raw = minValue + ((maxValue - minValue) * alpha)
            commit(raw, false)
        end

        self:_connect(track.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                fromPosition(input.Position.X)
            end
        end)

        self:_connect(track.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    dragging = false
                    commit(getter(), true)
                end
            end
        end)

        self:_connect(UserInputService.InputChanged, function(input)
            if not dragging then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                fromPosition(input.Position.X)
            end
        end)

        y = y + 26
        table.insert(self.dynamicThemeParts, {
            apply = function(theme)
                lbl.TextColor3 = theme.text
                valueLabel.TextColor3 = theme.text
                track.BackgroundColor3 = theme.window
                fill.BackgroundColor3 = theme.accent
                knob.BackgroundColor3 = theme.text
            end,
        })

        task.defer(function()
            commit(getter(), false)
        end)

        return track
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
    addCycleSwitch("Graphics", { "Super Low", "Low", "Default", "Extremely High" }, self.state.performanceMode, function(v)
        self.state.performanceMode = v
        self:log("EVENT", "Graphics mode set: " .. v)
        self.state.settingsActions.applyPerformanceMode(v)
    end)
    addCycleSwitch("FX Culling", { "Low", "Medium", "Strong", "Extreme" }, self.state.fxCulling, function(v)
        self.state.fxCulling = v
        self:log("EVENT", "FX Culling set: " .. v)
        self.state.settingsActions.applyFxCulling(v)
    end)
    addToggle("Streaming Optimisations", self.state.streamOptimized, function(v)
        self.state.streamOptimized = v
        self:log("EVENT", "Streaming Optimisations " .. (v and "enabled" or "disabled"))
        self.state.settingsActions.applyStreamingOptimized(v)
    end)
    addToggle("Background Survival Mode", self.state.backgroundSurvival, function(v)
        self.state.backgroundSurvival = v
        self:log("EVENT", "Background Survival Mode " .. (v and "enabled" or "disabled"))
        self.state.settingsActions.applyBackgroundSurvival(v)
    end)

    addSection("AFK Settings")
    addToggle("Anti-AFK (idle pulse)", self.state.antiAfk, function(v)
        self.state.antiAfk = v
        self.state.settingsActions.ensureAntiAfkConnection()
        self:log("EVENT", "Anti-AFK " .. (v and "enabled" or "disabled"))
    end)
    addToggle("Watchdog", self.state.watchdog, function(v)
        self.state.watchdog = v
        self:log("EVENT", "Watchdog " .. (v and "enabled" or "disabled"))
    end)

    addSlider("FPS Cap", 30, 240, 1, function()
        return self.state.fpsCap
    end, function(value, committed)
        self.state.fpsCap = math.clamp(math.floor(value + 0.5), 30, 240)
        if committed then
            self:_safeExecutorAction("FPS Cap", function()
                if setfpscap then
                    setfpscap(self.state.fpsCap)
                else
                    error("setfpscap unavailable")
                end
            end)
        end
    end, function(value)
        return string.format("%d", value)
    end)

    addCycleSwitch("Memory Guard", { "Off", "AutoRejoin", "AutoQuit" }, self.state.memGuardMode, function(v)
        self.state.memGuardMode = v
        self:log("EVENT", "Memory Guard " .. v)
    end)

    addSlider("Memory Guard Cap (GB)", 6, 16, 0.5, function()
        return self.state.memGuardGb
    end, function(value, committed)
        local rounded = math.floor((value * 2) + 0.5) / 2
        self.state.memGuardGb = math.clamp(rounded, 6, 16)
        if committed then
            self:log("EVENT", string.format("Memory Guard cap set: %.1f GB", self.state.memGuardGb))
        end
    end, function(value)
        return string.format("%.1f", value)
    end)

    addToggle("Disable 3D Rendering", self.state.disable3D, function(v)
        self.state.disable3D = v
        self.state.settingsActions.applyDisable3D(v)
    end)
    addButton("AFK Camera (move away)", function()
        self:_safeExecutorAction("AFK Camera", function()
            local cam = workspace.CurrentCamera
            if not cam then
                return
            end
            if not self.state._afkCameraSnapshot then
                self.state._afkCameraSnapshot = {
                    cameraType = cam.CameraType,
                    cameraSubject = cam.CameraSubject,
                    cframe = cam.CFrame,
                }
                cam.CameraType = Enum.CameraType.Scriptable
                cam.CameraSubject = nil
                cam.CFrame = CFrame.new(0, 10000, 0)
            else
                local old = self.state._afkCameraSnapshot
                cam.CameraType = old.cameraType or Enum.CameraType.Custom
                cam.CameraSubject = old.cameraSubject
                cam.CFrame = old.cframe or cam.CFrame
                self.state._afkCameraSnapshot = nil
            end
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
    self:_buildClickerPage()
    self:_buildMacroPage()
    self:_buildStatisticsPage()
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
            task.wait(30)
            if self.state.selectedPage == "Statistics" then
                self:_renderStatisticsPage()
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

    safeCall("ClickerSave", function()
        self:_saveClickerState(true)
        self:_finalizeSessionStatistics("destroy")
    end)

    safeCall("RuntimeStatsFinalize", function()
        local runtime = _G.__MEERLY_UI_RUNTIME_STATS
        if runtime then
            local elapsed = math.max(0, math.floor(os.clock() - (self.state.sessionStartClock or os.clock())))
            runtime.totalAccumulatedSeconds = math.max(0, tonumber(runtime.totalAccumulatedSeconds) or 0) + elapsed
            runtime.activeInstances = math.max(0, (tonumber(runtime.activeInstances) or 1) - 1)
            if runtime.activeInstances <= 0 then
                runtime.activeInstances = 0
                runtime.sharedStartUnix = os.time()
            end
        end
    end)

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
