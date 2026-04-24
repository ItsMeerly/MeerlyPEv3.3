--[[
    MeerlyOP1 - Magick Online Admin Visual Tool
    Client-side LocalScript for Roblox.

    NOTE:
    - This uses a hardcoded password hash gate for quick admin access control.
    - Client-side hardcoded keys can be reverse engineered; for production security,
      validate permissions on the server as well.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

--////////////// Hardcoded password gate //////////////
local function simpleHash(input)
    local hash = 5381
    for i = 1, #input do
        hash = ((hash * 33) + string.byte(input, i)) % 2147483647
    end
    return tostring(hash)
end

-- Change this to your chosen password, then copy hash output and replace below.
local HARDCODED_PASSWORD_HASH = "1185274955" -- simpleHash("MeerlyMagickAdmin")

--////////////// Cross-instance settings //////////////
local TELEPORT_KEY = "MeerlyOP1_Config"

local defaultConfig = {
    autoInject = false,
    saveConfiguration = true,
    visual = {
        highlightPlayers = false,
        viewPlayerNames = false,
        playerSkeletons = false,
        wallcheckColour = false,
        teamcheck = false,
        traceLines = false,
    }
}

local config = table.clone(defaultConfig)

local function deepCopy(source)
    local output = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            output[key] = deepCopy(value)
        else
            output[key] = value
        end
    end
    return output
end

local function loadTeleportConfig()
    local data = TeleportService:GetTeleportSetting(TELEPORT_KEY)
    if type(data) == "table" then
        config = deepCopy(defaultConfig)
        for key, value in pairs(data) do
            if type(value) == "table" and type(config[key]) == "table" then
                for subKey, subValue in pairs(value) do
                    config[key][subKey] = subValue
                end
            else
                config[key] = value
            end
        end
    end
end

local function saveTeleportConfig()
    if config.saveConfiguration then
        TeleportService:SetTeleportSetting(TELEPORT_KEY, config)
    end
end

loadTeleportConfig()

--////////////// UI //////////////
local THEME = {
    windowBg = Color3.fromRGB(20, 22, 25),
    panelBg = Color3.fromRGB(25, 27, 31),
    panelAltBg = Color3.fromRGB(32, 35, 40),
    textPrimary = Color3.fromRGB(232, 234, 237),
    textMuted = Color3.fromRGB(170, 174, 181),
    accent = Color3.fromRGB(0, 168, 255),
    accentActive = Color3.fromRGB(0, 196, 120),
    danger = Color3.fromRGB(175, 70, 70),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MeerlyOP1"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(480, 345)
root.Position = UDim2.fromScale(0.5, 0.5)
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.BackgroundColor3 = THEME.windowBg
root.BorderSizePixel = 0
root.Visible = true
root.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 4)
uiCorner.Parent = root

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 30)
title.Position = UDim2.fromOffset(8, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = THEME.textPrimary
title.Text = "[ MeerlyOP1 ]  Magick Online Admin"
title.Parent = root

local keybindHint = Instance.new("TextLabel")
keybindHint.Size = UDim2.fromOffset(120, 18)
keybindHint.Position = UDim2.new(1, -160, 0, 10)
keybindHint.BackgroundTransparency = 1
keybindHint.Font = Enum.Font.Gotham
keybindHint.TextSize = 11
keybindHint.TextXAlignment = Enum.TextXAlignment.Right
keybindHint.TextColor3 = THEME.textMuted
keybindHint.Text = "Toggle: ;"
keybindHint.Parent = root

local tabRow = Instance.new("Frame")
tabRow.Size = UDim2.new(1, -16, 0, 32)
tabRow.Position = UDim2.fromOffset(8, 36)
tabRow.BackgroundTransparency = 1
tabRow.Parent = root

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -16, 1, -76)
body.Position = UDim2.fromOffset(8, 68)
body.BackgroundColor3 = THEME.panelBg
body.BorderSizePixel = 0
body.Parent = root

local bodyCorner = Instance.new("UICorner")
bodyCorner.CornerRadius = UDim.new(0, 4)
bodyCorner.Parent = body

local bodyStroke = Instance.new("UIStroke")
bodyStroke.Color = Color3.fromRGB(45, 49, 56)
bodyStroke.Thickness = 1
bodyStroke.Parent = body

local function makeButton(text, parent, size, pos)
    local button = Instance.new("TextButton")
    button.Size = size or UDim2.fromOffset(150, 28)
    button.Position = pos or UDim2.fromOffset(0, 0)
    button.BackgroundColor3 = THEME.panelAltBg
    button.TextColor3 = THEME.textPrimary
    button.Font = Enum.Font.Gotham
    button.TextSize = 13
    button.Text = text
    button.AutoButtonColor = true
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(56, 61, 69)
    stroke.Thickness = 1
    stroke.Parent = button

    return button
end

local closeButton = makeButton("X", root, UDim2.fromOffset(26, 22), UDim2.new(1, -34, 0, 8))
closeButton.BackgroundColor3 = THEME.danger
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14

local function makeToggle(labelText, parent, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 34)
    row.Position = UDim2.fromOffset(4, (order - 1) * 38)
    row.BackgroundColor3 = THEME.panelAltBg
    row.BorderSizePixel = 0
    row.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -120, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = THEME.textPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText
    label.Parent = row

    local toggle = makeButton("OFF", row, UDim2.fromOffset(90, 24), UDim2.new(1, -100, 0.5, -12))
    toggle.BackgroundColor3 = THEME.danger

    return row, toggle
end

local loginOverlay = Instance.new("Frame")
loginOverlay.Size = UDim2.fromScale(1, 1)
loginOverlay.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
loginOverlay.BorderSizePixel = 0
loginOverlay.Parent = root

local loginTitle = Instance.new("TextLabel")
loginTitle.Size = UDim2.new(1, 0, 0, 26)
loginTitle.Position = UDim2.new(0, 0, 0, 20)
loginTitle.BackgroundTransparency = 1
loginTitle.Font = Enum.Font.GothamBold
loginTitle.TextSize = 18
loginTitle.Text = "Admin Key Required"
loginTitle.TextColor3 = THEME.textPrimary
loginTitle.Parent = loginOverlay

local keyBox = Instance.new("TextBox")
keyBox.Size = UDim2.new(0, 280, 0, 34)
keyBox.Position = UDim2.new(0.5, -140, 0.5, -18)
keyBox.BackgroundColor3 = THEME.panelAltBg
keyBox.Font = Enum.Font.Code
keyBox.TextSize = 14
keyBox.PlaceholderText = "Enter hardcoded key"
keyBox.Text = ""
keyBox.TextColor3 = THEME.textPrimary
keyBox.ClearTextOnFocus = false
keyBox.Parent = loginOverlay

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 4)
keyCorner.Parent = keyBox

