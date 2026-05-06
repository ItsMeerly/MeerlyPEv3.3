local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local config = {
    visuals = {
        employees = true,
        food = true,
        heals = false,
        guns = false,
        fov = 500,
    },
    actions = {
        aimbot = true,
        walkSpeedEnabled = false,
        walkSpeedValue = 22,
    },
}

local keywords = {
    food = {"cola", "burger", "hotdog", "donut", "food", "water", "pizza", "apple", "taco", "bloxy", "drink", "eat", "canned"},
    heals = {"medkit", "bandage", "heal", "aid", "pills", "health", "cure"},
    guns = {"gun", "ammo", "shotgun", "glock", "rifle", "mag", "pistol", "uzi", "bullet", "weapon", "armory", "firearm"},
}

local keywordEnabled = { food = {}, heals = {}, guns = {} }
for cat, words in pairs(keywords) do
    for _, word in ipairs(words) do
        keywordEnabled[cat][word] = true
    end
end

local scanInterval = 1.5
local visualUpdateInterval = 0.25
local aimScanInterval = 0.05
local maxVisualDistance = 900
local maxVisualsPerTick = 80
local itemScanAccumulator = 0
local visualUpdateAccumulator = 0
local aimScanAccumulator = 0
local itemEntries = {}
local enemyEntries = {}
local activeVisualParts = {}
local closestAimTarget = nil
local textCache = {}
local highlightCache = {}
local tpSlots = {}
local gui

