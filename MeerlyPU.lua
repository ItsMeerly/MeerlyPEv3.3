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
local hitboxEnlargerEnabled = false
local hitboxExpanderMasterEnabled = false
local hitboxPresetRows = {}
local hitboxPresetUiRows = {}
local hitboxPresetHeaderLabel = nil
local hitboxPresetSelection = "Potato PC"
local activeHitboxPreset = "Potato PC"
local hitboxOriginalSizes = {}
local hitboxPulseToken = 0
local hitboxPresetScanIntervals = {
    ["Boss Raids"] = 0.1,
    ["High Performance"] = 0.2,
    ["Medium Performance"] = 0.4,
    ["Low Performance"] = 0.6,
}
local hitboxPresetSizes = {
    ["Boss Raids"] = Vector3.new(250, 200, 250),
    ["High Performance"] = Vector3.new(480, 200, 480),
    ["Medium Performance"] = Vector3.new(250, 100, 250),
    ["Low Performance"] = Vector3.new(150, 100, 150),
    ["Potato PC"] = Vector3.new(1000, 300, 1000),
}
local hideOtherPlayersWeapons = false
local otherPlayersHidePassSeconds = 10
local walkSpeedOverrideEnabled = false
local walkSpeedValue = 16
local originalWalkSpeed = nil
local autoFusionEnabled = false
local fusionStatusOutput = nil
local fusionSettings = {
    All = { enabled = true, min = 10, max = math.huge },
    Uncommon = { enabled = true, min = 10, max = 40 },
    Rare = { enabled = true, min = 60, max = 150 },
    Epic = { enabled = true, min = 320, max = 4700 },
    Legendary = { enabled = true, min = 8500, max = 43000 },
    Mythic = { enabled = true, min = 71000, max = 770000 },
}
local sacrificeAutoEnabled = false
local sacrificeByColorEnabled = true
local sacrificeKeepQuantity = 2
local sacrificeRarityCapIndex = 3
local sacrificeStatusOutput = nil
local sacrificeLastActionOutput = nil
local sacrificeInventory = {}
local weaponFusionTabEnabled = false
local autoUpgradeEnabled = false
local upgradeSelected = {}
local upgradeLevelCap = {}
local upgradeStatusLabel = nil
local upgradeInfoLabel = nil
local upgradeLiveOutput = nil
local upgradeLastAttemptAt = 0
local upgradeLastStatusRefresh = 0
local sacrificeTierCaps = {
    { label = "Common (<= 5)", cap = 5 },
    { label = "Uncommon (<= 50)", cap = 50 },
    { label = "Rare (<= 200)", cap = 200 },
    { label = "Epic (<= 5k)", cap = 5000 },
    { label = "Legendary (<= 50k)", cap = 50000 },
    { label = "Mythic (<= 1M)", cap = 1000000 },
    { label = "Galactic (<= 7M)", cap = 7000000 },
    { label = "Godly (<= 11M)", cap = 11000000 },
    { label = "Omni (<= 99M)", cap = 99000000 },
}

local hardcodedAccessKey = "TheyPatchedUsOnce"
local keychainUrl = "https://work.ink/2kaV/meerlymrng2"

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
local trackedWeaponFxState = makeWeakKeyTable()
hitboxOriginalSizes = makeWeakKeyTable()
local otherPlayerWeaponPartState = makeWeakKeyTable()
local otherPlayerWeaponFxState = makeWeakKeyTable()

local backgroundMode = false
local windowFocused = true
local disable3D = false
local muteSounds = false
local hideDisappearEntities = false
local cullMobPartsEnabled = false
local uiUtilityState = {
    hideManaKillsEnabled = false,
    hideMiniRollEnabled = false,
    hideHudEnabled = false,
    originalVisibility = {},
}
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

local UPGRADE_ORDER = {
    "Weapons Equipped",
    "Damage Multiplier",
    "Enemy Spawn Rate",
    "Enemy Limit",
    "Mana Multiplier",
    "Spin Speed",
    "RNG Luck",
    "Kill Multiplier",
    "Skill Point Multiplier",
    "Boss Spawn Chance",
}

local UPGRADE_PRICES = {
    ["Weapons Equipped"] = function(p) return 1 + p^2 * p end,
    ["Damage Multiplier"] = function(p) return p^4 + 5 end,
    ["Enemy Spawn Rate"] = function(p) return math.floor(p^1.5 + 10) end,
    ["Enemy Limit"] = function(p) return math.floor(p^1.1 + 1 + 0.5) end,
    ["Mana Multiplier"] = function(p) return math.floor(8 + p^2.35 * p + 0.5) end,
    ["Spin Speed"] = function(p) return p^4 + 5 end,
    ["RNG Luck"] = function(p) return p^4 + 5 end,
    ["Kill Multiplier"] = function(p) return math.floor(p^3.9 + 100 + 0.5) end,
    ["Skill Point Multiplier"] = function(p) return math.floor(p^4.5 + 0.5) + 1 end,
    ["Boss Spawn Chance"] = function(p) return math.floor(p^4 + 0.5) + 150 end,
}

for _, upgradeName in ipairs(UPGRADE_ORDER) do
    upgradeSelected[upgradeName] = false
end

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

local function isWeaponFxInstance(instance)
    return instance:IsA("ParticleEmitter")
        or instance:IsA("Trail")
        or instance:IsA("Beam")
        or instance:IsA("Smoke")
        or instance:IsA("Fire")
        or instance:IsA("Sparkles")
end

local function setWeaponFxHiddenLocal(instance, hide, stateTable)
    if not isWeaponFxInstance(instance) then
        return
    end

    local state = stateTable[instance]
    if not state then
        state = {}
        local okEnabled, enabled = pcall(function()
            return instance.Enabled
        end)
        if okEnabled then
            state.enabled = enabled
        end

        if instance:IsA("ParticleEmitter") then
            local okRate, rate = pcall(function()
                return instance.Rate
            end)
            if okRate then
                state.rate = rate
            end
        end
        stateTable[instance] = state
    end

    if hide then
        pcall(function()
            instance.Enabled = false
        end)
        if instance:IsA("ParticleEmitter") then
            pcall(function()
                instance.Rate = 0
            end)
        end
    else
        if state.enabled ~= nil then
            pcall(function()
                instance.Enabled = state.enabled
            end)
        end
        if instance:IsA("ParticleEmitter") and state.rate ~= nil then
            pcall(function()
                instance.Rate = state.rate
            end)
        end
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
    for fx in pairs(otherPlayerWeaponFxState) do
        if (not fx) or (not fx.Parent) then
            otherPlayerWeaponFxState[fx] = nil
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
                        elseif isWeaponFxInstance(descendant) then
                            setWeaponFxHiddenLocal(descendant, hideOtherPlayersWeapons, otherPlayerWeaponFxState)
                        end
                    end
                    if isWeaponFxInstance(child) then
                        setWeaponFxHiddenLocal(child, hideOtherPlayersWeapons, otherPlayerWeaponFxState)
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
        for fx in pairs(otherPlayerWeaponFxState) do
            if fx and fx.Parent then
                setWeaponFxHiddenLocal(fx, false, otherPlayerWeaponFxState)
            end
        end
        otherPlayerWeaponPartState = makeWeakKeyTable()
        otherPlayerWeaponFxState = makeWeakKeyTable()
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

