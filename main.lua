local players_service = cloneref(game:GetService("Players"))
local local_player = players_service.LocalPlayer
local workspace_ref = cloneref(workspace)
local farm_model = nil

-- Config
local pickup_enabled = true
-- Sell point CFrame (vị trí bạn muốn đứng yên)
local sell_position = CFrame.new(86.5854721, 2.76619363, 0.426784277, 0, 0, -1, 0, 1, 0, 1, 0, 0)

-- Đưa người chơi đứng yên tại vị trí sell point
task.spawn(function()
    while pickup_enabled do
        local char = local_player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char:PivotTo(sell_position)
        end
        task.wait(1)
    end
end)

-- Tìm farm model của người chơi
for _, descendant in next, workspace_ref:FindFirstChild("Farm"):GetDescendants() do
    if descendant.Name == "Owner" and descendant.Value == local_player.Name then
        farm_model = descendant.Parent and descendant.Parent.Parent
        break
    end
end

-- Gọi fireproximityprompt toàn bộ cây, từ xa
task.spawn(function()
    while pickup_enabled and farm_model do
        local plants_folder = farm_model:FindFirstChild("Plants_Physical")
        if plants_folder then
            for _, plant_model in next, plants_folder:GetChildren() do
                if plant_model:IsA("Model") then
                    for _, object in next, plant_model:GetDescendants() do
                        if object:IsA("ProximityPrompt") then
                            -- ⚠️ Mở giới hạn khoảng cách nếu game cho phép
                            pcall(function()
                                object.RequiresLineOfSight = false
                                object.MaxActivationDistance = math.huge
                            end)
                            fireproximityprompt(object)
                            task.wait(0.01)
                        end
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)
