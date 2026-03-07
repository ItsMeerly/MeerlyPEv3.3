--[[
    Meerly PE - Performance / Stability Only UI
    Extracted from MeerlyPE_Feature_Testing.lua
    Focuses strictly on:
      - Anti-AFK + Watchdog
      - FPS / graphics / streaming controls
      - Background survival controls
      - Memory stats + memory guard
]]

-- Roblox services used across performance, UI, and player-entity controls.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Stats = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

_G.__MeerlyPerfState = _G.__MeerlyPerfState or {
    antiAfkEnabled = false,
    watchdogEnabled = false,
    lastHeartbeat = os.clock(),
}

local running = true
local destroyRequested = false
local uiVisible = true

local fpsCapEnabled = false
local targetFPS = 60
local lowGraphicsEnabled = false
local streamingOptimized = false
local aggressiveFxCullEnabled = false
local hideTrackedWeaponParts = false
local weaponDamageOverrideEnabled = false
local weaponDamageOverride = 25
local hideOtherPlayersWeapons = false
local otherPlayersHidePassSeconds = 10
local walkSpeedOverrideEnabled = false
local walkSpeedValue = 16
local originalWalkSpeed = nil

-- Enemy death effects can spam a BasePart named "Disappear" into Workspace.
-- We keep this on by default and use both event-based + fast-pass scanning to catch every spawn.
local autoHideDisappearEnabled = true
local disappearFastPassSeconds = 0.2

local fxCullConnection = nil
local weaponChildAddedConnection = nil
local weaponChildRemovedConnection = nil
local characterAddedConnection = nil
local disappearAddedConnection = nil

local trackedCharacter = nil
local trackedWeapons = {}
local trackedWeaponPartState = {}
local trackedWeaponDamageState = {}
local otherPlayerWeaponPartState = {}
local disappearPartState = {}

local backgroundMode = false
local windowFocused = true
local disable3D = false
local muteSounds = false

local heartbeatLagThreshold = 1.5
local watchdogThreshold = 4

local memoryStatsEnabled = false
local memoryGuardMode = "Off" -- Off | AutoRejoin | AutoQuit
local memoryGuardCapGB = 10
local memoryGuardCooldown = 30
local lastMemoryGuardAction = 0

local log

-- Centralized logger reference. It is assigned after UI creation so helper functions can call it safely.
local uiTheme = {
    bg = Color3.fromRGB(18, 18, 24),
    panel = Color3.fromRGB(25, 25, 33),
    accent = Color3.fromRGB(120, 180, 255),
    text = Color3.fromRGB(235, 235, 240),
    subtle = Color3.fromRGB(160, 160, 170),
    stroke = Color3.fromRGB(45, 45, 55),
}

-- ---- Memory helpers ----
-- safeTotalMemMb/luaMemMb/getCombinedMemoryGb are intentionally wrapped with pcall
-- so unsupported executor APIs do not break the rest of the UI.
local function safeTotalMemMb()
    local total
    pcall(function()
        total = Stats:GetTotalMemoryUsageMb()
    end)
    return total
end

local function luaMemMb()
    local ok, mb = pcall(function()
        return gcinfo() / 1024
    end)
    return ok and mb or nil
end

local function getCombinedMemoryGb()
    local luaMb = luaMemMb() or 0
    local totalMb = safeTotalMemMb()

    local combinedMb
    local engineOnlyMb

    if totalMb then
        if totalMb >= luaMb then
            combinedMb = totalMb
            engineOnlyMb = math.max(0, totalMb - luaMb)
        else
            combinedMb = luaMb + totalMb
            engineOnlyMb = totalMb
        end
    else
        combinedMb = luaMb
        engineOnlyMb = nil
    end

    return combinedMb / 1024, luaMb / 1024, (totalMb and totalMb / 1024 or nil), (engineOnlyMb and engineOnlyMb / 1024 or nil)
end

-- ---- Rendering helpers ----
-- Rendering helper block controls expensive post-processing and effect visibility.
local function stripBlurEffects()
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("BlurEffect") then
            obj.Enabled = false
            obj.Size = 0
        end
    end
end