local submit = makeButton("Unlock", loginOverlay, UDim2.fromOffset(100, 30), UDim2.new(0.5, -50, 0.5, 26))
local loginStatus = Instance.new("TextLabel")
loginStatus.Size = UDim2.new(1, 0, 0, 20)
loginStatus.Position = UDim2.new(0, 0, 0.5, 62)
loginStatus.BackgroundTransparency = 1
loginStatus.Font = Enum.Font.Gotham
loginStatus.TextSize = 12
loginStatus.TextColor3 = Color3.fromRGB(255, 130, 130)
loginStatus.Text = ""
loginStatus.Parent = loginOverlay

local visualTabBtn = makeButton("Visual", tabRow, UDim2.fromOffset(120, 28), UDim2.fromOffset(0, 0))
local customTabBtn = makeButton("Customisation", tabRow, UDim2.fromOffset(120, 28), UDim2.fromOffset(126, 0))

local visualPage = Instance.new("Frame")
visualPage.Size = UDim2.fromScale(1, 1)
visualPage.BackgroundTransparency = 1
visualPage.Parent = body

local customPage = Instance.new("Frame")
customPage.Size = UDim2.fromScale(1, 1)
customPage.BackgroundTransparency = 1
customPage.Visible = false
customPage.Parent = body

local function setTabActive(button, active)
    button.BackgroundColor3 = active and THEME.accent or THEME.panelAltBg
