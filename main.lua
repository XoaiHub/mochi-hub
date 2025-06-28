local CoreGui = game:GetService("CoreGui")
local obsidian = "Obsidian"

for _, v in ipairs(CoreGui:GetDescendants()) do
    if v:IsA("ScreenGui") and v.Name == obsidian then
        v:Destroy()
    else
    end
end

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/yue-os/ObsidianUi/refs/heads/main/Library.lua"))()
local player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local autoSubmit = false
local fruitThreshold = 10
local autoSell = false
local highlightToggle = false
local currentHighlight = nil
local currentBillboard = nil
local lastBiggest = nil
local flyEnabled = false
local noclipEnabled = false
local speedwalkEnabled = false
local speedValue = 16
local flyConn, noclipConn, speedConn
local autoBuySeeds = false
local savedPosition = nil

local function getOwnFarmSpawnCFrame()
    for _, farm in ipairs(workspace.Farm:GetChildren()) do
        local important = farm:FindFirstChild("Important")
        local data = important and important:FindFirstChild("Data")
        local owner = data and data:FindFirstChild("Owner")
        if owner and owner.Value == player.Name then
            local spawnPoint = farm:FindFirstChild("Spawn_Point")
            if spawnPoint and spawnPoint:IsA("BasePart") then
                return spawnPoint.CFrame
            end
        end
    end
    return nil
end

local function submitSummer()
    while autoSubmit do
        game:GetService("ReplicatedStorage")
            :WaitForChild("GameEvents")
            :WaitForChild("SummerHarvestRemoteEvent")
            :FireServer("SubmitHeldPlant")
        task.wait(0.1)
    end
end

local function keysOf(dict)
    local list = {}
    for k, v in pairs(dict) do
        if v then
            table.insert(list, k)
        end
    end
    return list
end

local function tpAndSell()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local returnCFrame = getOwnFarmSpawnCFrame()
        hrp.CFrame = CFrame.new(
            86.5854721, 2.76619363, 0.426784277,
            0, 0, -1,
            0, 1, 0,
            1, 0, 0
        )
        task.wait(0.2)
        ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Sell_Inventory"):FireServer()
        Library:Notify("Teleported and sold inventory!")
        if returnCFrame then
            task.wait(0.2)
            hrp.CFrame = returnCFrame
            Library:Notify("Returned to your garden spawn point!")
        else
            Library:Notify("Could not find your garden spawn point!")
        end
    else
        Library:Notify("HumanoidRootPart not found!")
    end
end

local function getFruitCount()
    local bag = player.Backpack
    local count = 0
    for _, v in pairs(bag:GetChildren()) do
        if v:FindFirstChild("Weight") and v:FindFirstChild("Variant") then
            count = count + 1
        end
    end
    return count
end


local function removeHighlight()
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
    if currentBillboard then
        currentBillboard:Destroy()
        currentBillboard = nil
    end
end

local function highlightBiggestFruit()
    local farm = nil
    for _, f in ipairs(workspace.Farm:GetChildren()) do
        local important = f:FindFirstChild("Important")
        local data = important and important:FindFirstChild("Data")
        local owner = data and data:FindFirstChild("Owner")
        if owner and owner.Value == player.Name then
            farm = f
            break
        end
    end
    if not farm then
        Library:Notify("No owned farm found.")
        removeHighlight()
        lastBiggest = nil
        return
    end

    local plants = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Plants_Physical")
    if not plants then
        Library:Notify("No Plants_Physical found.")
        removeHighlight()
        lastBiggest = nil
        return
    end

    local biggest, maxWeight = nil, -math.huge
    for _, fruit in ipairs(plants:GetChildren()) do
        local weightObj = fruit:FindFirstChild("Weight")
        if weightObj and tonumber(weightObj.Value) and tonumber(weightObj.Value) > maxWeight then
            biggest = fruit
            maxWeight = tonumber(weightObj.Value)
        end
    end

    if biggest ~= lastBiggest then
        removeHighlight()
        lastBiggest = biggest
        if biggest and biggest:IsA("Model") then
            -- Highlight
            local highlight = Instance.new("Highlight")
            highlight.FillColor = Color3.fromRGB(0, 255, 0)
            highlight.OutlineColor = Color3.fromRGB(0, 150, 0)
            highlight.FillTransparency = 0.3
            highlight.OutlineTransparency = 0
            highlight.Adornee = biggest
            highlight.Parent = biggest
            currentHighlight = highlight

            -- Billboard for weight
            local head = biggest:FindFirstChildWhichIsA("BasePart")
            if head then
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(0, 100, 0, 40)
                bb.AlwaysOnTop = true
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.Adornee = head
                bb.Parent = head

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.fromRGB(0, 255, 0)
                label.TextStrokeTransparency = 0.2
                label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                label.TextScaled = true
                label.Font = Enum.Font.FredokaOne
                label.Text = "Weight: " .. string.format("%.2f", maxWeight) .. "kg"
                label.Parent = bb

                currentBillboard = bb
            end
        end
    end
