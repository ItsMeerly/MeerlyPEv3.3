--[[
    Meerly Untitle Melee RNG
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

_G.__MeerlyPerfState = _G.__MeerlyPerfState or {
    antiAfkEnabled = false,
    watchdogEnabled = false,
    lastHeartbeat = os.clock(),
}

_G.__MeerlyPURuntime = _G.__MeerlyPURuntime or {}

if typeof(_G.__MeerlyPURuntime.shutdown) == "function" then
    pcall(function()
        _G.__MeerlyPURuntime.shutdown("reloaded")
    end)
end

local running = true
local destroyRequested = false
local uiVisible = true

local fpsCapEnabled = false
local targetFPS = 60
local lowGraphicsEnabled = false
local streamingOptimized = false
local aggressiveFxCullEnabled = false
local hideTrackedWeaponParts = false
local weaponDamageOverride = 25
local weaponDamageOverrideOnRescan = false
local weaponDamageOverridePassActive = false
local hitboxEnlargerEnabled = false
local hideOtherPlayersWeapons = false
local otherPlayersHidePassSeconds = 10
local walkSpeedOverrideEnabled = false
local walkSpeedValue = 16
local originalWalkSpeed = nil

local hardcodedAccessKey = "ForLoveWithLove"
local keychainUrl = "https://work.ink/2kaV/meerlyunrng"

local fxCullConnection = nil
local weaponChildAddedConnection = nil
local weaponChildRemovedConnection = nil
local characterAddedConnection = nil
local lightingChildAddedConnection = nil
local heartbeatConnection = nil
local windowFocusedConnection = nil
local windowFocusReleasedConnection = nil
local inputBeganConnection = nil

local function makeWeakKeyTable()
    return setmetatable({}, { __mode = "k" })
end

local trackedCharacter = nil
local trackedWeapons = makeWeakKeyTable()
local orderedTrackedWeapons = {}
local trackedWeaponPartState = makeWeakKeyTable()
local trackedWeaponPartConnections = makeWeakKeyTable()
local trackedWeaponDamageState = makeWeakKeyTable()
local otherPlayerWeaponPartState = makeWeakKeyTable()

local backgroundMode = false
local windowFocused = true
local disable3D = false
local muteSounds = false
local hideDisappearEntities = false
local cullMobPartsEnabled = false
local disappearOriginalName = "Disappear"
local disappearRenamedName = "Disappear123"
local renamedDisappearInstance = nil

local mobsAssetsConnection = nil
local hiddenMobPartsState = makeWeakKeyTable()

local heartbeatLagThreshold = 1.5
local watchdogThreshold = 4

local memoryStatsEnabled = false
local memoryGuardMode = "Off" -- Off | AutoRejoin | AutoQuit
local memoryGuardCapGB = 10
local memoryGuardCooldown = 30
local lastMemoryGuardAction = 0
local lastGcSweep = 0
local gcSweepInterval = 30

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

-- Returns Lua heap estimate in MB.
-- Why: combining engine + Lua memory gives a more useful pressure signal
-- for guard actions than either metric alone.
local function luaMemMb()
    local ok, mb = pcall(function()
        return gcinfo() / 1024
    end)
    return ok and mb or nil
end

-- Computes memory view used by the floating panel + memory guard.
-- Why: different executors report memory inconsistently; this function normalizes
-- to a best-effort combined GB value while exposing raw components for display.
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
-- Removes/neutralizes blur effects currently present in Lighting.
-- Why: blur and post-processing can be expensive on lower-end devices and
-- this script prioritizes frame consistency over visual fidelity.
local function stripBlurEffects()
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("BlurEffect") then
            obj.Enabled = false
            obj.Size = 0
        end
    end
end

-- Applies low-visual mode toggles in a single place.
-- Why: centralizing these writes avoids desync between UI state and render state.
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
    elseif obj:IsA("Trail") then
        obj.Enabled = false
    end
end

-- Disables common high-cost effect instances globally while enabled.
-- Why: in particle-heavy combat scenarios, effects often dominate frame time.
-- This also watches new descendants so late-spawned FX are culled immediately.
local function applyAggressiveFxCull(enabled)
    if enabled then
        if fxCullConnection then
            fxCullConnection:Disconnect()
        end

        local disabledCount = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                disableFxObject(obj)
                disabledCount += 1
            end
        end

        fxCullConnection = Workspace.DescendantAdded:Connect(function(obj)
            disableFxObject(obj)
        end)

        log(string.format("Aggressive FX cull enabled (%d emitters/trails disabled)", disabledCount))
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

-- Heuristic weapon detector for character children.
-- What: filters out known body/clothing nodes and treats tools/parts/damage-tagged
-- models as likely weapons.
-- Why: game structures vary, so strict class checks miss many custom rigs.
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

-- Applies local-only hide state to a BasePart while caching previous values.
-- Why: LocalTransparencyModifier avoids server replication and lets us restore
-- previous visual state cleanly when toggles are disabled.
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

-- Slow-pass scan for non-local player weapons.
-- Why: periodic scanning is cheaper than per-instance listeners across all players,
-- and is good enough for background visual simplification.
local function applyOtherPlayersWeaponHiding()
    for part in pairs(otherPlayerWeaponPartState) do
        if (not part) or (not part.Parent) then
            otherPlayerWeaponPartState[part] = nil
        end
    end

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
        otherPlayerWeaponPartState = makeWeakKeyTable()
    end

    return hiddenCount
end

local function isLikelyWeaponContainer(obj)
    return isLikelyWeaponContainerForCharacter(trackedCharacter, obj)
end

-- Applies local visual/collision state to weapon parts for the local character only.
local function applyWeaponPartState(part)
    local state = trackedWeaponPartState[part]
    if not state then
        state = {
            localTransparencyModifier = part.LocalTransparencyModifier,
        }
        trackedWeaponPartState[part] = state
    end

    local reconnect = trackedWeaponPartConnections[part] == nil
    if reconnect then
        trackedWeaponPartConnections[part] = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
            if hideTrackedWeaponParts and part.Parent and part.LocalTransparencyModifier ~= 1 then
                part.LocalTransparencyModifier = 1
            end
        end)
    end

    if hideTrackedWeaponParts then
        part.LocalTransparencyModifier = 1
    else
        part.LocalTransparencyModifier = state.localTransparencyModifier or 0
    end
end

local function isTargetHitboxEntity(part)
    if not part:IsA("BasePart") or part.Name ~= "Hitbox" then
        return false
    end

    local children = part:GetChildren()
    if #children ~= 3 then
        return false
    end

    local attachmentCount = 0
    local trailCount = 0

    for _, child in ipairs(children) do
        if child:IsA("Attachment") and child.Name == "Attachment" then
            attachmentCount += 1
        elseif child:IsA("Trail") and child.Name == "Trail" then
            trailCount += 1
        else
            return false
        end
    end

    return attachmentCount == 2 and trailCount == 1
end

local function applyHitboxEnlarger()
    if not hitboxEnlargerEnabled then
        return
    end

    local firstWeapon = orderedTrackedWeapons[1]
    if not firstWeapon or firstWeapon.Parent ~= trackedCharacter then
        return
    end

    local enlargedCount = 0
    if isTargetHitboxEntity(firstWeapon) then
        firstWeapon.Size = Vector3.new(1000, 30, 1000)
        enlargedCount += 1
    end

    for _, descendant in ipairs(firstWeapon:GetDescendants()) do
        if isTargetHitboxEntity(descendant) then
            descendant.Size = Vector3.new(1000, 30, 1000)
            enlargedCount += 1
        end
    end

    if enlargedCount > 0 then
        log(string.format("Hitbox enlarger applied on %s (%d hitbox parts)", firstWeapon.Name, enlargedCount))
    else
        log("Hitbox enlarger found no matching Hitbox part on first tracked weapon")
    end
end

local function isTargetHitboxEntity(part)
    if not part:IsA("BasePart") or part.Name ~= "Hitbox" then
        return false
    end

    local children = part:GetChildren()
    if #children ~= 3 then
        return false
    end

    local attachmentCount = 0
    local trailCount = 0

    for _, child in ipairs(children) do
        if child:IsA("Attachment") and child.Name == "Attachment" then
            attachmentCount += 1
        elseif child:IsA("Trail") and child.Name == "Trail" then
            trailCount += 1
        else
            return false
        end
    end

    return attachmentCount == 2 and trailCount == 1
end

local function applyHitboxEnlarger()
    if not hitboxEnlargerEnabled then
        return
    end

    local firstWeapon = orderedTrackedWeapons[1]
    if not firstWeapon or firstWeapon.Parent ~= trackedCharacter then
        return
    end

    local enlargedCount = 0
    if isTargetHitboxEntity(firstWeapon) then
        firstWeapon.Size = Vector3.new(1000, 30, 1000)
        enlargedCount += 1
    end

    for _, descendant in ipairs(firstWeapon:GetDescendants()) do
        if isTargetHitboxEntity(descendant) then
            descendant.Size = Vector3.new(1000, 30, 1000)
            enlargedCount += 1
        end
    end

    if enlargedCount > 0 then
        log(string.format("Hitbox enlarger applied on %s (%d hitbox parts)", firstWeapon.Name, enlargedCount))
    else
        log("Hitbox enlarger found no matching Hitbox part on first tracked weapon")
    end
end

-- Applies/restores Damage attribute overrides while preserving original values for clean rollback.
local function applyDamageState(instance)
    if not weaponDamageOverridePassActive then
        return
    end

    local state = trackedWeaponDamageState[instance]
    if state == nil then
        state = instance:GetAttribute("Damage")
        trackedWeaponDamageState[instance] = state
    end
    instance:SetAttribute("Damage", weaponDamageOverride)
end

-- Applies current local weapon policies (hide parts + damage override)
-- to a tracked weapon container and all descendants.
-- Why: keeps behavior consistent for both initial scans and live updates.
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

-- Starts tracking a weapon container and immediately applies active policies.
-- Why: newly spawned/equipped weapons should reflect current toggles instantly.
local function trackWeapon(container)
    if trackedWeapons[container] then
        applyWeaponState(container)
        return
    end

    trackedWeapons[container] = true
    table.insert(orderedTrackedWeapons, container)
    applyWeaponState(container)
    log("Tracked weapon: " .. container.Name)
end

-- Stops tracking a weapon and clears cached restore state for its parts/attributes.
-- Why: prevents stale references and memory growth as weapons are created/removed.
local function untrackWeapon(container)
    if not trackedWeapons[container] then
        return
    end

    trackedWeapons[container] = nil

    for i = #orderedTrackedWeapons, 1, -1 do
        if orderedTrackedWeapons[i] == container then
            table.remove(orderedTrackedWeapons, i)
        end
    end

    if container:IsA("BasePart") then
        if trackedWeaponPartConnections[container] then
            trackedWeaponPartConnections[container]:Disconnect()
            trackedWeaponPartConnections[container] = nil
        end
        trackedWeaponPartState[container] = nil
        trackedWeaponDamageState[container] = nil
    end

    for _, descendant in ipairs(container:GetDescendants()) do
        if trackedWeaponPartConnections[descendant] then
            trackedWeaponPartConnections[descendant]:Disconnect()
            trackedWeaponPartConnections[descendant] = nil
        end
        trackedWeaponPartState[descendant] = nil
        trackedWeaponDamageState[descendant] = nil
    end
end

-- Full rescan of local character children for likely weapon containers.
-- Why: some games spawn/move weapon objects without consistent events, so periodic
-- rescans keep the tracker accurate.
local function rescanCharacterWeapons(silent)
    if not trackedCharacter then
        return
    end

    local trackedCount = 0
    local currentlySeen = {}
    local newOrderedWeapons = {}
    for _, child in ipairs(trackedCharacter:GetChildren()) do
        if isLikelyWeaponContainer(child) then
            currentlySeen[child] = true
            table.insert(newOrderedWeapons, child)
            trackWeapon(child)
            trackedCount += 1
        end
    end

    orderedTrackedWeapons = newOrderedWeapons

    for weapon in pairs(trackedWeapons) do
        if not currentlySeen[weapon] or weapon.Parent ~= trackedCharacter then
            untrackWeapon(weapon)
        end
    end

    if not silent then
        log(string.format("Weapon scan complete: %d tracked", trackedCount))
    end
end

-- Runs a local weapon maintenance pass.
-- Why: centralizing this prevents nil callback errors and keeps toggle/button actions consistent.
local function runSelfWeaponPass(message, opts)
    opts = opts or {}

    if opts.rescan ~= false then
        rescanCharacterWeapons(true)
    end

    weaponDamageOverridePassActive = opts.applyDamageOnce == true

    for weapon in pairs(trackedWeapons) do
        if weapon and weapon.Parent == trackedCharacter then
            applyWeaponState(weapon)
        else
            untrackWeapon(weapon)
        end
    end

    if opts.applyDamageOnce then
        weaponDamageOverrideOnRescan = false
    end

    applyHitboxEnlarger()
    weaponDamageOverridePassActive = false

    if message then
        log(message)
    end
end

-- Rebinds weapon tracking whenever the local character changes (respawn/team swap).
-- Rebinds weapon tracking to the current character model after spawn changes.
-- Why: respawns swap the character instance, so old connections/state must be reset.
local function bindCharacterForWeapons(character)
    trackedCharacter = character
    trackedWeapons = makeWeakKeyTable()
    orderedTrackedWeapons = {}
    trackedWeaponPartState = makeWeakKeyTable()
    trackedWeaponPartConnections = makeWeakKeyTable()
    trackedWeaponDamageState = makeWeakKeyTable()
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

    rescanCharacterWeapons(true)
end

local function pruneTrackedWeaponStateTables()
    for part in pairs(trackedWeaponPartState) do
        if (not part) or (not part.Parent) then
            if trackedWeaponPartConnections[part] then
                trackedWeaponPartConnections[part]:Disconnect()
                trackedWeaponPartConnections[part] = nil
            end
            trackedWeaponPartState[part] = nil
        end
    end

    for part in pairs(trackedWeaponPartConnections) do
        if (not part) or (not part.Parent) then
            trackedWeaponPartConnections[part]:Disconnect()
            trackedWeaponPartConnections[part] = nil
        end
    end

    for instance in pairs(trackedWeaponDamageState) do
        if (not instance) or (not instance.Parent) then
            trackedWeaponDamageState[instance] = nil
        end
    end
end

local function runMemorySweep(now)
    if now - lastGcSweep < gcSweepInterval then
        return
    end

    lastGcSweep = now
    pcall(function()
        collectgarbage("collect")
    end)
end

-- WalkSpeed override helper. Some games reset WalkSpeed frequently, so we re-apply on a loop.
-- Enforces optional WalkSpeed override on the local Humanoid.
-- Why: many games/scripts reset WalkSpeed; a periodic re-apply keeps the requested
-- value stable while still allowing rollback to original speed.
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

-- Best-effort FPS cap wrapper.
-- Why: setfpscap is executor-specific, so this wrapper prevents hard failures.
local function safeSetFPS(cap)
    if typeof(setfpscap) == "function" then
        pcall(function() setfpscap(cap) end)
        return true
    end
    return false
end

-- Anti-AFK pulse utility that simulates a quick Space key press.
-- Why: lightweight periodic movement input helps avoid idle kick logic.
local function pressSpace()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

-- Small UI helper to keep panel visuals consistent.
local function makeCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = obj
end

-- Small UI helper adding subtle borders for readability on dark panels.
local function makeStroke(obj)
    local s = Instance.new("UIStroke")
    s.Color = uiTheme.stroke
    s.Thickness = 1
    s.Transparency = 0.4
    s.Parent = obj
end

-- ---- Main UI construction ----
local screen = Instance.new("ScreenGui")
screen.Name = "Meerly_Unititled_Melee_RNG"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

stripBlurEffects()

lightingChildAddedConnection = Lighting.ChildAdded:Connect(function(child)
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

local tabBar = Instance.new("Frame")
tabBar.Parent = window
tabBar.Size = UDim2.new(1, -20, 0, 30)
tabBar.Position = UDim2.fromOffset(10, 44)
tabBar.BackgroundColor3 = uiTheme.panel
tabBar.BorderSizePixel = 0
tabBar.ClipsDescendants = true
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

log = function(msg)
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(msg))
    logBox.Text = line
    print("[MeerlyPerf]", msg)
end

local keyAccepted = false

local function setMainUiUnlocked(unlocked)
    keyAccepted = unlocked == true
    tabBar.Visible = keyAccepted
    tabPagesRoot.Visible = keyAccepted
    logBox.Visible = keyAccepted
    title.Text = keyAccepted and "Meerly Untitled Melee RNG - hide/open with ;" or "Key System"
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
keyLinkButton.TextSize = 12
keyLinkButton.TextColor3 = uiTheme.text
keyLinkButton.Text = "Copy work.ink keychain link"
makeCorner(keyLinkButton, 6)
makeStroke(keyLinkButton)

local keyInput = Instance.new("TextBox")
keyInput.Parent = keyGate
keyInput.Size = UDim2.new(1, -20, 0, 34)
keyInput.Position = UDim2.fromOffset(10, 162)
keyInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
keyInput.BorderSizePixel = 0
keyInput.Font = Enum.Font.Gotham
keyInput.TextSize = 13
keyInput.TextColor3 = uiTheme.text
keyInput.PlaceholderText = "Enter key here..."
keyInput.Text = ""
keyInput.ClearTextOnFocus = false
makeCorner(keyInput, 6)

local keySubmit = Instance.new("TextButton")
keySubmit.Parent = keyGate
keySubmit.Size = UDim2.new(1, -20, 0, 34)
keySubmit.Position = UDim2.fromOffset(10, 208)
keySubmit.BackgroundColor3 = uiTheme.accent
keySubmit.BorderSizePixel = 0
keySubmit.Font = Enum.Font.GothamBold
keySubmit.TextSize = 12
keySubmit.TextColor3 = Color3.fromRGB(10, 10, 12)
keySubmit.Text = "Unlock Menu"
makeCorner(keySubmit, 6)

local keyStatus = Instance.new("TextLabel")
keyStatus.Parent = keyGate
keyStatus.Size = UDim2.new(1, -20, 0, 44)
keyStatus.Position = UDim2.fromOffset(10, 252)
keyStatus.BackgroundTransparency = 1
keyStatus.Font = Enum.Font.Code
keyStatus.TextSize = 12
keyStatus.TextWrapped = true
keyStatus.TextColor3 = uiTheme.subtle
keyStatus.TextXAlignment = Enum.TextXAlignment.Left
keyStatus.TextYAlignment = Enum.TextYAlignment.Top
keyStatus.Text = "Locked: menu tabs are hidden until key validation succeeds."

keyLinkButton.MouseButton1Click:Connect(function()
    local copied = false
    if setclipboard then
        pcall(function()
            setclipboard(keychainUrl)
            copied = true
        end)
    end

    if copied then
        keyStatus.Text = "Link copied to clipboard: " .. keychainUrl
    else
        keyStatus.Text = "Open this keychain URL manually: " .. keychainUrl
    end
end)

local function tryUnlockWithKey()
    local enteredKey = keyInput.Text
    if enteredKey == hardcodedAccessKey then
        setMainUiUnlocked(true)
        keyGate.Visible = false
        keyStatus.Text = "Access granted."
        log("Key accepted. Main menu unlocked")
    else
        keyStatus.Text = "Invalid key. Please retry via the work.ink keychain."
        log("Invalid key entry")
    end
end

keySubmit.MouseButton1Click:Connect(tryUnlockWithKey)
keyInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        tryUnlockWithKey()
    end
end)

