--[[
    Meerly PU - Ascension Utility
    Built with the same UX style + keygate behavior as MeerlyPU.lua.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer

local hardcodedAccessKey = "KnowledgeIsPower"
local keychainUrl = "https://work.ink/2kaV/meerly-knowledge-incremental"

local uiTheme = {
    bg = Color3.fromRGB(18, 18, 24),
    panel = Color3.fromRGB(25, 25, 33),
    accent = Color3.fromRGB(120, 180, 255),
    text = Color3.fromRGB(235, 235, 240),
    subtle = Color3.fromRGB(160, 160, 170),
    stroke = Color3.fromRGB(45, 45, 55),
}

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

local screen = Instance.new("ScreenGui")
screen.Name = "MeerlyPU_Ascension"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = localPlayer:WaitForChild("PlayerGui")

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
title.Text = "Key System"

local quickKillButton = Instance.new("TextButton")
quickKillButton.Parent = window
quickKillButton.Size = UDim2.fromOffset(24, 24)
quickKillButton.Position = UDim2.new(1, -34, 0, 12)
quickKillButton.BackgroundColor3 = Color3.fromRGB(170, 65, 65)
quickKillButton.BorderSizePixel = 0
quickKillButton.Font = Enum.Font.GothamBold
quickKillButton.TextSize = 14
quickKillButton.TextColor3 = Color3.fromRGB(245, 245, 245)
quickKillButton.Text = "X"
quickKillButton.ZIndex = 20
makeCorner(quickKillButton, 6)
makeStroke(quickKillButton)

local tabBar = Instance.new("Frame")
tabBar.Parent = window
tabBar.Size = UDim2.new(1, -20, 0, 30)
tabBar.Position = UDim2.fromOffset(10, 44)
tabBar.BackgroundColor3 = uiTheme.panel
tabBar.BorderSizePixel = 0
makeCorner(tabBar, 6)
makeStroke(tabBar)

local tabLayout = Instance.new("UIListLayout")
tabLayout.Parent = tabBar
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local tabPadding = Instance.new("UIPadding")
tabPadding.Parent = tabBar
tabPadding.PaddingLeft = UDim.new(0, 4)
tabPadding.PaddingRight = UDim.new(0, 4)

local tabPagesRoot = Instance.new("Frame")
tabPagesRoot.Parent = window
tabPagesRoot.Size = UDim2.new(1, -20, 1, -188)
tabPagesRoot.Position = UDim2.fromOffset(10, 108)
tabPagesRoot.BackgroundTransparency = 1

local logBox = Instance.new("TextLabel")
logBox.Parent = window
logBox.Size = UDim2.new(1, -20, 0, 44)
logBox.Position = UDim2.fromOffset(10, window.Size.Y.Offset - 52)
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

local function log(msg)
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(msg))
    logBox.Text = line
    print("[MeerlyPU Ascension]", msg)
end

local keyAccepted = false
local function setMainUiUnlocked(unlocked)
    keyAccepted = unlocked == true
    tabBar.Visible = keyAccepted
    tabPagesRoot.Visible = keyAccepted
    logBox.Visible = keyAccepted
    title.Text = keyAccepted and "Meerly Ascension Utility - hide/open with ;" or "Key System"
end

setMainUiUnlocked(false)

local keyGate = Instance.new("Frame")
keyGate.Parent = window
keyGate.Size = UDim2.new(1, -20, 1, -108)
keyGate.Position = UDim2.fromOffset(10, 50)
keyGate.BackgroundColor3 = uiTheme.panel
keyGate.BorderSizePixel = 0
makeCorner(keyGate, 8)
makeStroke(keyGate)

local keyGateTitle = Instance.new("TextLabel")
keyGateTitle.Parent = keyGate
keyGateTitle.Size = UDim2.new(1, -20, 0, 36)
keyGateTitle.Position = UDim2.fromOffset(10, 14)
keyGateTitle.BackgroundTransparency = 1
keyGateTitle.Font = Enum.Font.GothamBold
keyGateTitle.TextSize = 18
keyGateTitle.TextColor3 = uiTheme.text
keyGateTitle.TextXAlignment = Enum.TextXAlignment.Left
keyGateTitle.Text = "Enter Access Key"

local keyGateInfo = Instance.new("TextLabel")
keyGateInfo.Parent = keyGate
keyGateInfo.Size = UDim2.new(1, -20, 0, 52)
keyGateInfo.Position = UDim2.fromOffset(10, 50)
keyGateInfo.BackgroundTransparency = 1
keyGateInfo.Font = Enum.Font.Gotham
keyGateInfo.TextSize = 13
keyGateInfo.TextWrapped = true
keyGateInfo.TextColor3 = uiTheme.subtle
keyGateInfo.TextXAlignment = Enum.TextXAlignment.Left
keyGateInfo.TextYAlignment = Enum.TextYAlignment.Top
keyGateInfo.Text = "Open the work.ink keychain link, complete it, then paste your key below."

local keyLinkButton = Instance.new("TextButton")
keyLinkButton.Parent = keyGate
keyLinkButton.Size = UDim2.new(1, -20, 0, 34)
keyLinkButton.Position = UDim2.fromOffset(10, 116)
keyLinkButton.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
keyLinkButton.BorderSizePixel = 0
keyLinkButton.Font = Enum.Font.GothamBold
keyLinkButton.TextSize = 13
keyLinkButton.TextColor3 = uiTheme.text
keyLinkButton.Text = "Open Keychain Link"
makeCorner(keyLinkButton, 6)
makeStroke(keyLinkButton)

local keyInput = Instance.new("TextBox")
keyInput.Parent = keyGate
keyInput.Size = UDim2.new(1, -20, 0, 34)
keyInput.Position = UDim2.fromOffset(10, 158)
keyInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
keyInput.BorderSizePixel = 0
keyInput.Font = Enum.Font.Gotham
keyInput.TextSize = 13
keyInput.TextColor3 = uiTheme.text
keyInput.PlaceholderText = "Paste key here"
keyInput.ClearTextOnFocus = true
makeCorner(keyInput, 6)
makeStroke(keyInput)

local submitKeyButton = Instance.new("TextButton")
submitKeyButton.Parent = keyGate
submitKeyButton.Size = UDim2.new(1, -20, 0, 34)
submitKeyButton.Position = UDim2.fromOffset(10, 200)
submitKeyButton.BackgroundColor3 = uiTheme.accent
submitKeyButton.BorderSizePixel = 0
submitKeyButton.Font = Enum.Font.GothamBold
submitKeyButton.TextSize = 13
submitKeyButton.TextColor3 = Color3.fromRGB(10, 10, 12)
submitKeyButton.Text = "Unlock"
makeCorner(submitKeyButton, 6)
makeStroke(submitKeyButton)

local keyStatus = Instance.new("TextLabel")
keyStatus.Parent = keyGate
keyStatus.Size = UDim2.new(1, -20, 0, 24)
keyStatus.Position = UDim2.fromOffset(10, 242)
keyStatus.BackgroundTransparency = 1
keyStatus.Font = Enum.Font.Gotham
keyStatus.TextSize = 12
keyStatus.TextColor3 = uiTheme.subtle
keyStatus.TextXAlignment = Enum.TextXAlignment.Left
keyStatus.Text = "Status: Locked"

keyLinkButton.MouseButton1Click:Connect(function()
    local ok = pcall(function()
        if setclipboard then
            setclipboard(keychainUrl)
        end
    end)
    log(ok and "Key link copied to clipboard" or "Clipboard unavailable; copy manually")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Meerly Ascension",
            Text = "Key link: " .. keychainUrl,
            Duration = 5,
        })
    end)