end

local function getShopSeeds()
    local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local seedShopGui = playerGui:WaitForChild("Seed_Shop")
    local seedsFrame = seedShopGui:WaitForChild("Frame"):WaitForChild("ScrollingFrame")

    local seedList = {}

    -- Insert "All" as the very first option
    table.insert(seedList, "All")

    for _, seedFrame in pairs(seedsFrame:GetChildren()) do
        if seedFrame:IsA("Frame") then
            local mainFrame = seedFrame:FindFirstChild("Main_Frame")
            if mainFrame then
                local seedText = mainFrame:FindFirstChild("Seed_Text")
                if seedText and seedText:IsA("TextLabel") then
                    local rawName = seedText.Text or ""
                    -- Strip the word "Seed" and surrounding spaces
                    local cleaned = rawName:gsub("%s*[sS]eed%s*", ""):gsub("^%s*(.-)%s*$", "%1")
                    table.insert(seedList, cleaned)
                end
            end
        end
    end

    return seedList
end


local function savePosition()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        savedPosition = hrp.Position
        Library:Notify("Position saved!")
    else
        Library:Notify("Could not save position (HumanoidRootPart missing).")
    end
end

local function teleportTo(pos)
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        Library:Notify("Could not teleport (HumanoidRootPart missing).")
        return
    end
    if typeof(pos) == "Vector3" then
        hrp.CFrame = CFrame.new(pos)
    elseif typeof(pos) == "string" then
        local x, y, z = string.match(pos, "Vector3%s*%(([^,]+),%s*([^,]+),%s*([^)]+)%)")
        if x and y and z then
            hrp.CFrame = CFrame.new(tonumber(x), tonumber(y), tonumber(z))
        end
    end
end

local function sellInventory()
    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Sell_Inventory"):FireServer()
    Library:Notify("Inventory sold!")
end

-- Submit all plants for Night Quest
local function submitNightQuest()
    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("NightQuestRemoteEvent"):FireServer("SubmitAllPlants")
    Library:Notify("Submitted all plants for Night Quest!")
end

-- Teleport, sell, and return
local function teleportSellReturn()
    savePosition()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(86.57965850830078, 2.999999761581421, 0.4267919063568115)
    task.wait(0.25)
    sellInventory()
    task.wait(0.2)
    if savedPosition then
        teleportTo(savedPosition)
        Library:Notify("Returned to saved position!")
    end
end

-- Teleport, submit night quest, and return
local function teleportNightQuestReturn()
    savePosition()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(-101.0422592163086, 4.400012493133545, -10.985257148742676)
    task.wait(0.25)
    submitNightQuest()
    task.wait(0.2)
    if savedPosition then
        teleportTo(savedPosition)
        Library:Notify("Returned to saved position!")
    end
end

-- Favorite currently equipped tool
local function favoriteEquippedTool()
    local char = player.Character
    local backpack = player.Backpack
    local tool = char and char:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
    if tool and tool:GetAttribute("Favorite") == true then
        ReplicatedStorage.GameEvents.Favorite_Item:FireServer({tool})
        Library:Notify("Favorited equipped tool!")
    else
        Library:Notify("No favorite tool equipped.")
    end