local tabPages = {}
local tabButtons = {}
local currentTabName = "OP Settings"
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

createTab("OP Settings")
createTab("Utility")
createTab("Settings")
createTab("Teleports")

-- Keep tab buttons contained within bar width regardless of window size.
local tabNames = { "OP Settings", "Utility", "Settings", "Teleports" }
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

switchTab("OP Settings")

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
    tabName = tabName or currentTabName
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
    local function invokeCallback(nextState)
        local ok, err = pcall(function()
            callback(nextState)
        end)
        if not ok then
            warn(string.format("[MeerlyPerf] Toggle callback failed (%s): %s", tostring(labelText), tostring(err)))
            if log then
                log(string.format("Toggle error (%s): %s", tostring(labelText), tostring(err)))
            end
        end
    end

    local function refresh()
        button.Text = state and "ON" or "OFF"
        button.BackgroundColor3 = state and uiTheme.accent or Color3.fromRGB(70, 70, 82)
        button.TextColor3 = state and Color3.fromRGB(10, 10, 12) or uiTheme.text
    end

    button.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        invokeCallback(state)
    end)


    refresh()
    invokeCallback(state)

    return {
        set = function(v)
            state = v == true
            refresh()
            invokeCallback(state)
        end,
        get = function()
            return state
        end,
    }
