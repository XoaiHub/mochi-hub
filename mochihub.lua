--!strict
local getgenv: () -> ({[string]: any}) = getfenv().getgenv

getgenv().ScriptVersion = "v0.3.0a"

getgenv().Changelog = [[
v0.3.0a
- Added plant type specific position reuse
v0.2.0a
- Added reuse of plant vectors for replanting
]]

do
  local Core = loadstring(game:HttpGet("https://github.com/aw4e/Cheese/raw/dev/Core.lua"))
  if not Core then return warn("Failed to load the Cheese Core") end
  Core()
end

-- Types

type Element = {
	CurrentValue: any,
	CurrentOption: {string},
	Set: (self: Element, any) -> ()
}

type Flags = {[string]: Element}

type Tab = {
	CreateSection: (self: Tab, Name: string) -> Element,
	CreateDivider: (self: Tab) -> Element,
	CreateToggle: (self: Tab, any) -> Element,
	CreateSlider: (self: Tab, any) -> Element,
	CreateDropdown: (self: Tab, any) -> Element,
	CreateButton: (self: Tab, any) -> Element,
	CreateLabel: (self: Tab, any, any?) -> Element,
	CreateParagraph: (self: Tab, any) -> Element,
}

-- Variable

local Notify: (Title: string, Content: string, Image: string?) -> () = getgenv().Notify
local CreateFeature: (Tab: Tab, FeatureName: string) -> () = getgenv().CreateFeature

local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Backpack = Player.Backpack
local PlayerGui = Player:WaitForChild("PlayerGui")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")

local Farms = workspace:WaitForChild("Farm")

-- local Eggs = {}
-- local EggShop = require(ReplicatedStorage.Data.PetEggData)
-- local EggLocations = workspace.NPCS["Pet Stand"].EggLocations

-- for _, Egg in next, EggShop do
-- 	if Egg.StockChance > 0 then
-- 		table.insert(Eggs, Egg.EggName)
-- 	end
-- end


-- Functions

local function GetFarm()
	for _, F in ipairs(Farms:GetChildren()) do
		local Owner = F.Important.Data.Owner.Value
		if Owner == Player.Name then return F end
	end
end

local Farm = GetFarm()
local PlantLocations = Farm.Important.Plant_Locations
local PlantsPhysical = Farm.Important.Plants_Physical

local function GetPlantPositionByType(PlantType)
	for _, Plant in ipairs(PlantsPhysical:GetChildren()) do
		if Plant:IsA("Model") then
			local PlantName = Plant.Name
			if PlantName:lower():find(PlantType:lower()) then
				return Plant:GetPivot().Position
			end
		end
	end
	return nil
end

local function GetRandomPoint(Base)
	local Pivot, Size = Base:GetPivot(), Base.Size
	local Margin = 0.1
	local X = math.random() * (1 - Margin * 2) + Margin
	local Z = math.random() * (1 - Margin * 2) + Margin
	return Vector3.new(
		Pivot.X - Size.X / 2 + X * Size.X,
		4,
		Pivot.Z - Size.Z / 2 + Z * Size.Z
	)
end

local function GetOwnedSeeds()
	local Seeds = {}
	for _, Container in ipairs({Backpack, Character}) do
		for _, Tool in ipairs(Container:GetChildren()) do
			if Tool:IsA("Tool") and Tool:GetAttribute("ItemType") == "Seed" then
				local Name = Tool:GetAttribute("ItemName") or Tool:GetAttribute("Seed")
				Seeds[Name] = { Tool = Tool, Count = Tool:GetAttribute("Quantity") or 1 }
			end
		end
	end
	return Seeds
end

local function EquipTool(Tool)
	local Hum = Character:FindFirstChildOfClass("Humanoid")
	if Hum and Tool.Parent == Backpack then Hum:EquipTool(Tool) end
end