end


local function getGearShop()
    local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local gearShopGui = playerGui:WaitForChild("Gear_Shop")
    local gearsFrame = gearShopGui:WaitForChild("Frame"):WaitForChild("ScrollingFrame")

    local gearList = {}

    -- Insert "All" at the first position
    table.insert(gearList, "All")

    for _, gearFrame in pairs(gearsFrame:GetChildren()) do
        if gearFrame:IsA("Frame") then
            local mainFrame = gearFrame:FindFirstChild("Main_Frame")
            if mainFrame then
                local gearText = mainFrame:FindFirstChild("Gear_Text")
                if gearText and gearText:IsA("TextLabel") then
                    table.insert(gearList, gearText.Text)
                end
            end
        end
    end

    return gearList
end



--cut

local window = Library:CreateWindow({
    Title = "Y-Hub",
    Center = true,
    AutoShow = true,
    Size = UDim2.fromOffset(350, 180),
    ShowCustomCursor = false,
    ToggleKeybind = Enum.KeyCode.LeftControl
})

local mainTab = window:AddTab("Main")
local shopTab = window:AddTab("Shop")
local eventTab = window:AddTab("Event")
local playerTab = window:AddTab("Player")


local utilGroup = mainTab:AddLeftGroupbox("Teleport")
local group = mainTab:AddLeftGroupbox("Fruit")
local group2 = mainTab:AddRightGroupbox("Auto Harvest")
local lPlayer = playerTab:AddLeftGroupbox("Player")
local rShop = shopTab:AddRightGroupbox("UI")
local summer = eventTab:AddLeftGroupbox("Summer Event")
local seedShop = shopTab:AddLeftGroupbox("Seed Shop")
local gearShop = shopTab:AddLeftGroupbox("Gear Shop")
local petGroup = shopTab:AddRightGroupbox("Pet Automation")

group:AddSlider("fruit_slider", {
    Text = "Fruit Threshold",
    Min = 1,
    Max = 200,
    Default = 10,
    Rounding = 0,
    Callback = function(val)
        fruitThreshold = val
    end
})

group:AddToggle("auto_sell_toggle", {
    Text = "Auto Sell",
    Default = false,
    Callback = function(state)
        autoSell = state
        if autoSell then
            Library:Notify("Auto TP & Sell enabled.")
            task.spawn(function()
                while autoSell do
                    if getFruitCount() >= fruitThreshold then
                        tpAndSell()
                        task.wait(2)
                    end
                    task.wait(1)
                end
            end)
        else
            Library:Notify("Auto TP & Sell disabled.")
        end
    end
})

group:AddToggle("highlight_biggest_toggle", {
    Text = "Show Biggest",
    Default = false,
    Callback = function(state)
        highlightToggle = state
        if highlightToggle then
            highlightBiggestFruit()
            conn = RunService.RenderStepped:Connect(function()
                if highlightToggle then
                    highlightBiggestFruit()
                end
            end)
        else
            if conn then conn:Disconnect() end
            removeHighlight()
            lastBiggest = nil
        end
    end
})

