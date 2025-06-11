local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
local Workspace = cloneref(workspace)
local FarmModel = nil

-- Config
local PickupEnabled = true
local PickupRadius = 150

-- Wait for character
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

-- Find player's farm
local farmFolder = Workspace:FindFirstChild("Farm")
if farmFolder then
    for _, descendant in next, farmFolder:GetDescendants() do
        if descendant.Name == "Owner" and descendant:IsA("ObjectValue") and descendant.Value == LocalPlayer.Name then
            FarmModel = descendant:FindFirstAncestorOfClass("Model")
            break
        end
    end
end

-- Pickup loop
task.spawn(function()
    while PickupEnabled and FarmModel do
        local plantsFolder = FarmModel:FindFirstChild("Plants_Physical")
        if plantsFolder then
            for _, plant in next, plantsFolder:GetChildren() do
                if plant:IsA("Model") then
                    local pivot = plant:GetPivot().Position
                    local playerPos = LocalPlayer.Character:GetPivot().Position
                    local distance = (pivot - playerPos).Magnitude

                    for _, obj in next, plant:GetDescendants() do
                        if obj:IsA("ProximityPrompt") and distance < PickupRadius then
                            -- Optional teleport to the plant
                            LocalPlayer.Character:PivotTo(CFrame.new(pivot + Vector3.new(0, 3, 0)))

                            -- Activate the prompt
                            fireproximityprompt(obj)
                            task.wait(0.1)
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)