local function clearTable(tbl)
    if table.clear then
        table.clear(tbl)
    else
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getHRP(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function removeVisualForPart(part)
    local text = textCache[part]
    if text then
        if text.gui then
            text.gui:Destroy()
        elseif text.Destroy then
            text:Destroy()
        elseif text.Remove then
            text:Remove()
        end
        textCache[part] = nil
        activeVisualParts[part] = nil
    end
    local h = highlightCache[part]
    if h then
        h:Destroy()
        highlightCache[part] = nil
        activeVisualParts[part] = nil
    end
end

local function clearAllVisuals()
    for part in pairs(textCache) do
        removeVisualForPart(part)
    end
    clearTable(activeVisualParts)
end

local function hideUnusedVisuals(seenParts)
    for part in pairs(activeVisualParts) do
        if not seenParts[part] then
            removeVisualForPart(part)
            activeVisualParts[part] = nil
        end
    end
end

local function cleanDeadCache()
    for part in pairs(textCache) do
        if not part.Parent or not part:IsDescendantOf(workspace) then
            removeVisualForPart(part)
        end
    end
end

local function checkCategory(name, category)
    local lowered = string.lower(name)
    for _, word in ipairs(keywords[category]) do
        if keywordEnabled[category][word] and string.find(lowered, word, 1, true) then
            return true
        end
    end
    return false
end

local function isVisible(targetPart)
    local char = player.Character
    rayParams.FilterDescendantsInstances = {char, targetPart.Parent}
    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    local result = workspace:Raycast(origin, direction, rayParams)
    return result == nil
end

local function ensureVisual(part, color, label)
    local text = textCache[part]
    if not text then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "CommanderESPLabel"
        billboard.Adornee = part
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.MaxDistance = maxVisualDistance
        billboard.Size = UDim2.fromOffset(160, 34)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.Parent = gui

        local labelText = Instance.new("TextLabel")
        labelText.BackgroundTransparency = 1
        labelText.Size = UDim2.fromScale(1, 1)
        labelText.Font = Enum.Font.GothamBold
        labelText.TextSize = 14
        labelText.TextStrokeTransparency = 0.25
        labelText.TextWrapped = true
        labelText.Parent = billboard

        text = { gui = billboard, label = labelText }
        textCache[part] = text
    end

    local hrp = getHRP(player.Character)
    if not hrp then
        text.gui.Enabled = false
        return
    end

    local offset = hrp.Position - part.Position
    local dist = offset.Magnitude
    text.gui.Enabled = true
    text.gui.Adornee = part
    text.gui.MaxDistance = maxVisualDistance
    text.label.Text = string.format("%s [%dm]", label, math.floor(dist + 0.5))
    text.label.TextColor3 = color

    local h = highlightCache[part]
    if not h then
        local target = part.Parent and (part.Parent:IsA("Model") and part.Parent or part)
        h = Instance.new("Highlight")
        h.Name = "CommanderESP"
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.8
        h.OutlineTransparency = 0.2
        h.Parent = target
        highlightCache[part] = h
    end
    h.FillColor = color
    h.OutlineColor = color
end

local function refreshEnemyList()
    clearTable(enemyEntries)
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return end
    for _, enemy in ipairs(enemies:GetChildren()) do
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        if hrp then
            enemyEntries[#enemyEntries + 1] = hrp
        end
    end
end

local function refreshItemList()
    clearTable(itemEntries)
    local util = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Util")
    local items = util and util:FindFirstChild("Items")
    if not items then return end
    for _, folder in ipairs(items:GetChildren()) do
        local part = folder:FindFirstChildWhichIsA("BasePart", true)
        if part then
            itemEntries[#itemEntries + 1] = { folder = folder, part = part, lowerName = string.lower(folder.Name) }
        end
    end
end

local theme = {
    bg = Color3.fromRGB(20, 22, 25), panel = Color3.fromRGB(28, 30, 34), alt = Color3.fromRGB(36, 38, 43),
    text = Color3.fromRGB(236, 236, 236), muted = Color3.fromRGB(170, 174, 181), accent = Color3.fromRGB(0, 168, 255), danger = Color3.fromRGB(180, 70, 70),
}

gui = Instance.new("ScreenGui")
gui.Name = "MeerlyON"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(520, 380)
root.Position = UDim2.fromScale(0.5, 0.5)
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.BackgroundColor3 = theme.bg
root.Parent = gui
root.Active = true
root.Draggable = true
Instance.new("UICorner", root)

local title = Instance.new("TextLabel", root)
title.Size = UDim2.new(1, -90, 0, 28)
title.Position = UDim2.fromOffset(10, 6)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = theme.text
title.Text = "[ MeerlyON ]"

local hint = Instance.new("TextLabel", root)
hint.Size = UDim2.fromOffset(90, 16)
hint.Position = UDim2.new(1, -100, 0, 11)
hint.BackgroundTransparency = 1
hint.Text = "Toggle: ;"
hint.Font = Enum.Font.Gotham
hint.TextColor3 = theme.muted
hint.TextSize = 11

local kill = Instance.new("TextButton", root)
kill.Size = UDim2.fromOffset(24, 22)
kill.Position = UDim2.new(1, -32, 0, 6)
kill.Text = "X"
kill.Font = Enum.Font.GothamBold
kill.TextSize = 13
kill.TextColor3 = theme.text
kill.BackgroundColor3 = theme.danger
Instance.new("UICorner", kill)

local tabRow = Instance.new("Frame", root)
tabRow.Size = UDim2.new(1, -16, 0, 30)
tabRow.Position = UDim2.fromOffset(8, 38)
tabRow.BackgroundTransparency = 1

local content = Instance.new("Frame", root)
content.Size = UDim2.new(1, -16, 1, -76)
content.Position = UDim2.fromOffset(8, 70)
content.BackgroundColor3 = theme.panel
Instance.new("UICorner", content)

local pages = {}
local tabButtons = {}
local function newPage(name, index)
    local b = Instance.new("TextButton", tabRow)
    b.Size = UDim2.fromOffset(120, 26)
    b.Position = UDim2.fromOffset((index - 1) * 126, 2)
    b.BackgroundColor3 = theme.alt
    b.TextColor3 = theme.text
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.Text = name
    Instance.new("UICorner", b)

    local p = Instance.new("ScrollingFrame", content)
    p.Size = UDim2.new(1, -8, 1, -8)
    p.Position = UDim2.fromOffset(4, 4)
    p.BackgroundTransparency = 1
    p.ScrollBarThickness = 5
    p.CanvasSize = UDim2.fromOffset(0, 0)
    p.Visible = false

    pages[name] = p
    tabButtons[name] = b
    return p
end

local function updatePageCanvas(page)
    local bottom = 0
    for _, child in ipairs(page:GetChildren()) do
        if child:IsA("GuiObject") then
            bottom = math.max(bottom, child.Position.Y.Offset + child.Size.Y.Offset)
        end
    end
    page.CanvasSize = UDim2.fromOffset(0, bottom + 12)
end

local function makeButton(parent, text, pos, size)
    local btn = Instance.new("TextButton", parent)
    btn.Size = size or UDim2.fromOffset(140, 28)
    btn.Position = pos
    btn.BackgroundColor3 = theme.alt
    btn.TextColor3 = theme.text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Text = text
    Instance.new("UICorner", btn)
    return btn
end

local function makeToggle(parent, y, label, init, onChange)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -8, 0, 32)
    row.Position = UDim2.fromOffset(4, y)
    row.BackgroundColor3 = theme.alt
    Instance.new("UICorner", row)

    local txt = Instance.new("TextLabel", row)
    txt.Size = UDim2.new(1, -110, 1, 0)
    txt.Position = UDim2.fromOffset(10, 0)
    txt.BackgroundTransparency = 1
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextColor3 = theme.text
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 12
    txt.Text = label

    local state = init
    local btn = makeButton(row, state and "ON" or "OFF", UDim2.new(1, -95, 0.5, -11), UDim2.fromOffset(86, 22))
    local function repaint()
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and theme.accent or theme.danger
    end
    repaint()

    btn.MouseButton1Click:Connect(function()
        state = not state
        repaint()
        onChange(state)
    end)
    return row
end

local visualsPage = newPage("Visuals", 1)
local actionsPage = newPage("Actions", 2)
local teleportsPage = newPage("Teleports", 3)

local function showPage(name)
    for n, p in pairs(pages) do
        p.Visible = n == name
        tabButtons[n].BackgroundColor3 = (n == name) and theme.accent or theme.alt
    end
end
for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function() showPage(name) end)
end
showPage("Visuals")

makeToggle(visualsPage, 6, "Employees", config.visuals.employees, function(v) config.visuals.employees = v end)
makeToggle(visualsPage, 44, "Food", config.visuals.food, function(v) config.visuals.food = v end)
makeToggle(visualsPage, 82, "Heals", config.visuals.heals, function(v) config.visuals.heals = v end)
makeToggle(visualsPage, 120, "Gun Stuff", config.visuals.guns, function(v) config.visuals.guns = v end)

local fovLabel = Instance.new("TextLabel", visualsPage)
fovLabel.Size = UDim2.new(1, -8, 0, 26)
fovLabel.Position = UDim2.fromOffset(4, 160)
fovLabel.BackgroundColor3 = theme.alt
fovLabel.TextColor3 = theme.text
fovLabel.Text = "Aimbot FOV: " .. tostring(config.visuals.fov)
fovLabel.Font = Enum.Font.Gotham
fovLabel.TextSize = 12
Instance.new("UICorner", fovLabel)

local fovMinus = makeButton(visualsPage, "-", UDim2.fromOffset(4, 192), UDim2.fromOffset(44, 24))
local fovPlus = makeButton(visualsPage, "+", UDim2.fromOffset(52, 192), UDim2.fromOffset(44, 24))
local function setFov(v)
    config.visuals.fov = math.clamp(v, 50, 2000)
    fovLabel.Text = "Aimbot FOV: " .. tostring(config.visuals.fov)
end
fovMinus.MouseButton1Click:Connect(function() setFov(config.visuals.fov - 25) end)
fovPlus.MouseButton1Click:Connect(function() setFov(config.visuals.fov + 25) end)

local y = 226
for cat, words in pairs(keywords) do
    local hdr = Instance.new("TextLabel", visualsPage)
    hdr.Size = UDim2.new(1, -8, 0, 22)
    hdr.Position = UDim2.fromOffset(4, y)
    hdr.BackgroundTransparency = 1
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.TextColor3 = theme.muted
    hdr.Text = string.upper(cat) .. " KEYWORDS"
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 11
    y = y + 22
    for _, word in ipairs(words) do
        makeToggle(visualsPage, y, word, keywordEnabled[cat][word], function(v)
            keywordEnabled[cat][word] = v
        end)
        y = y + 34
    end
end
updatePageCanvas(visualsPage)

makeToggle(actionsPage, 6, "Aimbot (RMB)", config.actions.aimbot, function(v) config.actions.aimbot = v end)
makeToggle(actionsPage, 44, "WalkSpeed Override", config.actions.walkSpeedEnabled, function(v) config.actions.walkSpeedEnabled = v end)

local wsLabel = Instance.new("TextLabel", actionsPage)
wsLabel.Size = UDim2.new(1, -8, 0, 28)
wsLabel.Position = UDim2.fromOffset(4, 82)
wsLabel.BackgroundColor3 = theme.alt
wsLabel.TextColor3 = theme.text
wsLabel.Text = "WalkSpeed: " .. tostring(config.actions.walkSpeedValue)
wsLabel.Font = Enum.Font.Gotham
wsLabel.TextSize = 12
Instance.new("UICorner", wsLabel)
local wsMinus = makeButton(actionsPage, "-", UDim2.fromOffset(4, 114), UDim2.fromOffset(44, 24))
local wsPlus = makeButton(actionsPage, "+", UDim2.fromOffset(52, 114), UDim2.fromOffset(44, 24))
wsMinus.MouseButton1Click:Connect(function() config.actions.walkSpeedValue = math.max(0, config.actions.walkSpeedValue - 1); wsLabel.Text = "WalkSpeed: " .. config.actions.walkSpeedValue end)
wsPlus.MouseButton1Click:Connect(function() config.actions.walkSpeedValue = math.min(120, config.actions.walkSpeedValue + 1); wsLabel.Text = "WalkSpeed: " .. config.actions.walkSpeedValue end)
updatePageCanvas(actionsPage)

for i = 1, 5 do
    local row = Instance.new("Frame", teleportsPage)
    row.Size = UDim2.new(1, -8, 0, 34)
    row.Position = UDim2.fromOffset(4, 6 + (i - 1) * 38)
    row.BackgroundColor3 = theme.alt
    Instance.new("UICorner", row)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0, 80, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Slot " .. i
    lbl.TextColor3 = theme.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12

    local save = makeButton(row, "Save", UDim2.fromOffset(85, 5), UDim2.fromOffset(80, 24))
    local tp = makeButton(row, "Teleport", UDim2.fromOffset(172, 5), UDim2.fromOffset(90, 24))

    save.MouseButton1Click:Connect(function()
        local hrp = getHRP(player.Character)
        if hrp then tpSlots[i] = hrp.CFrame end
    end)
    tp.MouseButton1Click:Connect(function()
        local char = player.Character
        if char and tpSlots[i] then char:PivotTo(tpSlots[i]) end
    end)
end
updatePageCanvas(teleportsPage)

local stopped = false
local defaultWalkSpeed = nil
local conns = {}

conns[#conns + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Semicolon then
        root.Visible = not root.Visible
    end
end)

local function shutdown()
    if stopped then return end
    stopped = true
    for _, c in ipairs(conns) do c:Disconnect() end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and defaultWalkSpeed then
        hum.WalkSpeed = defaultWalkSpeed
    end
    clearAllVisuals()
    if gui then gui:Destroy() end
end
kill.MouseButton1Click:Connect(shutdown)

local function updateWalkSpeed()
    local char = player.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    defaultWalkSpeed = defaultWalkSpeed or hum.WalkSpeed
    hum.WalkSpeed = config.actions.walkSpeedEnabled and config.actions.walkSpeedValue or defaultWalkSpeed
end

local function updateAimbotTarget()
    closestAimTarget = nil

    if not config.actions.aimbot or not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        return
    end

    local shortest = config.visuals.fov
    local center = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)

    for _, targetPart in ipairs(enemyEntries) do
        if targetPart and targetPart.Parent then
            local sp, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist = (center - Vector2.new(sp.X, sp.Y)).Magnitude
                if dist < shortest and isVisible(targetPart) then
                    closestAimTarget = targetPart
                    shortest = dist
                end
            end
        end
    end
