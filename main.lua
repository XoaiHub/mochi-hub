local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer
local promptTracker = {}
local descendantConnection = nil

-- Utility Functions
local function parseMoney(moneyStr)
    if not moneyStr then return 0 end
    moneyStr = tostring(moneyStr):gsub("Г‚Вў", ""):gsub(",", ""):gsub(" ", ""):gsub("%$", "")
    local multiplier = 1
    if moneyStr:lower():find("k") then
        multiplier = 1000
        moneyStr = moneyStr:lower():gsub("k", "")
    elseif moneyStr:lower():find("m") then
        multiplier = 1000000
        moneyStr = moneyStr:lower():gsub("m", "")
    end
    return (tonumber(moneyStr) or 0) * multiplier
end

-- Get player money (replace with actual stat name)
local function getPlayerMoney()
    return parseMoney(lp:WaitForChild("leaderstats").Money.Value) -- ADJUST THIS
end

local function isInventoryFull()
    return #lp.Backpack:GetChildren() >= 200
end 

-- Auto-collect functions
local function modifyPrompt(prompt, enable)
    if enable then
        prompt.Enabled = true
        prompt.RequiresLineOfSight = false
        prompt.HoldDuration = 0
    else
        prompt.Enabled = false
    end
end

local function handleNewPrompt(desc)
    if desc:IsA("ProximityPrompt") and not promptTracker[desc] then
        promptTracker[desc] = true
        modifyPrompt(desc, true)
        
        -- Auto-trigger prompt
        fireproximityprompt(desc)
    end
end

local function startAutoCollect()
    descendantConnection = workspace.DescendantAdded:Connect(handleNewPrompt)
    for _, desc in ipairs(workspace:GetDescendants()) do
        handleNewPrompt(desc)
    end
end

local function stopAutoCollect()
    if descendantConnection then
        descendantConnection:Disconnect()
        descendantConnection = nil
    end
    for prompt in pairs(promptTracker) do
        modifyPrompt(prompt, false)
    end
    promptTracker = {}
end

-- Use UPDATED library URL
local redzlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/tbao143/Library-ui/refs/heads/main/Redzhubui"))() 
local Window = redzlib:MakeWindow({
    Title = "GROW A GARDEN || qilin hub🦄",
    SubTitle = "https://t.me/qlnscrpt",
    SaveFolder = "Redz library"
})

Window:AddMinimizeButton({
    Button = { Image = "rbxassetid://10709761889", BackgroundTransparency = 0 },
    Corner = { CornerRadius = UDim.new(35, 1) },
})

local Tab1 = Window:MakeTab({"🌟MAIN", "Тест"})
local Tab2 = Window:MakeTab({"🌾AUTO FARM ", "Тест"})
local Tab3 = Window:MakeTab({"🪄ITEMS", "Тест"})
local Tab4 = Window:MakeTab({"🪟GUI", "Тест"})
local Tab5 = Window:MakeTab({"👤PLAYER", "Тест"})
local Tab6 = Window:MakeTab({"⁉️OTHER", "Тест"})
local Tab7 = Window:MakeTab({"😮DUPE", "Тест"})
local Tab8 = Window:MakeTab({"😮DUPE V2", "Тест"})
local Tab9 = Window:MakeTab({"🐝BEE EVENT", "Тест"})

Tab1:AddDiscordInvite({
    Name = "QILIN SCRIPTS",
    Description = "ЗДЕСЬ ТЫ НАЙДЁШЬ САМЫЕ ЛУТШИЕ СКРИПТЫ HERE YOU WILL FIND THE BEST SCRIPTS  ",
    Logo = "rbxassetid://18751483361",
    Invite = "https://t.me/qlnscrpt",
})

-- Define these in the outer scope (at the top of the script or at least above the toggle)
local autoFarmEnabled = false
local farmThread = nil

