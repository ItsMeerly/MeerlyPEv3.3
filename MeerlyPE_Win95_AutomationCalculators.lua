--[[
    MeerlyPE_Win95_AutomationCalculators.lua
    - Loads MeerlyWin95UILibrary.lua without modifying library file.
    - Injects PE Automation + Calculators pages before Roblox Settings.
    - Keeps Automation/Calculators calculation/automation logic aligned with PE.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

-- ============================================================
-- Editable config (requested)
-- ============================================================
local CONFIG = {
    LibraryPath = "MeerlyWin95UILibrary.lua",
    AccessKey = "1234",
    AccessLink = "https://work.ink/2kaV/meerlype-key123",
    Title = "MeerlyPE Win95",
    ToggleKey = Enum.KeyCode.Semicolon,
}

local function escapeLuaString(value)
    return (tostring(value)
        :gsub("\\", "\\\\")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\"", "\\\""))
end

local function loadWin95Library()
    assert(type(readfile) == "function", "readfile is required to load local Win95 library")

    local tried = {}
    local function tryRead(path)
        if not path or path == "" then
            return nil
        end

        tried[#tried + 1] = path
        local ok, result = pcall(readfile, path)
        if ok and type(result) == "string" and result ~= "" then
            return result
        end

        if type(result) == "string" and string.find(result, "Expected File But Got Directory", 1, true) then
            local initPath = string.gsub(path, "/+$", "") .. "/init.lua"
            tried[#tried + 1] = initPath
            local okInit, initResult = pcall(readfile, initPath)
            if okInit and type(initResult) == "string" and initResult ~= "" then
                return initResult
            end
        end

        return nil
    end

    local source =
        tryRead(CONFIG.LibraryPath)
        or tryRead("./" .. tostring(CONFIG.LibraryPath or ""))
        or tryRead("MeerlyWin95UILibrary.lua")
        or tryRead("./MeerlyWin95UILibrary.lua")

    assert(source, "Failed to read Win95 library file. Tried: " .. table.concat(tried, ", "))

    source = source:gsub(
        'local HARDCODED_KEY = ".-"',
        'local HARDCODED_KEY = "' .. escapeLuaString(CONFIG.AccessKey) .. '"'
    )

    source = source:gsub(
        'local KEY_LINK = ".-"',
        'local KEY_LINK = "' .. escapeLuaString(CONFIG.AccessLink) .. '"'
    )

    local chunk = assert(loadstring(source), "Failed to compile Win95 library")
    return chunk()
end

local MeerlyWin95 = loadWin95Library()

-- ============================================================
-- PE logic helpers (same formulas/behavior)
-- ============================================================
local AutoSkillMode = { Off = 0, Normal = 1, Stagger = 2 }
local SKILL_KEYS = { Q = Enum.KeyCode.Q, E = Enum.KeyCode.E, R = Enum.KeyCode.R }
local SKILL_CHAIN_PRESETS = { Off = 0.5, Safe = 4.0, Relaxed = 6.0 }
local BASE_COOLDOWN_MS = 12250
local COOLDOWN_MIN_MS = 12550
local COOLDOWN_MAX_MS = 12750

local function randf(a, b)
    return a + math.random() * (b - a)
end

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(0.04)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function canUseSkill(state, skill)
    local info = state.skillState[skill]
    if not info then return true end
    if not info.lastUse then return true end

    local elapsedMs = (os.clock() - info.lastUse) * 1000
    local requiredMs = info.nextCooldownMs or BASE_COOLDOWN_MS
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

-- ============================================================
-- Win95 page helpers
-- ============================================================
local function nextStackY(holder)
    holder._y = holder._y or 8
    return holder._y
end

local function advanceStackY(holder, amount)
    holder._y = (holder._y or 8) + amount
end

local function addHeader(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = page
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 18
    lbl.Text = text
    lbl.Size = UDim2.new(1, -24, 0, 24)
    lbl.Position = UDim2.fromOffset(8, nextStackY(page))
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    advanceStackY(page, 30)
    return lbl
end

local function addAccordion(page, title, defaultOpen)
    local header = Instance.new("TextButton")
    header.Parent = page
    header.AutoButtonColor = false
    header.Font = Enum.Font.Code
    header.TextSize = 13
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Size = UDim2.new(1, -24, 0, 24)
    header.Position = UDim2.fromOffset(8, nextStackY(page))
    header.BorderSizePixel = 0
    header.BackgroundColor3 = Color3.fromRGB(60, 60, 70)

    local body = Instance.new("Frame")
    body.Parent = page
    body.BackgroundColor3 = Color3.fromRGB(42, 42, 50)
    body.BorderSizePixel = 0
    body.ClipsDescendants = true
    body.Position = UDim2.fromOffset(8, nextStackY(page) + 26)
    body.Size = UDim2.new(1, -24, 0, 0)

    local layout = Instance.new("UIListLayout")
    layout.Parent = body
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local padding = Instance.new("UIPadding")
    padding.Parent = body
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 6)
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)

    local open = defaultOpen == true
    local function refresh()
        header.Text = string.format("%s %s", open and "[-]" or "[+]", title)
        local h = open and (layout.AbsoluteContentSize.Y + 12) or 0
        body.Size = UDim2.new(1, -24, 0, h)
    end

    header.MouseButton1Click:Connect(function()
        open = not open
        refresh()
        page._reflow()
    end)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        refresh()
        page._reflow()
    end)

    page._registerBlock(function(y)
        header.Position = UDim2.fromOffset(8, y)
        body.Position = UDim2.fromOffset(8, y + 26)
        return 26 + body.Size.Y.Offset + 8
    end)

    refresh()
    return body
end

local function addButton(parent, text, callback)
    local b = Instance.new("TextButton")
    b.Parent = parent
    b.Size = UDim2.new(1, 0, 0, 24)
    b.BorderSizePixel = 0
    b.BackgroundColor3 = Color3.fromRGB(70, 70, 84)
    b.Font = Enum.Font.Code
    b.TextSize = 12
    b.Text = text
    b.TextColor3 = Color3.fromRGB(230, 230, 230)
    b.MouseButton1Click:Connect(callback)
    return b
end

local function addSmallRow(parent)
    local row = Instance.new("Frame")
    row.Parent = parent
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1

    local layout = Instance.new("UIListLayout")
    layout.Parent = row
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 4)

    return row