end

local toggles = {}
local function setToggleVisual(btn, state)
    btn.Text = state and "ON" or "OFF"
    btn.BackgroundColor3 = state and THEME.accentActive or THEME.danger
end

local function makeVisualToggle(configKey, text, order)
    local _, button = makeToggle(text, visualPage, order)
    toggles[configKey] = button
    setToggleVisual(button, config.visual[configKey])
    button.MouseButton1Click:Connect(function()
        config.visual[configKey] = not config.visual[configKey]
        setToggleVisual(button, config.visual[configKey])
    end)
end

makeVisualToggle("highlightPlayers", "Highlight Players", 1)
makeVisualToggle("viewPlayerNames", "View Player Names", 2)
makeVisualToggle("playerSkeletons", "Player Skeletons", 3)
makeVisualToggle("wallcheckColour", "Wallcheck Colour", 4)
makeVisualToggle("teamcheck", "Teamcheck", 5)
makeVisualToggle("traceLines", "Trace Lines", 6)

local _, autoInjectBtn = makeToggle("Auto-Inject", customPage, 1)
local _, saveConfigBtn = makeToggle("Save Configuration", customPage, 2)

setToggleVisual(autoInjectBtn, config.autoInject)
setToggleVisual(saveConfigBtn, config.saveConfiguration)
setTabActive(visualTabBtn, true)
setTabActive(customTabBtn, false)

autoInjectBtn.MouseButton1Click:Connect(function()
    config.autoInject = not config.autoInject
    setToggleVisual(autoInjectBtn, config.autoInject)
    saveTeleportConfig()
end)

saveConfigBtn.MouseButton1Click:Connect(function()
    config.saveConfiguration = not config.saveConfiguration
    setToggleVisual(saveConfigBtn, config.saveConfiguration)
    saveTeleportConfig()
end)

visualTabBtn.MouseButton1Click:Connect(function()
    visualPage.Visible = true
    customPage.Visible = false
    setTabActive(visualTabBtn, true)
    setTabActive(customTabBtn, false)
end)

customTabBtn.MouseButton1Click:Connect(function()
    visualPage.Visible = false
    customPage.Visible = true
    setTabActive(visualTabBtn, false)
    setTabActive(customTabBtn, true)
end)

--////////////// Visual feature internals //////////////
local visuals = {
    highlights = {},
    nameTags = {},
    skeletons = {},
    tracers = {},
}

local function getCharacterParts(character)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    return humanoidRootPart, head
end

local function clearMap(mapTable)
    for _, object in pairs(mapTable) do
        if typeof(object) == "Instance" and object.Parent then
            object:Destroy()
        elseif type(object) == "table" then
            for _, child in pairs(object) do
                if typeof(child) == "Instance" and child.Parent then
                    child:Destroy()
                end
            end
        end
    end
    table.clear(mapTable)
end

local function ensureHighlight(targetPlayer)
    local character = targetPlayer.Character
    if not character then return end

    local highlight = visuals.highlights[targetPlayer]
    if not highlight or highlight.Parent ~= character then
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
        highlight = Instance.new("Highlight")
        highlight.Name = "MeerlyOP1_Highlight"
        highlight.FillTransparency = 0.65
        highlight.OutlineTransparency = 0
        highlight.Parent = character
        visuals.highlights[targetPlayer] = highlight
    end

    if config.visual.wallcheckColour then
        local localCharacter = localPlayer.Character
        local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
        local targetRoot = character:FindFirstChild("HumanoidRootPart")
        if localRoot and targetRoot then
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {localCharacter, character}
            local direction = (targetRoot.Position - localRoot.Position)
            local hit = workspace:Raycast(localRoot.Position, direction, params)
            local visible = not hit
            highlight.FillColor = visible and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 75, 75)
            highlight.OutlineColor = visible and Color3.fromRGB(170, 255, 170) or Color3.fromRGB(255, 170, 170)
        end
    else
        highlight.FillColor = Color3.fromRGB(255, 200, 45)
        highlight.OutlineColor = Color3.fromRGB(255, 240, 190)
    end