end

-- Generic input row factory.
-- What: commits value on focus loss, allowing validation/coercion in onCommit.
-- Why: avoids duplicated textbox plumbing for each numeric setting.
local function makeInput(labelText, defaultText, onCommit, tabName)
    tabName = tabName or currentTabName
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
        local nextText = onCommit(box.Text)
        if nextText ~= nil then
            box.Text = tostring(nextText)
        end
    end)


    return box
end

-- Input row with a right-side action button.
-- What: commits text as usual and exposes a companion click action in the same row.
-- Why: weapon damage override is an action workflow, not a persistent ON/OFF mode.
local function makeInputWithButton(labelText, defaultText, onCommit, buttonText, onButtonClick, tabName)
    tabName = tabName or currentTabName
    local row = newRow(34, tabName)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(0.36, -10, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = uiTheme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText

    local compactLayout = tostring(labelText or "") == ""
    if compactLayout then
        label.Visible = false
    end

    local box = Instance.new("TextBox")
    box.Parent = row
    box.Size = compactLayout and UDim2.new(0.62, -6, 1, -8) or UDim2.new(0.31, -6, 1, -8)
    box.Position = compactLayout and UDim2.new(0.04, 0, 0, 4) or UDim2.new(0.37, 0, 0, 4)
    box.BackgroundColor3 = Color3.fromRGB(48, 48, 60)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextColor3 = uiTheme.text
    box.Text = tostring(defaultText or "")
    makeCorner(box, 5)

    local button = Instance.new("TextButton")
    button.Parent = row
    button.Size = UDim2.new(0.28, -8, 1, -8)
    button.Position = UDim2.new(0.69, 0, 0, 4)
    button.BackgroundColor3 = uiTheme.accent
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.TextColor3 = Color3.fromRGB(10, 10, 12)
    button.Text = buttonText
    makeCorner(button, 5)

    local function commit()
        local ok, newText = pcall(function()
            return onCommit(box.Text)
        end)
        if ok and newText ~= nil then
            box.Text = tostring(newText)
        elseif not ok then
            warn(string.format("[MeerlyPerf] Input callback failed (%s): %s", tostring(labelText), tostring(newText)))
            if log then
                log(string.format("Input error (%s): %s", tostring(labelText), tostring(newText)))
            end
        end
    end

    box.FocusLost:Connect(function()
        commit()
    end)

    button.MouseButton1Click:Connect(function()
        commit()
        local ok, err = pcall(onButtonClick)
        if not ok then
            warn(string.format("[MeerlyPerf] Button callback failed (%s): %s", tostring(buttonText), tostring(err)))
            if log then
                log(string.format("Button error (%s): %s", tostring(buttonText), tostring(err)))
            end
        end
    end)

    return row, box, button
end

-- Generic action button row factory.
-- Why: one pathway for action rows makes spacing/layout consistent everywhere.
local function makeButton(text, onClick, tabName)
    tabName = tabName or currentTabName
    local row = newRow(34, tabName)
    local btn = Instance.new("TextButton")
    btn.Parent = row
    btn.Size = UDim2.new(0.88, -8, 1, -8)
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

local function makeSectionLabel(text, tabName)
    local row = newRow(30, tabName)
    row.BackgroundTransparency = 1

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(1, -8, 1, 0)
    label.Position = UDim2.fromOffset(8, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = uiTheme.subtle
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    return label
end

local function clearTabRows(tabName)
    local page = tabPages[tabName]
    if not page then
        return
    end
    for _, child in ipairs(page:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end

local memoryGui = Instance.new("ScreenGui")
memoryGui.Name = "Meerly_Untitled_Melee_RNG"
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

local function resolveDisappearController()
    local playerScripts = player:FindFirstChild("PlayerScripts")
    if not playerScripts then
        return nil, "PlayerScripts not found"
    end

    local mobsClientController = playerScripts:FindFirstChild("MobsClientController")
    if not mobsClientController then
        return nil, "MobsClientController not found"
    end

    local disappearNode = mobsClientController:FindFirstChild(disappearOriginalName)
    if disappearNode then
        return disappearNode
    end

    if renamedDisappearInstance and renamedDisappearInstance.Parent == mobsClientController then
        return renamedDisappearInstance
    end

    local renamedNode = mobsClientController:FindFirstChild(disappearRenamedName)
    if renamedNode then
        renamedDisappearInstance = renamedNode
        return renamedNode
    end

    return nil, "Disappear root not found"
end

local function setDisappearHider(enabled)
    hideDisappearEntities = enabled

    local disappearNode, reason = resolveDisappearController()
    if not disappearNode then
        log(string.format("Disappear toggle failed: %s", tostring(reason)))
        return
    end

    if enabled then
        if disappearNode.Name == disappearRenamedName then
            renamedDisappearInstance = disappearNode
            log("Disappear root already renamed")
            return
        end

        local ok, err = pcall(function()
            disappearNode.Name = disappearRenamedName
        end)
        if ok then
            renamedDisappearInstance = disappearNode
            log(string.format("Disappear root renamed to '%s'", disappearRenamedName))
        else
            log("Failed to rename Disappear root: " .. tostring(err))
        end
    else
        local nodeToRestore = renamedDisappearInstance
        if not nodeToRestore or not nodeToRestore.Parent then
            nodeToRestore = disappearNode
        end

        if not nodeToRestore or nodeToRestore.Name ~= disappearRenamedName then
            log("Disappear root already restored")
            return
        end

        local ok, err = pcall(function()
            nodeToRestore.Name = disappearOriginalName
        end)
        if ok then
            renamedDisappearInstance = nil
            log("Disappear root restored to 'Disappear'")
        else
            log("Failed to restore Disappear root: " .. tostring(err))
        end
    end
end

local function isBossMobPart(part)
    local cursor = part
    while cursor and cursor ~= ReplicatedStorage do
        local lowerName = string.lower(cursor.Name)
        if lowerName == "boss" or lowerName == "bosses" or string.find(lowerName, "boss", 1, true) then
            return true
        end
        cursor = cursor.Parent
    end
    return false
end

local function resolveMobsAssetsFolder()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        return nil, "ReplicatedStorage.Assets not found"
    end

    local mobs = assets:FindFirstChild("Mobs")
    if not mobs then
        return nil, "ReplicatedStorage.Assets.Mobs not found"
    end

    return mobs
end

local function hideMobPart(part)
    if hiddenMobPartsState[part] or isBossMobPart(part) then
        return false
    end

    hiddenMobPartsState[part] = {
        parent = part.Parent,
    }
    part.Parent = nil
    return true
end

local function restoreHiddenMobParts()
    local restored = 0
    for part, state in pairs(hiddenMobPartsState) do
        if part and part.Parent == nil and state and state.parent and state.parent.Parent then
            pcall(function()
                part.Parent = state.parent
            end)
            restored += 1
        end
        hiddenMobPartsState[part] = nil
    end
    return restored
end

local function applyMobPartsCull(enabled)
    cullMobPartsEnabled = enabled

    if mobsAssetsConnection then
        mobsAssetsConnection:Disconnect()
        mobsAssetsConnection = nil
    end

    local mobsFolder, reason = resolveMobsAssetsFolder()
    if not mobsFolder then
        log("Mob parts cull failed: " .. tostring(reason))
        return
    end

    if enabled then
        local hidden = 0
        for _, obj in ipairs(mobsFolder:GetDescendants()) do
            if obj:IsA("BasePart") and hideMobPart(obj) then
                hidden += 1
            end
        end

        mobsAssetsConnection = mobsFolder.DescendantAdded:Connect(function(obj)
            if cullMobPartsEnabled and obj:IsA("BasePart") then
                pcall(function()
                    hideMobPart(obj)
                end)
            end
        end)

        log(string.format("Mob parts culled (hidden: %d, bosses ignored)", hidden))
    else
        local restored = restoreHiddenMobParts()
        log(string.format("Mob parts cull disabled (restored: %d)", restored))
    end
end

local function resolveOptionsListButton(buttonName)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil, "PlayerGui not found"
    end

    local mainGui = playerGui:FindFirstChild("MainGUI")
    if not mainGui then
        return nil, "MainGUI not found"
    end

    local optionsList = mainGui:FindFirstChild("OptionsList")
    if not optionsList then
        return nil, "OptionsList not found"
    end

    local button = optionsList:FindFirstChild(buttonName)
    if not button then
        return nil, buttonName .. " not found"
    end

    return button
end

local function getOptionsListButtonVisible(buttonName)
    local button = resolveOptionsListButton(buttonName)
    return button and button.Visible or false
end

local function setOptionsListButtonVisible(buttonName, enabled)
    local button, reason = resolveOptionsListButton(buttonName)
    if not button then
        log(string.format("%s visibility toggle failed: %s", buttonName, tostring(reason)))
        return
    end

    local ok, err = pcall(function()
        button.Visible = enabled
    end)

    if ok then
        log(string.format("%s visibility set to %s", buttonName, enabled and "ON" or "OFF"))
    else
        log(string.format("Failed to set %s visibility: %s", buttonName, tostring(err)))
    end
end

-- ---- Feature wiring (UI -> behavior) ----

-- OP Settings page.
makeSectionLabel("Weapon Damage Override", "OP Settings")
makeInputWithButton("", tostring(weaponDamageOverride), function(text)
    local v = tonumber(text)
    if v then
        weaponDamageOverride = v
    end
    return tostring(weaponDamageOverride)
end, "SCAN", function()
    weaponDamageOverrideOnRescan = true
    runSelfWeaponPass("Weapon damage override applied: " .. tostring(weaponDamageOverride), { applyDamageOnce = true })
end, "OP Settings")

makeToggle("Hitbox Enlarger", hitboxEnlargerEnabled, function(v)
    hitboxEnlargerEnabled = v
    runSelfWeaponPass(v and "Hitbox enlarger enabled" or "Hitbox enlarger disabled")
end, "OP Settings")

makeToggle("Hide Disappear Entities", hideDisappearEntities, function(v)
    setDisappearHider(v)
end, "OP Settings")

makeToggle("Aggressive FX Cull", aggressiveFxCullEnabled, function(v)
    aggressiveFxCullEnabled = v
    applyAggressiveFxCull(v)
end, "OP Settings")

makeToggle("Cull Mob Parts - Custom Hide Mobs", cullMobPartsEnabled, function(v)
    applyMobPartsCull(v)
end, "OP Settings")

makeSectionLabel("GamepassBypass:", "OP Settings")
makeButton("ShowAutoRaid", function()
    setOptionsListButtonVisible("AutoRaidBtn", true)
end, "OP Settings")

makeButton("ShowHideMobs", function()
    setOptionsListButtonVisible("HideMobsBtn", true)
end, "OP Settings")

-- Utility page.
makeSectionLabel("Game Utils", "Utility")
makeToggle("Hide Tracked Weapon Parts", hideTrackedWeaponParts, function(v)
    hideTrackedWeaponParts = v
    runSelfWeaponPass(v and "Tracked weapon parts hidden (local visual only)" or "Tracked weapon parts shown")
end, "Utility")

makeToggle("Hide Other's Weapon Parts", hideOtherPlayersWeapons, function(v)
    hideOtherPlayersWeapons = v
    local hiddenCount = applyOtherPlayersWeaponHiding()
    if v then
        log(string.format("Other-player weapon hide enabled (pass: %ds, parts: %d)", otherPlayersHidePassSeconds, hiddenCount))
    else
        log("Other-player weapon hide disabled")
    end
end, "Utility")

makeSectionLabel("Quick Utils", "Utility")
makeToggle("Memory Stats Floating UI", memoryStatsEnabled, function(v)
    memoryStatsEnabled = v
    memoryGui.Enabled = v
    log(v and "Memory stats enabled" or "Memory stats disabled")
end, "Utility")

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
end, "Utility")

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
end, "Utility")

makeButton("GC Sweep", function()
    collectgarbage("collect")
    log("Manual GC sweep complete")
end, "Utility")

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
end, "Utility")

