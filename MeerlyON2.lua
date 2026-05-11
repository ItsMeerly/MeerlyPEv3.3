--[[
    MeerlyON2 - Superstore Sleep-Over support module.
    Loaded by MLauncher for Superstore Sleep-Over place/universe ids.
]]

return function(context)
    local UI = context and context.UI
    local Logger = context and context.Logger

    if not UI then
        error("MeerlyON2 requires the launcher UI context.", 2)
    end

    if UI._MeerlyON2Loaded then
        if context.Logger then
            context.Logger:Warn("MeerlyON2 is already loaded.", "Superstore")
        end
        UI:SelectTab("Item ESP")
        return
    end
    UI._MeerlyON2Loaded = true

    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")

    local LocalPlayer = Players.LocalPlayer
    local GAME_NAME = "Superstore Sleep-Over"
    local AIM_FOV = 500

    local itemCategories = {
        {
            Name = "Food/Energy",
            Color = Color3.fromRGB(72, 220, 132),
            Items = { "Hotdog", "Burger", "Cola", "Ham", "Cake" },
        },
        {
            Name = "Health Items",
            Color = Color3.fromRGB(80, 190, 255),
            Items = { "Bandage", "Medkit" },
        },
        {
            Name = "Weapons",
            Color = Color3.fromRGB(255, 86, 86),
            Items = { "Plank", "Katana", "Pistol", "PumpShotgun", "AR" },
        },
        {
            Name = "Weap Ammo",
            Color = Color3.fromRGB(255, 184, 72),
            Items = { "AmmoPistolBasic", "AmmoShotgunBasic", "AmmoARBasic" },
        },
        {
            Name = "Materials",
            Color = Color3.fromRGB(190, 150, 105),
            Items = { "Wood", "Cloth", "Metal" },
        },
        {
            Name = "Flashlights",
            Color = Color3.fromRGB(245, 245, 120),
            Items = { "BasicFlashlight_Standard", "BasicFlashlight_Big", "HiddenFlashlight_Standard", "HiddenFlashlight_Big" },
        },
        {
            Name = "Tokens",
            Color = Color3.fromRGB(255, 215, 80),
            Items = { "SingleToken", "DoubleToken" },
        },
        {
            Name = "Progression",
            Color = Color3.fromRGB(170, 105, 255),
            Items = { "RedCube", "BlueCube", "GreenCube", "TimeFreeze" },
        },
    }

    local enemyTypes = {
        Employee = Color3.fromRGB(255, 95, 95),
        BuffEmployee = Color3.fromRGB(255, 130, 70),
        Manager = Color3.fromRGB(220, 70, 255),
    }
    local enemyOrder = { "Employee", "BuffEmployee", "Manager" }

    local itemLookup = {}
    for _, category in ipairs(itemCategories) do
        for _, itemName in ipairs(category.Items) do
            itemLookup[itemName] = category
        end
    end

    local function logInfo(message)
        if Logger then
            Logger:Info(message, "Superstore")
        end
    end

    local function logWarn(message)
        if Logger then
            Logger:Warn(message, "Superstore")
        end
    end

    local function clearTable(tbl)
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end

    local function cleanName(name)
        return tostring(name or ""):gsub("%s*%b()", "")
    end

    local function findPath(root, names)
        local current = root
        for _, name in ipairs(names) do
            current = current and current:FindFirstChild(name)
        end
        return current
    end

    local function getItemsFolder()
        return findPath(workspace, { "Map", "Util", "Items" })
    end

    local function getAlarmsFolder()
        return findPath(workspace, { "Map", "Util", "Alarms" })
    end

    local function getObjectsFolder()
        return findPath(workspace, { "Map", "Util", "Objects" })
    end

    local function getEnemiesFolder()
        return workspace:FindFirstChild("Enemies")
    end

    local function getCharacter()
        return LocalPlayer and LocalPlayer.Character
    end

    local function getRootPart(character)
        character = character or getCharacter()
        if not character then
            return nil
        end

        return character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChildWhichIsA("BasePart")
    end

    local function getTargetParts(instance)
        if not instance then
            return nil, nil
        end

        if instance:IsA("BasePart") then
            return instance, instance
        end

        if instance:IsA("Model") then
            local part = instance:FindFirstChild("HumanoidRootPart")
                or instance:FindFirstChild("Head")
                or instance.PrimaryPart
                or instance:FindFirstChildWhichIsA("BasePart", true)
            return instance, part
        end

        local model = instance:FindFirstAncestorOfClass("Model")
        local part = instance:FindFirstChildWhichIsA("BasePart", true)
            or (instance:IsA("BasePart") and instance)
        return model or part or instance, part
    end

    local espFolder = Instance.new("Folder")
    espFolder.Name = "MeerlyON2ESP"
    espFolder.Parent = CoreGui

    local itemVisuals = {}
    local enemyVisuals = {}
    local alarmVisuals = {}
    local objectVisuals = {}
    local folderWatchers = {}
    local cleanupCallbacks = {}
    local teleportSlots = {}

    local state = {
        ItemESP = false,
        ItemESPNames = true,
        EnemyESP = false,
        EnemyESPNames = true,
        AlarmESP = false,
        AlarmESPNames = true,
        ObjectESP = false,
        ObjectESPNames = true,
        AimAssist = false,
        ItemCategories = {},
        ItemNames = {},
        EnemyTypes = {},
        ObjectTypes = {},
    }

    for _, category in ipairs(itemCategories) do
        state.ItemCategories[category.Name] = true
        for _, itemName in ipairs(category.Items) do
            state.ItemNames[itemName] = true
        end
    end

    for _, enemyName in ipairs(enemyOrder) do
        state.EnemyTypes[enemyName] = true
    end

    local function createVisual(registry, object, label, color, showName)
        if not object or not object.Parent then
            return
        end

        local adornee, part = getTargetParts(object)
        if not adornee or not part then
            return
        end

        local existing = registry[object]
        if existing then
            existing.Highlight.Adornee = adornee
            existing.Highlight.FillColor = color
            existing.Highlight.OutlineColor = color
            existing.Billboard.Adornee = part
            existing.Billboard.Enabled = showName ~= false
            existing.Label.Text = label
            existing.Label.TextColor3 = color
            return
        end

        local highlight = Instance.new("Highlight")
        highlight.Name = "MeerlyON2Highlight"
        highlight.Adornee = adornee
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = color
        highlight.FillTransparency = 0.72
        highlight.OutlineColor = color
        highlight.OutlineTransparency = 0
        highlight.Parent = espFolder

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "MeerlyON2Label"
        billboard.Adornee = part
        billboard.AlwaysOnTop = true
        billboard.Enabled = showName ~= false
        billboard.Size = UDim2.fromOffset(180, 34)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.Parent = espFolder

        local text = Instance.new("TextLabel")
        text.BackgroundTransparency = 1
        text.Size = UDim2.fromScale(1, 1)
        text.Text = label
        text.TextColor3 = color
        text.TextSize = 13
        text.Font = Enum.Font.Code
        text.TextStrokeTransparency = 0.35
        text.Parent = billboard

        registry[object] = {
            Highlight = highlight,
            Billboard = billboard,
            Label = text,
            Connection = object.AncestryChanged:Connect(function(_, parent)
                if parent == nil then
                    local record = registry[object]
                    if record then
                        if record.Connection then
                            record.Connection:Disconnect()
                        end
                        if record.Highlight then
                            record.Highlight:Destroy()
                        end
                        if record.Billboard then
                            record.Billboard:Destroy()
                        end
                        registry[object] = nil
                    end
                end
            end),
        }
    end

    local function setRegistryNamesVisible(registry, visible)
        for _, record in pairs(registry) do
            if record.Billboard then
                record.Billboard.Enabled = visible and true or false
            end
        end
    end

    local function removeVisual(registry, object)
        local record = registry[object]
        if not record then
            return
        end

        if record.Connection then
            record.Connection:Disconnect()
        end
        if record.Highlight then
            record.Highlight:Destroy()
        end
        if record.Billboard then
            record.Billboard:Destroy()
        end

        registry[object] = nil
    end

    local function clearRegistry(registry)
        for object in pairs(registry) do
            removeVisual(registry, object)
        end
    end

    local function addItemVisual(item)
        if not state.ItemESP then
            return
        end

        local itemName = cleanName(item.Name)
        local category = itemLookup[itemName]
        if not category or not state.ItemNames[itemName] then
            return
        end

        createVisual(itemVisuals, item, item.Name, category.Color, state.ItemESPNames)
    end

    local function refreshItems()
        clearRegistry(itemVisuals)
        if not state.ItemESP then
            return
        end

        local folder = getItemsFolder()
        if not folder then
            logWarn("Items folder not found.")
            return
        end

        for _, item in ipairs(folder:GetChildren()) do
            addItemVisual(item)
        end
    end

    local function addEnemyVisual(enemy, retry)
        if not state.EnemyESP then
            return
        end

        local color = enemyTypes[enemy.Name]
        if not color or not state.EnemyTypes[enemy.Name] then
            return
        end

        local _, part = getTargetParts(enemy)
        if not part and not retry then
            task.delay(0.35, function()
                if enemy.Parent then
                    addEnemyVisual(enemy, true)
                end
            end)
            return
        end

        createVisual(enemyVisuals, enemy, enemy.Name, color, state.EnemyESPNames)
    end

    local function refreshEnemies()
        clearRegistry(enemyVisuals)
        if not state.EnemyESP then
            return
        end

        local folder = getEnemiesFolder()
        if not folder then
            logWarn("Enemies folder not found.")
            return
        end

        for _, enemy in ipairs(folder:GetChildren()) do
            addEnemyVisual(enemy)
        end
    end

    local function refreshAlarms()
        clearRegistry(alarmVisuals)
        if not state.AlarmESP then
            return
        end

        local folder = getAlarmsFolder()
        if not folder then
            logWarn("Alarms folder not found.")
            return
        end

        local index = 0
        for _, alarm in ipairs(folder:GetChildren()) do
            if alarm:IsA("BasePart") or alarm:FindFirstChildWhichIsA("BasePart", true) then
                index = index + 1
                createVisual(alarmVisuals, alarm, "Alarm " .. tostring(index), Color3.fromRGB(255, 45, 45), state.AlarmESPNames)
            end
        end
    end

    local objectScan = {
        ObjectsByName = {},
        Toggles = {},
        Status = nil,
    }

    local function refreshObjects()
        clearRegistry(objectVisuals)
        if not state.ObjectESP then
            return
        end

        for objectName, enabled in pairs(state.ObjectTypes) do
            if enabled and objectScan.ObjectsByName[objectName] then
                for _, object in ipairs(objectScan.ObjectsByName[objectName]) do
                    createVisual(objectVisuals, object, objectName, Color3.fromRGB(95, 210, 255), state.ObjectESPNames)
                end
            end
        end
    end

    local function setToggleText(toggle, text)
        if toggle and toggle.Label then
            toggle.Label.Text = text
            return
        end

        if toggle and toggle.Instance then
            for _, child in ipairs(toggle.Instance:GetChildren()) do
                if child:IsA("TextButton") and child.BackgroundTransparency == 1 then
                    child.Text = text
                    return
                end
            end
        end
    end

    local function scanObjects(objectsSection)
        local folder = getObjectsFolder()
        clearTable(objectScan.ObjectsByName)

        if not folder then
            if objectScan.Status then
                objectScan.Status.Text = "Objects: folder not found."
            end
            logWarn("Objects folder not found.")
            refreshObjects()
            return
        end

        for _, object in ipairs(folder:GetChildren()) do
            local objectName = cleanName(object.Name)
            if objectName ~= "" and objectName ~= "ChristmasLight" then
                objectScan.ObjectsByName[objectName] = objectScan.ObjectsByName[objectName] or {}
                table.insert(objectScan.ObjectsByName[objectName], object)
            end
        end

        local names = {}
        for objectName in pairs(objectScan.ObjectsByName) do
            table.insert(names, objectName)
        end
        table.sort(names)

        for objectName, toggle in pairs(objectScan.Toggles) do
            local count = objectScan.ObjectsByName[objectName] and #objectScan.ObjectsByName[objectName] or 0
            setToggleText(toggle, objectName .. " x " .. tostring(count))
        end

        for _, objectName in ipairs(names) do
            local count = #objectScan.ObjectsByName[objectName]
            if state.ObjectTypes[objectName] == nil then
                state.ObjectTypes[objectName] = false
            end

            if objectScan.Toggles[objectName] then
                setToggleText(objectScan.Toggles[objectName], objectName .. " x " .. tostring(count))
            else
                objectScan.Toggles[objectName] = objectsSection:CreateToggle({
                    Text = objectName .. " x " .. tostring(count),
                    Default = false,
                    Callback = function(value)
                        state.ObjectTypes[objectName] = value and true or false
                        refreshObjects()
                    end,
                })
            end
        end

        if objectScan.Status then
            objectScan.Status.Text = "Objects: " .. tostring(#names) .. " types scanned."
        end

        logInfo("Scanned " .. tostring(#names) .. " object types.")
        refreshObjects()
    end

    local function watchFolder(key, folder, clearFunc, addFunc, removeFunc)
        local watcher = folderWatchers[key]
        if watcher and watcher.Folder == folder then
            return
        end

        if watcher then
            for _, connection in ipairs(watcher.Connections) do
                connection:Disconnect()
            end
        end

        clearFunc()
        watcher = { Folder = folder, Connections = {} }
        folderWatchers[key] = watcher

        if not folder then
            return
        end

        table.insert(watcher.Connections, folder.ChildAdded:Connect(addFunc))
        table.insert(watcher.Connections, folder.ChildRemoved:Connect(removeFunc))

        for _, child in ipairs(folder:GetChildren()) do
            addFunc(child)
        end
    end

    local function refreshFolderWatchers()
        watchFolder("Items", getItemsFolder(), function()
            clearRegistry(itemVisuals)
        end, addItemVisual, function(item)
            removeVisual(itemVisuals, item)
        end)

        watchFolder("Enemies", getEnemiesFolder(), function()
            clearRegistry(enemyVisuals)
        end, addEnemyVisual, function(enemy)
            removeVisual(enemyVisuals, enemy)
        end)

        watchFolder("Alarms", getAlarmsFolder(), function()
            clearRegistry(alarmVisuals)
        end, function()
            refreshAlarms()
        end, function()
            refreshAlarms()
        end)
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local function isVisible(targetPart)
        local camera = workspace.CurrentCamera
        local character = getCharacter()
        if not camera or not character or not targetPart then
            return false
        end

        rayParams.FilterDescendantsInstances = { character, targetPart.Parent }
        local origin = camera.CFrame.Position
        local result = workspace:Raycast(origin, targetPart.Position - origin, rayParams)
        return result == nil
    end

    local function findAimTarget()
        local camera = workspace.CurrentCamera
        local folder = getEnemiesFolder()
        if not camera or not folder then
            return nil
        end

        local center = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)
        local closestPart = nil
        local closestDistance = AIM_FOV

        for _, enemy in ipairs(folder:GetChildren()) do
            if enemyTypes[enemy.Name] and state.EnemyTypes[enemy.Name] then
                local _, part = getTargetParts(enemy)
                if part and isVisible(part) then
                    local screenPoint, onScreen = camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local distance = (center - Vector2.new(screenPoint.X, screenPoint.Y)).Magnitude
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPart = part
                        end
                    end
                end
            end
        end

        return closestPart
    end

    local itemTab = UI:CreateTab("Item ESP")
    local otherTab = UI:CreateTab("Other ESP")
    local teleportTab = UI:CreateTab("Teleports")
    local itemSection = itemTab:CreateSection("Item ESP")
    local alarmSection = otherTab:CreateSection("Alarm ESP")
    local enemySection = otherTab:CreateSection("Enemy ESP")
    local objectSection = otherTab:CreateSection("Object ESP")
    local teleportSection = teleportTab:CreateSection("Teleports")

    itemSection:CreateToggle({
        Text = "Items ESP",
        Default = false,
        Callback = function(value)
            state.ItemESP = value and true or false
            refreshItems()
            logInfo(state.ItemESP and "Items ESP enabled." or "Items ESP disabled.")
        end,
    })

    itemSection:CreateToggle({
        Text = "ESP Names",
        Default = true,
        Callback = function(value)
            state.ItemESPNames = value and true or false
            setRegistryNamesVisible(itemVisuals, state.ItemESPNames)
        end,
    })

    local itemToggles = {}
    local categoryToggles = {}
    for _, category in ipairs(itemCategories) do
        local categoryRef = category
        itemSection:CreateLabel(categoryRef.Name)
        categoryToggles[categoryRef.Name] = itemSection:CreateToggle({
            Text = categoryRef.Name .. " (All)",
            Default = true,
            Callback = function(value)
                state.ItemCategories[categoryRef.Name] = value and true or false
                for _, itemName in ipairs(categoryRef.Items) do
                    state.ItemNames[itemName] = value and true or false
                    if itemToggles[itemName] then
                        itemToggles[itemName].Set(value, true)
                    end
                end
                refreshItems()
            end,
        })

        for _, itemName in ipairs(categoryRef.Items) do
            local itemNameRef = itemName
            itemToggles[itemName] = itemSection:CreateToggle({
                Text = itemNameRef,
                Default = true,
                Callback = function(value)
                    state.ItemNames[itemNameRef] = value and true or false
                    local allEnabled = true
                    for _, childName in ipairs(categoryRef.Items) do
                        if not state.ItemNames[childName] then
                            allEnabled = false
                            break
                        end
                    end
                    state.ItemCategories[categoryRef.Name] = allEnabled
                    if categoryToggles[categoryRef.Name] then
                        categoryToggles[categoryRef.Name].Set(allEnabled, true)
                    end
                    refreshItems()
                end,
            })
        end
    end

    alarmSection:CreateToggle({
        Text = "Alarms ESP",
        Default = false,
        Callback = function(value)
            state.AlarmESP = value and true or false
            refreshAlarms()
            logInfo(state.AlarmESP and "Alarms ESP enabled." or "Alarms ESP disabled.")
        end,
    })

    alarmSection:CreateToggle({
        Text = "ESP Names",
        Default = true,
        Callback = function(value)
            state.AlarmESPNames = value and true or false
            setRegistryNamesVisible(alarmVisuals, state.AlarmESPNames)
        end,
    })

    enemySection:CreateToggle({
        Text = "Enemies ESP",
        Default = false,
        Callback = function(value)
            state.EnemyESP = value and true or false
            refreshEnemies()
            logInfo(state.EnemyESP and "Enemies ESP enabled." or "Enemies ESP disabled.")
        end,
    })

    enemySection:CreateToggle({
        Text = "ESP Names",
        Default = true,
        Callback = function(value)
            state.EnemyESPNames = value and true or false
            setRegistryNamesVisible(enemyVisuals, state.EnemyESPNames)
        end,
    })

    for _, enemyName in ipairs(enemyOrder) do
        enemySection:CreateToggle({
            Text = enemyName,
            Default = true,
            Callback = function(value)
                state.EnemyTypes[enemyName] = value and true or false
                refreshEnemies()
            end,
        })
    end

    enemySection:CreateToggle({
        Text = "Enemy Aim Assist (RMB)",
        Default = false,
        Callback = function(value)
            state.AimAssist = value and true or false
            logInfo(state.AimAssist and "Enemy aim assist enabled." or "Enemy aim assist disabled.")
        end,
    })

    objectSection:CreateToggle({
        Text = "Objects ESP",
        Default = false,
        Callback = function(value)
            state.ObjectESP = value and true or false
            refreshObjects()
            logInfo(state.ObjectESP and "Objects ESP enabled." or "Objects ESP disabled.")
        end,
    })

    objectSection:CreateToggle({
        Text = "ESP Names",
        Default = true,
        Callback = function(value)
            state.ObjectESPNames = value and true or false
            setRegistryNamesVisible(objectVisuals, state.ObjectESPNames)
        end,
    })

    objectScan.Status = objectSection:CreateLabel("Objects: not scanned.")
    objectSection:CreateButton({
        Text = "Scan Objects",
        Callback = function()
            scanObjects(objectSection)
        end,
    })

    local function createTeleportRow(index)
        local row = teleportSection:_row(24)

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(0, 0)
        label.Size = UDim2.new(1, -176, 1, 0)
        label.Text = "Slot " .. tostring(index)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextSize = 12
        label.Font = Enum.Font.Code
        UI:_track(label, "Text", "TextColor3")
        label.Parent = row

        local saveButton = Instance.new("TextButton")
        saveButton.AnchorPoint = Vector2.new(1, 0)
        saveButton.Position = UDim2.new(1, -90, 0, 1)
        saveButton.Size = UDim2.fromOffset(82, 22)
        saveButton.BorderSizePixel = 1
        saveButton.Text = "Save"
        saveButton.TextSize = 12
        saveButton.Font = Enum.Font.Code
        saveButton.AutoButtonColor = false
        UI:_track(saveButton, "Control")
        UI:_track(saveButton, "Border", "BorderColor3")
        UI:_track(saveButton, "Text", "TextColor3")
        saveButton.Parent = row

        local loadButton = Instance.new("TextButton")
        loadButton.AnchorPoint = Vector2.new(1, 0)
        loadButton.Position = UDim2.new(1, 0, 0, 1)
        loadButton.Size = UDim2.fromOffset(82, 22)
        loadButton.BorderSizePixel = 1
        loadButton.Text = "Load"
        loadButton.TextSize = 12
        loadButton.Font = Enum.Font.Code
        loadButton.AutoButtonColor = false
        UI:_track(loadButton, "Control")
        UI:_track(loadButton, "Border", "BorderColor3")
        UI:_track(loadButton, "Text", "TextColor3")
        loadButton.Parent = row

        saveButton.MouseButton1Click:Connect(function()
            local character = getCharacter()
            local rootPart = getRootPart(character)
            if not character or not rootPart then
                logWarn("Could not save slot " .. tostring(index) .. "; character not ready.")
                return
            end

            teleportSlots[index] = rootPart.CFrame
            logInfo("Saved teleport slot " .. tostring(index) .. ".")
        end)

        loadButton.MouseButton1Click:Connect(function()
            local character = getCharacter()
            if not character or not teleportSlots[index] then
                logWarn("Teleport slot " .. tostring(index) .. " is empty.")
                return
            end

            character:PivotTo(teleportSlots[index])
            logInfo("Teleported to slot " .. tostring(index) .. ".")
        end)
    end

    for index = 1, 5 do
        createTeleportRow(index)
    end

    refreshFolderWatchers()

    local folderPoll = 0
    local renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
        folderPoll = folderPoll + deltaTime
        if folderPoll >= 2 then
            folderPoll = 0
            refreshFolderWatchers()
        end

        if state.AimAssist and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            local target = findAimTarget()
            local camera = workspace.CurrentCamera
            if target and camera then
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, target.Position)
            end
        end
    end)

    local function cleanup()
        if renderConnection then
            renderConnection:Disconnect()
            renderConnection = nil
        end

        for _, watcher in pairs(folderWatchers) do
            for _, connection in ipairs(watcher.Connections) do
                connection:Disconnect()
            end
        end
        clearTable(folderWatchers)

        for _, callback in ipairs(cleanupCallbacks) do
            callback()
        end
        clearTable(cleanupCallbacks)

        clearRegistry(itemVisuals)
        clearRegistry(enemyVisuals)
        clearRegistry(alarmVisuals)
        clearRegistry(objectVisuals)

        if espFolder then
            espFolder:Destroy()
            espFolder = nil
        end

        UI._MeerlyON2Loaded = nil
    end

    UI:OnKill(cleanup)
    UI:SelectTab("Item ESP")
    logInfo("MeerlyON2 loaded.")
end
