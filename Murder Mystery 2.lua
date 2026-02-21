--services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local decorations = workspace:FindFirstChild("Decorations")
local Honeycombs = Workspace.Honeycombs:GetChildren()


--destroy pit for diamond egg
if decorations then
    local zone = decorations:FindFirstChild("30BeeZone")
    if zone then
        local pit = zone:FindFirstChild("Pit")
        if pit then
            pit:Destroy()
        end
    end
end

-- CONFIG
local MOVE_SPEED = 900 -- studs per second
local BOB_HEIGHT = 1
local BOB_TIME = 0.1
local BOB_DURATION = 1.5

local targets = {
    CFrame.new(42, 149, -531),          -- Diamond Egg
    CFrame.new(-413.77, 17.17, 467.18), -- Star Jelly
    CFrame.new(83.94, 68.01, -142.12),  -- Gold Egg
    CFrame.new(-435.52, 93.26, 48.78),  -- Star Jelly
}

local function getCharacter()
    local char = player.Character or player.CharacterAdded:Wait()
    return char, char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
end

local function moveTo(hrp, targetCFrame)
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local duration = distance / MOVE_SPEED

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = targetCFrame }
    )

    tween:Play()
    tween.Completed:Wait()
end

local function bob(hrp)
    local upInfo = TweenInfo.new(BOB_TIME, Enum.EasingStyle.Linear)
    local downInfo = TweenInfo.new(BOB_TIME, Enum.EasingStyle.Linear)

    local startTime = os.clock()

    while os.clock() - startTime < BOB_DURATION do
        local upTween = TweenService:Create(
            hrp,
            upInfo,
            { CFrame = hrp.CFrame * CFrame.new(0, BOB_HEIGHT, 0) }
        )

        upTween:Play()
        upTween.Completed:Wait()

        local downTween = TweenService:Create(
            hrp,
            downInfo,
            { CFrame = hrp.CFrame * CFrame.new(0, -BOB_HEIGHT, 0) }
        )

        downTween:Play()
        downTween.Completed:Wait()
    end
end

-- MAIN LOOP
for i, target in ipairs(targets) do
    local character, hrp, humanoid = getCharacter()

    moveTo(hrp, target)
    bob(hrp)
end
wait(1)


--claim hive
local targetPosition = nil
local targetHiveID = nil
local foundOwnedHive = false

-- First, look for a hive owned by the local player
for _, hive in pairs(Honeycombs) do
    if hive:IsA("Model") 
       and hive:FindFirstChild("patharrow") 
       and hive.patharrow:FindFirstChild("Base") 
       and hive:FindFirstChild("HiveID") 
       and hive:FindFirstChild("Owner") 
       and hive.Owner.Value == _LocalPlayer then

        targetPosition = hive.patharrow.Base.Position + Vector3.new(0, 1, 0)
        targetHiveID = hive.HiveID.Value
        foundOwnedHive = true
        break
    end
end

-- If no owned hive was found, pick an unowned hive
if not foundOwnedHive then
    for _, hive in pairs(Honeycombs) do
        if hive:IsA("Model") 
           and hive:FindFirstChild("patharrow") 
           and hive.patharrow:FindFirstChild("Base") 
           and hive:FindFirstChild("HiveID") 
           and hive:FindFirstChild("Owner") 
           and hive.Owner.Value == nil then

            targetPosition = hive.patharrow.Base.Position + Vector3.new(0, 1, 0)
            targetHiveID = hive.HiveID.Value
            break
        end
    end
end

-- Claim the hive if we found one
if targetHiveID then
    ReplicatedStorage.Events.ClaimHive:FireServer(targetHiveID)
end

wait(0.4)

--honeyday
local args = {
	"ReceiveXmas2025Boost"
}
game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("SelectNPCOption"):FireServer(unpack(args))

wait(0.2)

--construct eggs and jellys
local constructEvent = ReplicatedStorage:WaitForChild("Events")
	:WaitForChild("ConstructHiveCellFromEgg")

local calls = {
	{3, 1, "Basic", 1, false},
	{1, 1, "Gold", 1, false},
	{2, 1, "Diamond", 1, false},
	{3, 1, "StarJelly", 1, false},
	{1, 1, "StarJelly", 1, false},
	{2, 1, "StarJelly", 1, false},
}

for _, args in ipairs(calls) do
	task.wait(0.2)
	constructEvent:InvokeServer(unpack(args))
end