-- Settings page.
makeSectionLabel("Performance", "Settings")
makeToggle("Low Graphics Mode", lowGraphicsEnabled, function(v)
    lowGraphicsEnabled = v
    applyVisuals(v)
    log(v and "Low graphics enabled" or "Low graphics disabled")
end, "Settings")

makeToggle("Streaming Optimisations", streamingOptimized, function(v)
    streamingOptimized = v
    if v then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        pcall(function() settings().Network.IncomingReplicationLag = 0.1 end)
        log("Streaming optimization enabled")
    else
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        log("Streaming optimization disabled")
    end
end, "Settings")

makeToggle("Mute Game Sounds", muteSounds, function(v)
    muteSounds = v
    pcall(function() SoundService.RespectFilteringEnabled = true end)
    pcall(function() SoundService.Volume = v and 0 or 1 end)
    log(v and "Game sounds muted" or "Game sounds unmuted")
end, "Settings")

makeSectionLabel("AFK", "Settings")
makeToggle("Anti-Afk", _G.__MeerlyPerfState.antiAfkEnabled, function(v)
    _G.__MeerlyPerfState.antiAfkEnabled = v
    log(v and "Anti-AFK enabled" or "Anti-AFK disabled")
end, "Settings")

makeToggle("Watchdog", _G.__MeerlyPerfState.watchdogEnabled, function(v)
    _G.__MeerlyPerfState.watchdogEnabled = v
    log(v and "Watchdog enabled" or "Watchdog disabled")
end, "Settings")

