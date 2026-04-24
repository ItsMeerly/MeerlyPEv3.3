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
    },
    colors = {
        highlightColour = {r = 0, g = 255, b = 120},
        skeletonColour = {r = 255, g = 255, b = 255},
        wallcheckColour = {r = 255, g = 70, b = 70},
        traceLineColour = {r = 255, g = 255, b = 255},
        nameTagColour = {r = 80, g = 255, b = 120},
    },
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

local function rgbTableToColor3(rgb)
    if type(rgb) ~= "table" then
        return Color3.fromRGB(255, 255, 255)
    end
    return Color3.fromRGB(tonumber(rgb.r) or 255, tonumber(rgb.g) or 255, tonumber(rgb.b) or 255)
end

local function color3ToRgbTable(color)
    return {
        r = math.floor(math.clamp(color.R * 255, 0, 255) + 0.5),
        g = math.floor(math.clamp(color.G * 255, 0, 255) + 0.5),
        b = math.floor(math.clamp(color.B * 255, 0, 255) + 0.5),
    }
end

local function persistConfig()
    if config.saveConfiguration then
        saveTeleportConfig()
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

local function makeKillButton(parent)
    local killButton = makeButton("X", parent, UDim2.fromOffset(26, 22), UDim2.new(1, -34, 0, 8))
    killButton.BackgroundColor3 = THEME.danger
    killButton.Font = Enum.Font.GothamBold
    killButton.TextSize = 14
    killButton.ZIndex = 20
    return killButton
end

local closeButton = makeKillButton(root)

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

local function makeColorPicker(labelText, parent, order, configKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 38)
    row.Position = UDim2.fromOffset(4, (order - 1) * 42)
    row.BackgroundColor3 = THEME.panelAltBg
    row.BorderSizePixel = 0
    row.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromOffset(130, 38)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = THEME.textPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText
    label.Parent = row

    local function makeChannelBox(channel, offset)
        local box = Instance.new("TextBox")
        box.Size = UDim2.fromOffset(42, 24)
        box.Position = UDim2.new(0, offset, 0.5, -12)
        box.BackgroundColor3 = Color3.fromRGB(24, 26, 30)
        box.TextColor3 = THEME.textPrimary
        box.PlaceholderText = channel
        box.TextSize = 11
        box.Font = Enum.Font.Code
        box.ClearTextOnFocus = false
        box.Parent = row
        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 4)
        boxCorner.Parent = box
        return box
    end

    local rBox = makeChannelBox("R", 148)
    local gBox = makeChannelBox("G", 194)
    local bBox = makeChannelBox("B", 240)

    local preview = Instance.new("Frame")
    preview.Size = UDim2.fromOffset(26, 24)
    preview.Position = UDim2.new(1, -36, 0.5, -12)
    preview.BorderSizePixel = 0
    preview.Parent = row
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 4)
    previewCorner.Parent = preview

    local function applyBoxes()
        local parsed = {
            r = math.clamp(tonumber(rBox.Text) or 255, 0, 255),
            g = math.clamp(tonumber(gBox.Text) or 255, 0, 255),
            b = math.clamp(tonumber(bBox.Text) or 255, 0, 255),
        }
        config.colors[configKey] = parsed
        preview.BackgroundColor3 = rgbTableToColor3(parsed)
        persistConfig()
    end

    local function syncBoxes()
        local existing = config.colors[configKey] or {r = 255, g = 255, b = 255}
        rBox.Text = tostring(existing.r or 255)
        gBox.Text = tostring(existing.g or 255)
        bBox.Text = tostring(existing.b or 255)
        preview.BackgroundColor3 = rgbTableToColor3(existing)
    end

    for _, box in ipairs({rBox, gBox, bBox}) do
        box.FocusLost:Connect(function()
            applyBoxes()
            syncBoxes()
        end)
    end

    syncBoxes()
end

local loginOverlay = Instance.new("Frame")
loginOverlay.Size = UDim2.fromScale(1, 1)
loginOverlay.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
loginOverlay.BorderSizePixel = 0
loginOverlay.Parent = root

local splashKillButton = makeKillButton(loginOverlay)

local splashKillButton = makeButton("X", loginOverlay, UDim2.fromOffset(26, 22), UDim2.new(1, -34, 0, 8))
splashKillButton.BackgroundColor3 = THEME.danger
splashKillButton.Font = Enum.Font.GothamBold
splashKillButton.TextSize = 14


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
        persistConfig()
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
    persistConfig()
end)

saveConfigBtn.MouseButton1Click:Connect(function()
    config.saveConfiguration = not config.saveConfiguration
    setToggleVisual(saveConfigBtn, config.saveConfiguration)
    persistConfig()
end)

makeColorPicker("Highlight Colour", customPage, 3, "highlightColour")
makeColorPicker("Skeleton Colour", customPage, 4, "skeletonColour")
makeColorPicker("Wallcheck Colour", customPage, 5, "wallcheckColour")
makeColorPicker("Trace Line Colour", customPage, 6, "traceLineColour")

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

local function getTargetVisibility(targetCharacter)
    local camera = workspace.CurrentCamera
    if not camera or not targetCharacter then
        return false
    end

    local localCharacter = localPlayer.Character
    local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        return false
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {localCharacter, targetCharacter}
    local direction = targetRoot.Position - camera.CFrame.Position
    local hit = workspace:Raycast(camera.CFrame.Position, direction, params)
    return not hit
