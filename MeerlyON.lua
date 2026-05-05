local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()
local coreGui = game:GetService("CoreGui")

-- 1. SETTINGS & CATEGORIES
local config = {
    monsters = true,
    food = true,
    heals = false,
    guns = false,
    aimbot = true,
    fov = 500
}

local savedBasePos = nil -- Stores your base CFrame

local keywords = {
    food = {"cola", "burger", "hotdog", "donut", "food", "water", "pizza", "apple", "taco", "bloxy", "drink", "eat", "canned"},
    heals = {"medkit", "bandage", "heal", "aid", "pills", "health", "cure"},
    guns = {"gun", "ammo", "shotgun", "glock", "rifle", "mag", "pistol", "uzi", "bullet", "weapon", "armory", "firearm"}
}

-- 2. STORAGE & DEEP CLEANER
local textCache = {} 

local function removeVisuals(obj)
    if textCache[obj] then textCache[obj]:Remove(); textCache[obj] = nil end
    local h = obj:FindFirstChild("CommanderESP") or (obj.Parent and obj.Parent:FindFirstChild("CommanderESP"))
    if h then h:Destroy() end
end

local function checkCategory(name, cat)
    name = name:lower()
    for _, word in pairs(keywords[cat]) do
        if name:find(word) then return true end
    end
    return false
end

local function nukeCategory(catType)
    for obj, _ in pairs(textCache) do
        local folderName = obj.Parent and obj.Parent.Name or ""
        local isMonster = (obj.Name == "HumanoidRootPart" and obj.Parent.Parent and obj.Parent.Parent.Name == "Enemies")
        if (catType == "monsters" and isMonster) or (checkCategory(folderName, catType)) then
            removeVisuals(obj)
        end
    end
end

-- 3. VISIBILITY CHECK (NO LOCK THROUGH WALLS)
local function isVisible(targetPart)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {player.Character, targetPart.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    local rayResult = workspace:Raycast(origin, direction, rayParams)
    return rayResult == nil
end

-- 4. UI SETUP
local screenGui = Instance.new("ScreenGui", coreGui)
local main = Instance.new("Frame", screenGui)
main.Size = UDim2.new(0, 260, 0, 420); main.Position = UDim2.new(0.05, 0, 0.3, 0)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 18); main.Active = true; main.Draggable = true
Instance.new("UICorner", main)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 45); title.Text = "MEGA STORE COMMANDER"; title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundColor3 = Color3.fromRGB(0, 150, 255); Instance.new("UICorner", title)

local function createToggle(text, pos, key, color)
    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0.9, 0, 0, 40); btn.Position = pos
    btn.Text = text .. (config[key] and " [ON]" or " [OFF]")
    btn.BackgroundColor3 = config[key] and color or Color3.fromRGB(30, 30, 35)
    btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = Enum.Font.Code
    btn.MouseButton1Click:Connect(function()
        config[key] = not config[key]
        btn.Text = text .. (config[key] and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = config[key] and color or Color3.fromRGB(30, 30, 35)
        if not config[key] then nukeCategory(key) end
    end)
    Instance.new("UICorner", btn)
end

-- 5. TELEPORT BUTTONS
local saveBtn = Instance.new("TextButton", main)
saveBtn.Size = UDim2.new(0.425, 0, 0, 40); saveBtn.Position = UDim2.new(0.05, 0, 0, 325)
saveBtn.Text = "SAVE BASE"; saveBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
saveBtn.TextColor3 = Color3.new(1, 1, 1); saveBtn.Font = Enum.Font.Code; Instance.new("UICorner", saveBtn)

local tpBtn = Instance.new("TextButton", main)
tpBtn.Size = UDim2.new(0.425, 0, 0, 40); tpBtn.Position = UDim2.new(0.525, 0, 0, 325)
tpBtn.Text = "TP TO BASE"; tpBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
tpBtn.TextColor3 = Color3.new(1, 1, 1); tpBtn.Font = Enum.Font.Code; Instance.new("UICorner", tpBtn)

saveBtn.MouseButton1Click:Connect(function()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        savedBasePos = hrp.CFrame
        saveBtn.Text = "SAVED!"
        task.wait(1)
        saveBtn.Text = "SAVE BASE"
    end
end)

tpBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    if char and savedBasePos then
        char:PivotTo(savedBasePos)
    else
        tpBtn.Text = "NO POS!"
        task.wait(1)
        tpBtn.Text = "TP TO BASE"
    end
end)

