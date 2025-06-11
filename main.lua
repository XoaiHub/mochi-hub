local players_service = cloneref(game:GetService("Players"))
local local_player = players_service.LocalPlayer
local workspace_ref = cloneref(workspace)
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local sell_event = replicated_storage:WaitForChild("GameEvents"):WaitForChild("Sell_Inventory")

local farm_model = nil

-- Config
local pickup_enabled = true
local sell_position = CFrame.new(86.5854721, 2.76619363, 0.426784277, 0, 0, -1, 0, 1, 0, 1, 0, 0)
local sell_wait_time = 10 -- thời gian đứng yên tại điểm bán trước khi tiếp tục
local teleport_wait_time = 1

-- Tìm farm model của người chơi
for _, descendant in next, workspace_ref:FindFirstChild("Farm"):GetDescendants() do
    if descendant.Name == "Owner" and descendant.Value == local_player.Name then
        farm_model = descendant.Parent and descendant.Parent.Parent
        break
    end
end

-- Kiểm tra túi đầy (CẦN CHỈNH LẠI HÀM NÀY CHO GAME CỦA BẠN)
local function isBagFull()
    -- Ví dụ: return local_player.leaderstats.Coins.Value >= 1000
    -- hoặc return local_player:FindFirstChild("Bag").Value >= local_player:FindFirstChild("MaxBag").Value
    return false -- Mặc định false, bạn cần cập nhật
end

-- Teleport nhân vật
local function teleportTo(cf)
    local char = local_player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char:PivotTo(cf)
    end
end

-- Main loop
task.spawn(function()
    while pickup_enabled and farm_model do
        local char = local_player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            task.wait(0.5)
            continue
        end

        -- Nếu túi đầy → bán
        if isBagFull() then
            teleportTo(sell_position)
            task.wait(teleport_wait_time)
            sell_event:FireServer()
            task.wait(sell_wait_time)
        else
            -- Nếu chưa đầy túi → đi collect
            local plants_folder = farm_model:FindFirstChild("Plants_Physical")
            if plants_folder then
                for _, plant_model in next, plants_folder:GetChildren() do
                    if plant_model:IsA("Model") then
                        local plant_pos = plant_model:GetPivot().Position

                        for _, prompt in next, plant_model:GetDescendants() do
                            if prompt:IsA("ProximityPrompt") then
                                teleportTo(CFrame.new(plant_pos + Vector3.new(0, 3, 0)))
                                task.wait(0.05)
                                fireproximityprompt(prompt)
                                task.wait(0.05)
                                teleportTo(sell_position) -- quay lại sell để đợi tiếp
                                task.wait(0.1)
                            end
                        end
                    end
                end
            end
        end

        task.wait(0.2)
    end
end)
