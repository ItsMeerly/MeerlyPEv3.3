--[[
    FPS Abilities Test Environment
    Powered by MUILib

    Features:
    - Esper Ability (ESP with Visibility & Team Checks)
    - True Shot Ability (Optimized Wall Checks, Aim Strength Control, Projectile Prediction)
    - FOV Telegraph (Visualized Screen Circle aligned to Absolute Viewport)
]]

local MUILib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ItsMeerly/MeerlyPEv3.3/main/MUILib.lua"))()
local UI = MUILib.new({ Title = "FPS Abilities Lab", Console = true })

-- // Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- // Variables
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Connections = {} 

-- Optimize Raycasting to prevent memory leaks/freezes
local SharedRaycast = RaycastParams.new()
SharedRaycast.FilterType = Enum.RaycastFilterType.Exclude
SharedRaycast.IgnoreWater = true

-- // Ability Tabs
local AbilitiesTab = UI:CreateTab("Abilities")
local EsperSection = AbilitiesTab:CreateSection("Esper (Sensory ESP)")
local TrueShotSection = AbilitiesTab:CreateSection("True Shot (Target Lock)")

-- ==========================================
-- ||              UTILITIES               ||
-- ==========================================

local function ParseInputBind(text, default)
    text = tostring(text):upper()
    local successKey, resultKey = pcall(function() return Enum.KeyCode[text] end)
    if successKey and resultKey then return resultKey end
    
    local successMouse, resultMouse = pcall(function() return Enum.UserInputType[text] end)
    if successMouse and resultMouse then return resultMouse end

    return default
end

local function IsEnemy(targetPlayer)
    if not targetPlayer then return false end
    if LocalPlayer.Team == nil then return true end
    return targetPlayer.Team ~= LocalPlayer.Team
end

local function IsVisible(targetPart)
    if not targetPart then return false end
    
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    
    SharedRaycast.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    
    local result = workspace:Raycast(origin, direction, SharedRaycast)
    
    if result then
        if result.Instance:IsDescendantOf(targetPart.Parent) then
            return true
        end
        return false
    end
    return true
end


-- ==========================================
-- ||             ESPER ABILITY            ||
-- ==========================================
local esperEnabled = false
local esperKeybind = Enum.KeyCode.E
local esperHighlights = {}
local esperFolder = Instance.new("Folder")
esperFolder.Name = "EsperAbilityFolder"
esperFolder.Parent = CoreGui

local esperToggle 

