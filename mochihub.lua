local players_service = cloneref(game:GetService("Players"))
local local_player = players_service.LocalPlayer
local workspace_ref = cloneref(workspace)
local farm_model = nil

-- Config
local pickup_enabled = true
local sell_position = CFrame.new(86.5854721, 2.76619363, 0.426784277, 0, 0, -1, 0, 1, 0, 1, 0, 0)

-- Tìm farm model của người chơi
for _, descendant in next, workspace_ref:FindFirstChild("Farm"):GetDescendants() do
    if descendant.Name == "Owner" and descendant.Value == local_player.Name then
        farm_model = descendant.Parent and descendant.Parent.Parent
        break
    end
end

-- Teleport nhân vật
local function teleportTo(cf)
    local char = local_player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char:PivotTo(cf)
    end
end

-- Đảm bảo nhân vật luôn ở sell point (sau lần đầu)
task.spawn(function()
    while pickup_enabled do
        task.wait(1)
        local char = local_player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            teleportTo(sell_position)
        end
    end
end)

-- Main loop: teleport tạm đến cây → fire → về sell point
task.spawn(function()
    while pickup_enabled and farm_model do
        local char = local_player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            task.wait(0.5)
            continue
        end

        local plants_folder = farm_model:FindFirstChild("Plants_Physical")
        if plants_folder then
            for _, plant_model in next, plants_folder:GetChildren() do
                if plant_model:IsA("Model") then
                    local plant_pos = plant_model:GetPivot().Position

                    for _, prompt in next, plant_model:GetDescendants() do
                        if prompt:IsA("ProximityPrompt") then
                            -- TP nhanh đến cây
                            teleportTo(CFrame.new(plant_pos + Vector3.new(0, 3, 0)))
                            task.wait(0.05)
                            fireproximityprompt(prompt)
                            task.wait(0.05)
                            -- Trở lại sell point
                            teleportTo(sell_position)
                            task.wait(0.1)
                        end
                    end
                end
            end
        end

        task.wait(0.2)
    end
end)
