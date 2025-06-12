local pickup_enabled = true
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")

local CollectController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CollectController"))

-- Kích hoạt chế độ thu thập
CollectController._lastCollected = 0
CollectController._holding = true
CollectController:_updateButtonState()

-- Tìm farm của người chơi
local farm_model
local farm_root = Workspace:FindFirstChild("Farm")
if farm_root then
    for _, descendant in ipairs(farm_root:GetDescendants()) do
        if descendant.Name == "Owner" and descendant:IsA("ObjectValue") and descendant.Value == LocalPlayer.Name then
            farm_model = descendant:FindFirstAncestorOfClass("Model")
            break
        end
    end
end

-- Hàm teleport đến object
local function teleportTo(part)
    if part and part:IsA("BasePart") then
        HRP.CFrame = part.CFrame + Vector3.new(0, 3, 0) -- Teleport phía trên đối tượng một chút
        task.wait(0.1)
    end
end

-- Thu hoạch cây
task.spawn(function()
    while pickup_enabled and farm_model and farm_model.Parent do
        local plants_folder = farm_model:FindFirstChild("Plants_Physical")
        if plants_folder then
            for _, plant_model in ipairs(plants_folder:GetChildren()) do
                if plant_model:IsA("Model") then
                    local mainPart = plant_model:FindFirstChildWhichIsA("BasePart")
                    if mainPart then
                        teleportTo(mainPart)
                    end

                    CollectController._lastCollected = 0
                    CollectController:_updateButtonState()
                    CollectController:Collect(plant_model)
                    task.wait(0.05)

                    for _, object in ipairs(plant_model:GetDescendants()) do
                        if object:IsA("BasePart") or object:IsA("Model") then
                            CollectController._lastCollected = 0
                            CollectController:_updateButtonState()
                            CollectController:Collect(object)
                            task.wait(0.01)
                        end
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)
