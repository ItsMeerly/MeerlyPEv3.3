
local NEXUSLIB_URL = "https://raw.githubusercontent.com/headshot7535-png/Nexuslib/main/Nexuslib"

local SCRIPT_URL     = "https://raw.githubusercontent.com/headshot7535-png/Untitled-Melee-RNG/main/Untitled%20Melee%20RNG"

-- ── Load NexusLib ─────────────────────────────────────────────
local Lib
if readfile and pcall then
    local ok, data = pcall(readfile, "NexusLib.lua")
    if ok and type(data) == "string" and #data > 500 then
        local loadOk, result = pcall(loadstring, data)
        if loadOk then Lib = result() end
    end
end
if not Lib then
    local ok, err = pcall(function()
        Lib = loadstring(game:HttpGet(NEXUSLIB_URL))()
    end)
    if not ok or not Lib then
        error("[MeleeRNG] NexusLib failed to load: " .. tostring(err))
    end
end

-- ── Services ──────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local RS               = game:GetService("ReplicatedStorage")
local CollectionService= game:GetService("CollectionService")

-- ── Wait for full load ────────────────────────────────────────
task.wait(2)
local LP
for _ = 1, 60 do
    LP = Players.LocalPlayer
    if LP and LP:FindFirstChildOfClass("PlayerGui") then break end
    task.wait(0.3)
end
if not LP then error("[MeleeRNG] LocalPlayer not ready") end

-- ── Re-exec generation token ──────────────────────────────────
_G.MeleeRNG_Gen = (_G.MeleeRNG_Gen or 0) + 1
local GEN = _G.MeleeRNG_Gen

-- ── Cleanup system ────────────────────────────────────────────
local _conns    = {}
local _threads  = {}
local _stopped  = false