makeToggle("Background Survival Mode", backgroundMode, function(v)
    backgroundMode = v
    log(v and "Background mode enabled" or "Background mode disabled")
end, "Settings")

makeToggle("Disable 3D Rendering", disable3D, function(v)
    disable3D = v
    if RunService.Set3dRenderingEnabled then
        pcall(function() RunService:Set3dRenderingEnabled(not v) end)
        log(v and "3D rendering disabled" or "3D rendering enabled")
    else
        log("3D render toggle unsupported")
    end
end, "Settings")

local modeButton
modeButton = makeButton("Memory Action: Off", function()
    local order = { "Off", "AutoRejoin", "AutoQuit" }
    local idx = table.find(order, memoryGuardMode) or 1
    idx = (idx % #order) + 1
    memoryGuardMode = order[idx]
    modeButton.Text = "Memory Action: " .. memoryGuardMode
    log("Memory guard mode: " .. memoryGuardMode)
end, "Settings")
modeButton.Text = "Memory Action: " .. memoryGuardMode

makeInput("Memory Cap (GB)", tostring(memoryGuardCapGB), function(text)
    local v = tonumber(text)
    if v and v >= 0.5 and v <= 128 then
        memoryGuardCapGB = v
    end
    return tostring(memoryGuardCapGB)
end, "Settings")

local function teleportToWorldSpawn(spawnObject)
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        log("Teleport failed: HumanoidRootPart not found")
        return
    end

    local targetCFrame
    if spawnObject:IsA("BasePart") then
        targetCFrame = spawnObject.CFrame
    elseif spawnObject:IsA("Model") then
        targetCFrame = spawnObject:GetPivot()
    end

    if not targetCFrame then
        log("Teleport failed: unsupported spawn object type")
        return
    end

    rootPart.CFrame = targetCFrame + Vector3.new(0, 4, 0)
end

local function populateTeleportsTab()
    clearTabRows("Teleports")
    makeSectionLabel("Teleports", "Teleports")
    makeButton("Refresh World Spawns", function()
        populateTeleportsTab()
        log("World spawn list refreshed")
    end, "Teleports")

    local areasFolder = Workspace:FindFirstChild("Areas")
    if not areasFolder then
        makeSectionLabel("workspace.Areas not found.", "Teleports")
        return
    end

    local spawnCount = 0
    for _, worldFolder in ipairs(areasFolder:GetChildren()) do
        local spawnsFolder = worldFolder:FindFirstChild("SPAWNS")
        local spawnObject = spawnsFolder and spawnsFolder:FindFirstChild("SPAWN")
        if spawnObject then
            spawnCount += 1
            makeButton("Teleport: " .. worldFolder.Name, function()
                teleportToWorldSpawn(spawnObject)
                log("Teleported to world spawn: " .. worldFolder.Name)
            end, "Teleports")
        end
    end

    if spawnCount == 0 then
        makeSectionLabel("No world spawn entries found.", "Teleports")
    end
end

populateTeleportsTab()

local function requestShutdown(reason)
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
    if lightingChildAddedConnection then
        pcall(function() lightingChildAddedConnection:Disconnect() end)
        lightingChildAddedConnection = nil
    end
    if heartbeatConnection then
        pcall(function() heartbeatConnection:Disconnect() end)
        heartbeatConnection = nil
    end
    if windowFocusedConnection then
        pcall(function() windowFocusedConnection:Disconnect() end)
        windowFocusedConnection = nil
    end
    if windowFocusReleasedConnection then
        pcall(function() windowFocusReleasedConnection:Disconnect() end)
        windowFocusReleasedConnection = nil
    end
    if inputBeganConnection then
        pcall(function() inputBeganConnection:Disconnect() end)
        inputBeganConnection = nil
    end
    if cullMobPartsEnabled then
        pcall(function()
            applyMobPartsCull(false)
        end)
    end
    if hideDisappearEntities then
        pcall(function()
            setDisappearHider(false)
        end)
    end
    pcall(function() screen:Destroy() end)
    pcall(function() memoryGui:Destroy() end)

    _G.__MeerlyPURuntime = {}
    pcall(function()
        collectgarbage("collect")
    end)

    if reason ~= "reloaded" then
        log("UI destroyed")
    end
end

_G.__MeerlyPURuntime.shutdown = requestShutdown

-- Hard shutdown path: disconnect loops/listeners and destroy UI safely.
makeButton("KILL SWITCH", function()
    requestShutdown("killswitch")
end, "Utility")

windowFocusedConnection = UserInputService.WindowFocused:Connect(function()
    windowFocused = true
    if backgroundMode then
        log("Window focused")
    end
end)

inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Semicolon then
        uiVisible = not uiVisible
        screen.Enabled = uiVisible
        log(uiVisible and "UI shown (; hotkey)" or "UI hidden (; hotkey)")
    end
end)