local function applyVisuals(disable)
    Lighting.GlobalShadows = not disable
    Lighting.FogEnd = disable and 1e6 or 100000
    pcall(function() settings().Rendering.QualityLevel = disable and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic end)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("BlurEffect") then
            obj.Enabled = false
            obj.Size = 0
        elseif obj:IsA("PostEffect") then
            obj.Enabled = not disable
        end
    end
end

-- Disables known expensive FX objects that commonly spike frame time in effect-heavy fights.
local function disableFxObject(obj)
    if obj:IsA("ParticleEmitter") then
        obj.Enabled = false
        obj.Rate = 0
    elseif obj:IsA("Trail") or obj:IsA("Beam") then
        obj.Enabled = false
    elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
        obj.Enabled = false
    elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
        obj.Enabled = false
    end
end

local function applyAggressiveFxCull(enabled)
    if enabled then
        if fxCullConnection then
            fxCullConnection:Disconnect()
        end

        local disabledCount = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
                or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles")
                or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                disableFxObject(obj)
                disabledCount += 1
            end
        end

        fxCullConnection = Workspace.DescendantAdded:Connect(function(obj)
            disableFxObject(obj)
        end)

        log(string.format("Aggressive FX cull enabled (%d effects disabled)", disabledCount))
    else
        if fxCullConnection then
            fxCullConnection:Disconnect()
            fxCullConnection = nil
        end
        log("Aggressive FX cull disabled (existing disabled effects stay off)")
    end
end

local characterNonWeaponNames = {
    ["Animate"] = true,
    ["Humanoid"] = true,
    ["HumanoidRootPart"] = true,
    ["Head"] = true,
    ["Torso"] = true,
    ["UpperTorso"] = true,
    ["LowerTorso"] = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true,
    ["LeftHand"] = true,
    ["RightHand"] = true,
    ["LeftFoot"] = true,
    ["RightFoot"] = true,
    ["LeftLowerArm"] = true,
    ["RightLowerArm"] = true,
    ["LeftUpperArm"] = true,
    ["RightUpperArm"] = true,
    ["LeftLowerLeg"] = true,
    ["RightLowerLeg"] = true,
    ["LeftUpperLeg"] = true,
    ["RightUpperLeg"] = true,
    ["Body Colors"] = true,
    ["BodyColors"] = true,
    ["Shirt"] = true,
    ["Pants"] = true,
    ["Shirt Graphic"] = true,
    ["Health"] = true,
}

local function isLikelyWeaponContainerForCharacter(character, obj)
    if not character or obj.Parent ~= character then
        return false
    end
    if characterNonWeaponNames[obj.Name] then
        return false
    end
    if obj:IsA("Accessory") or obj:IsA("Clothing") or obj:IsA("BodyColors") then
        return false
    end
    if obj:IsA("Tool") then
        return true
    end
    if typeof(obj:GetAttribute("Damage")) == "number" then
        return true
    end

    local hasPart = obj:IsA("BasePart")
    if not hasPart then
        hasPart = obj:FindFirstChildWhichIsA("BasePart", true) ~= nil
    end

    return hasPart
end

local function setPartHiddenLocal(part, hide, stateTable)
    local state = stateTable[part]
    if not state then
        state = { localTransparencyModifier = part.LocalTransparencyModifier }
        stateTable[part] = state
    end

    if hide then
        part.LocalTransparencyModifier = 1
    else
        part.LocalTransparencyModifier = state.localTransparencyModifier or 0
    end
end

local function applyOtherPlayersWeaponHiding()
    local hiddenCount = 0
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.Character then
            for _, child in ipairs(other.Character:GetChildren()) do
                if isLikelyWeaponContainerForCharacter(other.Character, child) then
                    if child:IsA("BasePart") then
                        setPartHiddenLocal(child, hideOtherPlayersWeapons, otherPlayerWeaponPartState)
                        hiddenCount += 1
                    end
                    for _, descendant in ipairs(child:GetDescendants()) do
                        if descendant:IsA("BasePart") then
                            setPartHiddenLocal(descendant, hideOtherPlayersWeapons, otherPlayerWeaponPartState)
                            hiddenCount += 1
                        end
                    end
                end
            end
        end
    end

    if not hideOtherPlayersWeapons then
        for part in pairs(otherPlayerWeaponPartState) do
            if part and part.Parent then
                setPartHiddenLocal(part, false, otherPlayerWeaponPartState)
            end
        end
        otherPlayerWeaponPartState = {}
    end

    return hiddenCount