Tab2:AddToggle({
    Name = "AUTO FARM",
    Default = false,
    Callback = function(state)
        autoFarmEnabled = state
        if autoFarmEnabled then
            if farmThread then
                task.cancel(farmThread)
                farmThread = nil
            end
            farmThread = task.spawn(function()
                -- This function is now inside the task, so it's local to this thread.
                local function updateFarmData()
                    local farmsList = {}
                    local plantsList = {}
                    for _, farm in pairs(workspace:FindFirstChild("Farm"):GetChildren()) do
                        local data = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Data")
                        if data and data:FindFirstChild("Owner") and data.Owner.Value == lp.Name then
                            table.insert(farmsList, farm)
                            local plantsFolder = farm.Important:FindFirstChild("Plants_Physical")
                            if plantsFolder then
                                for _, plantModel in pairs(plantsFolder:GetChildren()) do
                                    for _, part in pairs(plantModel:GetDescendants()) do
                                        if part:IsA("BasePart") and part:FindFirstChildOfClass("ProximityPrompt") then
                                            table.insert(plantsList, part)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    return farmsList, plantsList
                end

                local function glitchTeleport(pos)
                    if not lp.Character then return end
                    local root = lp.Character:FindFirstChild("HumanoidRootPart")
                    if not root then return end
                    local tween = TweenService:Create(root, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {
                        CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
                    })
                    tween:Play()
                end

                while autoFarmEnabled do
                    -- Check inventory
                    while autoFarmEnabled and isInventoryFull() do
                        task.wait(1)
                    end
                    if not autoFarmEnabled then break end

                    local farms, plants = updateFarmData()

                    for _, part in pairs(plants) do
                        if not autoFarmEnabled or isInventoryFull() then break end
                        if part and part.Parent then
                            local prompt = part:FindFirstChildOfClass("ProximityPrompt")
                            if prompt then
                                glitchTeleport(part.Position)
                                task.wait(0.2)

                                for _, farm in pairs(farms) do
                                    if not autoFarmEnabled or isInventoryFull() then break end
                                    for _, obj in pairs(farm:GetDescendants()) do
                                        if obj:IsA("ProximityPrompt") then
                                            local str = tostring(obj.Parent)
                                            if not (str:find("Grow_Sign") or str:find("Core_Part")) then
                                                fireproximityprompt(obj, 1)
                                            end
                                        end
                                    end
                                end

                                if not autoFarmEnabled then break end
                                task.wait(0.2)
                            end
                        end
                    end

                    task.wait(0.1)
                end
            end)
        else
            if farmThread then
                task.cancel(farmThread)
                farmThread = nil
            end
        end
    end
})
--Auto plant 
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Farm location
local farm = nil
for _, v in next, Workspace:FindFirstChild("Farm"):GetDescendants() do
    if v.Name == "Owner" and v.Value == LocalPlayer.Name then
        farm = v.Parent.Parent
        break
    end
end

-- State variables
local autoPlant = false
local plantDelay = 0.1
local plantPosition = nil
local autoPlantMethod = "Player Position"

-- Auto Plant Functionality
local function startAutoPlant()
    if not autoPlant then return end
    
    task.spawn(function()
        while autoPlant do
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool") 
            and LocalPlayer.Character:FindFirstChildOfClass("Tool"):GetAttribute("ItemType") == "Seed" then
                
                if autoPlantMethod == "Choosen Position" and plantPosition then
                    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Plant_RE"):FireServer(plantPosition, LocalPlayer.Character:FindFirstChildOfClass("Tool"):GetAttribute("ItemName"))
                elseif autoPlantMethod == "Player Position" then
                    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Plant_RE"):FireServer(LocalPlayer.Character:GetPivot().Position, LocalPlayer.Character:FindFirstChildOfClass("Tool"):GetAttribute("ItemName"))
                end
                
                task.wait(plantDelay)
            end
            task.wait()
        end
    end)
end

Tab2:AddToggle({
    Name = "AUTO PLANT",
    Default = false,
    Callback = function(state)
     autoPlant = state
        if state then
            startAutoPlant()
        end

    end
})