end

local function ensureNameTag(targetPlayer)
    local character = targetPlayer.Character
    if not character then return end
    local _, head = getCharacterParts(character)
    if not head then return end

    local billboard = visuals.nameTags[targetPlayer]
    if not billboard or billboard.Parent ~= head then
        if billboard and billboard.Parent then
            billboard:Destroy()
        end

        billboard = Instance.new("BillboardGui")
        billboard.Name = "MeerlyOP1_NameTag"
        billboard.Size = UDim2.fromOffset(200, 30)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = head

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.35
        label.TextSize = 14
        label.Text = targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")"
        label.Parent = billboard

        visuals.nameTags[targetPlayer] = billboard
    end
end

local function ensureSkeleton(targetPlayer)
    local character = targetPlayer.Character
    if not character then return end

    if not visuals.skeletons[targetPlayer] then
        visuals.skeletons[targetPlayer] = {}
    end

    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local adornName = "MeerlyOP1_Skeleton_" .. part.Name
            local adorn = part:FindFirstChild(adornName)
            if not adorn then
                adorn = Instance.new("BoxHandleAdornment")
                adorn.Name = adornName
                adorn.Adornee = part
                adorn.AlwaysOnTop = true
                adorn.ZIndex = 5
                adorn.Size = part.Size + Vector3.new(0.04, 0.04, 0.04)
                adorn.Transparency = 0.75
                adorn.Color3 = Color3.fromRGB(130, 220, 255)
                adorn.Parent = part
            end
            visuals.skeletons[targetPlayer][part] = adorn
        end
    end
end

local function ensureTracer(targetPlayer)
    local character = targetPlayer.Character
    local localCharacter = localPlayer.Character
    if not character or not localCharacter then return end

    local targetRoot = character:FindFirstChild("HumanoidRootPart")
    local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not localRoot then return end

    local tracer = visuals.tracers[targetPlayer]
    if not tracer then
        local part = Instance.new("Part")
        part.Name = "MeerlyOP1_TracerPart"
        part.Size = Vector3.new(0.2, 0.2, 0.2)
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = false
        part.Parent = workspace

        local a0 = Instance.new("Attachment")
        a0.Name = "A0"
        a0.Parent = localRoot

        local a1 = Instance.new("Attachment")
        a1.Name = "A1"
        a1.Parent = targetRoot

        local beam = Instance.new("Beam")
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Width0 = 0.08
        beam.Width1 = 0.08
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 220, 120))
        beam.FaceCamera = true
        beam.Parent = part

        tracer = {holder = part, a0 = a0, a1 = a1, beam = beam}
        visuals.tracers[targetPlayer] = tracer
    else
        if tracer.a0.Parent ~= localRoot then tracer.a0.Parent = localRoot end
        if tracer.a1.Parent ~= targetRoot then tracer.a1.Parent = targetRoot end
    end
end

local function clearFeature(feature)
    clearMap(visuals[feature])
end

local function clearPlayerVisuals(targetPlayer)
    if visuals.highlights[targetPlayer] then
        visuals.highlights[targetPlayer]:Destroy()
        visuals.highlights[targetPlayer] = nil
    end
    if visuals.nameTags[targetPlayer] then
        visuals.nameTags[targetPlayer]:Destroy()
        visuals.nameTags[targetPlayer] = nil
    end
    if visuals.skeletons[targetPlayer] then
        clearMap(visuals.skeletons[targetPlayer])
        visuals.skeletons[targetPlayer] = nil
    end
    if visuals.tracers[targetPlayer] then
        clearMap(visuals.tracers[targetPlayer])
        visuals.tracers[targetPlayer] = nil
    end
