--[[
    Meerly PU - Ascension Utility
    Built with the same UX style + keygate behavior as MeerlyPU.lua.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer

local hardcodedAccessKey = "ForLoveWithLove"
local keychainUrl = "https://work.ink/2kaV/meerlyunrng"

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
keyInput.ClearTextOnFocus = false
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
    page.ScrollBarThickness = 6
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

local tabNames = { "Features", "Teleports" }
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
local autoRaid = false
local autoRebirthDelay = 5
local autoEnlightenmentDelay = 5
local autoTranscendenceDelay = 5
local raidOriginalPosition = nil
local raidReturnPending = false
local raidConnection = nil

local originalHiddenStates = {}

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

end)

local function applyHideOnCharacter(character, hide)
    if not character then return end
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            if hide then
                if not originalHiddenStates[obj] then
                    originalHiddenStates[obj] = { transp = obj.LocalTransparencyModifier, coll = obj.CanCollide }
                end
                obj.LocalTransparencyModifier = 1
                obj.CanCollide = false
            else
                local state = originalHiddenStates[obj]
                if state then
                    obj.LocalTransparencyModifier = state.transp
                    obj.CanCollide = state.coll
                    originalHiddenStates[obj] = nil
                else
                    obj.LocalTransparencyModifier = 0
                end
            end
        elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("ParticleEmitter") then
            obj.Enabled = not hide
        end
    end
end

local function setHideOtherPlayers(state)
    hideOthersEnabled = state
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            applyHideOnCharacter(plr.Character, state)
        end
    end
    log(state and "Other players hidden" or "Other players restored")
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

local teleportLocations = {
    quickActions = {
        { "The Lobby", function() return workspace.SpawnLocation end },
        { "The Study", function() return workspace.Rooms.Room1:GetChildren()[4].RugMain end },
        { "The Archives", function() return workspace:GetChildren()[37]:GetChildren()[196] end },
        { "The Sanctum", function() return workspace.Rooms.Room3:GetChildren()[334] end },
        { "The Chamber", function() return workspace.Rooms.Room4:GetChildren()[120] end },
        { "The Observatory", function() return workspace.Rooms.Room5.FloorTile_40_5 end },
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

local function formatArgs(...)
    local args = { ... }
    if #args == 0 then
        return "(no args)"
    end

    local out = {}
    for i, arg in ipairs(args) do
        out[#out + 1] = string.format("arg%d=%s [%s]", i, tostring(arg), typeof(arg))
    end
    return table.concat(out, ", ")
end

local function findRaidState(...)
    local args = { ... }
    for _, arg in ipairs(args) do
        if typeof(arg) == "boolean" then
            return arg
        end
    end
    return nil
end

local function connectRaidRemote()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    local raidRemote = remotesFolder and remotesFolder:FindFirstChild("RaidStateChanged")

    if not raidRemote or not raidRemote:IsA("RemoteEvent") then
        log("Auto Raid: RaidStateChanged missing or not RemoteEvent")
        return
    end

    if raidConnection then
        raidConnection:Disconnect()
        raidConnection = nil
    end

    raidConnection = raidRemote.OnClientEvent:Connect(function(...)
        local state = findRaidState(...)
        log("RaidStateChanged received: " .. formatArgs(...))

        if state == nil then
            log("Auto Raid: no boolean state found in event args")
            return
        end

        if state then
            local character = localPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
                raidOriginalPosition = root.CFrame
                raidReturnPending = true
                local ok, lobbyTarget = pcall(teleportLocations.quickActions[1][2])
                if ok then
                    teleportTo(lobbyTarget)
                    log("Auto Raid: raid started, teleported to Lobby")
                else
                    log("Auto Raid: failed to resolve Lobby teleport")
                end
            else
                log("Auto Raid: no HumanoidRootPart to save return position")
            end
        elseif raidReturnPending and raidOriginalPosition then
            local character = localPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = raidOriginalPosition
                log("Auto Raid: raid ended, returned to original position")
            else
                log("Auto Raid: raid ended but no HumanoidRootPart found")
            end
            raidOriginalPosition = nil
            raidReturnPending = false
        end
    end)

    log("Auto Raid: listening to RaidStateChanged")
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

makeToggle("Auto Raid", false, function(state)
    autoRaid = state
    if state then
        connectRaidRemote()
    elseif raidConnection then
        raidConnection:Disconnect()
        raidConnection = nil
        raidOriginalPosition = nil
        raidReturnPending = false
        log("Auto Raid disabled")
    end
end, "Features")

makeInlineButtons({
    { "Rebirth", function() fireRemote("PerformRebirth") end },
    { "Enlighten", function() fireRemote("PerformEnlightenment") end },
    { "Transcend", function() fireRemote("PerformTranscendence") end },
}, "Features")

makeButton("Toggle Music", function()
    fireRemote("ToggleMusic")
end, "Features")

makeSectionLabel("Quick Actions", "Teleports")
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
