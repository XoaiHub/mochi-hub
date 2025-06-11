local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
local Workspace = cloneref(workspace)
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local FarmModel = nil

-- Config
local PickupEnabled = true
local SellInterval = 60 -- Thời gian giữa mỗi lần bán (giây)
local ReturnCFrame = CFrame.new(
    86.5854721, 2.76619363, 0.426784277,
    0, 0, -1,
    0, 1, 0,
    1, 0, 0
)

-- Tìm farm của người chơi
for _, descendant in next, Workspace:FindFirstChild("Farm"):GetDescendants() do
    if descendant.Name == "Owner" and descendant.Value == LocalPlayer.Name then
        FarmModel = descendant.Parent and descendant.Parent.Parent
        break
    end
end

-- Vòng lặp bán mỗi X giây
task.spawn(function()
    while PickupEnabled do
        task.wait(SellInterval)

        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- Teleport về vị trí chỉ định
            hrp.CFrame = ReturnCFrame
            task.wait(0.5)

            -- Fire sự kiện bán
            local sellEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Sell_Inventory")
            sellEvent:FireServer()
        end
    end
end)

-- Vòng lặp thu hoạch cây
task.spawn(function()
    while PickupEnabled and FarmModel do
        local plants_folder = FarmModel:FindFirstChild("Plants_Physical")
        if plants_folder then
            for _, plant_model in next, plants_folder:GetChildren() do
                if plant_model:IsA("Model") then
                    for _, object in next, plant_model:GetDescendants() do
                        if object:IsA("ProximityPrompt") then
                            local plant_pos = plant_model:GetPivot().Position

                            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                -- Teleport tạm tới cây
                                hrp.CFrame = CFrame.new(plant_pos + Vector3.new(0, 2, 0))
                                task.wait(0.2)

                                fireproximityprompt(object)
                                task.wait(0.1)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)