windowFocusReleasedConnection = UserInputService.WindowFocusReleased:Connect(function()
    windowFocused = false
    if backgroundMode then
        log("Window unfocused (background mode active)")
    end
end)

-- ---- Background loops/watchers ----
-- Heartbeat watchdog source timestamp update.
-- Why: heartbeat gaps are a simple signal for frame stalls/freezes.
heartbeatConnection = RunService.Heartbeat:Connect(function()
    local now = os.clock()
    local prev = _G.__MeerlyPerfState.lastHeartbeat or now
    local delta = now - prev
    _G.__MeerlyPerfState.lastHeartbeat = now
    if delta > heartbeatLagThreshold then
        log(string.format("Heartbeat lag detected: %.2fs", delta))
    end
end)

-- Anti-AFK worker: emits a space pulse every 10 minutes while enabled.
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

-- Watchdog worker: logs if heartbeat appears delayed beyond threshold.
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

-- Background worker: drops quality when unfocused and background mode is on.
task.spawn(function()
    while running do
        task.wait(2)
        if backgroundMode and not windowFocused then
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        end
    end
end)

-- Memory panel worker: refreshes floating memory telemetry.
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

-- Memory guard worker: executes auto-action when memory cap is exceeded.
task.spawn(function()
    while running do
        task.wait(5)
        local now = os.clock()
        local combinedGb = getCombinedMemoryGb()
        runMemorySweep(now)

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

-- Weapon maintenance worker: periodic correction for hidden/damage state drift.
-- Why: some games/scripts recreate or mutate weapon visuals/attributes after equip,
-- so this pass reapplies active policies and prunes stale cached references.
task.spawn(function()
    while running do
        task.wait(0.5)
        if hideTrackedWeaponParts then
            rescanCharacterWeapons(true)
            for weapon in pairs(trackedWeapons) do
                applyWeaponState(weapon)
            end
        end
        pruneTrackedWeaponStateTables()
    end
end)

-- Other-player hide worker: intentionally slow cadence to minimize overhead.
task.spawn(function()
    while running do
        task.wait(otherPlayersHidePassSeconds)
        if hideOtherPlayersWeapons then
            applyOtherPlayersWeaponHiding()
        end
    end
end)

-- WalkSpeed enforcement worker: reapplies override if external scripts change it.
task.spawn(function()
    while running do
        task.wait(0.75)
        if walkSpeedOverrideEnabled then
            applyWalkSpeed()
        end
    end
end)

log("Meerly Untitled Melee RNG Script Loaded")
