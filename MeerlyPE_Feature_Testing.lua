-- ============================================================
-- PE v4 Build 7 — Dev Build (UX REWORK + CLICKER GAME + STATISTICS)
-- Automation + Calculators + Minigame + Console + Misc + Macro
-- ============================================================


-- SERVICES

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local Lighting            = game:GetService("Lighting")
local UserInputService    = game:GetService("UserInputService")
local TeleportService     = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local Stats               = game:GetService("Stats")
local HttpService         = game:GetService("HttpService")

local player = Players.LocalPlayer
math.randomseed(os.clock())


-- ACCESS GATE CONFIG

local KEYGATE_LINK = "https://work.ink/2kaV/meerlype-key123"
local KEYGATE_KEY = "1234"


local SPLASH_CHANGELOG = {
    "Build 7:",
    "Sidebar / Page Rework.",
    "Added minigame 'Clicker'.",
    "Added Statistics.",
    "Merged Calculators.",
    "Merged Misc / Performance", 
    "Added some level of persistence (read/write required).",
}

local SPLASH_SOCIALS = {
    { name = "Discord", value = "meerly | old: #7571" },
    { name = "Email", value = "Meerly.GFX@gmail.com" },
    { name = "PE Discord", value = "https://discord.gg/BdxHP9mT" },
}


-- CONNECTION TRACKING / SAFE TEARDOWN

local __destroyed = false
local __connections = {}

local function track(conn)
    if conn then
        __connections[#__connections + 1] = conn
    end
    return conn
end


-- THEME SYSTEM

local Theme = {
    Accent     = Color3.fromRGB(120, 180, 255),
    Background = Color3.fromRGB(16, 16, 20),
    Panel      = Color3.fromRGB(22, 22, 28),
    PanelDark  = Color3.fromRGB(18, 18, 22),
    Border     = Color3.fromRGB(40, 40, 48),
    Text       = Color3.fromRGB(235, 235, 240),
    SubText    = Color3.fromRGB(150, 150, 155),
}

local DEFAULT_THEME = table.clone(Theme)
local function cloneTheme(t) return table.clone(t) end

local ThemeObjects = {}
local function register(obj, prop, key)
    ThemeObjects[#ThemeObjects+1] = { obj=obj, prop=prop, key=key }
end

local ThemeRefreshers = {}

local CurrentPage
local Pages = {}
local SidebarButtons = {}

local function setActiveTab(activeName)
    for name, btn in pairs(SidebarButtons) do
        if name == activeName then
            btn.BackgroundColor3 = Theme.PanelDark
            btn.TextColor3 = Theme.Accent
        else
            btn.BackgroundColor3 = Theme.Panel
            btn.TextColor3 = Theme.Text
        end
    end
end

local function applyTheme(newTheme)
    Theme = cloneTheme(newTheme)

    for _, item in ipairs(ThemeObjects) do
        if item.obj and item.obj.Parent then
            if item.key then
                item.obj[item.prop] = Theme[item.key]
            else
                item.obj[item.prop] = Theme[item.prop]
            end
        end
    end

    for _, fn in ipairs(ThemeRefreshers) do
        pcall(fn)
    end

    if CurrentPage then
        setActiveTab(CurrentPage.Name)
    end
end


-- VISUAL FX

local Blur = Instance.new("BlurEffect")
Blur.Size = 0
Blur.Parent = Lighting

local function setBlur(amount)
    Blur.Size = amount
end

local setTransparency


-- GLOBAL SINGLETONS & STATE

_G.__MeerlyState = _G.__MeerlyState or {
    antiAfkEnabled  = false,
    watchdogEnabled = false,
    lastHeartbeat   = os.clock(),
}

local antiAfkEnabled  = _G.__MeerlyState.antiAfkEnabled
local watchdogEnabled = _G.__MeerlyState.watchdogEnabled


-- CORE STATE

local running   = true

-- AUTOMATION STATE
local AutoSkillMode = { Off = 0, Normal = 1, Stagger = 2 }
local autoSkillMode = autoSkillMode or AutoSkillMode.Off

local SKILL_KEYS = { Q = Enum.KeyCode.Q, E = Enum.KeyCode.E, R = Enum.KeyCode.R }
local skillEnabled  = skillEnabled or { Q = true, E = true, R = false }
local skillPriority = { "Q", "E", "R" }

local BASE_COOLDOWN_MS = 12250
local COOLDOWN_MIN_MS  = 12550
local COOLDOWN_MAX_MS  = 12750

local adaptiveCooldownEnabled = false
local cooldownVariance = 1

local SKILL_CHAIN_PRESETS = { Off = 0.5, Safe = 4.0, Relaxed = 6.0 }
local selectedChainMode = "Off"
local staggerOrder  = { "Off", "Relaxed", "Safe" }
local staggerLabels = { Off = "10s", Relaxed = "6s", Safe = "4s" }

local autoClickerEnabled = false
local autoClickRate = 10

local setAutoClickerToggle, getAutoClickerToggle
local macroHotkeyToggleRecord

local skillState = skillState or {
    Q = { lastUse = nil, nextCooldownMs = BASE_COOLDOWN_MS },
    E = { lastUse = nil, nextCooldownMs = BASE_COOLDOWN_MS },
    R = { lastUse = nil, nextCooldownMs = BASE_COOLDOWN_MS },
}

-- MISC STATE
local AFKCameraEnabled = false
local savedCameraType, savedCameraSubject, savedCameraCFrame
local zoomUnlockEnabled = false
local originalMinZoom = player.CameraMinZoomDistance
local originalMaxZoom = player.CameraMaxZoomDistance

-- PERFORMANCE STATE
local fpsCapEnabled = false
local targetFPS = 60
local visualsDisabled = false
local streamingOptimized = false
local backgroundMode = false
local windowFocused = true
local heartbeatLagThreshold = 1.5
local memoryLogInterval = 60
local lastMemoryLog = 0

-- FLOATING MEMORY UI STATE
local memoryStatsEnabled = false

-- MACRO STATE
local macroRecording = false
local macroPlaying = false
local macroLoopEnabled = false
local macroEvents = {}
local macroStartClock = 0
local macroFilename = "macro.json"
local configPrefix = "config_slot"
local memoryGuardMode = "Off" -- Off | AutoRejoin | AutoQuit
local memoryGuardCapGB = 10
local lastMemoryGuardAction = 0
local memoryGuardCooldown = 30

-- MINI CLICKER GAME STATE (LOW MEMORY)
local clickerScore = 0
local clickerHighScore = 0
local clickerRunning = false
local clickPower = 1
local passiveIncomePerSec = 0
local clickerLastSave = 0
local clickerHighScoreFile = "clicker_highscore.txt"
local clickerStateFile = "clicker_state.txt"
local CLICKER_AUTOSAVE_SEC = 600
local CLICKER_STATE_CULL_SEC = 30

local CLICKER_UPGRADES = {
    { id = "Tap",   name = "Tap Training",   kind = "clickFlat",   value = 1,    baseCost = 15,   growth = 1.22 },
    { id = "Gen",   name = "Generator",      kind = "passiveFlat", value = 1,    baseCost = 40,   growth = 1.28 },
    { id = "Over",  name = "Overclock",      kind = "clickMult",   value = 0.12, baseCost = 110,  growth = 1.42 },
    { id = "Auto",  name = "Automation",     kind = "passiveMult", value = 0.14, baseCost = 170,  growth = 1.48 },
    { id = "Turbo", name = "Turbo Gloves",   kind = "clickFlat",   value = 4,    baseCost = 420,  growth = 1.36 },
    { id = "Drone", name = "Drone Farm",     kind = "passiveFlat", value = 6,    baseCost = 780,  growth = 1.41 },
    { id = "Nova",  name = "Nova Catalyst",  kind = "clickMult",   value = 0.20, baseCost = 1350, growth = 1.5 },
}

local function newClickerUpgradeLevels()
    local levels = {}
    for _, def in ipairs(CLICKER_UPGRADES) do
        levels[def.id] = 0
    end
    return levels
end

local clickerUpgradeLevels = newClickerUpgradeLevels()

local clickerShapeVertices = 3
local clickerShapeCycle = 0
local clickerShapeProgress = 0
local clickerShapeMilestone = 25
local clickerPassiveCarry = 0

-- STATISTICS / ACHIEVEMENTS
local statisticsFile = "statistics_data.json"
local statisticsSessionStartClock = os.clock()
local statisticsData = {
    longestSessionSeconds = 0,
    totalSkillActivations = 0,
    clickerHighScore = 0,
    sessionActive = false,
    sessionStartTime = 0,
    lastSessionReason = "",
}

local STAT_TIERS = {
    None = { label = "Grey", color = Color3.fromRGB(96, 96, 108) },
    Bronze = { label = "Bronze", color = Color3.fromRGB(184, 115, 51) },
    Silver = { label = "Silver", color = Color3.fromRGB(170, 170, 178) },
    Gold = { label = "Gold", color = Color3.fromRGB(235, 198, 64) },
    Diamond = { label = "Diamond", color = Color3.fromRGB(80, 170, 255) },
    Platinum = { label = "Platinum", color = Color3.fromRGB(245, 245, 255) },
    Master = { label = "Master", color = Color3.fromRGB(255, 0, 255) },
}


-- LOGGING SYSTEM

local LogLevels = {
    Automation = true,
    Skills     = false,
    Clicker    = true,
    Boss       = true,
    XP         = true,
    System     = true,
    Macro      = true,
    Debug      = false,
    Error      = true,
}

local MAX_LOGS = 300
local logBuffer = table.create(MAX_LOGS)
local logHead = 0
local logCount = 0

local updateConsole

local function timestamp()
    return os.date("%H:%M:%S")
end

function log(level, message)
    if not LogLevels[level] then return end
    logHead = (logHead % MAX_LOGS) + 1
    logBuffer[logHead] = string.format("[%s] [%s] %s", timestamp(), level, tostring(message))
    logCount = math.min(logCount + 1, MAX_LOGS)
    if updateConsole then updateConsole() end
end


-- UTIL

local function randf(a, b)
    return a + math.random() * (b - a)
end

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(0.04)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function canUseSkill(skill)
    local state = skillState[skill]
    if not state then return true end
    if not state.lastUse then return true end
    local elapsedMs = (os.clock() - state.lastUse) * 1000
    local requiredMs = state.nextCooldownMs or BASE_COOLDOWN_MS
    return elapsedMs >= requiredMs
end

local function effectiveDPS(baseDPS, skills, multipliers)
    local total = baseDPS
    for k, enabled in pairs(skills) do
        if enabled then
            total += (baseDPS * (multipliers[k] / 100)) / 10
        end
    end
    return total
end

local function safeAutoScroll(scroller)
    pcall(function()
        scroller.CanvasPosition = Vector2.new(
            0,
            math.max(0, scroller.CanvasSize.Y.Offset - (scroller.AbsoluteWindowSize and scroller.AbsoluteWindowSize.Y or 0))
        )
    end)
end

local function safeTotalMemMb()
    local totalMem
    pcall(function()
        totalMem = Stats:GetTotalMemoryUsageMb()
    end)
    return totalMem
end

local function luaMemMb()
    local ok, val = pcall(function()
        return gcinfo() / 1024
    end)
    return ok and val or nil
end

local function safeWriteFile(path, content)
    if type(writefile) == "function" then
        return pcall(function() writefile(path, content) end)
    end
    return false, "writefile not available"
end

local function safeReadFile(path)
    if type(readfile) == "function" then
        local ok, data = pcall(function() return readfile(path) end)
        return ok, data
    end
    return false, "readfile not available"
end


local function formatDurationHM(totalSeconds)
    totalSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
    local h = math.floor(totalSeconds / 3600)
    local m = math.floor((totalSeconds % 3600) / 60)
    return string.format("%dh %02dm", h, m)
end

local function getTierByThreshold(value, bronzeOrTargets, silver, gold, diamond, platinum, master)
    value = tonumber(value) or 0

    local tierTargets
    if type(bronzeOrTargets) == "table" then
        tierTargets = bronzeOrTargets
    else
        tierTargets = {
            Bronze = tonumber(bronzeOrTargets),
            Silver = tonumber(silver),
            Gold = tonumber(gold),
            Diamond = tonumber(diamond),
            Platinum = tonumber(platinum),
            Master = tonumber(master),
        }
    end

    local order = { "Bronze", "Silver", "Gold", "Diamond", "Platinum", "Master" }
    local current = "None"
    for _, tierName in ipairs(order) do
        local target = tierTargets[tierName]
        if target and value >= target then
            current = tierName
        end
    end
    return current
end

local function saveStatistics()
    local payload = HttpService:JSONEncode(statisticsData)
    local ok, err = safeWriteFile(statisticsFile, payload)
    if not ok then
        log("Error", "Statistics save failed: " .. tostring(err))
    end
    return ok
end

local function loadStatistics()
    local okRead, raw = safeReadFile(statisticsFile)
    if okRead and type(raw) == "string" and #raw > 0 then
        local okDecode, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
        if okDecode and type(parsed) == "table" then
            statisticsData.longestSessionSeconds = math.max(0, math.floor(tonumber(parsed.longestSessionSeconds) or 0))
            statisticsData.totalSkillActivations = math.max(0, math.floor(tonumber(parsed.totalSkillActivations) or 0))
            statisticsData.clickerHighScore = math.max(0, math.floor(tonumber(parsed.clickerHighScore) or 0))
            statisticsData.sessionActive = parsed.sessionActive == true
            statisticsData.sessionStartTime = math.max(0, math.floor(tonumber(parsed.sessionStartTime) or 0))
            statisticsData.lastSessionReason = tostring(parsed.lastSessionReason or "")
        end
    end

    if statisticsData.sessionActive and statisticsData.sessionStartTime > 0 then
        local recoveredSeconds = math.max(0, os.time() - statisticsData.sessionStartTime)
        if recoveredSeconds > statisticsData.longestSessionSeconds then
            statisticsData.longestSessionSeconds = recoveredSeconds
            log("System", "Recovered session length from previous run: " .. formatDurationHM(recoveredSeconds))
        end
    end

    statisticsData.sessionActive = true
    statisticsData.sessionStartTime = os.time()
    statisticsData.lastSessionReason = "running"
end

local function finalizeSessionStatistics(reason)
    local elapsed = math.max(0, math.floor(os.clock() - statisticsSessionStartClock))
    if elapsed > statisticsData.longestSessionSeconds then
        statisticsData.longestSessionSeconds = elapsed
    end

    if clickerHighScore > statisticsData.clickerHighScore then
        statisticsData.clickerHighScore = clickerHighScore
    end

    statisticsData.sessionActive = false
    statisticsData.lastSessionReason = tostring(reason or "session_end")
    saveStatistics()
end

local function incrementSkillActivation(count)
    count = math.max(1, math.floor(tonumber(count) or 1))
    statisticsData.totalSkillActivations += count
end


local function dumpLogsToFile(reason)
    local lines = {}
    for i = 1, logCount do
        local idx = ((logHead - logCount + i - 1) % MAX_LOGS) + 1
        lines[#lines + 1] = logBuffer[idx]
    end

    lines[#lines + 1] = "[" .. timestamp() .. "] [System] Session end: " .. tostring(reason or "unknown")
    local filename = "session_logs_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    local ok, err = safeWriteFile(filename, table.concat(lines, "\n"))
    if ok then
        log("System", "Saved logs to " .. filename)
    else
        log("Error", "Log save failed: " .. tostring(err))
    end
end

local function getCombinedMemoryGb()
    local luaMb = gcinfo() / 1024
    local totalMb = safeTotalMemMb()
    local combinedMb = totalMb or luaMb
    return combinedMb / 1024, luaMb / 1024, totalMb and (totalMb / 1024) or nil
end


local function serializeTheme(theme)
    local out = {}
    for k, v in pairs(theme or {}) do
        if typeof(v) == "Color3" then
            out[k] = {
                __type = "Color3",
                r = math.floor(v.R * 255 + 0.5),
                g = math.floor(v.G * 255 + 0.5),
                b = math.floor(v.B * 255 + 0.5),
            }
        else
            out[k] = v
        end
    end
    return out
end

local function deserializeTheme(data)
    local out = {}
    for k, v in pairs(data or {}) do
        if type(v) == "table" and v.__type == "Color3" then
            out[k] = Color3.fromRGB(tonumber(v.r) or 255, tonumber(v.g) or 255, tonumber(v.b) or 255)
        else
            out[k] = v
        end
    end
    return out
end

local function runFileIOSelfTest(prefix)
    local name = (prefix or "io_test") .. "_" .. tostring(math.random(1000,9999)) .. ".json"
    local payload = HttpService:JSONEncode({ ok = true, t = os.time() })
    local wOk, wErr = safeWriteFile(name, payload)
    if not wOk then return false, "write failed: " .. tostring(wErr) end
    local rOk, raw = safeReadFile(name)
    if not rOk then return false, "read failed: " .. tostring(raw) end
    local okDecode, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okDecode or type(parsed) ~= "table" or parsed.ok ~= true then
        return false, "decode failed"
    end
    return true, name
end

local function clickerUpgradeCost(def, level)
    return math.max(1, math.floor((def.baseCost * (def.growth ^ level)) + 0.5))
end

local function recalcClickerStats()
    local clickFlat = 1
    local passiveFlat = 0
    local clickMult = 1
    local passiveMult = 1

    for _, def in ipairs(CLICKER_UPGRADES) do
        local lv = clickerUpgradeLevels[def.id] or 0
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

    clickPower = math.max(1, math.floor(clickFlat * clickMult + 0.5))
    passiveIncomePerSec = math.max(0, math.floor(passiveFlat * passiveMult + 0.5))
end

local function addClickerScore(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return end

    clickerScore += amount
    if clickerScore > clickerHighScore then
        clickerHighScore = clickerScore
    end

    clickerShapeProgress += amount
    while clickerShapeProgress >= clickerShapeMilestone do
        clickerShapeProgress -= clickerShapeMilestone
        clickerShapeVertices += 1
        if clickerShapeVertices > 9 then
            clickerShapeVertices = 3
            clickerShapeCycle += 1
        end
        clickerShapeMilestone = math.floor((clickerShapeMilestone * 1.35) + 5)
    end
end

local function angleDeg(dy, dx)
    local ok, val = pcall(function()
        if math.atan2 then
            return math.deg(math.atan2(dy, dx))
        end
        return math.deg(math.atan(dy, dx))
    end)
    if ok and val then return val end
    return 0
end

local function loadClickerHighScore()
    local okRead, raw = safeReadFile(clickerHighScoreFile)
    if okRead then
        local val = tonumber(raw)
        if val then
            clickerHighScore = math.max(0, math.floor(val))
        end
    end

    local okState, rawState = safeReadFile(clickerStateFile)
    if okState and type(rawState) == "string" then
        local scorePart, upgradesPart, vPart, cPart, pPart, mPart = rawState:match("^(%-?%d+)|([^|]+)|(%-?%d+)|(%-?%d+)|(%-?%d+)|(%-?%d+)$")
        if not scorePart then
            scorePart, upgradesPart = rawState:match("^(%-?%d+)|(.+)$")
        end

        local parsedScore = tonumber(scorePart)
        if parsedScore then
            clickerScore = math.max(0, math.floor(parsedScore))
        end

        if type(upgradesPart) == "string" then
            for chunk in string.gmatch(upgradesPart, "[^;]+") do
                local id, lv = chunk:match("^(%a+):(%-?%d+)$")
                if id and lv and clickerUpgradeLevels[id] ~= nil then
                    clickerUpgradeLevels[id] = math.max(0, math.floor(tonumber(lv) or 0))
                end
            end
        end

        if vPart and cPart and pPart and mPart then
            clickerShapeVertices = math.clamp(math.floor(tonumber(vPart) or 3), 3, 9)
            clickerShapeCycle = math.max(0, math.floor(tonumber(cPart) or 0))
            clickerShapeProgress = math.max(0, math.floor(tonumber(pPart) or 0))
            clickerShapeMilestone = math.max(25, math.floor(tonumber(mPart) or 25))
            if clickerShapeProgress >= clickerShapeMilestone then
                clickerShapeProgress = clickerShapeProgress % clickerShapeMilestone
            end
        end

        if clickerScore > clickerHighScore then
            clickerHighScore = clickerScore
        end
    end

    clickerPassiveCarry = 0
    recalcClickerStats()

    if clickerHighScore > statisticsData.clickerHighScore then
        statisticsData.clickerHighScore = clickerHighScore
    end
end

local function encodeClickerUpgrades()
    local parts = table.create(#CLICKER_UPGRADES)
    for _, def in ipairs(CLICKER_UPGRADES) do
        parts[#parts + 1] = string.format("%s:%d", def.id, clickerUpgradeLevels[def.id] or 0)
    end
    return table.concat(parts, ";")
end

local function saveClickerState(force)
    if not force and os.clock() - clickerLastSave < CLICKER_AUTOSAVE_SEC then
        return
    end
    clickerLastSave = os.clock()

    local payload = string.format("%d|%s|%d|%d|%d|%d", math.floor(clickerScore), encodeClickerUpgrades(), math.floor(clickerShapeVertices), math.floor(clickerShapeCycle), math.floor(clickerShapeProgress), math.floor(clickerShapeMilestone))
    local okState, errState = safeWriteFile(clickerStateFile, payload)
    if not okState then
        log("Error", "Clicker state save failed: " .. tostring(errState))
    end

    local okHigh, errHigh = safeWriteFile(clickerHighScoreFile, tostring(math.floor(clickerHighScore)))
    if clickerHighScore > statisticsData.clickerHighScore then
        statisticsData.clickerHighScore = clickerHighScore
        saveStatistics()
    end
    if not okHigh then
        log("Error", "Clicker highscore save failed: " .. tostring(errHigh))
    end
end

local function saveClickerHighScore(force)
    saveClickerState(force)
end

loadClickerHighScore()
loadStatistics()
if clickerHighScore > statisticsData.clickerHighScore then
    statisticsData.clickerHighScore = clickerHighScore
end
saveStatistics()

-- ROOT GUI

local gui = Instance.new("ScreenGui")
gui.Name = "MeerlyNW_UI_v4_Build7"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function makeRound(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 4)
    c.Parent = parent
    return c
end

local function addStroke(target, color, thickness, transparency)
    local st = Instance.new("UIStroke")
    st.Color = color or Theme.Border
    st.Thickness = thickness or 1
    st.Transparency = transparency == nil and 0.45 or transparency
    st.Parent = target
    return st
end

local function addGloss(target)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)),
    })
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.95),
        NumberSequenceKeypoint.new(1, 1),
    })
    g.Rotation = 90
    g.Parent = target
    return g