end

local function updateVisuals()
    local char = player.Character
    local hrp = getHRP(char)
    if not hrp then
        clearAllVisuals()
        return
    end

    if not config.visuals.employees and not config.visuals.food and not config.visuals.heals and not config.visuals.guns then
        clearAllVisuals()
        return
    end

    local seenParts = {}
    local visualCount = 0
    local maxDistanceSquared = maxVisualDistance * maxVisualDistance

    if config.visuals.employees then
        for _, targetPart in ipairs(enemyEntries) do
            if visualCount >= maxVisualsPerTick then break end
            if targetPart and targetPart.Parent then
                local offset = targetPart.Position - hrp.Position
                if offset:Dot(offset) <= maxDistanceSquared then
                    seenParts[targetPart] = true
                    activeVisualParts[targetPart] = true
                    ensureVisual(targetPart, Color3.fromRGB(255, 70, 70), "EMPLOYEE")
                    visualCount = visualCount + 1
                end
            end
        end
    end

    for _, entry in ipairs(itemEntries) do
        if visualCount >= maxVisualsPerTick then break end

        local folder, part = entry.folder, entry.part
        if folder and part and part.Parent then
            local offset = part.Position - hrp.Position
            if offset:Dot(offset) <= maxDistanceSquared then
                local lowerName = entry.lowerName or string.lower(folder.Name)
                local drawColor = nil

                if config.visuals.food and checkCategory(lowerName, "food") then
                    drawColor = Color3.fromRGB(40, 230, 145)
                elseif config.visuals.heals and checkCategory(lowerName, "heals") then
                    drawColor = Color3.fromRGB(60, 185, 255)
                elseif config.visuals.guns and checkCategory(lowerName, "guns") then
                    drawColor = Color3.fromRGB(255, 190, 60)
                end

                if drawColor then
                    seenParts[part] = true
                    activeVisualParts[part] = true
                    ensureVisual(part, drawColor, folder.Name)
                    visualCount = visualCount + 1
                end
            end
        end
    end

    hideUnusedVisuals(seenParts)
end

refreshEnemyList()
refreshItemList()

conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
    if stopped then return end

    itemScanAccumulator = itemScanAccumulator + dt
    visualUpdateAccumulator = visualUpdateAccumulator + dt
    aimScanAccumulator = aimScanAccumulator + dt

    if itemScanAccumulator >= scanInterval then
        itemScanAccumulator = 0
        refreshEnemyList()
        refreshItemList()
        cleanDeadCache()
    end

    if aimScanAccumulator >= aimScanInterval then
        aimScanAccumulator = 0
        updateAimbotTarget()
    end

    if visualUpdateAccumulator >= visualUpdateInterval then
        visualUpdateAccumulator = 0
        updateWalkSpeed()
        updateVisuals()
    end

    if config.actions.aimbot and closestAimTarget and closestAimTarget.Parent and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        camera.CFrame = CFrame.lookAt(camera.CFrame.Position, closestAimTarget.Position)
    end
end)