-- 6. CORE ENGINE
local function updateESP(obj, color, name, isMonster)
    if not textCache[obj] then
        textCache[obj] = Drawing.new("Text")
        textCache[obj].Size = 18; textCache[obj].Center = true; textCache[obj].Outline = true
    end
    local txt = textCache[obj]
    local screenPos, onScreen = camera:WorldToViewportPoint(obj.Position)
    if onScreen then
        local dist = (player.Character.HumanoidRootPart.Position - obj.Position).Magnitude
        txt.Visible = true; txt.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
        txt.Text = name .. " [" .. math.floor(dist) .. "s]"; txt.Color = color
        local target = isMonster and obj.Parent or (obj.Parent:IsA("Model") and obj.Parent or obj)
        if target and not target:FindFirstChild("CommanderESP") then
            local h = Instance.new("Highlight", target)
            h.Name = "CommanderESP"; h.FillColor = color; h.FillTransparency = 0.5
        end
    else
        txt.Visible = false
    end
end

-- 7. THE MASTER LOOP
RunService:BindToRenderStep("CommanderMain", Enum.RenderPriority.Camera.Value + 1, function()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Cleanup missing things
    for obj, _ in pairs(textCache) do
        if not obj or not obj.Parent or not obj:IsDescendantOf(workspace) then removeVisuals(obj) end
    end

    -- A) EMPLOYEES
    local closestEnemy = nil
    local shortestMouseDist = config.fov
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    if workspace:FindFirstChild("Enemies") then
        for _, enemy in pairs(workspace.Enemies:GetChildren()) do
            local targetPart = enemy:FindFirstChild("HumanoidRootPart")
            if targetPart then
                if config.monsters then updateESP(targetPart, Color3.new(1, 0, 0), "EMPLOYEE", true) end
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                if onScreen and isVisible(targetPart) then
                    local mDist = (center - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    if mDist < shortestMouseDist then closestEnemy = targetPart; shortestMouseDist = mDist end
                end
            end
        end
    end

    -- B) AIMBOT
    if config.aimbot and closestEnemy and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        camera.CFrame = CFrame.lookAt(camera.CFrame.Position, closestEnemy.Position)
    end

    -- C) SMART SCANNER
    local items = workspace.Map.Util:FindFirstChild("Items")
    if items then
        for _, folder in pairs(items:GetChildren()) do
            local p = folder:FindFirstChildWhichIsA("BasePart", true) or folder:FindFirstChildWhichIsA("MeshPart", true)
            if p then
                if config.food and checkCategory(folder.Name, "food") then updateESP(p, Color3.new(0, 1, 0.5), folder.Name, false)
                elseif config.heals and checkCategory(folder.Name, "heals") then updateESP(p, Color3.new(0, 0.8, 1), folder.Name, false)
                elseif config.guns and checkCategory(folder.Name, "guns") then updateESP(p, Color3.new(1, 0.8, 0), folder.Name, false) end
            end
        end
    end
end)

-- 8. TOGGLES
createToggle("TRACK EMPLOYEES", UDim2.new(0.05, 0, 0, 50), "monsters", Color3.fromRGB(200, 0, 0))
createToggle("TRACK FOOD", UDim2.new(0.05, 0, 0, 95), "food", Color3.fromRGB(0, 150, 80))
createToggle("TRACK HEALS", UDim2.new(0.05, 0, 0, 140), "heals", Color3.fromRGB(0, 120, 200))
createToggle("TRACK GUN STUFF", UDim2.new(0.05, 0, 0, 185), "guns", Color3.fromRGB(200, 150, 0))
createToggle("AIMBOT (NO WALLS)", UDim2.new(0.05, 0, 0, 230), "aimbot", Color3.fromRGB(120, 0, 255))

UIS.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightControl then screenGui.Enabled = not screenGui.Enabled end
end)