local SeedLabelMap, GearLabelMap, SeedStock, GearStock = {}, {}, {}, {}
local RarityOrder = {Common=1, Uncommon=2, Rare=3, Legendary=4, Mythical=5, Divine=6}

local function ParseShopItems(ShopName, LabelMap, StockMap, Filter)
	local Shop = PlayerGui:WaitForChild(ShopName)
	local Items = Shop:FindFirstChild("Item_Size", true).Parent
	local List = {}

	for _, Item in ipairs(Items:GetChildren()) do
		local Main = Item:FindFirstChild("Main_Frame")
		if not Main then continue end

		local Stock = tonumber(Main.Stock_Text.Text:match("%d+")) or 0
		if Filter and Stock <= 0 then continue end

		local Rarity = Main.Rarity_Text.Text
		local Label = Item.Name .. " [" .. Rarity .. "]"
		table.insert(List, {Label = Label, Rarity = Rarity})
		LabelMap[Label] = Item.Name
		StockMap[Label] = Stock
	end

	table.sort(List, function(A, B) return (RarityOrder[A.Rarity] or 99) < (RarityOrder[B.Rarity] or 99) end)
	local Display = {}; for _, V in ipairs(List) do table.insert(Display, V.Label) end
	return Display
end

local function BuyAll(LabelMap, StockMap, Selected, EventName)
	for _, Label in ipairs(Selected or {}) do
		local Item, Stock = LabelMap[Label], StockMap[Label]
		if Item and Stock and Stock > 0 then
			for _ = 1, Stock do GameEvents[EventName]:FireServer(Item) end
		end
	end
end

-- Features

local Flags: Flags = getgenv().Flags

local Window = getgenv().Window

local Tab: Tab = Window:CreateTab({
	Name = "Automation",
	Icon = "code",
	ImageSource = "Lucide",
	ShowTitle = false
})

Tab:CreateSection("Plant's")

Tab:CreateToggle({
  Name = "Use Existing Plant Positions",
  Description = "Reuse positions where plants were previously located",
  Default = true,
  Callback = function()end
}, "UseExistingPositions")

