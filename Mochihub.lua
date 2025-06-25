------------------ SETTINGS ------------------
 
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")
local workspace = game:GetService("Workspace")
local backpack = player:WaitForChild("Backpack")
local playerGui = player:WaitForChild("PlayerGui")
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")

local scriptEnabled = true

local Window
local IsBuyHoneyShop, IsPlaceEggs, IsOpenEggs, IsCollectHoney, IsAntiAfk, IsCraftItems
local CollectHoneyPeriod, CraftItemsPeriod, BuyPetStockPeriod, BuyGearShopPeriod, BuySeedShopPeriod, HoneyShopPeriod, PlaceEggsPeriod, OpenEggsPeriod, AntiAfkPeriod
local SelectedHoneyShopItems = {}
local SelectedGearShopItems = {}
local SelectedSeedShopItems = {}
local SelectedPetStockEggs = {}
local SellPetsConsole

local collectHoneyTime
 
------------------ MAIN -----------------
player.CharacterAdded:Connect(function(char)
	character = char
end)
------------------ HONEY EVENT ------------------

function HandleHoneyCrafter()
    local honeyCrafter = workspace.Interaction.UpdateItems.HoneyCrafter

    local honeyStation = honeyCrafter.HoneyCrafter_HoneyStation
    local honeyStationPrompt = honeyStation.Barrel:FindFirstChild("HoneyCrafterPrompt_Honey", true)
    if honeyStationPrompt and honeyStationPrompt.ActionText == "Submit Honey" then
        print("Sumbit honey craft")
        GameEvents.HoneyCrafterRemoteEvent:FireServer("SubmitHoney")
    end

    local plantStation = honeyCrafter.HoneyCrafter_PlantStation
    local plantStationPrompt = plantStation.Barrel:FindFirstChild("HoneyCrafterPrompt_Plant", true)
    if plantStationPrompt and plantStationPrompt.ActionText == "Submit Plant" then
        local requiredPlant

        for _, child in ipairs(plantStation:GetChildren()) do
            local primaryPart = child.PrimaryPart
            if not primaryPart then continue end

            local partName = child.PrimaryPart.Name
            if not partName or partName ~= "Handle" then continue end

            requiredPlant = child.Name
        end

        SumbitPlantForCraft(requiredPlant)
    end

    -- GameEvents.HoneyCrafterRemoteEvent:FireServer("SubmitHeldPlant")
    --GameEvents.HoneyCrafterRemoteEvent("CraftItem")
end

function GetPollinatedPlantWithType(plantType)
    local plant

    for _, item in ipairs(backpack:GetChildren()) do
        local itemName = item:GetAttribute("ItemName")
        if not itemName or itemName ~= plantType then continue end
        if not string.find(item.Name, "Pollinated") then continue end
        plant = item
    end

    return plant
end

function HasPlantWithType(plantType)
    local has = false

    local farm = GetFarm()
    local plantsPhysical = farm.Important.Plants_Physical

    for _, child in ipairs(plantsPhysical:GetChildren()) do
        if child.Name ~= plantType then continue end
        has = true
    end

    return has
end

function SumbitPlantForCraft(plant)
    local requiredPlant = GetPollinatedPlantWithType(plant)

    if requiredPlant then
        GameEvents.HoneyCrafterRemoteEvent:FireServer("SubmitHeldPlant")
        print("required plant has in inventory, submit for craft")
        return
    end

    local hasPlant = HasPlantWithType(plant)

    if hasPlant then
        print("has plant on farm ")
    end

    local seedShopItems = GetSeedShopItems()
    local stock = seedShopItems[plant]

    if stock == 0 then
        print("stock of required plant for craft is empty")
        return
    end

    GameEvents.BuySeedStock:FireServer(plant)
end
 
function HandleCombpressor()
	local combpressor = workspace.HoneyEvent.HoneyCombpressor
 
	local jarPrompt = combpressor.Spout.Jar:FindFirstChild("HoneyCombpressorPrompt")
	if jarPrompt and jarPrompt.ActionText == "Collect Honey" then
		print("Collect Honey")
		collectHoneyTime = tick()
		ReplicatedStorage.GameEvents.HoneyMachineService_RE:FireServer("MachineInteract")
	end
 
	local onettPrompt = combpressor.Onett:FindFirstChild("HoneyCombpressorPrompt")
	if onettPrompt and onettPrompt.ActionText == "Give Plant" then
		local pollinatedFruit = FindPollinatedFruitInBackpack()

		if pollinatedFruit then
			print("Give Plant")
			GivePlant(onettPrompt, pollinatedFruit)
		else
			local pollinatedFruits = GetPollinatedFruits()
			local pollinatedFruitsSize = TableSize(pollinatedFruits)

			if pollinatedFruitsSize < 1 then
				print("Pollinated fruits on farm none exists")
			end

			if pollinatedFruitsSize > 0 then
				print("Go to collect pollinated")
				CollectPollinated(pollinatedFruits)
			end
		end
	end