end

local function shouldTrackTarget(targetPlayer)
    if targetPlayer == localPlayer then
        return false
    end

    if config.visual.teamcheck then
        local localTeam = localPlayer.Team
        local targetTeam = targetPlayer.Team
        if localTeam and targetTeam and localTeam == targetTeam then
            return false
        end
    end

    return true
end

local isMenuVisible = true
local isScriptKilled = false

local function setMenuVisible(visible)
    isMenuVisible = visible
    root.Visible = visible
end

closeButton.MouseButton1Click:Connect(function()
    isScriptKilled = true
    clearFeature("highlights")
    clearFeature("nameTags")
    clearFeature("skeletons")
    clearFeature("tracers")
    screenGui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isScriptKilled then
        return
    end

    if input.KeyCode == Enum.KeyCode.Semicolon then
        setMenuVisible(not isMenuVisible)
    end
end)

RunService.RenderStepped:Connect(function()
    if isScriptKilled then
        return
    end

    if not loginOverlay.Visible then
        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            if shouldTrackTarget(targetPlayer) then
                if config.visual.highlightPlayers then
                    ensureHighlight(targetPlayer)
                elseif visuals.highlights[targetPlayer] then
                    visuals.highlights[targetPlayer]:Destroy()
                    visuals.highlights[targetPlayer] = nil
                end

                if config.visual.viewPlayerNames then
                    ensureNameTag(targetPlayer)
                elseif visuals.nameTags[targetPlayer] then
                    visuals.nameTags[targetPlayer]:Destroy()
                    visuals.nameTags[targetPlayer] = nil
                end

                if config.visual.playerSkeletons then
                    ensureSkeleton(targetPlayer)
                elseif visuals.skeletons[targetPlayer] then
                    clearMap(visuals.skeletons[targetPlayer])
                    visuals.skeletons[targetPlayer] = nil
                end

                if config.visual.traceLines then
                    ensureTracer(targetPlayer)
                elseif visuals.tracers[targetPlayer] then
                    clearMap(visuals.tracers[targetPlayer])
                    visuals.tracers[targetPlayer] = nil
                end
            else
                clearPlayerVisuals(targetPlayer)
            end
        end
    else
        clearFeature("highlights")
        clearFeature("nameTags")
        clearFeature("skeletons")
        clearFeature("tracers")
    end
end)

Players.PlayerRemoving:Connect(function(player)
    clearPlayerVisuals(player)
end)

--////////////// Login behavior //////////////
local function unlockWithKey(candidate)
    return simpleHash(candidate) == HARDCODED_PASSWORD_HASH
end

local function tryUnlock()
    local entered = keyBox.Text or ""
    if unlockWithKey(entered) then
        loginStatus.TextColor3 = Color3.fromRGB(120, 255, 120)
        loginStatus.Text = "Unlocked"
        task.wait(0.15)
        loginOverlay.Visible = false

        -- persist key only when Save Configuration is enabled, enabling seamless teleports
        if config.saveConfiguration then
            config._cachedKey = entered
            saveTeleportConfig()
        end
    else
        loginStatus.TextColor3 = Color3.fromRGB(255, 120, 120)
        loginStatus.Text = "Invalid key"
    end
end

submit.MouseButton1Click:Connect(tryUnlock)
keyBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        tryUnlock()
    end
end)

-- Auto-inject with prefilled key if it was saved from previous instance
if config.autoInject and config._cachedKey then
    keyBox.Text = config._cachedKey
    if unlockWithKey(config._cachedKey) then
        loginOverlay.Visible = false
    end
end

-- Keep teleport settings refreshed while enabled
RunService.Heartbeat:Connect(function()
    if isScriptKilled then
        return
    end

    if config.autoInject and config.saveConfiguration then
        saveTeleportConfig()
    end
end)