local function restoreTrackedHitboxDefaults(silent)
    hitboxPulseToken += 1
    local restoredCount = 0
    for hitbox, defaultSize in pairs(hitboxOriginalSizes) do
        if hitbox and hitbox.Parent and hitbox:IsA("BasePart") then
            hitbox.Size = defaultSize
            restoredCount += 1
        end
        hitboxOriginalSizes[hitbox] = nil
    end
    if (not silent) and restoredCount > 0 then
        log(string.format("Hitbox defaults restored: %d", restoredCount))
    end
end

local function collectTrackedHitboxes(targetPreset)
    local hitboxes = {}
    local scannedWeapons = 0
    local allowSingleWeapon = targetPreset == "Potato PC"

    for _, weapon in ipairs(orderedTrackedWeapons) do
        if weapon and weapon.Parent == trackedCharacter then
            scannedWeapons += 1
            local weaponHitboxes = {}

            if isTargetHitboxEntity(weapon) then
                table.insert(weaponHitboxes, weapon)
            end

            for _, descendant in ipairs(weapon:GetDescendants()) do
                if isTargetHitboxEntity(descendant) then
                    table.insert(weaponHitboxes, descendant)
                end
            end

            if #weaponHitboxes > 0 then
                for _, hitbox in ipairs(weaponHitboxes) do
                    table.insert(hitboxes, hitbox)
                end
                if allowSingleWeapon then
                    break
                end
            end
        end
    end

    return hitboxes, scannedWeapons
end

local function applyHitboxEnlarger(presetName, silent)
    if not hitboxEnlargerEnabled then
        return
    end

    local targetPreset = presetName or activeHitboxPreset or "Potato PC"
    local targetSize = hitboxPresetSizes[targetPreset]
    if not targetSize then
        return
    end

    if not trackedCharacter or not trackedCharacter.Parent then
        return
    end

    local pulseToken = hitboxPulseToken + 1
    hitboxPulseToken = pulseToken
    local pulseSize = Vector3.new(0.01, 0.01, 0.01)
    local hitboxes, scannedWeapons = collectTrackedHitboxes(targetPreset)

    for _, hitbox in ipairs(hitboxes) do
        if not hitboxOriginalSizes[hitbox] then
            hitboxOriginalSizes[hitbox] = hitbox.Size
        end
        hitbox.Size = pulseSize
    end

    task.delay(0.1, function()
        if (not running) or (not hitboxEnlargerEnabled) or hitboxPulseToken ~= pulseToken then
            return
        end
        local delayedPreset = presetName or activeHitboxPreset or "Potato PC"
        local delayedSize = hitboxPresetSizes[delayedPreset]
        if not delayedSize then
            return
        end
        for _, hitbox in ipairs(hitboxes) do
            if hitbox and hitbox.Parent and isTargetHitboxEntity(hitbox) then
                hitbox.Size = delayedSize
            end
        end
    end)

    local enlargedCount = #hitboxes
    if not silent and enlargedCount > 0 then
        log(string.format(
            "Hitbox [%s] scan complete: %d weapons, %d hitboxes @ %.0f, %.0f, %.0f",
            targetPreset,
            scannedWeapons,
            enlargedCount,
            targetSize.X,
            targetSize.Y,
            targetSize.Z
        ))
    elseif not silent then
        log(string.format("Hitbox [%s] scan found no matching hitboxes", targetPreset))
    end
end

-- Applies current local weapon policies (hide parts)
-- to a tracked weapon container and all descendants.
-- Why: keeps behavior consistent for both initial scans and live updates.
local function applyWeaponState(container)
    if container:IsA("BasePart") then
        applyWeaponPartState(container)
    elseif isWeaponFxInstance(container) then
        setWeaponFxHiddenLocal(container, hideTrackedWeaponParts, trackedWeaponFxState)
    end

    for _, descendant in ipairs(container:GetDescendants()) do
        if descendant:IsA("BasePart") then
            applyWeaponPartState(descendant)
        elseif isWeaponFxInstance(descendant) then
            setWeaponFxHiddenLocal(descendant, hideTrackedWeaponParts, trackedWeaponFxState)
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

-- Stops tracking a weapon and clears cached restore state for its parts/fx.
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
        hitboxOriginalSizes[container] = nil
        if trackedWeaponPartConnections[container] then
            trackedWeaponPartConnections[container]:Disconnect()
            trackedWeaponPartConnections[container] = nil
        end
        trackedWeaponPartState[container] = nil
        trackedWeaponFxState[container] = nil
    end

    for _, descendant in ipairs(container:GetDescendants()) do
        hitboxOriginalSizes[descendant] = nil
        if trackedWeaponPartConnections[descendant] then
            trackedWeaponPartConnections[descendant]:Disconnect()
            trackedWeaponPartConnections[descendant] = nil
        end
        trackedWeaponPartState[descendant] = nil
        trackedWeaponFxState[descendant] = nil
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

    if type(trackedWeapons) ~= "table" then
        trackedWeapons = makeWeakKeyTable()
        orderedTrackedWeapons = orderedTrackedWeapons or {}
        log("Weapon tracker table was unavailable; recreated tracker state")
    end

    if not trackedCharacter or not trackedCharacter.Parent then
        trackedCharacter = player and player.Character
        if not trackedCharacter then
            log("Weapon pass skipped: no active character")
            return
        end
        log("Weapon tracker pointed at current character")
    end

    if opts.rescan ~= false then
        local rescanOk, rescanErr = pcall(function()
            rescanCharacterWeapons(true)
        end)
        if not rescanOk then
            log(string.format("Weapon rescan failed: %s", tostring(rescanErr)))
        end
    end

    for weapon in pairs(trackedWeapons) do
        if weapon and weapon.Parent == trackedCharacter then
            local passOk, passErr = pcall(function()
                applyWeaponState(weapon)
            end)
            if not passOk then
                log(string.format("Weapon pass failed on %s: %s", tostring(weapon.Name), tostring(passErr)))
            end
        else
            untrackWeapon(weapon)
        end
    end

    local hitboxOk, hitboxErr = pcall(function()
        applyHitboxEnlarger(opts.hitboxPreset, opts.silentHitbox)
    end)
    if not hitboxOk then
        log(string.format("Hitbox enlarger pass failed: %s", tostring(hitboxErr)))
    end
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
    trackedWeaponFxState = makeWeakKeyTable()
    hitboxOriginalSizes = makeWeakKeyTable()
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

    for fx in pairs(trackedWeaponFxState) do
        if (not fx) or (not fx.Parent) then
            trackedWeaponFxState[fx] = nil
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
screen.Name = "Unititled_Melee_RNG"
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
    title.Text = keyAccepted and "Untitled Melee RNG - hide/open with ;" or "Key System"
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
createTab("Upgrades")
createTab("Sacrifice")
createTab("Settings")
createTab("Teleports")

