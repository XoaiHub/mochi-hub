-- AutoCrate.lua

local MinBalls      = 800
local CurrencyStat  = "BeachBalls2025"
local CheckInterval = 2.0
local AfterOpenWait = 1.25

local BOX_DEFS = {
    ["Mystery Box"] = {
        crateId   = "Summer2025Box",
        crateType = "MysteryBox",
    },
    ["Summer 2025 Box"] = {
        crateId   = "Summer2025Box",
        crateType = "MysteryBox",
    },
    -- ["Halloween Box"] = { crateId = "Halloween2025Box", crateType = "MysteryBox" },
}

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local function getLeaderstatValue(statName)
    local ok, val = pcall(function()
        local ls = LP:FindFirstChild("leaderstats")
        if not ls then return nil end
        local s = ls:FindFirstChild(statName)
        if not s then return nil end
        return s.Value
    end)
    if ok then return val end
    return nil
end

local function getBallCount()
    return getLeaderstatValue(CurrencyStat) or 0
end

local Remotes   = RS:WaitForChild("Remotes")
local Shop      = Remotes:WaitForChild("Shop")
local OpenCrate = Shop:WaitForChild("OpenCrate")

local function openOne(displayName)
    local def = BOX_DEFS[displayName]
    if not def then return false end
    local args = { def.crateId, def.crateType, CurrencyStat }
    local ok, err = pcall(function()
        OpenCrate:InvokeServer(unpack(args))
    end)
    if ok then
        print("🎁 Opened:", displayName)
        return true
    else
        warn("[CrateAuto] Error:", err)
        return false
    end
end

local function waitAfterOpen(minBefore)
    local t0 = tick()
    repeat
        task.wait(0.25)
        if getBallCount() < minBefore then break end
    until (tick() - t0) > math.max(0.5, AfterOpenWait)
end

task.spawn(function()
    while task.wait(math.max(0.5, CheckInterval)) do
        local balls = getBallCount()
        if balls >= MinBalls then
            for displayName, enabled in pairs(getgenv().Config or {}) do
                if enabled and BOX_DEFS[displayName] then
                    while getBallCount() >= MinBalls do
                        local ok = openOne(displayName)
                        if not ok then break end
                        waitAfterOpen(MinBalls)
                    end
                end
            end
        end
    end
end)