end

local function addSmallButton(parent, text)
    local b = Instance.new("TextButton")
    b.Parent = parent
    b.Size = UDim2.new(0.333, -3, 1, 0)
    b.BorderSizePixel = 0
    b.BackgroundColor3 = Color3.fromRGB(68, 68, 80)
    b.Font = Enum.Font.Code
    b.TextSize = 12
    b.Text = text
    b.TextColor3 = Color3.fromRGB(230, 230, 230)
    return b
end

local function addTextbox(parent, labelText, defaultText)
    local wrap = Instance.new("Frame")
    wrap.Parent = parent
    wrap.Size = UDim2.new(1, 0, 0, 24)
    wrap.BackgroundTransparency = 1

    local label = Instance.new("TextLabel")
    label.Parent = wrap
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Size = UDim2.new(0.56, 0, 1, 0)
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(210, 210, 210)

    local tb = Instance.new("TextBox")
    tb.Parent = wrap
    tb.Size = UDim2.new(0.44, -4, 1, 0)
    tb.Position = UDim2.new(0.56, 4, 0, 0)
    tb.BorderSizePixel = 0
    tb.BackgroundColor3 = Color3.fromRGB(56, 56, 66)
    tb.Text = defaultText or ""
    tb.ClearTextOnFocus = false
    tb.Font = Enum.Font.Code
    tb.TextSize = 12
    tb.TextColor3 = Color3.fromRGB(240, 240, 240)
    return tb
end

local function addLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = parent
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Size = UDim2.new(1, 0, 0, 32)
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    return lbl
end