Tab:CreateToggle({
  Name = "Auto Plant Seeds",
  Callback = function()
    while Flags.AutoPlantSeeds.CurrentValue and task.wait(.1) do
      local Seeds = GetOwnedSeeds()
      if not next(Seeds) then continue end

      local FarmLand = PlantLocations:GetChildren()

      for Name, Seed in pairs(Seeds) do
        EquipTool(Seed.Tool)
        task.wait(.2)

        local Pos

        if Flags.UseExistingPositions.CurrentValue then
					Pos = GetPlantPositionByType(Name)
        end

        if not Pos then
					Pos = GetRandomPoint(FarmLand[math.random(#FarmLand)])
        end

        for i = 1, Seed.Count do
					GameEvents.Plant_RE:FireServer(Pos, Name)
					task.wait(.5)
        end
      end
    end
  end
}, "AutoPlantSeeds")

Tab:CreateButton({
	Name = "Free Trowel",
	Description = "Get a free trowel",
	Callback = function()
		local Tool = Instance.new("Tool")
		Tool.Name = "Trowel"
		Tool.RequiresHandle = true

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1,1,1)
		handle.Color = Color3.new(0.5, 0.5, 0.5)
		handle.CanCollide = false
		handle.Anchored = false
		handle.Parent = Tool

		Tool.Parent = Backpack
	end
})

local Tab: Tab = Window:CreateTab({
  Name = "Shop",
  Icon = "shopping-cart",
  ImageSource = "Lucide",
  ShowTitle = false
})

Tab:CreateSection("Seed's")

Tab:CreateDropdown({
  Name = "Select Seed",
  Description = "Select the seed you want to buy",
  Options = ParseShopItems("Seed_Shop", SeedLabelMap, SeedStock, false),
  CurrentOption = {},
  MultipleOptions = true,
  SpecialType = nil,
  Callback = function()end
}, "SelectSeed")

Tab:CreateToggle({
  Name = "Show Available Seeds",
  Callback = function()
    local Filter = Flags.ShowAvailableSeeds.CurrentValue
    local Options = ParseShopItems("Seed_Shop", SeedLabelMap, SeedStock, Filter)
    Flags.SelectSeed:Set({
      Options = Options,
      CurrentOption = {},
    })
  end
}, "ShowAvailableSeeds")

Tab:CreateToggle({
  Name = "Auto Buy Seed",
  Callback = function()
    while Flags.AutoBuySeed.CurrentValue and task.wait(.1) do
      local Selected = Flags.SelectSeed.CurrentOption
      BuyAll(SeedLabelMap, SeedStock, Selected, "BuySeedStock")
    end
  end
}, "AutoBuySeed")

Tab:CreateSection("Gear's")

Tab:CreateDropdown({
  Name = "Select Gear",
  Description = "Select the gear you want to buy",
  Options = ParseShopItems("Gear_Shop", GearLabelMap, GearStock, false),
  CurrentOption = {},
  MultipleOptions = true,
  SpecialType = nil,
  Callback = function()end
}, "SelectGear")

Tab:CreateToggle({
  Name = "Show Available Gear",
  Callback = function()
    local Filter = Flags.ShowAvailableGear.CurrentValue
    local Options = ParseShopItems("Gear_Shop", GearLabelMap, GearStock, Filter)
    Flags.SelectGear:Set({
      Options = Options,
      CurrentOption = {},
    })
  end
}, "ShowAvailableGear")

Tab:CreateToggle({
  Name = "Auto Buy Gear",
  Callback = function()
    while Flags.AutoBuyGear.CurrentValue and task.wait(.1) do
      local Selected = Flags.SelectGear.CurrentOption
      BuyAll(GearLabelMap, GearStock, Selected, "BuyGearStock")
    end
  end
}, "AutoBuyGear")

task.spawn(function()
  while true and task.wait(1) do
    ParseShopItems("Seed_Shop", SeedLabelMap, SeedStock, Flags.ShowAvailableSeeds.CurrentValue)
    ParseShopItems("Gear_Shop", GearLabelMap, GearStock, Flags.ShowAvailableGear.CurrentValue)
  end
end)

-- Tab:CreateSection("Egg's")

-- Tab:CreateDropdown({
-- 	Name = "Select Egg",
-- 	Description = "Select the egg you want to buy",
-- 	Options = Eggs,
-- 	CurrentOption = {},
-- 	MultipleOptions = true,
-- 	SpecialType = nil,
-- 	Callback = function()end
-- }, "SelectEgg")

-- Tab:CreateToggle({
-- 	Name = "Auto Buy Egg",
-- 	Callback = function()
-- 		while Flags.AutoBuyEgg.CurrentValue and task.wait(.1) do
-- 			for Index, Loc in next, EggLocations:GetChildren() do
-- 				for SIndex, _ in next, Flags.SelectEgg.CurrentOption do
-- 					if Loc.Name == SIndex and not Loc:GetAttribute("RobuxEggOnly") then
-- 						GameEvents.BuyPetEgg:FireServer(Index - 3)
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end
-- }, "AutoBuyEgg")

local Tab: Tab = Window:CreateTab({
	Name = "QoL",
	Icon = "leaf",
	ImageSource = "Lucide",
	ShowTitle = false
})

Tab:CreateSection("QoL")

CreateFeature(Tab, "QoL")

local Tab: Tab = Window:CreateTab({
	Name = "Safety",
	Icon = "shield",
	ImageSource = "Material",
	ShowTitle = false
})

Tab:CreateSection("Identity")

CreateFeature(Tab, "HideIdentity")

local Tab: Tab = Window:CreateTab({
	Name = "Settings",
	Icon = "settings",
	ImageSource = "Lucide",
	ShowTitle = false
})

Tab:BuildConfigSection()

getgenv().CreateUniversalTabs()