end

-- Fast utility used by the Disappear-part system. We hide locally so this is client-safe and low risk.
local function setDisappearPartHidden(part, hide)
    local state = disappearPartState[part]
    if not state then
        state = { localTransparencyModifier = part.LocalTransparencyModifier, canCollide = part.CanCollide }
        disappearPartState[part] = state
    end

    if hide then
        part.LocalTransparencyModifier = 1
        part.CanCollide = false
    else
        part.LocalTransparencyModifier = state.localTransparencyModifier or 0
        part.CanCollide = state.canCollide
    end
end

-- This function is intentionally tiny because it may run at high frequency.
-- It handles both direct BasePart spawns named "Disappear" and containers that include one.
local function processDisappearCandidate(instance)
    if not autoHideDisappearEnabled then
        return
    end

    if instance:IsA("BasePart") and instance.Name == "Disappear" then
        setDisappearPartHidden(instance, true)
        return
    end

    if not instance:IsA("BasePart") then
        local d = instance:FindFirstChild("Disappear", true)
        if d and d:IsA("BasePart") then
            setDisappearPartHidden(d, true)
        end
    end
end

-- Periodic fast scan catches edge cases where parts are renamed after spawn,
-- moved in bulk, or created before listeners are attached.
local function fastScanDisappearParts()
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "Disappear" then
            setDisappearPartHidden(d, autoHideDisappearEnabled)
        end
    end

    if not autoHideDisappearEnabled then
        for part in pairs(disappearPartState) do
            if part and part.Parent then
                setDisappearPartHidden(part, false)
            end
        end
        disappearPartState = {}
    end
end

local function isLikelyWeaponContainer(obj)
    return isLikelyWeaponContainerForCharacter(trackedCharacter, obj)
end

-- Applies local visual/collision state to weapon parts for the local character only.
local function applyWeaponPartState(part)
    local state = trackedWeaponPartState[part]
    if not state then
        state = {
            transparency = part.Transparency,
            canCollide = part.CanCollide,
        }
        trackedWeaponPartState[part] = state
    end

    if hideTrackedWeaponParts then
        part.LocalTransparencyModifier = 1
        part.CanCollide = false
    else
        part.LocalTransparencyModifier = 0
        part.Transparency = state.transparency
        part.CanCollide = state.canCollide
    end
end

-- Applies/restores Damage attribute overrides while preserving original values for clean rollback.
local function applyDamageState(instance)
    if weaponDamageOverrideEnabled then
        local state = trackedWeaponDamageState[instance]
        if state == nil then
            state = instance:GetAttribute("Damage")
            trackedWeaponDamageState[instance] = state
        end
        instance:SetAttribute("Damage", weaponDamageOverride)
    else
        if trackedWeaponDamageState[instance] ~= nil then
            instance:SetAttribute("Damage", trackedWeaponDamageState[instance])
        end
    end
end

local function applyWeaponState(container)
    if container:IsA("BasePart") then
        applyWeaponPartState(container)
    end

    if container:GetAttribute("Damage") ~= nil then
        applyDamageState(container)
    end

    for _, descendant in ipairs(container:GetDescendants()) do
        if descendant:IsA("BasePart") then
            applyWeaponPartState(descendant)
        end
        if descendant:GetAttribute("Damage") ~= nil then
            applyDamageState(descendant)
        end
    end
end

local function trackWeapon(container)
    if trackedWeapons[container] then
        applyWeaponState(container)
        return
    end

    trackedWeapons[container] = true
    applyWeaponState(container)
    log("Tracked weapon: " .. container.Name)
end

local function untrackWeapon(container)
    if not trackedWeapons[container] then
        return
    end

    trackedWeapons[container] = nil

    if container:IsA("BasePart") then
        trackedWeaponPartState[container] = nil
        trackedWeaponDamageState[container] = nil
    end

    for _, descendant in ipairs(container:GetDescendants()) do
        trackedWeaponPartState[descendant] = nil
        trackedWeaponDamageState[descendant] = nil
    end
