--[[
    MeerlyPU_Win95_Migrated.lua
    Migrates selected MeerlyPU features into Win95 pages:
      - Weapons
      - Utility
      - Teleports
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local CONFIG = {
    LibraryPath = "MeerlyWin95UILibrary.lua",
    LibraryRawUrl = "https://raw.githubusercontent.com/ItsMeerly/MeerlyScriptHub/refs/heads/main/MeerlyWin95UILibrary.lua",
    UseDefaultRawFallbacks = true,
    AccessKey = "ForLoveWithLove",
    AccessLink = "https://work.ink/2kaV/meerlyunrng",
    Title = "Meerly Win95 - PU Migration",
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
    local tried, triedSet = {}, {}

    local function markTried(tag)
        if not triedSet[tag] then
            triedSet[tag] = true
            tried[#tried + 1] = tag
        end
    end

    local function tryRead(path)
        if type(readfile) ~= "function" or not path or path == "" then
            return nil
        end

        markTried("file:" .. path)
        local ok, result = pcall(readfile, path)
        if ok and type(result) == "string" and result ~= "" then
            return result
        end

        if type(result) == "string" and string.find(result, "Expected File But Got Directory", 1, true) then
            local initPath = string.gsub(path, "/+$", "") .. "/init.lua"
            markTried("file:" .. initPath)
            local okInit, initResult = pcall(readfile, initPath)
            if okInit and type(initResult) == "string" and initResult ~= "" then
                return initResult
            end
        end

        return nil
    end

    local function tryHttpGet(url)
        if not url or url == "" then
            return nil
        end

        local getter
        if typeof(game) == "Instance" and type(game.HttpGet) == "function" then
            getter = function(target)
                return game:HttpGet(target)
            end
        elseif type(httpget) == "function" then
            getter = httpget
        end

        if not getter then
            return nil
        end

        markTried("url:" .. url)
        local ok, result = pcall(getter, url)
        if ok and type(result) == "string" and result ~= "" then
            return result
        end

        return nil
    end

    local function localCandidates()
        local candidates = {
            CONFIG.LibraryPath,
            "./" .. tostring(CONFIG.LibraryPath or ""),
            "MeerlyWin95UILibrary.lua",
            "./MeerlyWin95UILibrary.lua",
            "MeerlyWin95UILibrary/init.lua",
            "./MeerlyWin95UILibrary/init.lua",
        }

        if type(listfiles) == "function" then
            local ok, files = pcall(listfiles, ".")
            if ok and type(files) == "table" then
                for _, full in ipairs(files) do
                    local lower = string.lower(tostring(full))
                    if lower:find("win95") and lower:sub(-4) == ".lua" then
                        candidates[#candidates + 1] = full
                    end
                end
            end
        end

        return candidates
    end

    local function defaultRawUrls()
        if CONFIG.UseDefaultRawFallbacks == false then
            return {}
        end

        return {
            "https://raw.githubusercontent.com/ItsMeerly/MeerlyPEv3.3/main/MeerlyWin95UILibrary.lua",
            "https://raw.githubusercontent.com/ItsMeerly/MeerlyPEv3.3/master/MeerlyWin95UILibrary.lua",
            "https://raw.githubusercontent.com/ItsMeerly/MeerlyPE/main/MeerlyWin95UILibrary.lua",
            "https://raw.githubusercontent.com/ItsMeerly/MeerlyPE/master/MeerlyWin95UILibrary.lua",
        }
    end

    local source
    for _, candidate in ipairs(localCandidates()) do
        source = tryRead(candidate)
        if source then
            break
        end
    end

    if not source then
        source = tryHttpGet(CONFIG.LibraryRawUrl)
    end

    if not source then
        for _, url in ipairs(defaultRawUrls()) do
            source = tryHttpGet(url)
            if source then
                break
            end
        end
    end

    assert(source, "Failed to load Win95 library source. Tried: " .. table.concat(tried, ", "))

    local accessKeyEscaped = escapeLuaString(CONFIG.AccessKey)
    local accessLinkEscaped = escapeLuaString(CONFIG.AccessLink)

    local keyPattern = 'local%s+HARDCODED_KEY%s*=%s*"[^"]*"'
    local linkPattern = 'local%s+KEY_LINK%s*=%s*"[^"]*"'

    local keyReplacements
    source, keyReplacements = source:gsub(keyPattern, 'local HARDCODED_KEY = "' .. accessKeyEscaped .. '"', 1)

    local linkReplacements
    source, linkReplacements = source:gsub(linkPattern, 'local KEY_LINK = "' .. accessLinkEscaped .. '"', 1)

    assert(keyReplacements > 0, "Failed to patch HARDCODED_KEY in Win95 library source")
    assert(linkReplacements > 0, "Failed to patch KEY_LINK in Win95 library source")

    source = source:gsub("ScrollBarInset%s*=%s*Enum%.ScrollBarInset%.%w+%s*,?%s*", "")

    local chunk = assert(loadstring(source), "Failed to compile Win95 library")
    return chunk()
end

local MeerlyWin95 = loadWin95Library()

local PageStackState = setmetatable({}, { __mode = "k" })
local PageOwners = setmetatable({}, { __mode = "k" })

local function bindDynamicTheme(ui, applyFn)
    if not ui or type(applyFn) ~= "function" then return end
    applyFn(ui.theme)
    table.insert(ui.dynamicThemeParts, { apply = function(theme) applyFn(theme) end })
end

local function findPageOwner(obj)
    local node = obj
    while node do
        local owner = PageOwners[node]
        if owner then return owner end
        node = node.Parent
    end
    return nil
end

local function addSimpleBevel(frame)
    local top = Instance.new("Frame")
    top.Name = "BevelTop"
    top.Parent = frame
    top.BackgroundTransparency = 0
    top.BorderSizePixel = 0
    top.Position = UDim2.fromOffset(0, 0)
    top.Size = UDim2.new(1, 0, 0, 1)
    top.ZIndex = frame.ZIndex + 1

    local left = Instance.new("Frame")
    left.Name = "BevelLeft"
    left.Parent = frame
    left.BackgroundTransparency = 0
    left.BorderSizePixel = 0
    left.Position = UDim2.fromOffset(0, 0)
    left.Size = UDim2.new(0, 1, 1, 0)
    left.ZIndex = frame.ZIndex + 1

    local bottom = Instance.new("Frame")
    bottom.Name = "BevelBottom"
    bottom.Parent = frame
    bottom.BackgroundTransparency = 0
    bottom.BorderSizePixel = 0
    bottom.Position = UDim2.new(0, 0, 1, -1)
    bottom.Size = UDim2.new(1, 0, 0, 1)
    bottom.ZIndex = frame.ZIndex + 1

    local right = Instance.new("Frame")
    right.Name = "BevelRight"
    right.Parent = frame
    right.BackgroundTransparency = 0
    right.BorderSizePixel = 0
    right.Position = UDim2.new(1, -1, 0, 0)
    right.Size = UDim2.new(0, 1, 1, 0)
    right.ZIndex = frame.ZIndex + 1

    local ui = findPageOwner(frame)
    bindDynamicTheme(ui, function(theme)
        top.BackgroundColor3 = theme.bevelLight
        left.BackgroundColor3 = theme.bevelLight
        bottom.BackgroundColor3 = theme.bevelDark
        right.BackgroundColor3 = theme.bevelDark
    end)
end

local function getPageState(page)
    local state = PageStackState[page]
    if not state then
        state = { baseY = 8, blocks = {} }
        PageStackState[page] = state
    end
    return state
end

local function nextStackY(page)
    return getPageState(page).baseY
end

local function advanceStackY(page, amount)
    getPageState(page).baseY += amount
end

local function registerStackBlock(page, block)
    table.insert(getPageState(page).blocks, block)
end

local function reflowStackPage(page)
    local y = getPageState(page).baseY
    for _, block in ipairs(getPageState(page).blocks) do
        y += block(y)
    end
end

local function addHeader(page, text)
    local ui = findPageOwner(page)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = page
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 18
    lbl.Text = text
    lbl.Size = UDim2.new(1, -24, 0, 24)
    lbl.Position = UDim2.fromOffset(8, nextStackY(page))
    bindDynamicTheme(ui, function(theme) lbl.TextColor3 = theme.text end)
    advanceStackY(page, 30)
end

local function addAccordion(page, title, defaultOpen)
    local ui = findPageOwner(page)

    local header = Instance.new("TextButton")
    header.Parent = page
    header.AutoButtonColor = false
    header.Font = Enum.Font.Code
    header.TextSize = 13
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Size = UDim2.new(1, -24, 0, 24)
    header.Position = UDim2.fromOffset(8, nextStackY(page))
    header.BorderSizePixel = 0

    local body = Instance.new("Frame")
    body.Parent = page
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
        reflowStackPage(page)
    end)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        refresh()
        reflowStackPage(page)
    end)

    registerStackBlock(page, function(y)
        header.Position = UDim2.fromOffset(8, y)
        body.Position = UDim2.fromOffset(8, y + 26)
        return 26 + body.Size.Y.Offset + 8
    end)

    refresh()
    addSimpleBevel(header)
    bindDynamicTheme(ui, function(theme)
        header.BackgroundColor3 = theme.window
        header.TextColor3 = theme.text
        body.BackgroundColor3 = theme.panel
    end)

    return body
end

local function addButton(parent, text, callback)
    local ui = findPageOwner(parent)
    local b = Instance.new("TextButton")
    b.Parent = parent
    b.Size = UDim2.new(1, 0, 0, 24)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.Code
    b.TextSize = 12
    b.Text = text
    b.MouseButton1Click:Connect(callback)
    addSimpleBevel(b)
    bindDynamicTheme(ui, function(theme)
        b.BackgroundColor3 = theme.window
        b.TextColor3 = theme.text
    end)
    return b
end

local function addToggle(parent, text, defaultValue, callback)
    local ui = findPageOwner(parent)
    local btn = Instance.new("TextButton")
    btn.Parent = parent
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Code
    btn.TextSize = 12

    local value = defaultValue == true
    local function refresh()
        btn.Text = string.format("[%s] %s", value and "ON" or "OFF", text)
        btn.BackgroundColor3 = value and ui.theme.accent or ui.theme.window
        btn.TextColor3 = ui.theme.text
    end

    btn.MouseButton1Click:Connect(function()
        value = not value
        refresh()
        if callback then callback(value) end
    end)

    addSimpleBevel(btn)
    bindDynamicTheme(ui, refresh)
    refresh()

    return {
        set = function(v)
            value = v == true
            refresh()
        end,
        get = function()
            return value
        end,
    }
end

local function addTextbox(parent, labelText, defaultText, onCommit)
    local ui = findPageOwner(parent)
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

    local tb = Instance.new("TextBox")
    tb.Parent = wrap
    tb.Size = UDim2.new(0.44, -4, 1, 0)
    tb.Position = UDim2.new(0.56, 4, 0, 0)
    tb.BorderSizePixel = 0
    tb.Text = defaultText or ""
    tb.ClearTextOnFocus = false
    tb.Font = Enum.Font.Code
    tb.TextSize = 12
    addSimpleBevel(tb)

    tb.FocusLost:Connect(function()
        if onCommit then
            local nextText = onCommit(tb.Text)
            if nextText ~= nil then
                tb.Text = tostring(nextText)
            end
        end
    end)

    bindDynamicTheme(ui, function(theme)
        label.TextColor3 = theme.text
        tb.BackgroundColor3 = theme.panel
        tb.TextColor3 = theme.text
    end)

    return tb
end

local function addLabel(parent, text)
    local ui = findPageOwner(parent)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = parent
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Size = UDim2.new(1, 0, 0, 34)
    lbl.Text = text
    bindDynamicTheme(ui, function(theme) lbl.TextColor3 = theme.subtle end)
    return lbl
end

local function wireStackPage(page, ui)
    local state = getPageState(page)
    state.baseY = 8
    state.blocks = {}
    PageOwners[page] = ui
end

local characterNonWeaponNames = {
    Humanoid = true,
    HumanoidRootPart = true,
    Head = true,
    UpperTorso = true,
    LowerTorso = true,
    Torso = true,
    LeftHand = true,
    RightHand = true,
    LeftFoot = true,
    RightFoot = true,
    LeftLowerArm = true,
    RightLowerArm = true,
    LeftUpperArm = true,
    RightUpperArm = true,
    LeftLowerLeg = true,
    RightLowerLeg = true,
    LeftUpperLeg = true,
    RightUpperLeg = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true,
    Shirt = true,
    Pants = true,
    BodyColors = true,
    Animator = true,
    Animate = true,
    Health = true,
}

local state = {
    hideTrackedWeaponParts = false,
    hideOtherPlayersWeapons = false,
    weaponDamageOverrideEnabled = false,
    weaponDamageValue = 25,
    aggressiveFxCullEnabled = false,
    hideDisappearEntities = false,
}

local trackedCharacter
local trackedWeapons = setmetatable({}, { __mode = "k" })
local trackedWeaponPartState = setmetatable({}, { __mode = "k" })
local trackedWeaponDamageState = setmetatable({}, { __mode = "k" })
local otherPlayerWeaponPartState = setmetatable({}, { __mode = "k" })
local disappearOriginalName, disappearRenamedName = "Disappear", "Disappear123"
local renamedDisappearInstance
local fxCullConnection

local function isLikelyWeaponContainerForCharacter(character, obj)
    if not character or obj.Parent ~= character then return false end
    if characterNonWeaponNames[obj.Name] then return false end
    if obj:IsA("Accessory") or obj:IsA("Clothing") or obj:IsA("BodyColors") then return false end
    if obj:IsA("Tool") then return true end
    if typeof(obj:GetAttribute("Damage")) == "number" then return true end
    if obj:IsA("BasePart") then return true end
    return obj:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function isLikelyWeaponContainer(obj)
    return isLikelyWeaponContainerForCharacter(trackedCharacter, obj)
end

local function setPartHiddenLocal(part, hide, stateTable)
    local prev = stateTable[part]
    if not prev then
        prev = { localTransparencyModifier = part.LocalTransparencyModifier }
        stateTable[part] = prev
    end
    part.LocalTransparencyModifier = hide and 1 or (prev.localTransparencyModifier or 0)
end

local function applyWeaponPartState(part)
    local prev = trackedWeaponPartState[part]
    if not prev then
        prev = { transparency = part.Transparency, canCollide = part.CanCollide }
        trackedWeaponPartState[part] = prev
    end

    if state.hideTrackedWeaponParts then
        part.LocalTransparencyModifier = 1
        part.CanCollide = false
    else
        part.LocalTransparencyModifier = 0
        part.Transparency = prev.transparency
        part.CanCollide = prev.canCollide
    end
end

local function applyDamageState(instance)
    if state.weaponDamageOverrideEnabled then
        if trackedWeaponDamageState[instance] == nil then
            trackedWeaponDamageState[instance] = instance:GetAttribute("Damage")
        end
        instance:SetAttribute("Damage", state.weaponDamageValue)
    elseif trackedWeaponDamageState[instance] ~= nil then
        instance:SetAttribute("Damage", trackedWeaponDamageState[instance])
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
end

local function untrackWeapon(container)
    trackedWeapons[container] = nil
    trackedWeaponPartState[container] = nil
    trackedWeaponDamageState[container] = nil
    for _, d in ipairs(container:GetDescendants()) do
        trackedWeaponPartState[d] = nil
        trackedWeaponDamageState[d] = nil
    end
end

local function rescanCharacterWeapons()
    if not trackedCharacter then return 0 end
    local count = 0
    local seen = {}
    for _, child in ipairs(trackedCharacter:GetChildren()) do
        if isLikelyWeaponContainer(child) then
            seen[child] = true
            trackWeapon(child)
            count += 1
        end
    end
    for weapon in pairs(trackedWeapons) do
        if not seen[weapon] or weapon.Parent ~= trackedCharacter then
            untrackWeapon(weapon)
        end
    end
    return count
end

local function applyOtherPlayersWeaponHiding()
    local hidden = 0

    for part in pairs(otherPlayerWeaponPartState) do
        if (not part) or (not part.Parent) then
            otherPlayerWeaponPartState[part] = nil
        end
    end

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.Character then
            for _, child in ipairs(other.Character:GetChildren()) do
                if isLikelyWeaponContainerForCharacter(other.Character, child) then
                    if child:IsA("BasePart") then
                        setPartHiddenLocal(child, state.hideOtherPlayersWeapons, otherPlayerWeaponPartState)
                        hidden += 1
                    end
                    for _, d in ipairs(child:GetDescendants()) do
                        if d:IsA("BasePart") then
                            setPartHiddenLocal(d, state.hideOtherPlayersWeapons, otherPlayerWeaponPartState)
                            hidden += 1
                        end
                    end
                end
            end
        end
    end

    if not state.hideOtherPlayersWeapons then
        for part in pairs(otherPlayerWeaponPartState) do
            if part and part.Parent then
                setPartHiddenLocal(part, false, otherPlayerWeaponPartState)
            end
        end
        otherPlayerWeaponPartState = setmetatable({}, { __mode = "k" })
    end

    return hidden
end

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
        if fxCullConnection then fxCullConnection:Disconnect() end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            disableFxObject(obj)
        end
        fxCullConnection = Workspace.DescendantAdded:Connect(disableFxObject)
    else
        if fxCullConnection then
            fxCullConnection:Disconnect()
            fxCullConnection = nil
        end
    end
end

local function resolveDisappearController()
    local ps = player:FindFirstChild("PlayerScripts")
    if not ps then return nil end
    local mcc = ps:FindFirstChild("MobsClientController")
    if not mcc then return nil end

    local disappearNode = mcc:FindFirstChild(disappearOriginalName)
    if disappearNode then return disappearNode end

    if renamedDisappearInstance and renamedDisappearInstance.Parent == mcc then
        return renamedDisappearInstance
    end

    local renamedNode = mcc:FindFirstChild(disappearRenamedName)
    if renamedNode then
        renamedDisappearInstance = renamedNode
        return renamedNode
    end

    return nil
end

local function setDisappearHider(enabled)
    state.hideDisappearEntities = enabled
    local node = resolveDisappearController()
    if not node then return false end

    if enabled then
        if node.Name ~= disappearRenamedName then
            local ok = pcall(function() node.Name = disappearRenamedName end)
            if ok then renamedDisappearInstance = node end
            return ok
        end
        return true
    end

    local nodeToRestore = renamedDisappearInstance
    if not nodeToRestore or not nodeToRestore.Parent then
        nodeToRestore = node
    end

    if nodeToRestore and nodeToRestore.Name == disappearRenamedName then
        local ok = pcall(function() nodeToRestore.Name = disappearOriginalName end)
        if ok then renamedDisappearInstance = nil end
        return ok
    end

    return true
end

local function resolveOptionsListButton(buttonName)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    local mainGui = playerGui:FindFirstChild("MainGUI")
    if not mainGui then return nil end
    local optionsList = mainGui:FindFirstChild("OptionsList")
    if not optionsList then return nil end
    return optionsList:FindFirstChild(buttonName)
end

local function getOptionsListButtonVisible(buttonName)
    local button = resolveOptionsListButton(buttonName)
    return button and button.Visible or false
end

local function setOptionsListButtonVisible(buttonName, enabled)
    local button = resolveOptionsListButton(buttonName)
    if not button then return false end
    return pcall(function() button.Visible = enabled end)
end

local function teleportToWorldSpawn(spawnObject)
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local targetCFrame
    if spawnObject:IsA("BasePart") then
        targetCFrame = spawnObject.CFrame
    elseif spawnObject:IsA("Model") then
        targetCFrame = spawnObject:GetPivot()
    end

    if not targetCFrame then return false end
    rootPart.CFrame = targetCFrame + Vector3.new(0, 4, 0)
    return true
end

local function bindCharacterForWeapons(character)
    trackedCharacter = character
    trackedWeapons = setmetatable({}, { __mode = "k" })
    trackedWeaponPartState = setmetatable({}, { __mode = "k" })
    trackedWeaponDamageState = setmetatable({}, { __mode = "k" })

    character.ChildAdded:Connect(function(child)
        if isLikelyWeaponContainer(child) then
            task.wait()
            trackWeapon(child)
        end
    end)

    character.ChildRemoved:Connect(function(child)
        untrackWeapon(child)
    end)

    rescanCharacterWeapons()
end

function MeerlyWin95:_buildPUMigratedWeaponsPage()
    local page = self:addPage("Weapons", "WP")
    wireStackPage(page, self)
    addHeader(page, "Weapons")

    local body = addAccordion(page, "Weapon Controls", true)

    addToggle(body, "Hide Tracked Weapon Parts", state.hideTrackedWeaponParts, function(v)
        state.hideTrackedWeaponParts = v
        rescanCharacterWeapons()
        for weapon in pairs(trackedWeapons) do
            applyWeaponState(weapon)
        end
        self:log("EVENT", v and "Tracked weapon parts hidden" or "Tracked weapon parts shown")
    end)

    addToggle(body, "Hide Other's Weapons Parts", state.hideOtherPlayersWeapons, function(v)
        state.hideOtherPlayersWeapons = v
        local hidden = applyOtherPlayersWeaponHiding()
        self:log("EVENT", v and ("Other players weapon parts hidden: " .. tostring(hidden)) or "Other players weapon parts restored")
    end)

    addButton(body, "Other's Weapons Parts", function()
        local hidden = applyOtherPlayersWeaponHiding()
        self:log("INFO", "Other-player weapon pass complete. Parts touched: " .. tostring(hidden))
    end)

    addToggle(body, "Override Weapons Damage", state.weaponDamageOverrideEnabled, function(v)
        state.weaponDamageOverrideEnabled = v
        rescanCharacterWeapons()
        for weapon in pairs(trackedWeapons) do
            applyWeaponState(weapon)
        end
        self:log("EVENT", v and ("Weapon damage override enabled: " .. tostring(state.weaponDamageValue)) or "Weapon damage override disabled")
    end)

    addTextbox(body, "Weapon Damage Value", tostring(state.weaponDamageValue), function(text)
        local v = tonumber(text)
        if v then
            state.weaponDamageValue = v
            if state.weaponDamageOverrideEnabled then
                for weapon in pairs(trackedWeapons) do
                    applyWeaponState(weapon)
                end
            end
            self:log("INFO", "Weapon damage value set to " .. tostring(state.weaponDamageValue))
        end
        return tostring(state.weaponDamageValue)
    end)

    addButton(body, "Rescan Weapons", function()
        local count = rescanCharacterWeapons()
        for weapon in pairs(trackedWeapons) do
            applyWeaponState(weapon)
        end
        self:log("EVENT", "Weapon rescan complete: " .. tostring(count) .. " tracked")
    end)

    reflowStackPage(page)
end

function MeerlyWin95:_buildPUMigratedUtilityPage()
    local page = self:addPage("Utility", "UT")
    wireStackPage(page, self)
    addHeader(page, "Utility")

    local body = addAccordion(page, "Utility Controls", true)

    addToggle(body, "Show AutoRaidBtn", getOptionsListButtonVisible("AutoRaidBtn"), function(v)
        local ok = setOptionsListButtonVisible("AutoRaidBtn", v)
        self:log(ok and "EVENT" or "WARN", ok and ("AutoRaidBtn visibility: " .. tostring(v)) or "AutoRaidBtn not found")
    end)

    addToggle(body, "Show HideMobsBtn", getOptionsListButtonVisible("HideMobsBtn"), function(v)
        local ok = setOptionsListButtonVisible("HideMobsBtn", v)
        self:log(ok and "EVENT" or "WARN", ok and ("HideMobsBtn visibility: " .. tostring(v)) or "HideMobsBtn not found")
    end)

    addToggle(body, "Hide Disappear Entities", state.hideDisappearEntities, function(v)
        local ok = setDisappearHider(v)
        self:log(ok and "EVENT" or "WARN", ok and (v and "Disappear root hidden" or "Disappear root restored") or "Disappear root not found")
    end)

    addToggle(body, "Aggressive FX Cull", state.aggressiveFxCullEnabled, function(v)
        state.aggressiveFxCullEnabled = v
        applyAggressiveFxCull(v)
        self:log("EVENT", v and "Aggressive FX culling enabled" or "Aggressive FX culling disabled")
    end)

    addLabel(body, "Aggressive FX Cull disables particle/trail/light-like effects as they spawn.")

    reflowStackPage(page)
end

function MeerlyWin95:_buildPUMigratedTeleportsPage()
    local page = self:addPage("Teleports", "TP")
    wireStackPage(page, self)
    addHeader(page, "Teleports")

    local teleportsBody = addAccordion(page, "World Teleports", true)

    local function populateWorldTeleportButtons()
        for _, child in ipairs(teleportsBody:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end

        addButton(teleportsBody, "Refresh World Teleports", function()
            populateWorldTeleportButtons()
            self:log("INFO", "World teleport list refreshed")
        end)

        local areasFolder = Workspace:FindFirstChild("Areas")
        if not areasFolder then
            addLabel(teleportsBody, "workspace.Areas not found.")
            return
        end

        local count = 0
        for _, worldFolder in ipairs(areasFolder:GetChildren()) do
            local spawnsFolder = worldFolder:FindFirstChild("SPAWNS")
            local spawnObject = spawnsFolder and spawnsFolder:FindFirstChild("SPAWN")
            if spawnObject then
                count += 1
                addButton(teleportsBody, "Teleport: " .. worldFolder.Name, function()
                    local ok = teleportToWorldSpawn(spawnObject)
                    self:log(ok and "EVENT" or "WARN", ok and ("Teleported to " .. worldFolder.Name) or ("Teleport failed for " .. worldFolder.Name))
                end)
            end
        end

        if count == 0 then
            addLabel(teleportsBody, "No world spawn entries found.")
        end
    end

    populateWorldTeleportButtons()
    reflowStackPage(page)
end

local originalBuildDefaultPages = MeerlyWin95._buildDefaultPages
function MeerlyWin95:_buildDefaultPages()
    -- Build PU pages first so they appear before library default pages in taskbar.
    self:_buildPUMigratedWeaponsPage()
    self:_buildPUMigratedUtilityPage()
    self:_buildPUMigratedTeleportsPage()
    originalBuildDefaultPages(self)
end

if player.Character then
    bindCharacterForWeapons(player.Character)
end
player.CharacterAdded:Connect(function(character)
    task.wait(0.15)
    bindCharacterForWeapons(character)
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if state.hideTrackedWeaponParts or state.weaponDamageOverrideEnabled then
            rescanCharacterWeapons()
            for weapon in pairs(trackedWeapons) do
                applyWeaponState(weapon)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(8)
        if state.hideOtherPlayersWeapons then
            applyOtherPlayersWeaponHiding()
        end
    end
end)

local app = MeerlyWin95.new({
    title = CONFIG.Title,
    toggleKey = CONFIG.ToggleKey,
    defaultThemeIndex = 2,
})

_G.MeerlyWin95_PUMigrated = app
app:log("EVENT", "PU migrated pages loaded: Weapons / Utility / Teleports")