end)

local function tryUnlockWithKey()
    if keyInput.Text == hardcodedAccessKey then
        keyGate.Visible = false
        setMainUiUnlocked(true)
        keyStatus.Text = "Status: Unlocked"
        log("Key accepted")
    else
        keyStatus.Text = "Status: Invalid key"
        log("Invalid key entered")
    end
end

submitKeyButton.MouseButton1Click:Connect(tryUnlockWithKey)
keyInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        tryUnlockWithKey()
    end
end)

local tabPages = {}
local tabButtons = {}
local currentTabName = "Features"
local activeList = nil

local function switchTab(name)
    if not tabPages[name] then return end
    currentTabName = name
    for tabName, tabPage in pairs(tabPages) do
        tabPage.Visible = (tabName == name)
    end
    for tabName, tabBtn in pairs(tabButtons) do
        tabBtn.BackgroundColor3 = (tabName == name) and uiTheme.accent or Color3.fromRGB(70, 70, 82)
        tabBtn.TextColor3 = (tabName == name) and Color3.fromRGB(10, 10, 12) or uiTheme.text
    end
    activeList = tabPages[name]
end

local function createTab(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Parent = tabPagesRoot
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = (name == "Teleports") and 10 or 6
    page.ScrollBarImageColor3 = uiTheme.accent
    page.ScrollBarImageTransparency = 0.15
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false

    local layout = Instance.new("UIListLayout")
    layout.Parent = page
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    tabPages[name] = page

    local btn = Instance.new("TextButton")
    btn.Parent = tabBar
    btn.BorderSizePixel = 0
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = uiTheme.text
    btn.Text = name
    makeCorner(btn, 5)
    tabButtons[name] = btn

    btn.MouseButton1Click:Connect(function()
        switchTab(name)
    end)

    return page
end

local tabNames = { "Features", "Teleports", "Auto Raid" }
for _, tab in ipairs(tabNames) do
    createTab(tab)
end

local function updateTabButtonSizes()
    local paddingPx = tabLayout.Padding.Offset
    local barWidth = tabBar.AbsoluteSize.X
    if barWidth <= 0 then
        barWidth = 410
    end

    local available = barWidth - tabPadding.PaddingLeft.Offset - tabPadding.PaddingRight.Offset - ((#tabNames - 1) * paddingPx)
    local widthPer = math.max(54, math.floor(available / #tabNames))

    for _, n in ipairs(tabNames) do
        if tabButtons[n] then
            tabButtons[n].Size = UDim2.fromOffset(widthPer, 22)
        end
    end
end

updateTabButtonSizes()
tabBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTabButtonSizes)
switchTab("Features")

local function newRow(height, tabName)
    local parentList = tabPages[tabName or currentTabName] or activeList
    local row = Instance.new("Frame")
    row.Parent = parentList
    row.Size = UDim2.new(1, -4, 0, height or 34)
    row.BackgroundColor3 = uiTheme.panel
    row.BorderSizePixel = 0
    makeCorner(row, 6)
    makeStroke(row)
    return row
end

local function makeToggle(labelText, default, callback, tabName)
    local row = newRow(34, tabName)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(0.58, -12, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = uiTheme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText

    local button = Instance.new("TextButton")
    button.Parent = row
    button.Size = UDim2.new(0.28, 0, 1, -8)
    button.Position = UDim2.new(0.62, 0, 0, 4)
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

local function makeInput(labelText, defaultText, onCommit, tabName)
    local row = newRow(34, tabName)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(0.48, -12, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = uiTheme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText

    local box = Instance.new("TextBox")
    box.Parent = row
    box.Size = UDim2.new(0.38, 0, 1, -8)
    box.Position = UDim2.new(0.50, 0, 0, 4)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextColor3 = uiTheme.text
    box.ClearTextOnFocus = false
    box.Text = tostring(defaultText)
    makeCorner(box, 5)

    box.FocusLost:Connect(function()
        box.Text = tostring(onCommit(box.Text))
    end)

    box.Text = tostring(onCommit(box.Text))

    return box
end

local function makeButton(text, callback, tabName)
    local row = newRow(34, tabName)
    local button = Instance.new("TextButton")
    button.Parent = row
    button.Size = UDim2.new(1, -8, 1, -8)
    button.Position = UDim2.fromOffset(4, 4)
    button.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.TextColor3 = uiTheme.text
    button.Text = text
    makeCorner(button, 5)
    makeStroke(button)
    button.MouseButton1Click:Connect(callback)
    return button
end

local function makeInlineButtons(buttons, tabName)
    local row = newRow(34, tabName)
    local gap = 6
    local count = #buttons
    local totalGap = (count - 1) * gap
    local widthScale = 1 / count
    local widthOffset = -math.floor((8 + totalGap) / count)

    for idx, data in ipairs(buttons) do
        local btn = Instance.new("TextButton")
        btn.Parent = row
        btn.Size = UDim2.new(widthScale, widthOffset, 1, -8)
        btn.Position = UDim2.new((idx - 1) * widthScale, 4 + ((idx - 1) * gap), 0, 4)
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextColor3 = uiTheme.text
        btn.Text = data[1]
        makeCorner(btn, 5)
        makeStroke(btn)
        btn.MouseButton1Click:Connect(data[2])
    end
end

local function makeSlider(labelText, minValue, maxValue, defaultValue, onChanged, tabName)
    local row = newRow(52, tabName)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(1, -20, 0, 18)
    label.Position = UDim2.fromOffset(10, 6)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = uiTheme.text
    label.TextXAlignment = Enum.TextXAlignment.Left

    local bar = Instance.new("Frame")
    bar.Parent = row
    bar.Size = UDim2.new(1, -20, 0, 10)
    bar.Position = UDim2.fromOffset(10, 30)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    bar.BorderSizePixel = 0
    makeCorner(bar, 4)

    local fill = Instance.new("Frame")
    fill.Parent = bar
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = uiTheme.accent
    fill.BorderSizePixel = 0
    makeCorner(fill, 4)

    local dragging = false
    local value = math.clamp(defaultValue or minValue, minValue, maxValue)

    local function updateLabel()
        label.Text = string.format("%s: %ds", labelText, value)
    end

    local function updateVisuals()
        local alpha = (value - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        updateLabel()
    end

    local function setFromX(x)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        value = math.floor(minValue + ((maxValue - minValue) * alpha) + 0.5)
        updateVisuals()
        onChanged(value)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromX(input.Position.X)
        end
    end)

    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end)

    updateVisuals()
    onChanged(value)

    return {
        get = function() return value end,
        set = function(v)
            value = math.clamp(math.floor(v), minValue, maxValue)
            updateVisuals()
            onChanged(value)
        end,
        setVisible = function(state)
            row.Visible = state == true
        end,
    }
end

local walkSpeedEnabled = false
local walkSpeedValue = 16
local hideOthersEnabled = false
local uiVisible = true
local autoRebirth = false
local autoEnlightenment = false
local autoTranscendence = false
local autoRebirthDelay = 5
local autoEnlightenmentDelay = 5
local autoTranscendenceDelay = 5
local antiAfkEnabled = false
local antiAfkInterval = 600
local autoClickerEnabled = false
local autoClickerCPS = 10
local hidePlayersScanInterval = 10
local autoRaidMasterEnabled = false
local raidStarted = false
local onGoingRaid = false
local raidEnemyScanInterval = 2
local raidSeekEnabled = false
local raidPresenceScanInterval = 7
local lastRaidPresenceScan = 0
local raidReturnTeleportResolver = nil
local raidReturnTeleportName = nil
local raidTeleportedToLobby = false
local autoSkillsEnabled = false
local autoSkillBeam = false
local autoSkillSlam = false
local autoSkillNova = false
local beamCooldown = 9
local slamCooldown = 4
local novaCooldown = 21
local lastBeamCast = 0
local lastSlamCast = 0
local lastNovaCast = 0

local hiddenObjectStates = {}

local function hideObject(obj)
    if hiddenObjectStates[obj] then
        return
    end

    local state = {}

    if obj:IsA("BasePart") then
        state.class = "BasePart"
        state.localTransparencyModifier = obj.LocalTransparencyModifier
        state.transparency = obj.Transparency
        state.canCollide = obj.CanCollide
        state.canTouch = obj.CanTouch
        if obj.CanQuery ~= nil then
            state.canQuery = obj.CanQuery
        end
        obj.LocalTransparencyModifier = 1
        obj.Transparency = 1
        obj.CanCollide = false
        obj.CanTouch = false
        pcall(function() obj.CanQuery = false end)
    elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
        state.class = "Gui"
        state.enabled = obj.Enabled
        obj.Enabled = false
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        state.class = "Effect"
        state.enabled = obj.Enabled
        obj.Enabled = false
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        state.class = "DecalTexture"
        state.transparency = obj.Transparency
        obj.Transparency = 1
    elseif obj:IsA("Highlight") then
        state.class = "Highlight"
        state.enabled = obj.Enabled
        state.fillTransparency = obj.FillTransparency
        state.outlineTransparency = obj.OutlineTransparency
        obj.Enabled = false
        obj.FillTransparency = 1
        obj.OutlineTransparency = 1
    else
        return
    end

    hiddenObjectStates[obj] = state
end

local function restoreObject(obj)
    local state = hiddenObjectStates[obj]
    if not state then
        return
    end

    if state.class == "BasePart" then
        obj.LocalTransparencyModifier = state.localTransparencyModifier or 0
        obj.Transparency = state.transparency or 0
        obj.CanCollide = state.canCollide == true
        obj.CanTouch = state.canTouch == true
        pcall(function()
            if state.canQuery ~= nil then
                obj.CanQuery = state.canQuery
            end
        end)
    elseif state.class == "Gui" or state.class == "Effect" then
        obj.Enabled = state.enabled ~= false
    elseif state.class == "DecalTexture" then
        obj.Transparency = state.transparency or 0
    elseif state.class == "Highlight" then
        obj.Enabled = state.enabled ~= false
        obj.FillTransparency = state.fillTransparency or 0
        obj.OutlineTransparency = state.outlineTransparency or 0
    end

    hiddenObjectStates[obj] = nil
end

local function applyHideOnCharacter(character, hide)
    if not character then return end
    for _, obj in ipairs(character:GetDescendants()) do
        if hide then
            hideObject(obj)
        else
            restoreObject(obj)
        end
    end
end

local function restoreAllHiddenObjects()
    for obj in pairs(hiddenObjectStates) do
        if obj and obj.Parent then
            restoreObject(obj)
        else
            hiddenObjectStates[obj] = nil
        end
    end
end

local function getHumanoid()

    local character = localPlayer.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

RunService.Heartbeat:Connect(function()
    if not keyAccepted then return end
    local humanoid = getHumanoid()
    if humanoid and walkSpeedEnabled then
        humanoid.WalkSpeed = walkSpeedValue
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    if input.KeyCode == Enum.KeyCode.Semicolon then
        uiVisible = not uiVisible
        window.Visible = uiVisible
        return
    end

    if input.KeyCode == Enum.KeyCode.F6 then
        autoClickerEnabled = not autoClickerEnabled
        log("Auto Clicker " .. (autoClickerEnabled and "enabled" or "disabled") .. " (F6)")
        return
    end

end)

local function setHideOtherPlayers(state)
    hideOthersEnabled = state

    if not state then
        restoreAllHiddenObjects()
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            applyHideOnCharacter(plr.Character, state)
        end
    end
    log(state and "Other players hidden (including FX/parts/accessories)" or "Other players restored")
end

Players.PlayerAdded:Connect(function(plr)
    if plr == localPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        if hideOthersEnabled then
            task.wait(0.2)
            applyHideOnCharacter(char, true)
        end
    end)
end)

task.spawn(function()
    while screen.Parent do
        if keyAccepted and hideOthersEnabled then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= localPlayer then
                    applyHideOnCharacter(plr.Character, true)
                end
            end
        end
        task.wait(hidePlayersScanInterval)
    end
end)

local teleportLocations = {
    quickActions = {
        { "The Lobby", function() return workspace.SpawnLocation end },
        { "The Study", function() return workspace.Rooms.Room1:GetChildren()[4].RugMain end },
        { "The Archives", function() return workspace:GetChildren()[37]:GetChildren()[196] end },
        { "The Sanctum", function() return workspace.Rooms.Room3:GetChildren()[334] end },
        { "The Chamber", function() return workspace.Rooms.Room4:GetChildren()[120] end },
        { "The Observatory", function() return workspace.Rooms.Room5.FloorTile_40_5 end },
    },
    autoScrolls = {
        { "Knowledge Scrolls", function() return workspace.ScrollAltar.ScrollAltar end },
        { "Tome Scrolls", function() return workspace:GetChildren()[64].ScrollAltar end },
        { "Rune Scrolls", function() return workspace:GetChildren()[61].ScrollAltar.ScrollAltar end },
        { "Essence Scrolls", function() return workspace:GetChildren()[63].ScrollAltar end },
        { "Starlight Scrolls", function() return workspace:GetChildren()[62].ScrollAltar end },
    },
    secret = {
        { "Observatory Roof", function() return workspace.Rooms.Room5.DomeApex end },
    },
}

local function makeSectionLabel(text, tabName)
    local row = newRow(30, tabName)
    row.BackgroundTransparency = 1
    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(1, -8, 1, 0)
    label.Position = UDim2.fromOffset(4, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = uiTheme.accent
    label.Text = text
end

local function teleportTo(targetInstance)
    if not targetInstance then
        log("Teleport failed: target not found")
        return
    end

    local character = localPlayer.Character
    if not character then
        log("Teleport failed: no character")
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        log("Teleport failed: no HumanoidRootPart")
        return
    end

    local cf
    if targetInstance:IsA("BasePart") then
        cf = targetInstance.CFrame + Vector3.new(0, 4, 0)
    elseif targetInstance:IsA("Model") then
        cf = targetInstance:GetPivot() + Vector3.new(0, 4, 0)
    else
        log("Teleport failed: unsupported target type")
        return
    end

    root.CFrame = cf
    log("Teleported to " .. targetInstance:GetFullName())
end

local function fireRemote(remoteName)
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    local remote = remotesFolder and remotesFolder:FindFirstChild(remoteName)
    if not remote or not remote:IsA("RemoteEvent") then
        log("Remote missing: " .. remoteName)
        return
    end
    remote:FireServer()
    log("Fired remote: " .. remoteName)
end

local function isRaidTimerVisible()
    local hud = localPlayer:FindFirstChild("PlayerGui") and localPlayer.PlayerGui:FindFirstChild("HUD")
    local raidTimer = hud and hud:FindFirstChild("RaidNextTimer")
    if not raidTimer then
        return nil
    end
    return raidTimer.Visible == true
end

local function getRaidEnemiesAlive()
    local raidEnemies = Workspace:FindFirstChild("RaidEnemies")
    if not raidEnemies then
        return false, nil
    end

    for _, enemy in ipairs(raidEnemies:GetChildren()) do
        if enemy and enemy.Parent then
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health > 0 then
                return true, enemy
            end
        end
    end

    return false, nil
end

local function getRaidResultsVisible()
    local hud = localPlayer:FindFirstChild("PlayerGui") and localPlayer.PlayerGui:FindFirstChild("HUD")
    local results = hud and hud:FindFirstChild("RaidResultsScreen")
    return results and results.Visible == true
end

local function ensureRaidSpellBarActive()
    local hud = localPlayer:FindFirstChild("PlayerGui") and localPlayer.PlayerGui:FindFirstChild("HUD")
    local spellBar = hud and hud:FindFirstChild("RaidSpellBar")
    if not spellBar then
        return false
    end

    spellBar.Visible = true
    pcall(function()
        if spellBar:IsA("GuiObject") then
            spellBar.Active = true
        end
    end)

    return true
end

local function resolveClosestGeneralTeleport()
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil, nil
    end

    local closestDistance = math.huge
    local closestName = nil
    local closestResolver = nil

    for _, data in ipairs(teleportLocations.quickActions) do
        local name, resolver = data[1], data[2]
        local ok, target = pcall(resolver)
        if ok and target then
            local targetPos
            if target:IsA("BasePart") then
                targetPos = target.Position
            elseif target:IsA("Model") then
                targetPos = target:GetPivot().Position
            end

            if targetPos then
                local distance = (root.Position - targetPos).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestName = name
                    closestResolver = resolver
                end
            end
        end
    end

    return closestName, closestResolver
end

local function moveToRaidEnemy(enemy)
    if not enemy then return end
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local targetPart = enemy:IsA("Model") and (enemy.PrimaryPart or enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildWhichIsA("BasePart")) or (enemy:IsA("BasePart") and enemy or nil)
    if not targetPart then return end

    humanoid:MoveTo(targetPart.Position)
end

local function pressRaidSkill(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function makeButtonGrid(buttons, columns, tabName)
    local columnCount = math.max(1, columns or 2)
    local rows = math.ceil(#buttons / columnCount)

    for rowIndex = 1, rows do
        local rowButtons = {}
        local startIdx = ((rowIndex - 1) * columnCount) + 1
        local endIdx = math.min(startIdx + columnCount - 1, #buttons)
        for i = startIdx, endIdx do
            rowButtons[#rowButtons + 1] = buttons[i]
        end
        makeInlineButtons(rowButtons, tabName)
    end
end

local function makeInputToggleRow(labelText, defaultText, defaultToggle, onCommit, onToggle, tabName)
    local row = newRow(34, tabName)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(0.42, -8, 1, 0)
    label.Position = UDim2.fromOffset(8, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = uiTheme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText

    local box = Instance.new("TextBox")
    box.Parent = row
    box.Size = UDim2.new(0.24, -4, 1, -8)
    box.Position = UDim2.new(0.42, 0, 0, 4)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextColor3 = uiTheme.text
    box.ClearTextOnFocus = false
    makeCorner(box, 5)

    local toggle = Instance.new("TextButton")
    toggle.Parent = row
    toggle.Size = UDim2.new(0.24, -4, 1, -8)
    toggle.Position = UDim2.new(0.74, 0, 0, 4)
    toggle.BorderSizePixel = 0
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 12
    makeCorner(toggle, 5)

    local toggleState = defaultToggle == true
    local function refreshToggle()
        toggle.Text = toggleState and "ON" or "OFF"
        toggle.BackgroundColor3 = toggleState and uiTheme.accent or Color3.fromRGB(70, 70, 82)
        toggle.TextColor3 = toggleState and Color3.fromRGB(10, 10, 12) or uiTheme.text
    end

    toggle.MouseButton1Click:Connect(function()
        toggleState = not toggleState
        refreshToggle()
        onToggle(toggleState)
    end)

    box.FocusLost:Connect(function()
        box.Text = tostring(onCommit(box.Text))
    end)

    box.Text = tostring(onCommit(defaultText))
    refreshToggle()
    onToggle(toggleState)

    return {
        setToggle = function(v)
            toggleState = v == true
            refreshToggle()
            onToggle(toggleState)
        end,
        getToggle = function()
            return toggleState
        end,
    }
end

local function makeSkillToggleRow(tabName)
    local row = newRow(34, tabName)
    local entries = {
        { name = "Beam", stateRef = function() return autoSkillBeam end, setRef = function(v) autoSkillBeam = v end },
        { name = "Slam", stateRef = function() return autoSkillSlam end, setRef = function(v) autoSkillSlam = v end },
        { name = "Nova", stateRef = function() return autoSkillNova end, setRef = function(v) autoSkillNova = v end },
    }

    local gap = 6
    local count = #entries
    local widthScale = 1 / count
    local widthOffset = -math.floor((8 + ((count - 1) * gap)) / count)

    for idx, entry in ipairs(entries) do
        local btn = Instance.new("TextButton")
        btn.Parent = row
        btn.Size = UDim2.new(widthScale, widthOffset, 1, -8)
        btn.Position = UDim2.new((idx - 1) * widthScale, 4 + ((idx - 1) * gap), 0, 4)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        makeCorner(btn, 5)
        makeStroke(btn)

        local function refresh()
            local state = entry.stateRef()
            btn.Text = string.format("%s: %s", entry.name, state and "ON" or "OFF")
            btn.BackgroundColor3 = state and uiTheme.accent or Color3.fromRGB(70, 70, 82)
            btn.TextColor3 = state and Color3.fromRGB(10, 10, 12) or uiTheme.text
        end

        btn.MouseButton1Click:Connect(function()
            entry.setRef(not entry.stateRef())
            refresh()
        end)

        refresh()
    end

    return row
end

makeSectionLabel("General Actions", "Features")

makeInput("WalkSpeed Value", walkSpeedValue, function(text)
    local value = tonumber(text) or 16
    walkSpeedValue = math.clamp(math.floor(value), 1, 300)
    return walkSpeedValue
end, "Features")

makeToggle("Walkspeed Changer", false, function(state)
    walkSpeedEnabled = state
    if not state then
        local humanoid = getHumanoid()
        if humanoid then humanoid.WalkSpeed = 16 end
    end
    log("Walkspeed changer " .. (state and "enabled" or "disabled"))
end, "Features")

makeToggle("Hide Other Players", false, function(state)
    setHideOtherPlayers(state)
end, "Features")

makeToggle("Anti-AFK (SPACE / 10 min)", false, function(state)
    antiAfkEnabled = state
    log("Anti-AFK " .. (state and "enabled" or "disabled"))
end, "Features")

makeInput("Auto Clicker CPS (F6)", autoClickerCPS, function(text)
    local value = tonumber(text) or autoClickerCPS
    autoClickerCPS = math.clamp(math.floor(value), 1, 20)
    log("Auto Clicker CPS set to " .. autoClickerCPS)
    return autoClickerCPS
end, "Features")

makeSectionLabel("Remote Bypass", "Features")

local rebirthSlider
makeToggle("Auto Rebirth", false, function(state)
    autoRebirth = state
    if rebirthSlider then
        rebirthSlider.setVisible(state)
    end
    log("Auto Rebirth " .. (state and "enabled" or "disabled"))
end, "Features")

rebirthSlider = makeSlider("Rebirth Timer", 1, 90, autoRebirthDelay, function(value)
    autoRebirthDelay = value
end, "Features")
rebirthSlider.setVisible(autoRebirth)

local enlightenmentSlider
makeToggle("Auto Enlightenment", false, function(state)
    autoEnlightenment = state
    if enlightenmentSlider then
        enlightenmentSlider.setVisible(state)
    end
    log("Auto Enlightenment " .. (state and "enabled" or "disabled"))
end, "Features")

enlightenmentSlider = makeSlider("Enlightenment Timer", 1, 90, autoEnlightenmentDelay, function(value)
    autoEnlightenmentDelay = value
end, "Features")
enlightenmentSlider.setVisible(autoEnlightenment)

local transcendenceSlider
makeToggle("Auto Transcendence", false, function(state)
    autoTranscendence = state
    if transcendenceSlider then
        transcendenceSlider.setVisible(state)
    end
    log("Auto Transcendence " .. (state and "enabled" or "disabled"))
end, "Features")

transcendenceSlider = makeSlider("Transcendence Timer", 1, 90, autoTranscendenceDelay, function(value)
    autoTranscendenceDelay = value
end, "Features")
transcendenceSlider.setVisible(autoTranscendence)


makeInlineButtons({
    { "Rebirth", function() fireRemote("PerformRebirth") end },
    { "Enlighten", function() fireRemote("PerformEnlightenment") end },
    { "Transcend", function() fireRemote("PerformTranscendence") end },
}, "Features")

makeButton("Toggle Music", function()
    fireRemote("ToggleMusic")
end, "Features")

makeSectionLabel("General Actions", "Teleports")
for _, data in ipairs(teleportLocations.quickActions) do
    local name, resolver = data[1], data[2]
    makeButton("Teleport: " .. name, function()
        local ok, target = pcall(resolver)
        if not ok then
            log("Teleport resolver error for " .. name)
            return
        end
        teleportTo(target)
    end, "Teleports")
end

makeSectionLabel("Auto Scrolls", "Teleports")
local scrollButtons = {}
for _, data in ipairs(teleportLocations.autoScrolls) do
    local name, resolver = data[1], data[2]
    scrollButtons[#scrollButtons + 1] = {
        name,
        function()
            local ok, target = pcall(resolver)
            if not ok then
                log("Teleport resolver error for " .. name)
                return
            end
            teleportTo(target)
        end,
    }
end
makeButtonGrid(scrollButtons, 2, "Teleports")

makeSectionLabel("Secret", "Teleports")
for _, data in ipairs(teleportLocations.secret) do
    local name, resolver = data[1], data[2]
    makeButton("Teleport: " .. name, function()
        local ok, target = pcall(resolver)
        if not ok then
            log("Teleport resolver error for " .. name)
            return
        end
        teleportTo(target)
    end, "Teleports")
end

makeSectionLabel("Raid Automation", "Auto Raid")

makeToggle("Auto Raid Master", false, function(state)
    autoRaidMasterEnabled = state
    if not state then
        raidStarted = false
        onGoingRaid = false
        raidTeleportedToLobby = false
        raidReturnTeleportResolver = nil
        raidReturnTeleportName = nil
        lastRaidPresenceScan = 0
    else
        lastRaidPresenceScan = 0
    end
    log("Auto Raid master " .. (state and "enabled" or "disabled"))
end, "Auto Raid")

makeInputToggleRow("Seek Enemies Scan /s", raidEnemyScanInterval, raidSeekEnabled, function(text)
    local value = tonumber(text) or raidEnemyScanInterval
    raidEnemyScanInterval = math.clamp(math.floor(value), 1, 10)
    return raidEnemyScanInterval
end, function(state)
    raidSeekEnabled = state
end, "Auto Raid")

makeToggle("Auto Skills", false, function(state)
    autoSkillsEnabled = state
end, "Auto Raid")

makeSkillToggleRow("Auto Raid")

task.spawn(function()
    while screen.Parent do
        if keyAccepted and autoRaidMasterEnabled then
            local raidTimerVisible = isRaidTimerVisible()
            if raidTimerVisible ~= nil then
                raidStarted = (raidTimerVisible == false)
                if raidTimerVisible then
                    onGoingRaid = false
                end
            end

            if raidStarted then
                if (os.clock() - lastRaidPresenceScan) >= raidPresenceScanInterval then
                    local enemiesAlive = getRaidEnemiesAlive()
                    onGoingRaid = enemiesAlive
                    lastRaidPresenceScan = os.clock()
                end

                if onGoingRaid then
                    ensureRaidSpellBarActive()
                end

                if onGoingRaid and not raidTeleportedToLobby then
                    local closestName, closestResolver = resolveClosestGeneralTeleport()
                    if closestResolver then
                        raidReturnTeleportResolver = closestResolver
                        raidReturnTeleportName = closestName
                    end

                    task.wait(2)
                    local ok, lobbyTarget = pcall(teleportLocations.quickActions[1][2])
                    if ok then
                        teleportTo(lobbyTarget)
                        raidTeleportedToLobby = true
                        log("Auto Raid: raid detected, teleported to Lobby")
                    end
                elseif (not onGoingRaid) and raidTeleportedToLobby and getRaidResultsVisible() then
                    task.wait(2)
                    if raidReturnTeleportResolver then
                        local ok, returnTarget = pcall(raidReturnTeleportResolver)
                        if ok and returnTarget then
                            teleportTo(returnTarget)
                            log("Auto Raid: returned to " .. tostring(raidReturnTeleportName or "closest location"))
                        end
                    end
                    raidReturnTeleportResolver = nil
                    raidReturnTeleportName = nil
                    raidTeleportedToLobby = false
                    raidStarted = false
                end
            end
        end

        task.wait(5)
    end
end)

task.spawn(function()
    while screen.Parent do
        if keyAccepted and autoRaidMasterEnabled and raidStarted and raidSeekEnabled then
            local enemiesAlive, firstEnemy = getRaidEnemiesAlive()
            onGoingRaid = enemiesAlive
            if enemiesAlive and firstEnemy then
                moveToRaidEnemy(firstEnemy)
            end
        end

        task.wait(math.max(raidEnemyScanInterval, 1))
    end
end)

task.spawn(function()
    while screen.Parent do
        if keyAccepted and autoRaidMasterEnabled and raidStarted and onGoingRaid and autoSkillsEnabled then
            if ensureRaidSpellBarActive() then
                local now = os.clock()
                if autoSkillBeam and (now - lastBeamCast) >= beamCooldown then
                    pressRaidSkill(Enum.KeyCode.E)
                    lastBeamCast = now
                end
                if autoSkillSlam and (now - lastSlamCast) >= slamCooldown then
                    pressRaidSkill(Enum.KeyCode.R)
                    lastSlamCast = now
                end
                if autoSkillNova and (now - lastNovaCast) >= novaCooldown then
                    pressRaidSkill(Enum.KeyCode.T)
                    lastNovaCast = now
                end
            end
        end

        task.wait(0.1)
    end
end)

task.spawn(function()
    while screen.Parent do
        if keyAccepted and autoRebirth then
            fireRemote("PerformRebirth")
        end
        task.wait(autoRebirthDelay)
    end
end)

task.spawn(function()
    while screen.Parent do
        if keyAccepted and antiAfkEnabled then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            log("Anti-AFK: sent virtual SPACE input")
        end
        task.wait(antiAfkInterval)
    end
end)

task.spawn(function()
    while screen.Parent do
        if keyAccepted and autoClickerEnabled then
            local mousePos = UserInputService:GetMouseLocation()
            VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 0)
            task.wait(1 / math.max(autoClickerCPS, 1))
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while screen.Parent do
        if keyAccepted and autoEnlightenment then
            fireRemote("PerformEnlightenment")
        end
        task.wait(autoEnlightenmentDelay)
    end
end)

task.spawn(function()
    while screen.Parent do
        if keyAccepted and autoTranscendence then
            fireRemote("PerformTranscendence")
        end
        task.wait(autoTranscendenceDelay)
    end
end)

quickKillButton.MouseButton1Click:Connect(function()
    screen:Destroy()
end)

log("Loaded. Unlock with key to begin.")
