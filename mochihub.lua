-- Function to auto select team (run only once)
function autoSelectTeam()
    local args = {
        [1] = "SetTeam",  -- Team setting command
        [2] = "Pirates"   -- Team you want to select (Pirates in this case)
    }

    -- Call InvokeServer to select team
    local success, result = pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
    end)

    -- Check if successful and handle errors
    if success then
        print("Successfully set team to Pirates.")
    else
        warn("Error setting team: " .. tostring(result))
    end
end

-- Call autoSelectTeam once when the script starts
autoSelectTeam()

-- Global variables for quest and fruit
local NameM, NameQ, LvQ, CFQ

-- Function for teleportation to a position
function TP(Pos)
    local character = game.Players.LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = Pos
    else
        warn("HumanoidRootPart not found!")
    end
end

-- Function to check and set quest details based on level
function checkQuest()
    local lvl = game:GetService("Players").LocalPlayer.Data.Level.Value
    -- Check quest based on level ranges
    if lvl <= 9 then
        NameM = "Bandit"
        NameQ = "BanditQuest1"
        LvQ = 1
        CFQ = CFrame.new(1058.9927978515625, 16.13587760925293, 1551.7337646484375)
    elseif lvl >= 10 and lvl < 14 then
        NameM = "Monkey"
        NameQ = "JungleQuest"
        LvQ = 1
        CFQ = CFrame.new(-1598.089111328125, 35.55011749267578, 153.37783813476562)
    elseif lvl >= 15 and lvl <= 24 then
        NameM = "Gorilla"
        NameQ = "JungleQuest"
        LvQ = 2
        CFQ = CFrame.new(-1598.089111328125, 35.55011749267578, 153.37783813476562)
    elseif lvl >= 25 and lvl <= 29 then
        NameM = "The Gorilla King"
        NameQ = "JungleQuest"
        LvQ = 3
        CFQ = CFrame.new(-1136.59375, 6.0392680168151855, -451.90875244140625)
    elseif lvl >= 30 and lvl <= 44 then
        NameM = "Pirate"
        NameQ = "BuggyQuest1"
        LvQ = 1
        CFQ = CFrame.new(-1140.51416015625, 3.4500136375427246, 3902.158203125)
    elseif lvl >= 45 and lvl <= 59 then
        NameM = "Brute"
        NameQ = "BuggyQuest1"
        LvQ = 2
        CFQ = CFrame.new(-877.4066772460938, 13.633481979370117, 4261.064453125)
    elseif lvl >= 60 and lvl <= 74 then
        NameM = "Desert Bandit"
        NameQ = "DesertQuest"
        LvQ = 1
        CFQ = CFrame.new(875.7348022460938, 5.147282123565674, 4485.775390625)
    elseif lvl >= 75 and lvl <= 89 then
        NameM = "Desert Officer"
        NameQ = "DesertQuest"
        LvQ = 2
        CFQ = CFrame.new(1608.4351806640625, -0.09106875956058502, 4461.8984375)
    elseif lvl >= 90 and lvl <= 99 then
        NameM = "Snow Bandit"
        NameQ = "SnowQuest"
        LvQ = 1
        CFQ = CFrame.new(1181.7484130859375, 85.97068786621094, -1318.0391845703125)
    elseif lvl >= 100 and lvl <= 120 then
        NameM = "Snowman"
        NameQ = "SnowQuest"
        LvQ = 2
        CFQ = CFrame.new(1153.3218994140625, 104.47148895263672, -1431.357177734375)
    end
end

-- Function to start the quest
function getQ()
    checkQuest()
    -- Only attempt to start the quest if it is properly set
    if NameQ and LvQ then
        local args = {
            [1] = "StartQuest",
            [2] = NameQ,
            [3] = LvQ
        }
        local success, result = pcall(function()
            return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
        end)
        if not success then
            warn("Error starting quest: " .. tostring(result))
        end
    else
        warn("Quest details not properly set.")
    end
end

-- Function for fast attack
function FastAttack()
    local ReplicatedStorage = game.ReplicatedStorage
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")

    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterAttack"):FireServer(0.5)
    end)
    if not success then
        warn("Error during fast attack: " .. tostring(err))
        return
    end
    
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return end

    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        if enemy:IsA("Model") and enemy:FindFirstChild("Head") then
            local head = enemy:FindFirstChild("Head")
            local humanoid = enemy:FindFirstChild("Humanoid")
            if head and humanoid then
                local distance = (head.Position - rootPart.Position).Magnitude
                if distance <= 60 then
                    -- Ensure that we properly handle the hit registration and hidden state of the head
                    pcall(function()
                        head:SetAttribute("Hidden", true)
                    end)
                    success, err = pcall(function()
                        ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterHit"):FireServer(enemy.Head)
                    end)
                    if not success then
                        warn("Error during RegisterHit: " .. tostring(err))
                        return
                    end
                end
            end
        end
    end
end

-- Function to bring mob to a specified position
function BringMob(PosMon)
    checkQuest()
    if workspace.Enemies then
        for _, v in pairs(workspace.Enemies:GetChildren()) do
            if v.Name == NameM and v:FindFirstChild("HumanoidRootPart") then
                local humanoid = v:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    v.HumanoidRootPart.CanCollide = false
                    v.HumanoidRootPart.CFrame = PosMon                                                          
                end
            end  
        end
    else
        warn("Enemies folder not found in workspace.")
    end
end

-- Function to randomly buy or equip a fruit
function randomFruit()
    local fruits = {"Cousin"}  -- Example fruits list
    local actions = {"Buy", "Equip"}  -- Example actions

    local selectedFruit = fruits[math.random(1, #fruits)]
    local selectedAction = actions[math.random(1, #actions)]

    -- Display the chosen action and fruit
    print("Executing action: " .. selectedAction .. " on fruit: " .. selectedFruit)

    local args = {selectedFruit, selectedAction}
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:WaitForChild("Remotes")
    local commF = remotes:WaitForChild("CommF_")

    local success, result = pcall(function()
        return commF:InvokeServer(unpack(args))
    end)

    if success then
        print("Success! Result: " .. tostring(result))
    else
        warn("Error invoking server: " .. tostring(result))
    end
end

-- Global variable for auto farm
_G.AutoFarm = true

-- Main farming loop
while task.wait() do
    pcall(function()
        if _G.AutoFarm then
            -- Kiểm tra và thực hiện quest
            if game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible == false then
                checkQuest()
                TP(CFQ)
                getQ()
            elseif game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible == true then
                checkQuest()
                if game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text:find(NameM) then
                    -- Tấn công và đưa kẻ thù đến vị trí
                    if workspace.Enemies:FindFirstChild(NameM) then
                        for _, v in pairs(workspace.Enemies:GetChildren()) do
                            if v.Name == NameM then
                                if v.Humanoid.Health > 0 then
                                    if v:FindFirstChild("HumanoidRootPart") then
                                        repeat
                                            task.wait(0.01)
                                            BringMob(v.HumanoidRootPart.CFrame)
                                            TP(v.HumanoidRootPart.CFrame * CFrame.new(0, 10, 0))
                                            FastAttack()
                                        until not _G.AutoFarm or v.Humanoid.Health <= 0
                                    end
                                end  
                            end
                        end
                    end
                else
                    local args = {
                        [1] = "AbandonQuest"
                    }
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
                end
            end
            -- Random fruit action every 5 seconds
            randomFruit()
        end
    end)
end