-- Keep tab buttons contained within bar width regardless of window size.
local tabNames = { "OP Settings", "Utility", "Upgrades", "Sacrifice", "Settings", "Teleports" }
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

local function setHitboxPresetSelection(presetName)
    hitboxPresetSelection = presetName
    activeHitboxPreset = presetName
    for key, row in pairs(hitboxPresetRows) do
        if row and row.setState then
            row.setState(key == presetName)
        end
    end
    if hitboxEnlargerEnabled then
        runSelfWeaponPass(string.format("Hitbox mode set: %s", presetName), { silentHitbox = true })
    end
end

local function setHitboxPresetRowsVisible(visible)
    if hitboxPresetHeaderLabel and hitboxPresetHeaderLabel.Parent then
        hitboxPresetHeaderLabel.Parent.Visible = visible
    end
    for _, row in ipairs(hitboxPresetUiRows) do
        if row then
            row.Visible = visible
        end
    end
end

local function makeHitboxPresetRow(labelText, presetName, tabName)
    tabName = tabName or currentTabName
    local row = newRow(34, tabName)
    table.insert(hitboxPresetUiRows, row)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(0.42, -10, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = uiTheme.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText

    local toggleButton = Instance.new("TextButton")
    toggleButton.Parent = row
    toggleButton.Size = UDim2.new(0.30, -6, 1, -8)
    toggleButton.Position = UDim2.new(0.66, 0, 0, 4)
    toggleButton.BorderSizePixel = 0
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 11
    makeCorner(toggleButton, 5)

    local state = presetName == hitboxPresetSelection
    local function refresh()
        toggleButton.Text = state and "ON" or "OFF"
        toggleButton.BackgroundColor3 = state and uiTheme.accent or Color3.fromRGB(70, 70, 82)
        toggleButton.TextColor3 = state and Color3.fromRGB(10, 10, 12) or uiTheme.text
    end

    toggleButton.MouseButton1Click:Connect(function()
        state = true
        setHitboxPresetSelection(presetName)
        refresh()
    end)

    refresh()

    hitboxPresetRows[presetName] = {
        setState = function(v)
            state = v == true
            refresh()
        end,
        getState = function()
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
-- Why: some settings are best represented as value + explicit action in one row.
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

local function makeSlider(labelText, defaultValue, minValue, maxValue, onChange, tabName)
    tabName = tabName or currentTabName
    local row = newRow(44, tabName)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(0.40, -10, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = uiTheme.text
    label.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame")
    track.Parent = row
    track.Size = UDim2.new(0.44, 0, 0, 6)
    track.Position = UDim2.new(0.46, 0, 0.5, -3)
    track.BackgroundColor3 = Color3.fromRGB(48, 48, 60)
    track.BorderSizePixel = 0
    makeCorner(track, 3)

    local fill = Instance.new("Frame")
    fill.Parent = track
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = uiTheme.accent
    fill.BorderSizePixel = 0
    makeCorner(fill, 3)

    local knob = Instance.new("TextButton")
    knob.Parent = row
    knob.Size = UDim2.fromOffset(14, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
    knob.BorderSizePixel = 0
    knob.Text = ""
    knob.AutoButtonColor = false
    makeCorner(knob, 7)

    local dragging = false
    local value = math.clamp(math.floor(tonumber(defaultValue) or minValue), minValue, maxValue)

    local function updateVisuals()
        local alpha = 0
        if maxValue > minValue then
            alpha = (value - minValue) / (maxValue - minValue)
        end
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        local knobX = track.AbsolutePosition.X + (track.AbsoluteSize.X * alpha)
        local knobY = track.AbsolutePosition.Y + (track.AbsoluteSize.Y / 2)
        knob.Position = UDim2.fromOffset(math.floor(knobX - row.AbsolutePosition.X), math.floor(knobY - row.AbsolutePosition.Y))
        label.Text = string.format("%s: %ds", labelText, value)
    end

    local function setFromAbsoluteX(absX)
        local width = math.max(track.AbsoluteSize.X, 1)
        local alpha = math.clamp((absX - track.AbsolutePosition.X) / width, 0, 1)
        local raw = minValue + ((maxValue - minValue) * alpha)
        local nextValue = math.clamp(math.floor(raw + 0.5), minValue, maxValue)
        if nextValue ~= value then
            value = nextValue
            local ok, err = pcall(function()
                onChange(value)
            end)
            if not ok then
                warn(string.format("[MeerlyPerf] Slider callback failed (%s): %s", tostring(labelText), tostring(err)))
                if log then
                    log(string.format("Slider error (%s): %s", tostring(labelText), tostring(err)))
                end
            end
        end
        updateVisuals()
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromAbsoluteX(input.Position.X)
        end
    end)

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromAbsoluteX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromAbsoluteX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    row:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateVisuals)
    row:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateVisuals)
    track:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateVisuals)
    track:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateVisuals)

    local ok, err = pcall(function()
        onChange(value)
    end)
    if not ok and log then
        log(string.format("Slider error (%s): %s", tostring(labelText), tostring(err)))
    end

    task.defer(updateVisuals)

    return {
        get = function()
            return value
        end,
        set = function(v)
            value = math.clamp(math.floor(tonumber(v) or value), minValue, maxValue)
            local okSet, errSet = pcall(function()
                onChange(value)
            end)
            if not okSet and log then
                log(string.format("Slider error (%s): %s", tostring(labelText), tostring(errSet)))
            end
            updateVisuals()
        end,
    }
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

local function makeOutputField(labelText, initialText, tabName)
    local row = newRow(168, tabName)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.Size = UDim2.new(1, -14, 0, 20)
    label.Position = UDim2.fromOffset(8, 2)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = uiTheme.subtle
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText

    local box = Instance.new("TextBox")
    box.Parent = row
    box.Size = UDim2.new(1, -14, 1, -28)
    box.Position = UDim2.fromOffset(8, 24)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.MultiLine = true
    box.TextWrapped = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.Font = Enum.Font.Code
    box.TextSize = 12
    box.TextEditable = false
    box.TextColor3 = uiTheme.text
    box.Text = initialText or ""
    makeCorner(box, 5)

    return box
end

local function getFusionCategoryForOneIn(oneInValue)
    for categoryName, config in pairs(fusionSettings) do
        if categoryName ~= "All" and oneInValue >= config.min and oneInValue <= config.max then
            return categoryName
        end
    end
    return "All"
end

local function parseOneInFromText(raw)
    local text = tostring(raw or ""):lower()
    local value = text:match("one%s*in%s*[:|%-]*%s*([%d,%.]+)") or text:match("1%s*/%s*([%d,%.]+)") or text:match("([%d,%.]+)")
    if not value then
        return nil
    end
    value = value:gsub(",", "")
    local parsed = tonumber(value)
    if parsed and parsed >= 0 then
        return math.floor(parsed + 0.5)
    end
    return nil
end

local function readGuiText(node)
    if not node then
        return ""
    end

    local textValue = ""
    pcall(function()
        textValue = tostring(node.Text or "")
    end)

    if textValue == "" then
        pcall(function()
            textValue = tostring(node.ContentText or "")
        end)
    end

    return textValue
end