end

local function rescanCharacterWeapons(silent)
    if not trackedCharacter then
        return
    end

    local trackedCount = 0
    for _, child in ipairs(trackedCharacter:GetChildren()) do
        if isLikelyWeaponContainer(child) then
            trackWeapon(child)
            trackedCount += 1
        end
    end

    if not silent then
        log(string.format("Weapon scan complete: %d tracked", trackedCount))
    end
end

-- Rebinds weapon tracking whenever the local character changes (respawn/team swap).
local function bindCharacterForWeapons(character)
    trackedCharacter = character
    trackedWeapons = {}
    trackedWeaponPartState = {}
    trackedWeaponDamageState = {}
    originalWalkSpeed = nil

    if weaponChildAddedConnection then
        weaponChildAddedConnection:Disconnect()
    end
    if weaponChildRemovedConnection then
        weaponChildRemovedConnection:Disconnect()
    end

    weaponChildAddedConnection = character.ChildAdded:Connect(function(child)
        if isLikelyWeaponContainer(child) then
            task.wait()
            trackWeapon(child)
        end
    end)

    weaponChildRemovedConnection = character.ChildRemoved:Connect(function(child)
        untrackWeapon(child)
    end)

    rescanCharacterWeapons()
end

-- WalkSpeed override helper. Some games reset WalkSpeed frequently, so we re-apply on a loop.
local function applyWalkSpeed()
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if originalWalkSpeed == nil then
        originalWalkSpeed = humanoid.WalkSpeed
    end

    if walkSpeedOverrideEnabled then
        humanoid.WalkSpeed = walkSpeedValue
    elseif originalWalkSpeed ~= nil then
        humanoid.WalkSpeed = originalWalkSpeed
    end
end

local function safeSetFPS(cap)
    if typeof(setfpscap) == "function" then
        pcall(function() setfpscap(cap) end)
        return true
    end
    return false
end

local function pressSpace()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

local function makeCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = obj
end

local function makeStroke(obj)
    local s = Instance.new("UIStroke")
    s.Color = uiTheme.stroke
    s.Thickness = 1
    s.Transparency = 0.4
    s.Parent = obj
end

-- ---- Main UI construction ----
local screen = Instance.new("ScreenGui")
screen.Name = "MeerlyPE_PerfStability_UI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

stripBlurEffects()

Lighting.ChildAdded:Connect(function(child)
    if child:IsA("BlurEffect") then
        child.Enabled = false
        child.Size = 0
    end
end)

local window = Instance.new("Frame")
window.Parent = screen
window.Size = UDim2.fromOffset(430, 560)
window.Position = UDim2.fromScale(0.04, 0.14)
window.BackgroundColor3 = uiTheme.bg
window.BorderSizePixel = 0
window.Active = true
window.Draggable = true
makeCorner(window, 10)
makeStroke(window)

local title = Instance.new("TextLabel")
title.Parent = window
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.fromOffset(10, 10)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = uiTheme.text
title.Text = "Performance / Stability"

local logBox = Instance.new("TextLabel")
logBox.Parent = window
logBox.Size = UDim2.new(1, -20, 0, 52)
logBox.Position = UDim2.fromOffset(10, 44)
logBox.BackgroundColor3 = uiTheme.panel
logBox.BorderSizePixel = 0
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.TextWrapped = true
logBox.Font = Enum.Font.Code
logBox.TextSize = 13
logBox.TextColor3 = uiTheme.subtle
logBox.Text = "[System] Ready"
makeCorner(logBox, 6)
makeStroke(logBox)

log = function(msg)
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(msg))
    logBox.Text = line
    print("[MeerlyPerf]", msg)
end

local list = Instance.new("ScrollingFrame")
list.Parent = window
list.Size = UDim2.new(1, -20, 1, -158)
list.Position = UDim2.fromOffset(10, 106)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()

