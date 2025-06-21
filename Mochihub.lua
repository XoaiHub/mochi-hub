-- mm2 coin farm 🤑🤑🤑

local TweenService = game:GetService("TweenService")
local LP = game.Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP = Char:WaitForChild("HumanoidRootPart")
local Humanoid = Char:WaitForChild("Humanoid")

local function GetMap()
    while true do
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:GetAttribute("MapID") and obj:FindFirstChild("CoinContainer") then
                return obj
            end
        end
        task.wait()
    end
end

local function getNearest()
    local map = GetMap()
    local closest, dist = nil, math.huge
    for _, coin in ipairs(map.CoinContainer:GetChildren()) do
        local v = coin:FindFirstChild("CoinVisual")
        if v and not v:GetAttribute("Collected") then
            local d = (HRP.Position - coin.Position).Magnitude
            if d < dist then
                closest = coin
                dist = d
            end
        end
    end
    return closest
end

local function tp(hp)
    Humanoid:ChangeState(11)
    local d = (HRP.Position - hp.Position).Magnitude
    local t = TweenService:Create(HRP, TweenInfo.new(d / 25, Enum.EasingStyle.Linear), {CFrame = hp.CFrame})
    t:Play()
    t.Completed:Wait()
end

while task.wait() do
    local target = getNearest()
    if target then
        tp(target)
        local v = target:FindFirstChild("CoinVisual")
        while v and not v:GetAttribute("Collected") and v.Parent do
            local n = getNearest()
            if n and n ~= target then break end
            task.wait()
        end
    end
end