local function addSection(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = parent
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(160, 210, 255)
    return lbl
end

local function addResultLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = parent
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    return lbl
end

local function wireStackPage(page)
    page._blocks = {}
    page._registerBlock = function(block)
        table.insert(page._blocks, block)
    end

    page._reflow = function()
        local y = nextStackY(page)
        for _, block in ipairs(page._blocks) do
            y += block(y)
        end
    end
end

-- ============================================================
-- Injected PE Automation page
-- ============================================================
function MeerlyWin95:_buildPEAutomationPage()
    local page = self:addPage("Automation", "AU")
    wireStackPage(page)
    addHeader(page, "Automation")

    self.state.peAutomation = self.state.peAutomation or {
        autoSkillMode = AutoSkillMode.Off,
        skillEnabled = { Q = true, E = true, R = false },
        skillPriority = { "Q", "E", "R" },
        selectedChainMode = "Off",
        adaptiveCooldownEnabled = false,
        cooldownVariance = 1,
        autoClickerEnabled = false,
        autoClickRate = 10,
        skillState = {
            Q = { lastUse = nil, nextCooldownMs = BASE_COOLDOWN_MS },
            E = { lastUse = nil, nextCooldownMs = BASE_COOLDOWN_MS },
            R = { lastUse = nil, nextCooldownMs = BASE_COOLDOWN_MS },
        },
    }

    local st = self.state.peAutomation
    local staggerOrder = { "Off", "Relaxed", "Safe" }
    local staggerLabels = { Off = "10s", Relaxed = "6s", Safe = "4s" }

    local autoBody = addAccordion(page, "Automation (Mode + Skills)", true)
    local clickBody = addAccordion(page, "Auto Clicker", true)
    local cdBody = addAccordion(page, "Cooldown Behaviour", false)

    local modeNames = {
        [AutoSkillMode.Off] = "Auto Skills: OFF",
        [AutoSkillMode.Normal] = "Auto Skills: ON",
        [AutoSkillMode.Stagger] = "Auto Skills: STAGGER",
    }

    local modeBtn
    local function refreshModeBtn()
        if modeBtn then
            modeBtn.Text = modeNames[st.autoSkillMode]
        end
    end

    modeBtn = addButton(autoBody, modeNames[st.autoSkillMode], function()
        st.autoSkillMode = (st.autoSkillMode + 1) % 3
        refreshModeBtn()
        self:log("EVENT", "Auto Skill mode set to " .. modeBtn.Text)
    end)

    local rowSkills = addSmallRow(autoBody)
    for _, k in ipairs({ "Q", "E", "R" }) do
        local b = addSmallButton(rowSkills, k .. ": OFF")
        local function refresh()
            local enabled = st.skillEnabled[k]
            b.Text = k .. ": " .. (enabled and "ON" or "OFF")
            b.BackgroundColor3 = enabled and Color3.fromRGB(72, 98, 72) or Color3.fromRGB(68, 68, 80)
        end
        refresh()
        b.MouseButton1Click:Connect(function()
            st.skillEnabled[k] = not st.skillEnabled[k]
            refresh()
            self:log("EVENT", k .. " toggle set to " .. (st.skillEnabled[k] and "ON" or "OFF"))
        end)
    end

    local presetBtn
    local function refreshPresetBtn()
        if presetBtn then
            presetBtn.Text = "Stagger Preset: " .. (staggerLabels[st.selectedChainMode] or st.selectedChainMode)
        end
    end

    presetBtn = addButton(autoBody, "Stagger Preset: " .. (staggerLabels[st.selectedChainMode] or st.selectedChainMode), function()
        local idx = table.find(staggerOrder, st.selectedChainMode) or 1
        idx = (idx % #staggerOrder) + 1
        st.selectedChainMode = staggerOrder[idx]
        refreshPresetBtn()
        self:log("EVENT", "Stagger preset set to " .. st.selectedChainMode)
    end)

    addLabel(autoBody, "Tip: F6 toggles Auto Clicker. Auto Skills supports OFF / ON / STAGGER.")

    local acBtn
    local function refreshAC()
        if acBtn then
            acBtn.Text = "Auto Clicker: " .. (st.autoClickerEnabled and "ON" or "OFF")
            acBtn.BackgroundColor3 = st.autoClickerEnabled and Color3.fromRGB(72, 98, 72) or Color3.fromRGB(68, 68, 80)
        end
    end
    acBtn = addButton(clickBody, "Auto Clicker: OFF", function()
        st.autoClickerEnabled = not st.autoClickerEnabled
        refreshAC()
        self:log("EVENT", "Auto Clicker set to " .. (st.autoClickerEnabled and "ON" or "OFF"))
    end)
    refreshAC()

    local clickRateBox = addTextbox(clickBody, "Clicks/sec (1-30)", tostring(st.autoClickRate))
    clickRateBox.FocusLost:Connect(function()
        local v = tonumber(clickRateBox.Text)
        if v and v > 0 then
            st.autoClickRate = math.clamp(v, 1, 30)
        end
        clickRateBox.Text = tostring(st.autoClickRate)
        self:log("EVENT", "Click rate set to " .. st.autoClickRate .. " clicks/sec")
    end)

    addLabel(clickBody, "Auto Clicker uses VirtualInputManager and respects the cps limiter.")

    local adBtn
    local function refreshAd()
        if adBtn then
            adBtn.Text = "Adaptive Cooldowns: " .. (st.adaptiveCooldownEnabled and "ON" or "OFF")
        end
    end

    adBtn = addButton(cdBody, "Adaptive Cooldowns: OFF", function()
        st.adaptiveCooldownEnabled = not st.adaptiveCooldownEnabled
        refreshAd()
        self:log("EVENT", "Adaptive Cooldowns set to " .. (st.adaptiveCooldownEnabled and "ON" or "OFF"))
    end)
    refreshAd()

    local varBox = addTextbox(cdBody, "Cooldown variance (number)", tostring(st.cooldownVariance))
    varBox.FocusLost:Connect(function()
        st.cooldownVariance = tonumber(varBox.Text) or st.cooldownVariance
        varBox.Text = tostring(st.cooldownVariance)
    end)

    page:_reflow()

    task.spawn(function()
        local staggerIndex = 1
        local lastStaggerFire = 0

        while self.state.alive do
            task.wait(0.05)

            if not self.state.unlocked then
                continue
            end

            if st.autoSkillMode == AutoSkillMode.Off then
                continue
            end

            local enabled = {}
            for _, s in ipairs(st.skillPriority) do
                if st.skillEnabled[s] then
                    table.insert(enabled, s)
                end
            end
            if #enabled == 0 then
                continue
            end

            if st.autoSkillMode == AutoSkillMode.Normal then
                local fired = false
                for _, skill in ipairs(enabled) do
                    if canUseSkill(st, skill) then
                        pressKey(SKILL_KEYS[skill])
                        self.state.statisticsData.totalSkillActivations += 1

                        local now = os.clock()
                        st.skillState[skill].lastUse = now
                        st.skillState[skill].nextCooldownMs = st.adaptiveCooldownEnabled
                            and math.floor(randf(COOLDOWN_MIN_MS, COOLDOWN_MAX_MS))
                            or BASE_COOLDOWN_MS

                        self:log("EVENT", "Executed " .. skill)
                        fired = true
                    end
                end
                if fired then
                    task.wait(0.1)
                end

            elseif st.autoSkillMode == AutoSkillMode.Stagger then
                local stagger = SKILL_CHAIN_PRESETS[st.selectedChainMode] or 4
                local now = os.clock()
                if (now - lastStaggerFire) < stagger then
                    continue
                end

                local skill = enabled[staggerIndex]
                if skill and canUseSkill(st, skill) then
                    pressKey(SKILL_KEYS[skill])
                    self.state.statisticsData.totalSkillActivations += 1

                    st.skillState[skill].lastUse = now
                    st.skillState[skill].nextCooldownMs = st.adaptiveCooldownEnabled
                        and math.floor(randf(COOLDOWN_MIN_MS, COOLDOWN_MAX_MS))
                        or BASE_COOLDOWN_MS

                    self:log("EVENT", "Executed " .. skill .. " (staggered)")

                    lastStaggerFire = now
                    staggerIndex = (staggerIndex % #enabled) + 1
                end
            end
        end
    end)

    task.spawn(function()
        while self.state.alive do
            if not self.state.unlocked or not st.autoClickerEnabled then
                task.wait(0.2)
            else
                local pos = UserInputService:GetMouseLocation()
                local x, y = math.floor(pos.X), math.floor(pos.Y)
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
                    task.wait(0.01)
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
                end)
                task.wait(1 / math.clamp(tonumber(st.autoClickRate) or 10, 1, 30))
            end
        end
    end)
end

-- ============================================================
-- Injected PE Calculators page (accordion)
-- ============================================================
function MeerlyWin95:_buildPECalculatorsPage()
    local page = self:addPage("Calculators", "CL")
    wireStackPage(page)
    addHeader(page, "Calculators")

    local xpBody = addAccordion(page, "XP Calculator (v3)", true)

    local inputs = {}
    local function addXPInput(labelText, defaultText)
        local tb = addTextbox(xpBody, labelText, defaultText)
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

    addSection(xpBody, "Skill Modifiers")
    local calcSkills = { Q = false, E = false, R = false }
    local skillMultiplier = { Q = 200, E = 200, R = 200 }

    local rowSkill = addSmallRow(xpBody)
    local rowMult = addSmallRow(xpBody)

    local r1 = addResultLabel(xpBody, "XP/hr: --")
    local r2 = addResultLabel(xpBody, "Time to 100%: --")

    local function splitCsvNums(sv)
        local out = {}
        for token in string.gmatch((sv or ""), "([^,]+)") do
            local cleaned = token:gsub("%%", ""):gsub("%s+", "")
            local n = tonumber(cleaned)
            if n then out[#out + 1] = n end
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

        self:log("EVENT", "Recalculated XP/hr")
    end

    for _, k in ipairs({ "Q", "E", "R" }) do
        local sbtn = addSmallButton(rowSkill, k .. ": OFF")
        local mbtn = addSmallButton(rowMult, skillMultiplier[k] .. "%")

        local function refreshSkill()
            sbtn.Text = k .. ": " .. (calcSkills[k] and "ON" or "OFF")
            sbtn.BackgroundColor3 = calcSkills[k] and Color3.fromRGB(72, 98, 72) or Color3.fromRGB(68, 68, 80)
        end

        local function refreshMult()
            mbtn.Text = skillMultiplier[k] .. "%"
            mbtn.BackgroundColor3 = (skillMultiplier[k] == 250) and Color3.fromRGB(72, 98, 72) or Color3.fromRGB(68, 68, 80)
        end

        refreshSkill()
        refreshMult()

        sbtn.MouseButton1Click:Connect(function()
            calcSkills[k] = not calcSkills[k]
            refreshSkill()
            recalcXP()
        end)

        mbtn.MouseButton1Click:Connect(function()
            skillMultiplier[k] = (skillMultiplier[k] == 200) and 250 or 200
            refreshMult()
            recalcXP()
        end)
    end

    for _, tb in pairs(inputs) do
        tb.FocusLost:Connect(recalcXP)
    end

    addButton(xpBody, "Recalculate", recalcXP)
    task.defer(recalcXP)

    local bossBody = addAccordion(page, "Boss Calculator (v2.4)", false)

    local bossInputs = {}
    local function addBossInput(labelText, defaultText)
        local tb = addTextbox(bossBody, labelText, defaultText)
        bossInputs[labelText] = tb
        return tb
    end

    addBossInput("Self HP", "1000")
    addBossInput("Self DPS", "50")
    addBossInput("Enemy HP", "2000")
    addBossInput("Enemy DMG", "100")

    addSection(bossBody, "Skill Modifiers")
    local bossCalcSkills = { Q = false, E = false, R = false }
    local bossSkillMultiplier = { Q = 200, E = 200, R = 200 }

    local rowSkillB = addSmallRow(bossBody)
    local rowMultB = addSmallRow(bossBody)

    addSection(bossBody, "Boss Mode")
    local bossModeEnabled = false
    local bossModeBtn
    bossModeBtn = addButton(bossBody, "Boss Mode: OFF", function()
        bossModeEnabled = not bossModeEnabled
        bossModeBtn.Text = "Boss Mode: " .. (bossModeEnabled and "ON" or "OFF")
    end)

    addSection(bossBody, "Result")
    local br = addLabel(bossBody, "Result: --")

    local function recalcBoss()
        local selfHP = tonumber(bossInputs["Self HP"].Text)
        local baseDPS = tonumber(bossInputs["Self DPS"].Text)
        local enemyHP = tonumber(bossInputs["Enemy HP"].Text)
        local enemyDMG = tonumber(bossInputs["Enemy DMG"].Text)

        if not selfHP or not baseDPS or not enemyHP or not enemyDMG then
            br.Text = "Result: Invalid inputs"
            return
        end

        local selfDPS = effectiveDPS(baseDPS, bossCalcSkills, bossSkillMultiplier)
        local enemyInterval = bossModeEnabled and 3.5 or 2

        local timeToKill = enemyHP / selfDPS
        local timeToDie = selfHP / (enemyDMG / enemyInterval)

        if timeToKill < timeToDie then
            br.Text = string.format("You win! Kill in %.2fs before dying.", timeToKill)
        elseif timeToKill > timeToDie then
            br.Text = string.format("You die! Enemy kills you in %.2fs.", timeToDie)
        else
            br.Text = string.format("Simultaneous! Both die at %.2fs.", timeToKill)
        end

        self:log("EVENT", "Recalculated boss result")
    end

    bossModeBtn.MouseButton1Click:Connect(recalcBoss)

    for _, k in ipairs({ "Q", "E", "R" }) do
        local sbtn = addSmallButton(rowSkillB, k .. ": OFF")
        local mbtn = addSmallButton(rowMultB, bossSkillMultiplier[k] .. "%")

        local function refreshSkill()
            sbtn.Text = k .. ": " .. (bossCalcSkills[k] and "ON" or "OFF")
            sbtn.BackgroundColor3 = bossCalcSkills[k] and Color3.fromRGB(72, 98, 72) or Color3.fromRGB(68, 68, 80)
        end

        local function refreshMult()
            mbtn.Text = bossSkillMultiplier[k] .. "%"
            mbtn.BackgroundColor3 = (bossSkillMultiplier[k] == 250) and Color3.fromRGB(72, 98, 72) or Color3.fromRGB(68, 68, 80)
        end

        refreshSkill()
        refreshMult()

        sbtn.MouseButton1Click:Connect(function()
            bossCalcSkills[k] = not bossCalcSkills[k]
            refreshSkill()
            recalcBoss()
        end)

        mbtn.MouseButton1Click:Connect(function()
            bossSkillMultiplier[k] = (bossSkillMultiplier[k] == 200) and 250 or 200
            refreshMult()
            recalcBoss()
        end)
    end

    for _, tb in pairs(bossInputs) do
        tb.FocusLost:Connect(recalcBoss)
    end

    addButton(bossBody, "Recalculate", recalcBoss)
    task.defer(recalcBoss)

    page:_reflow()
end

-- Build order injection: new pages BEFORE Settings
local originalBuildDefaultPages = MeerlyWin95._buildDefaultPages
function MeerlyWin95:_buildDefaultPages()
    self:_buildPEAutomationPage()
    self:_buildPECalculatorsPage()
    originalBuildDefaultPages(self)
end

local app = MeerlyWin95.new({
    title = CONFIG.Title,
    toggleKey = CONFIG.ToggleKey,
})

_G.MeerlyWin95_PE = app
return app