local layout = Instance.new("UIListLayout")
layout.Parent = list
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local function newRow(height)
    local row = Instance.new("Frame")
    row.Parent = list
    row.Size = UDim2.new(1, -4, 0, height or 34)
    row.BackgroundColor3 = uiTheme.panel
    row.BorderSizePixel = 0
    makeCorner(row, 6)
    makeStroke(row)
    return row
end

-- Reusable toggle factory for on/off controls in the performance panel.
local function makeToggle(labelText, default, callback)
    local row = newRow(34)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(0.64, -12, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = uiTheme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText

    local button = Instance.new("TextButton")
    button.Parent = row
    button.Size = UDim2.new(0.32, 0, 1, -8)
    button.Position = UDim2.new(0.68, 0, 0, 4)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    makeCorner(button, 5)

    local state = default == true
    local function refresh()
        button.Text = state and "ON" or "OFF"
        button.BackgroundColor3 = state and uiTheme.accent or Color3.fromRGB(70, 70, 82)
        button.TextColor3 = state and Color3.fromRGB(10, 10, 12) or uiTheme.text
    end

    button.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        callback(state)
    end)

    refresh()
    callback(state)

    return {
        set = function(v)
            state = v == true
            refresh()
            callback(state)
        end,
        get = function()
            return state
        end,
    }
end