local function resolveFusionScrollFrame()
    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
    local mainGui = playerGui and playerGui:FindFirstChild("MainGUI")
    local generalUi = mainGui and mainGui:FindFirstChild("GeneralUI")
    if not generalUi then
        return nil
    end

    local fuseFrame = generalUi:FindFirstChild("FuseFrame") or generalUi:FindFirstChild("FuseFrame", true)
    if not fuseFrame then
        return nil
    end

    return fuseFrame:FindFirstChild("ScrollingFrame") or fuseFrame:FindFirstChild("ScrollingFrame", true)
end

local function parseFusionWeaponFrames()
    local parsed = {}
    local fuseScroll = resolveFusionScrollFrame()
    if not fuseScroll then
        return parsed
    end

    for _, child in ipairs(fuseScroll:GetDescendants()) do
        if child:IsA("GuiObject") and child.Name == "WeaponFrame" then
            local chanceLabel = child:FindFirstChild("ItemChance", true)
            local nameLabel = child:FindFirstChild("ItemName", true)
            local qtyLabel = child:FindFirstChild("ItemQuantity", true) or child:FindFirstChild("ItemQty", true)
            local chanceText = readGuiText(chanceLabel)
            if chanceText == "" then
                chanceText = "Unknown"
            end
            local oneIn = parseOneInFromText(chanceText)
            local qtyText = readGuiText(qtyLabel)
            local qty = tonumber((qtyText):gsub("[^%d]", "")) or 0
            local weaponName = readGuiText(nameLabel)
            weaponName = weaponName ~= "" and weaponName:gsub("^%s*(.-)%s*$", "%1") or "Unknown"
            table.insert(parsed, {
                name = weaponName,
                oneIn = oneIn,
                oneInRaw = chanceText,
                amount = qty,
                frame = child,
            })
        end
    end
    return parsed
end

local function lookupFusionWeaponAsset(weaponName)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local weaponsFolder = assets and assets:FindFirstChild("Weapons")
    if not weaponsFolder then
        return nil
    end

    local byName = weaponsFolder:FindFirstChild(weaponName, true)
    if byName then
        return byName
    end

    for _, candidate in ipairs(weaponsFolder:GetDescendants()) do
        if candidate:IsA("Model") and candidate.Name == weaponName then
            return candidate
        end
    end

    return nil
end

local function parseFusionInventoryRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local invRemote = remotes and remotes:FindFirstChild("GetWeaponsInv")
    if not invRemote then
        return nil
    end

    local ok, raw = pcall(function()
        return invRemote:InvokeServer()
    end)
    if not ok or type(raw) ~= "table" then
        return nil
    end
    return raw
end

local function normalizeFusionWeaponInventory(rawInventory)
    local parsed = {}
    if type(rawInventory) ~= "table" then
        return parsed
    end

    local function insertNormalizedEntry(weaponName, amount, oneIn, oneInRaw)
        local trimmedName = tostring(weaponName or "Unknown"):gsub("^%s*(.-)%s*$", "%1")
        local parsedAmount = tonumber(amount) or 1
        parsedAmount = math.max(0, math.floor(parsedAmount))
        local parsedOneIn = tonumber(oneIn)
        if (not parsedOneIn) then
            local asset = lookupFusionWeaponAsset(trimmedName)
            if asset then
                parsedOneIn = tonumber(asset:GetAttribute("OneIn"))
            end
        end

        table.insert(parsed, {
            name = trimmedName,
            oneIn = parsedOneIn or math.huge,
            oneInRaw = oneInRaw or (parsedOneIn and tostring(parsedOneIn) or "Unknown"),
            amount = parsedAmount,
        })
    end

    local function pushEntry(item, fallbackName)
        if type(item) == "table" then
            local weaponName = item.WeaponName or item.WepName or item.Name or item.ItemName or fallbackName
            local amount = tonumber(item.Quantity or item.Amount or item.Qty or item.ItemQty or item.Count or item.amount) or 1
            local oneIn = tonumber(item.OneIn or item.Chance or item.ItemChance) or parseOneInFromText(item.ItemChanceText)
            if (not oneIn) and type(item.RarityText) == "string" then
                oneIn = parseOneInFromText(item.RarityText)
            end

            insertNormalizedEntry(weaponName, amount, oneIn, item.ItemChanceText)
        elseif type(item) == "number" then
            insertNormalizedEntry(fallbackName, item)
        elseif type(item) == "string" and fallbackName then
            -- Handle sparse structures where keys are names and values are descriptor strings.
            insertNormalizedEntry(fallbackName, 1, parseOneInFromText(item), item)
        end
    end

    if rawInventory[1] ~= nil then
        for _, item in ipairs(rawInventory) do
            pushEntry(item)
        end
    else
        for key, item in pairs(rawInventory) do
            pushEntry(item, key)
        end
    end

    return parsed
end

local function attachFusionFramesToInventory(inventory, frames)
    local frameBuckets = {}
    for _, frameEntry in ipairs(frames) do
        local key = tostring(frameEntry.name or "Unknown")
        frameBuckets[key] = frameBuckets[key] or {}
        table.insert(frameBuckets[key], frameEntry.frame)
    end

    for _, entry in ipairs(inventory) do
        local key = tostring(entry.name or "Unknown")
        local bucket = frameBuckets[key]
        if bucket and #bucket > 0 then
            entry.frame = table.remove(bucket, 1)
        end
    end
end

local function lookupWeaponOneInFromAssets(weaponName)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local weaponsFolder = assets and assets:FindFirstChild("Weapons")
    if not weaponsFolder then
        return nil
    end

    local byName = weaponsFolder:FindFirstChild(weaponName, true)
    if not byName then
        return nil
    end

    local oneIn = tonumber(byName:GetAttribute("OneIn"))
    if oneIn then
        return oneIn
    end

    local oneInValueObj = byName:FindFirstChild("OneIn", true)
    if oneInValueObj and (oneInValueObj:IsA("IntValue") or oneInValueObj:IsA("NumberValue")) then
        return tonumber(oneInValueObj.Value)
    end

    return nil
end

local function getSacrificeInventory()
    local rawInventory = parseFusionInventoryRemote()
    local parsed = {}

    local function pushEntry(entry, fallbackName)
        if type(entry) ~= "table" then
            return
        end

        local weaponName = tostring(entry.WeaponName or entry.WepName or entry.Name or entry.ItemName or fallbackName or "Unknown")
        weaponName = weaponName:gsub("^%s*(.-)%s*$", "%1")
        if weaponName == "" then
            weaponName = "Unknown"
        end

        local amount = tonumber(entry.Quantity or entry.Amount or entry.Qty or entry.ItemQty or entry.Count or entry.amount) or 1
        amount = math.max(0, math.floor(amount))
        local weaponType = tostring(entry.WeaponType or entry.Type or entry.ItemType or "Weapon")
        local oneIn = tonumber(entry.OneIn or entry.Chance or entry.ItemChance) or parseOneInFromText(entry.ItemChanceText)
        if not oneIn then
            oneIn = lookupWeaponOneInFromAssets(weaponName)
        end

        if amount > 0 then
            table.insert(parsed, {
                name = weaponName,
                amount = amount,
                type = weaponType,
                oneIn = oneIn or math.huge,
            })
        end
    end

    if type(rawInventory) == "table" then
        if rawInventory[1] ~= nil then
            for _, entry in ipairs(rawInventory) do
                pushEntry(entry)
            end
        else
            for key, entry in pairs(rawInventory) do
                pushEntry(entry, key)
            end
        end
    end

    table.sort(parsed, function(a, b)
        if a.oneIn == b.oneIn then
            return a.name < b.name
        end
        return a.oneIn < b.oneIn
    end)

    return parsed