end


-- MAIN WINDOW

local window = Instance.new("Frame", gui)
window.Size = UDim2.fromScale(0.46, 0.6)
window.Position = UDim2.fromScale(0.03, 0.2)
window.BackgroundColor3 = Theme.Background
window.BorderSizePixel = 0
window.Active = true
window.Draggable = true
register(window, "BackgroundColor3", "Background")
makeRound(window, 8)
addStroke(window, Theme.Border, 1.2, 0.35)
addGloss(window)


-- FORWARD DECL: KILL SWITCH

local memoryGui 
local function killSwitch(reason)
    if __destroyed then return end
    __destroyed = true
    running = false
    macroRecording = false
    macroPlaying = false

    pcall(function()
        log("System", "Kill switch triggered" .. (reason and (": " .. tostring(reason)) or ""))
    end)

    pcall(function()
        saveClickerHighScore(true)
    end)

    pcall(function()
        finalizeSessionStatistics(reason or "kill switch")
    end)

    pcall(function()
        dumpLogsToFile(reason or "kill switch")
    end)

    pcall(function()
        player.CameraMinZoomDistance = originalMinZoom
        player.CameraMaxZoomDistance = originalMaxZoom
    end)

    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            cam.CameraType = savedCameraType or Enum.CameraType.Custom
            cam.CameraSubject = savedCameraSubject
            if savedCameraCFrame then
                cam.CFrame = savedCameraCFrame
            end
        end
    end)

    pcall(function()
        if Blur then Blur.Size = 0 end
    end)

    for _, c in ipairs(__connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(__connections)

    pcall(function()
        if gui then gui:Destroy() end
    end)
    pcall(function()
        if memoryGui then memoryGui:Destroy() end
    end)

    pcall(function()
        if Blur then Blur:Destroy() end
    end)
end


-- KILL SWITCH BUTTON (TOP LAYER)

local killBtn = Instance.new("TextButton")
killBtn.Name = "KillButton"
killBtn.Parent = gui
killBtn.Size = UDim2.fromScale(0.07, 0.04)
killBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
killBtn.BorderSizePixel = 0
killBtn.AutoButtonColor = true
killBtn.Text = "KILL"
killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = 14
killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
killBtn.ZIndex = 999999
makeRound(killBtn, 4)
addStroke(killBtn, Color3.fromRGB(200, 80, 80), 1, 0.3)

local function positionKill()
    if __destroyed then return end
    local p = window.AbsolutePosition
    local s = window.AbsoluteSize
    killBtn.AnchorPoint = Vector2.new(0, 1)
    killBtn.Position = UDim2.fromOffset(p.X + 12, p.Y + s.Y + 12)
end
positionKill()
track(window:GetPropertyChangedSignal("AbsolutePosition"):Connect(positionKill))
track(window:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionKill))
track(killBtn.MouseButton1Click:Connect(function()
    killSwitch("KILL button")
end))


-- SPLASH / KEYGATE

