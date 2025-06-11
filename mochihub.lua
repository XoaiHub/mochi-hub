pcall(function()
    workspace.StreamingEnabled = false
    if workspace:FindFirstChild("SimulationRadius") then
        workspace.SimulationRadius = 999999
    end
end)

-- Create VirtualUser to prevent AFK kick
local bb = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    bb:CaptureController()
    bb:ClickButton2(Vector2.new())

    
end)


local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local player   = Players.LocalPlayer
local char     = player.Character or player.CharacterAdded:Wait()
local hrp      = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
game:GetService("RunService"):Set3dRenderingEnabled(false)

local executor = "unknown"
pcall(function()
    if identifyexecutor then
        executor = identifyexecutor():lower()
    end
end)
print("Running on executor:", executor)

local success, _queue = pcall(function()
    return (syn and syn.queue_on_teleport)
        or queue_on_teleport
        or (fluxus and fluxus.queue_on_teleport)
end)
local queue_on_tp = success and _queue or function(...) end

local remotesRoot1 = ReplicatedStorage:WaitForChild("Remotes")
local remotePromiseFolder = ReplicatedStorage
    :WaitForChild("Shared")
    :WaitForChild("Network")
    :WaitForChild("RemotePromise")
local remotesRoot2 = remotePromiseFolder:WaitForChild("Remotes")

local EndDecisionRemote = remotesRoot1:WaitForChild("EndDecision")

local hasPromise = true
local RemotePromiseMod
do
    local ok, mod = pcall(function()
        return require(remotePromiseFolder)
    end)
    if ok and mod then
        RemotePromiseMod = mod
    else
        hasPromise = false
        warn("↳ Free Executor doesnt support RemotePromise now using the Fallback thing")
    end
end

local activateName = "C_ActivateObject"
local activateRemote = remotesRoot2:FindFirstChild(activateName)
    or remotesRoot1:FindFirstChild(activateName)
assert(activateRemote,
       "No Remote '"..activateName.."' Found")

local Activate
if hasPromise then
    Activate = RemotePromiseMod.new(activateName)
else
    if activateRemote:IsA("RemoteFunction") then
        Activate = { InvokeServer = function(_, ...) return activateRemote:InvokeServer(...) end }
    elseif activateRemote:IsA("RemoteEvent") then
        Activate = { InvokeServer = function(_, ...) return activateRemote:FireServer(...) end }
    else
        error(activateName.." is not an Remote")
    end
end

local bondData = {}
local seenKeys = {}

local function recordBonds()
    local runtime = Workspace:WaitForChild("RuntimeItems")
    for _, item in ipairs(runtime:GetChildren()) do
        if item.Name:match("Bond") then
            local part = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
            if part then
                local key = ("%.1f_%.1f_%.1f"):format(
                    part.Position.X, part.Position.Y, part.Position.Z
                )
                if not seenKeys[key] then
                    seenKeys[key] = true
                    table.insert(bondData, { item = item, pos = part.Position })
                end
            end
        end
    end
end

print("=== Starting map scan ===")
local scanTarget = CFrame.new(-424.448975, 26.055481, -49040.6562)
local scanSteps  = 50
for i = 1, scanSteps do
    hrp.CFrame = hrp.CFrame:Lerp(scanTarget, i/scanSteps)
    task.wait(0.3)
    recordBonds()
    task.wait(0.1)
end
hrp.CFrame = scanTarget
task.wait(0.3)
recordBonds()

print(("→ %d Bonds found"):format(#bondData))
if #bondData == 0 then
    warn("Couldnt find Bonds however")
    return
end

local chair = Workspace:WaitForChild("RuntimeItems"):FindFirstChild("Chair")
assert(chair and chair:FindFirstChild("Seat"), "Chair.Seat not found")
local seat = chair.Seat

seat:Sit(humanoid)
task.wait(0.2)
local seatWorks = (humanoid.SeatPart == seat)

for idx, entry in ipairs(bondData) do
    print(("--- Bond %d/%d ---"):format(idx, #bondData))
    local targetPos = entry.pos + Vector3.new(0, 2, 0)

    if seatWorks then
        seat:PivotTo(CFrame.new(targetPos))
        task.wait(0.1)
        if humanoid.SeatPart ~= seat then
            seat:Sit(humanoid)
            task.wait(0.1)
        end
    else
        hrp.CFrame = CFrame.new(targetPos)
        task.wait(0.3)
    end

    local ok, err = pcall(function()
        Activate:InvokeServer(entry.item)
    end)
    if not ok then
        warn("InvokeServer error:", err)
    end

    task.wait(0.5)

    if not entry.item.Parent then
        print("Bond collected")
    else
        warn("Not colllected some error with the Timeout maybe...")
    end
end


humanoid:TakeDamage(999999)
EndDecisionRemote:FireServer(false)
queue_on_tp('loadstring(game:HttpGet("https://raw.githubusercontent.com/PenguinCre8te/Auto-bond-dead-rails/refs/heads/main/script.lua"))()') -- For examlpe 'loadstring(game:HttpGet("https://raw.githubusercontent.com/PenguinCre8te/Auto-bond-dead-rails/refs/heads/main/script.lua"))()'

print("=== Script finished ===")