end

function FindPollinatedFruitInBackpack()
	for _, item in ipairs(backpack:GetChildren()) do
		if not string.find(item.Name, "Pollinated") then continue end
        return item
	end

	return nil
end
 
function GivePlant(prompt, item)
	ResetMainSlot()
	item.Parent = character
	ReplicatedStorage.GameEvents.HoneyMachineService_RE:FireServer("MachineInteract")
end

function GetHoneyShopItems()
	local honeyShop = PlayerGui.HoneyEventShop_UI
	local frames = honeyShop.Frame.ScrollingFrame

	local items = {}

	for _, item in ipairs(frames:GetChildren()) do
		local mainFrame = item:FindFirstChild("Main_Frame")
		if not mainFrame then continue end
        local stockText = mainFrame.Stock_Text 

        items[item.Name] = tonumber(stockText.Text:match("%d+"))
	end

	return items
end
 
function BuyHoneyShop()
    local honeyShopItems = GetHoneyShopItems()

	for good, _ in pairs(SelectedHoneyShopItems) do
        local stock = honeyShopItems[good]

        for i = 1, stock do
		    GameEvents.BuyEventShopStock:FireServer(good)
        end

        if stock == 0 then continue end

		print(string.format("Buy in shop %s x%d", good, stock))
	end
end

------------------ SEED ----------------
function BuySeedShop()
    local seedShopItems = GetSeedShopItems()

    for good, _ in pairs(SelectedSeedShopItems) do
        local stock = seedShopItems[good]

        for i = 1, stock do
		    GameEvents.BuySeedStock:FireServer(good)
        end

        if stock == 0 then continue end

		print(string.format("Buy in shop %s x%d", good, stock))
	end
end

 
------------------ FARM ------------------
 
function GetFarm()
	local farms = workspace:FindFirstChild("Farm")
	if not farms then return nil end
 
	for _, farm in ipairs(farms:GetChildren()) do
		local important = farm:FindFirstChild("Important")
		local owner = important and important.Data and important.Data:FindFirstChild("Owner")
        if not owner or owner.Value ~= player.name then continue end

        return farm
	end
end
 
function GetPollinatedFruits()
	local fruits = {}

	local farm = GetFarm()
	if not farm then return fruits end
 
	local plants = farm.Important.Plants_Physical

	for _, plant in ipairs(plants:GetChildren()) do
		local fruitGroup = plant:FindFirstChild("Fruits")
        if not fruitGroup then continue end

        for _, fruit in ipairs(fruitGroup:GetChildren()) do
            if not fruit:GetAttribute("Pollinated") then continue end

            local prompt = fruit:FindFirstChild("ProximityPrompt", true)
            if not prompt or not prompt.Enabled or not fruit.PrimaryPart then continue end

            fruits[fruit] = prompt
		end
	end

	return fruits
end
 
function CollectPollinated(fruits)
    for fruit, prompt in pairs(fruits) do
		local ByteNetReliable = ReplicatedStorage.ByteNetReliable

		ByteNetReliable:FireServer(
			buffer.fromstring("\001\001\000\001"),
			{ fruit }
		)
    end
end

function GetSeedShopItems()
	local gearShop = PlayerGui.Seed_Shop
	local frames = gearShop.Frame.ScrollingFrame

	local items = {}

	for _, item in ipairs(frames:GetChildren()) do
		local mainFrame = item:FindFirstChild("Main_Frame")
		if not mainFrame then continue end
        local stockText = mainFrame.Stock_Text 

        items[item.Name] = tonumber(stockText.Text:match("%d+"))
	end

	return items
end
 
------------------ PETS ------------------

function OpenEggs()
	local farm = GetFarm()
	if not farm then return end

	local objects = farm.Important.Objects_Physical
 
	for _, obj in ipairs(objects:GetChildren()) do
        if obj:GetAttribute("OBJECT_TYPE") ~= "PetEgg" or obj:GetAttribute("TimeToHatch") ~= 0 then continue end

        print("Open egg " .. obj.Name)
        OpenEgg(obj)
	end
end