local function showSplashGate(onUnlock)
    setBlur(18)

    window.Visible = false
    killBtn.Visible = false

    local splash = Instance.new("Frame")
    splash.Name = "SplashGate"
    splash.Parent = gui
    splash.Size = UDim2.fromScale(1, 1)
    splash.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    splash.BackgroundTransparency = 0.2
    splash.ZIndex = 10000

    local function formatBulletedList(lines)
        local out = {}
        for _, line in ipairs(lines) do
            out[#out + 1] = "• " .. tostring(line)
        end
        return table.concat(out, "\n")
    end

    local function formatSocials(lines)
        local out = {}
        for _, entry in ipairs(lines) do
            out[#out + 1] = string.format("%s: %s", tostring(entry.name or ""), tostring(entry.value or ""))
        end
        return table.concat(out, "\n")
    end

    local card = Instance.new("Frame")
    card.Parent = splash
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(920, 320)
    card.BackgroundColor3 = Theme.PanelDark
    card.BorderSizePixel = 0
    card.ZIndex = 10001
    makeRound(card, 8)

    local columns = Instance.new("Frame")
    columns.Parent = card
    columns.BackgroundTransparency = 1
    columns.Position = UDim2.fromOffset(16, 14)
    columns.Size = UDim2.fromOffset(888, 292)
    columns.ZIndex = 10002

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.Parent = columns
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    rowLayout.Padding = UDim.new(0, 12)

    local function makeSidePanel(titleText, bodyText)
        local panel = Instance.new("Frame")
        panel.Size = UDim2.fromOffset(228, 292)
        panel.BackgroundColor3 = Theme.Panel
        panel.BorderSizePixel = 0
        panel.ZIndex = 10002
        makeRound(panel, 8)

        local title = Instance.new("TextLabel")
        title.Parent = panel
        title.BackgroundTransparency = 1
        title.Size = UDim2.fromOffset(196, 28)
        title.Position = UDim2.fromOffset(16, 14)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 18
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Theme.Text
        title.Text = titleText
        title.ZIndex = 10003

        local body = Instance.new("TextLabel")
        body.Parent = panel
        body.BackgroundTransparency = 1
        body.Size = UDim2.fromOffset(196, 236)
        body.Position = UDim2.fromOffset(16, 46)
        body.Font = Enum.Font.Gotham
        body.TextSize = 14
        body.TextWrapped = true
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextColor3 = Theme.SubText
        body.Text = bodyText
        body.ZIndex = 10003

        return panel
    end

    local leftPanel = makeSidePanel("Changelog", formatBulletedList(SPLASH_CHANGELOG))
    leftPanel.Parent = columns

    local gatePanel = Instance.new("Frame")
    gatePanel.Parent = columns
    gatePanel.Size = UDim2.fromOffset(420, 292)
    gatePanel.BackgroundTransparency = 1
    gatePanel.ZIndex = 10002

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Parent = gatePanel
    titleLbl.BackgroundTransparency = 1
    titleLbl.Size = UDim2.fromOffset(420, 38)
    titleLbl.Position = UDim2.fromOffset(0, 4)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 24
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextColor3 = Theme.Text
    titleLbl.Text = "Meerly PE v4 Build 7"
    titleLbl.ZIndex = 10002

    local subtitleLbl = Instance.new("TextLabel")
    subtitleLbl.Parent = gatePanel
    subtitleLbl.BackgroundTransparency = 1
    subtitleLbl.Size = UDim2.fromOffset(420, 24)
    subtitleLbl.Position = UDim2.fromOffset(0, 42)
    subtitleLbl.Font = Enum.Font.Gotham
    subtitleLbl.TextSize = 14
    subtitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    subtitleLbl.TextColor3 = Theme.SubText
    subtitleLbl.Text = "Open Work.Ink to get your key, then unlock the client."
    subtitleLbl.ZIndex = 10002

    local linkBox = Instance.new("TextBox")
    linkBox.Parent = gatePanel
    linkBox.Size = UDim2.fromOffset(420, 34)
    linkBox.Position = UDim2.fromOffset(0, 83)
    linkBox.BackgroundColor3 = Theme.Panel
    linkBox.BorderSizePixel = 0
    linkBox.Font = Enum.Font.Code
    linkBox.TextSize = 15
    linkBox.TextXAlignment = Enum.TextXAlignment.Left
    linkBox.TextColor3 = Theme.Text
    linkBox.PlaceholderText = "Work.Ink link"
    linkBox.Text = KEYGATE_LINK
    linkBox.ClearTextOnFocus = false
    linkBox.ZIndex = 10002
    makeRound(linkBox, 8)

    local keyInput = Instance.new("TextBox")
    keyInput.Parent = gatePanel
    keyInput.Size = UDim2.fromOffset(420, 42)
    keyInput.Position = UDim2.fromOffset(0, 132)
    keyInput.BackgroundColor3 = Theme.Panel
    keyInput.BorderSizePixel = 0
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 16
    keyInput.TextColor3 = Theme.Text
    keyInput.PlaceholderText = "Enter key"
    keyInput.Text = ""
    keyInput.ClearTextOnFocus = false
    keyInput.ZIndex = 10002
    makeRound(keyInput, 8)

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Parent = gatePanel
    statusLbl.BackgroundTransparency = 1
    statusLbl.Size = UDim2.fromOffset(420, 24)
    statusLbl.Position = UDim2.fromOffset(0, 182)
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 13
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextColor3 = Theme.SubText
    statusLbl.Text = ""
    statusLbl.ZIndex = 10002

    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Parent = gatePanel
    unlockBtn.Size = UDim2.fromOffset(420, 40)
    unlockBtn.Position = UDim2.fromOffset(0, 218)
    unlockBtn.BackgroundColor3 = Theme.Accent
    unlockBtn.BorderSizePixel = 0
    unlockBtn.Font = Enum.Font.GothamBold
    unlockBtn.TextSize = 15
    unlockBtn.TextColor3 = Color3.new(1, 1, 1)
    unlockBtn.Text = "Unlock"
    unlockBtn.ZIndex = 10002
    makeRound(unlockBtn, 8)

    local rightPanel = makeSidePanel("Socials", formatSocials(SPLASH_SOCIALS))
    rightPanel.Parent = columns

    local closeBtn = Instance.new("TextButton")
    closeBtn.Parent = card
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.Position = UDim2.fromOffset(884, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(120, 45, 45)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "X"
    closeBtn.ZIndex = 10003
    makeRound(closeBtn, 8)

    local function normalizedKey(text)
        local t = tostring(text or "")
        t = t:gsub('^%s*"', ""):gsub('"%s*$', "")
        t = t:gsub("^%s+", ""):gsub("%s+$", "")
        return t
    end

    local function attemptUnlock()
        local entered = normalizedKey(keyInput.Text)
        local required = normalizedKey(KEYGATE_KEY)

        if entered == required or string.lower(entered) == string.lower(required) then
            statusLbl.TextColor3 = Color3.fromRGB(120, 220, 130)
            statusLbl.Text = "Access granted. Loading client..."
            task.wait(0.15)
            splash:Destroy()
            setBlur(0)
            window.Visible = true
            killBtn.Visible = true
            if onUnlock then onUnlock() end
            return
        end
        statusLbl.TextColor3 = Color3.fromRGB(240, 90, 90)
        statusLbl.Text = "Invalid key. Please check Work.Ink and try again."
    end

    track(unlockBtn.MouseButton1Click:Connect(attemptUnlock))
    track(closeBtn.MouseButton1Click:Connect(function()
        killSwitch("Splash close button")
    end))
    track(keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            attemptUnlock()
        end
    end))
end
showSplashGate()

-- TOP BAR
local topBar = Instance.new("Frame", window)
topBar.Size = UDim2.fromScale(1, 0.08)
topBar.BackgroundColor3 = Theme.PanelDark
topBar.BorderSizePixel = 0
register(topBar, "BackgroundColor3", "PanelDark")
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
addStroke(topBar, Theme.Border, 1, 0.5)

-- TITLE
local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.fromScale(0.6, 1)
title.Position = UDim2.fromScale(0.02, 0)
title.BackgroundTransparency = 1
title.Text = "MeerlyNW — Peak Evolution"
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Theme.Text
register(title, "TextColor3", "Text")

-- STATUS
local status = Instance.new("TextLabel", topBar)
status.Size = UDim2.fromScale(0.35, 1)
status.Position = UDim2.fromScale(0.63, 0)
status.BackgroundTransparency = 1
status.Text = "● Ready"
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.TextXAlignment = Enum.TextXAlignment.Right
status.TextColor3 = Theme.Accent
register(status, "TextColor3", "Accent")

-- BODY
local body = Instance.new("Frame", window)
body.Position = UDim2.fromScale(0, 0.08)
body.Size = UDim2.fromScale(1, 0.92)
body.BackgroundColor3 = Theme.Background
body.BackgroundTransparency = 0
body.BorderSizePixel = 0
register(body, "BackgroundColor3", "Background")

local contentShell = Instance.new("Frame", body)
contentShell.Name = "ContentShell"
contentShell.Position = UDim2.fromScale(0.18, 0)
contentShell.Size = UDim2.fromScale(0.82, 1)
contentShell.BackgroundColor3 = Theme.PanelDark
contentShell.BorderSizePixel = 0
register(contentShell, "BackgroundColor3", "PanelDark")
makeRound(contentShell, 8)
addStroke(contentShell, Theme.Border, 1, 0.55)

-- SIDEBAR
local sidebar = Instance.new("Frame", body)
sidebar.Size = UDim2.fromScale(0.18, 1)
sidebar.BackgroundColor3 = Theme.Panel
register(sidebar, "BackgroundColor3", "Panel")
sidebar.BorderSizePixel = 0
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)
addStroke(sidebar, Theme.Border, 1, 0.5)

local sidebarLayout = Instance.new("UIListLayout", sidebar)
sidebarLayout.Padding = UDim.new(0, 6)
sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sidebarLayout.VerticalAlignment = Enum.VerticalAlignment.Top

local sidebarPadding = Instance.new("UIPadding", sidebar)
sidebarPadding.PaddingTop = UDim.new(0, 12)

-- CONTENT AREA
local content = Instance.new("Frame", body)
content.Position = UDim2.fromScale(0.18, 0)
content.Size = UDim2.fromScale(0.82, 1)
content.BackgroundTransparency = 1
content.ZIndex = 2


-- PAGES

local function createPage(name)
    local page = Instance.new("ScrollingFrame", content)
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollBarThickness = 6
    page.ScrollBarImageTransparency = 0.3
    page.Visible = false
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0

    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local padding = Instance.new("UIPadding", page)
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)

    local function refreshCanvas()
        task.defer(function()
            if not page or not page.Parent then return end
            local h = layout.AbsoluteContentSize.Y + 24
            page.CanvasSize = UDim2.new(0, 0, 0, h)
        end)
    end
    track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshCanvas))
    refreshCanvas()

    Pages[name] = page
    return page
end

local function switchPage(name)
    if CurrentPage then CurrentPage.Visible = false end
    CurrentPage = Pages[name]
    if CurrentPage then
        CurrentPage.Visible = true
        setActiveTab(name)
    end
end

local function sidebarButton(text)
    local btn = Instance.new("TextButton", sidebar)
    btn.Size = UDim2.fromScale(0.9, 0.06)
    btn.BackgroundColor3 = Theme.Panel
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Theme.Text
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    register(btn, "BackgroundColor3", "Panel")
    register(btn, "TextColor3", "Text")

    SidebarButtons[text] = btn
    track(btn.MouseButton1Click:Connect(function()
        switchPage(text)
    end))
    return btn
end

local pageNames = { "Automation", "Macro", "Calculators", "Misc", "Clicker", "Statistics", "Config", "Themes", "Console", "Help" }
for _, name in ipairs(pageNames) do
    sidebarButton(name)
    createPage(name)
end

-- hidden utility pages kept for existing tools
createPage("Misc")
createPage("Console")

switchPage("Automation")


-- LAYOUT-FRAME TAGGING (come back to me later)

local function markLayoutFrame(frame)
    frame:SetAttribute("__layout", true)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    return frame
end


-- WIRE TRANSPARENCY (needs changing)

setTransparency = function(alpha)
    alpha = tonumber(alpha) or 0
    window.BackgroundTransparency = math.clamp(alpha, 0, 0.45)
    topBar.BackgroundTransparency = math.clamp(alpha, 0, 0.25)
    sidebar.BackgroundTransparency = math.clamp(alpha, 0, 0.25)
    body.BackgroundTransparency = math.clamp(alpha, 0, 0.35)

    for _, obj in ipairs(window:GetDescendants()) do
        if obj:IsA("Frame") and obj ~= body and obj ~= content then
            if not obj:GetAttribute("__layout") then
                obj.BackgroundTransparency = math.clamp(alpha, 0, 0.6)
            end
        end
    end

    for _, page in pairs(Pages) do
        for _, child in ipairs(page:GetDescendants()) do
            if child:IsA("Frame") then
                if not child:GetAttribute("__layout") then
                    child.BackgroundTransparency = math.clamp(alpha, 0, 0.6)
                end
            end
        end
    end
end


-- UI HELPERS

local function nextOrder(parent)
    local n = (parent:GetAttribute("__lo") or 0) + 1
    parent:SetAttribute("__lo", n)
    return n
end

local function ensureStroke(btn)
    local stroke = btn:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Parent = btn
    end
    stroke.Thickness = 1
    stroke.Transparency = 0.6
    return stroke
end

local function styleToggleButton(btn, isOn)
    local stroke = ensureStroke(btn)
    if isOn then
        btn.BackgroundColor3 = Theme.PanelDark
        btn.TextColor3 = Theme.Accent
        stroke.Color = Theme.Accent
    else
        btn.BackgroundColor3 = Theme.Panel
        btn.TextColor3 = Theme.Text
        stroke.Color = Theme.Border
    end
end

local function uiSection(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.LayoutOrder = nextOrder(parent)
    lbl.Size = UDim2.new(1, 0, 0, 26)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 16
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Theme.Text
    register(lbl, "TextColor3", "Text")
    return lbl
end

local function uiCollapsible(parent, title, defaultOpen)
    local holder = Instance.new("Frame", parent)
    holder.LayoutOrder = nextOrder(parent)
    holder.Size = UDim2.new(1, 0, 0, 34)
    markLayoutFrame(holder)

    local head = Instance.new("TextButton", holder)
    head.Size = UDim2.new(1, 0, 0, 32)
    head.BackgroundColor3 = Theme.Panel
    head.BorderSizePixel = 0
    head.Font = Enum.Font.GothamBold
    head.TextSize = 13
    head.TextXAlignment = Enum.TextXAlignment.Left
    head.TextColor3 = Theme.Text
    head.AutoButtonColor = false
    makeRound(head, 6)
    addStroke(head, Theme.Border, 1, 0.5)
    register(head, "BackgroundColor3", "Panel")
    register(head, "TextColor3", "Text")

    local body = Instance.new("Frame", holder)
    body.Position = UDim2.fromOffset(0, 36)
    body.Size = UDim2.new(1, 0, 0, 0)
    markLayoutFrame(body)

    local bodyLayout = Instance.new("UIListLayout", body)
    bodyLayout.Padding = UDim.new(0, 10)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local bodyPadding = Instance.new("UIPadding", body)
    bodyPadding.PaddingLeft = UDim.new(0, 6)
    bodyPadding.PaddingRight = UDim.new(0, 6)

    local open = defaultOpen ~= false
    local function refresh()
        head.Text = string.format("%s %s", open and "▼" or "▶", title)
        local bodyH = open and (bodyLayout.AbsoluteContentSize.Y + 6) or 0
        body.Size = UDim2.new(1, 0, 0, bodyH)
        holder.Size = UDim2.new(1, 0, 0, 34 + bodyH)
        body.Visible = open
    end

    track(head.MouseButton1Click:Connect(function()
        open = not open
        refresh()
    end))
    track(bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if open then refresh() end
    end))

    ThemeRefreshers[#ThemeRefreshers + 1] = refresh
    refresh()
    return body
end

local function uiToggle(parent, text, initial, callback)
    local btn = Instance.new("TextButton", parent)
    btn.LayoutOrder = nextOrder(parent)
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local state = initial and true or false
    local function refresh()
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        styleToggleButton(btn, state)
    end

    ThemeRefreshers[#ThemeRefreshers + 1] = refresh
    refresh()

    track(btn.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        if callback then callback(state) end
    end))

    local function setState(v, silent)
        state = v and true or false
        refresh()
        if (not silent) and callback then callback(state) end
    end

    local function getState()
        return state
    end

    return btn, setState, getState
end

local function uiButton(parent, text, callback)
    local btn = Instance.new("TextButton", parent)
    btn.LayoutOrder = nextOrder(parent)
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Theme.PanelDark
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Theme.Text
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    register(btn, "BackgroundColor3", "PanelDark")
    register(btn, "TextColor3", "Text")

    track(btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end))

    return btn
end

local function uiTextbox(parent, placeholder, defaultText)
    local tb = Instance.new("TextBox", parent)
    tb.LayoutOrder = nextOrder(parent)
    tb.Size = UDim2.new(1, 0, 0, 32)
    tb.BackgroundColor3 = Theme.PanelDark
    tb.TextColor3 = Theme.Text
    tb.PlaceholderText = placeholder or ""
    tb.ClearTextOnFocus = false
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 14
    tb.BorderSizePixel = 0
    tb.Text = defaultText or ""
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)

    register(tb, "BackgroundColor3", "PanelDark")
    register(tb, "TextColor3", "Text")

    return tb
end

local function uiRow3(parent)
    local row = Instance.new("Frame", parent)
    row.LayoutOrder = nextOrder(parent)
    row.Size = UDim2.new(1, 0, 0, 32)
    markLayoutFrame(row)

    local l = Instance.new("UIListLayout", row)
    l.FillDirection = Enum.FillDirection.Horizontal
    l.HorizontalAlignment = Enum.HorizontalAlignment.Left
    l.VerticalAlignment = Enum.VerticalAlignment.Center
    l.Padding = UDim.new(0, 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder

    return row
end

local function uiSmallBtn(parent, text)
    local b = Instance.new("TextButton", parent)
    b.LayoutOrder = nextOrder(parent)
    b.Size = UDim2.new(0.32, 0, 1, 0)
    b.BackgroundColor3 = Theme.Panel
    b.TextColor3 = Theme.Text
    b.Font = Enum.Font.Gotham
    b.TextSize = 14
    b.Text = text
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    ensureStroke(b)

    register(b, "BackgroundColor3", "Panel")
    register(b, "TextColor3", "Text")

    return b
end

local function uiFieldRow(parent, labelText, defaultText, labelWidthScale)
    labelWidthScale = labelWidthScale or 0.42

    local row = Instance.new("Frame", parent)
    row.LayoutOrder = nextOrder(parent)
    row.Size = UDim2.new(1, 0, 0, 32)
    markLayoutFrame(row)

    local lbl = Instance.new("TextLabel", row)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(labelWidthScale, 0, 1, 0)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Theme.SubText
    lbl.Text = labelText
    register(lbl, "TextColor3", "SubText")

    local tb = Instance.new("TextBox", row)
    tb.Size = UDim2.new(1 - labelWidthScale, 0, 1, 0)
    tb.Position = UDim2.new(labelWidthScale, 0, 0, 0)
    tb.BackgroundColor3 = Theme.PanelDark
    tb.TextColor3 = Theme.Text
    tb.PlaceholderText = ""
    tb.ClearTextOnFocus = false
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 14
    tb.BorderSizePixel = 0
    tb.Text = defaultText or ""
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)

    register(tb, "BackgroundColor3", "PanelDark")
    register(tb, "TextColor3", "Text")

    return tb, row