-- Reusable numeric/text input factory.
local function makeInput(labelText, defaultText, onCommit)
    local row = newRow(34)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(0.54, -12, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = uiTheme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText

    local box = Instance.new("TextBox")
    box.Parent = row
    box.Size = UDim2.new(0.42, 0, 1, -8)
    box.Position = UDim2.new(0.56, 0, 0, 4)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextColor3 = uiTheme.text
    box.ClearTextOnFocus = false
    box.Text = tostring(defaultText)
    makeCorner(box, 5)

    box.FocusLost:Connect(function()
        local nextText = onCommit(box.Text)
        if nextText ~= nil then
            box.Text = tostring(nextText)
        end
    end)

    return box
end

-- Reusable action-button factory.
local function makeButton(text, onClick)
    local row = newRow(34)
    local btn = Instance.new("TextButton")
    btn.Parent = row
    btn.Size = UDim2.new(1, -8, 1, -8)
    btn.Position = UDim2.fromOffset(4, 4)
    btn.BorderSizePixel = 0
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = uiTheme.text
    btn.Text = text
    makeCorner(btn, 5)
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

local memoryGui = Instance.new("ScreenGui")
memoryGui.Name = "MeerlyPE_PerfStability_Memory"
memoryGui.ResetOnSpawn = false
memoryGui.IgnoreGuiInset = true
memoryGui.Enabled = false
memoryGui.Parent = player:WaitForChild("PlayerGui")

local memoryFrame = Instance.new("Frame")
memoryFrame.Parent = memoryGui
memoryFrame.Size = UDim2.fromOffset(280, 120)
memoryFrame.Position = UDim2.fromScale(0.73, 0.18)
memoryFrame.BackgroundColor3 = uiTheme.bg
memoryFrame.BorderSizePixel = 0
memoryFrame.Active = true
memoryFrame.Draggable = true
makeCorner(memoryFrame, 8)
makeStroke(memoryFrame)

local memoryText = Instance.new("TextLabel")
memoryText.Parent = memoryFrame
memoryText.Size = UDim2.new(1, -16, 1, -16)
memoryText.Position = UDim2.fromOffset(8, 8)
memoryText.BackgroundTransparency = 1
memoryText.TextXAlignment = Enum.TextXAlignment.Left
memoryText.TextYAlignment = Enum.TextYAlignment.Top
memoryText.Font = Enum.Font.Code
memoryText.TextSize = 13
memoryText.TextColor3 = uiTheme.text
memoryText.Text = "Memory: --"

-- ---- Feature wiring (UI -> behavior) ----
makeToggle("Anti-AFK (presses Space every 10m)", _G.__MeerlyPerfState.antiAfkEnabled, function(v)
    _G.__MeerlyPerfState.antiAfkEnabled = v
    log(v and "Anti-AFK enabled" or "Anti-AFK disabled")
end)

makeToggle("Watchdog", _G.__MeerlyPerfState.watchdogEnabled, function(v)
    _G.__MeerlyPerfState.watchdogEnabled = v
    log(v and "Watchdog enabled" or "Watchdog disabled")
end)

makeToggle("Memory Stats Floating UI", memoryStatsEnabled, function(v)
    memoryStatsEnabled = v
    memoryGui.Enabled = v
    log(v and "Memory stats enabled" or "Memory stats disabled")
end)

makeToggle("FPS Cap", fpsCapEnabled, function(v)
    fpsCapEnabled = v
    if fpsCapEnabled then
        if safeSetFPS(targetFPS) then
            log("FPS cap set: " .. targetFPS)
        else
            log("FPS cap unsupported by executor")
        end
    else
        safeSetFPS(0)
        log("FPS cap removed")
    end
end)

makeInput("Target FPS (30-240)", tostring(targetFPS), function(text)
    local val = tonumber(text)
    if val and val >= 30 and val <= 240 then
        targetFPS = math.floor(val)
        if fpsCapEnabled then
            safeSetFPS(targetFPS)
            log("FPS cap updated: " .. targetFPS)
        end
    end
    return tostring(targetFPS)
end)

makeToggle("Low Graphics Mode", lowGraphicsEnabled, function(v)
    lowGraphicsEnabled = v
    applyVisuals(v)
    log(v and "Low graphics enabled" or "Low graphics disabled")
end)

makeToggle("Streaming Optimization", streamingOptimized, function(v)
    streamingOptimized = v
    if v then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        pcall(function() settings().Network.IncomingReplicationLag = 0.1 end)
        log("Streaming optimization enabled")
    else
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        log("Streaming optimization disabled")
    end
end)

makeToggle("Aggressive FX Cull", aggressiveFxCullEnabled, function(v)
    aggressiveFxCullEnabled = v
    applyAggressiveFxCull(v)
end)

makeToggle("Auto-hide Disappear Parts", autoHideDisappearEnabled, function(v)
    autoHideDisappearEnabled = v
    fastScanDisappearParts()
    log(v and "Auto-hide Disappear enabled" or "Auto-hide Disappear disabled")
end)

makeToggle("Hide Tracked Weapon Parts", hideTrackedWeaponParts, function(v)
    hideTrackedWeaponParts = v
    for weapon in pairs(trackedWeapons) do
        applyWeaponState(weapon)
    end
    log(v and "Tracked weapon parts hidden" or "Tracked weapon parts shown")
end)

makeToggle("Override Weapon Damage", weaponDamageOverrideEnabled, function(v)
    weaponDamageOverrideEnabled = v
    for weapon in pairs(trackedWeapons) do
        applyWeaponState(weapon)
    end
    log(v and ("Weapon damage override enabled: " .. tostring(weaponDamageOverride)) or "Weapon damage override disabled")
end)

makeInput("Weapon Damage Value", tostring(weaponDamageOverride), function(text)
    local v = tonumber(text)
    if v then
        weaponDamageOverride = v
        if weaponDamageOverrideEnabled then
            for weapon in pairs(trackedWeapons) do
                applyWeaponState(weapon)
            end
            log("Weapon damage override updated: " .. tostring(weaponDamageOverride))
        end
    end
    return tostring(weaponDamageOverride)
end)

makeButton("Rescan Weapons", function()
    rescanCharacterWeapons()
end)

makeToggle("Hide Other Players Weapons (Slow Pass)", hideOtherPlayersWeapons, function(v)
    hideOtherPlayersWeapons = v
    local hiddenCount = applyOtherPlayersWeaponHiding()
    if v then
        log(string.format("Other-player weapon hide enabled (pass: %ds, parts: %d)", otherPlayersHidePassSeconds, hiddenCount))
    else
        log("Other-player weapon hide disabled")
    end
end)

makeInput("Disappear Fast Pass (0.1-2s)", tostring(disappearFastPassSeconds), function(text)
    local v = tonumber(text)
    if v and v >= 0.1 and v <= 2 then
        disappearFastPassSeconds = v
    end
    return tostring(disappearFastPassSeconds)
end)

makeInput("Other Weapon Pass Seconds (3-60)", tostring(otherPlayersHidePassSeconds), function(text)
    local v = tonumber(text)
    if v and v >= 3 and v <= 60 then
        otherPlayersHidePassSeconds = math.floor(v)
    end
    return tostring(otherPlayersHidePassSeconds)
end)

makeToggle("Override WalkSpeed", walkSpeedOverrideEnabled, function(v)
    walkSpeedOverrideEnabled = v
    applyWalkSpeed()
    log(v and ("WalkSpeed override enabled: " .. tostring(walkSpeedValue)) or "WalkSpeed override disabled")
end)

makeInput("WalkSpeed Value", tostring(walkSpeedValue), function(text)
    local v = tonumber(text)
    if v and v >= 1 and v <= 250 then
        walkSpeedValue = v
        if walkSpeedOverrideEnabled then
            applyWalkSpeed()
            log("WalkSpeed updated: " .. tostring(walkSpeedValue))
        end
    end
    return tostring(walkSpeedValue)
end)

makeToggle("Background Survival Mode", backgroundMode, function(v)
    backgroundMode = v
    log(v and "Background mode enabled" or "Background mode disabled")
end)

makeToggle("Disable 3D Rendering", disable3D, function(v)
    disable3D = v
    if RunService.Set3dRenderingEnabled then
        pcall(function() RunService:Set3dRenderingEnabled(not v) end)
        log(v and "3D rendering disabled" or "3D rendering enabled")
    else
        log("3D render toggle unsupported")
    end
end)

makeToggle("Mute Game Sounds", muteSounds, function(v)
    muteSounds = v
    pcall(function() SoundService.RespectFilteringEnabled = true end)
    pcall(function() SoundService.Volume = v and 0 or 1 end)
    log(v and "Game sounds muted" or "Game sounds unmuted")
end)

local modeButton = makeButton("Memory Action: Off", function()
    local order = { "Off", "AutoRejoin", "AutoQuit" }
    local idx = table.find(order, memoryGuardMode) or 1
    idx = (idx % #order) + 1
    memoryGuardMode = order[idx]
    modeButton.Text = "Memory Action: " .. memoryGuardMode
    log("Memory guard mode: " .. memoryGuardMode)
end)

makeInput("Memory Cap (GB)", tostring(memoryGuardCapGB), function(text)
    local v = tonumber(text)
    if v and v >= 0.5 and v <= 128 then
        memoryGuardCapGB = v
    end
    return tostring(memoryGuardCapGB)
end)

makeButton("Rejoin Server", function()
    log("Rejoining server...")
    task.spawn(function()
        local ok, err = pcall(function()
            if game.JobId and game.JobId ~= "" then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
            else
                TeleportService:Teleport(game.PlaceId, player)
            end
        end)
        if not ok then
            log("Rejoin failed: " .. tostring(err))
        end
    end)
end)

-- Hard shutdown path: disconnect loops/listeners and destroy UI safely.
makeButton("KILL SWITCH", function()
    if destroyRequested then return end
    destroyRequested = true
    running = false
    pcall(function() safeSetFPS(0) end)
    if fxCullConnection then
        pcall(function() fxCullConnection:Disconnect() end)
        fxCullConnection = nil
    end
    if weaponChildAddedConnection then
        pcall(function() weaponChildAddedConnection:Disconnect() end)
        weaponChildAddedConnection = nil
    end
    if weaponChildRemovedConnection then
        pcall(function() weaponChildRemovedConnection:Disconnect() end)
        weaponChildRemovedConnection = nil
    end
    if characterAddedConnection then
        pcall(function() characterAddedConnection:Disconnect() end)
        characterAddedConnection = nil
    end
    if disappearAddedConnection then
        pcall(function() disappearAddedConnection:Disconnect() end)
        disappearAddedConnection = nil
    end
    pcall(function() screen:Destroy() end)
    pcall(function() memoryGui:Destroy() end)
    log("UI destroyed")
end)

UserInputService.WindowFocused:Connect(function()
    windowFocused = true
    if backgroundMode then
        log("Window focused")
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Semicolon then
        uiVisible = not uiVisible
        screen.Enabled = uiVisible
        log(uiVisible and "UI shown (; hotkey)" or "UI hidden (; hotkey)")
    end
end)

UserInputService.WindowFocusReleased:Connect(function()
    windowFocused = false
    if backgroundMode then
        log("Window unfocused (background mode active)")
    end
end)

-- ---- Background loops/watchers ----
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    local prev = _G.__MeerlyPerfState.lastHeartbeat or now
    local delta = now - prev
    _G.__MeerlyPerfState.lastHeartbeat = now
    if delta > heartbeatLagThreshold then
        log(string.format("Heartbeat lag detected: %.2fs", delta))
    end
end)

task.spawn(function()
    local interval = 600
    local nextFire = os.clock() + interval
    while running do
        task.wait(1)
        if _G.__MeerlyPerfState.antiAfkEnabled then
            if os.clock() >= nextFire then
                pressSpace()
                nextFire = os.clock() + interval
                log("Anti-AFK pulse")
            end
        else
            nextFire = os.clock() + interval
        end
    end
end)

task.spawn(function()
    while running do
        task.wait(1)
        if _G.__MeerlyPerfState.watchdogEnabled then
            local delta = os.clock() - (_G.__MeerlyPerfState.lastHeartbeat or os.clock())
            if delta > watchdogThreshold then
                log(string.format("Watchdog warning: heartbeat delayed (%.2fs)", delta))
            end
        end
    end
end)

task.spawn(function()
    while running do
        task.wait(2)
        if backgroundMode and not windowFocused then
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        end
    end
end)

task.spawn(function()
    while running do
        task.wait(1)
        if memoryStatsEnabled and memoryGui.Enabled then
            local combinedGb, luaGb, totalGb, engineGb = getCombinedMemoryGb()
            memoryText.Text = string.format(
                "Combined: %.2f GB\nLua: %.2f GB\nTotal: %s GB\nEngine(est): %s GB",
                combinedGb,
                luaGb,
                totalGb and string.format("%.2f", totalGb) or "--",
                engineGb and string.format("%.2f", engineGb) or "--"
            )
        end
    end
end)

task.spawn(function()
    while running do
        task.wait(5)
        local now = os.clock()
        local combinedGb = getCombinedMemoryGb()

        if memoryGuardMode ~= "Off" and combinedGb >= memoryGuardCapGB and (now - lastMemoryGuardAction) >= memoryGuardCooldown then
            lastMemoryGuardAction = now
            log(string.format("Memory guard triggered: %.2f GB >= %.2f GB (%s)", combinedGb, memoryGuardCapGB, memoryGuardMode))

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
                        log("AutoRejoin failed: " .. tostring(err))
                    end
                end)
            elseif memoryGuardMode == "AutoQuit" then
                pcall(function() player:Kick("AutoQuit: memory cap exceeded") end)
            end
        end
    end
end)