function PlaceEggs()
	ResetMainSlot()

	local farm = GetFarm()
	if not farm then return end

	local placedEggs = {}
	local objects = farm.Important.Objects_Physical
 
	for _, obj in ipairs(objects:GetChildren()) do
        if obj:GetAttribute("OBJECT_TYPE") ~= "PetEgg" then continue end
        table.insert(placedEggs, obj)
	end

	if #placedEggs > 3 then
		print("Eggs on farm is max")
	end

	if #placedEggs < 4 then
		local eggsToPlace = 4 - #placedEggs
		local eggs = GetEggs()

		for _, egg in ipairs(eggs) do
			if eggsToPlace < 1 then break end
			local count = egg:GetAttribute("Uses")

			for i = 1, math.min(count, eggsToPlace) do
				print("Placing egg " .. egg.Name)
				PlaceEgg(egg)
				eggsToPlace -= 1
			end
		end
	end
end
 
function PlaceEgg(egg)
	local farm = GetFarm()
	if not farm then return end
 
	local box = farm.Important.Plant_Locations:FindFirstChild("Can_Plant")
	if not box then return end

	local angle = math.rad(math.random(0, 360))
	local radius = math.random(1, 50)
	local pos = box.Position + Vector3.new(math.cos(angle)*radius, 0, math.sin(angle)*radius)
 
	ResetMainSlot()
	egg.Parent = character
 
    GameEvents.PetEggService:FireServer("CreateEgg", pos)
end
 
function OpenEgg(egg)
	SellPets()
	GameEvents.PetEggService:FireServer("HatchPet", egg)
end
 
function SellPets()
	for _, item in ipairs(backpack:GetChildren()) do
		for name in string.gmatch(SellPetsConsole.Value, "[^\r\n]+") do
            if not string.find(item.Name, name) then continue end

            item.Parent = character
            GameEvents.SellPet_RE:FireServer(item)
            print("Sell pet " .. item.Name)
		end
	end
end

function GetPetsCount(petName)
	local count = 0

	for _, item in ipairs(backpack:GetChildren()) do
        if not string.find(item.Name, petName) then continue end
		count += 1
	end

	return count
end

function GetEggs()
	local eggs = {}

	for _, item in ipairs(backpack:GetChildren()) do
		if not string.find(item.Name, "Egg") then continue end
		table.insert(eggs, item)
	end

	return eggs
end

function GetPlacedEggs()
	local placedEggs = {}

	local farm = GetFarm()
	if not farm then return end

	local objects = farm.Important.Objects_Physical
 
	for _, obj in ipairs(objects:GetChildren()) do
		if obj:GetAttribute("OBJECT_TYPE") ~= "PetEgg" then continue end
		local timeToHatch = obj:GetAttribute("TimeToHatch") 
		placedEggs[obj] = timeToHatch
	end

	return placedEggs
end

function GetPetStockEggs()
	local items = ReplicatedStorage.Assets.Models.EggModels

	local names = {}

	for _, item in ipairs(items:GetChildren()) do
		table.insert(names, item.Name)
	end

	return names
end

function BuyPetStock()
	local children = workspace.NPCS:WaitForChild("Pet Stand").EggLocations:GetChildren()

	for i = #children, 1, -1 do
        if children[i]:IsA("Model") then continue end
	    table.remove(children, i)
	end

	for index, egg in ipairs(children) do
		if not SelectedPetStockEggs[egg.Name] then continue end
        GameEvents.BuyPetEgg:FireServer(index)
	end
end

------------------ GEAR --------------------
function GetGearShopItems()
	local gearShop = PlayerGui.Gear_Shop
	local frames = gearShop.Frame.ScrollingFrame

	local items = {}

	for _, item in ipairs(frames:GetChildren()) do
		local mainFrame = item:FindFirstChild("Main_Frame")
		if not mainFrame then continue end
        local stockText = mainFrame.Stock_Text 

        items[item.Name] = tonumber(stockText.Text:match("%d+"))
	end

	return items
end

function BuyGearShop()
    local gearShopItems = GetGearShopItems()

    for good, _ in pairs(SelectedGearShopItems) do
        local stock = gearShopItems[good]

        for i = 1, stock do
		    GameEvents.BuyGearStock:FireServer(good)
        end

        if stock == 0 then continue end

		print(string.format("Buy in shop %s x%d", good, stock))
	end
end
 
------------------ UTILS ------------------
function AntiAfk()
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
	wait(0.1)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end
 
