-- [[
--  GAG Calculator for Grow a Garden by Havoc
--  Discord: havoc06946 - DM me for more suggestions
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lurnai = {}
Lurnai.LocalPlayer = Players.LocalPlayer
Lurnai.PlayerGui = Lurnai.LocalPlayer:WaitForChild("PlayerGui")
Lurnai.ShecklesUI = Lurnai.PlayerGui:WaitForChild("Sheckles_UI")
Lurnai.MoneyUI = Lurnai.ShecklesUI:WaitForChild("Money")

Lurnai.InventoryValueUI = Lurnai.MoneyUI:Clone()
Lurnai.InventoryValueUI.Name = "InventoryValue"
Lurnai.InventoryValueUI.Parent = Lurnai.ShecklesUI

local originalPosition = Lurnai.MoneyUI.Position
Lurnai.MoneyUI.Position =
    UDim2.new(
    originalPosition.X.Scale,
    originalPosition.X.Offset,
    originalPosition.Y.Scale,
    originalPosition.Y.Offset - 50
)

Lurnai.InventoryValueUI.Position =
    UDim2.new(
    originalPosition.X.Scale,
    originalPosition.X.Offset,
    originalPosition.Y.Scale,
    originalPosition.Y.Offset - 36
)

Lurnai.Item_Module = require(ReplicatedStorage.Item_Module)
Lurnai.MutationHandler = require(ReplicatedStorage.Modules.MutationHandler)
Lurnai.PetUtilities = require(ReplicatedStorage.Modules.PetServices.PetUtilities)
Lurnai.PetRegistry = require(ReplicatedStorage.Data.PetRegistry)
Lurnai.NumberUtil = require(ReplicatedStorage.Modules.NumberUtil)
Lurnai.DataService = require(ReplicatedStorage.Modules.DataService)

function Lurnai.CalculatePlantValue(plant)
    local itemString = plant:FindFirstChild("Item_String")
    if not itemString then
        return 0
    end

    local variant = plant:FindFirstChild("Variant")
    if not variant then
        return 0
    end

    local weight = plant:FindFirstChild("Weight")
    if not weight then
        return 0
    end

    local itemData = Lurnai.Item_Module.Return_Data(itemString.Value)
    if not itemData or #itemData < 3 then
        return 0
    end

    local baseValue = itemData[3]
    local weightRequirement = itemData[2]
    local variantMultiplier = Lurnai.Item_Module.Return_Multiplier(variant.Value)
    local mutationMultiplier = Lurnai.MutationHandler:CalcValueMulti(plant)
    local plantValue = baseValue * mutationMultiplier * variantMultiplier
    local weightRatio = math.clamp(weight.Value / weightRequirement, 0.95, 100000000)
    local finalValue = plantValue * (weightRatio * weightRatio)

    return math.round(finalValue)
end

function Lurnai.CalculatePetValue(petTool)
    if not petTool then
        return 0
    end

    local itemType = petTool:GetAttribute("ItemType")
    if itemType ~= "Pet" then
        return 0
    end

    local petUUID = petTool:GetAttribute("PET_UUID")
    if not petUUID then
        return 0
    end

    local success, playerData =
        pcall(
        function()
            return Lurnai.DataService:GetData()
        end
    )

    if not success or not playerData then
        return 0
    end

    local petData = playerData.PetsData.PetInventory.Data[petUUID]
    if not petData then
        return 0
    end

    local hatchedFrom = petData.PetData.HatchedFrom
    if not hatchedFrom or hatchedFrom == "" then
        return 0
    end

    local eggData = Lurnai.PetRegistry.PetEggs[hatchedFrom]
    if not eggData then
        return 0
    end

    local petTypeData = eggData.RarityData.Items[petData.PetType]
    if not petTypeData then
        return 0
    end

    local weightRange = petTypeData.GeneratedPetData.WeightRange
    if not weightRange then
        return 0
    end

    local weightProgress = Lurnai.NumberUtil.ReverseLerp(weightRange[1], weightRange[2], petData.PetData.BaseWeight)
    local weightMultiplier = math.lerp(0.8, 1.2, weightProgress)

    local levelProgress = Lurnai.PetUtilities:GetLevelProgress(petData.PetData.Level)
    local levelMultiplier = math.lerp(0.15, 6, levelProgress)

    local baseSellPrice = Lurnai.PetRegistry.PetList[petData.PetType].SellPrice
    local finalValue = baseSellPrice * weightMultiplier * levelMultiplier

    return math.floor(finalValue)
end

function Lurnai.FormatNumber(num)
    local formatted = tostring(num)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then
            break
        end
    end
    return formatted
end

function Lurnai.CalculateHeldItemValue()
    local character = Lurnai.LocalPlayer.Character
    if not character then
        return 0
    end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then
        return 0
    end

    if tool:FindFirstChild("Item_String") then
        return Lurnai.CalculatePlantValue(tool)
    end

    if tool:GetAttribute("ItemType") == "Pet" then
        return Lurnai.CalculatePetValue(tool)
    end

    return 0
end

function Lurnai.CalculateInventoryValue()
    local backpack = Lurnai.LocalPlayer:FindFirstChild("Backpack")
    if not backpack then
        return 0
    end

    local totalValue = 0

    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            if tool:FindFirstChild("Item_String") then
                totalValue = totalValue + Lurnai.CalculatePlantValue(tool)
            end

            if tool:GetAttribute("ItemType") == "Pet" then
                totalValue = totalValue + Lurnai.CalculatePetValue(tool)
            end
        end
    end

    local character = Lurnai.LocalPlayer.Character
    if character then
        local equippedTool = character:FindFirstChildOfClass("Tool")
        if equippedTool then
            if equippedTool:FindFirstChild("Item_String") then
                totalValue = totalValue + Lurnai.CalculatePlantValue(equippedTool)
            end

            if equippedTool:GetAttribute("ItemType") == "Pet" then
                totalValue = totalValue + Lurnai.CalculatePetValue(equippedTool)
            end
        end
    end

    return totalValue
end

function Lurnai.UpdateHeldItemDisplay()
    local value = Lurnai.CalculateHeldItemValue()

    if value > 0 then
        Lurnai.MoneyUI.Text = "Worth: $" .. Lurnai.FormatNumber(value)
        Lurnai.MoneyUI.Visible = true
    else
        Lurnai.MoneyUI.Visible = false
    end
end

function Lurnai.UpdateInventoryDisplay()
    local totalValue = Lurnai.CalculateInventoryValue()

    if totalValue > 0 then
        Lurnai.InventoryValueUI.Text = "Inventory: $" .. Lurnai.FormatNumber(totalValue)
        Lurnai.InventoryValueUI.Visible = true
    else
        Lurnai.InventoryValueUI.Text = "Inventory: $0"
        Lurnai.InventoryValueUI.Visible = true
    end
end

Lurnai.MoneyUI.Visible = false
Lurnai.InventoryValueUI.Visible = true

Lurnai.connection =
    RunService.Heartbeat:Connect(
    function()
        Lurnai.UpdateHeldItemDisplay()
        Lurnai.UpdateInventoryDisplay()
    end
)

local backpack = Lurnai.LocalPlayer:WaitForChild("Backpack")
backpack.ChildAdded:Connect(Lurnai.UpdateInventoryDisplay)
backpack.ChildRemoved:Connect(Lurnai.UpdateInventoryDisplay)

Lurnai.LocalPlayer.CharacterAdded:Connect(
    function(character)
        character.ChildAdded:Connect(Lurnai.UpdateInventoryDisplay)
        character.ChildRemoved:Connect(Lurnai.UpdateInventoryDisplay)
    end
)

Lurnai.PlayerRemoving =
    Players.PlayerRemoving:Connect(
    function(player)
        if player == Lurnai.LocalPlayer then
            Lurnai.connection:Disconnect()
        end
    end
)