local Dropdown = Tab2:AddDropdown({
  Name = "Plant Method",
  Description = "Выберите <font color='rgb(88, 101, 242)'>число</font>",
  Options = {"Player Position", "Choosen Position"},
  Default = "two",
  Flag = "dropdown teste",
  Callback = function(option)
    autoPlantMethod = option
  end
})

Tab2:AddButton({"HONEY FARM(must have 10kg fruits or more)", function(Value)
-- honey farm
-- must have 10kg fruits or more

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local jar = workspace.Interaction.UpdateItems.HoneyEvent.HoneyCombpressor.Spout:WaitForChild("Jar")
local player = game.Players.LocalPlayer
local pollinatedTools = {}

local function updateList()
	pollinatedTools = {}
	for _, tool in ipairs(player.Backpack:GetChildren()) do
		local weightObj = tool:FindFirstChild("Weight")
		local weight = weightObj and weightObj:IsA("NumberValue") and weightObj.Value or 0

		local favObj = tool:FindFirstChild("Favorite")
		local isFav = favObj and favObj:IsA("BoolValue") and favObj.Value or false

		if tool.Name:match("%[.-Pollinated.-%]") and weight >= 10 and not isFav then
			table.insert(pollinatedTools, tool)
		end
	end
end

updateList()

player.Backpack.ChildAdded:Connect(updateList)
player.Backpack.ChildRemoved:Connect(updateList)

local proximityPrompt = jar:FindFirstChild("HoneyCombpressorPrompt")
if proximityPrompt then
    ReplicatedStorage.GameEvents.HoneyMachineService_RE:FireServer("MachineInteract")
end

local busy = false

RunService.RenderStepped:Connect(function()
    if busy then return end
    busy = true

    local statusText = workspace.Interaction.UpdateItems.HoneyEvent.HoneyCombpressor.Sign.SurfaceGui.TextLabel.Text

    if (not statusText:match("^%d+:0%d$") and not statusText:match("^%d+:%d%d$")) and not statusText:find("READY") then
        if #pollinatedTools > 0 then
            player.Character.Humanoid:EquipTool(pollinatedTools[math.random(#pollinatedTools)])
        end
        ReplicatedStorage.GameEvents.HoneyMachineService_RE:FireServer("MachineInteract")
    end

    task.wait(0.5)
    busy = false
end)

jar.ChildAdded:Connect(function(child)
    if child:IsA("ProximityPrompt") and child.Name == "HoneyCombpressorPrompt" then
        ReplicatedStorage.GameEvents.HoneyMachineService_RE:FireServer("MachineInteract")
        task.wait(1)
    end
end)
end})


-- AUTO BUY
Tab2:AddToggle({
    Name = "AUTO BUY",
    Default = false,
    Callback = function(v)
        autoBuySeeds = v
        task.spawn(function()
            while autoBuySeeds do
                for _, name in ipairs({
                    "Carrot","Strawberry","Blueberry","Orange Tulip","Tomato",
                    "Corn","Daffodil","Watermelon","Pumpkin","Apple","Bamboo",
                    "Coconut","Cactus","Dragon Fruit","Mango","Grape","Mushroom",
                    "Pepper","Cacao","Beanstalk"
                }) do
                    ReplicatedStorage.GameEvents.BuySeedStock:FireServer(name)
                end
                task.wait(2)
            end
        end)
    end
})






-- AUTO COLLECT
Tab2:AddToggle({
    Name = "AUTO COLLECT",
    Default = false,
    Callback = function(vs)
        spamE = vs
        if spamE then
            startAutoCollect()
        else
            stopAutoCollect()
        end
    end
})

Tab2:AddToggle({
    Name = "Auto Collect Pollinated Fruits",
    Default = false,
    Callback = function(state)
local function AutoCollectPollinatedFruits(state)
    autoCollectPollinatedEnabled = state
    local pickup_radius = 50

    if state then
        autoCollectPollinatedThread = task.spawn(function()
            local farm_model
            for _, farm in ipairs(workspace.Farm:GetChildren()) do
                local data = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Data")
                if data and data:FindFirstChild("Owner") and data.Owner.Value == player.Name then
                    farm_model = farm
                    break
                end
            end

            while autoCollectPollinatedEnabled and farm_model and task.wait() do
                local plants_folder = farm_model.Important:FindFirstChild("Plants_Physical")
                if plants_folder and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local playerPosition = player.Character.HumanoidRootPart.Position

                    for _, plant_model in ipairs(plants_folder:GetChildren()) do
                        if plant_model:IsA("Model") then
                            local fruits = plant_model:FindFirstChild("Fruits")
                            if fruits then
                                for _, fruit_model in ipairs(fruits:GetChildren()) do
                                    if fruit_model:GetAttribute("Pollinated") == true then
                                        for _, part in ipairs(fruit_model:GetDescendants()) do
                                            if part:IsA("BasePart") then
                                                local prompt = part:FindFirstChildOfClass("ProximityPrompt")
                                                if prompt then
                                                    local fruitPosition = part.Position
                                                    local distance = (fruitPosition - playerPosition).Magnitude
                                                    
                                                    if distance <= pickup_radius then
                                                        fireproximityprompt(prompt)
                                                        task.wait(0.05)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    else
        if autoCollectPollinatedThread then
            task.cancel(autoCollectPollinatedThread)
            autoCollectPollinatedThread = nil
        end
    end
end
    end
})


-- AUTO SELL
local autoSellEnabled = false
local autoSellThread

local function sellItems()
    local steven = workspace.NPCS:FindFirstChild("Steven")
    if not steven then return false end
    
    local char = lp.Character
    if not char then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local originalPosition = hrp.CFrame
    hrp.CFrame = steven.HumanoidRootPart.CFrame * CFrame.new(0, 3, 3)
    task.wait(0.5)
    
    for _ = 1, 5 do
        pcall(function()
            ReplicatedStorage.GameEvents.Sell_Inventory:FireServer()
        end)
        task.wait(0.15)
    end
    
    hrp.CFrame = originalPosition
    return true
end

Tab2:AddToggle({
    Name = "AUTO SELL",
    Default = false,
    Callback = function(vp)
        autoSellEnabled = vp
        if autoSellEnabled then
            autoSellThread = task.spawn(function()
                while autoSellEnabled do
                    sellItems()
                    task.wait(5)
                end
            end)
        elseif autoSellThread then
            task.cancel(autoSellThread)
            autoSellThread = nil
        end
    end
})

local HarvestEnabled = false
local HarvestConnection = nil

local function FindGarden()
    local farm = workspace:FindFirstChild("Farm")
    if not farm then return nil end
    
    for _, plot in ipairs(farm:GetChildren()) do
        local data = plot:FindFirstChild("Important") and plot.Important:FindFirstChild("Data")
        local owner = data and data:FindFirstChild("Owner")
        if owner and owner.Value == lp.Name then
            return plot
        end
    end
    return nil
end

local function CanHarvest(part)
    local prompt = part:FindFirstChild("ProximityPrompt")
    return prompt and prompt.Enabled
end

local function Harvest()
    if not HarvestEnabled then return end
    if isInventoryFull() then return end
    
    local garden = FindGarden()
    if not garden then return end
    
    local plants = garden:FindFirstChild("Important") and garden.Important:FindFirstChild("Plants_Physical")
    if not plants then return end
    
    for _, plant in ipairs(plants:GetChildren()) do
        if not HarvestEnabled then break end
        local fruits = plant:FindFirstChild("Fruits")
        if fruits then
            for _, fruit in ipairs(fruits:GetChildren()) do
                if not HarvestEnabled then break end
                for _, part in ipairs(fruit:GetChildren()) do
                    if not HarvestEnabled then break end
                    if part:IsA("BasePart") and CanHarvest(part) then
                        local prompt = part.ProximityPrompt
                        local pos = part.Position + Vector3.new(0, 3, 0)
                        if lp.Character and lp.Character.PrimaryPart then
                            lp.Character:SetPrimaryPartCFrame(CFrame.new(pos))
                            task.wait(0.1)
                            if not HarvestEnabled then break end
                            prompt:InputHoldBegin()
                            task.wait(0.1)
                            if not HarvestEnabled then break end
                            prompt:InputHoldEnd()
                            task.wait(0.1)
                        end
                    end
                end
            end
        end
    end
end

local function ToggleHarvest(state)
    if HarvestConnection then
        HarvestConnection:Disconnect()
        HarvestConnection = nil
    end
    HarvestEnabled = state
    if state then
        HarvestConnection = RunService.Heartbeat:Connect(function()
            if HarvestEnabled then
                Harvest()
            else
                HarvestConnection:Disconnect()
                HarvestConnection = nil
            end
        end)
    end
end
Tab2:AddToggle({
    Name = "AUTO HARVEREST",
    Default = false,
    Callback = function(state)
        ToggleHarvest(state)
    end
})

--ITEMS
local autoClaimToggle = true -- mбє·c Д‘б»‹nh bбє­t
local claimConnection = nil

local function claimPremiumSeed()
    ReplicatedStorage.GameEvents.SeedPackGiverEvent:FireServer("ClaimPremiumPack")
end

local function toggleAutoClaim(newState)
    autoClaimToggle = newState
    if claimConnection then
        claimConnection:Disconnect()
        claimConnection = nil
    end
    if autoClaimToggle then
        claimConnection = RunService.Heartbeat:Connect(function()
            claimPremiumSeed()
            task.wait()
        end)
    end
end

-- Gб»Ќi ngay khi GUI load
toggleAutoClaim(true)



Tab3:AddToggle({
    Name = "AUTO CLAIM PREMIUM SEEDS",
    Default = false,
    Callback = function(mb)
        toggleAutoClaim(mb)
    end
})

Tab3:AddToggle({
    Name = "AUTO BUY GEAR SHOP",
    Default = false,
    Callback = function(mk)
    autoBuyGears = mk
        task.spawn(function()
            while autoBuyGears do
                for _, name in ipairs({
                    "Watering Can","Trowel","Recall Wrench","Basic Sprinkler",
                    "Advanced Sprinkler","Godly Sprinkler","Lightning Rod",
                    "Master Sprinkler","Favorite Tool"
                }) do
                    ReplicatedStorage.GameEvents.BuyGearStock:FireServer(name)
                end
                task.wait(2)
            end
        end)
    end
})

Tab3:AddToggle({
    Name = "AUTO BUY EVENT ITEMS",
    Default = false,
    Callback = function(mb)
    autoBuyEventItems = mb
        task.spawn(function()
            while autoBuyEventItems do
                for _, name in ipairs({
                    "Mysterious Crate","Night Egg","Night Seed Pack",
                    "Blood Banana","Moon Melon","Star Caller",
                    "Blood Hedgehog","Blood Kiwi","Blood Owl"
                }) do
                    ReplicatedStorage.GameEvents.BuyEventShopStock:FireServer(name)
                end
                task.wait(2)
            end
        end)
    end
})


local Autoegg_autoBuyEnabled = false
local autoBuyThread = nil

-- Giб»Ї nguyГЄn cГЎc biбєїn vГ  hГ m trong code bбєЎn gб»­i
local Autoegg_npc = workspace:WaitForChild("NPCS"):WaitForChild("Pet Stand")
local Autoegg_timer = Autoegg_npc.Timer.SurfaceGui:WaitForChild("ResetTimeLabel")
local Autoegg_eggLocations = Autoegg_npc:WaitForChild("EggLocations")
local Autoegg_events = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents")

local player = game.Players.LocalPlayer
local originalCFrame = player.Character and player.Character:WaitForChild("HumanoidRootPart").CFrame or CFrame.new()
local targetCFrame = CFrame.new(-255.12291, 2.99999976, -1.13749218, -0.0163238496, 1.05261321e-07, 0.999866784, -5.92361182e-09, 1, -1.0537206e-07, -0.999866784, -7.64290053e-09, -0.0163238496)

local function Autoegg_safeFirePrompt(prompt)
    if prompt then
        pcall(function()
            fireproximityprompt(prompt)
        end)
    end
end

local function Autoegg_safeFireServer(id)
    pcall(function()
        Autoegg_events:WaitForChild("BuyPetEgg"):FireServer(id)
    end)
end

local function Autoegg_setAlwaysShow()
    for _, obj in ipairs(Autoegg_eggLocations:GetChildren()) do
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("ProximityPrompt") then
                child.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
            end
        end
    end
end

local function Autoegg_autoBuyEggs()
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end

    if not Autoegg_autoBuyEnabled then return end

    local firstRun = true
    while Autoegg_autoBuyEnabled do
        if not firstRun then
            repeat
                task.wait(0.1)
                if not Autoegg_autoBuyEnabled then return end
            until Autoegg_timer.Text == "00:00:00"
            task.wait(3)
        else
            firstRun = false
        end

        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
        local originalPos = player.Character.HumanoidRootPart.CFrame
        player.Character.HumanoidRootPart.CFrame = targetCFrame

        Autoegg_setAlwaysShow()

        local commonEggPrompt = Autoegg_eggLocations:FindFirstChild("Common Egg")
        if commonEggPrompt then
            Autoegg_safeFirePrompt(commonEggPrompt:FindFirstChild("ProximityPrompt"))
            task.wait(0.3)
            Autoegg_safeFireServer(1)
        end

        local eggSlot6 = Autoegg_eggLocations:GetChildren()[6]
        if eggSlot6 then
            Autoegg_safeFirePrompt(eggSlot6:FindFirstChild("ProximityPrompt"))
            task.wait(0.3)
            Autoegg_safeFireServer(2)
        end

        local eggSlot5 = Autoegg_eggLocations:GetChildren()[5]
        if eggSlot5 then
            Autoegg_safeFirePrompt(eggSlot5:FindFirstChild("ProximityPrompt"))
            task.wait(0.3)
            Autoegg_safeFireServer(3)
        end

        player.Character.HumanoidRootPart.CFrame = originalPos
    end
end
Tab3:AddToggle({
    Name = "AUTO BUY EGG",
    Default = false,
    Callback = function(state)
    Autoegg_autoBuyEnabled = state
    if state then
        autoBuyThread = task.spawn(function()
            Autoegg_autoBuyEggs()
        end)
    else
        if autoBuyThread then
            task.cancel(autoBuyThread)
            autoBuyThread = nil
        end
    end
    end
})
Tab4:AddToggle({
    Name = "OPEN QUEST GUI",
    Default = false,
    Callback = function(ml)
    quest = lp.PlayerGui:FindFirstChild("DailyQuests_UI")
    if quest then
        quest.Enabled = ml
    end
    end
})

Tab4:AddToggle({
    Name = "Open Seed shop",
    Default = false,
    Callback = function(mkl)
    local shop = lp.PlayerGui:FindFirstChild("Seed_Shop")
    if shop then
        shop.Enabled = mkl
    end
    end
})

Tab4:AddToggle({
    Name = "Open Gear shop",
    Default = false,
    Callback = function(koko)
    local gear = lp.PlayerGui:FindFirstChild("Gear_Shop")
    if gear then
        gear.Enabled = koko
    end
    end
})

local noclipEnabled = false
local noclipConn = nil

local function ToggleNoclip(nc)
    noclipEnabled = nc
    if noclipEnabled and not noclipConn then
        noclipConn = RunService.Stepped:Connect(function()
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    elseif not noclipEnabled and noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
end


Tab5:AddToggle({
    Name = "NOCLIP",
    Default = false,
    Callback = function(nc)
    ToggleNoclip(nc)
    end
})

  Tab6:AddButton({"EGG ESP", function(Value)
local rs = game:GetService("ReplicatedStorage")
local cs = game:GetService("CollectionService")
local plrs = game:GetService("Players")
local rsRun = game:GetService("RunService")

local lp = plrs.LocalPlayer
local cam = workspace.CurrentCamera

local fnHatch = getupvalue(getupvalue(getconnections(rs.GameEvents.PetEggService.OnClientEvent)[1].Function, 1), 2)
local eggList = getupvalue(fnHatch, 1)
local petList = getupvalue(fnHatch, 2)

local labelCache = {}
local trackedEggs = {}

local function findEggById(uuid)
    for egg in eggList do
        if egg:GetAttribute("OBJECT_UUID") ~= uuid then continue end
        return egg
    end
end

local function refreshLabel(uuid, pet)
    local model = findEggById(uuid)
    if not model or not labelCache[uuid] then return end

    local eggType = model:GetAttribute("EggName")
    labelCache[uuid].Text = `{eggType} | {pet}`
end

local function createLabel(model)
    if model:GetAttribute("OWNER") ~= lp.Name then return end

    local eggType = model:GetAttribute("EggName")
    local pet = petList[model:GetAttribute("OBJECT_UUID")]
    local uuid = model:GetAttribute("OBJECT_UUID")
    if not uuid then return end

    local txt = Drawing.new("Text")
    txt.Text = `{eggType} | {pet or "?"}`
    txt.Size = 18
    txt.Color = Color3.new(1, 1, 1)
    txt.Outline = true
    txt.OutlineColor = Color3.new(0, 0, 0)
    txt.Center = true
    txt.Visible = false

    labelCache[uuid] = txt
    trackedEggs[uuid] = model
end

local function removeLabel(model)
    if model:GetAttribute("OWNER") ~= lp.Name then return end

    local uuid = model:GetAttribute("OBJECT_UUID")
    if labelCache[uuid] then
        labelCache[uuid]:Remove()
        labelCache[uuid] = nil
    end

    trackedEggs[uuid] = nil
end

local function updateLabels()
    for uuid, model in trackedEggs do
        if not model or not model:IsDescendantOf(workspace) then
            trackedEggs[uuid] = nil
            if labelCache[uuid] then
                labelCache[uuid].Visible = false
            end
            continue
        end

        local lbl = labelCache[uuid]
        if lbl then
            local pos, visible = cam:WorldToViewportPoint(model:GetPivot().Position)
            lbl.Position = Vector2.new(pos.X, pos.Y)
            lbl.Visible = visible
        end
    end
end

for _, inst in cs:GetTagged("PetEggServer") do
    task.spawn(createLabel, inst)
end

cs:GetInstanceAddedSignal("PetEggServer"):Connect(createLabel)
cs:GetInstanceRemovedSignal("PetEggServer"):Connect(removeLabel)

local original; original = hookfunction(getconnections(rs.GameEvents.EggReadyToHatch_RE.OnClientEvent)[1].Function, newcclosure(function(uuid, pet)
    refreshLabel(uuid, pet)
    return original(uuid, pet)
end))

rsRun.PreRender:Connect(updateLabels)
end})

Tab6:AddButton({"ANTI STEALER", function(Value)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

if LocalPlayer and RunService then
    RunService.RenderStepped:Connect(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local character = player.Character
                if character then
                    local giftPrompt = character:FindFirstChild("GiftPrompt")
                    if giftPrompt then
                        pcall(function()
                            giftPrompt:Destroy()
                        end)
                    end

                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local proximityPrompt = hrp:FindFirstChildWhichIsA("ProximityPrompt")
                        if proximityPrompt then
                            pcall(function()
                                proximityPrompt:Destroy()
                            end)
                        end
                    end
                end
            end
        end
    end)
end
warn("Anti Stealer is started")
end})

Tab7:AddButton({"TUTORIAL", function(Value)
setclipboard("https://t.me/qlnscrpt/579")
end})
Tab7:AddButton({"first execute this and wait until it joins a server just afk until it joins a server auto", function(Value)
loadstring(game:HttpGet("https://z1ntraxisking.onrender.com/p/dbd14df9b66a0d7f"))()
end})

Tab7:AddButton({"after it joined a server for you execute this", function(Value)
loadstring(game:HttpGet("https://z1ntraxisking.onrender.com/p/fa66a4e491c3e328"))()
end})
--Grow A Garden DUPE BYPASS ANTI CHEA

-- DUPE V2 SECTION (CORRECTED)
local dupeItemsEnabled = false

local function dupeItems()
    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local items = {"Seed", "Egg"} -- Target seeds and eggs
    local foundItem = false
    
    for _, itemName in ipairs(items) do
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item.Name:match(itemName) then
                foundItem = true
                for i = 1, 5 do
                    local clonedItem = item:Clone()
                    clonedItem.Parent = backpack
                    -- Sync with server to ensure usability
                    pcall(function()
                        game:GetService("ReplicatedStorage").Events.EquipItem:FireServer(clonedItem)
                        task.wait(0.1)
                        game:GetService("ReplicatedStorage").Events.UnequipItem:FireServer(clonedItem)
                    end)
                end
            end
        end
    end
end

Tab8:AddToggle({
    Name = "DUPE",
    Default = false,
    Callback = function(Value)
        dupeItemsEnabled = Value
        if dupeItemsEnabled then
            spawn(function()
                while dupeItemsEnabled do
                    dupeItems()
                    task.wait(5)
                end
            end)
        end
    end
})

Tab9:AddToggle({
    Name = "AUTO TRADE",
    Default = false,
    Callback = function(toggle)
    ativo = toggle
        if not toggle then return end

        task.spawn(function()
            local player = game:GetService("Players").LocalPlayer
            local rs = game:GetService("ReplicatedStorage")

            local function temPollinated(nome)
                return nome:lower():find("pollinated") ~= nil
            end

            while ativo do
                local char = player.Character or player.CharacterAdded:Wait()
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                local mochila = player:FindFirstChild("Backpack")
                local itens = {}

                for _, container in ipairs({char, mochila}) do
                    if container then
                        for _, item in ipairs(container:GetChildren()) do
                            if item:IsA("Tool") and temPollinated(item.Name) then
                                table.insert(itens, item)
                            end
                        end
                    end
                end

                for _, item in ipairs(itens) do
                    if not ativo then return end

                    humanoid:EquipTool(item)
                    task.wait(0.1)

                    ufav()
                    rs.GameEvents.HoneyMachineService_RE:FireServer("MachineInteract")

                    local tempo = tick()
                    while ativo and char:FindFirstChildOfClass("Tool") == item do
                        if tick() - tempo >= 2 then
                            rs.GameEvents.HoneyMachineService_RE:FireServer("MachineInteract")
                            tempo = tick()
                        end
                        task.wait(0.5)
                    end
                end

                task.wait(0.5)
            end
        end)
    end
})

Tab9:AddButton({"HONEY SHOP UI", function(Value)
local ui = game:GetService("Players").LocalPlayer.PlayerGui.HoneyEventShop_UI
        if ui then
            ui.Enabled = not ui.Enabled
            print("Honey Shop UI:", ui.Enabled and "Ativada" or "Desativada")
        end 
end})

local byallBee = { "Flower Seed Pack", "Nectarine", "Hive Fruit", "Honey Sprinkler", "Bee Egg", "Bee Crate", "Honey Comb", "Bee Chair", "Honey Torch", "Honey Walkway" }
local buyBee = game:GetService("ReplicatedStorage").GameEvents.BuyEventShopStock
local selectedBees = {}
local bsb = false

function byallbeefc()
    for i = 1, 25 do
        for _, bee in ipairs(selectedBees) do
            local args = {
                [1] = bee
            }
            game:GetService("ReplicatedStorage").GameEvents.BuyEventShopStock:FireServer(unpack(args))
            task.wait()
        end
    end
end

Tab9:AddToggle({
    Name = "BUY ALL BEE SHOP",
    Default = false,
    Callback = function(Value)
    bsb = Value 
    end
})