-- ---- Character lifecycle bootstrapping ----
if player.Character then
    bindCharacterForWeapons(player.Character)
end

characterAddedConnection = player.CharacterAdded:Connect(function(character)
    task.wait(0.15)
    bindCharacterForWeapons(character)
end)

-- Event path for immediate response on newly spawned Disappear parts.
disappearAddedConnection = Workspace.DescendantAdded:Connect(function(instance)
    processDisappearCandidate(instance)
end)

-- Initial catch-up scan for already-existing Disappear parts.
fastScanDisappearParts()

task.spawn(function()
    while running do
        task.wait(3)
        rescanCharacterWeapons(true)
    end
end)

task.spawn(function()
    while running do
        task.wait(otherPlayersHidePassSeconds)
        if hideOtherPlayersWeapons then
            applyOtherPlayersWeaponHiding()
        end
    end
end)

task.spawn(function()
    while running do
        task.wait(0.75)
        if walkSpeedOverrideEnabled then
            applyWalkSpeed()
        end
    end
end)

-- Very fast pass for high-density enemy areas where many Disappear parts spawn continuously.
-- Keeping this separate from other scans prevents misses without making weapon scans heavier.
task.spawn(function()
    while running do
        task.wait(disappearFastPassSeconds)
        fastScanDisappearParts()
    end
end)

log("Performance / Stability UI loaded")