end

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

    local visibleColour = rgbTableToColor3(config.colors.highlightColour)
    local occludedColour = rgbTableToColor3(config.colors.wallcheckColour)
    local resolved = visibleColour
    if config.visual.wallcheckColour and not getTargetVisibility(character) then
        resolved = occludedColour
    end
    highlight.FillColor = resolved
    highlight.OutlineColor = resolved
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
        label.TextColor3 = rgbTableToColor3(config.colors.nameTagColour or config.colors.highlightColour)
        label.TextStrokeTransparency = 0.35
        label.TextSize = 14
        label.Text = targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")"
        label.Parent = billboard

        visuals.nameTags[targetPlayer] = billboard
    else
        local label = billboard:FindFirstChildOfClass("TextLabel")
        if label then
            local visibleColour = rgbTableToColor3(config.colors.nameTagColour or config.colors.highlightColour)
            local occludedColour = rgbTableToColor3(config.colors.wallcheckColour)
            local resolved = visibleColour
            if config.visual.wallcheckColour and not getTargetVisibility(character) then
                resolved = occludedColour
            end
            label.TextColor3 = resolved
        end
    end
end

local function ensureSkeleton(targetPlayer)
    local character = targetPlayer.Character
    if not character then return end

    if not visuals.skeletons[targetPlayer] then
        visuals.skeletons[targetPlayer] = {}
    end

    local rig = character:FindFirstChildOfClass("Humanoid")
    local isR15 = rig and rig.RigType == Enum.HumanoidRigType.R15
    local pairs = isR15 and {
        {"Head", "UpperTorso"},
        {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
    } or {
        {"Head", "Torso"},
        {"Torso", "Left Arm"}, {"Left Arm", "Left Leg"},
        {"Torso", "Right Arm"}, {"Right Arm", "Right Leg"},
        {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
    }

    for _, link in ipairs(pairs) do
        local part0 = character:FindFirstChild(link[1])
        local part1 = character:FindFirstChild(link[2])
        if part0 and part1 and part0:IsA("BasePart") and part1:IsA("BasePart") then
            local key = link[1] .. "_" .. link[2]
            local beamObj = visuals.skeletons[targetPlayer][key]
            if not beamObj then
                local a0 = Instance.new("Attachment")
                a0.Parent = part0
                local a1 = Instance.new("Attachment")
                a1.Parent = part1
                local beam = Instance.new("Beam")
                beam.Attachment0 = a0
                beam.Attachment1 = a1
                beam.FaceCamera = true
                beam.Width0 = 0.05
                beam.Width1 = 0.05
                beam.LightEmission = 1
                beam.Transparency = NumberSequence.new(0)
                beam.Parent = part0
                beamObj = {a0 = a0, a1 = a1, beam = beam}
                visuals.skeletons[targetPlayer][key] = beamObj
            end

            local visibleColour = rgbTableToColor3(config.colors.skeletonColour)
            local occludedColour = rgbTableToColor3(config.colors.wallcheckColour)
            local resolved = visibleColour
            if config.visual.wallcheckColour and not getTargetVisibility(character) then
                resolved = occludedColour
            end
            beamObj.beam.Color = ColorSequence.new(resolved)
        end
    end
end

local function ensureTracer(targetPlayer)
    local character = targetPlayer.Character
    local localCharacter = localPlayer.Character
    if not character or not localCharacter then return end

    local targetRoot = character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local tracer = visuals.tracers[targetPlayer]
    if not tracer then
        local part = Instance.new("Part")
        part.Name = "MeerlyOP1_TracerPart"
        part.Size = Vector3.new(0.2, 0.2, 0.2)
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = false
        part.Parent = workspace

        part.CFrame = CFrame.new()

        local a0 = Instance.new("Attachment")
        a0.Name = "A0"
        a0.Parent = part

        local a1 = Instance.new("Attachment")
        a1.Name = "A1"
        a1.Parent = part

        local beam = Instance.new("Beam")
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Width0 = 0.08
        beam.Width1 = 0.08
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        beam.FaceCamera = true
        beam.Parent = part

        tracer = {holder = part, a0 = a0, a1 = a1, beam = beam}
        visuals.tracers[targetPlayer] = tracer
    end

    local camera = workspace.CurrentCamera
    if not camera then return end

    tracer.a0.Position = camera.CFrame.Position
    tracer.a1.Position = targetRoot.Position
    local visibleColour = rgbTableToColor3(config.colors.traceLineColour)
    local occludedColour = rgbTableToColor3(config.colors.wallcheckColour)
    local resolved = visibleColour
    if config.visual.wallcheckColour and not getTargetVisibility(character) then
        resolved = occludedColour
    end
    tracer.beam.Color = ColorSequence.new(resolved)
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

local function killScript()
    if isScriptKilled then
        return
    end

    isScriptKilled = true
    clearFeature("highlights")
    clearFeature("nameTags")
    clearFeature("skeletons")
    clearFeature("tracers")
    screenGui:Destroy()
end

closeButton.MouseButton1Click:Connect(function()
    killScript()
end)

splashKillButton.MouseButton1Click:Connect(function()
    killScript()
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