lPlayer:AddToggle("fly", {
    Text = "Fly Mode",
    Default = false,
    Callback = function(Value)
        flyEnabled = Value
        if flyEnabled and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = Player.Character.HumanoidRootPart
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bodyVelocity.Parent = humanoidRootPart

            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bodyGyro.P = 10000
            bodyGyro.D = 1000
            bodyGyro.Parent = humanoidRootPart

            RunService.RenderStepped:Connect(function()
                if flyEnabled then
                    local moveDirection = Vector3.new(0, 0, 0)
                    if UIS:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + humanoidRootPart.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - humanoidRootPart.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - humanoidRootPart.CFrame.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + humanoidRootPart.CFrame.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
                    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then moveDirection = moveDirection - Vector3.new(0, 1, 0) end

                    moveDirection = moveDirection.Unit * flySpeed
                    bodyVelocity.Velocity = Vector3.new(moveDirection.X, moveDirection.Y, moveDirection.Z)
                    bodyGyro.CFrame = humanoidRootPart.CFrame
                end
            end)
            OrionLib:MakeNotification({
                Name = "Fly Mode",
                Content = "Fly Mode enabled (WASD to move, Space to ascend, Ctrl to descend)",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        else
            if bodyVelocity then bodyVelocity:Destroy() end
            if bodyGyro then bodyGyro:Destroy() end
            OrionLib:MakeNotification({
                Name = "Fly Mode",
                Content = "Fly Mode disabled",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
})

lPlayer:AddToggle("noclip_toggle", {
    Text = "Noclip",
    Default = false,
    Callback = function(state)
        noclipEnabled = state
        if noclipEnabled then
            noclipConn = game:GetService("RunService").Stepped:Connect(function()
                local char = player.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            Library:Notify("Noclip enabled.")
        else
            if noclipConn then noclipConn:Disconnect() noclipConn = nil end
            local char = player.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
            Library:Notify("Noclip disabled.")
        end
    end
})

lPlayer:AddSlider("speed_slider", {
    Text = "Speed",
    Min = 16,
    Max = 100,
    Default = 16,
    Rounding = 0,
    Callback = function(val)
        speedValue = val
        if speedwalkEnabled then
            local char = player.Character or player.CharacterAdded:Wait()
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = speedValue
            end
        end
    end
})

lPlayer:AddToggle("speedwalk_toggle", {
    Text = "Speedwalk",
    Default = false,
    Callback = function(state)
        speedwalkEnabled = state
        local char = player.Character or player.CharacterAdded:Wait()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if speedwalkEnabled and hum then
            hum.WalkSpeed = speedValue
            speedConn = char.ChildAdded:Connect(function(child)
                if child:IsA("Humanoid") then
                    child.WalkSpeed = speedValue
                end
            end)
            Library:Notify("Speedwalk enabled.")
        else
            if hum then hum.WalkSpeed = 16 end
            if speedConn then speedConn:Disconnect() speedConn = nil end
            Library:Notify("Speedwalk disabled.")
        end
    end
})

local seedList = getShopSeeds()
local selectedSeeds = {}

seedShop:AddDropdown("seed_dropdown", {
    Values = seedList,
    Multi = true,
    Searchable = true,
    Text = "Seeds Available",
    Default = {},               
    Callback = function(selected)
        selectedSeeds = keysOf(selected)
        Library:Notify("Selected seeds: " .. table.concat(selectedSeeds, ", "))
    end
})

seedShop:AddToggle("auto_buy_selected_seeds", {
    Text = "Auto Buy",
    Default = false,
    Callback = function(value)
        autoBuySeeds = value
        if autoBuySeeds then
            Library:Notify("Auto-buy enabled!")
            task.spawn(function()
                local event = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("BuySeedStock")

                while autoBuySeeds do
                    if #selectedSeeds > 0 then
                        for _, seedName in ipairs(selectedSeeds) do
                            event:FireServer(seedName)
                        end
                    end
                    task.wait(0.5)
                end
                Library:Notify("Auto-buy disabled!")
            end)
        else
            Library:Notify("Auto-buy disabled!")
        end
    end
})

utilGroup:AddButton("Save Position", savePosition)
utilGroup:AddButton("Teleport to Saved Position", function()
    if savedPosition then
        teleportTo(savedPosition)
        Library:Notify("Teleported to saved position!")
    else
        Library:Notify("No position saved yet.")
    end
end)
group:AddButton("Sell Inventory", sellInventory)
group:AddButton("TP, Sell, Return", teleportSellReturn)

local buyAllSeedsToggle = false
seedShop:AddToggle("buy_all_seeds_toggle", {
    Text = "Auto Buy All",
    Default = false,
    Callback = function(val)
        buyAllSeedsToggle = val
        if val then
            Library:Notify("Auto buy all seeds enabled.")
            task.spawn(function()
                while buyAllSeedsToggle do
                    for i = 1, 25 do
                        for _, seed in ipairs(selectedSeeds or {}) do
                            ReplicatedStorage.GameEvents.BuySeedStock:FireServer(seed)
                            task.wait()
                        end
                    end
                    task.wait(60)
                end
            end)
        else
            Library:Notify("Auto buy all seeds disabled.")
        end
    end
})
local gearList = getGearShop()
local selectedGears = {}

gearShop:AddDropdown("gear_dropdown", {
    Values = gearList,
    Multi = true,
    Searchable = true,
    Text = "Gears Available",
    Default = {},
    Callback = function(selected)
        selectedGears = keysOf(selected) -- make sure you have the keysOf helper
        Library:Notify("Selected gears: " .. table.concat(selectedGears, ", "))
    end
})

local autoBuyGears = false
gearShop:AddToggle("auto_buy_selected_gears", {
    Text = "Auto Buy Selected Gears",
    Default = false,
    Callback = function(value)
        autoBuyGears = value
        if autoBuyGears then
            Library:Notify("Auto-buy gears enabled!")
            task.spawn(function()
                local event = game:GetService("ReplicatedStorage").GameEvents:WaitForChild("BuyGearStock")

                while autoBuyGears do
                    if #selectedGears > 0 then
                        local toBuy = {}

                        if table.find(selectedGears, "All") then
                            -- Buy every gear except the "All" option
                            for _, gearName in ipairs(gearList) do
                                if gearName ~= "All" then
                                    table.insert(toBuy, gearName)
                                end
                            end
                        else
                            toBuy = selectedGears
                        end

                        print("[DEBUG] Buying gears:", table.concat(toBuy, ", "))
                        for _, gearName in ipairs(toBuy) do
                            event:FireServer(gearName)
                        end
                    end
                    task.wait(0.5)
                end
                Library:Notify("Auto-buy gears disabled!")
            end)
        else
            Library:Notify("Auto-buy gears disabled!")
        end
    end
})

local buyAllGearsToggle = false

gearShop:AddToggle("buy_all_gears_toggle", {
    Text = "Auto Buy All Gears",
    Default = false,
    Callback = function(val)
        buyAllGearsToggle = val
        if val then
            Library:Notify("Auto buy all gears enabled.")
            task.spawn(function()
                while buyAllGearsToggle do
                    for i = 1, 25 do
                        for _, gear in ipairs(selectedGears or {}) do
                            ReplicatedStorage.GameEvents.BuyGearStock:FireServer(gear)
                            task.wait()
                        end
                    end
                    task.wait(60)
                end
            end)
        else
            Library:Notify("Auto buy all gears disabled.")
        end
    end
})


local autoBuyPetsToggle = false
petGroup:AddToggle("auto_buy_pets_toggle", {
    Text = "Auto Buy All Eggs",
    Default = false,
    Callback = function(val)
        autoBuyPetsToggle = val
        if val then
            Library:Notify("Auto buy all pets enabled.")
            task.spawn(function()
                while autoBuyPetsToggle do
                    for i = 1, 3 do
                        for _, pet in ipairs({1, 2, 3}) do
                            ReplicatedStorage.GameEvents.BuyPetEgg:FireServer(pet)
                            task.wait()
                        end
                    end
                    task.wait(60)
                end
            end)
        else
            Library:Notify("Auto buy all pets disabled.")
        end
    end
})

rShop:AddButton("Cosmetic Shop", function()
    local ui = player.PlayerGui:FindFirstChild("CosmeticShop_UI")
    if ui then
        ui.Enabled = not ui.Enabled
        Library:Notify("Cosmetic Shop UI: " .. (ui.Enabled and "Enabled" or "Disabled"))
    end
end)

rShop:AddButton("Gear Shop", function()
    local ui = player.PlayerGui:FindFirstChild("Gear_Shop")
    if ui then
        ui.Enabled = not ui.Enabled
        Library:Notify("Gear Shop UI: " .. (ui.Enabled and "Enabled" or "Disabled"))
    end
end)

rShop:AddButton("Seed Shop", function()
    local ui = player.PlayerGui:FindFirstChild("Seed_Shop")
    if ui then
        ui.Enabled = not ui.Enabled
        Library:Notify("Seed Shop UI: " .. (ui.Enabled and "Enabled" or "Disabled"))
    end
end)

rShop:AddButton("Daily Quest", function()
    local ui = player.PlayerGui:FindFirstChild("DailyQuests_UI")
    if ui then
        ui.Enabled = not ui.Enabled
        Library:Notify("Daily Quest UI: " .. (ui.Enabled and "Enabled" or "Disabled"))
    end
end)

local antiAfkGroup = mainTab:AddRightGroupbox("Anti-AFK")
local antiAfkEnabled = false
local afkConnection

antiAfkGroup:AddToggle("anti_afk_toggle", {
    Text = "Enable Anti-AFK",
    Default = false,
    Callback = function(Value)
        antiAfkEnabled = Value

        if antiAfkEnabled then
            -- Connect the event
            afkConnection = player.Idled:Connect(function()
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
            Library:Notify("Anti-AFK enabled!")
        else
            -- Disconnect the event
            if afkConnection then
                afkConnection:Disconnect()
                afkConnection = nil
            end
            Library:Notify("Anti-AFK disabled!")
        end
    end
})


local minWeight, maxWeight = 0, 9999
group2:AddSlider("min_weight_slider", {
    Text = "Min Weight (kg)",
    Min = 0,
    Max = 9999,
    Default = 0,
    Rounding = 2,
    Callback = function(val)
        minWeight = val
        Library:Notify("Min Weight set to: " .. tostring(minWeight))
    end
})
group2:AddSlider("max_weight_slider", {
    Text = "Max Weight (kg)",
    Min = 0,
    Max = 9999,
    Default = 9999,
    Rounding = 2,
    Callback = function(val)
        maxWeight = val
        Library:Notify("Max Weight set to: " .. tostring(maxWeight))
    end
})

local instantCollectEnabled = false
group2:AddToggle("instant_collect_toggle", {
    Text = "Auto Collect",
    Default = false,
    Callback = function(state)
        instantCollectEnabled = state
        if instantCollectEnabled then
            Library:Notify("Instant collect enabled!")
            task.spawn(function()
                while instantCollectEnabled do
                    local players = game:GetService("Players")
                    local replicated_storage = game:GetService("ReplicatedStorage")
                    local get_farm = require(replicated_storage.Modules.GetFarm)
                    local byte_net_reliable = replicated_storage:WaitForChild("ByteNetReliable")
                    local buffer = buffer.fromstring("\1\1\0\1")

                    local local_player = players.LocalPlayer
                    local farm = get_farm(local_player)
                    if not farm or not farm.Important or not farm.Important:FindFirstChild("Plants_Physical") then
                        Library:Notify("Could not find your farm plants.")
                        break
                    end

                    for _, v in next, farm.Important.Plants_Physical:GetChildren() do
                        if harvestFilter(v, minWeight, maxWeight) then
                            byte_net_reliable:FireServer(buffer, { v })
                        end
                        if v:FindFirstChild("Fruits", true) then
                            for _, i in next, v.Fruits:GetChildren() do
                                if harvestFilter(i, minWeight, maxWeight) then
                                    byte_net_reliable:FireServer(buffer, { i })
                                end
                            end
                        end
                    end
                    task.wait(2) -- Adjust delay as needed
                end
                Library:Notify("Instant collect disabled!")
            end)
        else
            Library:Notify("Instant collect disabled!")
        end
    end
})


summer:AddToggle("auto_submit_summer", {
    Text = "Auto Submit Plant",
    Default = false,
    Callback = function(Value)
        autoSubmit = Value
        if autoSubmit then
            Library:Notify("Auto Submit Hold Plants")
            -- Run the submitSummer in a new thread so it doesn't block
            task.spawn(submitSummer)
        else
            Library:Notify("Disabled Auto Submit")
        end
    end
})

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local infiniteJump = false

lPlayer:AddToggle("infinite_jump_toggle", {
    Text = "Infinite Jump",
    Default = false,
    Callback = function(enabled)
        infiniteJump = enabled
    end
})

UserInputService.JumpRequest:Connect(function()
    if infiniteJump then
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)