end


-- FLOATING MEMORY STATS UI - SEPARATE SCREEN GUI

memoryGui = Instance.new("ScreenGui")
memoryGui.Name = "MeerlyNW_MemoryStats"
memoryGui.ResetOnSpawn = false
memoryGui.IgnoreGuiInset = true
memoryGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
memoryGui.Enabled = false
memoryGui.Parent = player:WaitForChild("PlayerGui")

local memWindow = Instance.new("Frame", memoryGui)
memWindow.Size = UDim2.fromOffset(260, 110)
memWindow.Position = UDim2.fromScale(0.74, 0.18)
memWindow.BackgroundColor3 = Theme.Background
memWindow.BorderSizePixel = 0
memWindow.Active = true
memWindow.Draggable = true
register(memWindow, "BackgroundColor3", "Background")
Instance.new("UICorner", memWindow).CornerRadius = UDim.new(0, 10)

local memStroke = Instance.new("UIStroke", memWindow)
memStroke.Thickness = 1
memStroke.Transparency = 0.55
memStroke.Color = Theme.Border
ThemeRefreshers[#ThemeRefreshers + 1] = function()
    if memStroke then memStroke.Color = Theme.Border end
end

local memTitle = Instance.new("TextLabel", memWindow)
memTitle.Size = UDim2.new(1, -16, 0, 20)
memTitle.Position = UDim2.fromOffset(8, 6)
memTitle.BackgroundTransparency = 1
memTitle.Font = Enum.Font.GothamBold
memTitle.TextSize = 14
memTitle.TextXAlignment = Enum.TextXAlignment.Left
memTitle.TextColor3 = Theme.Text
memTitle.Text = "Memory Stats"
register(memTitle, "TextColor3", "Text")

local memEngine = Instance.new("TextLabel", memWindow)
memEngine.Size = UDim2.new(1, -16, 0, 34)
memEngine.Position = UDim2.fromOffset(8, 30)
memEngine.BackgroundTransparency = 1
memEngine.Font = Enum.Font.Gotham
memEngine.TextSize = 13
memEngine.TextXAlignment = Enum.TextXAlignment.Left
memEngine.TextYAlignment = Enum.TextYAlignment.Top
memEngine.TextColor3 = Theme.Text
memEngine.TextWrapped = true
memEngine.Text = "Engine: --"
register(memEngine, "TextColor3", "Text")

local memLua = Instance.new("TextLabel", memWindow)
memLua.Size = UDim2.new(1, -16, 0, 34)
memLua.Position = UDim2.fromOffset(8, 70)
memLua.BackgroundTransparency = 1
memLua.Font = Enum.Font.Gotham
memLua.TextSize = 13
memLua.TextXAlignment = Enum.TextXAlignment.Left
memLua.TextYAlignment = Enum.TextYAlignment.Top
memLua.TextColor3 = Theme.Text
memLua.TextWrapped = true
memLua.Text = "Lua: --"
register(memLua, "TextColor3", "Text")

local memPeakEngine, memPeakLua = 0, 0
local function resetMemoryPeaks()
    memPeakEngine, memPeakLua = 0, 0
end

local function formatMemBlock(label, cur, peak)
    if cur == nil then
        return string.format("%s: --\nPeak: --", label), peak
    end
    if cur > (peak or 0) then
        peak = cur
    end
    return string.format("%s: %.1f MB\nPeak: %.1f MB", label, cur, peak or 0), peak
end

task.spawn(function()
    while running do
        task.wait(1)
        if memoryStatsEnabled and memoryGui and memoryGui.Parent then
            local eng = safeTotalMemMb()
            local lua = luaMemMb()

            local s1
            s1, memPeakEngine = formatMemBlock("Engine", eng, memPeakEngine)
            memEngine.Text = s1

            local s2
            s2, memPeakLua = formatMemBlock("Lua", lua, memPeakLua)
            memLua.Text = s2
        end
    end
end)


-- AUTOMATION PAGE

do
    local page = Pages.Automation

    uiSection(page, "Automation Mode")

    local modeNames = {
        [AutoSkillMode.Off]     = "Auto Skills: OFF",
        [AutoSkillMode.Normal]  = "Auto Skills: ON",
        [AutoSkillMode.Stagger] = "Auto Skills: STAGGER",
    }

    local modeBtn
    local function refreshModeBtn()
        if modeBtn then modeBtn.Text = modeNames[autoSkillMode] end
    end

    modeBtn = uiButton(page, modeNames[autoSkillMode], function()
        autoSkillMode = (autoSkillMode + 1) % 3
        refreshModeBtn()
        status.Text = (autoSkillMode ~= AutoSkillMode.Off) and "● Running" or "● Ready"
        log("Automation", "Auto Skill mode set to " .. modeBtn.Text)
    end)
    ThemeRefreshers[#ThemeRefreshers + 1] = refreshModeBtn

    uiSection(page, "Cooldown Behaviour")

    uiToggle(page, "Adaptive Cooldowns", adaptiveCooldownEnabled, function(v)
        adaptiveCooldownEnabled = v
        log("Automation", "Adaptive Cooldowns set to " .. (v and "ON" or "OFF"))
    end)

    local varBox = uiTextbox(page, "Cooldown variance (number)", tostring(cooldownVariance))
    track(varBox.FocusLost:Connect(function()
        cooldownVariance = tonumber(varBox.Text) or cooldownVariance
        varBox.Text = tostring(cooldownVariance)
    end))

    uiSection(page, "Skills & Stagger Preset")

    local rowSkills = uiRow3(page)
    for _, k in ipairs({ "Q", "E", "R" }) do
        local b = uiSmallBtn(rowSkills, k .. ": " .. (skillEnabled[k] and "ON" or "OFF"))

        local function refreshSkillBtn()
            b.Text = k .. ": " .. (skillEnabled[k] and "ON" or "OFF")
            styleToggleButton(b, skillEnabled[k])
        end
        ThemeRefreshers[#ThemeRefreshers + 1] = refreshSkillBtn
        refreshSkillBtn()

        track(b.MouseButton1Click:Connect(function()
            skillEnabled[k] = not skillEnabled[k]
            refreshSkillBtn()
            log("Skills", k .. " toggle set to " .. (skillEnabled[k] and "ON" or "OFF"))
        end))
    end

    local presetBtn
    local function refreshPresetBtn()
        if presetBtn then
            presetBtn.Text = "Stagger Preset: " .. (staggerLabels[selectedChainMode] or selectedChainMode)
        end
    end

    presetBtn = uiButton(page, "Stagger Preset: " .. (staggerLabels[selectedChainMode] or selectedChainMode), function()
        local idx = table.find(staggerOrder, selectedChainMode) or 1
        idx = (idx % #staggerOrder) + 1
        selectedChainMode = staggerOrder[idx]
        refreshPresetBtn()
        log("Automation", "Stagger preset set to " .. selectedChainMode)
    end)
    ThemeRefreshers[#ThemeRefreshers + 1] = refreshPresetBtn

    uiSection(page, "Auto Clicker")

    local _, setAC, getAC = uiToggle(page, "Auto Clicker", autoClickerEnabled, function(v)
        autoClickerEnabled = v
        log("Clicker", "Auto Clicker set to " .. (v and "ON" or "OFF"))
    end)
    setAutoClickerToggle, getAutoClickerToggle = setAC, getAC

    local clickRateBox = uiTextbox(page, "Clicks/sec (1-30)", tostring(autoClickRate))
    track(clickRateBox.FocusLost:Connect(function()
        local v = tonumber(clickRateBox.Text)
        if v and v > 0 then
            autoClickRate = math.clamp(v, 1, 30)
        end
        clickRateBox.Text = tostring(autoClickRate)
        log("Clicker", "Click rate set to " .. autoClickRate .. " clicks/sec")
    end))

    local note = Instance.new("TextLabel", page)
    note.Size = UDim2.new(1, 0, 0, 46)
    note.BackgroundTransparency = 1
    note.TextWrapped = true
    note.TextXAlignment = Enum.TextXAlignment.Left
    note.TextYAlignment = Enum.TextYAlignment.Top
    note.Font = Enum.Font.Gotham
    note.TextSize = 13
    note.TextColor3 = Theme.SubText
    note.Text =
        "• Auto Skills runs Q/E/R.\n" ..
        "• Auto Clicker supports hotkey F6."
    register(note, "TextColor3", "SubText")
end


-- AUTO SKILLS LOOP

task.spawn(function()
    local staggerIndex = 1
    local lastStaggerFire = 0

    while running do
        task.wait(0.05)

        if autoSkillMode == AutoSkillMode.Off then
            continue
        end

        local enabled = {}
        for _, s in ipairs(skillPriority) do
            if skillEnabled[s] then
                table.insert(enabled, s)
            end
        end
        if #enabled == 0 then
            continue
        end

        if autoSkillMode == AutoSkillMode.Normal then
            local fired = false
            for _, skill in ipairs(enabled) do
                if canUseSkill(skill) then
                    pressKey(SKILL_KEYS[skill])
                    incrementSkillActivation(1)

                    local now = os.clock()
                    skillState[skill].lastUse = now
                    skillState[skill].nextCooldownMs =
                        adaptiveCooldownEnabled
                            and math.floor(randf(COOLDOWN_MIN_MS, COOLDOWN_MAX_MS))
                            or BASE_COOLDOWN_MS

                    log("Skills", "Executed " .. skill)
                    fired = true
                end
            end
            if fired then
                task.wait(0.1)
            end

        elseif autoSkillMode == AutoSkillMode.Stagger then
            local stagger = SKILL_CHAIN_PRESETS[selectedChainMode] or 4
            local now = os.clock()

            if (now - lastStaggerFire) < stagger then
                continue
            end

            local skill = enabled[staggerIndex]
            if skill and canUseSkill(skill) then
                pressKey(SKILL_KEYS[skill])
                incrementSkillActivation(1)

                skillState[skill].lastUse = now
                skillState[skill].nextCooldownMs =
                    adaptiveCooldownEnabled
                        and math.floor(randf(COOLDOWN_MIN_MS, COOLDOWN_MAX_MS))
                        or BASE_COOLDOWN_MS

                log("Skills", "Executed " .. skill .. " (staggered)")

                lastStaggerFire = now
                staggerIndex = (staggerIndex % #enabled) + 1
            end
        end
    end
end)


-- AUTO CLICKER LOOP

local function performClick()
    local pos = UserInputService:GetMouseLocation()
    local x, y = math.floor(pos.X), math.floor(pos.Y)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

task.spawn(function()
    while running do
        if not autoClickerEnabled then
            task.wait(0.2)
        else
            local cps = math.clamp(tonumber(autoClickRate) or 10, 1, 30)
            performClick()
            task.wait(1 / cps)
        end
    end
end)


-- ANTI-AFK LOOP

task.spawn(function()
    local interval = 600
    local nextFire = os.clock() + interval

    while running do
        task.wait(1)
        if antiAfkEnabled then
            if os.clock() >= nextFire then
                pressKey(Enum.KeyCode.Space)
                nextFire = os.clock() + interval
                log("System", "Anti-AFK pulse (Space)")
            end
        else
            nextFire = os.clock() + interval
        end
    end
end)


-- MACRO PAGE (record/play/save/load + loop + walkspeed)

do
    local page = Pages.Macro
    uiSection(page, "Macro Executor")

    local statusLbl = Instance.new("TextLabel", page)
    statusLbl.LayoutOrder = nextOrder(page)
    statusLbl.Size = UDim2.new(1, 0, 0, 26)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 13
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextColor3 = Theme.SubText
    register(statusLbl, "TextColor3", "SubText")
    statusLbl.Text = "Status: Idle"

    local function setMacroStatus(t)
        statusLbl.Text = "Status: " .. tostring(t)
    end

    uiToggle(page, "Loop Playback", false, function(v)
        macroLoopEnabled = v
        log("Macro", "Loop playback set to " .. (v and "ON" or "OFF"))
        if macroPlaying then
            setMacroStatus("Playing (" .. #macroEvents .. " events)" .. (macroLoopEnabled and " [LOOP]" or ""))
        end
    end)

    uiSection(page, "File")
    local fileBox = uiTextbox(page, "Filename (e.g. macro.json)", macroFilename)
    track(fileBox.FocusLost:Connect(function()
        local t = tostring(fileBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if t == "" then t = "macro.json" end
        macroFilename = t
        fileBox.Text = macroFilename
    end))

    uiSection(page, "Controls")

    local row = uiRow3(page)
    local recBtn = uiSmallBtn(row, "Record")
    local playBtn = uiSmallBtn(row, "Play")
    local saveBtn = uiSmallBtn(row, "Save")

    local row2 = uiRow3(page)
    local loadBtn = uiSmallBtn(row2, "Load")
    local clearBtn = uiSmallBtn(row2, "Clear")
    local stopBtn = uiSmallBtn(row2, "Stop")

    local row3 = uiRow3(page)
    local ioTestBtn = uiSmallBtn(row3, "I/O Self-Test")
    ioTestBtn.Size = UDim2.new(1, 0, 1, 0)

    local function refreshRecBtn()
        recBtn.Text = macroRecording and "Recording..." or "Record"
        styleToggleButton(recBtn, macroRecording)
    end
    ThemeRefreshers[#ThemeRefreshers+1] = refreshRecBtn
    refreshRecBtn()

    local function refreshPlayBtn()
        playBtn.Text = macroPlaying and "Playing..." or "Play"
        styleToggleButton(playBtn, macroPlaying)
    end
    ThemeRefreshers[#ThemeRefreshers+1] = refreshPlayBtn
    refreshPlayBtn()

    local function refreshStopBtn()
        stopBtn.Text = (macroRecording or macroPlaying) and "Stop" or "Stop"
        styleToggleButton(stopBtn, (macroRecording or macroPlaying))
    end
    ThemeRefreshers[#ThemeRefreshers+1] = refreshStopBtn
    refreshStopBtn()

    local ALLOWED = {
        W = true, A = true, S = true, D = true,
        SPACE = true, F = true, G = true,
    }

    local KEYCODES = {
        W = Enum.KeyCode.W,
        A = Enum.KeyCode.A,
        S = Enum.KeyCode.S,
        D = Enum.KeyCode.D,
        SPACE = Enum.KeyCode.Space,
        F = Enum.KeyCode.F,
        G = Enum.KeyCode.G,
    }

    local function keyNameFromInput(input)
        if input.KeyCode == Enum.KeyCode.Space then return "SPACE" end
        local name = input.KeyCode.Name
        if ALLOWED[name] then return name end
        return nil
    end

    local function toggleRecord()
        if macroPlaying then
            setMacroStatus("Stop playback before recording.")
            return
        end
        macroRecording = not macroRecording
        if macroRecording then
            macroEvents = {}
            macroStartClock = os.clock()
            setMacroStatus("Recording... (F7 toggles)")
            log("Macro", "Recording started")
        else
            setMacroStatus("Recorded " .. #macroEvents .. " events")
            log("Macro", "Recording stopped (" .. #macroEvents .. " events)")
        end
        refreshRecBtn()
        refreshStopBtn()
    end

    macroHotkeyToggleRecord = toggleRecord
    track(recBtn.MouseButton1Click:Connect(toggleRecord))

    -- Record key events
    track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if __destroyed or not running then return end
        if not macroRecording then return end

        local k = keyNameFromInput(input)
        if not k then return end

        macroEvents[#macroEvents+1] = { t = os.clock() - macroStartClock, k = k, d = 1 }
    end))

    track(UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if __destroyed or not running then return end
        if not macroRecording then return end

        local k = keyNameFromInput(input)
        if not k then return end

        macroEvents[#macroEvents+1] = { t = os.clock() - macroStartClock, k = k, d = 0 }
    end))

    local function playOnce()
        local start = os.clock()
        for i = 1, #macroEvents do
            if not running or __destroyed or not macroPlaying then break end
            local e = macroEvents[i]
            local target = start + (tonumber(e.t) or 0)
            while running and (not __destroyed) and macroPlaying and os.clock() < target do
                task.wait()
            end
            if not running or __destroyed or not macroPlaying then break end

            local kc = KEYCODES[tostring(e.k)]
            if kc then
                VirtualInputManager:SendKeyEvent(e.d == 1, kc, false, game)
            end
        end
    end

    track(playBtn.MouseButton1Click:Connect(function()
        if macroRecording then
            setMacroStatus("Stop recording before playback.")
            return
        end
        if #macroEvents == 0 then
            setMacroStatus("No events to play.")
            return
        end
        if macroPlaying then return end

        macroPlaying = true
        refreshPlayBtn()
        refreshStopBtn()
        setMacroStatus("Playing (" .. #macroEvents .. " events)" .. (macroLoopEnabled and " [LOOP]" or ""))
        log("Macro", "Playback started (" .. #macroEvents .. " events)" .. (macroLoopEnabled and " [LOOP]" or ""))

        task.spawn(function()
            while running and (not __destroyed) and macroPlaying do
                pcall(playOnce)
                if not macroLoopEnabled then break end
                task.wait(0.1)
            end
            macroPlaying = false
            refreshPlayBtn()
            refreshStopBtn()
            setMacroStatus("Idle")
            log("Macro", "Playback stopped")
        end)
    end))

    track(stopBtn.MouseButton1Click:Connect(function()
        if macroRecording then
            macroRecording = false
            refreshRecBtn()
        end
        if macroPlaying then
            macroPlaying = false
            refreshPlayBtn()
        end
        refreshStopBtn()
        setMacroStatus("Idle")
        log("Macro", "Stopped")
    end))

    track(clearBtn.MouseButton1Click:Connect(function()
        if macroRecording or macroPlaying then
            setMacroStatus("Stop first, then clear.")
            return
        end
        macroEvents = {}
        setMacroStatus("Cleared")
        log("Macro", "Macro cleared")
    end))

    track(saveBtn.MouseButton1Click:Connect(function()
        if #macroEvents == 0 then
            setMacroStatus("Nothing to save.")
            return
        end

        local payload = {
            version = 1,
            recordedAt = os.time(),
            keys = { "W","A","S","D","SPACE","F","G" },
            events = macroEvents,
        }

        local json = HttpService:JSONEncode(payload)
        local ok, err = safeWriteFile(macroFilename, json)

        if ok then
            setMacroStatus("Saved: " .. macroFilename)
            log("Macro", "Saved macro to " .. macroFilename)
        else
            setMacroStatus("Save failed (no writefile?)")
            log("Error", "Macro save failed: " .. tostring(err))
        end
    end))

    track(ioTestBtn.MouseButton1Click:Connect(function()
        local ok, msg = runFileIOSelfTest("macro_io")
        if ok then
            setMacroStatus("I/O test passed: " .. msg)
            log("System", "Macro I/O self-test passed: " .. msg)
        else
            setMacroStatus("I/O test failed: " .. msg)
            log("Error", "Macro I/O self-test failed: " .. msg)
        end
    end))

    track(loadBtn.MouseButton1Click:Connect(function()
        if macroRecording or macroPlaying then
            setMacroStatus("Stop first, then load.")
            return
        end

        local ok, data = safeReadFile(macroFilename)
        if not ok then
            setMacroStatus("Load failed (no readfile?)")
            log("Error", "Macro load failed: " .. tostring(data))
            return
        end

        local decoded
        local ok2, err2 = pcall(function()
            decoded = HttpService:JSONDecode(data)
        end)
        if not ok2 or type(decoded) ~= "table" then
            setMacroStatus("Invalid JSON")
            log("Error", "Macro JSON decode failed: " .. tostring(err2))
            return
        end

        if type(decoded.events) ~= "table" then
            setMacroStatus("Invalid macro file")
            return
        end

        macroEvents = decoded.events
        setMacroStatus("Loaded " .. #macroEvents .. " events")
        log("Macro", "Loaded macro from " .. macroFilename .. " (" .. #macroEvents .. " events)")
    end))

    uiSection(page, "WalkSpeed (your game)")

    local wsBox = uiTextbox(page, "WalkSpeed (number)", "16")
    local function setWalkSpeed(value)
        local char = player.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        hum.WalkSpeed = value
    end

    uiButton(page, "Apply WalkSpeed", function()
        local v = tonumber(wsBox.Text)
        if not v then
            setMacroStatus("WalkSpeed invalid")
            return
        end
        setWalkSpeed(v)
        setMacroStatus("WalkSpeed set to " .. v)
        log("System", "WalkSpeed set to " .. v)
    end)

    track(player.CharacterAdded:Connect(function()
        task.wait(1)
        local v = tonumber(wsBox.Text)
        if v then pcall(function() setWalkSpeed(v) end) end
    end))

    local note = Instance.new("TextLabel", page)
    note.LayoutOrder = nextOrder(page)
    note.Size = UDim2.new(1, 0, 0, 60)
    note.BackgroundTransparency = 1
    note.TextWrapped = true
    note.TextXAlignment = Enum.TextXAlignment.Left
    note.TextYAlignment = Enum.TextYAlignment.Top
    note.Font = Enum.Font.Gotham
    note.TextSize = 13
    note.TextColor3 = Theme.SubText
    register(note, "TextColor3", "SubText")
    note.Text =
        "• Record: W/A/S/D/SPACE/F/G\n" ..
        "• Hotkey: F7 toggles record\n" ..
        "• Save/Load uses writefile/readfile when available."
end


-- CALCULATORS PAGE

do
    local page = Pages.Calculators
    uiSection(page, "Calculators")

    local xpBody = uiCollapsible(page, "XP Calculator (v3)", true)

    local inputs = {}
    local function addXPInput(labelText, defaultText)
        local tb = uiFieldRow(xpBody, labelText, defaultText, 0.42)
        inputs[labelText] = tb
        return tb
    end

    addXPInput("Auto Damage", "0")
    addXPInput("Enemy HP", "0,0")
    addXPInput("Enemy XP %", "0,0")
    addXPInput("XP Multiplier", "1")
    addXPInput("2x Potions (10m)", "0")
    addXPInput("3x Potions (10m)", "0")
    addXPInput("Current XP %", "0")

    uiSection(xpBody, "Skill Modifiers")

    local calcSkills = { Q = false, E = false, R = false }
    local skillMultiplier = { Q = 200, E = 200, R = 200 }

    local rowSkill = uiRow3(xpBody)
    local rowMult  = uiRow3(xpBody)

    local r1 = Instance.new("TextLabel", xpBody)
    r1.LayoutOrder = nextOrder(xpBody)
    r1.Size = UDim2.new(1, 0, 0, 24)
    r1.BackgroundTransparency = 1
    r1.Font = Enum.Font.Gotham
    r1.TextSize = 14
    r1.TextXAlignment = Enum.TextXAlignment.Left
    r1.TextColor3 = Theme.SubText
    register(r1, "TextColor3", "SubText")
    r1.Text = "XP/hr: --"

    local r2 = Instance.new("TextLabel", xpBody)
    r2.LayoutOrder = nextOrder(xpBody)
    r2.Size = UDim2.new(1, 0, 0, 24)
    r2.BackgroundTransparency = 1
    r2.Font = Enum.Font.Gotham
    r2.TextSize = 14
    r2.TextXAlignment = Enum.TextXAlignment.Left
    r2.TextColor3 = Theme.SubText
    register(r2, "TextColor3", "SubText")
    r2.Text = "Time to 100%: --"

    local function splitCsvNums(sv)
        local out = {}
        for token in string.gmatch((sv or ""), "([^,]+)") do
            local cleaned = token:gsub("%%", ""):gsub("%s+", "")
            local n = tonumber(cleaned)
            if n then out[#out+1] = n end
        end
        return out
    end

    local function parseNum(text)
        if text == nil then return nil end
        local cleaned = tostring(text):gsub("%%", ""):gsub("%s+", "")
        if cleaned == "" then return nil end
        return tonumber(cleaned)
    end

    local function recalcXP()
        local dmg = parseNum(inputs["Auto Damage"].Text)
        local curXP = parseNum(inputs["Current XP %"].Text)
        if not dmg or not curXP then return end

        local totalDPS = effectiveDPS(dmg, calcSkills, skillMultiplier)
        local hps = splitCsvNums(inputs["Enemy HP"].Text)
        local xps = splitCsvNums(inputs["Enemy XP %"].Text)

        local baseXPhr = 0
        for i = 1, math.min(#hps, #xps) do
            local hp = hps[i]
            local xpVal = xps[i]
            if hp and xpVal and hp > 0 then
                baseXPhr += (xpVal / (hp / totalDPS)) * 3600
            end
        end

        local xpMul = parseNum(inputs["XP Multiplier"].Text) or 1
        if xpMul <= 0 then xpMul = 1 end
        baseXPhr = baseXPhr * xpMul

        local pot2x = math.max(0, parseNum(inputs["2x Potions (10m)"].Text) or 0)
        local pot3x = math.max(0, parseNum(inputs["3x Potions (10m)"].Text) or 0)

        local baseXPps = baseXPhr / 3600
        local remainingXP = math.max(0, 100 - curXP)
        local secondsTo100 = 0

        local segments = {
            { seconds = pot3x * 600, mult = 3 },
            { seconds = pot2x * 600, mult = 2 },
            { seconds = math.huge, mult = 1 },
        }

        if baseXPps <= 0 then
            secondsTo100 = math.huge
        else
            for _, seg in ipairs(segments) do
                if remainingXP <= 0 then break end
                local rate = baseXPps * seg.mult
                if rate <= 0 then
                    secondsTo100 = math.huge
                    break
                end

                if seg.seconds == math.huge then
                    secondsTo100 += (remainingXP / rate)
                    remainingXP = 0
                else
                    local segmentGain = rate * seg.seconds
                    if segmentGain >= remainingXP then
                        secondsTo100 += (remainingXP / rate)
                        remainingXP = 0
                    else
                        remainingXP -= segmentGain
                        secondsTo100 += seg.seconds
                    end
                end
            end
        end

        local totalPotionMinutes = (pot3x + pot2x) * 10
        r1.Text = string.format("XP/hr: %.2f%% | Potions: 3x %.0fm -> 2x %.0fm (total %.0fm)", baseXPhr, pot3x * 10, pot2x * 10, totalPotionMinutes)
        if secondsTo100 == math.huge then
            r2.Text = "Time to 100%: --"
        else
            local hoursTo100 = secondsTo100 / 3600
            r2.Text = string.format("Time to 100%%: %.2f hrs (%.1f mins)", hoursTo100, secondsTo100 / 60)
        end

        log("XP", "Recalculated XP/hr")
    end

    for _, k in ipairs({ "Q", "E", "R" }) do
        local sbtn = uiSmallBtn(rowSkill, k .. ": OFF")
        local mbtn = uiSmallBtn(rowMult,  skillMultiplier[k] .. "%")

        local function refreshXpSkillBtn()
            sbtn.Text = k .. ": " .. (calcSkills[k] and "ON" or "OFF")
            styleToggleButton(sbtn, calcSkills[k])
        end

        local function refreshXpMultBtn()
            mbtn.Text = skillMultiplier[k] .. "%"
            styleToggleButton(mbtn, skillMultiplier[k] == 250)
        end

        ThemeRefreshers[#ThemeRefreshers + 1] = refreshXpSkillBtn
        ThemeRefreshers[#ThemeRefreshers + 1] = refreshXpMultBtn
        refreshXpSkillBtn()
        refreshXpMultBtn()

        track(sbtn.MouseButton1Click:Connect(function()
            calcSkills[k] = not calcSkills[k]
            refreshXpSkillBtn()
            recalcXP()
        end))

        track(mbtn.MouseButton1Click:Connect(function()
            skillMultiplier[k] = (skillMultiplier[k] == 200) and 250 or 200
            refreshXpMultBtn()
            recalcXP()
        end))
    end

    for _, tb in pairs(inputs) do
        track(tb.FocusLost:Connect(recalcXP))
    end

    uiButton(xpBody, "Recalculate", recalcXP)
    task.defer(recalcXP)

    local bossBody = uiCollapsible(page, "Boss Calculator (v2.4)", false)

    local bossInputs = {}
    local function addBossInput(labelText, defaultText)
        local tb = uiFieldRow(bossBody, labelText, defaultText, 0.42)
        bossInputs[labelText] = tb
        return tb
    end

    addBossInput("Self HP", "1000")
    addBossInput("Self DPS", "50")
    addBossInput("Enemy HP", "2000")
    addBossInput("Enemy DMG", "100")

    uiSection(bossBody, "Skill Modifiers")

    local bossCalcSkills = { Q = false, E = false, R = false }
    local bossSkillMultiplier = { Q = 200, E = 200, R = 200 }

    local rowSkillB = uiRow3(bossBody)
    local rowMultB  = uiRow3(bossBody)

    uiSection(bossBody, "Boss Mode")
    local bossModeEnabled = false
    local bossModeBtn
    bossModeBtn = uiButton(bossBody, "Boss Mode: OFF", function()
        bossModeEnabled = not bossModeEnabled
        bossModeBtn.Text = "Boss Mode: " .. (bossModeEnabled and "ON" or "OFF")
    end)

    uiSection(bossBody, "Result")
    local br = Instance.new("TextLabel", bossBody)
    br.LayoutOrder = nextOrder(bossBody)
    br.Size = UDim2.new(1, 0, 0, 32)
    br.BackgroundTransparency = 1
    br.Font = Enum.Font.Gotham
    br.TextSize = 14
    br.TextXAlignment = Enum.TextXAlignment.Left
    br.TextColor3 = Theme.SubText
    register(br, "TextColor3", "SubText")
    br.Text = "Result: --"

    local function recalcBoss()
        local selfHP   = tonumber(bossInputs["Self HP"].Text)
        local baseDPS  = tonumber(bossInputs["Self DPS"].Text)
        local enemyHP  = tonumber(bossInputs["Enemy HP"].Text)
        local enemyDMG = tonumber(bossInputs["Enemy DMG"].Text)

        if not selfHP or not baseDPS or not enemyHP or not enemyDMG then
            br.Text = "Result: Invalid inputs"
            return
        end

        local selfDPS = effectiveDPS(baseDPS, bossCalcSkills, bossSkillMultiplier)
        local enemyInterval = bossModeEnabled and 3.5 or 2

        local timeToKill = enemyHP / selfDPS
        local timeToDie  = selfHP / (enemyDMG / enemyInterval)

        if timeToKill < timeToDie then
            br.Text = string.format("You win! Kill in %.2fs before dying.", timeToKill)
        elseif timeToKill > timeToDie then
            br.Text = string.format("You die! Enemy kills you in %.2fs.", timeToDie)
        else
            br.Text = string.format("Simultaneous! Both die at %.2fs.", timeToKill)
        end

        log("Boss", "Recalculated boss result")
    end

    track(bossModeBtn.MouseButton1Click:Connect(recalcBoss))

    for _, k in ipairs({ "Q", "E", "R" }) do
        local sbtn = uiSmallBtn(rowSkillB, k .. ": OFF")
        local mbtn = uiSmallBtn(rowMultB, bossSkillMultiplier[k] .. "%")

        local function refreshBossSkillBtn()
            sbtn.Text = k .. ": " .. (bossCalcSkills[k] and "ON" or "OFF")
            styleToggleButton(sbtn, bossCalcSkills[k])
        end

        local function refreshBossMultBtn()
            mbtn.Text = bossSkillMultiplier[k] .. "%"
            styleToggleButton(mbtn, bossSkillMultiplier[k] == 250)
        end

        ThemeRefreshers[#ThemeRefreshers + 1] = refreshBossSkillBtn
        ThemeRefreshers[#ThemeRefreshers + 1] = refreshBossMultBtn
        refreshBossSkillBtn()
        refreshBossMultBtn()

        track(sbtn.MouseButton1Click:Connect(function()
            bossCalcSkills[k] = not bossCalcSkills[k]
            refreshBossSkillBtn()
            recalcBoss()
        end))

        track(mbtn.MouseButton1Click:Connect(function()
            bossSkillMultiplier[k] = (bossSkillMultiplier[k] == 200) and 250 or 200
            refreshBossMultBtn()
            recalcBoss()
        end))
    end

    for _, tb in pairs(bossInputs) do
        track(tb.FocusLost:Connect(recalcBoss))
    end

    uiButton(bossBody, "Recalculate", recalcBoss)
    task.defer(recalcBoss)
end


-- MISC PAGE

do
    local page = Pages.Misc
    uiSection(page, "Quick Actions")

    uiButton(page, "Rejoin Server", function()
        local placeId = game.PlaceId
        local jobId = game.JobId
        log("System", "Rejoining current server...")
        task.spawn(function()
            local ok, err = pcall(function()
                if jobId and jobId ~= "" then
                    TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
                else
                    TeleportService:Teleport(placeId, player)
                end
            end)
            if not ok then
                log("Error", "Rejoin failed: " .. tostring(err))
            end
        end)
    end)

    uiSection(page, "AFK & Camera")

    uiToggle(page, "Anti-AFK", _G.__MeerlyState.antiAfkEnabled == true, function(v)
        antiAfkEnabled = v
        _G.__MeerlyState.antiAfkEnabled = v
        log("System", v and "Anti-AFK enabled" or "Anti-AFK disabled")
    end)

    uiToggle(page, "Watchdog", _G.__MeerlyState.watchdogEnabled == true, function(v)
        watchdogEnabled = v
        _G.__MeerlyState.watchdogEnabled = v
        log("System", v and "Watchdog enabled" or "Watchdog disabled")
    end)

    uiToggle(page, "Memory Stats", false, function(v)
        memoryStatsEnabled = v
        memoryGui.Enabled = v
        if v then
            resetMemoryPeaks()
            log("System", "Memory Stats UI enabled")
        else
            log("System", "Memory Stats UI disabled")
        end
    end)

    local Camera = workspace.CurrentCamera

    local function applyAFKCamera()
        if not AFKCameraEnabled then return end
        if not Camera then Camera = workspace.CurrentCamera end
        if not Camera then return end
        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CameraSubject = nil
        Camera.CFrame = CFrame.new(0, 10000, 0)
    end

    local function restoreCamera()
        if not Camera then Camera = workspace.CurrentCamera end
        if not Camera then return end
        Camera.CameraType = savedCameraType or Enum.CameraType.Custom
        Camera.CameraSubject = savedCameraSubject
        Camera.CFrame = savedCameraCFrame or Camera.CFrame
    end

    uiToggle(page, "AFK Camera Mode", AFKCameraEnabled, function(v)
        AFKCameraEnabled = v
        if v then
            savedCameraType = Camera.CameraType
            savedCameraSubject = Camera.CameraSubject
            savedCameraCFrame = Camera.CFrame
            applyAFKCamera()
            log("System", "AFK Camera enabled (render minimised)")
        else
            restoreCamera()
            log("System", "AFK Camera disabled (restored)")
        end
    end)

    track(RunService.Heartbeat:Connect(function()
        if AFKCameraEnabled then applyAFKCamera() end
    end))

    uiToggle(page, "Zoom Unlock", zoomUnlockEnabled, function(v)
        zoomUnlockEnabled = v
        if v then
            player.CameraMinZoomDistance = 0.5
            player.CameraMaxZoomDistance = 1000
            log("System", "Camera zoom unlocked")
        else
            player.CameraMinZoomDistance = originalMinZoom
            player.CameraMaxZoomDistance = originalMaxZoom
            log("System", "Camera zoom restored")
        end
    end)

    uiSection(page, "Performance & Background")

    uiToggle(page, "FPS Cap", fpsCapEnabled, function(v)
        fpsCapEnabled = v
        if fpsCapEnabled and setfpscap then
            setfpscap(targetFPS)
            log("System", "FPS cap set to " .. targetFPS)
        elseif fpsCapEnabled then
            log("System", "FPS cap unsupported by executor")
        else
            if setfpscap then
                setfpscap(0)
                log("System", "FPS cap removed")
            end
        end
    end)

    local fpsBox = uiTextbox(page, "Target FPS (30–240)", tostring(targetFPS))
    track(fpsBox.FocusLost:Connect(function()
        local v = tonumber(fpsBox.Text)
        if v and v >= 30 and v <= 240 then
            targetFPS = v
            fpsBox.Text = tostring(targetFPS)
            if fpsCapEnabled and setfpscap then
                setfpscap(targetFPS)
                log("System", "FPS cap updated to " .. targetFPS)
            end
        else
            fpsBox.Text = tostring(targetFPS)
        end
    end))

    local function applyVisuals(disable)
        Lighting.GlobalShadows = not disable
        Lighting.FogEnd = disable and 1e6 or 100000
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") then
                v.Enabled = not disable
            end
        end
    end

    uiToggle(page, "Low Graphics Mode", visualsDisabled, function(v)
        visualsDisabled = v
        applyVisuals(v)
        log("System", v and "Visual effects disabled" or "Visual effects restored")
    end)

    uiToggle(page, "Streaming Optimization", streamingOptimized, function(v)
        streamingOptimized = v
        if v then
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            pcall(function() settings().Network.IncomingReplicationLag = 0.1 end)
            log("System", "Streaming optimization enabled")
        else
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
            log("System", "Streaming optimization disabled")
        end
    end)

    uiToggle(page, "Background Survival Mode", backgroundMode, function(v)
        backgroundMode = v
        log("System", v and "Background survival enabled — optimized for tabbed-out AFK" or "Background survival disabled")
    end)

    uiToggle(page, "Disable 3D Rendering", false, function(v)
        if RunService.Set3dRenderingEnabled then
            pcall(function() RunService:Set3dRenderingEnabled(not v) end)
            log("System", v and "3D rendering disabled" or "3D rendering enabled")
        else
            log("System", "3D rendering toggle unsupported")
        end
    end)

    uiToggle(page, "Mute Game Sounds", false, function(v)
        pcall(function() game:GetService("SoundService").RespectFilteringEnabled = true end)
        pcall(function()
            local ss = game:GetService("SoundService")
            ss.Volume = v and 0 or 1
        end)
        log("System", v and "Sounds muted" or "Sounds unmuted")
    end)

    track(UserInputService.WindowFocused:Connect(function()
        windowFocused = true
        if backgroundMode then log("System", "Window focused — exiting background mode") end
    end))

    track(UserInputService.WindowFocusReleased:Connect(function()
        windowFocused = false
        if backgroundMode then log("System", "Window unfocused — background mode active") end
    end))

    task.spawn(function()
        while running do
            task.wait(2)
            if backgroundMode and not windowFocused then
                pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            end
        end
    end)

    track(RunService.Heartbeat:Connect(function()
        local now = os.clock()
        local prev = _G.__MeerlyState.lastHeartbeat or now
        local delta = now - prev
        _G.__MeerlyState.lastHeartbeat = now
        if delta > heartbeatLagThreshold then
            log("System", string.format("⚠️ Heartbeat lag detected: %.2fs gap", delta))
        end
    end))

    uiSection(page, "Memory Guard")

    local modeBtn = uiButton(page, "Memory Action: Off", nil)
    local modes = { "Off", "AutoRejoin", "AutoQuit" }
    local function refreshModeBtn()
        modeBtn.Text = "Memory Action: " .. memoryGuardMode
    end
    local function cycleMode()
        local idx = table.find(modes, memoryGuardMode) or 1
        idx = (idx % #modes) + 1
        memoryGuardMode = modes[idx]
        refreshModeBtn()
        log("System", "Memory guard mode set to " .. memoryGuardMode)
    end
    track(modeBtn.MouseButton1Click:Connect(cycleMode))
    refreshModeBtn()

    local capBox, _ = uiFieldRow(page, "Combined Lua+Engine Cap (GB)", tostring(memoryGuardCapGB), 0.58)
    track(capBox.FocusLost:Connect(function()
        local v = tonumber(capBox.Text)
        if v and v >= 0.5 and v <= 128 then
            memoryGuardCapGB = v
        end
        capBox.Text = tostring(memoryGuardCapGB)
    end))

    uiSection(page, "Safety")
    uiButton(page, "KILL SWITCH (Destroy UI)", function()
        killSwitch("button")
    end)

    local info = Instance.new("TextLabel", page)
    info.Size = UDim2.new(1, 0, 0, 84)
    info.BackgroundTransparency = 1
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.Font = Enum.Font.Gotham
    info.TextSize = 14
    info.TextColor3 = Theme.SubText
    register(info, "TextColor3", "SubText")
    info.Text =
        "• Anti-AFK presses Space every 10 minutes.\n" ..
        "• Memory Stats is a separate floating UI (doesn't hide with ;).\n" ..
        "• Kill Switch destroys everything."
end


-- WATCHDOG LOOP

local watchdogThreshold = 4
_G.__MeerlyState.lastHeartbeat = _G.__MeerlyState.lastHeartbeat or os.clock()

task.spawn(function()
    while running do
        task.wait(1)
        if not _G.__MeerlyState.watchdogEnabled then
            continue
        end

        local delta = os.clock() - (_G.__MeerlyState.lastHeartbeat or os.clock())
        if delta > watchdogThreshold then
            log("System", string.format("Watchdog warning: heartbeat delayed (%.2fs)", delta))
        end
    end
end)


-- MEMORY/PERFORMANCE LOOP

do
    task.spawn(function()
        while running do
            task.wait(5)
            local now = os.clock()
            local combinedGb, luaGb, totalGb = getCombinedMemoryGb()

            if memoryGuardMode ~= "Off" and combinedGb >= memoryGuardCapGB and (now - lastMemoryGuardAction) >= memoryGuardCooldown then
                lastMemoryGuardAction = now
                log("System", string.format("Memory guard triggered at %.2f GB (cap %.2f GB): %s", combinedGb, memoryGuardCapGB, memoryGuardMode))
                if memoryGuardMode == "AutoRejoin" then
                    task.spawn(function()
                        local ok, err = pcall(function()
                            if game.JobId and game.JobId ~= "" then
                                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
                            else
                                TeleportService:Teleport(game.PlaceId, player)
                            end
                        end)
                        if not ok then
                            log("Error", "AutoRejoin failed: " .. tostring(err))
                        end
                    end)
                elseif memoryGuardMode == "AutoQuit" then
                    pcall(function() player:Kick("AutoQuit: memory cap exceeded") end)
                    killSwitch("Memory guard auto-quit")
                end
            end

            if now - lastMemoryLog >= memoryLogInterval then
                lastMemoryLog = now
                if totalGb then
                    log("System", string.format("Memory: Lua %.2f GB | Total %.2f GB", luaGb, totalGb))
                else
                    log("System", string.format("Memory: Lua %.2f GB", luaGb))
                end
            end
        end
    end)
end


-- CLICKER PAGE

do
    local page = Pages.Clicker

    uiSection(page, "AFK Mini Clicker (Lightweight)")

    local _, setRunBtnState = uiToggle(page, "Mini Game", clickerRunning, function(v)
        clickerRunning = v
    end)
    setRunBtnState(clickerRunning, true)

    local statusLabel = Instance.new("TextLabel", page)
    statusLabel.LayoutOrder = nextOrder(page)
    statusLabel.Size = UDim2.new(1, 0, 0, 56)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextYAlignment = Enum.TextYAlignment.Top
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 13
    statusLabel.TextWrapped = true
    statusLabel.TextColor3 = Theme.SubText
    register(statusLabel, "TextColor3", "SubText")

    local shapeWrap = Instance.new("Frame", page)
    shapeWrap.LayoutOrder = nextOrder(page)
    shapeWrap.Size = UDim2.new(1, 0, 0, 130)
    shapeWrap.BackgroundColor3 = Theme.PanelDark
    shapeWrap.BorderSizePixel = 0
    makeRound(shapeWrap, 8)
    addStroke(shapeWrap, Theme.Border, 1, 0.45)
    register(shapeWrap, "BackgroundColor3", "PanelDark")

    local shapeTitle = Instance.new("TextLabel", shapeWrap)
    shapeTitle.Size = UDim2.new(1, -12, 0, 20)
    shapeTitle.Position = UDim2.fromOffset(8, 6)
    shapeTitle.BackgroundTransparency = 1
    shapeTitle.Font = Enum.Font.Gotham
    shapeTitle.TextSize = 12
    shapeTitle.TextXAlignment = Enum.TextXAlignment.Left
    shapeTitle.TextColor3 = Theme.SubText
    register(shapeTitle, "TextColor3", "SubText")

    local shapeCanvas = Instance.new("Frame", shapeWrap)
    shapeCanvas.Size = UDim2.fromOffset(94, 94)
    shapeCanvas.Position = UDim2.new(0.5, -47, 0, 28)
    shapeCanvas.BackgroundTransparency = 1

    local shapeEdges = table.create(9)
    for i = 1, 9 do
        local edge = Instance.new("Frame", shapeCanvas)
        edge.AnchorPoint = Vector2.new(0.5, 0.5)
        edge.Size = UDim2.fromOffset(2, 2)
        edge.BorderSizePixel = 0
        edge.Visible = false
        edge.BackgroundColor3 = Theme.Accent
        register(edge, "BackgroundColor3", "Accent")
        shapeEdges[i] = edge
    end

    local upgradeFrame = Instance.new("Frame", page)
    upgradeFrame.LayoutOrder = nextOrder(page)
    upgradeFrame.Size = UDim2.new(1, 0, 0, 318)
    markLayoutFrame(upgradeFrame)

    local upgradeGrid = Instance.new("UIGridLayout", upgradeFrame)
    upgradeGrid.CellSize = UDim2.new(0.49, 0, 0, 72)
    upgradeGrid.CellPadding = UDim2.fromOffset(8, 8)
    upgradeGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    upgradeGrid.VerticalAlignment = Enum.VerticalAlignment.Top

    local upgradeButtons = {}
    local refreshClickerView
    for _, def in ipairs(CLICKER_UPGRADES) do
        local btn = Instance.new("TextButton", upgradeFrame)
        btn.BackgroundColor3 = Theme.Panel
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextWrapped = true
        btn.TextColor3 = Theme.Text
        makeRound(btn, 6)
        ensureStroke(btn)
        register(btn, "BackgroundColor3", "Panel")
        register(btn, "TextColor3", "Text")

        track(btn.MouseButton1Click:Connect(function()
            if not clickerRunning then return end
            local level = clickerUpgradeLevels[def.id] or 0
            local cost = clickerUpgradeCost(def, level)
            if clickerScore < cost then
                log("Clicker", string.format("%s requires %d", def.name, cost))
                return
            end
            clickerScore -= cost
            clickerUpgradeLevels[def.id] = level + 1
            recalcClickerStats()
            refreshClickerView()
        end))

        upgradeButtons[#upgradeButtons + 1] = { def = def, btn = btn }
    end

    local actionRow = uiRow3(page)
    local clickBtn = uiSmallBtn(actionRow, "Click")
    local resetBtn = uiSmallBtn(actionRow, "Reset")
    local saveBtn = uiSmallBtn(actionRow, "Save")

    track(clickBtn.MouseButton1Click:Connect(function()
        if not clickerRunning then return end
        addClickerScore(clickPower)
        refreshClickerView()
    end))

    track(resetBtn.MouseButton1Click:Connect(function()
        clickerScore = 0
        clickerUpgradeLevels = newClickerUpgradeLevels()
        clickerShapeVertices = 3
        clickerShapeCycle = 0
        clickerShapeProgress = 0
        clickerShapeMilestone = 25
        clickerPassiveCarry = 0
        recalcClickerStats()
        refreshClickerView()
    end))

    track(saveBtn.MouseButton1Click:Connect(function()
        saveClickerHighScore(true)
        log("Clicker", "Saved: " .. clickerHighScoreFile .. " + " .. clickerStateFile)
    end))

    local function updateShapeVisual()
        local n = math.clamp(clickerShapeVertices, 3, 9)
        local radius = 36
        local cx, cy = 47, 47
        local palette = {
            Color3.fromRGB(120, 180, 255),
            Color3.fromRGB(140, 230, 160),
            Color3.fromRGB(255, 175, 95),
            Color3.fromRGB(220, 135, 255),
            Color3.fromRGB(255, 110, 145),
            Color3.fromRGB(255, 230, 120),
        }
        local c = palette[(clickerShapeCycle % #palette) + 1]

        for i = 1, 9 do
            local edge = shapeEdges[i]
            if i <= n then
                local a1 = ((i - 1) / n) * (2 * math.pi) - (math.pi / 2)
                local a2 = (i / n) * (2 * math.pi) - (math.pi / 2)
                local x1 = cx + (math.cos(a1) * radius)
                local y1 = cy + (math.sin(a1) * radius)
                local x2 = cx + (math.cos(a2) * radius)
                local y2 = cy + (math.sin(a2) * radius)
                local dx, dy = x2 - x1, y2 - y1
                local len = math.sqrt((dx * dx) + (dy * dy))

                edge.Visible = true
                edge.BackgroundColor3 = c
                edge.Size = UDim2.fromOffset(math.max(2, len), 2)
                edge.Position = UDim2.fromOffset((x1 + x2) * 0.5, (y1 + y2) * 0.5)
                edge.Rotation = angleDeg(dy, dx)
            else
                edge.Visible = false
            end
        end

        shapeTitle.Text = string.format(
            "Shape: %d-gon | Next vertex in %d clicks | Cycle %d",
            n,
            math.max(0, clickerShapeMilestone - clickerShapeProgress),
            clickerShapeCycle
        )
    end

    function refreshClickerView()
        statusLabel.Text = string.format(
            "State: %s\nScore: %d | High: %d | Click: +%d | Passive: +%d/s",
            clickerRunning and "RUNNING" or "PAUSED",
            clickerScore,
            clickerHighScore,
            clickPower,
            passiveIncomePerSec
        )

        for _, item in ipairs(upgradeButtons) do
            local def = item.def
            local lv = clickerUpgradeLevels[def.id] or 0
            local cost = clickerUpgradeCost(def, lv)
            item.btn.Text = string.format("%s\nLv %d | Cost %d", def.name, lv, cost)
        end

        updateShapeVisual()
    end

    ThemeRefreshers[#ThemeRefreshers + 1] = refreshClickerView
    refreshClickerView()

    task.spawn(function()
        local lastTick = os.clock()
        local lastCull = os.clock()
        while running and not __destroyed do
            task.wait(0.25)
            local ok, err = pcall(function()
                local now = os.clock()

                if clickerRunning and passiveIncomePerSec > 0 then
                    local dt = now - lastTick
                    if dt > 0 then
                        local gained = (passiveIncomePerSec * dt) + clickerPassiveCarry
                        local whole = math.floor(gained)
                        clickerPassiveCarry = gained - whole
                        if whole > 0 then
                            addClickerScore(whole)
                        end
                    end
                end
                lastTick = now

                if now - clickerLastSave >= CLICKER_AUTOSAVE_SEC then
                    saveClickerHighScore(true)
                end

                if now - lastCull >= CLICKER_STATE_CULL_SEC then
                    lastCull = now
                    gcinfo()
                end

                refreshClickerView()
            end)

            if not ok then
                log("Error", "Clicker loop error: " .. tostring(err))
                task.wait(1)
            end
        end
    end)
end


-- STATISTICS PAGE

do
    local page = Pages.Statistics

    uiSection(page, "Statistics / Achievements")

    local summaryLabel = Instance.new("TextLabel", page)
    summaryLabel.LayoutOrder = nextOrder(page)
    summaryLabel.Size = UDim2.new(1, 0, 0, 42)
    summaryLabel.BackgroundTransparency = 1
    summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
    summaryLabel.TextYAlignment = Enum.TextYAlignment.Top
    summaryLabel.Font = Enum.Font.Gotham
    summaryLabel.TextSize = 13
    summaryLabel.TextWrapped = true
    summaryLabel.TextColor3 = Theme.SubText
    register(summaryLabel, "TextColor3", "SubText")

    local function createAchievementCard(titleText, height)
        local card = Instance.new("Frame", page)
        card.LayoutOrder = nextOrder(page)
        card.Size = UDim2.new(1, 0, 0, height or 78)
        card.BackgroundColor3 = Theme.PanelDark
        card.BorderSizePixel = 0
        makeRound(card, 8)
        register(card, "BackgroundColor3", "PanelDark")

        local stroke = addStroke(card, STAT_TIERS.None.color, 1.25, 0.12)

        local title = Instance.new("TextLabel", card)
        title.Size = UDim2.new(1, -16, 0, 22)
        title.Position = UDim2.fromOffset(8, 8)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Theme.Text
        title.Text = titleText
        register(title, "TextColor3", "Text")

        local detail = Instance.new("TextLabel", card)
        detail.Size = UDim2.new(1, -16, 0, (height or 78) - 36)
        detail.Position = UDim2.fromOffset(8, 30)
        detail.BackgroundTransparency = 1
        detail.Font = Enum.Font.Gotham
        detail.TextSize = 12
        detail.TextWrapped = true
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.TextYAlignment = Enum.TextYAlignment.Top
        detail.TextColor3 = Theme.SubText
        register(detail, "TextColor3", "SubText")

        return card, detail, stroke
    end

    local _, clickerDetail, clickerStroke = createAchievementCard("High Score in Clicker mini game")
    local progressionCard, progressionDetail, progressionStroke = createAchievementCard("Clicker Progression", 96)
    local _, sessionDetail, sessionStroke = createAchievementCard("Longest Session")
    local _, skillsDetail, skillsStroke = createAchievementCard("Total Skills Activated")

    progressionDetail.Size = UDim2.new(1, -124, 0, 60)

    local progressionPreview = Instance.new("Frame", progressionCard)
    progressionPreview.Size = UDim2.fromOffset(86, 62)
    progressionPreview.Position = UDim2.new(1, -94, 0, 18)
    progressionPreview.BackgroundTransparency = 1

    local previewEdges = table.create(9)
    for i = 1, 9 do
        local edge = Instance.new("Frame", progressionPreview)
        edge.AnchorPoint = Vector2.new(0.5, 0.5)
        edge.Size = UDim2.fromOffset(2, 2)
        edge.BorderSizePixel = 0
        edge.Visible = false
        edge.BackgroundColor3 = Theme.Accent
        register(edge, "BackgroundColor3", "Accent")
        previewEdges[i] = edge
    end

    local previewCycle = Instance.new("TextLabel", progressionPreview)
    previewCycle.Size = UDim2.new(1, 0, 0, 16)
    previewCycle.Position = UDim2.new(0, 0, 1, -16)
    previewCycle.BackgroundTransparency = 1
    previewCycle.Font = Enum.Font.GothamBold
    previewCycle.TextSize = 11
    previewCycle.TextXAlignment = Enum.TextXAlignment.Center
    previewCycle.TextColor3 = Theme.Text
    register(previewCycle, "TextColor3", "Text")

    local function applyTier(stroke, tierName)
        local tier = STAT_TIERS[tierName] or STAT_TIERS.None
        stroke.Color = tier.color
    end

    local function refreshProgressionPreview()
        local n = math.clamp(clickerShapeVertices, 3, 9)
        local radius = 18
        local cx, cy = 43, 24
        local palette = {
            Color3.fromRGB(120, 180, 255),
            Color3.fromRGB(140, 230, 160),
            Color3.fromRGB(255, 175, 95),
            Color3.fromRGB(220, 135, 255),
            Color3.fromRGB(255, 110, 145),
            Color3.fromRGB(255, 230, 120),
        }
        local cycleColor = palette[(clickerShapeCycle % #palette) + 1]

        for i = 1, 9 do
            local edge = previewEdges[i]
            if i <= n then
                local a1 = ((i - 1) / n) * (2 * math.pi) - (math.pi / 2)
                local a2 = (i / n) * (2 * math.pi) - (math.pi / 2)
                local x1 = cx + (math.cos(a1) * radius)
                local y1 = cy + (math.sin(a1) * radius)
                local x2 = cx + (math.cos(a2) * radius)
                local y2 = cy + (math.sin(a2) * radius)
                local dx, dy = x2 - x1, y2 - y1
                local len = math.sqrt((dx * dx) + (dy * dy))

                edge.Visible = true
                edge.BackgroundColor3 = cycleColor
                edge.Size = UDim2.fromOffset(math.max(2, len), 2)
                edge.Position = UDim2.fromOffset((x1 + x2) * 0.5, (y1 + y2) * 0.5)
                edge.Rotation = angleDeg(dy, dx)
            else
                edge.Visible = false
            end
        end

        previewCycle.Text = string.format("C%d", clickerShapeCycle)
        previewCycle.TextColor3 = cycleColor
    end

    local function refreshStatisticsView()
        if clickerHighScore > statisticsData.clickerHighScore then
            statisticsData.clickerHighScore = clickerHighScore
        end

        local clickerScoreBest = statisticsData.clickerHighScore
        local clickerTierTargets = {
            Bronze = 10000,
            Silver = 500000,
            Gold = 10000000,
            Diamond = 50000000,
            Platinum = 250000000,
            Master = 1000000000,
        }
        local clickerTier = getTierByThreshold(clickerScoreBest, clickerTierTargets)

        local progressionCycle = clickerShapeCycle
        local progressionTierTargets = {
            Bronze = 2,
            Silver = 6,
            Gold = 10,
            Diamond = 15,
            Platinum = 21,
            Master = 28,
        }
        local progressionTier = getTierByThreshold(progressionCycle, progressionTierTargets)

        local sessionSecs = statisticsData.longestSessionSeconds
        local sessionTierTargets = {
            Bronze = 4 * 3600,
            Silver = 8 * 3600,
            Gold = 12 * 3600,
            Diamond = 18 * 3600,
            Platinum = 24 * 3600,
            Master = 36 * 3600,
        }
        local sessionTier = getTierByThreshold(sessionSecs, sessionTierTargets)
        local skillCount = statisticsData.totalSkillActivations
        local skillTierTargets = {
            Bronze = 1000,
            Silver = 10000,
            Gold = 50000,
            Diamond = 150000,
            Platinum = 500000,
            Master = 1000000,
        }
        local skillTier = getTierByThreshold(skillCount, skillTierTargets)

        clickerDetail.Text = string.format(
            "Best score: %d\nB 10,000 | S 500,000 | G 10,000,000 | D 50,000,000 | P 250,000,000 | M 1,000,000,000\nCurrent Tier: %s",
            clickerScoreBest,
            STAT_TIERS[clickerTier].label
        )
        applyTier(clickerStroke, clickerTier)

        progressionDetail.Text = string.format(
            "Shape: %d-gon | Cycle: %d\nB C2 | S C6 | G C10 | D C15 | P C21 | M C28\nCurrent Tier: %s",
            clickerShapeVertices,
            progressionCycle,
            STAT_TIERS[progressionTier].label
        )
        applyTier(progressionStroke, progressionTier)
        refreshProgressionPreview()

        sessionDetail.Text = string.format(
            "Best: %s\nB 4h | S 8h | G 12h | D 18h | P 24h | M 36h\nCurrent Tier: %s",
            formatDurationHM(sessionSecs),
            STAT_TIERS[sessionTier].label
        )
        applyTier(sessionStroke, sessionTier)

        skillsDetail.Text = string.format(
            "Total activations: %d\nB 1,000 | S 10,000 | G 50,000 | D 150,000 | P 500,000 | M 1,000,000\nCurrent Tier: %s",
            skillCount,
            STAT_TIERS[skillTier].label
        )
        applyTier(skillsStroke, skillTier)

        summaryLabel.Text = string.format(
            "Session now: %s | Current Action: %s",
            formatDurationHM(os.clock() - statisticsSessionStartClock),
            tostring(statisticsData.lastSessionReason or "unknown")
        )
    end

    uiButton(page, "Update Statistics", function()
        finalizeSessionStatistics("manual update")
        statisticsData.sessionActive = true
        statisticsData.sessionStartTime = os.time()
        statisticsData.lastSessionReason = "running"
        saveClickerState(true)
        saveStatistics()
        refreshStatisticsView()
        log("System", "Statistics updated and saved")
    end)

    ThemeRefreshers[#ThemeRefreshers + 1] = refreshStatisticsView
    refreshStatisticsView()

    task.spawn(function()
        while running and not __destroyed do
            task.wait(2)
            refreshStatisticsView()
        end
    end)
end
-- CONFIG PAGE

do
    local page = Pages.Config
    uiSection(page, "Config Slots")

    local function captureConfig()
        return {
            autoSkillMode = autoSkillMode,
            skillEnabled = skillEnabled,
            selectedChainMode = selectedChainMode,
            adaptiveCooldownEnabled = adaptiveCooldownEnabled,
            autoClickerEnabled = autoClickerEnabled,
            autoClickRate = autoClickRate,
            antiAfkEnabled = antiAfkEnabled,
            watchdogEnabled = watchdogEnabled,
            AFKCameraEnabled = AFKCameraEnabled,
            zoomUnlockEnabled = zoomUnlockEnabled,
            fpsCapEnabled = fpsCapEnabled,
            targetFPS = targetFPS,
            visualsDisabled = visualsDisabled,
            streamingOptimized = streamingOptimized,
            backgroundMode = backgroundMode,
            memoryStatsEnabled = memoryStatsEnabled,
            memoryGuardMode = memoryGuardMode,
            memoryGuardCapGB = memoryGuardCapGB,
            theme = serializeTheme(Theme),
        }
    end

    local function applyConfig(cfg)
        if type(cfg) ~= "table" then return end
        autoSkillMode = cfg.autoSkillMode or autoSkillMode
        skillEnabled = cfg.skillEnabled or skillEnabled
        selectedChainMode = cfg.selectedChainMode or selectedChainMode
        adaptiveCooldownEnabled = (cfg.adaptiveCooldownEnabled == true)
        autoClickerEnabled = (cfg.autoClickerEnabled == true)
        autoClickRate = tonumber(cfg.autoClickRate) or autoClickRate
        antiAfkEnabled = (cfg.antiAfkEnabled == true)
        watchdogEnabled = (cfg.watchdogEnabled == true)
        _G.__MeerlyState.antiAfkEnabled = antiAfkEnabled
        _G.__MeerlyState.watchdogEnabled = watchdogEnabled
        AFKCameraEnabled = (cfg.AFKCameraEnabled == true)
        zoomUnlockEnabled = (cfg.zoomUnlockEnabled == true)
        fpsCapEnabled = (cfg.fpsCapEnabled == true)
        targetFPS = tonumber(cfg.targetFPS) or targetFPS
        visualsDisabled = (cfg.visualsDisabled == true)
        streamingOptimized = (cfg.streamingOptimized == true)
        backgroundMode = (cfg.backgroundMode == true)
        memoryStatsEnabled = (cfg.memoryStatsEnabled == true)
        memoryGuardMode = cfg.memoryGuardMode or memoryGuardMode
        memoryGuardCapGB = tonumber(cfg.memoryGuardCapGB) or memoryGuardCapGB

        memoryGui.Enabled = memoryStatsEnabled
        if setfpscap and fpsCapEnabled then pcall(function() setfpscap(targetFPS) end) end
        if cfg.theme then
            pcall(function() applyTheme(deserializeTheme(cfg.theme)) end)
        end
        log("System", "Config applied")
    end

    uiButton(page, "I/O Self-Test (Config)", function()
        local ok, msg = runFileIOSelfTest("config_io")
        if ok then
            log("System", "Config I/O self-test passed: " .. msg)
        else
            log("Error", "Config I/O self-test failed: " .. msg)
        end
    end)

    for slot = 1, 5 do
        uiSection(page, "Slot " .. slot)
        local row = uiRow3(page)
        local saveBtn = uiSmallBtn(row, "Save")
        local loadBtn = uiSmallBtn(row, "Load")
        local pathBtn = uiSmallBtn(row, "File")

        track(saveBtn.MouseButton1Click:Connect(function()
            local payload = captureConfig()
            local okEncode, json = pcall(function() return HttpService:JSONEncode(payload) end)
            if not okEncode then
                log("Error", "Config " .. slot .. " encode failed")
                return
            end
            local filename = string.format("%s%d.json", configPrefix, slot)
            local ok, err = safeWriteFile(filename, json)
            if ok then
                log("System", "Saved config to " .. filename)
            else
                log("Error", "Save config failed: " .. tostring(err))
            end
        end))

        track(loadBtn.MouseButton1Click:Connect(function()
            local filename = string.format("%s%d.json", configPrefix, slot)
            local okRead, raw = safeReadFile(filename)
            if not okRead then
                log("Error", "Load config failed: " .. tostring(raw))
                return
            end
            local okDecode, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if not okDecode or type(decoded) ~= "table" then
                log("Error", "Invalid config file: " .. filename)
                return
            end
            applyConfig(decoded)
            log("System", "Loaded config from " .. filename)
        end))

        track(pathBtn.MouseButton1Click:Connect(function()
            log("System", string.format("Config file: %s%d.json", configPrefix, slot))
        end))
    end
end


-- CONSOLE PAGE

do
    local page = Pages.Console
    uiSection(page, "Live System Console")

    local filterFrame = Instance.new("Frame", page)
    filterFrame.Size = UDim2.new(1, 0, 0, 120)
    markLayoutFrame(filterFrame)

    local filterLayout = Instance.new("UIGridLayout", filterFrame)
    filterLayout.CellSize = UDim2.fromOffset(160, 32)
    filterLayout.CellPadding = UDim2.fromOffset(8, 8)

    local logScroller = Instance.new("ScrollingFrame", page)
    logScroller.Size = UDim2.new(1, 0, 0, 320)
    logScroller.CanvasSize = UDim2.fromOffset(0, 0)
    logScroller.ScrollBarThickness = 8
    logScroller.BackgroundColor3 = Theme.PanelDark
    logScroller.BorderSizePixel = 0
    Instance.new("UICorner", logScroller).CornerRadius = UDim.new(0, 10)
    register(logScroller, "BackgroundColor3", "PanelDark")

    local pad = Instance.new("UIPadding", logScroller)
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)

    local logText = Instance.new("TextLabel", logScroller)
    logText.BackgroundTransparency = 1
    logText.Size = UDim2.fromScale(1, 0)
    logText.AutomaticSize = Enum.AutomaticSize.Y
    logText.TextWrapped = true
    logText.TextXAlignment = Enum.TextXAlignment.Left
    logText.TextYAlignment = Enum.TextYAlignment.Top
    logText.Font = Enum.Font.Code
    logText.TextSize = 14
    logText.TextColor3 = Theme.Text
    logText.Text = ""
    register(logText, "TextColor3", "Text")

    for name, _ in pairs(LogLevels) do
        local btn = Instance.new("TextButton", filterFrame)
        btn.Size = UDim2.fromOffset(160, 32)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextColor3 = Theme.Text
        btn.BackgroundColor3 = Theme.Panel
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        ensureStroke(btn)

        local function refreshFilterBtn()
            btn.Text = name .. ": " .. (LogLevels[name] and "ON" or "OFF")
            styleToggleButton(btn, LogLevels[name])
        end
        ThemeRefreshers[#ThemeRefreshers + 1] = refreshFilterBtn
        refreshFilterBtn()

        track(btn.MouseButton1Click:Connect(function()
            LogLevels[name] = not LogLevels[name]
            refreshFilterBtn()
            if updateConsole then updateConsole() end
        end))
    end

    updateConsole = function()
        if not logText then return end

        local lines = {}
        for i = 1, logCount do
            local idx = ((logHead - logCount + i - 1) % MAX_LOGS) + 1
            lines[#lines + 1] = logBuffer[idx]
        end

        logText.Text = table.concat(lines, "\n")

        task.defer(function()
            local h = logText.AbsoluteSize.Y
            logScroller.CanvasSize = UDim2.fromOffset(0, h + 20)
            safeAutoScroll(logScroller)
        end)
    end

    updateConsole()
end


-- THEMES PAGE

do
    local page = Pages.Themes

    uiSection(page, "Theme Presets")
    uiButton(page, "Default Theme", function()
        applyTheme(cloneTheme(DEFAULT_THEME))
    end)

    uiButton(page, "AMOLED", function()
        applyTheme({
            Accent = Color3.fromRGB(90, 160, 255),
            Background = Color3.fromRGB(0, 0, 0),
            Panel = Color3.fromRGB(10, 10, 10),
            PanelDark = Color3.fromRGB(6, 6, 6),
            Border = Color3.fromRGB(30, 30, 30),
            Text = Color3.fromRGB(240, 240, 240),
            SubText = Color3.fromRGB(160, 160, 160)
        })
    end)

    uiSection(page, "Accent Color Picker")
    local accentR = uiFieldRow(page, "Accent R (0-255)", tostring(math.floor(Theme.Accent.R * 255 + 0.5)), 0.58)
    local accentG = uiFieldRow(page, "Accent G (0-255)", tostring(math.floor(Theme.Accent.G * 255 + 0.5)), 0.58)
    local accentB = uiFieldRow(page, "Accent B (0-255)", tostring(math.floor(Theme.Accent.B * 255 + 0.5)), 0.58)
    local accentPreview = uiButton(page, "Preview Accent", function() end)

    local function applyAccentFromInputs()
        local r = math.clamp(tonumber(accentR.Text) or 120, 0, 255)
        local g = math.clamp(tonumber(accentG.Text) or 180, 0, 255)
        local b = math.clamp(tonumber(accentB.Text) or 255, 0, 255)
        accentR.Text, accentG.Text, accentB.Text = tostring(math.floor(r)), tostring(math.floor(g)), tostring(math.floor(b))
        local t = cloneTheme(Theme)
        t.Accent = Color3.fromRGB(r, g, b)
        applyTheme(t)
        accentPreview.BackgroundColor3 = t.Accent
    end

    track(accentR.FocusLost:Connect(applyAccentFromInputs))
    track(accentG.FocusLost:Connect(applyAccentFromInputs))
    track(accentB.FocusLost:Connect(applyAccentFromInputs))
    track(accentPreview.MouseButton1Click:Connect(applyAccentFromInputs))
    ThemeRefreshers[#ThemeRefreshers + 1] = function()
        accentPreview.BackgroundColor3 = Theme.Accent
    end
    accentPreview.BackgroundColor3 = Theme.Accent

    uiSection(page, "Blur")
    uiButton(page, "Blur Off", function() setBlur(0) end)
    uiButton(page, "Blur Soft", function() setBlur(8) end)
    uiButton(page, "Blur Heavy", function() setBlur(16) end)

    uiSection(page, "Transparency")
    uiButton(page, "Solid", function() setTransparency(0) end)
    uiButton(page, "Glass", function() setTransparency(0.15) end)
    uiButton(page, "Ultra Light", function() setTransparency(0.3) end)
end


-- HELP PAGE

do
    local page = Pages.Help
    uiSection(page, "MeerlyNW — Peak Evolution")

    local info = Instance.new("TextLabel", page)
    info.Size = UDim2.new(1, 0, 0, 210)
    info.BackgroundTransparency = 1
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.Font = Enum.Font.Gotham
    info.TextSize = 14
    info.TextColor3 = Theme.SubText
    register(info, "TextColor3", "SubText")
    info.Text = [[
Peak Evolution v4 Build 7 — Stable

Hotkeys:
• ;  Toggle main UI
• F6 Toggle Auto Clicker
• F7 Toggle Macro Record/Stop
• END Kill switch

Notes:
• Memory Stats UI is separate and does NOT hide with the main UI.
• Macro and Config Save/Load uses writefile/readfile (available in some environments).
• Clicker highscore & Progression autosave every 10 minutes and on close.
]]
end


-- UI TOGGLE (;) + HOTKEYS + KILL SWITCH

local UI_TOGGLE_KEY = Enum.KeyCode.Semicolon

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if __destroyed then return end

    if input.KeyCode == UI_TOGGLE_KEY then
        gui.Enabled = not gui.Enabled
        if gui.Enabled then
            status.Text = (autoSkillMode ~= AutoSkillMode.Off) and "● Running" or "● Ready"
            log("System", "UI shown")
        else
            status.Text = "● Hidden"
            log("System", "UI hidden")
        end

    elseif input.KeyCode == Enum.KeyCode.F6 then
        autoClickerEnabled = not autoClickerEnabled
        if setAutoClickerToggle then
            setAutoClickerToggle(autoClickerEnabled, true) -- SILENT UI UPDATE
        end
        log("Clicker", "Auto Clicker hotkey (F6): " .. (autoClickerEnabled and "ON" or "OFF"))

    elseif input.KeyCode == Enum.KeyCode.F7 then
        if macroHotkeyToggleRecord then
            macroHotkeyToggleRecord()
        end

    elseif input.KeyCode == Enum.KeyCode.End then
        killSwitch("END key")
    end
end))



pcall(function()
    game:BindToClose(function()
        saveClickerHighScore(true)
        finalizeSessionStatistics("game close")
        dumpLogsToFile("game close")
    end)
end)

-- INITIAL LOG

log("System", "v4 Build 7 loaded")
