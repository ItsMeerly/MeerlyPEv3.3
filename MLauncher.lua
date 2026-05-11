--[[
    Meerly Launcher (MLauncher)
    Full-screen-first keygate and Roblox PlaceId/GameId router for loading authorized game scripts.

    Entry:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/ItsMeerly/Meerly-Peak-Evolution/main/MLauncher.lua"))()
]]

local Launcher = {}
Launcher.Version = "0.1.0"
Launcher.RepositoryRoot = "https://raw.githubusercontent.com/ItsMeerly/Meerly-Peak-Evolution/main"
Launcher.LibraryUrl = Launcher.RepositoryRoot .. "/MUILib.lua"

Launcher.ValidKeys = {
    -- Replace these with your own local/testing keys, or swap ValidateKey for a remote API check.
    ["MEERLY-DEV"] = true,
}

Launcher.Games = {
    Places = {
        -- [1234567890] = {
        --     Name = "Example Place",
        --     Url = Launcher.RepositoryRoot .. "/Games/Example.lua",
        --     Enabled = true,
        -- },
    },
    Universes = {
        -- [1234567890] = {
        --     Name = "Example Universe",
        --     Url = Launcher.RepositoryRoot .. "/Games/Example.lua",
        --     Enabled = true,
        -- },
    },
}

local function safeHttpGet(url)
    return game:HttpGet(url)
end

function Launcher:LoadLibrary()
    local source = safeHttpGet(self.LibraryUrl)
    return loadstring(source)()
end

function Launcher:ValidateKey(key)
    key = tostring(key or "")
    if key == "" then
        return false, "Enter a key first."
    end
    if self.ValidKeys[key] then
        return true, "Key accepted."
    end
    return false, "Invalid key."
end

function Launcher:GetGameConfig()
    local placeId = game.PlaceId
    local gameId = game.GameId
    local placeConfig = self.Games.Places[placeId]
    if placeConfig then
        return placeConfig, "PlaceId", placeId
    end
    local universeConfig = self.Games.Universes[gameId]
    if universeConfig then
        return universeConfig, "GameId", gameId
    end
    return nil, "Unsupported", placeId
end

function Launcher:LoadGameScript(gameConfig, context)
    if not gameConfig then
        context.Logger:Error("No game config was provided.", "Launcher")
        return false
    end
    if gameConfig.Enabled == false then
        context.Logger:Warn("This game script is disabled in the launcher registry.", "Launcher")
        return false
    end
    if not gameConfig.Url or gameConfig.Url == "" then
        context.Logger:Warn("No script URL configured for " .. tostring(gameConfig.Name or "this game") .. ".", "Launcher")
        return false
    end

    context.Logger:Info("Fetching script for " .. tostring(gameConfig.Name or "configured game") .. ".", "Loader")
    local ok, result = pcall(function()
        local source = safeHttpGet(gameConfig.Url)
        local loaded = loadstring(source)
        return loaded()
    end)

    if not ok then
        context.Logger:Error(result, "Loader")
        return false
    end

    if type(result) == "function" then
        local ran, err = pcall(function()
            result(context)
        end)
        if not ran then
            context.Logger:Error(err, "GameScript")
            return false
        end
    elseif type(result) == "table" and type(result.Start) == "function" then
        local ran, err = pcall(function()
            result:Start(context)
        end)
        if not ran then
            context.Logger:Error(err, "GameScript")
            return false
        end
    end

    context.Logger:Info("Game script loaded successfully.", "Loader")
    return true
end

function Launcher:BuildKeygate(UI)
    local keyTab = UI:CreateTab("Keygate")
    UI:SelectTab("Keygate")

    local access = keyTab:CreateSection("Access")
    access:CreateLabel("Enter your Meerly key to unlock game-specific loading.")
    access:CreateLabel("Press ; to minimize/restore. Use X to kill and run cleanup callbacks.")

    local storedKey = ""
    UI.Config["Last Launcher Key Input"] = UI.Config["Last Launcher Key Input"] or { Key = "" }
    storedKey = UI.Config["Last Launcher Key Input"].Key or ""

    local keyBox = access:CreateTextbox({
        Text = "Key",
        Placeholder = "Enter key...",
        Default = storedKey,
        Callback = function(text)
            UI.Config["Last Launcher Key Input"].Key = text
            UI:SaveUIConfig()
        end,
    })

    local status = access:CreateLabel("Status: Waiting for key.")

    access:CreateButton({
        Text = "Validate Key & Load Game",
        Callback = function()
            local key = keyBox.Text
            UI.Config["Last Launcher Key Input"].Key = key
            UI:SaveUIConfig()

            local valid, message = self:ValidateKey(key)
            if not valid then
                status.Text = "Status: " .. message
                UI.Logger:Warn(message, "Keygate")
                return
            end

            status.Text = "Status: Key accepted. Detecting game..."
            UI.Logger:Info(message, "Keygate")

            local gameConfig, matchType, matchId = self:GetGameConfig()
            local gameSave = UI:GetGameConfig(matchId)
            gameSave.LastLoadedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
            gameSave.MatchType = matchType
            UI:SetGameConfig(matchId, gameSave)

            if not gameConfig then
                status.Text = "Status: Unsupported game."
                UI.Logger:Error("Unsupported game. PlaceId=" .. tostring(game.PlaceId) .. ", GameId=" .. tostring(game.GameId), "Router")
                return
            end

            UI.Logger:Info("Matched " .. matchType .. " " .. tostring(matchId) .. " -> " .. tostring(gameConfig.Name or "Unnamed"), "Router")

            local context = {
                UI = UI,
                Logger = UI.Logger,
                Window = UI.Window,
                Launcher = self,
                PlaceId = game.PlaceId,
                GameId = game.GameId,
                MatchType = matchType,
                MatchId = matchId,
                GameConfig = gameConfig,
                GameSave = gameSave,
            }

            local loaded = self:LoadGameScript(gameConfig, context)
            status.Text = loaded and "Status: Loaded " .. tostring(gameConfig.Name or "game") .. "." or "Status: Load failed. Check Console."
        end,
    })

    access:CreateButton({
        Text = "Kill Launcher",
        Callback = function()
            UI:Kill()
        end,
    })
end

function Launcher:Start()
    local MUILib = self:LoadLibrary()
    local UI = MUILib.new({
        Title = "Meerly Launcher",
        Theme = "MeerlyDark",
        Size = UDim2.fromOffset(580, 390),
        MinSize = Vector2.new(430, 285),
        Console = false,
        ThemeTab = false,
    })

    UI.Logger:Info("MLauncher " .. self.Version .. " started.", "Launcher")
    UI.Logger:Debug("PlaceId=" .. tostring(game.PlaceId) .. ", GameId=" .. tostring(game.GameId), "Launcher")

    UI:OnKill(function()
        UI.Logger:Info("Launcher kill callback executed.", "Launcher")
    end)

    self:BuildKeygate(UI)
    UI:CreateThemeTab()
    UI:_buildConsole()
    UI:SelectTab("Keygate")
    return UI
end

return Launcher:Start()