local function ClearEsper()
    for player, highlight in pairs(esperHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    table.clear(esperHighlights)
end

local function UpdateEsper()
    if not esperEnabled then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not IsEnemy(player) then 
            if esperHighlights[player] then
                esperHighlights[player]:Destroy()
                esperHighlights[player] = nil
            end
            continue 
        end
        
        local character = player.Character
        local rootPart = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if character and rootPart and humanoid and humanoid.Health > 0 then
            local highlight = esperHighlights[player]
            
            if not highlight or not highlight.Parent then
                highlight = Instance.new("Highlight")
                highlight.Name = player.Name .. "_Esper"
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillTransparency = 0.6
                highlight.OutlineTransparency = 0.1
                highlight.Parent = esperFolder
                esperHighlights[player] = highlight
            end
            
            highlight.Adornee = character
            
            if IsVisible(rootPart) then
                highlight.FillColor = Color3.fromRGB(87, 215, 126)
                highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
            else
                highlight.FillColor = Color3.fromRGB(242, 76, 76)
                highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
            end
        else
            if esperHighlights[player] then
                esperHighlights[player]:Destroy()
                esperHighlights[player] = nil
            end
        end
    end
end

esperToggle = EsperSection:CreateToggle({
    Text = "Enable Esper",
    Default = false,
    Callback = function(value)
        esperEnabled = value
        if not value then ClearEsper() end
    end,
})

EsperSection:CreateTextbox({
    Text = "Toggle Keybind",
    Placeholder = "E",
    Default = "E",
    Callback = function(text)
        esperKeybind = ParseInputBind(text, Enum.KeyCode.E)
    end,
})


-- ==========================================
-- ||           TRUE SHOT ABILITY          ||
-- ==========================================
local tsKeybind = Enum.UserInputType.MouseButton2
local tsPart = "Head"
local tsMode = "Camera"
local tsStrength = 30 
local tsFOV = 150
local tsWallCheck = true
local tsShowFOV = true

-- Prediction Settings
local tsPrediction = false
local tsProjSpeed = 1000

-- FOV Telegraph GUI Construction
local fovGui = Instance.new("ScreenGui")
fovGui.Name = "TrueShotFOV"
fovGui.ResetOnSpawn = false
fovGui.IgnoreGuiInset = true 
fovGui.Parent = CoreGui

local fovCircle = Instance.new("Frame")
fovCircle.Name = "FOVCircle"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = tsShowFOV
fovCircle.Parent = fovGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = UI.Theme.Accent or Color3.fromRGB(224, 42, 91)
fovStroke.Thickness = 1.5
fovStroke.Parent = fovCircle

local function UpdateFOVVisual()
    local diameter = tsFOV * 2
    fovCircle.Size = UDim2.fromOffset(diameter, diameter)
    fovCircle.Visible = tsShowFOV
    fovStroke.Color = UI.Theme.Accent or Color3.fromRGB(224, 42, 91)
end
UpdateFOVVisual()

local function GetTargetPart(plr)
    if not plr.Character then return nil end
    if tsPart == "Head" then
        return plr.Character:FindFirstChild("Head")
    else
        return plr.Character:FindFirstChild("HumanoidRootPart")
    end
end

-- Prediction Math function
local function GetPredictedPosition(targetPart)
    if not tsPrediction then 
        return targetPart.Position 
    end
    
    -- Prevent division by zero
    local speed = math.max(tsProjSpeed, 1)
    
    -- Calculate distance to target
    local distance = (targetPart.Position - Camera.CFrame.Position).Magnitude
    
    -- Calculate how long the bullet takes to arrive
    local timeToImpact = distance / speed
    
    -- Calculate where the target will be based on their current physics velocity
    local predictedOffset = targetPart.AssemblyLinearVelocity * timeToImpact
    
    return targetPart.Position + predictedOffset
end

local function GetClosestEnemy()
    local mousePos = UserInputService:GetMouseLocation()
    local closestTarget = nil
    local closestPredictedPos = nil
    local closestDist = tsFOV

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and IsEnemy(plr) and plr.Character then
            local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local targetPart = GetTargetPart(plr)
                if targetPart then
                    -- Get where they will be, or where they are (if prediction is off)
                    local predictedPos = GetPredictedPosition(targetPart)
                    
                    local screenPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < closestDist then
                            -- We still raycast wall check to the actual part to ensure we have physical Line of Sight
                            if tsWallCheck and not IsVisible(targetPart) then continue end
                            
                            closestDist = dist
                            closestTarget = targetPart
                            closestPredictedPos = predictedPos
                        end
                    end
                end
            end
        end
    end
    return closestTarget, closestPredictedPos
end

local function AimCamera(targetPos)
    local currentCF = Camera.CFrame
    local targetCF = CFrame.lookAt(currentCF.Position, targetPos)
    local alpha = math.clamp(tsStrength / 100, 0.01, 1)
    
    if alpha < 1 then
        Camera.CFrame = currentCF:Lerp(targetCF, alpha)
    else
        Camera.CFrame = targetCF 
    end
end

local function AimMouse(targetPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
    
    if onScreen then
        local mouseLoc = UserInputService:GetMouseLocation()
        local alpha = math.clamp(tsStrength / 100, 0.01, 1)
        
        local deltaX = (screenPos.X - mouseLoc.X) * alpha
        local deltaY = (screenPos.Y - mouseLoc.Y) * alpha
        
        if mousemoverel then 
            pcall(function() mousemoverel(deltaX, deltaY) end) 
        else
            pcall(function() VirtualInputManager:SendMouseMovement(deltaX, deltaY, nil) end)
        end
    end
end

TrueShotSection:CreateTextbox({
    Text = "Hold Keybind",
    Placeholder = "MouseButton2",
    Default = "MouseButton2",
    Callback = function(text)
        tsKeybind = ParseInputBind(text, Enum.UserInputType.MouseButton2)
    end,
})

TrueShotSection:CreateDropdown({
    Text = "Aim Mode",
    Options = { "Camera", "Mouse" },
    Default = "Camera",
    Callback = function(value)
        tsMode = value
    end,
})

TrueShotSection:CreateDropdown({
    Text = "Target Part",
    Options = { "Head", "HumanoidRootPart" },
    Default = "Head",
    Callback = function(value)
        tsPart = value
    end,
})

TrueShotSection:CreateSlider({
    Text = "Aim Strength (%)",
    Min = 1,
    Max = 100,
    Default = tsStrength,
    Increment = 1,
    Callback = function(value)
        tsStrength = value
    end,
})

TrueShotSection:CreateSlider({
    Text = "Field of View (FOV)",
    Min = 0,
    Max = 500,
    Default = tsFOV,
    Increment = 1,
    Callback = function(value)
        tsFOV = value
        UpdateFOVVisual()
    end,
})

TrueShotSection:CreateToggle({
    Text = "Enable Prediction",
    Default = tsPrediction,
    Callback = function(value)
        tsPrediction = value
    end,
})

TrueShotSection:CreateSlider({
    Text = "Projectile Speed",
    Min = 100,
    Max = 5000,
    Default = tsProjSpeed,
    Increment = 50,
    Callback = function(value)
        tsProjSpeed = value
    end,
})

TrueShotSection:CreateToggle({
    Text = "Show FOV Telegraph",
    Default = tsShowFOV,
    Callback = function(value)
        tsShowFOV = value
        UpdateFOVVisual()
    end,
})

TrueShotSection:CreateToggle({
    Text = "Wall Checker",
    Default = tsWallCheck,
    Callback = function(value)
        tsWallCheck = value
    end,
})


-- ==========================================
-- ||            MAIN GAME LOOP            ||
-- ==========================================

table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == esperKeybind or input.UserInputType == esperKeybind then
        esperEnabled = not esperEnabled
        esperToggle.Set(esperEnabled, true) 
        if not esperEnabled then ClearEsper() end
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    UpdateEsper()
    
    if tsShowFOV then
        local mousePos = UserInputService:GetMouseLocation()
        fovCircle.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
        if fovStroke.Color ~= UI.Theme.Accent then
            fovStroke.Color = UI.Theme.Accent
        end
    end

    local isHolding = false
    if tsKeybind.EnumType == Enum.UserInputType then
        isHolding = UserInputService:IsMouseButtonPressed(tsKeybind)
    elseif tsKeybind.EnumType == Enum.KeyCode then
        isHolding = UserInputService:IsKeyDown(tsKeybind)
    end

    if isHolding then
        local targetPart, predictedPos = GetClosestEnemy()
        if targetPart and predictedPos then
            if tsMode == "Camera" then
                AimCamera(predictedPos)
            else
                AimMouse(predictedPos)
            end
        end
    end
end))

-- ==========================================
-- ||        DESTRUCTION PIPELINE          ||
-- ==========================================
UI:OnKill(function()
    UI.Logger:Warn("Cleaning up FPS Abilities Lab connections and instances...", "System")
    
    for _, connection in ipairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    table.clear(Connections)
    
    ClearEsper()
    if esperFolder then esperFolder:Destroy() end
    if fovGui then fovGui:Destroy() end
    
    esperEnabled = false
    
    UI.Logger:Info("Cleanup complete.", "System")
end)

UI.Logger:Info("FPS Abilities Lab Loaded Successfully.", "System")
