-- Item Placement System v4 HYPER - Parallel batch firing
-- Fires multiple items simultaneously for maximum speed

local response = request({
	Url = "https://raw.githubusercontent.com/ItsMeerly/MeerlyPEv3.3/refs/heads/main/MUILib.lua",
	Method = "GET"
})

if response.StatusCode ~= 200 then
	error("Failed to load MUILib: " .. tostring(response.StatusCode))
end

local MUILib = loadstring(response.Body)()
local UI = MUILib.new({
	Title = "Item Placement System v4 - HYPER",
	Console = true
})

-- Game services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = require(ReplicatedStorage.shared.network)

-- Wait for folders
local ITEMS_FOLDER = game.Workspace:WaitForChild("Items", 5)
local HITBOXES_FOLDER = game.Workspace:WaitForChild("ItemTypeHitboxes", 5)

if not ITEMS_FOLDER or not HITBOXES_FOLDER then
	error("Could not find required folders")
end

-- State
local isRunning = false
local itemsPlaced = 0
local totalItems = 0
local batchSize = 50
local batchDelay = 0.001

UI.Logger:Info("Item Placement System v4 HYPER - Parallel Batch Firing", "System")

-- Create main tab
local mainTab = UI:CreateTab("Placement")
local settingsSection = mainTab:CreateSection("Settings")
local controlsSection = mainTab:CreateSection("Controls")
local statusSection = mainTab:CreateSection("Status")

-- Status display
local statusLabel = statusSection:CreateLabel("Status: Ready")
local progressLabel = statusSection:CreateLabel("Progress: 0/0")
local currentItemLabel = statusSection:CreateLabel("Current: Batching...")
local speedLabel = statusSection:CreateLabel("Mode: Parallel Batch (50 items/batch)")

-- Helper to count total items
local function countTotalItems()
	local count = 0
	for _, categoryFolder in pairs(ITEMS_FOLDER:GetChildren()) do
		if categoryFolder:IsA("Folder") then
			for _, itemTypeFolder in pairs(categoryFolder:GetChildren()) do
				if itemTypeFolder:IsA("Folder") then
					count = count + #itemTypeFolder:GetChildren()
				end
			end
		end
	end
	return count
end

-- Main placement function - HYPER PARALLEL
local function placeItems()
	isRunning = true
	itemsPlaced = 0
	totalItems = countTotalItems()
	
	local startTime = tick()
	UI.Logger:Info("Starting HYPER placement of " .. totalItems .. " items with batch size: " .. batchSize, "Placement")
	
	-- Create hitbox mapping
	local hitboxMap = {}
	for _, hitbox in pairs(HITBOXES_FOLDER:GetChildren()) do
		if hitbox:IsA("Part") then
			hitboxMap[hitbox.Name] = hitbox
		end
	end
	
	-- Process each category
	for _, categoryFolder in pairs(ITEMS_FOLDER:GetChildren()) do
		if not isRunning then break end
		if not categoryFolder:IsA("Folder") then continue end
		
		-- Process each item type
		for _, itemTypeFolder in pairs(categoryFolder:GetChildren()) do
			if not isRunning then break end
			if not itemTypeFolder:IsA("Folder") then continue end
			
			local itemTypeName = itemTypeFolder.Name
			local hitbox = hitboxMap[itemTypeName]
			
			if not hitbox then
				UI.Logger:Warn("No hitbox for item type: " .. itemTypeName, "Placement")
				continue
			end
			
			-- Batch fire items
			local batchCount = 0
			for _, item in pairs(itemTypeFolder:GetChildren()) do
				if not isRunning then break end
				
				-- Fire equip and place immediately (non-blocking via task.spawn)
				task.spawn(function()
					pcall(function()
						network.Fire("client_request_item_equip", item)
						network.Fire("client_request_item_place", item, itemTypeName)
					end)
				end)
				
				itemsPlaced = itemsPlaced + 1
				batchCount = batchCount + 1
				
				-- After batch, yield briefly to let server catch up
				if batchCount >= batchSize then
					currentItemLabel.Text = "Batch complete (" .. batchCount .. " items)"
					task.wait(batchDelay)
					batchCount = 0
				end
			end
			
			if not isRunning then break end
		end
	end
	
	-- Wait for remaining items to process
	task.wait(0.1)
	
	local elapsedTime = tick() - startTime
	isRunning = false
	UI.Logger:Info("✓ Placement complete! " .. itemsPlaced .. " items in " .. string.format("%.2f", elapsedTime) .. "s", "Placement")
	UI.Logger:Info("Speed: " .. string.format("%.1f", totalItems / elapsedTime) .. " items/sec", "Stats")
end

-- Settings Section
settingsSection:CreateSlider({
	Text = "Batch Size",
	Min = 1,
	Max = 500,
	Default = 50,
	Increment = 10,
	Callback = function(value)
		batchSize = value
		speedLabel.Text = "Batch Size: " .. value .. " items/batch"
		UI.Logger:Debug("Batch size: " .. value, "Settings")
	end
})

settingsSection:CreateSlider({
	Text = "Batch Delay (ms)",
	Min = 0,
	Max = 50,
	Default = 1,
	Increment = 1,
	Callback = function(value)
		batchDelay = value / 1000
		UI.Logger:Debug("Batch delay: " .. value .. "ms", "Settings")
	end
})

-- Controls Section
controlsSection:CreateButton({
	Text = "📊 Count Items",
	Callback = function()
		local count = countTotalItems()
		statusLabel.Text = "Total items: " .. count
		UI.Logger:Info("Counted " .. count .. " items", "Placement")
	end
})

controlsSection:CreateButton({
	Text = "⚡⚡ START HYPER",
	Callback = function()
		if not isRunning then
			task.spawn(placeItems)
			UI.Logger:Info("HYPER mode: Batch size=" .. batchSize, "Placement")
		else
			UI.Logger:Warn("Already running!", "Placement")
		end
	end
})

controlsSection:CreateButton({
	Text = "⏹ STOP",
	Callback = function()
		if isRunning then
			isRunning = false
			UI.Logger:Info("Stopped", "Placement")
		end
	end
})

-- Real-time status updates
task.spawn(function()
	while true do
		task.wait(0.1)
		if isRunning then
			statusLabel.Text = "Status: ⚡⚡ HYPER RUNNING"
			local percent = totalItems > 0 and (itemsPlaced / totalItems * 100) or 0
			progressLabel.Text = string.format("Progress: %d/%d (%.1f%%)", itemsPlaced, totalItems, percent)
		else
			statusLabel.Text = "Status: Ready"
			progressLabel.Text = "Progress: Waiting"
		end
	end
end)

print("✓ HYPER v4 loaded!")
print("✓ Parallel batch firing enabled")
print("✓ Speed settings: Batch Size + Delay")
print("✓ Prepare for ultra-speed!")