function ResetMainSlot()
	for _, item in ipairs(character:GetChildren()) do
        if not item:IsA("Tool") then continue end
        item.Parent = backpack
	end
end

function Loop(Toggle: Checkbox?, Func, period)
	coroutine.wrap(function()
		local lastRun = tick()

		while scriptEnabled do
			if Toggle ~= nil and Toggle.Value == false then
				task.wait(0.1)
				continue
			end

			local currentPeriod

			if typeof(period) == "table" then
				currentPeriod = period.Value
			elseif typeof(period) == "number" then
				currentPeriod = period
			else
				currentPeriod = 1
			end

			if tick() - lastRun >= currentPeriod then
				local success, err = pcall(Func)
				if not success then
					print(tostring(err))
				end
				lastRun = tick()
			end

			task.wait(0.1)
		end
	end)()
end

function FormatTime(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)

	local parts = {}

	if h > 0 then
		table.insert(parts, h .. "h")
	end
	if m > 0 then
		table.insert(parts, m .. "m")
	end
	if s > 0 or #parts == 0 then
		table.insert(parts, s .. "s")
	end

	return table.concat(parts, " ")
end

function TableSize(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count += 1
	end
	return count
end

-------------------------GUI-----------------------
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId

local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
}

ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})
ReGui:DefineTheme("GardenTheme", {
	WindowBg = Accent.Brown,
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.DarkGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
	CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.Green,
    SliderGrab = Accent.Green,
})

function Exit()
	scriptEnabled = false
	Window:Remove()
end

function FeaturesWindow()
	Window = ReGui:TabsWindow({
		Title = "Features",
		Theme = "GardenTheme",
		Size = UDim2.fromOffset(300, 400),
		NoResize = true,
		NoClose = true,
	})

	local PetTab = Window:CreateTab({Name="Pet"})

	PetTab:Separator({Text="Place"})

	IsPlaceEggs = PetTab:Checkbox({
		Value = false,
		Label = "Place Eggs"
	})
	PlaceEggsPeriod = PetTab:InputInt({
		Label = "Period",
		Value = 60,
		Minimum = 1,
		Maximum = 1000000
	})

	PetTab:Separator({Text="Open"})

	IsOpenEggs = PetTab:Checkbox({
		Value = false,
		Label = "Open Eggs"
	})
	OpenEggsPeriod = PetTab:InputInt({
		Label = "Period",
		Value = 60,
		Minimum = 1,
		Maximum = 1000000
	})

	PetTab:Separator({Text="Auto Sell"})

	SellPetsConsole = PetTab:Console({
		LineNumbers = true,
		Value = "Hedgehog\nFrog\nMole\nMouse\nSquirrel\nAnt"
	})

	PetTab:Button({
		Text = "Sell Pets",
		Callback = SellPets,
	})

	PetTab:Separator({Text="Egg Stock"})

	for _, item in ipairs(GetPetStockEggs()) do
		PetTab:Checkbox({
			Value = false,
			Label = item,
			Callback = function(self, Value: boolean)
				if (Value) then
					SelectedPetStockEggs[item] = true
				else
					SelectedPetStockEggs[item] = nil
				end
			end
		})
	end

	BuyPetStockPeriod = PetTab:InputInt({
		Label = "Period",
		Value = 300,
		Minimum = 1,
		Maximum = 1000000
	})

    local GearTab = Window:CreateTab({Name="Gear"})

    BuyGearShopPeriod = GearTab:InputInt({
		Label = "Period",
		Value = 1,
		Minimum = 1,
		Maximum = 1000000
	})

    for item, _ in pairs(GetGearShopItems()) do
		GearTab:Checkbox({
			Value = false,
			Label = item,
			Callback = function(self, Value: boolean)
				if (Value) then
					SelectedGearShopItems[item] = true
				else
					SelectedGearShopItems[item] = nil
				end
			end
		})
	end

    
    local SeedTab = Window:CreateTab({Name="Seed"})

    BuySeedShopPeriod = SeedTab:InputInt({
		Label = "Period",
		Value = 1,
		Minimum = 1,
		Maximum = 1000000
	})

    for item, _ in pairs(GetSeedShopItems()) do
		SeedTab:Checkbox({
			Value = false,
			Label = item,
			Callback = function(self, Value: boolean)
				if (Value) then
					SelectedSeedShopItems[item] = true
				else
					SelectedSeedShopItems[item] = nil
				end
			end
		})
	end

	local HoneyEventTab = Window:CreateTab({Name="Honey Event"})

	HoneyEventTab:Separator({Text="Combpressor"})

	IsCollectHoney = HoneyEventTab:Checkbox({
		Value = false,
		Label = "Collect Honey"
	})

	CollectHoneyPeriod = HoneyEventTab:InputInt({
		Label = "Period",
		Value = 1,
		Minimum = 1,
		Maximum = 1000000
	})

    HoneyEventTab:Separator({Text="Crafter"})

    
	IsCraftItems = HoneyEventTab:Checkbox({
		Value = false,
		Label = "Craft Items"
	})

	CraftItemsPeriod = HoneyEventTab:InputInt({
		Label = "Period",
		Value = 1,
		Minimum = 1,
		Maximum = 1000000
	})

	HoneyEventTab:Separator({Text="Honey Shop"})

	for item, _ in pairs(GetHoneyShopItems()) do
		HoneyEventTab:Checkbox({
			Value = false,
			Label = item,
			Callback = function(self, Value: boolean)
				if (Value) then
					SelectedHoneyShopItems[item] = true
				else
					SelectedHoneyShopItems[item] = nil
				end
			end
		})
	end

	HoneyShopPeriod = HoneyEventTab:InputInt({
		Label = "Period",
		Value = 60,
		Minimum = 1,
		Maximum = 1000000
	})

	local OtherTab = Window:CreateTab({Name="Other"})
	IsAntiAfk = OtherTab:Checkbox({
		Value = false,
		Label = "Anti-AFK",
	})

	AntiAfkPeriod = OtherTab:InputInt({
		Label = "Period",
		Value = 60,
		Minimum = 1,
		Maximum = 1000000
	})

	OtherTab:Button({
		Text = "Show Statistic",
		Callback = ShowStatistic
	})

    OtherTab:Separator({Text="Fps"})
    
	local fpsInput = OtherTab:InputInt({
		Label = "Fps",
		Value = 60,
		Minimum = 1,
		Maximum = 144
	})

    OtherTab:Button({
		Text = "Set",
		Callback = function()
            setfpscap(fpsInput.Value)
        end
	})

	OtherTab:Button({
		Text = "Exit",
		Callback = Exit
	})
