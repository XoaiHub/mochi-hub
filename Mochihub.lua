local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "SheScripts Gag",
   Icon = 0,
   LoadingTitle = "Loading Script",
   LoadingSubtitle = "Grow A Garden Seed Buyer",
   ShowText = "SheScripts",
   Theme = "Midnight",
   ToggleUIKeybind = "K",
   ConfigurationSaving = {
      Enabled = true,
      FileName = "SheScriptsGag"
   },
   Discord = {
      Enabled = false
   },
   KeySystem = false
})

local Tab = Window:CreateTab("Buy Seeds", "package")

local validSeeds = {
   "Carrot", "Strawberry", "Blueberry", "Tomato", "Cauliflower", "Watermelon", "Green Apple", "Avocado", "Banana", "Pineapple", "Kiwi", "Bell Pepper", "Prickly Pear", "Loquat", "Feljoa"
}

local selectedSeed = validSeeds[1]
local buyingAll = false
local autoBuying = false
local autoBuyingAll = false

local rs = game:GetService("ReplicatedStorage")
local buyEvent = rs:FindFirstChild("GameEvents") and rs.GameEvents:FindFirstChild("BuySeedStock")

Tab:CreateInput({
   Name = "Seed Name",
   PlaceholderText = "Enter Seed Name",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      selectedSeed = Text
   end
})

Tab:CreateDropdown({
   Name = "Select Seed",
   Options = validSeeds,
   CurrentOption = {validSeeds[1]},
   MultipleOptions = false,
   Callback = function(Options)
      selectedSeed = Options[1]
   end
})

Tab:CreateButton({
   Name = "Buy Selected Seed",
   Callback = function()
      if buyEvent and selectedSeed then
         buyEvent:FireServer(selectedSeed)
      end
   end
})

Tab:CreateToggle({
   Name = "Auto Buy Selected",
   CurrentValue = false,
   Callback = function(val)
      autoBuying = val
      task.spawn(function()
         while autoBuying do
            if buyEvent and selectedSeed then
               buyEvent:FireServer(selectedSeed)
            end
            task.wait(0.00000000001)
         end
      end)
   end
})

Tab:CreateToggle({
   Name = "Auto Buy All",
   CurrentValue = false,
   Callback = function(val)
      autoBuyingAll = val
      task.spawn(function()
         while autoBuyingAll do
            for _, seed in ipairs(validSeeds) do
               if buyEvent then
                  buyEvent:FireServer(seed)
               end
               task.wait(0.00000000001)
            end
         end
      end)
   end
})

local Sell = Window:CreateTab("Sell", "rewind")

Sell:CreateButton({
   Name = "Sell Inventory",
   Callback = function()
      local sellPos = CFrame.new(90.08035, 0.98381, 3.02662)
      local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
      if hrp then
         local orig = hrp.CFrame
         hrp.CFrame = sellPos
         task.wait(0.1)
         rs.GameEvents.Sell_Inventory:FireServer()
         task.wait(0.1)
         hrp.CFrame = orig
      end
   end
})

Sell:CreateButton({
   Name = "Sell Item in Hand",
   Callback = function()
      local sellPos = CFrame.new(90.08035, 0.98381, 3.02662)
      local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
      if hrp then
         local orig = hrp.CFrame
         hrp.CFrame = sellPos
         task.wait(0.1)
         rs.GameEvents.Sell_Item:FireServer()
         task.wait(0.1)
         hrp.CFrame = orig
      end
   end
})

local Shop = Window:CreateTab("Shops", "shopping-bag")

Shop:CreateButton({
   Name = "Seed Shop",
   Callback = function()
      local gui = game:GetService("Players").LocalPlayer.PlayerGui
      gui.Seed_Shop.Enabled = true
      gui.Gear_Shop.Enabled = false
      gui.HoneyEventShop_UI.Enabled = false
      gui.CosmeticShop_UI.Enabled = false
   end
})

Shop:CreateButton({
   Name = "Gear Shop",
   Callback = function()
      local gui = game:GetService("Players").LocalPlayer.PlayerGui
      gui.Seed_Shop.Enabled = false
      gui.Gear_Shop.Enabled = true
      gui.HoneyEventShop_UI.Enabled = false
      gui.CosmeticShop_UI.Enabled = false
   end
})

Shop:CreateButton({
   Name = "Cosmetics Shop",
   Callback = function()
      local gui = game:GetService("Players").LocalPlayer.PlayerGui
      gui.Seed_Shop.Enabled = false
      gui.Gear_Shop.Enabled = false
      gui.HoneyEventShop_UI.Enabled = false
      gui.CosmeticShop_UI.Enabled = true
   end
})

Shop:CreateButton({
   Name = "Honey Shop",
   Callback = function()
      local gui = game:GetService("Players").LocalPlayer.PlayerGui
      gui.Seed_Shop.Enabled = false
      gui.Gear_Shop.Enabled = false
      gui.HoneyEventShop_UI.Enabled = true
      gui.CosmeticShop_UI.Enabled = false
   end
})

Shop:CreateButton({
   Name = "Hide",
   Callback = function()
      local gui = game:GetService("Players").LocalPlayer.PlayerGui
      gui.Seed_Shop.Enabled = false
      gui.Gear_Shop.Enabled = false
      gui.HoneyEventShop_UI.Enabled = false
      gui.CosmeticShop_UI.Enabled = false
   end
})
