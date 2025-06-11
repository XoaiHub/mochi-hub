local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Workspace = cloneref(workspace)

local LocalPlayer = Players.LocalPlayer
local SellEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Sell_Inventory")
local SellPosition = CFrame.new(86.5854721, 2.76619363, 0.426784277, 0, 0, -1, 0, 1, 0, 1, 0, 0)

local FarmModel = nil
local Running = true

-- ⚠️ Thay thế bằng logic thật sự để xác định túi đầy
local function isBagFull()
    -- Ví dụ:
    -- return LocalPlayer:FindFirstChild("Bag").Value >= LocalPlayer:FindFirstChild("MaxBag").Value
    return false -- Mặc định chưa đầy túi
end

local function teleportTo(cf)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char:PivotTo(cf)
    end
end

-- Tìm farm model của bạn
do
    local farmFolder = Workspace:FindFirstChild("Farm")
    if farmFolder then
        for _, desc in ipairs(farmFolder:GetDescendants()) do
            if desc.Name == "Owner" and desc.Value == LocalPlayer.Name then
                FarmModel = desc.Parent and desc.Parent.Parent
                break
            end
        end
    end
end

-- Main loop
task.spawn(function()
    while Running and FarmModel do
        if isBagFull() then
            teleportTo(SellPosition)
            task.wait(1)
            SellEvent:FireServer()
            task.wait(1)
        else
            local Plants = FarmModel:FindFirstChild("Plants_Physical")
            if Plants then
                for _, plant in ipairs(Plants:GetChildren()) do
                    if isBagFull() then break end

                    if plant:IsA("Model") then
                        local prompt = plant:FindFirstDescendantWhichIsA("ProximityPrompt")
                        if prompt then
                            local pos = plant:GetPivot().Position + Vector3.new(0, 3, 0)
                            teleportTo(CFrame.new(pos))
                            task.wait(0.05)
                            fireproximityprompt(prompt)
                            task.wait(0.1)
                        end
                    end
                end
            end
        end

        task.wait(0.2)
    end
end)