local function addConn(c)  _conns[#_conns+1] = c end
local function addThread(t) _threads[#_threads+1] = t end
local function cleanupAll()
    _stopped = true
    for _, c in ipairs(_conns)   do pcall(function() c:Disconnect() end) end
    for _, t in ipairs(_threads) do pcall(function() task.cancel(t) end) end
    _conns = {}; _threads = {}
end

-- ── Base helpers ──────────────────────────────────────────────
local function getChar()  return LP.Character end
local function getRoot()  local c=getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHuman() local c=getChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function alive()    local h=getHuman() return h and h.Health > 0 end

-- ── Leaderstats discovery (emoji keys — confirmed from dump) ──
-- Uses WaitForChild polling so emoji bytes resolve correctly
local _ls = nil
local function getLS()
    if _ls and _ls.Parent then return _ls end
    _ls = LP:FindFirstChild("leaderstats")
    return _ls
end
-- Cached leaderstat references (avoid repeated FindFirstChild scans)
local _cachedStats = {}
local function getCachedStat(name)
    if _cachedStats[name] and _cachedStats[name].Parent then
        return _cachedStats[name].Value
    end
    local ls = getLS(); if not ls then return 0 end
    for _, child in ipairs(ls:GetChildren()) do
        if child.Name:find(name, 1, true) then
            _cachedStats[name] = child
            return child.Value
        end
    end
    return 0
end
local function getKills()   return getCachedStat("Kills") end
local function getMana()    return getCachedStat("Mana") end
local function getSP()      return getCachedStat("SP") end
local function getAscends() return getCachedStat("Ascends") end
-- Ascend kill gate (AscendUIController): "2 + v8 .. M Kills" where v8 = current ascend count — not area MinimumKills
local function getAscendKillsRequired()
    return (2 + (tonumber(getAscends()) or 0)) * 1000000
end

-- Default post-ascend TP (Forgotten Valley — original log); player can override in Misc → Ascend
local DEF_ASCEND_TP_X, DEF_ASCEND_TP_Y, DEF_ASCEND_TP_Z = 496.9, 222.1, -7380.4

-- ── Remote cache ─────────────────────────────────────────────
local _remotes = {}
local function R(name)
    if _remotes[name] and _remotes[name].Parent then return _remotes[name] end
    local r = RS:FindFirstChild("Remotes")
    if not r then return nil end
    _remotes[name] = r:FindFirstChild(name)
    return _remotes[name]
end
local function fireR(name, ...)
    local r = R(name); if not r then return end
    local args = table.pack(...)
    return pcall(function() r:FireServer(table.unpack(args, 1, args.n)) end)
end
local function invokeR(name, ...)
    local r = R(name); if not r then return nil end
    local args = table.pack(...)
    local ok, res = pcall(function() return r:InvokeServer(table.unpack(args, 1, args.n)) end)
    return ok and res or nil
end

-- ── Live mob table (mirrors MobsClientController u19) ─────────
-- We read directly from workspace.Mobs. Each model has attribute "ID".
-- Properties confirmed: Root=HumanoidRootPart, Health via HitMob event.
-- We maintain our OWN health shadow for attack-flow control.
local MOB_DATA = {}  -- [modelRef] = {id, health, maxHealth, boss, megaBoss, root}

local function refreshMobData()
    MOB_DATA = {}
    local mobsFolder = workspace:FindFirstChild("Mobs")
    if not mobsFolder then return end
    -- Mobs have NO Humanoid — health is server-side only.
    -- Valid mob = Model with HumanoidRootPart + "ID" attribute (set by SpawnMob).
    for _, model in ipairs(mobsFolder:GetChildren()) do
        if model:IsA("Model") and isMobAlive(model) then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            local id  = model:GetAttribute("ID") or model.Name
            MOB_DATA[model] = {
                id       = id,
                model    = model,
                root     = hrp,
                boss     = model:GetAttribute("Boss") == true,
                megaBoss = model:GetAttribute("MegaBoss") == true,
            }
        end
    end
end

-- Valid mob: Model in workspace.Mobs + HumanoidRootPart + "ID" attribute set
-- Mobs have NO Humanoid — health is server-side only. Do NOT check Humanoid.Health.
-- "MobRootPart" CollectionService tag confirmed on HumanoidRootPart (dump line 41039).
local function isMobAlive(model)
    if not (model and model.Parent) then return false end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    -- If the model has been destroyed by HitMob the root disappears
    return hrp ~= nil and model:GetAttribute("ID") ~= nil
end

local function getNearestMob(filterFn)
    local root = getRoot(); if not root then return nil end
    local mobsFolder = workspace:FindFirstChild("Mobs")
    if not mobsFolder then return nil end
    local best, bestDist = nil, math.huge
    for _, model in ipairs(mobsFolder:GetChildren()) do
        if model:IsA("Model") and isMobAlive(model) then
            if not filterFn or filterFn(model) then
                local hrp = model:FindFirstChild("HumanoidRootPart")
                local d = (root.Position - hrp.Position).Magnitude
                if d < bestDist then bestDist = d; best = model end
            end
        end
    end
    return best, bestDist
end

local function countAliveMobs()
    local mobsFolder = workspace:FindFirstChild("Mobs"); if not mobsFolder then return 0 end
    local n = 0
    for _, m in pairs(mobsFolder:GetChildren()) do
        if m:IsA("Model") and isMobAlive(m) then n = n + 1 end
    end
    return n
end

-- ── Damage multiplier (live from server) ──────────────────────
local _dmgMulti = 0
local function getDmgMulti()
    local v = invokeR("GetUpgradeValue", "Damage Multiplier")
    if type(v) == "number" then _dmgMulti = v end
    return _dmgMulti
end
-- ── State ─────────────────────────────────────────────────────
local states = {
    autoEquipBest  = false,
    autoAscend     = false,
    farmBoss       = true,   -- ON by default: higher areas spawn bosses
    farmMegaBoss   = false,
    skipRegular    = false,
    noclip         = false,
    godMode        = false,
    fly            = false,
    infJump        = false,
    antiAfk        = false,
    fullBright     = false,
    espMobs        = false,
    autoSave       = true,
    showAutoRaid   = false,
    showHideMobs   = false,
    autoReExec     = false,
    hitboxPulse    = false,
    hitboxDutyCycle  = 2,  -- BIG on 1 frame per N heartbeats (2 = half the frames big, old behavior; 6+ = mostly tiny, less physics lag)
    autoUpgradeOn  = false,  -- master Auto Upgrade loop (saved with other toggles)
    autoManaToSP   = false,  -- Heartbeat: CalculateManaPrice + ConvertMana (1 unit, ~10/s cap)
    -- After ascend: TP target (HumanoidRootPart + 3 studs Y); set via Misc → Ascend
    ascendAfterTpX = DEF_ASCEND_TP_X,
    ascendAfterTpY = DEF_ASCEND_TP_Y,
    ascendAfterTpZ = DEF_ASCEND_TP_Z,
    -- Sacrifice (Fountain) — OneIn tiers from RS.Assets.Weapons; only By color + By name
    autoSacrifice    = false,
    sacFilterColor   = false,  -- OneIn ≤ selected tier max (game color / rarity)
    sacFilterName    = false,
    sacRarityCapIdx  = 1,     -- 1–9 = dropdown tier cap (see SAC_TIERS)
    sacKeepQty       = 0,    -- 0–999; persisted + synced on load
    -- Totem of Fortune — TotemConfirm(weaponName); cap 25 + AP level×5; 1h CD when server returns false
    -- Filters are separate from Fountain sacrifice (own color cap + keep qty)
    autoTotem           = false,
    totemFilterColor    = false,  -- only weapons in selected OneIn *band* (not “up through”; Fountain stays ≤ cap)
    totemRarityCapIdx   = 1,
    totemKeepQty        = 0,
    totemDoneThisCycle  = 0,
    totemCapHitUnix     = nil, -- os.time() when server capped (starts 1h cycle lock)
    totemSavedServerCap = nil, -- parsed/confirmed max; survives re-exec (see LS merge below)
    totemCapFromServerNotify = false, -- "server confirmed" banner until CD ends
    -- Totem color = OneIn range; ticked rows = which names in that range may be sacrificed (like Cobalt)
    totemOnlyTickedNames    = false,
}

-- Upgrade names for save/load (must exist before saveSettings references upgradeSelected)
local UPGRADE_ORDER = {
    "Weapons Equipped", "Damage Multiplier", "Enemy Spawn Rate", "Enemy Limit",
    "Mana Multiplier", "Spin Speed", "RNG Luck", "Kill Multiplier",
    "Skill Point Multiplier", "Boss Spawn Chance",
}

local upgradeSelected = {}  -- [upgradeName] = bool — filled from LS below
local upgradeLevelCap = {} -- [upgradeName] = max level (stop auto-buy when current >= cap); nil = no cap
local _sacNameSelected = {} -- [weaponName] = bool — Sacrifice "By Name" picks (persisted)

local walkSpeedVal   = 16
-- BIG-phase default: map-tuned — huge boxes add overlap pairs and tank KPM vs ~500 (Test 8b ~5.5x).
local hitboxSize     = 500
local flyBV, flyBG
local espBillboards  = {}

-- ── Settings persistence ──────────────────────────────────────
local SETTINGS_FILE = "meleernq_settings.json"
local function saveSettings()
    pcall(function()
        local t = {}
        for k, v in pairs(states) do t[k] = v end
        t.walkSpeedVal = walkSpeedVal
        local up = {}
        for _, name in ipairs(UPGRADE_ORDER) do
            up[name] = upgradeSelected[name] == true
        end
        t.upgradeSelected = up
        local ucaps = {}
        for _, un in ipairs(UPGRADE_ORDER) do
            local c = upgradeLevelCap[un]
            if type(c) == "number" and c >= 1 then ucaps[un] = math.floor(c) end
        end
        t.upgradeLevelCap = ucaps
        t.hitboxSize = hitboxSize
        local sacNames = {}
        for name, on in pairs(_sacNameSelected) do
            if on then sacNames[#sacNames + 1] = name end
        end
        table.sort(sacNames)
        t.sacNamesSelected = sacNames
        writefile(SETTINGS_FILE, HttpService:JSONEncode(t))
    end)
end
local function forceSave()
    saveSettings()
end
local LS = {}
pcall(function()
    if isfile and isfile(SETTINGS_FILE) then
        local ok, d = pcall(function()
            return HttpService:JSONDecode(readfile(SETTINGS_FILE))
        end)
        if ok and type(d) == "table" then LS = d end
    end
end)
for k in pairs(states) do if LS[k] ~= nil then states[k] = LS[k] end end
if LS.walkSpeedVal then walkSpeedVal = LS.walkSpeedVal end
if LS.autoSave     then states.autoSave     = LS.autoSave     end
if LS.showAutoRaid then states.showAutoRaid = LS.showAutoRaid end
if LS.showHideMobs then states.showHideMobs = LS.showHideMobs end
if LS.hitboxSize ~= nil then
    local n = tonumber(LS.hitboxSize)
    if n then
        n = math.max(10, math.min(100000, math.floor(n)))
        -- Old presets used 100k / 60k / 25k BIG; map-tuned targets are 500 / 500 / 350.
        if n >= 50000 then
            n = 500
        elseif n >= 15000 then
            n = 350
        end
        hitboxSize = n
    end
end
if type(LS.upgradeSelected) == "table" then
    for _, name in ipairs(UPGRADE_ORDER) do
        local v = LS.upgradeSelected[name]
        upgradeSelected[name] = (v == true or v == 1)
    end
end
if type(LS.upgradeLevelCap) == "table" then
    for _, name in ipairs(UPGRADE_ORDER) do
        local v = tonumber(LS.upgradeLevelCap[name])
        if v and v >= 1 then upgradeLevelCap[name] = math.floor(v) end
    end
end
if type(LS.sacNamesSelected) == "table" then
    _sacNameSelected = {}
    for _, n in ipairs(LS.sacNamesSelected) do
        if type(n) == "string" then _sacNameSelected[n] = true end
    end
end
states.autoUpgradeOn = states.autoUpgradeOn == true
states.autoAscend    = states.autoAscend == true
states.autoSacrifice = states.autoSacrifice == true
states.autoManaToSP  = states.autoManaToSP == true
if LS.sacFilterColor ~= nil then
    states.sacFilterColor = LS.sacFilterColor == true
elseif LS.sacFilterRarity ~= nil then
    states.sacFilterColor = LS.sacFilterRarity == true
end
states.sacFilterColor = states.sacFilterColor == true
states.sacFilterName  = states.sacFilterName == true
states.sacRarityCapIdx = math.clamp(math.floor(tonumber(states.sacRarityCapIdx) or 1), 1, 9)
states.sacKeepQty      = math.clamp(math.floor(tonumber(states.sacKeepQty) or 0), 0, 999)
states.ascendAfterTpX  = tonumber(states.ascendAfterTpX) or DEF_ASCEND_TP_X
states.ascendAfterTpY  = tonumber(states.ascendAfterTpY) or DEF_ASCEND_TP_Y
states.ascendAfterTpZ  = tonumber(states.ascendAfterTpZ) or DEF_ASCEND_TP_Z

states.autoTotem = states.autoTotem == true
states.totemOnlyTickedNames = states.totemOnlyTickedNames == true
states.totemFilterColor = states.totemFilterColor == true
states.totemRarityCapIdx = math.clamp(math.floor(tonumber(states.totemRarityCapIdx) or 1), 1, 9)
states.totemKeepQty = math.clamp(math.floor(tonumber(states.totemKeepQty) or 0), 0, 999)
states.totemDoneThisCycle = math.max(0, math.floor(tonumber(states.totemDoneThisCycle) or 0))
-- Totem CD/cap from LS applied in totem block (after TOTEM_CYCLE_SEC) + sanitize vs os.time()

local function getAscendAfterTpCFrame()
    local x = tonumber(states.ascendAfterTpX) or DEF_ASCEND_TP_X
    local y = tonumber(states.ascendAfterTpY) or DEF_ASCEND_TP_Y
    local z = tonumber(states.ascendAfterTpZ) or DEF_ASCEND_TP_Z
    x = math.clamp(x, -500000, 500000)
    y = math.clamp(y, -50000, 500000)
    z = math.clamp(z, -500000, 500000)
    return CFrame.new(x, y, z)
end

-- Post-ascend TP: retry until HRP is within tolerance of saved spot at least once (or timeout).
local ASCEND_TP_NEAR_STUDS   = 20   -- count as "arrived" when HRP is this close to target
local ASCEND_TP_RETRY_SEC    = 0.12 -- how often to re-apply CFrame while not there yet
local ASCEND_TP_MAX_CHASE    = 90   -- stop retrying after this many seconds (avoid hanging forever)
local ASCEND_STAT_WAIT_ITER  = 60  -- 60×0.1s = up to 6s for Ascends stat to replicate

local function getAscendAfterTpWorldPos()
    return (getAscendAfterTpCFrame() * CFrame.new(0, 3, 0)).Position
end

local function hrpNearAscendTp()
    local root = getRoot()
    if not root then return false end
    local tgt = getAscendAfterTpWorldPos()
    return (root.Position - tgt).Magnitude <= ASCEND_TP_NEAR_STUDS
end

--- Wait for Ascends to increase, then keep TPing until local HRP reaches saved position once (or chase timeout).
local function teleportAfterAscendIfConfirmed(beforeAscends)
    beforeAscends = tonumber(beforeAscends) or 0
    local ascended = false
    for _ = 1, ASCEND_STAT_WAIT_ITER do
        if GEN ~= _G.MeleeRNG_Gen then return false end
        task.wait(0.1)
        local now = tonumber(getAscends()) or 0
        if now > beforeAscends then
            ascended = true
            break
        end
    end
    if not ascended then return false end

    local deadline = os.clock() + ASCEND_TP_MAX_CHASE
    while os.clock() < deadline do
        if GEN ~= _G.MeleeRNG_Gen then return false end
        if hrpNearAscendTp() then
            return true
        end
        local root = getRoot()
        if root then
            pcall(function()
                root.CFrame = getAscendAfterTpCFrame() * CFrame.new(0, 3, 0)
            end)
        end
        task.wait(ASCEND_TP_RETRY_SEC)
    end
    return hrpNearAscendTp()
end

local function formatAscendTpSaved()
    return string.format("X=%.2f Y=%.2f Z=%.2f",
        tonumber(states.ascendAfterTpX) or DEF_ASCEND_TP_X,
        tonumber(states.ascendAfterTpY) or DEF_ASCEND_TP_Y,
        tonumber(states.ascendAfterTpZ) or DEF_ASCEND_TP_Z)
end

-- Main chunk was hitting Luau's ~200 local register limit; UI + re-exec live in their own function.
local SLbl = (function()
-- ============================================================
--  BUILD WINDOW  (tabs: Move → ESP → Areas → Upgrades → Sacrifice → Chat → Misc)
-- ============================================================
local Win  = Lib:Window({ title = "⚔️  Melee RNG  v1.0" })
local SLbl = Win._status

-- Shared palette / status cards (used by every tab)
local C = {
    bg=Color3.fromRGB(8,10,18), card=Color3.fromRGB(15,19,32),
    border=Color3.fromRGB(25,35,60), accent=Color3.fromRGB(0,180,255),
    accentD=Color3.fromRGB(0,100,180), text=Color3.fromRGB(210,225,245),
    sub=Color3.fromRGB(60,80,120), green=Color3.fromRGB(0,200,100),
    purple=Color3.fromRGB(160,80,255), red=Color3.fromRGB(255,70,70),
    orange=Color3.fromRGB(255,160,30), gold=Color3.fromRGB(255,210,50),
}
local function makeStatusCard(page, lo, titleStr, accentCol)
    accentCol = accentCol or C.accent
    local Card = Instance.new("Frame", page)
    Card.Size = UDim2.new(1,-10,0,88)
    Card.BackgroundColor3 = C.card; Card.BorderSizePixel = 0; Card.LayoutOrder = lo
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0,10)
    local stroke = Instance.new("UIStroke", Card); stroke.Color = C.border; stroke.Thickness = 1

    local function lbl(txt, xOff, yOff, h, col, font, size)
        local L = Instance.new("TextLabel", Card)
        L.Text = txt; L.Size = UDim2.new(1,-110,0,h)
        L.Position = UDim2.new(0, xOff or 14, 0, yOff or 8)
        L.BackgroundTransparency = 1; L.TextColor3 = col or C.text
        L.Font = font or Enum.Font.GothamBold; L.TextSize = size or 12
        L.TextXAlignment = Enum.TextXAlignment.Left
        return L
    end
    local Title  = lbl(titleStr, 14, 8,  18, C.text, Enum.Font.GothamBold, 13)
    local Status = lbl("OFF · Idle", 14, 28, 13, C.sub,  Enum.Font.Code, 9)
    local Info1  = lbl("",          14, 44, 12, C.sub,  Enum.Font.Code, 9)
    local Info2  = lbl("",          14, 58, 12, accentCol, Enum.Font.Code, 9)

    local Pill = Instance.new("Frame", Card)
    Pill.Size = UDim2.new(0,44,0,24); Pill.Position = UDim2.new(1,-50,0.5,-12)
    Pill.BackgroundColor3 = C.border; Pill.BorderSizePixel = 0
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1,0)
    local Thumb = Instance.new("Frame", Pill)
    Thumb.Size = UDim2.new(0,18,0,18); Thumb.Position = UDim2.new(0,3,0.5,-9)
    Thumb.BackgroundColor3 = C.sub; Thumb.BorderSizePixel = 0
    Instance.new("UICorner", Thumb).CornerRadius = UDim.new(1,0)
    local PBtn = Instance.new("TextButton", Pill)
    PBtn.Size = UDim2.new(1,0,1,0); PBtn.BackgroundTransparency = 1
    PBtn.Text = ""; PBtn.ZIndex = 3

    local ti = TweenService.new(0.18, Enum.EasingStyle.Quad)
    local function setState(on)
        if on then
            TweenService:Create(Pill,  ti, {BackgroundColor3 = accentCol}):Play()
            TweenService:Create(Thumb, ti, {Position = UDim2.new(0,23,0.5,-9), BackgroundColor3 = accentCol}):Play()
            stroke.Color = accentCol; Title.TextColor3 = accentCol
        else
            TweenService:Create(Pill,  ti, {BackgroundColor3 = C.border}):Play()
            TweenService:Create(Thumb, ti, {Position = UDim2.new(0,3,0.5,-9), BackgroundColor3 = C.sub}):Play()
            stroke.Color = C.border; Title.TextColor3 = C.text
            Status.Text = "OFF · Idle"
        end
    end
    return { Card=Card, Title=Title, Status=Status, Info1=Info1, Info2=Info2,
             Pill=Pill, PBtn=PBtn, stroke=stroke, setState=setState }
end

local MoveTab = Win:Tab("🚀",  "Move")
local ESPTab  = Win:Tab("👁️",  "ESP")
local AreaTab = Win:Tab("🗺️",  "Areas")
local UpgTab  = Win:Tab("⬆️",  "Upgrades")
local SacTab  = Win:Tab("🕯️", "Sacrifice")

-- Auto upgrade: SP, GetUnlockedUpgrades / GetUpgradeLevel / BuyUpgrade (prices = SharedConstants client copy)

-- Price functions — exact copies from SharedConstants.Upgrades (dump lines 3601-3690)
local UPGRADE_PRICES = {
    ["Weapons Equipped"]       = function(p) return 1 + p^2 * p end,
    ["Damage Multiplier"]      = function(p) return p^4 + 5 end,
    ["Enemy Spawn Rate"]       = function(p) return math.floor(p^1.5 + 10) end,
    ["Enemy Limit"]            = function(p) return math.round(p^1.1 + 1) end,
    ["Mana Multiplier"]        = function(p) return math.round(8 + p^2.35 * p) end,
    ["Spin Speed"]             = function(p) return p^4 + 5 end,
    ["RNG Luck"]               = function(p) return p^4 + 5 end,
    ["Kill Multiplier"]        = function(p) return math.round(p^3.9 + 100) end,
    ["Skill Point Multiplier"] = function(p) return math.round(p^4.5) + 1 end,
    ["Boss Spawn Chance"]      = function(p) return math.round(p^4) + 150 end,
}

-- Server SP cost if the game exposes it (more accurate than SharedConstants clone). Cleared after a buy.
local _upgPriceCache = {}
local UPG_PRICE_CACHE_TTL = 2.5
local UPG_PRICE_REMOTE_NAMES = {
    "GetUpgradePrice", "GetNextUpgradePrice", "GetUpgradeCost", "CalculateUpgradePrice",
}

local function upgInvalidatePriceCache()
    _upgPriceCache = {}
end

-- GetUpgradeLevel sometimes returns a table/wrapped value; raw table breaks p^4 math → no price → row dropped from queue.
local function upgCoerceLevel(raw)
    if raw == nil or raw == false then return 0 end
    if type(raw) == "number" then
        if raw ~= raw or raw < 0 then return 0 end
        return math.min(math.floor(raw), 1e9)
    end
    if type(raw) == "string" then
        local n = tonumber(raw)
        return n and upgCoerceLevel(n) or 0
    end
    if type(raw) == "table" then
        local n = tonumber(raw[1])
            or tonumber(raw.Level) or tonumber(raw.level)
            or tonumber(raw.L) or tonumber(raw.Lvl) or tonumber(raw.Value) or tonumber(raw.value)
        return n and upgCoerceLevel(n) or 0
    end
    return 0
end

local function upgReadUpgradeLevel(name)
    local raw = nil
    pcall(function() raw = invokeR("GetUpgradeLevel", name) end)
    return upgCoerceLevel(raw)
end

local function upgCoercePrice(raw)
    if type(raw) == "number" and raw == raw and raw > 0 and raw < 1e18 then return raw end
    if type(raw) == "string" then
        local n = tonumber(raw)
        if n then return upgCoercePrice(n) end
    end
    if type(raw) == "table" then
        local n = tonumber(raw[1])
            or tonumber(raw.Price) or tonumber(raw.price)
            or tonumber(raw.Cost) or tonumber(raw.cost)
            or tonumber(raw.SP) or tonumber(raw.sp)
        if n then return upgCoercePrice(n) end
    end
    return nil
end

-- Prefer (name, level) first — many handlers ignore `name` when level is omitted and return a wrong/default cost.
local function upgTryRemotePrice(name, lvl)
    local li = math.floor(tonumber(lvl) or 0)
    if li < 0 then li = 0 end
    for _, rn in ipairs(UPG_PRICE_REMOTE_NAMES) do
        local v = nil
        pcall(function() v = invokeR(rn, name, li) end)
        local p = upgCoercePrice(v)
        if p then return p end
        pcall(function() v = invokeR(rn, name) end)
        p = upgCoercePrice(v)
        if p then return p end
    end
    return nil
end

--- Next-tier SP: cached remote (if any), else formula with pcall (lvl+1, then lvl fallback).
local function upgGetNextPrice(name, lvl)
    local now = os.clock()
    local ck = name .. "#" .. tostring(lvl)
    local ent = _upgPriceCache[ck]
    if ent and (now - ent.t) < UPG_PRICE_CACHE_TTL then return ent.p end
    local rp = upgTryRemotePrice(name, lvl)
    if rp then
        _upgPriceCache[ck] = { t = now, p = rp }
        return rp
    end
    local priceFn = UPGRADE_PRICES[name]
    if not priceFn then return nil end
    local price = nil
    local ok, p1 = pcall(priceFn, lvl + 1)
    if ok and type(p1) == "number" and p1 == p1 and p1 > 0 and p1 < math.huge then price = p1 end
    if not price then
        local ok2, p2 = pcall(priceFn, lvl)
        if ok2 and type(p2) == "number" and p2 == p2 and p2 > 0 and p2 < math.huge then price = p2 end
    end
    if price then _upgPriceCache[ck] = { t = now, p = price } end
    return price
end

--- All toggles ON in UI (`upgradeSelected`) + under level cap; sorted by next-tier SP cost (cheapest first).
-- Enemy Limit uses p^1.1; most others use p^4 — at high levels Enemy Limit is often cheapest by formula alone.
local function upgBuildSortedCandidates()
    local list = {}
    for _, name in ipairs(UPGRADE_ORDER) do
        if upgradeSelected[name] == true then
            local lvl = upgReadUpgradeLevel(name)
            local capN = upgradeLevelCap[name]
            if type(capN) == "number" and capN >= 1 and lvl >= capN then continue end
            local price = upgGetNextPrice(name, lvl)
            if type(price) == "number" and price == price and price < math.huge then
                list[#list + 1] = { name = name, price = price, lvl = lvl }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.price ~= b.price then return a.price < b.price end
        return a.name < b.name
    end)
    return list
end

--- Every toggle ON, in UI order: next SP price, or "at cap", or "?" if price unknown.
local function upgFormatAllToggled(candidates)
    local priceByName = {}
    for _, r in ipairs(candidates) do
        priceByName[r.name] = r.price
    end
    local parts = {}
    for _, name in ipairs(UPGRADE_ORDER) do
        if upgradeSelected[name] ~= true then continue end
        local p = priceByName[name]
        if type(p) == "number" and p == p and p < math.huge then
            parts[#parts + 1] = string.format("%s:%.0f", name, p)
        else
            local lvl = upgReadUpgradeLevel(name)
            local capN = upgradeLevelCap[name]
            if type(capN) == "number" and capN >= 1 and lvl >= capN then
                parts[#parts + 1] = string.format("%s:cap L%d", name, lvl)
            else
                parts[#parts + 1] = name .. ":?"
            end
        end
    end
    if #parts == 0 then return "—" end
    return table.concat(parts, " · ")
end

local function upgCountSelectedToggles()
    local n = 0
    for _, name in ipairs(UPGRADE_ORDER) do
        if upgradeSelected[name] == true then n = n + 1 end
    end
    return n
end

local function upgFormatSp(sp)
    local n = tonumber(sp)
    if not n then return tostring(sp) end
    return tostring(math.floor(n + 1e-6))
end

local upgStatusLbl  = UpgTab:Label("Status: OFF")
local upgInfoLbl    = UpgTab:Label("SP: — | Next: —")

local function setAutoUpgrade(on)
    states.autoUpgradeOn = on == true
    upgStatusLbl.Set(on and "Status: ON - Watching SP..." or "Status: OFF")
end

setAutoUpgrade(states.autoUpgradeOn)

UpgTab:Button("⚡", "Toggle Auto Upgrade", "Start/stop the auto upgrade loop (saved)", C.gold, function()
    setAutoUpgrade(not states.autoUpgradeOn)
    saveSettings()
end)

UpgTab:Label("Every toggle ON is used. Sort = lowest next SP (server price remote if present, else formula). Enemy Limit scales ~p^1.1 vs p^4 — often cheapest late-game.")
UpgTab:Section("Select Upgrades to Auto-Buy")
UpgTab:Label("Optional level cap under each row: auto-buy stops when current level ≥ cap (empty = no limit).")

-- Build upgrade selection list using NexusLib toggles
local upgToggles = {}
local upgCapInputs = {}

local function parseUpgradeCapInput(text)
    local s = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    local n = tonumber(s)
    if not n or n < 1 then return nil end
    return math.min(math.floor(n), 999999)
end

-- Build toggles immediately with no remote calls (instant, no blocking)
-- Level/price info is fetched async and shown in the status label
for _, name in ipairs(UPGRADE_ORDER) do
    local isSel = upgradeSelected[name] == true
    local n2    = name
    local t = UpgTab:Toggle(name, "Auto-buy when SP is sufficient", isSel, function(on)
        upgradeSelected[n2] = (on == true)
        saveSettings()
    end)
    upgToggles[name] = t
    local capDefault = ""
    if type(upgradeLevelCap[n2]) == "number" and upgradeLevelCap[n2] >= 1 then
        capDefault = tostring(upgradeLevelCap[n2])
    end
    local inp = UpgTab:Input(
        "Level cap",
        n2 .. " — stop when level reaches this number; leave empty for no cap (saved)",
        "no cap",
        capDefault,
        function(txt)
            upgradeLevelCap[n2] = parseUpgradeCapInput(txt)
            saveSettings()
        end
    )
    upgCapInputs[n2] = inp
end

UpgTab:Button("✅", "Select All / None", "Toggle all upgrades on or off", C.green, function()
    local anyOff = false
    for _, n in ipairs(UPGRADE_ORDER) do
        if not upgradeSelected[n] then anyOff = true; break end
    end
    for _, n in ipairs(UPGRADE_ORDER) do
        upgradeSelected[n] = anyOff
        if upgToggles[n] then
            pcall(function() upgToggles[n].Set(anyOff) end)
        end
    end
    saveSettings()
end)

UpgTab:Section("Live status (updates every 5s)")
local upgLevelLbls = {}
for _, un in ipairs(UPGRADE_ORDER) do
    upgLevelLbls[un] = UpgTab:Label(un .. ": …")
end

local function upgFormatLiveRowText(name)
    local lvl = upgReadUpgradeLevel(name)
    local capN = upgradeLevelCap[name]
    local capSet = type(capN) == "number" and capN >= 1
    local atCap = capSet and lvl >= capN
    local price = upgGetNextPrice(name, lvl)
    local mid
    if atCap then
        mid = string.format("Lv %d · AT CAP (%d)", lvl, capN)
    elseif type(price) == "number" and price == price and price < math.huge then
        mid = string.format("Lv %d · next %.0f SP", lvl, price)
    else
        mid = string.format("Lv %d · next ? SP", lvl)
    end
    local tail = (capSet and not atCap) and string.format(" · stop @%d", capN) or ""
    return name .. " · " .. mid .. tail
end

addThread(task.spawn(function()
    task.wait(2)
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        for _, un in ipairs(UPGRADE_ORDER) do
            local lbl = upgLevelLbls[un]
            if lbl and lbl.Set then
                pcall(function() lbl.Set(upgFormatLiveRowText(un)) end)
            end
        end
        task.wait(5)
    end
end))

-- Async level info — updates status label without blocking toggle creation
addThread(task.spawn(function()
    task.wait(2)  -- wait for game to load
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        local sp = getSP()
        local candidates = upgBuildSortedCandidates()
        if not states.autoUpgradeOn then
            upgInfoLbl.Set(string.format("SP: %s | %d on | auto OFF | On: %s",
                upgFormatSp(sp), upgCountSelectedToggles(), upgFormatAllToggled(candidates)))
            task.wait(2)
            continue
        end
        local nextName, nextPrice = "none", math.huge
        if #candidates > 0 then
            nextName = candidates[1].name
            nextPrice = candidates[1].price
        end
        upgInfoLbl.Set(string.format("SP: %s | %d on | 1st:%s (%s SP) | On: %s",
            upgFormatSp(sp), upgCountSelectedToggles(), nextName,
            nextPrice == math.huge and "?" or tostring(math.floor(nextPrice)),
            upgFormatAllToggled(candidates)))
        task.wait(3)
    end
end))

-- ── Auto Upgrade Loop ─────────────────────────────────────────────────────
-- Checks every second if we can afford any selected upgrade, buys it, refreshes.
addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        task.wait(1)
        if not states.autoUpgradeOn then continue end

        local sp = getSP()
        local bought = false

        local candidates = upgBuildSortedCandidates()
        local spNum = tonumber(sp) or 0
        for _, row in ipairs(candidates) do
            local name, price, lvl = row.name, row.price, row.lvl
            if spNum >= price then
                local ok = invokeR("BuyUpgrade", name)
                if ok then
                    bought = true
                    upgInvalidatePriceCache()
                    sp = getCachedStat("SP")
                    spNum = tonumber(sp) or 0
                    upgStatusLbl.Set(string.format("✓ Bought: %s Lv%d→Lv%d | SP: %s", name, lvl, lvl + 1, upgFormatSp(sp)))
                    SLbl.Text = "⬆️ Upgraded: " .. name
                    _cachedStats["SP"] = nil
                    break
                end
                -- Server rejected; try next cheapest this tick (if any)
            end
        end

        if not bought then
            local nextName, nextPrice = "none", math.huge
            if #candidates > 0 then
                nextName = candidates[1].name
                nextPrice = candidates[1].price
            end
            upgStatusLbl.Set(string.format("⏳ Next:%s (%d SP) | Have %s | On:%s",
                nextName, nextPrice == math.huge and 0 or math.floor(nextPrice), upgFormatSp(sp),
                upgFormatAllToggled(candidates)))
        end

    end
end))

-- ============================================================
--  SACRIFICE TAB UI (Win:Tab created with other tabs)
--  Rarity = weapon:GetAttribute("OneIn") on RS.Assets.Weapons (matches in-game colors)
-- ============================================================

-- OneIn max per tier (sacrifice weapons with OneIn ≤ cap for selected row)
local SAC_TIERS = {
    { emoji = "⬜", name = "Common",     maxOneIn = 5 },
    { emoji = "🟩", name = "Uncommon",   maxOneIn = 50 },
    { emoji = "🟦", name = "Rare",       maxOneIn = 200 },
    { emoji = "🟣", name = "Epic",       maxOneIn = 5000 },
    { emoji = "🟠", name = "Legendary",  maxOneIn = 50000 },
    { emoji = "🩷", name = "Mythic",     maxOneIn = 1000000 },
    { emoji = "🟤", name = "Galactic",   maxOneIn = 7000000 },
    { emoji = "🩵", name = "Godly",      maxOneIn = 11000000 },
    { emoji = "⬛", name = "Omnipotent", maxOneIn = 99000000 },
}

local _sacInv = {}
local _sacAssetCache = {}

local function sacWeaponsFolder()
    local a = RS:FindFirstChild("Assets")
    return a and a:FindFirstChild("Weapons")
end

local function sacLookupAsset(weaponName)
    if _sacAssetCache[weaponName] ~= nil then
        local c = _sacAssetCache[weaponName]
        return c ~= false and c or nil
    end
    local folder = sacWeaponsFolder()
    local asset = nil
    if folder then
        asset = folder:FindFirstChild(weaponName)
        if not asset then
            local nl = weaponName:lower()
            for _, ch in ipairs(folder:GetChildren()) do
                if ch.Name:lower() == nl then asset = ch; break end
            end
        end
    end
    _sacAssetCache[weaponName] = asset or false
    return asset
end

local function sacTierFromOneIn(oneIn)
    local o = tonumber(oneIn)
    if not o then return "?", "?" end
    for _, t in ipairs(SAC_TIERS) do
        if o <= t.maxOneIn then
            return t.emoji .. " " .. t.name, t
        end
    end
    return "✴ Above Omnipotent", nil
end

local function sacCapOneInForDropdownIdx(idx)
    local t = SAC_TIERS[math.clamp(math.floor(tonumber(idx) or 1), 1, #SAC_TIERS)]
    return t and t.maxOneIn or 5
end

local function normSacWeapon(e)
    if type(e) ~= "table" then return nil end
    local name = e.Name or e.name or e.WepName or e.WeaponName or e.Weapon
    if not name or name == "" then return nil end
    local wtype = e.Type or e.WeaponType or e.type or e.Category or "Unknown"
    return {
        name   = tostring(name),
        type   = tostring(wtype),
        qty    = math.max(0, math.floor(tonumber(e.Quantity or e.Qty or e.Count or e.amount or e.Amount or 1) or 0)),
        oneIn  = nil,
        rank   = math.floor(tonumber(e.Rank or e.rank or e.Tier or 0) or 0),
        damage = tonumber(e.Damage or e.damage or e.DPS or e.BaseDamage or 0) or 0,
    }
end

local function sacEnrichFromAssets()
    for _, w in ipairs(_sacInv) do
        local asset = sacLookupAsset(w.name)
        if asset then
            w.oneIn = tonumber(asset:GetAttribute("OneIn"))
            w.rank = math.floor(tonumber(asset:GetAttribute("Rank")) or w.rank or 0)
            w.damage = tonumber(asset:GetAttribute("Damage")) or w.damage or 0
        end
        if w.oneIn == nil then
            w.oneIn = math.huge
        end
    end
end

local SAC_DROPDOWN_LABELS = {}
for i, t in ipairs(SAC_TIERS) do
    SAC_DROPDOWN_LABELS[i] = string.format("%s %s · sacrifice if OneIn≤%s", t.emoji, t.name, tostring(t.maxOneIn))
end

-- Totem: exact tier band only (Fountain still uses “up through” caps above).
local SAC_TOTEM_DROPDOWN_LABELS = {}
for i, t in ipairs(SAC_TIERS) do
    if i == 1 then
        SAC_TOTEM_DROPDOWN_LABELS[i] = string.format("%s %s · Totem only: OneIn ≤ %s", t.emoji, t.name, tostring(t.maxOneIn))
    else
        local prev = SAC_TIERS[i - 1].maxOneIn
        SAC_TOTEM_DROPDOWN_LABELS[i] = string.format(
            "%s %s · Totem only: OneIn > %s and ≤ %s",
            t.emoji,
            t.name,
            tostring(prev),
            tostring(t.maxOneIn)
        )
    end
end

local function sacAnyFilterOn()
    return states.sacFilterColor or states.sacFilterName
end

local function sacWeaponPasses(w)
    if states.sacFilterName then
        return _sacNameSelected[w.name] == true
    end
    if states.sacFilterColor then
        local cap = sacCapOneInForDropdownIdx(states.sacRarityCapIdx)
        local oi = tonumber(w.oneIn)
        if not oi or oi == math.huge then return false end
        return oi <= cap
    end
    return false
end

-- ── Totem of Fortune (TotemConfirm) — rarity by OneIn color; highest Rank first (luck = Rank/10% per slot)
local TOTEM_AP_UPGRADE_NAME = "Totem Of Fortune Sacrifices"
local TOTEM_CYCLE_SEC       = 3600
local TOTEM_BASE_MAX        = 25
local TOTEM_ACTION_DELAY_SEC = 30 -- one-time settle delay right after hourly CD ends
local TOTEM_REJECT_BACKOFF_SEC = 45 -- after server false: don't spam InvokeServer (fewer red toasts)
local TOTEM_MIN_INVOKE_GAP_SEC = 6 -- Cobalt is manual (~slow); fast auto can trip server / spam red ERROR
local TOTEM_SKIP_AFTER_REJECT_SEC = 180 -- server false for this weapon name: try other picks for a few minutes
local TOTEM_CONFIRM_WINDOW_SEC = 1.2 -- only count if no red ERROR arrives in this window
local _totemLastConfirmClock = 0
local _totemRejectUntil = {} -- [weaponName] = os.clock() until skip expires
local _totemRoundRobin = 1 -- cycles through all Totem-color weapons; each InvokeServer uses that row's real name
local _totemPendingToken = 0 -- increments per invoke; delayed confirmer checks latest token
local _totemPendingReject = false
local _totemApCache         = { t = 0, lvl = 0 }
local _totemNextActionAt    = 0   -- os.clock() time gate (session only)
local _totemActionsThisRun  = 0   -- number of successful totem sacrifices this run
local _totemWasOnCooldown   = (states.totemCapHitUnix ~= nil)
-- Server-confirmed cap: states.totemSavedServerCap (persisted) + SendNotification parse

-- Totem CD keys are often missing from default `states` (nil fields), so merge loop skips them — load from LS here.
-- Remaining CD = TOTEM_CYCLE_SEC - (os.time() - savedUnix). Roblox os.time() is real UTC wall clock: works after
-- disconnect/rejoin as long as meleernq_settings.json was saved (Auto Save or cap triggered save).
states.totemCapHitUnix = tonumber(LS.totemCapHitUnix)
states.totemSavedServerCap = tonumber(LS.totemSavedServerCap)
states.totemCapFromServerNotify = LS.totemCapFromServerNotify == true

local function totemSanitizeLoadedCooldown()
    local hit = states.totemCapHitUnix
    if not hit then return end
    local now = os.time()
    local elapsed = now - hit
    if elapsed < 0 then
        states.totemCapHitUnix = nil
        forceSave()
        return
    end
    if elapsed >= TOTEM_CYCLE_SEC then
        states.totemCapHitUnix = nil
        states.totemDoneThisCycle = 0
        states.totemCapFromServerNotify = false
        states.totemSavedServerCap = nil
        forceSave()
    end
end
totemSanitizeLoadedCooldown()

local function totemParseMaxFromNotification(msg)
    if type(msg) ~= "string" then return nil end
    -- "You can only sacrifice max 40 weapons every hour!"
    local nmax = msg:match("[Mm]ax%s+(%d+)")
    if nmax then
        local n = tonumber(nmax)
        if n and n >= 1 and n <= 999 then return math.floor(n) end
    end
    local _, mx = msg:match("(%d+)%s*/%s*(%d+)")
    if mx then
        local n = tonumber(mx)
        if n then return math.floor(n) end
    end
    _, mx = msg:match("(%d+)%s+of%s+(%d+)")
    if mx then
        local n = tonumber(mx)
        if n then return math.floor(n) end
    end
    local best = nil
    for n in msg:gmatch("%d+") do
        local v = math.floor(tonumber(n) or 0)
        if v >= 1 and v <= 500 then
            if not best or v > best then best = v end
        end
    end
    return best
end

local function totemNotificationLooksLikeCap(msg)
    if type(msg) ~= "string" then return false end
    local m = msg:lower()
    -- Server string has no "totem" — e.g. "sacrifice max 40 ... every hour!"
    if m:find("sacrifice", 1, true) and m:find("every hour", 1, true) then return true end
    if m:find("totem", 1, true) == nil and m:find("fortune", 1, true) == nil then return false end
    if m:find("max", 1, true) or m:find("limit", 1, true) or m:find("reached", 1, true)
        or m:find("cap", 1, true) or m:find("full", 1, true) or m:find("cannot", 1, true)
        or m:find("already", 1, true) then
        return true
    end
    local a, b = msg:match("(%d+)%s*/%s*(%d+)")
    if a and b and tonumber(a) and tonumber(b) and tonumber(a) >= tonumber(b) then
        return true
    end
    return false
end

--- ERROR notifications we treat as Totem hourly cap (message text varies; may omit "totem")
local function totemSendNotificationIsRelevant(message)
    if type(message) ~= "string" then return false end
    local m = message:lower()
    if m:find("totem", 1, true) or m:find("fortune", 1, true) then return true end
    if m:find("sacrifice", 1, true) and m:find("every hour", 1, true) then return true end
    return false
end

local function getTotemApLevel()
    local now = os.clock()
    if now - _totemApCache.t < 12 then
        return _totemApCache.lvl
    end
    _totemApCache.t = now
    local lvl = 0
    pcall(function()
        local u = invokeR("GetAscendUpgrades")
        if type(u) == "table" then
            lvl = math.floor(tonumber(u[TOTEM_AP_UPGRADE_NAME]) or 0)
            if lvl == 0 then
                for k, v in pairs(u) do
                    if type(k) == "string" and k:find("Totem", 1, true) and k:find("Fortune", 1, true) then
                        local nv = tonumber(v)
                        if nv then lvl = math.floor(nv); break end
                    end
                end
            end
        end
        if lvl == 0 then
            local alt = invokeR("GetAscendUpgradeLevel", TOTEM_AP_UPGRADE_NAME)
            lvl = math.floor(tonumber(alt) or 0)
        end
    end)
    _totemApCache.lvl = lvl
    return lvl
end

local function getTotemMaxPerCycle()
    local calc = TOTEM_BASE_MAX + getTotemApLevel() * 5
    local srv = tonumber(states.totemSavedServerCap)
    if srv and srv > 0 then
        return srv
    end
    return calc
end

--- Returns isOnCooldown, secondsRemaining (0 if not on CD). Clears cycle when CD elapsed.
local function totemInCooldown()
    local hit = states.totemCapHitUnix
    if not hit then
        _totemWasOnCooldown = false
        return false, 0
    end
    local now = os.time()
    local elapsed = now - hit
    if elapsed >= TOTEM_CYCLE_SEC then
        states.totemCapHitUnix = nil
        states.totemDoneThisCycle = 0
        states.totemCapFromServerNotify = false
        states.totemSavedServerCap = nil
        -- CD just reached zero: wait a bit so stale cap text / delayed notifications don't instantly re-lock.
        if _totemWasOnCooldown then
            _totemNextActionAt = math.max(_totemNextActionAt, os.clock() + TOTEM_ACTION_DELAY_SEC)
        end
        _totemWasOnCooldown = false
        if states.autoSave then saveSettings() else forceSave() end
        return false, 0
    end
    _totemWasOnCooldown = true
    return true, TOTEM_CYCLE_SEC - elapsed
end

local function totemWeaponPassesColor(w)
    if not states.totemFilterColor then return false end
    local idx = math.clamp(math.floor(tonumber(states.totemRarityCapIdx) or 1), 1, #SAC_TIERS)
    local oi = tonumber(w.oneIn)
    if not oi or oi == math.huge then return false end
    local maxCap = SAC_TIERS[idx].maxOneIn
    if idx == 1 then
        return oi > 0 and oi <= maxCap
    end
    local minCap = SAC_TIERS[idx - 1].maxOneIn
    return oi > minCap and oi <= maxCap
end

local function formatTotemCd(secs)
    secs = math.max(0, math.floor(secs))
    local m = math.floor(secs / 60)
    local s = secs % 60
    return string.format("%dm%ds", m, s)
end

local function totemActionWaitRemaining()
    local remain = _totemNextActionAt - os.clock()
    if remain <= 0 then return 0 end
    return math.floor(remain + 0.5)
end

local totemStatusLbl
local function updateTotemStatusLbl()
    if not totemStatusLbl then return end
    local maxC = getTotemMaxPerCycle()
    local onCd, remain = totemInCooldown()
    local done = math.min(math.max(0, states.totemDoneThisCycle), maxC)
    local cdStr = onCd and formatTotemCd(remain) or "ready"
    local waitSec = totemActionWaitRemaining()
    if states.totemCapFromServerNotify and onCd then
        totemStatusLbl.Set(string.format("Cap hit | Max=%d (server confirmed) · CD: %s | this run: %d", maxC, cdStr, _totemActionsThisRun))
    elseif waitSec > 0 then
        totemStatusLbl.Set(string.format("Totem: %d/%d done | wait: %ds | this run: %d | AP max: %d", done, maxC, waitSec, _totemActionsThisRun, maxC))
    else
        totemStatusLbl.Set(string.format("Totem: %d/%d done | CD: %s | this run: %d | AP max: %d", done, maxC, cdStr, _totemActionsThisRun, maxC))
    end
end

local function totemPassesNameTickGate(w)
    if not states.totemOnlyTickedNames then return true end
    return _sacNameSelected[w.name] == true
end

local function totemRemoteWeaponName(fullName)
    local n = tostring(fullName or ""):match("^%s*(.-)%s*$") or ""
    if n == "" then return n end
    local low = n:lower()
    for _, t in ipairs(SAC_TIERS) do
        local pref = (t.name .. " "):lower()
        if low:sub(1, #pref) == pref then
            local stripped = n:sub(#pref + 1):match("^%s*(.-)%s*$") or ""
            if stripped ~= "" then return stripped end
            break
        end
    end
    return n
end

local function totemEligibleCountCached()
    local keep = math.max(0, math.floor(tonumber(states.totemKeepQty) or 0))
    local n = 0
    for _, w in ipairs(_sacInv) do
        if totemWeaponPassesColor(w) and w.qty > keep and totemPassesNameTickGate(w) then
            n = n + 1
        end
    end
    return n
end

local function onTotemSendNotification(message, msgType)
    if GEN ~= _G.MeleeRNG_Gen then return end
    if type(message) ~= "string" then return end
    local mt = type(msgType) == "string" and msgType:upper() or ""
    if mt ~= "ERROR" then return end
    if not totemSendNotificationIsRelevant(message) then return end
    -- A relevant red ERROR during pending window means this attempt should NOT count.
    _totemPendingReject = true

    local parsedMax = totemParseMaxFromNotification(message)
    if not parsedMax or parsedMax < 1 then return end

    states.totemSavedServerCap = parsedMax
    _totemApCache.t = 0

    if not totemNotificationLooksLikeCap(message) then
        saveSettings()
        updateTotemStatusLbl()
        return
    end

    -- Ignore stale/replayed cap text until our local progress reached cap.
    -- This prevents CD from restarting early at 0:00 when old text re-fires.
    local localDone = math.max(0, math.floor(tonumber(states.totemDoneThisCycle) or 0))
    if localDone < parsedMax then
        local eligibleNow = totemEligibleCountCached()
        if eligibleNow > 0 then
            updateTotemStatusLbl()
            return
        end
        -- Even if no eligible weapon right now, do not start hourly CD from text alone.
        -- User can refresh/retarget filters; CD starts only after true cap usage.
        updateTotemStatusLbl()
        return
    end

    states.totemDoneThisCycle = math.max(localDone, parsedMax)
    if not states.totemCapHitUnix then
        states.totemCapHitUnix = os.time()
    end
    states.totemCapFromServerNotify = true
    saveSettings()
    updateTotemStatusLbl()
end

SacTab:Section("Sacrifice")
SacTab:Label("All options below save to meleernq_settings.json (with Auto Save on). Weapon name ticks save too.")
SacTab:Label("Refresh ties each weapon to RS.Assets.Weapons for OneIn (color tier). Auto-refresh ~2s after load.")
SacTab:Label("By color: OneIn ≤ dropdown cap. By Name: only ticked rows (ignores color). Keep qty always applies.")
local sacStatusLbl = SacTab:Label("Auto: OFF · idle")
local sacLastLbl   = SacTab:Label("Last: —")

local sacInvLbl
local sacWeaponScroll

local function rebuildSacWeaponRows()
    if not sacWeaponScroll then return end
    for _, c in ipairs(sacWeaponScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    table.sort(_sacInv, function(a, b) return a.name:lower() < b.name:lower() end)
    for i, w in ipairs(_sacInv) do
        local row = Instance.new("TextButton", sacWeaponScroll)
        row.Size = UDim2.new(1, -8, 0, 26)
        row.LayoutOrder = i
        row.BackgroundColor3 = _sacNameSelected[w.name] and Color3.fromRGB(0, 45, 25) or Color3.fromRGB(12, 16, 24)
        row.BorderSizePixel = 0
        row.Text = ""
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -28, 1, 0)
        lbl.Position = UDim2.new(0, 6, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.TextColor3 = _sacNameSelected[w.name] and C.green or C.text
        local tierLbl = select(1, sacTierFromOneIn(w.oneIn))
        local oiDisp = (w.oneIn and w.oneIn < 1e15) and tostring(math.floor(w.oneIn)) or "?"
        lbl.Text = string.format("%s  OneIn=%s  ×%d  R%d  dmg %.0f  %s", tierLbl, oiDisp, w.qty, w.rank, w.damage, w.name)
        local chk = Instance.new("Frame", row)
        chk.Size = UDim2.new(0, 14, 0, 14)
        chk.Position = UDim2.new(1, -20, 0.5, -7)
        chk.BackgroundColor3 = _sacNameSelected[w.name] and C.green or C.border
        chk.BorderSizePixel = 0
        Instance.new("UICorner", chk).CornerRadius = UDim.new(0, 3)
        local tick = Instance.new("TextLabel", chk)
        tick.Size = UDim2.new(1, 0, 1, 0)
        tick.BackgroundTransparency = 1
        tick.Text = "✓"
        tick.TextColor3 = Color3.new(1, 1, 1)
        tick.Font = Enum.Font.GothamBold
        tick.TextSize = 9
        tick.Visible = _sacNameSelected[w.name] == true
        row.MouseButton1Click:Connect(function()
            _sacNameSelected[w.name] = not _sacNameSelected[w.name]
            rebuildSacWeaponRows()
            saveSettings()
        end)
    end
end

local function refreshSacInventory()
    _sacAssetCache = {}
    local raw = invokeR("GetWeaponsInv")
    _sacInv = {}
    if type(raw) == "table" then
        local function pushEntry(e)
            local w = normSacWeapon(e)
            if w and w.qty > 0 then _sacInv[#_sacInv + 1] = w end
        end
        if raw[1] ~= nil then
            for _, e in ipairs(raw) do pushEntry(e) end
        else
            for _, e in pairs(raw) do pushEntry(e) end
        end
    end
    sacEnrichFromAssets()
    local totalQty = 0
    for _, w in ipairs(_sacInv) do totalQty = totalQty + w.qty end
    if sacInvLbl then
        sacInvLbl.Set(string.format("Inv: %d types | %d total qty", #_sacInv, totalQty))
    end
    for _, w in ipairs(_sacInv) do
        local tl = select(1, sacTierFromOneIn(w.oneIn))
        local oi = (w.oneIn and w.oneIn < 1e15) and math.floor(w.oneIn) or -1
        print(string.format("[MeleeRNG/Sac] [OK] %-32s x%-4d  Rank=%-3s  Dmg=%-8s  OneIn=%-10s  %s  | %s",
            w.name, w.qty, tostring(w.rank), tostring(w.damage), oi >= 0 and tostring(oi) or "?", w.type, tl))
    end
    rebuildSacWeaponRows()
    SLbl.Text = string.format("Sacrifice: %d weapon types (OneIn from Assets)", #_sacInv)
end

--- One TotemConfirm call: Totem color = OneIn range (e.g. Galactic). Every matching weapon is a candidate;
--- we cycle round-robin and pass each row's actual w.name (same as Cobalt string).
local function totemExecuteNext()
    if totemActionWaitRemaining() > 0 then
        return false, "wait"
    end
    local gapLeft = TOTEM_MIN_INVOKE_GAP_SEC - (os.clock() - _totemLastConfirmClock)
    if gapLeft > 0 then
        return false, "throttle"
    end
    local onCd = select(1, totemInCooldown())
    if onCd then return false, "cd" end
    local maxC = getTotemMaxPerCycle()
    if states.totemDoneThisCycle >= maxC then
        -- Orphan save: count at max but no hour anchor → was showing "CD: ready" while server still locks
        if not states.totemCapHitUnix then
            states.totemCapHitUnix = os.time()
            saveSettings()
        end
        return false, "local_cap"
    end
    refreshSacInventory()
    local keep = math.max(0, math.floor(tonumber(states.totemKeepQty) or 0))
    local nowClk = os.clock()
    local candidates = {}
    for _, w in ipairs(_sacInv) do
        if totemWeaponPassesColor(w) and w.qty > keep and totemPassesNameTickGate(w) then
            local skipT = _totemRejectUntil[w.name]
            if not skipT or nowClk >= skipT then
                candidates[#candidates + 1] = w
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        local oa = tonumber(a.oneIn) or math.huge
        local ob = tonumber(b.oneIn) or math.huge
        if oa ~= ob then return oa < ob end
        return a.name:lower() < b.name:lower()
    end)
    local nCand = #candidates
    if nCand == 0 then
        if states.totemOnlyTickedNames then
            local hasInColor = false
            local tickInColor = false
            for _, ww in ipairs(_sacInv) do
                if totemWeaponPassesColor(ww) and ww.qty > keep then
                    hasInColor = true
                    if _sacNameSelected[ww.name] then tickInColor = true break end
                end
            end
            if hasInColor and not tickInColor then
                return false, "no_totem_tick"
            end
        end
        return false, "no_weapon"
    end
    local idx = ((_totemRoundRobin - 1) % nCand) + 1
    local w = candidates[idx]
    local function advanceTotemRoundRobin()
        _totemRoundRobin = (idx % nCand) + 1
    end
    local tr = R("TotemConfirm")
    if not tr then return false, "fail" end
    _totemLastConfirmClock = os.clock()
    -- Cobalt-style: one string = that row's inventory weapon name.
    local remoteName = totemRemoteWeaponName(w.name)
    print(string.format("[MeleeRNG/Totem] %d/%d in color · inv=%q -> send=%q", idx, nCand, w.name, remoteName))
    local invokeOk, res = pcall(function() return tr:InvokeServer(remoteName) end)
    if not invokeOk then
        invokeOk, res = pcall(function() return tr:InvokeServer(remoteName, w.type) end)
    end
    if not invokeOk then
        advanceTotemRoundRobin()
        return false, "fail"
    end
    -- Server returns false = rejected (cap or transient); don't force-start 1h CD from this alone.
    if res == false then
        _totemRejectUntil[w.name] = os.clock() + TOTEM_SKIP_AFTER_REJECT_SEC
        states.totemSavedServerCap = maxC
        _totemNextActionAt = math.max(_totemNextActionAt, os.clock() + TOTEM_REJECT_BACKOFF_SEC)
        saveSettings()
        advanceTotemRoundRobin()
        return false, "server_reject"
    end
    -- Count only if no relevant red ERROR appears shortly after this invoke.
    _totemPendingToken = _totemPendingToken + 1
    local myTok = _totemPendingToken
    _totemPendingReject = false
    task.delay(TOTEM_CONFIRM_WINDOW_SEC, function()
        if GEN ~= _G.MeleeRNG_Gen then return end
        if myTok ~= _totemPendingToken then return end
        if _totemPendingReject then return end
        states.totemDoneThisCycle = states.totemDoneThisCycle + 1
        _totemActionsThisRun = _totemActionsThisRun + 1
        -- Last sacrifice of the cycle starts the same 1h window the server uses
        if states.totemDoneThisCycle >= maxC then
            if not states.totemCapHitUnix then
                states.totemCapHitUnix = os.time()
            end
        end
        saveSettings()
        updateTotemStatusLbl()
    end)
    advanceTotemRoundRobin()
    return true, w.name
end

-- Fix JSON that has totemDoneThisCycle >= max but no totemCapHitUnix (never showed hourly CD)
addThread(task.spawn(function()
    task.wait(1.5)
    if GEN ~= _G.MeleeRNG_Gen then return end
    pcall(function()
        local maxC = getTotemMaxPerCycle()
        if states.totemDoneThisCycle >= maxC and not states.totemCapHitUnix then
            states.totemCapHitUnix = os.time()
            forceSave()
            updateTotemStatusLbl()
        end
    end)
end))

SacTab:Button("🔄", "Refresh Inventory", "GetWeaponsInv:InvokeServer() — list + console print", C.accent, function()
    refreshSacInventory()
end)

sacInvLbl = SacTab:Label("Inv: 0 types | 0 total — tap Refresh")

SacTab:Section("Filters (color + name only)")
local sacFilterColorToggle = SacTab:Toggle("By color (OneIn)", "Sacrifice weapons with OneIn ≤ cap for tier below (from Assets) — saved", states.sacFilterColor, function(on)
    states.sacFilterColor = on == true; saveSettings()
end)
local sacFilterNameToggle = SacTab:Toggle("By Name", "Only ticked rows in list — ignores color filter — saved", states.sacFilterName, function(on)
    states.sacFilterName = on == true; saveSettings()
end)

local sacRarityDropdown = SacTab:Dropdown(
    "Sacrifice up through this color",
    "Max OneIn for that color band (saved). Weapons with OneIn ≤ that number match.",
    SAC_DROPDOWN_LABELS,
    math.clamp(states.sacRarityCapIdx, 1, #SAC_TIERS),
    function(_, _, idx)
        states.sacRarityCapIdx = math.clamp(math.floor(tonumber(idx) or 1), 1, #SAC_TIERS)
        saveSettings()
    end
)

SacTab:Label("Tier caps (OneIn): ⬜≤5 · 🟩≤50 · 🟦≤200 · 🟣≤5k · 🟠≤50k · 🩷≤1M · 🟤≤7M · 🩵≤11M · ⬛≤99M")

SacTab:Section("Always keep")
local sacKeepSlider = SacTab:Slider("Always keep qty", "Per weapon type: keep at least this many; sacrifice the rest (saved)", {
    min = 0, max = 999, default = math.clamp(states.sacKeepQty, 0, 999),
    format = function(v) return "keep " .. tostring(math.floor(v)) end,
}, function(v)
    states.sacKeepQty = math.floor(v); saveSettings()
end)

local sacAutoToggle = SacTab:Toggle("Toggle Auto Sacrifice", "Every 1.5s: inventory, filters, FountainSacrifice — saved", states.autoSacrifice, function(on)
    states.autoSacrifice = on == true
    saveSettings()
    sacStatusLbl.Set(on and "Auto: ON · every 1.5s" or "Auto: OFF · idle")
    SLbl.Text = on and "Auto Sacrifice ON" or "Auto Sacrifice OFF"
end)

SacTab:Section("Totem of Fortune")
SacTab:Label("Separate from Fountain: own color cap + keep below. Remote: TotemConfirm(weaponName). Luck ~Rank/10% per slot.")
SacTab:Label("Cap: 25 + AP×5. ERROR notifications update max; 1h CD starts only after local done reaches max (prevents stale text resets).")
SacTab:Label("CD timer uses device os.time() vs saved start — time keeps passing offline; needs settings saved (Auto Save or after cap).")
local totemFilterColorToggle = SacTab:Toggle("Totem: By color (OneIn)", "Totem only — weapons in that tier’s OneIn band only (not “up through”) — saved", states.totemFilterColor, function(on)
    states.totemFilterColor = on == true
    saveSettings()
end)
local totemOnlyTickedToggle = SacTab:Toggle("Totem: only ✓ list names", "ON = TotemConfirm only weapons you tick in the list below that also pass Totem color + keep (same idea as typing one Cobalt name) — saved", states.totemOnlyTickedNames, function(on)
    states.totemOnlyTickedNames = on == true
    saveSettings()
end)
local totemRarityDropdown = SacTab:Dropdown(
    "Totem — only this color tier",
    "Totem matches OneIn inside this band only. Fountain dropdown above still uses “up through” caps.",
    SAC_TOTEM_DROPDOWN_LABELS,
    math.clamp(states.totemRarityCapIdx, 1, #SAC_TIERS),
    function(_, _, idx)
        states.totemRarityCapIdx = math.clamp(math.floor(tonumber(idx) or 1), 1, #SAC_TIERS)
        saveSettings()
    end
)
SacTab:Label("Totem bands: Common ≤5 · Uncommon (5,50] · Rare (50,200] · Epic (200,5k] · Leg (5k,50k] · Mythic (50k,1M] · Galactic (1M,7M] · Godly (7M,11M] · Omni (11M,99M]")
local totemKeepSlider = SacTab:Slider("Totem — always keep qty", "Per weapon type for Totem only; independent of Fountain keep (saved)", {
    min = 0, max = 999, default = math.clamp(states.totemKeepQty, 0, 999),
    format = function(v) return "keep " .. tostring(math.floor(v)) end,
}, function(v)
    states.totemKeepQty = math.floor(v)
    saveSettings()
end)
SacTab:Label("Totem color = OneIn range (e.g. all Galactic). Auto cycles those weapons and calls TotemConfirm(each real name). Optional: only ✓ list names to narrow further.")
totemStatusLbl = SacTab:Label("Totem: —")
local totemLastLbl = SacTab:Label("Totem last: —")
SacTab:Label("Totem auto safety: waits 30s once when hourly CD reaches 0 to avoid stale re-lock text.")
SacTab:Button("📊", "Totem Status", "Refresh progress / cooldown / AP max", C.accent, function()
    updateTotemStatusLbl()
    SLbl.Text = "Totem status updated"
end)
SacTab:Button("🕯️", "Totem: sacrifice 1 (next in color)", "Cycles all weapons in Totem color + keep; uses each inventory name on the remote", C.gold, function()
    local ok, why = totemExecuteNext()
    updateTotemStatusLbl()
    if ok then
        totemLastLbl.Set("Totem last: " .. tostring(why))
        SLbl.Text = "Totem: " .. tostring(why)
    else
        local msg = ({
            cd = "On cooldown",
            local_cap = "At cycle cap (wait CD or refresh)",
            no_weapon = "No weapon (enable Totem By color or refresh inv)",
            no_totem_tick = "Tick weapon(s) in the list that pass Totem color — or turn off Totem only ✓ names",
            server_reject = "Server rejected this weapon — skipped 3m; try others (Cobalt name may differ from auto pick)",
            throttle = "Wait a few seconds between totem calls (anti-spam)",
            fail = "TotemConfirm error (remote missing or InvokeServer threw)",
        })[why] or tostring(why)
        totemLastLbl.Set("Totem last: " .. msg)
        SLbl.Text = "Totem: " .. msg
    end
end)
local totemAutoToggle = SacTab:Toggle("Auto Totem", "Every 1.5s: Totem color cap + keep, highest Rank, TotemConfirm — saved", states.autoTotem, function(on)
    states.autoTotem = on == true
    saveSettings()
    SLbl.Text = on and "Auto Totem ON" or "Auto Totem OFF"
end)

SacTab:Section("By Name — tick rows")
SacTab:Label("Selections are saved. Empty list until Refresh.")

local function sacNextLayoutOrder()
    local m = 0
    for _, ch in ipairs(SacTab._page:GetChildren()) do
        if ch:IsA("GuiObject") and ch.LayoutOrder > m then m = ch.LayoutOrder end
    end
    return m + 1
end

local sacListCard = Instance.new("Frame", SacTab._page)
sacListCard.BackgroundColor3 = C.card
sacListCard.BorderSizePixel = 0
sacListCard.Size = UDim2.new(1, -10, 0, 0)
sacListCard.AutomaticSize = Enum.AutomaticSize.Y
sacListCard.LayoutOrder = sacNextLayoutOrder()
Instance.new("UICorner", sacListCard).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", sacListCard).Color = C.border
local sacCardPad = Instance.new("UIPadding", sacListCard)
sacCardPad.PaddingBottom = UDim.new(0, 8)

sacWeaponScroll = Instance.new("ScrollingFrame", sacListCard)
sacWeaponScroll.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
sacWeaponScroll.Size = UDim2.new(1, -16, 0, 140)
sacWeaponScroll.Position = UDim2.new(0, 8, 0, 8)
sacWeaponScroll.BorderSizePixel = 0
sacWeaponScroll.ScrollBarThickness = 3
sacWeaponScroll.ScrollBarImageColor3 = C.accent
sacWeaponScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
sacWeaponScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", sacWeaponScroll).CornerRadius = UDim.new(0, 6)
local sacListLayout = Instance.new("UIListLayout", sacWeaponScroll)
sacListLayout.Padding = UDim.new(0, 2)
sacListLayout.SortOrder = Enum.SortOrder.LayoutOrder
sacListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local inner = math.min(sacListLayout.AbsoluteContentSize.Y + 6, 240)
    sacWeaponScroll.Size = UDim2.new(1, -16, 0, math.max(120, inner))
end)

task.defer(function()
    pcall(function()
        if sacFilterColorToggle and sacFilterColorToggle.Set then
            sacFilterColorToggle.Set(states.sacFilterColor)
        end
        if sacFilterNameToggle and sacFilterNameToggle.Set then
            sacFilterNameToggle.Set(states.sacFilterName)
        end
        if sacRarityDropdown and sacRarityDropdown.Set then
            sacRarityDropdown.Set(states.sacRarityCapIdx)
        end
        if sacKeepSlider and sacKeepSlider.Set then
            sacKeepSlider.Set(math.clamp(states.sacKeepQty, 0, 999), true)
        end
        if sacAutoToggle and sacAutoToggle.Set then
            sacAutoToggle.Set(states.autoSacrifice)
        end
        if totemAutoToggle and totemAutoToggle.Set then
            totemAutoToggle.Set(states.autoTotem)
        end
        if totemFilterColorToggle and totemFilterColorToggle.Set then
            totemFilterColorToggle.Set(states.totemFilterColor)
        end
        if totemOnlyTickedToggle and totemOnlyTickedToggle.Set then
            totemOnlyTickedToggle.Set(states.totemOnlyTickedNames)
        end
        if totemRarityDropdown and totemRarityDropdown.Set then
            totemRarityDropdown.Set(states.totemRarityCapIdx)
        end
        if totemKeepSlider and totemKeepSlider.Set then
            totemKeepSlider.Set(math.clamp(states.totemKeepQty, 0, 999), true)
        end
        sacStatusLbl.Set(states.autoSacrifice and "Auto: ON · every 1.5s" or "Auto: OFF · idle")
        updateTotemStatusLbl()
    end)
end)

task.defer(function()
    task.wait(2)
    if GEN ~= _G.MeleeRNG_Gen then return end
    pcall(refreshSacInventory)
end)

addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        if not states.autoSacrifice then task.wait(1); continue end
        task.wait(1.5)
        if not sacAnyFilterOn() then
            sacStatusLbl.Set("Auto: ON — enable ≥1 filter")
            continue
        end
        local sacrificed, skipped = 0, 0
        pcall(function()
            _sacAssetCache = {}
            local raw = invokeR("GetWeaponsInv")
            _sacInv = {}
            if type(raw) == "table" then
                local function pushEntry(e)
                    local w = normSacWeapon(e)
                    if w and w.qty > 0 then _sacInv[#_sacInv + 1] = w end
                end
                if raw[1] ~= nil then
                    for _, e in ipairs(raw) do pushEntry(e) end
                else
                    for _, e in pairs(raw) do pushEntry(e) end
                end
            end
            sacEnrichFromAssets()
            rebuildSacWeaponRows()
            local totalQty = 0
            for _, w in ipairs(_sacInv) do totalQty = totalQty + w.qty end
            sacInvLbl.Set(string.format("Inv: %d types | %d total qty", #_sacInv, totalQty))

            local keep = math.max(0, math.floor(tonumber(states.sacKeepQty) or 0))
            for _, w in ipairs(_sacInv) do
                if sacWeaponPasses(w) then
                    local toSac = math.max(0, w.qty - keep)
                    if toSac > 0 then
                        local res = invokeR("FountainSacrifice", w.name, w.type, toSac)
                        if res == false then
                            skipped = skipped + 1
                        else
                            sacrificed = sacrificed + 1
                            sacLastLbl.Set("Last: " .. w.name .. " ×" .. tostring(toSac))
                        end
                    else
                        skipped = skipped + 1
                    end
                else
                    skipped = skipped + 1
                end
            end
        end)
        sacStatusLbl.Set(string.format("Auto: ON · sacrificed %d types · skipped %d · next 1.5s", sacrificed, skipped))
    end
end))

addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        task.wait(1)
        updateTotemStatusLbl()
    end
end))

addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        if not states.autoTotem then task.wait(1); continue end
        task.wait(1.5)
        if not states.totemFilterColor then
            if totemLastLbl then totemLastLbl.Set("Totem auto: turn on Totem: By color (OneIn)") end
            continue
        end
        local ok, why = totemExecuteNext()
        if totemLastLbl then
            if ok then
                totemLastLbl.Set("Totem last: " .. tostring(why))
            elseif why == "no_weapon" or why == "no_totem_tick" or why == "fail" or why == "wait" or why == "server_reject" or why == "throttle" then
                totemLastLbl.Set("Totem auto: " .. tostring(why))
            end
        end
        updateTotemStatusLbl()
    end
end))

-- Totem: server cap + max from RS.Remotes.SendNotification (message, "ERROR")
addThread(task.spawn(function()
    local remotesFolder = RS:WaitForChild("Remotes", 60)
    if not remotesFolder then return end
    local sn = remotesFolder:WaitForChild("SendNotification", 90)
    if not sn then return end
    pcall(function()
        if sn:IsA("RemoteEvent") or sn.ClassName == "UnreliableRemoteEvent" then
            addConn(sn.OnClientEvent:Connect(onTotemSendNotification))
        end
    end)
end))

Win:ChatTab()
local MiscTab = Win:Tab("⚙️", "Misc")

-- ============================================================
-- Cache hitbox parts so we don't scan descendants every frame
-- ── Hitbox pulse variables (Touched-only: no HitMob FireServer — game handles damage) ──
-- Data-driven (this map): BIG 500 ≫ 100k (~5.5x KPM, Test 8b — fewer physics overlap pairs).
-- Tiny 0.01 ≫ 0.05 (~4x KPM, Test 9 — mobs exit bounds more cleanly). CanTouch must be true (Test 7).
-- Combined ~40k+ KPM vs ~22k before these constants.
local HITBOX_BIG_DEFAULT  = 500   -- map-tuned BIG (vs 100k+ = overlap hell)
local HITBOX_BIG_LIGHT    = 350   -- low-lag preset: smaller BIG footprint
local HITBOX_TINY_STUDS   = 0.01
local hitboxExpanded  = false
local hitboxOrigSizes = {}
local _pulseConn      = nil
local _TINY_V         = Vector3.new(HITBOX_TINY_STUDS, HITBOX_TINY_STUDS, HITBOX_TINY_STUDS)
local _pulseActive    = false
local _pulsePhase     = false
local _hitboxCache    = {}
local _hitboxCacheDirty = true
-- Reused every pulse (avoids Vector3.new + table churn)
local _pulseBigVec    = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
local HITBOX_DUTY_MAX    = 12

MoveTab:Section("Hitbox Pulse")
MoveTab:Label("Summary (map-tested): BIG ≈500 studs ≫ 100k for KPM (less physics overlap). Tiny = 0.01 studs ≫ 0.05. CanTouch must stay on. Design target ~40k+ KPM vs ~22k before tuning.")
MoveTab:Label("How it works:")
MoveTab:Label("• Kills: client Touched when Hitbox size changes — this script does not spam HitMob.")
MoveTab:Label("• Duty N: 1 Heartbeat BIG, then N−1 tiny. Lower N = more flips = more Touched (and more work when BIG).")
MoveTab:Label("• Slider = BIG edge length (studs). Tiny size is fixed in code at 0.01 (not slider).")
MoveTab:Label("• Hitbox list rebuilds only when needed: weapon-folder child count changes (watcher ~2s) or a cached part loses Parent — no periodic full rescan.")
MoveTab:Label("Lag: raise duty and/or use 🐢 preset; avoid cranking BIG past what the map needs. Off in menus.")

local hitboxDutySlider, hitboxRadiusSlider

hitboxDutySlider = MoveTab:Slider("Big phase duty (1 big / N heartbeats)", "One frame BIG per cycle, rest tiny. N=2 ≈ half the Heartbeats BIG. Higher N = calmer physics, fewer Touched edges.",
    {min=2, max=HITBOX_DUTY_MAX, default=math.clamp(math.floor(tonumber(states.hitboxDutyCycle) or 2), 2, HITBOX_DUTY_MAX),
     format=function(v) return "1 big / "..tostring(math.floor(v)) end},
    function(v)
        states.hitboxDutyCycle = math.clamp(math.floor(v), 2, HITBOX_DUTY_MAX)
        saveSettings()
    end)

hitboxRadiusSlider = MoveTab:Slider("BIG size (studs)", "Edge length of the huge box each duty BIG frame. ~500 matches tested sweet spot; very large values often hurt KPM here (overlap pairs).",
    {min=10, max=100000, default=hitboxSize,
     format=function(v) return math.floor(v).." studs" end},
    function(v)
        hitboxSize = math.floor(v)
        _pulseBigVec = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        saveSettings()
    end)

local function applyHitboxPulsePreset(title, duty, radius)
    local d = math.clamp(math.floor(duty), 2, HITBOX_DUTY_MAX)
    local r = math.clamp(math.floor(radius), 10, 100000) -- max still 100k if you override via slider
    if hitboxDutySlider and type(hitboxDutySlider.Set) == "function"
        and hitboxRadiusSlider and type(hitboxRadiusSlider.Set) == "function" then
        hitboxDutySlider.Set(d)
        hitboxRadiusSlider.Set(r)
    else
        states.hitboxDutyCycle = d
        hitboxSize = r
        _pulseBigVec = Vector3.new(r, r, r)
    end
    saveSettings()
    SLbl.Text = "⚡ Preset: " .. title
end

MoveTab:Label("Presets — tap to save duty + BIG size (tiny stays 0.01):")
MoveTab:Button("⚡", "Max farm — duty 2", "BIG 500 · highest flip rate + map-tuned reach", C.green, function()
    applyHitboxPulsePreset("Max farm — duty 2", 2, HITBOX_BIG_DEFAULT)
end)
MoveTab:Button("⚖️", "Balanced — duty 5", "BIG 500 · same reach as ⚡, BIG only 1/5 Heartbeats (lighter physics)", C.accent, function()
    applyHitboxPulsePreset("Balanced — duty 5", 5, HITBOX_BIG_DEFAULT)
end)
MoveTab:Button("🐢", "Low lag — duty 10", "BIG 350 · smaller BIG footprint + rare BIG frames", C.sub, function()
    applyHitboxPulsePreset("Low lag — duty 10", 10, HITBOX_BIG_LIGHT)
end)

-- workspace.[PlayerName] holds the player's equipped weapon models
-- Each weapon model contains a BasePart named "Hitbox"
local function getPlayerWeaponFolder()
    return workspace:FindFirstChild(LP.Name)
end

local function restoreHitboxes()
    for hb, origSize in pairs(hitboxOrigSizes) do
        pcall(function()
            if hb and hb.Parent then hb.Size = origSize end
        end)
    end
    hitboxOrigSizes = {}
end

local function rebuildHitboxCache()
    _hitboxCache = {}
    local folder = getPlayerWeaponFolder()
    if not folder then return end
    for _, weapon in ipairs(folder:GetChildren()) do
        if weapon:IsA("Model") then
            for _, desc in pairs(weapon:GetDescendants()) do
                if desc:IsA("BasePart") and desc.Name == "Hitbox" then
                    if not hitboxOrigSizes[desc] then
                        hitboxOrigSizes[desc] = desc.Size
                    end
                    desc.CanTouch = true -- Test 7: false ~8.8k vs true ~37.6k KPM — required for Touched
                    _hitboxCache[#_hitboxCache+1] = desc
                end
            end
        end
    end
    _hitboxCacheDirty = false
end

-- Equip/unequip: child count changes → dirty → next Heartbeat rebuildHitboxCache
addThread(task.spawn(function()
    local lastCount = 0
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        task.wait(2)
        local folder = getPlayerWeaponFolder()
        local count = folder and #folder:GetChildren() or 0
        if count ~= lastCount then
            lastCount = count
            _hitboxCacheDirty = true
        end
    end
end))

local function setHitboxPulse(on)
    _pulseActive = on
    hitboxExpanded = on
    if on then
        _pulseBigVec = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        _hitboxCacheDirty = true
        if _pulseConn then _pulseConn:Disconnect() end

        local _dutyTick = 0

        _pulseConn = RunService.Heartbeat:Connect(function()
            if GEN ~= _G.MeleeRNG_Gen or not _pulseActive then
                if _pulseConn then _pulseConn:Disconnect(); _pulseConn = nil end
                return
            end

            if _hitboxCacheDirty then
                rebuildHitboxCache()
            end

            -- Duty cycle: BIG only 1 frame per N (rest TINY). Touched fires on size change.
            _dutyTick = _dutyTick + 1
            local duty = math.clamp(math.floor(tonumber(states.hitboxDutyCycle) or 2), 2, HITBOX_DUTY_MAX)
            _pulsePhase = ((_dutyTick - 1) % duty) == 0
            local newSize = _pulsePhase and _pulseBigVec or _TINY_V
            local hCache = _hitboxCache
            local nh = #hCache
            for i = 1, nh do
                local hb = hCache[i]
                if hb and hb.Parent then
                    if hb.Size ~= newSize then hb.Size = newSize end
                else
                    _hitboxCacheDirty = true
                end
            end
        end)
        addConn(_pulseConn)
        rebuildHitboxCache()
        SLbl.Text = string.format("⚡ Pulse ON | %.0f studs | %d hitboxes | duty 1/%d (Touched only)", hitboxSize, #_hitboxCache, math.clamp(math.floor(tonumber(states.hitboxDutyCycle) or 2), 2, HITBOX_DUTY_MAX))
    else
        if _pulseConn then _pulseConn:Disconnect(); _pulseConn = nil end
        for i = 1, #_hitboxCache do
            local hb = _hitboxCache[i]
            if hb and hb.Parent and hitboxOrigSizes[hb] then
                hb.Size = hitboxOrigSizes[hb]
            end
        end
        _hitboxCache = {}
        SLbl.Text = "Pulse OFF — hitboxes restored"
    end
end

local hitboxPulseToggle = MoveTab:Toggle("⚡ Hitbox Pulse", "BIG/tiny duty cycle on weapon Hitboxes (tiny = 0.01). Kills via Touched — no HitMob batch in this loop.", states.hitboxPulse, function(on)
    states.hitboxPulse = on
    setHitboxPulse(on)
    saveSettings()
end)

task.defer(function()
    if states.hitboxPulse then
        setHitboxPulse(true)
        pcall(function()
            if hitboxPulseToggle and hitboxPulseToggle.Set then
                hitboxPulseToggle.Set(true)
            end
        end)
    end
end)

MoveTab:Button("🔍", "Print Hitbox Sizes", "Lists all weapons and current Hitbox sizes", C.sub, function()
    local folder = getPlayerWeaponFolder()
    if not folder then SLbl.Text = "⚠ workspace." .. LP.Name .. " not found"; return end
    local count = 0
    for _, weapon in ipairs(folder:GetChildren()) do
        if weapon:IsA("Model") then
            for _, desc in pairs(weapon:GetDescendants()) do
                if desc:IsA("BasePart") and desc.Name == "Hitbox" then
                    count = count + 1
                    print(string.format("[MeleeRNG] Hitbox: %-30s  Size: %.1f x %.1f x %.1f",
                        weapon.Name, desc.Size.X, desc.Size.Y, desc.Size.Z))
                end
            end
        end
    end
    if count == 0 then print("[MeleeRNG] No Hitbox parts found in workspace." .. LP.Name) end
    SLbl.Text = count .. " hitboxes found — check output"
end)

MoveTab:Section("Walk Speed")
MoveTab:Slider("Walk Speed", "Default 16 · Max 250", {min=0, max=250, default=walkSpeedVal}, function(v)
    walkSpeedVal = math.floor(v); saveSettings()
    local h = getHuman(); if h then h.WalkSpeed = walkSpeedVal end
end)

MoveTab:Section("Hacks")
MoveTab:Toggle("🚀 Infinite Jump", "Jump while airborne", states.infJump, function(on)
    states.infJump = on; saveSettings()
end)
MoveTab:Toggle("👻 No Clip", "Walk through walls", states.noclip, function(on)
    states.noclip = on; saveSettings()
end)
MoveTab:Toggle("🛡️ God Mode", "Lock health at max", states.godMode, function(on)
    states.godMode = on; saveSettings()
end)
MoveTab:Toggle("🦅 Fly", "WASD + E/Q to go up/down", states.fly, function(on)
    states.fly = on; saveSettings()
    if not on then
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    end
end)
MoveTab:Toggle("⏱️ Anti AFK", "Game AFKScript is disabled on load (no kick timer). Optional: every 60s synthetic click if you still want input-based backup.", states.antiAfk, function(on)
    states.antiAfk = on; saveSettings()
end)
MoveTab:Toggle("💡 Full Bright", "Max ambient light, remove fog", states.fullBright, function(on)
    states.fullBright = on; saveSettings()
end)

MoveTab:Section("Actions")
MoveTab:Button("📋", "Print Position", "Prints XYZ + current area to output", C.accent, function()
    local r = getRoot(); if not r then SLbl.Text = "No character"; return end
    local p = r.Position
    local area = invokeR("GetArea")
    local areaName = area and area.Name or "Unknown"
    local msg = string.format("X=%.1f Y=%.1f Z=%.1f | Area: %s | Kills: %s",
        p.X, p.Y, p.Z, areaName, tostring(getKills()))
    print("[MeleeRNG] " .. msg); SLbl.Text = msg
end)
MoveTab:Button("🔄", "Respawn", "Kills character", C.red, function()
    local h = getHuman(); if h then h.Health = 0 end
end)
MoveTab:Button("🌀", "Fire Nearest Machine", "Fires nearest workspace.Machines ProximityPrompt (no teleport — executor fireproximityprompt)", C.green, function()
    local root = getRoot(); if not root then SLbl.Text = "No character"; return end
    local machines = workspace:FindFirstChild("Machines")
    if not machines then SLbl.Text = "⚠ workspace.Machines not found"; return end
    -- ProximityPrompt is a DIRECT child of each machine model (confirmed from explorer image)
    -- Structure: workspace.Machines.[MachineName].ProximityPrompt
    local best, bestDist, bestPrompt = nil, math.huge, nil
    for _, machine in pairs(machines:GetChildren()) do
        -- Direct child ProximityPrompt
        local prompt = machine:FindFirstChild("ProximityPrompt")
        if prompt and prompt:IsA("ProximityPrompt") then
            local hrp = machine:FindFirstChild("HumanoidRootPart")
                     or machine.PrimaryPart
            local pos
            if hrp then
                pos = hrp.Position
            else
                local ok, bb = pcall(function() return machine:GetBoundingBox() end)
                if ok then pos = bb.Position end
            end
            if pos then
                local d = (root.Position - pos).Magnitude
                if d < bestDist then
                    bestDist = d; bestPrompt = prompt; best = machine
                end
            end
        end
    end
    if bestPrompt then
        pcall(function() fireproximityprompt(bestPrompt) end)
        SLbl.Text = string.format("Fired prompt: %s (%.0f studs)", best.Name, bestDist)
    else
        SLbl.Text = "⚠ No direct ProximityPrompt found in workspace.Machines children"
    end
end)

-- ============================================================
--  ESP TAB
-- ============================================================
ESPTab:Section("Mob ESP")
ESPTab:Toggle("👹 Mob ESP", "Billboard tags on all mobs in workspace.Mobs", states.espMobs, function(on)
    states.espMobs = on; saveSettings()
    if not on then
        for _, bb in pairs(espBillboards) do pcall(function() bb:Destroy() end) end
        espBillboards = {}
    end
end)

ESPTab:Section("Info")
ESPTab:Label("Mob ESP attaches BillboardGui to Head/UpperTorso. Loot ESP attaches to PrimaryPart. All removed on Stop.")

-- ============================================================
--  AREAS TAB
-- ============================================================
AreaTab:Section("Teleport to Area")
AreaTab:Label("Areas discovered live from workspace.Areas.\nAreas require MinimumKills to unlock.")

local AreaListFrame = Instance.new("Frame", AreaTab._page)
AreaListFrame.Size = UDim2.new(1,-10,0,280); AreaListFrame.BackgroundColor3 = C.card
AreaListFrame.BorderSizePixel = 0; AreaListFrame.LayoutOrder = 5; AreaListFrame.ClipsDescendants = true
Instance.new("UICorner", AreaListFrame).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", AreaListFrame).Color = C.border

local AreaScroll = Instance.new("ScrollingFrame", AreaListFrame)
AreaScroll.Size = UDim2.new(1,-6,1,-4); AreaScroll.Position = UDim2.new(0,3,0,4)
AreaScroll.BackgroundTransparency = 1; AreaScroll.BorderSizePixel = 0
AreaScroll.ScrollBarThickness = 3; AreaScroll.ScrollBarImageColor3 = C.accent
AreaScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; AreaScroll.CanvasSize = UDim2.new(0,0,0,0)
local AreaLayout = Instance.new("UIListLayout", AreaScroll)
AreaLayout.Padding = UDim.new(0,3); AreaLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function buildAreaList()
    for _, c in pairs(AreaScroll:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
    end
    local areasFolder = workspace:FindFirstChild("Areas")
    if not areasFolder then return end
    local areas = areasFolder:GetChildren()
    table.sort(areas, function(a,b)
        return (tonumber(a:GetAttribute("MinimumKills")) or 0) <
               (tonumber(b:GetAttribute("MinimumKills")) or 0)
    end)
    for i, area in ipairs(areas) do
        local minKills   = tonumber(area:GetAttribute("MinimumKills")) or 0
        local minAscends = tonumber(area:GetAttribute("MinAscends")) or 0
        local myKills    = getKills()
        local myAscends  = getAscends()
        local unlocked   = myKills >= minKills and myAscends >= minAscends
        local btn = Instance.new("TextButton", AreaScroll)
        btn.Size = UDim2.new(1,-4,0,36); btn.LayoutOrder = i
        btn.BackgroundColor3 = unlocked and Color3.fromRGB(0,30,15) or C.card
        btn.BorderSizePixel = 0; btn.Text = ""
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
        local bStroke = Instance.new("UIStroke", btn)
        bStroke.Color = unlocked and C.green or C.border; bStroke.Thickness = 1

        local nLbl = Instance.new("TextLabel", btn)
        nLbl.Text = area.Name; nLbl.Size = UDim2.new(0.55,0,1,0); nLbl.Position = UDim2.new(0,10,0,0)
        nLbl.BackgroundTransparency = 1; nLbl.TextColor3 = unlocked and C.green or C.sub
        nLbl.Font = Enum.Font.GothamBold; nLbl.TextSize = 10; nLbl.TextXAlignment = Enum.TextXAlignment.Left

        local reqLbl = Instance.new("TextLabel", btn)
        local reqStr = minAscends > 0
            and string.format("⚔%s | 🌟%d", tostring(minKills), minAscends)
            or  string.format("⚔ %s kills", tostring(minKills))
        reqLbl.Text = reqStr; reqLbl.Size = UDim2.new(0.45,-10,1,0); reqLbl.Position = UDim2.new(0.55,0,0,0)
        reqLbl.BackgroundTransparency = 1; reqLbl.TextColor3 = C.sub
        reqLbl.Font = Enum.Font.Code; reqLbl.TextSize = 8; reqLbl.TextXAlignment = Enum.TextXAlignment.Right

        local aName = area.Name
        btn.MouseButton1Click:Connect(function()
            local root = getRoot(); if not root then SLbl.Text = "No character"; return end
            local areaRef = areasFolder:FindFirstChild(aName)
            if not areaRef then SLbl.Text = "⚠ Area not found"; return end
            -- Teleport confirmed from dump: HumanoidRootPart.CFrame = area.SafeAreaSpawn.CFrame
            local spawn = areaRef:FindFirstChild("SafeAreaSpawn")
            if spawn then
                local ok = pcall(function()
                    root.CFrame = spawn.CFrame * CFrame.new(0,3,0)
                end)
                SLbl.Text = ok and ("TP → " .. aName) or "⚠ Teleport failed"
            else
                SLbl.Text = "⚠ No SafeAreaSpawn in " .. aName
            end
        end)
    end
end

AreaTab:Button("🔄", "Refresh Area List", "Re-scans workspace.Areas", C.accent, function()
    buildAreaList(); SLbl.Text = "Area list refreshed"
end)
task.defer(buildAreaList)

AreaTab:Section("Current Area")
local CurAreaLbl = AreaTab:Label("Current area: checking...")
task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        task.wait(3)
        pcall(function()
            local area = invokeR("GetArea")
            if area then
                CurAreaLbl.Set("Current area: " .. area.Name ..
                    " | Kills: " .. tostring(getKills()) ..
                    " | Ascends: " .. tostring(getAscends()))
            end
        end)
    end
end)

-- ============================================================
--  FEATURE LOGIC LOOPS
-- ============================================================

-- ── Infinite Jump ─────────────────────────────────────────────
addConn(UserInputService.JumpRequest:Connect(function()
    if GEN ~= _G.MeleeRNG_Gen then return end
    if states.infJump then
        local h = getHuman(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- ── Auto Mana → SP (CalculateManaPrice / ConvertMana — 1 unit, throttled ~10/s) ──
local _manaConvLast = 0
addConn(RunService.Heartbeat:Connect(function()
    if GEN ~= _G.MeleeRNG_Gen then return end
    if not states.autoManaToSP then return end
    local now = os.clock()
    if now - _manaConvLast < 0.1 then return end
    _manaConvLast = now
    pcall(function()
        local cost = invokeR("CalculateManaPrice", 1)
        if cost == nil or cost == false then return end
        local c = (typeof(cost) == "number" and cost) or tonumber(cost)
        if c == nil or c ~= c or c < 0 then return end  -- need finite, non‑negative price
        local m = tonumber(getMana()) or 0
        if m < c then return end  -- not enough mana for this 1× SP step; skip remote
        invokeR("ConvertMana", 1)
    end)
end))

-- ── Noclip (cached BaseParts) ─────────────────────────────────
local noclipParts, noclipConns = {}, {}
local function clearNoclipConns()
    for _, c in ipairs(noclipConns) do pcall(function() c:Disconnect() end) end
    noclipConns = {}
end
local function rebuildNoclipParts(char)
    table.clear(noclipParts); clearNoclipConns()
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then noclipParts[#noclipParts+1] = d end
    end
    noclipConns[#noclipConns+1] = char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then noclipParts[#noclipParts+1] = d end
    end)
end
rebuildNoclipParts(getChar())

local _lastNoclipPrune = 0
addConn(RunService.Stepped:Connect(function()
    if GEN ~= _G.MeleeRNG_Gen then return end
    if not states.noclip then return end
    local now = os.clock()
    if now - _lastNoclipPrune > 5 then
        _lastNoclipPrune = now
        for i=#noclipParts,1,-1 do
            if not (noclipParts[i] and noclipParts[i].Parent) then
                table.remove(noclipParts, i)
            end
        end
    end
    for _, p in ipairs(noclipParts) do
        if p and p.Parent then p.CanCollide = false end
    end
end))

-- ── God Mode ─────────────────────────────────────────────────
local _lastGod = 0
addConn(RunService.Heartbeat:Connect(function()
    if GEN ~= _G.MeleeRNG_Gen then return end
    if not states.godMode then return end
    local now = os.clock(); if now - _lastGod < 0.5 then return end
    _lastGod = now
    local h = getHuman()
    if h then
        if h.MaxHealth ~= math.huge then h.MaxHealth = math.huge end
        if h.Health    ~= math.huge then h.Health    = math.huge end
    end
end))

-- ── Fly ───────────────────────────────────────────────────────
addConn(RunService.Heartbeat:Connect(function()
    if GEN ~= _G.MeleeRNG_Gen then return end
    if states.fly then
        local root = getRoot(); if not root then return end
        if not flyBV then
            flyBV = Instance.new("BodyVelocity", root)
            flyBV.MaxForce = Vector3.new(1e5,1e5,1e5); flyBV.Velocity = Vector3.zero
        end
        if not flyBG then
            flyBG = Instance.new("BodyGyro", root)
            flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); flyBG.D = 100
        end
        local cam = workspace.CurrentCamera; local spd = 60; local mv = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then mv = mv + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then mv = mv - Vector3.new(0,1,0) end
        if mv.Magnitude > 0 then mv = mv.Unit end
        flyBV.Velocity = mv * spd; flyBG.CFrame = cam.CFrame
        local h = getHuman(); if h then h:ChangeState(Enum.HumanoidStateType.Physics) end
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    end
end))

-- ── Full Bright ───────────────────────────────────────────────
local _fbApplied = false
local _origLight = {
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
}
addConn(RunService.Heartbeat:Connect(function()
    if GEN ~= _G.MeleeRNG_Gen then return end
    if states.fullBright then
        if _fbApplied then return end; _fbApplied = true
        Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 10; Lighting.FogEnd = 1e6; Lighting.FogStart = 1e6
    elseif _fbApplied then
        _fbApplied = false
        Lighting.Ambient = _origLight.Ambient; Lighting.OutdoorAmbient = _origLight.OutdoorAmbient
        Lighting.Brightness = _origLight.Brightness
        Lighting.FogEnd = _origLight.FogEnd; Lighting.FogStart = _origLight.FogStart
    end
end))

-- ── Anti AFK ─────────────────────────────────────────────────
-- Kill the game’s AFK LocalScript (no getrawmetatable / newcclosure). Stops its RenderStepped / TP kick path.
local function disableGameAfkScript()
    pcall(function()
        local ps = LP:FindFirstChild("PlayerScripts")
        if not ps then return end
        local s = ps:FindFirstChild("AFKScript")
        if s and s:IsA("LocalScript") then
            s.Disabled = true
        end
    end)
end

addThread(task.spawn(function()
    local ps = LP:WaitForChild("PlayerScripts", 45)
    if GEN ~= _G.MeleeRNG_Gen or not ps then return end
    disableGameAfkScript()
    addConn(ps.ChildAdded:Connect(function(child)
        if GEN ~= _G.MeleeRNG_Gen then return end
        if child.Name == "AFKScript" and child:IsA("LocalScript") then
            child.Disabled = true
        end
    end))
    while GEN == _G.MeleeRNG_Gen do
        task.wait(8)
        disableGameAfkScript()
    end
end))

-- Optional backup: game AFK sometimes keys off InputBegan; VIM click path + VirtualUser fallback.
-- VirtualUser:ClickButton2 is camera-side and skips that path.
local function sendAntiAfkInput()
    local vx, vy = 1, 1
    local cam = workspace.CurrentCamera
    if cam then
        local vs = cam.ViewportSize
        vx = math.max(0, math.floor(vs.X * 0.5))
        vy = math.max(0, math.floor(vs.Y * 0.5))
    end
    local okVim = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(vx, vy, 0, true)  -- 0 = left, down
        task.wait()
        vim:SendMouseButtonEvent(vx, vy, 0, false)
    end)
    if okVim then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.new(vx, vy))
    end)
end

addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        task.wait(60)
        if states.antiAfk then
            sendAntiAfkInput()
        end
    end
end))

-- ── WalkSpeed enforcement (re-applies on server reset via metatable) ──
local _speedConn = nil
local function enforceSpeed()
    local h = getHuman(); if not h then return end
    h.WalkSpeed = walkSpeedVal
    if _speedConn then _speedConn:Disconnect() end
    _speedConn = h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if GEN ~= _G.MeleeRNG_Gen then if _speedConn then _speedConn:Disconnect() end return end
        if h.WalkSpeed ~= walkSpeedVal then h.WalkSpeed = walkSpeedVal end
    end)
    addConn(_speedConn)
end
do local h = getHuman(); if h then h.WalkSpeed = walkSpeedVal end end
enforceSpeed()

-- ── ESP — Mob & Loot ─────────────────────────────────────────
local function makeBillboard(parent, text, color, yOff)
    local bb = Instance.new("BillboardGui", parent)
    bb.Size = UDim2.new(0,120,0,24); bb.StudsOffset = Vector3.new(0, yOff or 3, 0)
    bb.AlwaysOnTop = true; bb.MaxDistance = 200
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = color or C.red
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextStrokeTransparency = 0.2
    return bb
end

addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        task.wait(0.6)

        -- Mob ESP
        if states.espMobs then
            local mobs = workspace:FindFirstChild("Mobs")
            if mobs then
                -- Remove stale
                for model, bb in pairs(espBillboards) do
                    if not isMobAlive(model) then
                        bb:Destroy(); espBillboards[model] = nil
                    end
                end
                -- Add new
                -- Mobs have no Humanoid — label uses model name + boss type
                for _, model in pairs(mobs:GetChildren()) do
                    if model:IsA("Model") and isMobAlive(model) and not espBillboards[model] then
                        -- Attach to Head if present (visible part), else HumanoidRootPart
                        -- HumanoidRootPart has Transparency=1 so billboard needs a visible anchor
                        local anchor = model:FindFirstChild("Head")
                                    or model:FindFirstChild("UpperTorso")
                                    or model:FindFirstChild("HumanoidRootPart")
                        if anchor then
                            local isBoss  = model:GetAttribute("Boss") == true
                            local isMega  = model:GetAttribute("MegaBoss") == true
                            local col     = isMega and C.red or isBoss and C.gold or C.orange
                            local tag     = isMega and " [MEGA]" or isBoss and " [BOSS]" or ""
                            local label   = model.Name .. tag
                            local bb = makeBillboard(anchor, label, col, 2.5)
                            espBillboards[model] = bb
                        end
                    end
                end
            end
        elseif next(espBillboards) then
            for _, bb in pairs(espBillboards) do pcall(function() bb:Destroy() end) end
            espBillboards = {}
        end


    end
end))

-- ── CharacterAdded ────────────────────────────────────────────
addConn(LP.CharacterAdded:Connect(function(c)
    if GEN ~= _G.MeleeRNG_Gen then return end
    task.wait(0.5)
    rebuildNoclipParts(c)
    local h = c:WaitForChild("Humanoid", 5)
    if h then h.WalkSpeed = walkSpeedVal end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    enforceSpeed()
    _hitboxCacheDirty = true
end))

-- ============================================================
-- ── Auto Ascend Loop ──────────────────────────────────────────
-- ConfirmAscend:InvokeServer() — kill gate is (2 + ascends)×1M (AscendUIController), not area MinimumKills
addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        if not states.autoAscend then task.wait(2); continue end
        pcall(function()
            local need = getAscendKillsRequired()
            if (tonumber(getKills()) or 0) < need then return end
            local area = invokeR("GetArea"); if not area then return end
            local nextPortal = area:FindFirstChild("NextPortal"); if not nextPortal then return end
            local dest = nextPortal:GetAttribute("Destination")
            local beforeA = tonumber(getAscends()) or 0
            local ok = invokeR("ConfirmAscend")
            if not ok then return end
            if teleportAfterAscendIfConfirmed(beforeA) then
                SLbl.Text = "✓ Ascended → " .. tostring(dest or "?") .. " | TP " .. formatAscendTpSaved()
            end
        end)
        task.wait(5)
    end
end))

-- ── Periodic DMG multiplier refresh ──────────────────────────
addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        task.wait(30)
        pcall(getDmgMulti)
    end
end))

-- ============================================================
--  STOP BUTTON
-- ============================================================

-- ── Kill Rate Tracking + Ascend ETA ───────────────────────────────────────
local _killHistory  = {}
local _KILL_WINDOW  = 60
local _lastKillCount = 0

local function recordKills()
    local now   = os.clock()
    local kills = getKills()
    if kills ~= _lastKillCount then
        _lastKillCount = kills
        _killHistory[#_killHistory+1] = {t=now, k=kills}
    end
    local cutoff = now - _KILL_WINDOW
    local i = 1
    while i <= #_killHistory and _killHistory[i].t < cutoff do i = i+1 end
    if i > 1 then
        for j = 1, #_killHistory-i+1 do _killHistory[j] = _killHistory[j+i-1] end
        for j = #_killHistory-i+2, #_killHistory do _killHistory[j] = nil end
    end
end

local function getKillRate()
    if #_killHistory < 2 then return 0 end
    local oldest = _killHistory[1]; local newest = _killHistory[#_killHistory]
    local dt = newest.t - oldest.t
    if dt < 1 then return 0 end
    return (newest.k - oldest.k) / dt * 60
end

local function fmtTime(secs)
    if secs <= 0 or secs ~= secs then return "—" end
    if secs > 86400*30 then return ">30 days" end
    local d=math.floor(secs/86400); local h=math.floor((secs%86400)/3600)
    local m=math.floor((secs%3600)/60); local s=math.floor(secs%60)
    if d>0 then return string.format("%dd %dh %dm",d,h,m) end
    if h>0 then return string.format("%dh %dm %ds",h,m,s) end
    if m>0 then return string.format("%dm %ds",m,s) end
    return string.format("%ds",s)
end

-- next portal name (or nil), kills short of req, total kills required = (2+ascends)×1M
local function getAscendETA()
    local req = getAscendKillsRequired()
    local killsNeeded = math.max(0, req - (tonumber(getKills()) or 0))
    local dest
    pcall(function()
        local area = invokeR("GetArea"); if not area then return end
        local np = area:FindFirstChild("NextPortal"); if not np then return end
        dest = np:GetAttribute("Destination")
    end)
    return dest, killsNeeded, req
end

addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        recordKills()
        task.wait(0.5)
    end
end))

MiscTab:Section("Stats & Kill Rate")
local StatsLbl = MiscTab:Label("Kills: — | Mana: — | SP: — | Ascends: —")
local KPMLbl   = MiscTab:Label("KPM: — | ETA ascend: —")
local ETALbl   = MiscTab:Label("Ascend: — / — kills —")

addThread(task.spawn(function()
    while true do
        if GEN ~= _G.MeleeRNG_Gen then break end
        task.wait(1)
        local kpm = getKillRate()
        pcall(function()
            StatsLbl.Set(string.format("Kills: %s | Mana: %s | SP: %s | Ascends: %s",
                tostring(getKills()), tostring(getMana()), tostring(getSP()), tostring(getAscends())))
            local dest, killsNeeded, req = getAscendETA()
            if req then
                local etaSecs = (kpm>0 and killsNeeded>0) and (killsNeeded/kpm*60) or nil
                local etaStr  = etaSecs and fmtTime(etaSecs) or (killsNeeded==0 and "READY" or "—")
                local destStr = dest and tostring(dest) or "?"
                KPMLbl.Set(string.format("KPM: %.1f | ETA ascend → %s: %s", kpm, destStr, etaStr))
                ETALbl.Set(string.format("Ascend: %s / %s kills (%s more) → %s",
                    tostring(getKills()), tostring(req), tostring(killsNeeded), destStr))
            else
                KPMLbl.Set(string.format("KPM: %.1f | Ascend: —", kpm))
                ETALbl.Set("Ascend: —")
            end
        end)
    end
end))

MiscTab:Section("Ascend")
local autoAscendToggle = MiscTab:Toggle("⬆️ Auto Ascend", "When kills ≥ (2 + your Ascends) × 1M — saved to meleernq_settings.json", states.autoAscend, function(on)
    states.autoAscend = on == true
    saveSettings()
    SLbl.Text = states.autoAscend and "Auto Ascend ON" or "Auto Ascend OFF"
end)

task.defer(function()
    pcall(function()
        if autoAscendToggle and autoAscendToggle.Set then
            autoAscendToggle.Set(states.autoAscend)
        end
    end)
end)

MiscTab:Label("Post-ascend teleport: stand where you want, tap Set — saved with settings.")
local ascendTpLbl = MiscTab:Label("")
local function refreshAscendTpLbl()
    ascendTpLbl.Set("Saved TP (+3 studs Y): " .. formatAscendTpSaved())
end
refreshAscendTpLbl()

MiscTab:Button("📍", "Set Ascend TP Here", "Saves HumanoidRootPart position as after-ascend teleport target", C.green, function()
    local root = getRoot()
    if not root then SLbl.Text = "⚠ No character"; return end
    local p = root.Position
    states.ascendAfterTpX = p.X
    states.ascendAfterTpY = p.Y
    states.ascendAfterTpZ = p.Z
    saveSettings()
    refreshAscendTpLbl()
    SLbl.Text = "✓ Ascend TP saved — " .. formatAscendTpSaved()
end)
MiscTab:Button("↩", "Reset Ascend TP to Default", "Forgotten Valley coords (496.9, 222.1, -7380.4)", C.sub, function()
    states.ascendAfterTpX = DEF_ASCEND_TP_X
    states.ascendAfterTpY = DEF_ASCEND_TP_Y
    states.ascendAfterTpZ = DEF_ASCEND_TP_Z
    saveSettings()
    refreshAscendTpLbl()
    SLbl.Text = "✓ Ascend TP reset to default"
end)

MiscTab:Button("⬆️", "Ascend Now", "ConfirmAscend — then TP only if Ascends stat increases", C.gold, function()
    local beforeA = tonumber(getAscends()) or 0
    local ok = invokeR("ConfirmAscend")
    if not ok then
        SLbl.Text = "⚠ Not ready (kill requirement not met)"
        return
    end
    if teleportAfterAscendIfConfirmed(beforeA) then
        SLbl.Text = "✓ Ascended — TP " .. formatAscendTpSaved()
    else
        SLbl.Text = "⚠ Ascends unchanged — no TP (server did not apply ascend?)"
    end
end)
MiscTab:Button("🎯", "Check Ascend Status", "Shows (2+Ascends)×1M kill gate vs your kills + next portal", C.accent, function()
    local req = getAscendKillsRequired()
    local have = tonumber(getKills()) or 0
    local more = math.max(0, req - have)
    local dest = nil
    pcall(function()
        local area = invokeR("GetArea")
        if not area then return end
        local np = area:FindFirstChild("NextPortal")
        if not np then return end
        dest = np:GetAttribute("Destination")
    end)
    SLbl.Text = string.format(
        "Ascend: %s / %s kills (%s more) | ascends=%s | next → %s",
        tostring(have), tostring(req), tostring(more), tostring(getAscends()), tostring(dest or "?"))
end)

MiscTab:Section("Machines (workspace.Machines)")
MiscTab:Label("Open via ProximityPrompt only — no teleport (needs executor fireproximityprompt).")

local MACHINE_NAMES = {"Fountain Of Skill", "Fusion Machine", "Totem Of Fortune", "Weapon Crafter"}
for _, mname in ipairs(MACHINE_NAMES) do
    local mn = mname
    MiscTab:Button("🔧", mn, "Fire " .. mn .. " ProximityPrompt from range (no TP)", C.accent, function()
        local machines = workspace:FindFirstChild("Machines")
        local machine  = machines and machines:FindFirstChild(mn)
        if not machine then SLbl.Text = "⚠ " .. mn .. " not found in workspace.Machines"; return end
        local prompt = machine:FindFirstChild("ProximityPrompt")
        if prompt then
            local ok = pcall(function() fireproximityprompt(prompt) end)
            SLbl.Text = ok and ("✓ Opened: " .. mn) or ("⚠ fireproximityprompt failed — " .. mn)
        else
            SLbl.Text = "⚠ No ProximityPrompt on " .. mn
        end
    end)
end

MiscTab:Section("Game UI")
MiscTab:Toggle("👁️ Show AutoRaid Button", "Keeps AutoRaidBtn visible — saved & applied on load", states.showAutoRaid, function(on)
    states.showAutoRaid = on; saveSettings()
    pcall(function()
        LP.PlayerGui:WaitForChild("MainGUI",3)
            :WaitForChild("OptionsList",3)
            :WaitForChild("AutoRaidBtn",3).Visible = on
    end)
    SLbl.Text = on and "✓ AutoRaidBtn shown" or "AutoRaidBtn hidden"
end)
MiscTab:Toggle("🙈 Show HideMobs Button", "Keeps HideMobsBtn visible — saved & applied on load", states.showHideMobs, function(on)
    states.showHideMobs = on; saveSettings()
    pcall(function()
        LP.PlayerGui:WaitForChild("MainGUI",3)
            :WaitForChild("OptionsList",3)
            :WaitForChild("HideMobsBtn",3).Visible = on
    end)
    SLbl.Text = on and "✓ HideMobsBtn shown" or "HideMobsBtn hidden"
end)

MiscTab:Section("Upgrades (debug)")
local UPGRADE_NAMES = {
    "Weapons Equipped","Damage Multiplier","Enemy Spawn Rate","Enemy Limit",
    "Mana Multiplier","Spin Speed","RNG Luck","Kill Multiplier",
    "Skill Point Multiplier","Boss Spawn Chance"
}
MiscTab:Button("📊", "Print Upgrade Levels", "Fetches all upgrade levels via GetUnlockedUpgrades", C.accent, function()
    local upgrades = invokeR("GetUnlockedUpgrades")
    if not upgrades then SLbl.Text = "⚠ GetUnlockedUpgrades returned nil"; return end
    for _, name in ipairs(UPGRADE_NAMES) do
        local level = upgReadUpgradeLevel(name)
        local val   = invokeR("GetUpgradeValue", name) or 0
        print(string.format("[MeleeRNG] %-30s  Lv%d  Value: %s", name, level, tostring(val)))
    end
    SLbl.Text = "Upgrade levels printed to output"
end)

MiscTab:Section("Mana → SP")
local manaToSpToggle = MiscTab:Toggle("⚡ Auto Mana → SP", "Convert 1 mana step at a time as fast as the server allows (~10/s). Saved with settings.", states.autoManaToSP, function(on)
    states.autoManaToSP = on == true
    saveSettings()
    SLbl.Text = on and "Auto Mana→SP ON" or "Auto Mana→SP OFF"
end)
task.defer(function()
    pcall(function()
        if manaToSpToggle and manaToSpToggle.Set then
            manaToSpToggle.Set(states.autoManaToSP)
        end
    end)
end)

MiscTab:Section("Community")
MiscTab:Button("💬", "Join Discord", "Opens discord.gg/vSTmMTyw in browser", C.purple, function()
    if setclipboard then
        setclipboard("https://discord.gg/vSTmMTyw")
        SLbl.Text = "Discord link copied to clipboard!"
    end
    if syn and syn.openUrl then syn.openUrl("https://discord.gg/vSTmMTyw")
    elseif (function() local ok, _ = pcall(function() return game:GetService("GuiService"):OpenBrowserWindow("https://discord.gg/vSTmMTyw") end) return ok end)() then
    end
    SLbl.Text = "discord.gg/vSTmMTyw — link copied!"
end)

MiscTab:Section("Script")
MiscTab:Toggle("🔁 Auto Rejoin", "Queues script on server teleport / disconnect hop only; throttled so executors cannot spam re-exec", states.autoReExec, function(on)
    states.autoReExec = on
    saveSettings()
    SLbl.Text = on and "Auto Rejoin ON" or "Auto Rejoin OFF"
    if on then
        pcall(function()
            local f = _G.MeleeRNG_ArmReexecQueue
            if f then f("toggle_ui") end
        end)
    end
end)
MiscTab:Toggle("💾 Auto Save", "Automatically saves all toggle/slider states to disk", states.autoSave, function(on)
    states.autoSave = on
    forceSave()  -- always save the autoSave state itself
    SLbl.Text = on and "✓ Auto Save ON — settings saved on every change" or "Auto Save OFF"
end)
MiscTab:Button("🛑", "Stop All Loops", "Disconnects all connections and cancels all threads", C.red, function()
    states.autoAscend  = false
    states.autoSacrifice = false
    states.autoTotem   = false
    states.autoManaToSP  = false
    pcall(function()
        if sacAutoToggle and sacAutoToggle.Set then sacAutoToggle.Set(false) end
    end)
    pcall(function()
        if totemAutoToggle and totemAutoToggle.Set then totemAutoToggle.Set(false) end
    end)
    pcall(function()
        if manaToSpToggle and manaToSpToggle.Set then manaToSpToggle.Set(false) end
    end)
    states.noclip    = false; states.godMode   = false
    states.fly       = false; states.antiAfk   = false
    states.fullBright= false; states.espMobs   = false
    cleanupAll()
    -- Restore lighting
    if _fbApplied then
        Lighting.Ambient = _origLight.Ambient; Lighting.OutdoorAmbient = _origLight.OutdoorAmbient
        Lighting.Brightness = _origLight.Brightness
        Lighting.FogEnd = _origLight.FogEnd; Lighting.FogStart = _origLight.FogStart
        _fbApplied = false
    end
    -- Remove ESP
    for _, bb in pairs(espBillboards) do pcall(function() bb:Destroy() end) end
    espBillboards = {}
    -- Remove fly
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    -- Restore hitboxes on stop
    hitboxExpanded = false
    _pulseActive   = false
    if _pulseConn then pcall(function() _pulseConn:Disconnect() end); _pulseConn = nil end
    pcall(restoreHitboxes)
    SLbl.Text = "All loops stopped. Re-execute to restart."
end)

MiscTab:Button("💾", "Save Settings", "Force-saves current toggle/slider state", C.green, function()
    saveSettings()
    SLbl.Text = "Settings saved to " .. SETTINGS_FILE
end)

-- ── Auto re-exec (queue_on_teleport + OnTeleport) ────────────────────────────
-- Some executors re-fire queued scripts immediately or stack queues — debounce + single load arm.
do
    local REEXEC_URL = SCRIPT_URL
    local QUEUE_MIN_INTERVAL = 12  -- seconds between queue_on_teleport calls (same session / gen)

    if _G.MeleeRNG_AutoRejoin and not states.autoReExec then
        states.autoReExec = true
        saveSettings()
    end
    local function syncMeleeRejoinFlag()
        _G.MeleeRNG_AutoRejoin = states.autoReExec
    end
    syncMeleeRejoinFlag()

    local function armQueue(reason)
        if not queue_on_teleport or not states.autoReExec then return end
        local now = os.clock()
        local last = _G.MeleeRNG_QueueLastClock
        if type(last) == "number" and (now - last) < QUEUE_MIN_INTERVAL then
            return
        end
        _G.MeleeRNG_QueueLastClock = now
        pcall(function()
            queue_on_teleport('loadstring(game:HttpGet("' .. REEXEC_URL .. '",true))()')
        end)
    end

    pcall(function()
        LP.OnTeleport:Connect(function(teleportState)
            if teleportState ~= Enum.TeleportState.RequestedByServer then return end
            if GEN ~= _G.MeleeRNG_Gen then return end
            syncMeleeRejoinFlag()
            armQueue("teleport")
        end)
    end)

    -- Arm once if already ON from settings (do not double-arm via the poller below)
    if states.autoReExec then
        armQueue("load")
    end

    task.spawn(function()
        -- Match saved state so we don't fire armQueue again 2s later on every load
        local wasOn = states.autoReExec == true
        while true do
            if GEN ~= _G.MeleeRNG_Gen then break end
            task.wait(2)
            syncMeleeRejoinFlag()
            if states.autoReExec and not wasOn then
                armQueue("toggle_on")
            end
            wasOn = states.autoReExec == true
        end
    end)

    _G.MeleeRNG_ArmReexecQueue = armQueue
end

return SLbl
end)()

-- ============================================================
--  DONE
-- ============================================================
do local h = getHuman(); if h then h.WalkSpeed = walkSpeedVal end end
-- Apply saved UI button visibility on load
task.defer(function()
    if states.showAutoRaid then
        pcall(function()
            LP.PlayerGui:WaitForChild("MainGUI",5):WaitForChild("OptionsList",5):WaitForChild("AutoRaidBtn",5).Visible = true
        end)
    end
    if states.showHideMobs then
        pcall(function()
            LP.PlayerGui:WaitForChild("MainGUI",5):WaitForChild("OptionsList",5):WaitForChild("HideMobsBtn",5).Visible = true
        end)
    end
end)
print(string.format("[MeleeRNG] Loaded v1.0 | Gen=%d | DMGx=%d%%", GEN, _dmgMulti))
SLbl.Text = string.format("MeleeRNG v1.0 ready | Gen=%d | Kills: %s", GEN, tostring(getKills()))