end

local function getSacrificeTierCap()
    local idx = math.clamp(math.floor(tonumber(sacrificeRarityCapIndex) or 1), 1, #sacrificeTierCaps)
    return sacrificeTierCaps[idx].cap, sacrificeTierCaps[idx].label, idx
end

local function shouldSacrificeEntry(entry)
    if not entry or entry.amount <= 0 then
        return false
    end

    if not sacrificeByColorEnabled then
        return false
    end

    local cap = getSacrificeTierCap()
    return (tonumber(entry.oneIn) or math.huge) <= cap
end

local function updateSacrificeInventoryOutput(inventory)
    if not sacrificeStatusOutput then
        return
    end

    local lines = {}
    for _, item in ipairs(inventory or {}) do
        local keepQty = math.max(0, math.floor(sacrificeKeepQuantity))
        local canSacrificeQty = math.max(0, item.amount - keepQty)
        local oneInDisplay = (item.oneIn and item.oneIn < math.huge) and tostring(math.floor(item.oneIn)) or "?"
        table.insert(lines, string.format("%s | OneIn %s | Owned %d | CanSac %d", item.name, oneInDisplay, item.amount, canSacrificeQty))
    end

    sacrificeStatusOutput.Text = #lines > 0 and table.concat(lines, "\n") or "No weapons found."
    local container = sacrificeStatusOutput.Parent
    if container then
        local lineCount = math.max(6, #lines)
        local dynamicHeight = math.clamp(36 + (lineCount * 14), 168, 780)
        container.Size = UDim2.new(1, -4, 0, dynamicHeight)
    end
end

local function refreshSacrificeInventory(silent)
    sacrificeInventory = getSacrificeInventory()
    updateSacrificeInventoryOutput(sacrificeInventory)
    if (not silent) and log then
        log(string.format("Sacrifice list refreshed (%d weapon entries)", #sacrificeInventory))
    end
    return sacrificeInventory
end

local function runSacrificePass()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local sacrificeRemote = remotes and remotes:FindFirstChild("FountainSacrifice")
    if not sacrificeRemote then
        return 0, 0, "FountainSacrifice remote not found"
    end

    local inventory = refreshSacrificeInventory(true)
    local kept = math.max(0, math.floor(sacrificeKeepQuantity))
    local attempted = 0
    local succeeded = 0

    for _, entry in ipairs(inventory) do
        if shouldSacrificeEntry(entry) then
            local toSacrifice = math.max(0, entry.amount - kept)
            if toSacrifice > 0 then
                attempted += 1
                local ok, result = pcall(function()
                    return sacrificeRemote:InvokeServer(entry.name, entry.type, toSacrifice)
                end)
                if ok and result ~= false then
                    succeeded += 1
                    if sacrificeLastActionOutput then
                        sacrificeLastActionOutput.Text = string.format("Last sacrifice: %s x%d", entry.name, toSacrifice)
                    end
                end
            end
        end
    end

    return attempted, succeeded, nil
end

local function getWeaponInventoryForFusion()
    local frameInventory = parseFusionWeaponFrames()
    local remoteInventory = parseFusionInventoryRemote()
    local inventory = normalizeFusionWeaponInventory(remoteInventory)

    if #inventory == 0 then
        inventory = frameInventory
    else
        attachFusionFramesToInventory(inventory, frameInventory)
    end

    table.sort(inventory, function(a, b)
        local ao = tonumber(a.oneIn) or math.huge
        local bo = tonumber(b.oneIn) or math.huge
        if ao == bo then
            return a.name < b.name
        end
        return ao < bo
    end)

    return inventory
end

local function shouldFuseWeaponEntry(entry)
    if not entry or entry.amount < 3 then
        return false
    end

    local oneIn = entry.oneIn or 0
    local allConfig = fusionSettings.All
    if not (allConfig.enabled and oneIn >= allConfig.min) then
        return false
    end

    local category = getFusionCategoryForOneIn(oneIn)
    local categoryConfig = fusionSettings[category]
    if not categoryConfig then
        return false
    end

    return categoryConfig.enabled and oneIn >= categoryConfig.min and oneIn <= categoryConfig.max
end

local function updateFusionStatusOutput(inventory)
    if not fusionStatusOutput then
        return
    end
    local lines = {}
    for _, item in ipairs(inventory or {}) do
        local oneInDisplay = item.oneInRaw and item.oneInRaw ~= "" and item.oneInRaw or tostring(item.oneIn)
        table.insert(lines, string.format("%s | One In %s | x%d", tostring(item.name), tostring(oneInDisplay), tonumber(item.amount) or 0))
    end
    fusionStatusOutput.Text = #lines > 0 and table.concat(lines, "\n") or "No weapons found."
end

local function resolveFuseConfirmButton()
    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
    local mainGui = playerGui and playerGui:FindFirstChild("MainGUI")
    local generalUi = mainGui and mainGui:FindFirstChild("GeneralUI")
    local fuseConfirm = generalUi and generalUi:FindFirstChild("FuseConfirm")
    return fuseConfirm and fuseConfirm:FindFirstChild("FuseBtn", true)
end

local function tryFuseViaUiButton(entry)
    local frame = entry and entry.frame
    if not frame then
        return false
    end

    local fuseButton = frame:FindFirstChild("Btn", true)
    if not fuseButton then
        for _, obj in ipairs(frame:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and string.lower(obj.Name) == "btn" then
                fuseButton = obj
                break
            end
        end
    end

    if not (fuseButton and (fuseButton:IsA("TextButton") or fuseButton:IsA("ImageButton"))) then
        return false
    end

    local okSelect = pcall(function()
        fuseButton:Activate()
    end)
    if not okSelect then
        return false
    end

    task.wait(0.1)
    local confirmButton = resolveFuseConfirmButton()
    if not (confirmButton and (confirmButton:IsA("TextButton") or confirmButton:IsA("ImageButton"))) then
        return false
    end

    local okConfirm = pcall(function()
        confirmButton:Activate()
    end)
    return okConfirm
end

local function tryFuseWeaponsFromInventory(inventory)
    local fusedCount = 0
    for _, item in ipairs(inventory) do
        if shouldFuseWeaponEntry(item) and item.frame then
            if tryFuseViaUiButton(item) then
                fusedCount += 1
                task.wait(0.3)
            end
        end
    end
    return fusedCount
end

local function runWeaponFusionPass(silent)
    local inventory = getWeaponInventoryForFusion()
    updateFusionStatusOutput(inventory)
    if autoFusionEnabled then
        local fusedCount = tryFuseWeaponsFromInventory(inventory)
        if (not silent) and fusedCount > 0 then
            log(string.format("Weapon Fusion fused %d entries", fusedCount))
        end
    end
    return inventory
end

local function getRemotesFolder()
    return ReplicatedStorage:FindFirstChild("Remotes")
end

local function invokeRemoteFunction(remoteName, ...)
    local remotes = getRemotesFolder()
    local remote = remotes and remotes:FindFirstChild(remoteName)
    if not remote or not remote:IsA("RemoteFunction") then
        return nil
    end

    local ok, result = pcall(function(...)
        return remote:InvokeServer(...)
    end, ...)
    if not ok then
        return nil
    end
    return result
end

function coerceUpgradeLevel(raw)
    if raw == nil or raw == false then
        return 0
    end
    if type(raw) == "number" then
        if raw ~= raw or raw < 0 then
            return 0
        end
        return math.max(0, math.floor(raw))
    end
    if type(raw) == "string" then
        return coerceUpgradeLevel(tonumber(raw))
    end
    if type(raw) == "table" then
        return coerceUpgradeLevel(raw[1] or raw.Level or raw.level or raw.Lvl or raw.Value or raw.value)
    end
    return 0
end

function coerceUpgradePrice(raw)
    if type(raw) == "number" and raw == raw and raw > 0 then
        return raw
    end
    if type(raw) == "string" then
        return coerceUpgradePrice(tonumber(raw))
    end
    if type(raw) == "table" then
        return coerceUpgradePrice(raw[1] or raw.Price or raw.price or raw.Cost or raw.cost or raw.SP or raw.sp)
    end
    return nil
end

function readUpgradeLevel(upgradeName)
    return coerceUpgradeLevel(invokeRemoteFunction("GetUpgradeLevel", upgradeName))
end

local function readCurrentSkillPoints()
    local fromRemote = invokeRemoteFunction("GetSP")
        or invokeRemoteFunction("GetSkillPoints")
        or invokeRemoteFunction("GetPlayerSP")
    local asNumber = tonumber(fromRemote)
    if asNumber then
        return asNumber
    end

    local leaderstats = player:FindFirstChild("leaderstats")
    local spValue = leaderstats and (leaderstats:FindFirstChild("SP") or leaderstats:FindFirstChild("SkillPoints"))
    if spValue and (spValue:IsA("IntValue") or spValue:IsA("NumberValue")) then
        return tonumber(spValue.Value)
    end
    return nil
end

function getUpgradeNextPrice(upgradeName, currentLevel)
    local remotePrice = coerceUpgradePrice(
        invokeRemoteFunction("GetUpgradePrice", upgradeName, currentLevel)
        or invokeRemoteFunction("GetNextUpgradePrice", upgradeName, currentLevel)
        or invokeRemoteFunction("GetUpgradeCost", upgradeName, currentLevel)
        or invokeRemoteFunction("CalculateUpgradePrice", upgradeName, currentLevel)
        or invokeRemoteFunction("GetUpgradePrice", upgradeName)
        or invokeRemoteFunction("GetNextUpgradePrice", upgradeName)
    )
    if remotePrice then
        return remotePrice
    end

    local formula = UPGRADE_PRICES[upgradeName]
    if not formula then
        return nil
    end

    local ok, price = pcall(function()
        return formula((tonumber(currentLevel) or 0) + 1)
    end)
    if ok and type(price) == "number" and price == price and price > 0 then
        return price
    end
    return nil
end

function parseUpgradeCapInput(text)
    local parsed = tonumber(tostring(text or ""):gsub("^%s*(.-)%s*$", "%1"))
    if not parsed or parsed < 1 then
        return nil
    end
    return math.floor(parsed)
end

function getUpgradeCandidates()
    local candidates = {}
    for _, upgradeName in ipairs(UPGRADE_ORDER) do
        if upgradeSelected[upgradeName] then
            local level = readUpgradeLevel(upgradeName)
            local cap = upgradeLevelCap[upgradeName]
            local capReached = type(cap) == "number" and level >= cap
            if not capReached then
                local nextPrice = getUpgradeNextPrice(upgradeName, level)
                if type(nextPrice) == "number" then
                    table.insert(candidates, {
                        name = upgradeName,
                        level = level,
                        price = nextPrice,
                    })
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.price == b.price then
            return a.name < b.name
        end
        return a.price < b.price
    end)
    return candidates
end

function refreshUpgradesLiveOutput()
    if not upgradeLiveOutput then
        return
    end

    local lines = {}
    for _, upgradeName in ipairs(UPGRADE_ORDER) do
        local level = readUpgradeLevel(upgradeName)
        local cap = upgradeLevelCap[upgradeName]
        local nextPrice = getUpgradeNextPrice(upgradeName, level)
        local enabledText = upgradeSelected[upgradeName] and "ON" or "OFF"
        local capText = (type(cap) == "number") and tostring(cap) or "-"
        local priceText = nextPrice and tostring(math.floor(nextPrice)) or "?"
        table.insert(lines, string.format("%s | %s | Lv %d | Next %s SP | Cap %s", upgradeName, enabledText, level, priceText, capText))
    end

    upgradeLiveOutput.Text = table.concat(lines, "\n")
end

function clearTabRows(tabName)
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
memoryGui.Name = "Untitled_Melee_RNG"
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

function resolveDisappearController()
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

function setDisappearHider(enabled)
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

function isBossMobPart(part)
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

function resolveMobsAssetsFolder()
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

function hideMobPart(part)
    if hiddenMobPartsState[part] or isBossMobPart(part) then
        return false
    end

    if string.lower(part.Name) == "humanoidrootpart" then
        return false
    end

    hiddenMobPartsState[part] = {
        parent = part.Parent,
    }
    part.Parent = nil
    return true
end

function restoreHiddenMobParts()
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

function applyMobPartsCull(enabled)
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

function resolveOptionsListButton(buttonName)
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

function getOptionsListButtonVisible(buttonName)
    local button = resolveOptionsListButton(buttonName)
    return button and button.Visible or false
end

function setOptionsListButtonVisible(buttonName, enabled)
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

function resolveMainGui()
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil, "PlayerGui not found"
    end

    local mainGui = playerGui:FindFirstChild("MainGUI")
    if not mainGui then
        return nil, "MainGUI not found"
    end

    return mainGui
end

local function resolveGeneralUi()
    local mainGui, reason = resolveMainGui()
    if not mainGui then
        return nil, reason
    end

    local generalUi = mainGui:FindFirstChild("GeneralUI")
    if not generalUi then
        return nil, "GeneralUI not found"
    end

    return generalUi
end

local function setGeneralUiFrameVisible(frameName, enabled, rememberOriginal)
    local generalUi, reason = resolveGeneralUi()
    if not generalUi then
        log(string.format("%s visibility toggle failed: %s", frameName, tostring(reason)))
        return false
    end

    local frame = generalUi:FindFirstChild(frameName)
    if not frame then
        log(string.format("%s visibility toggle failed: frame not found", frameName))
        return false
    end

    if rememberOriginal and uiUtilityState.originalVisibility[frameName] == nil then
        uiUtilityState.originalVisibility[frameName] = frame.Visible
    end

    local ok, err = pcall(function()
        frame.Visible = enabled
    end)

    if not ok then
        log(string.format("Failed to set %s visibility: %s", frameName, tostring(err)))
        return false
    end

    return true
end

local function setManaKillsHidden(hidden)
    setGeneralUiFrameVisible("ManaFrame", not hidden, true)
    setGeneralUiFrameVisible("KillsFrame", not hidden, true)
end

local function resetUiUtilitiesVisibility()
    for frameName, originalState in pairs(uiUtilityState.originalVisibility) do
        if frameName == "GeneralUI" then
            local generalUi = resolveGeneralUi()
            if generalUi then
                generalUi.Visible = originalState
            end
        else
            setGeneralUiFrameVisible(frameName, originalState, false)
        end
    end
    uiUtilityState.hideManaKillsEnabled = false
    uiUtilityState.hideMiniRollEnabled = false
    uiUtilityState.hideHudEnabled = false
end

-- ---- Feature wiring (UI -> behavior) ----

-- OP Settings page.
makeToggle("Kill Aura", hitboxExpanderMasterEnabled, function(v)
    hitboxExpanderMasterEnabled = v
    hitboxEnlargerEnabled = v
    setHitboxPresetRowsVisible(v)
    if v then
        runSelfWeaponPass("Hitbox expander enabled", { silentHitbox = true })
    else
        restoreTrackedHitboxDefaults()
        log("Hitbox expander disabled")
    end
end, "OP Settings")

hitboxPresetHeaderLabel = makeSectionLabel("Kill Aura Modes", "OP Settings")
makeHitboxPresetRow("Boss", "Boss Raids", "OP Settings")
makeHitboxPresetRow("High", "High Performance", "OP Settings")
makeHitboxPresetRow("Medium", "Medium Performance", "OP Settings")
makeHitboxPresetRow("Low", "Low Performance", "OP Settings")
makeHitboxPresetRow("Potato", "Potato PC", "OP Settings")
setHitboxPresetSelection("Potato PC")
setHitboxPresetRowsVisible(hitboxExpanderMasterEnabled)

makeToggle("Hide Kill Effects", hideDisappearEntities, function(v)
    setDisappearHider(v)
end, "OP Settings")

makeToggle("Cull Mob Parts - Custom Hide Mobs", cullMobPartsEnabled, function(v)
    applyMobPartsCull(v)
end, "OP Settings")

makeSectionLabel("GamepassBypass:", "OP Settings")
makeToggle("ShowAutoRaid", getOptionsListButtonVisible("AutoRaidBtn"), function(v)
    setOptionsListButtonVisible("AutoRaidBtn", v)
end, "OP Settings")

makeToggle("ShowHideMobs", getOptionsListButtonVisible("HideMobsBtn"), function(v)
    setOptionsListButtonVisible("HideMobsBtn", v)
end, "OP Settings")

-- Utility page.
makeSectionLabel("Game Utils", "Utility")
makeButton("Fusion UI", function()
    if setGeneralUiFrameVisible("FuseFrame", true, false) then
        log("Opened Fusion UI")
    end
end, "Utility")

makeButton("Totem UI", function()
    if setGeneralUiFrameVisible("TotemOfFortuneFrame", true, false) then
        log("Opened Totem UI")
    end
end, "Utility")

makeButton("Crafting UI", function()
    if setGeneralUiFrameVisible("WeaponCrafter", true, false) then
        log("Opened Crafting UI")
    end
end, "Utility")

makeButton("Ascend UI", function()
    if setGeneralUiFrameVisible("AscendPrompt", true, false) then
        log("Opened Ascend UI")
    end
end, "Utility")

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

makeSectionLabel("UI Utilities", "Utility")
makeToggle("Hide Mana / Kills", uiUtilityState.hideManaKillsEnabled, function(v)
    uiUtilityState.hideManaKillsEnabled = v
    setManaKillsHidden(v)
end, "Utility")

makeToggle("Hide Mini-Roll", uiUtilityState.hideMiniRollEnabled, function(v)
    uiUtilityState.hideMiniRollEnabled = v
    setGeneralUiFrameVisible("MiniRollFrame", not v, true)
end, "Utility")

makeToggle("Hide HUD", uiUtilityState.hideHudEnabled, function(v)
    uiUtilityState.hideHudEnabled = v
    local generalUi, reason = resolveGeneralUi()
    if not generalUi then
        log("Hide HUD toggle failed: " .. tostring(reason))
        return
    end

    if uiUtilityState.originalVisibility.GeneralUI == nil then
        uiUtilityState.originalVisibility.GeneralUI = generalUi.Visible
    end
    generalUi.Visible = not v
end, "Utility")

-- Weapon Fusion page.
if weaponFusionTabEnabled then
    makeSectionLabel("Weapon Fusion", "Weapon Fusion")
    makeToggle("Auto Fusion On/Off", autoFusionEnabled, function(v)
        autoFusionEnabled = v
        log(v and "Weapon Fusion enabled" or "Weapon Fusion disabled")
    end, "Weapon Fusion")

    for _, category in ipairs({ "All", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }) do
        local config = fusionSettings[category]
        if config then
            makeToggle(string.format("%s OneIn Enabled", category), config.enabled, function(v)
                config.enabled = v
            end, "Weapon Fusion")
        end
    end

    makeButton("Refresh Weapon Fusion List", function()
        local inventory = runWeaponFusionPass(true)
        log(string.format("Weapon Fusion list refreshed (%d entries)", #inventory))
    end, "Weapon Fusion")

    fusionStatusOutput = makeOutputField("Weapons (Weapon | OneIn | x Amount owned)", "No weapons found.", "Weapon Fusion")
end

-- Sacrifice page.
makeSectionLabel("Sacrifice (Fountain)", "Sacrifice")
makeToggle("Auto Sacrifice", sacrificeAutoEnabled, function(v)
    sacrificeAutoEnabled = v
    log(v and "Auto Sacrifice enabled" or "Auto Sacrifice disabled")
end, "Sacrifice")

makeToggle("By Rarity (OneIn Cap)", sacrificeByColorEnabled, function(v)
    sacrificeByColorEnabled = v
    local cap, label = getSacrificeTierCap()
    log(string.format("Sacrifice color filter: %s (cap %s)", v and "ON" or "OFF", label))
    if v then
        log(string.format("Sacrifice cap set to <= %d", cap))
    end
end, "Sacrifice")

makeInput("Always Keep Qty", tostring(sacrificeKeepQuantity), function(text)
    local value = math.floor(tonumber(text) or sacrificeKeepQuantity)
    sacrificeKeepQuantity = math.max(0, value)
    updateSacrificeInventoryOutput(sacrificeInventory)
    return tostring(sacrificeKeepQuantity)
end, "Sacrifice")

sacrificeTierButton = makeButton("Tier Cap: --", function()
    sacrificeRarityCapIndex += 1
    if sacrificeRarityCapIndex > #sacrificeTierCaps then
        sacrificeRarityCapIndex = 1
    end
    local _, label = getSacrificeTierCap()
    sacrificeTierButton.Text = "Tier Cap: " .. label
    updateSacrificeInventoryOutput(sacrificeInventory)
end, "Sacrifice")
sacrificeTierButton.Text = "Tier Cap: " .. select(2, getSacrificeTierCap())

makeButton("Refresh Sacrifice List", function()
    refreshSacrificeInventory(false)
end, "Sacrifice")

makeButton("Run Sacrifice Once", function()
    local attempted, succeeded, err = runSacrificePass()
    if err then
        log("Sacrifice run failed: " .. tostring(err))
        return
    end
    log(string.format("Sacrifice run complete: %d attempted, %d succeeded", attempted, succeeded))
    refreshSacrificeInventory(true)
end, "Sacrifice")

sacrificeLastActionOutput = makeSectionLabel("Last sacrifice: --", "Sacrifice")
sacrificeStatusOutput = makeOutputField("Inventory (Weapon | OneIn | Owned | CanSac)", "No weapons found.", "Sacrifice")
refreshSacrificeInventory(true)

makeSlider("GC Sweep", gcSweepInterval, 10, 300, function(v)
    gcSweepInterval = v
    log(string.format("GC sweep interval set: %ds", gcSweepInterval))
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

-- Upgrades page.
makeSectionLabel("Auto Upgrade", "Upgrades")
makeToggle("Auto Upgrade", autoUpgradeEnabled, function(v)
    autoUpgradeEnabled = v
    if upgradeStatusLabel then
        upgradeStatusLabel.Text = v and "Status: ON - watching SP and upgrade prices" or "Status: OFF"
    end
    log(v and "Auto Upgrade enabled" or "Auto Upgrade disabled")
end, "Upgrades")

makeButton("Select All / None", function()
    local anyDisabled = false
    for _, upgradeName in ipairs(UPGRADE_ORDER) do
        if not upgradeSelected[upgradeName] then
            anyDisabled = true
            break
        end
    end
    for _, upgradeName in ipairs(UPGRADE_ORDER) do
        upgradeSelected[upgradeName] = anyDisabled
    end
    refreshUpgradesLiveOutput()
    log(anyDisabled and "All upgrades selected" or "All upgrades deselected")
end, "Upgrades")

upgradeStatusLabel = makeSectionLabel("Status: OFF", "Upgrades")
upgradeInfoLabel = makeSectionLabel("SP: -- | Next: --", "Upgrades")
makeSectionLabel("Upgrade Selection (toggle + optional cap)", "Upgrades")

for _, upgradeName in ipairs(UPGRADE_ORDER) do
    makeToggle(upgradeName, upgradeSelected[upgradeName], function(v)
        upgradeSelected[upgradeName] = v
        refreshUpgradesLiveOutput()
    end, "Upgrades")

    makeInput(upgradeName .. " cap", "", function(text)
        upgradeLevelCap[upgradeName] = parseUpgradeCapInput(text)
        refreshUpgradesLiveOutput()
        return upgradeLevelCap[upgradeName] and tostring(upgradeLevelCap[upgradeName]) or ""
    end, "Upgrades")
end

upgradeLiveOutput = makeOutputField("Live Upgrades (Name | ON/OFF | Level | Next SP | Cap)", "Loading...", "Upgrades")
refreshUpgradesLiveOutput()

-- Settings page.
makeSectionLabel("Performance", "Settings")
makeToggle("Low Graphics Mode", lowGraphicsEnabled, function(v)
    lowGraphicsEnabled = v
    applyVisuals(v)
    log(v and "Low graphics enabled" or "Low graphics disabled")
end, "Settings")

makeToggle("Aggressive FX Cull", aggressiveFxCullEnabled, function(v)
    aggressiveFxCullEnabled = v
    applyAggressiveFxCull(v)
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
    pcall(function()
        resetUiUtilitiesVisibility()
    end)
    pcall(function()
        restoreTrackedHitboxDefaults(true)
    end)
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

quickKillButton.MouseButton1Click:Connect(function()
    requestShutdown("killswitch")
end)

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

-- Auto-upgrade worker: checks selected upgrades, chooses cheapest valid target, and buys safely.
task.spawn(function()
    while running do
        task.wait(1)
        local now = os.clock()

        if now - upgradeLastStatusRefresh >= 3 then
            upgradeLastStatusRefresh = now
            local sp = readCurrentSkillPoints()
            local candidates = getUpgradeCandidates()
            local nextName = candidates[1] and candidates[1].name or "none"
            local nextPrice = candidates[1] and tostring(math.floor(candidates[1].price)) or "--"
            if upgradeInfoLabel then
                upgradeInfoLabel.Text = string.format("SP: %s | Next: %s (%s SP)", sp and tostring(math.floor(sp)) or "--", nextName, nextPrice)
            end
            refreshUpgradesLiveOutput()
        end

        if not autoUpgradeEnabled then
            continue
        end

        if now - upgradeLastAttemptAt < 0.9 then
            continue
        end
        upgradeLastAttemptAt = now

        local sp = readCurrentSkillPoints()
        local candidates = getUpgradeCandidates()
        local purchased = false

        for _, candidate in ipairs(candidates) do
            if (not sp) or sp >= candidate.price then
                local result = invokeRemoteFunction("BuyUpgrade", candidate.name)
                if result ~= false and result ~= nil then
                    purchased = true
                    if upgradeStatusLabel then
                        upgradeStatusLabel.Text = string.format("Status: Bought %s (%d -> %d)", candidate.name, candidate.level, candidate.level + 1)
                    end
                    log(string.format("Auto Upgrade bought: %s", candidate.name))
                    break
                end
            end
        end

        if (not purchased) and upgradeStatusLabel then
            local nextCandidate = candidates[1]
            if nextCandidate then
                upgradeStatusLabel.Text = string.format(
                    "Status: waiting for %s (%d SP), current SP %s",
                    nextCandidate.name,
                    math.floor(nextCandidate.price),
                    sp and tostring(math.floor(sp)) or "--"
                )
            else
                upgradeStatusLabel.Text = "Status: no eligible upgrades selected"
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

-- Weapon maintenance worker: periodic correction for hidden weapon-part state drift.
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

-- Hitbox mode worker: runs mode-specific scan cadence for non-potato presets.
task.spawn(function()
    while running do
        local preset = activeHitboxPreset
        local interval = hitboxPresetScanIntervals[preset]
        if hitboxEnlargerEnabled and interval then
            runSelfWeaponPass(nil, { rescan = true })
            task.wait(interval)
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while running do
        local silent = not autoFusionEnabled
        pcall(function()
            runWeaponFusionPass(silent)
        end)
        task.wait(autoFusionEnabled and 2 or 5)
    end
end)

task.spawn(function()
    while running do
        if sacrificeAutoEnabled then
            local attempted, succeeded, err = runSacrificePass()
            if err then
                log("Auto Sacrifice error: " .. tostring(err))
            else
                log(string.format("Auto Sacrifice: %d attempted, %d succeeded", attempted, succeeded))
            end
            refreshSacrificeInventory(true)
            task.wait(1.5)
        else
            refreshSacrificeInventory(true)
            task.wait(5)
        end
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

log("Untitled Melee RNG Script Loaded")