end

function ShowStatistic()
	local ModalWindow = Window:PopupModal({
		Title = "Statistic",
	})

	ModalWindow:Separator({Text = "Favorited Pets"})

	local featurePets = { "Raccoon", "Queen Bee" }

	for _, featurePet in ipairs(featurePets) do
		local count = GetPetsCount(featurePet)
		ModalWindow:Label({
			Text = string.format("%s x%d", featurePet, count)
		})
	end

	ModalWindow:Separator({Text = "Eggs in Backpack"})
	
	for _, egg in ipairs(GetEggs()) do
		ModalWindow:Label({
			Text = egg.Name
		})
	end

	ModalWindow:Separator({Text = "Placed eggs"})
	
	for egg, timeToHatch in pairs(GetPlacedEggs()) do
		local name = egg:GetAttribute("EggName")
		local readableTime = FormatTime(timeToHatch)
		ModalWindow:Label({
			Text = string.format("%s %s", name, readableTime)
		})
	end

	ModalWindow:Separator({Text = "Event"})

	local lastCollectHoney

	if collectHoneyTime then
		lastCollectHoney = FormatTime(tick() - collectHoneyTime)
	else
		lastCollectHoney = "Never"
	end

	ModalWindow:Label({
		Text = string.format("Last Collect Honey: %s ago", lastCollectHoney)
	})

	local pollinatedFruits = GetPollinatedFruits()

	ModalWindow:Label({
		Text = string.format("Pollinated Fruits: %d", TableSize(pollinatedFruits))
	})

	ModalWindow:Button({
		Text = "Close",
		Callback = function()
			ModalWindow:ClosePopup()
		end
	})
end

FeaturesWindow()

-------------LOOP-------------
Loop(IsAntiAfk, AntiAfk, AntiAfkPeriod)
Loop(nil, BuyHoneyShop, HoneyShopPeriod)
Loop(nil, BuyGearShop, BuyGearShopPeriod)
Loop(nil, BuySeedShop, BuySeedShopPeriod)
Loop(nil, BuyPetStock, BuyPetStockPeriod)
Loop(isOpenEggs, OpenEggs, OpenEggsPeriod)
Loop(IsPlaceEggs, PlaceEggs, PlaceEggsPeriod)
Loop(IsCollectHoney, HandleCombpressor, CollectHoneyPeriod)
Loop(IsCraftItems, HandleHoneyCrafter, CraftItemsPeriod)
