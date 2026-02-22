local Config = {
    EnableQuest = getgenv().kaitun.Enable,
    EnableMotherBear = true,
    EnableBlackBear = true,
    MotherBearStopQuest = "Seven To Seven",
    FarmDuration = 30,
    MaxTokensPerScan = 20,
    EnableGearUpgrade = true,
    EnableAutoEgg = true,
    EnableAutoSell = true,
    TweenSpeed = tonumber(getgenv().kaitun.TweenSpeed) or 50,
    WalkSpeed = tonumber(getgenv().kaitun.WalkSpeed) or 60,
    SellTimeout = 90,
    MobDetectRange = 25,
    EnableMobAvoidance = true,
    EnableStarJelly = getgenv().kaitun.Sticker,
    FarmField = nil,
    FpsBoost = getgenv().kaitun.FpsBoost,
}

repeat
    task.wait()
until game:IsLoaded()

local RS = game:GetService("ReplicatedStorage")
local SC = require(RS:WaitForChild("ClientStatCache"))
local Plr = game:GetService("Players")
local Lplr = Plr.LocalPlayer
local env = RS:WaitForChild("Events")
local Run = game:GetService("RunService")
local TS = game:GetService("TweenService")
local plr = Lplr
local Collector = require(RS.Collectors)
local EggModule = require(RS.ItemPackages.Eggs)
repeat task.wait() until plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
repeat task.wait() until plr.PlayerGui:FindFirstChild("ScreenGui")


TokenManager = {}
AutoDig = {}
Tween = {}
ItemManager = {}
HiveManager = {}
NPC = {}
ClickManager = {}
Gear = {}
Stats = {}
MobManager = {}
Quest = {}
Quest._reservedHoney = 0
SellManager = {}

local Config = getgenv().Config

local GetStats = function()
    local i, v = pcall(function()
        return SC:Get()
    end)
    return i and v or nil
end

function ItemManager.purchase(category, Type, amount)
    amount = amount or 1
    local i = pcall(function()
        env:WaitForChild("ItemPackageEvent"):InvokeServer("Purchase", {
            ["Type"] = Type,
            ["Category"] = category,
            ["Amount"] = amount,
        })
    end)
    if not i then warn("[Blessed Softworks] Bugging!!!") end
    return i
end

function ItemManager.buyTreat(amount)
    amount = amount or 1
    return ItemManager.purchase("Eggs", "Treat", amount)
end

function ItemManager.buySilverEgg(amount)
    amount = amount or 1
    return ItemManager.purchase("Eggs", "Silver", amount)
end
function ItemManager.buyBasicEgg(amount)
    amount = amount or 1
    return ItemManager.purchase("Eggs", "Basic", amount)
end

function ItemManager.checkPrice(itemName)
    local stats = SC:Get()
    if not stats then return nil end
    local ok, cost = pcall(function()
        return EggModule.GetCost({["Type"] = itemName, ["Amount"] = 1}, stats)
    end)
    if ok and cost then return cost end
    return nil
end

function ItemManager.canAfford(itemName)
    local cost = ItemManager.checkPrice(itemName)
    if not cost then return false end
    if cost.Category == "Honey" then
        local honey = 0
        local cs = Lplr:FindFirstChild("CoreStats")
        if cs and cs:FindFirstChild("Honey") then honey = cs.Honey.Value end
        return honey >= cost.Amount, cost.Amount
    end
    return false, cost.Amount
end

function HiveManager.GetBee()
    if not GetStats then
        warn("[KaiTun] GetStats not initialized yet")
        return {}
    end
    local stats = GetStats()
    if not stats then return {} end

    local bees = {}
    local honeycomb = stats.Honeycomb

    if type(honeycomb) == "table" then
        for xKey, yData in pairs(honeycomb) do
            if type(yData) == "table" then
                for yKey, beeData in pairs(yData) do
                    if type(beeData) == "table" and beeData.Type then
                        local xStr = tostring(xKey)
                        local yStr = tostring(yKey)
                        local xNum = tonumber(xStr:match("%d+"))
                        local yNum = tonumber(yStr:match("%d+"))
                        table.insert(bees, {
                            X = xNum or 1,
                            Y = yNum or 1,
                            Type = beeData.Type,
                            Level = beeData.Lvl or beeData.Level or 1,
                            Gifted = beeData.Gifted or false,
                            Rarity = beeData.Rarity or "Common",
                        })
                    end
                end
            end
        end
    end

    table.sort(bees, function(a, b)
        return a.Level > b.Level
    end)

    return bees
end

function HiveManager.placeBasicEgg(col, row, amount)
    amount = amount or 1
    HiveManager.PlaceEgg(col, row, "Basic", amount)
end

function HiveManager.getEmptySlot()
    local stats = SC:Get()
    if not stats or not stats.Honeycomb then return nil, nil end
    for x = 1, 6 do
        for y = 1, 6 do
            local xKey = "x" .. x
            local yKey = "y" .. y
            if not stats.Honeycomb[xKey] or not stats.Honeycomb[xKey][yKey]
                or not stats.Honeycomb[xKey][yKey].Type then
                return x, y
            end
        end
    end
    return nil, nil
end

function HiveManager.buyAndPlaceBasicEgg()
    local canBuy = ItemManager.canAfford("Basic")
    if not canBuy then return false end
    local x, y = HiveManager.getEmptySlot()
    if not x then return false end
    ItemManager.buyBasicEgg(1)
    task.wait(0.5)
    HiveManager.PlaceEgg(x, y, "Basic", 1)
    task.wait(0.5)
    return true
end
function HiveManager.GetPlayerHive()
    local honeycombs = workspace:FindFirstChild("Honeycombs")
    if not honeycombs then return nil end

    for _, hive in pairs(honeycombs:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and (owner.Value == plr or owner.Value == plr.Name) then
            return hive
        end
    end

    return nil
end

function HiveManager.BeesCount()
    local bees = HiveManager.GetBee()
    local total = #bees

    if total == 0 then
        print(" [!] Not Found")
    else
        for i, bee in ipairs(bees) do
            local giftedText = bee.Gifted and "★ GIFTED" or "  Normal"
            print(string.format(
                "#%02d  | %-18s | Lv.%-5d | %-10s | [%d,%d]",
                i,
                bee.Type,
                bee.Level,
                giftedText,
                bee.X,
                bee.Y
            ))
        end
    end

    if total > 0 then
        print(string.format(
            " >> Highest Level: %d | Lowest Level: %d",
            bees[1].Level,
            bees[total].Level
        ))
    end
end

function HiveManager.PlaceEgg(col, row, eggType, amount)
    amount = amount or 1
    pcall(function()
        env:WaitForChild("ConstructHiveCellFromEgg"):InvokeServer(col, row, eggType, amount, false)
    end)
end

function HiveManager.Feed(x, y, itemType, amount)
    amount = amount or 1

    local ok, v1, v2, v3, v4, v5 = pcall(function()
        return env:WaitForChild("ConstructHiveCellFromEgg"):InvokeServer(x, y, itemType, amount, false)
    end)

    if not ok then
        warn("[Blessed Softworks] Bugging!!!")
        return false
    end

    if v2 then
        pcall(function()
            SC:Set({ "Eggs", itemType }, v1)
            if v4 then SC:Set({ "DiscoveredBees" }, v4) end
            if v3 then SC:Set({ "Honeycomb" }, v3) end
            if v5 then SC:Set({ "Totals", "EggUses" }, v5) end
        end)
        return true
    else
        warn("[Blessed Softworks] Bugging!!!")
        return false
    end
end
function HiveManager.getMaxBeeLevel()
    local bees = HiveManager.GetBee()
    if #bees == 0 then return 1 end
    return bees[1].Level
end

function HiveManager.claimHive()
    if HiveManager.GetPlayerHive() then return end
    repeat
        task.wait(1)
        local honeycombs = workspace:FindFirstChild("Honeycombs")
        if honeycombs then
            local pos, id
            for _, v in pairs(honeycombs:GetChildren()) do
                if v:FindFirstChild("Owner") and v.Owner.Value == nil then
                    if v:FindFirstChild("SpawnPos") then pos = v.SpawnPos.Value end
                    if v:FindFirstChild("HiveID") then id = v.HiveID.Value end
                    break
                end
            end
            if pos and id then
                Tween.tweenTo(CFrame.new(pos.Position))
                task.wait(1)
                pcall(function()
                    RS.Events.ClaimHive:FireServer(id)
                end)
                task.wait(1)
            end
        end
    until HiveManager.GetPlayerHive()
end
function NPC.alert(npcName)
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return false end
    local npc = npcs:FindFirstChild(npcName)
    if not npc then return false end
    local i, v = pcall(function()
        return npc.Platform.AlertPos.AlertGui.ImageLabel.ImageTransparency == 0
    end)
    return i and v
end

function NPC.talkTo(npcName)
    local npcFolder = workspace:FindFirstChild("NPCs")
    local npc = npcFolder and npcFolder:FindFirstChild(npcName)
    if not npc then
        warn("Bugging!!!" .. npcName)
        return false
    end

    local ok = pcall(function()
        local npcModule = require(game.ReplicatedStorage.Activatables.NPCs)
        npcModule.ButtonEffect(plr, npc)
    end)
    if not ok then return false end

    local dialogTimeout = tick()
    repeat
        task.wait(0.1)
    until (function()
            local guiOk, visible = pcall(function()
                return plr.PlayerGui.ScreenGui.NPC.Visible
            end)
            return (guiOk and not visible) or (tick() - dialogTimeout > 15)
        end)()

    task.wait(1)
    return true
end

function NPC.goAndAccept(npcName)
    if Tween then
        Tween.moveToNPC(npcName)
    end
    task.wait(1)
    NPC.talkTo(npcName)
    task.wait(1)
end

function NPC.goAndTurnIn(npcName, questName)
    if Tween then
        Tween.moveToNPC(npcName)
    end
    task.wait(1)
    NPC.talkTo(npcName)
    task.wait(1)

    if NPC.alert(npcName) then
        task.wait(1)
        NPC.talkTo(npcName)
        task.wait(1)
    end
end

local function createTweenFloat()
    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
        if not plr.Character.HumanoidRootPart:FindFirstChild("KaiTunFloat") then
            local bv = Instance.new("BodyVelocity")
            bv.Parent = plr.Character.HumanoidRootPart
            bv.Name = "KaiTunFloat"
            bv.MaxForce = Vector3.new(0, 100000, 0)
            bv.Velocity = Vector3.new(0, 0, 0)
        end
    end
end

local KaiTunNoClip = false

Run.Stepped:Connect(function()
    if KaiTunNoClip and plr.Character then
        createTweenFloat()
        for _, v in pairs(plr.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    else
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local f = plr.Character.HumanoidRootPart:FindFirstChild("KaiTunFloat")
            if f then f:Destroy() end
        end
    end
    pcall(function()
        local npcGui = plr.PlayerGui:FindFirstChild("ScreenGui")
        if npcGui then
            local npcFrame = npcGui:FindFirstChild("NPC")
            if npcFrame and npcFrame.Visible == true then
                local cam = plr.PlayerGui:FindFirstChild("Camera")
                if cam then
                    local controllers = cam:FindFirstChild("Controllers")
                    if controllers then
                        local npcController = controllers:FindFirstChild("NPC")
                        if npcController then
                            local incr = npcController:FindFirstChild("IncrementDialogue")
                            if incr then
                                incr:Invoke()
                            end
                        end
                    end
                end
            end
        end
    end)
end)

function Tween.tweenTo(targetCFrame)
    if not (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")) then return end
    KaiTunNoClip = true
    local root = plr.Character.HumanoidRootPart
    local distance = (targetCFrame.Position - root.Position).Magnitude

    if distance <= 50 then
        root.CFrame = targetCFrame
    else
        local speed = Config.TweenSpeed or 100
        local tween = TS:Create(
            root,
            TweenInfo.new(distance / speed, Enum.EasingStyle.Linear),
            { CFrame = targetCFrame }
        )
        tween:Play()
        tween.Completed:Wait()
    end
    KaiTunNoClip = false
end



function Tween.moveToField(fieldName)
    local zones = workspace:FindFirstChild("FlowerZones")
    if not zones then return false end
    local field = zones:FindFirstChild(fieldName)
    if field then
        Tween.tweenTo(field.CFrame)
        return true
    end
    return false
end

function Tween.moveToNPC(npcName)
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return false end
    local npc = npcs:FindFirstChild(npcName)
    if not npc then return false end

    if npc:FindFirstChild("Platform") then
        local pos = npc.Platform.Position
        Tween.tweenTo(CFrame.new(pos.X, pos.Y + 5, pos.Z))
        return true
    else
        local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
        if hrp then
            Tween.tweenTo(hrp.CFrame * CFrame.new(0, 0, -5))
            return true
        end
    end
    return false
end

ClickManager._lastDigTime = 0
AutoDig._lastDigTime = 0

AutoDig._scoopAnim = Instance.new("Animation")
AutoDig._scoopAnim.AnimationId = "http://www.roblox.com/asset/?id=522635514"

function AutoDig.getEquippedTool()
    local stats = GetStats()
    return stats and (stats.EquippedCollector or "None") or "None"
end

function AutoDig.getCooldown()
    local stats = SC:Get()
    if not stats then return nil end

    local toolName = stats.EquippedCollector
    if not toolName or toolName == "None" then return nil end

    local cd = Collector.GetStat(toolName, "Cooldown")
    if not cd then return nil end

    local speedMult = (stats.Transient and stats.Transient.CollectorSpeed) or 1
    if speedMult ~= 1 then
        cd = cd / speedMult
    end
    return cd
end

function AutoDig.isBackpackFull()
    local coreStats = Lplr:WaitForChild("CoreStats", 1)
    if not coreStats then return false end
    local pollen = coreStats:FindFirstChild("Pollen")
    local capacity = coreStats:FindFirstChild("Capacity")
    if pollen and capacity then
        return not (capacity.Value > pollen.Value)
    end
    return false
end

function AutoDig.getPollen()
    local coreStats = Lplr:FindFirstChild("CoreStats")
    if coreStats and coreStats:FindFirstChild("Pollen") then
        return coreStats.Pollen.Value
    end
    return 0
end

function AutoDig.dig()
    if AutoDig.getEquippedTool() == "None" then return end
    local cd = AutoDig.getCooldown() or 0
    local now = time()
    if now - AutoDig._lastDigTime < cd then return end
    AutoDig._lastDigTime = now

    pcall(function()
        local humanoid = Lplr.Character and Lplr.Character:FindFirstChild("Humanoid")
        if humanoid then
            local track = humanoid:LoadAnimation(AutoDig._scoopAnim)
            track:Play()
        end
    end)

    require(RS.Events).ClientCall("ToolCollect")
end

function AutoDig.digFor(seconds)
    local startTime = tick()
    while tick() - startTime < seconds do
        if AutoDig.isBackpackFull() then return "backpack_full" end
        AutoDig.dig()
        task.wait(0.05)
    end
    return "timeout"
end

function AutoDig.digUntilFull(maxSeconds)
    maxSeconds = maxSeconds or 300
    local startTime = tick()
    while tick() - startTime < maxSeconds do
        if AutoDig.isBackpackFull() then return true end
        AutoDig.dig()
        task.wait(0.05)
    end
    return AutoDig.isBackpackFull()
end
local function getHoney()
    local ok, val = pcall(function()
        return Lplr:FindFirstChild("CoreStats") and Lplr.CoreStats:FindFirstChild("Honey") and Lplr.CoreStats.Honey.Value
    end)
    if ok and val then return val end
    local stats = GetStats()
    if stats and stats.Honey then return stats.Honey end
    return 0
end
Gear.ToolOrder = {
    { name = "Scooper", cost = 0 },
    { name = "Rake", cost = 800 },
    { name = "Clippers", cost = 2200 },
    { name = "Magnet", cost = 5500 },
    { name = "Vacuum", cost = 14000 },
    { name = "Super-Scooper", cost = 40000 },
    { name = "Pulsar", cost = 125000 },
    { name = "Electro-Magnet", cost = 300000 },
    { name = "Scissors", cost = 850000 },
    { name = "Honey Dipper", cost = 1500000 },
    { name = "Scythe", cost = 3500000 },
    { name = "Bubble Wand", cost = 3500000 },
}

Gear.BackpackOrder = {
    { name = "Pouch", cost = 0 },
    { name = "Jar", cost = 650 },
    { name = "Backpack", cost = 5500 },
    { name = "Canister", cost = 22000 },
    { name = "Mega-Jug", cost = 50000 },
    { name = "Compressor", cost = 160000 },
    { name = "Elite Barrel", cost = 650000 },
    { name = "Port-O-Hive", cost = 1250000 },
    { name = "Porcelain Port-O-Hive", cost = 250000000 },
}

function Gear.getCurrentGear()
    -- Force fresh stats so we never use stale cache
    local stats
    if Stats and Stats.forceRefresh then
        stats = Stats.forceRefresh()
    end
    if not stats then
        stats = GetStats()
    end
    if not stats then
        warn("[Gear] getCurrentGear: stats is nil!")
        return "Scooper", "Pouch", { "Scooper" }, { "Pouch" }
    end

    local tool = stats.EquippedCollector or "Scooper"
    local bag = stats.EquippedBackpack or "Pouch"

    -- Debug: print raw stats values
    local backpacksStr = "nil"
    if stats.Backpacks then
        local parts = {}
        for k, v in pairs(stats.Backpacks) do
            table.insert(parts, tostring(k) .. "=" .. tostring(v))
        end
        backpacksStr = "{" .. table.concat(parts, ", ") .. "}"
    end
    local collectorsStr = "nil"
    if stats.Collectors then
        local parts = {}
        for k, v in pairs(stats.Collectors) do
            table.insert(parts, tostring(k) .. "=" .. tostring(v))
        end
        collectorsStr = "{" .. table.concat(parts, ", ") .. "}"
    end
    print("[Gear] Raw Stats => EquippedCollector: " .. tostring(stats.EquippedCollector) .. " | EquippedBackpack: " .. tostring(stats.EquippedBackpack))
    print("[Gear] Raw Stats => Backpacks: " .. backpacksStr .. " | Collectors: " .. collectorsStr)

    local function deriveOwned(orderList, equippedName, serverList)
        local equippedIdx = 1
        for i, item in ipairs(orderList) do
            if item.name == equippedName then
                equippedIdx = i
                break
            end
        end

        local highestServerIdx = 0
        if type(serverList) == "table" then
            for _, ownedName in pairs(serverList) do
                for i, item in ipairs(orderList) do
                    if item.name == ownedName and i > highestServerIdx then
                        highestServerIdx = i
                    end
                end
            end
        end

        local highest = math.max(equippedIdx, highestServerIdx)
        local owned = {}
        for i = 1, highest do
            table.insert(owned, orderList[i].name)
        end
        return owned
    end

    local ownedTools = deriveOwned(Gear.ToolOrder, tool, stats.Collectors)
    local ownedBags = deriveOwned(Gear.BackpackOrder, bag, stats.Backpacks)

    return tool, bag, ownedTools, ownedBags
end

function Gear.findHighestOwnedIndex(orderList, ownedList)
    local ownedSet = {}
    for _, name in ipairs(ownedList) do
        ownedSet[name] = true
    end

    local highest = 1
    for i, item in ipairs(orderList) do
        if ownedSet[item.name] then
            highest = i
        end
    end
    return highest
end

local function equipIfNeeded(category, itemName, currentEquipped)
    if currentEquipped == itemName then return end
    pcall(function()
        env:WaitForChild("ItemPackageEvent"):InvokeServer("Equip", {
            Type = itemName,
            Category = category,
            Mute = false
        })
    end)
    task.wait(1)
end

function Gear.tryUpgradeTool()
    local currentTool, _, ownedTools = Gear.getCurrentGear()
    local highestIdx = Gear.findHighestOwnedIndex(Gear.ToolOrder, ownedTools)
    local highestName = Gear.ToolOrder[highestIdx].name

    equipIfNeeded("Collector", highestName, currentTool)

    local nextIdx = highestIdx + 1
    if nextIdx > #Gear.ToolOrder then return false end

    local nextTool = Gear.ToolOrder[nextIdx]
    local honey = getHoney()
    local reserved = Quest._reservedHoney or 0
    local available = honey - reserved

    if available >= nextTool.cost then
        print("[Gear] Buying tool: " .. nextTool.name .. " | Cost: " .. nextTool.cost .. " | Honey: " .. honey)
        local ok, err = pcall(function()
            env:WaitForChild("ItemPackageEvent"):InvokeServer("Purchase", {
                ["Type"] = nextTool.name,
                ["Category"] = "Collector",
            })
        end)
        if not ok then warn("[Gear] Purchase tool failed: " .. tostring(err)) end
        task.wait(1)

        -- Re-equip trick: equip Scooper first, then equip target
        print("[Gear] Re-equip trick: Scooper -> " .. nextTool.name)
        pcall(function()
            env:WaitForChild("ItemPackageEvent"):InvokeServer("Equip", {
                ["Mute"] = true,
                ["Type"] = "Scooper",
                ["Category"] = "Collector",
            })
        end)
        task.wait(1)

        local ok2, err2 = pcall(function()
            env:WaitForChild("ItemPackageEvent"):InvokeServer("Equip", {
                ["Mute"] = false,
                ["Type"] = nextTool.name,
                ["Category"] = "Collector",
            })
        end)
        if not ok2 then warn("[Gear] Equip tool failed: " .. tostring(err2)) end
        task.wait(2)

        if Stats and Stats.forceRefresh then Stats.forceRefresh() end

        local _, _, newOwned = Gear.getCurrentGear()
        local newIdx = Gear.findHighestOwnedIndex(Gear.ToolOrder, newOwned)
        if newIdx >= nextIdx then
            print("[Gear] Tool upgraded to: " .. nextTool.name)
            return true
        else
            warn("[Gear] Tool purchase may have failed for: " .. nextTool.name)
        end
    end

    return false
end

function Gear.tryUpgradeBackpack()
    local _, currentBag, _, ownedBags = Gear.getCurrentGear()
    local highestIdx = Gear.findHighestOwnedIndex(Gear.BackpackOrder, ownedBags)
    local highestName = Gear.BackpackOrder[highestIdx].name

    equipIfNeeded("Accessory", highestName, currentBag)

    local nextIdx = highestIdx + 1
    if nextIdx > #Gear.BackpackOrder then return false end

    local nextBag = Gear.BackpackOrder[nextIdx]
    local honey = getHoney()
    local reserved = Quest._reservedHoney or 0
    local available = honey - reserved

    if available >= nextBag.cost then
        print("[Gear] Buying bag: " .. nextBag.name .. " | Cost: " .. nextBag.cost .. " | Honey: " .. honey)

        -- Fire remote exactly as remote spy shows
        local IPE = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("ItemPackageEvent")

        local ok, err = pcall(function()
            IPE:InvokeServer("Purchase", {
                ["Category"] = "Accessory",
                ["Type"] = nextBag.name,
            })
        end)
        if ok then
            print("[Gear] Purchase bag remote fired: " .. nextBag.name)
        else
            warn("[Gear] Purchase bag failed: " .. tostring(err))
        end
        task.wait(2)

        pcall(function()
            IPE:InvokeServer("Equip", {
                ["Category"] = "Accessory",
                ["Type"] = "Pouch",
                ["Mute"] = true,
            })
        end)
        task.wait(1)

        local ok2, err2 = pcall(function()
            IPE:InvokeServer("Equip", {
                ["Category"] = "Accessory",
                ["Type"] = nextBag.name,
                ["Mute"] = false,
            })
        end)
        if not ok2 then warn("[Gear] Equip bag failed: " .. tostring(err2)) end
        task.wait(2)

        -- Force refresh stats after purchase
        if Stats and Stats.forceRefresh then Stats.forceRefresh() end

        local _, _, _, newOwned = Gear.getCurrentGear()
        local newIdx = Gear.findHighestOwnedIndex(Gear.BackpackOrder, newOwned)
        if newIdx >= nextIdx then
            print("[Gear] Bag upgraded to: " .. nextBag.name)
            return true
        else
            warn("[Gear] Bag purchase may have failed for: " .. nextBag.name)
        end
    end

    return false
end

function Gear.upgradeAll()
    local currentTool, currentBag, ownedTools, ownedBags = Gear.getCurrentGear()
    local honey = getHoney()
    local reserved = Quest._reservedHoney or 0
    local available = honey - reserved

    print("[Gear] Honey: " .. tostring(honey) .. " | Reserved: " .. tostring(reserved) .. " | Available: " .. tostring(available))
    print("[Gear] Current Tool: " .. tostring(currentTool) .. " | Current Bag: " .. tostring(currentBag))

    local bagIdx = Gear.findHighestOwnedIndex(Gear.BackpackOrder, ownedBags)
    equipIfNeeded("Accessory", Gear.BackpackOrder[bagIdx].name, currentBag)

    local toolIdx = Gear.findHighestOwnedIndex(Gear.ToolOrder, ownedTools)
    equipIfNeeded("Collector", Gear.ToolOrder[toolIdx].name, currentTool)

    local nextBagIdx = bagIdx + 1
    if nextBagIdx <= #Gear.BackpackOrder then
        print("[Gear] Next Bag: " .. Gear.BackpackOrder[nextBagIdx].name .. " | Cost: " .. Gear.BackpackOrder[nextBagIdx].cost)
    end
    local nextToolIdx = toolIdx + 1
    if nextToolIdx <= #Gear.ToolOrder then
        print("[Gear] Next Tool: " .. Gear.ToolOrder[nextToolIdx].name .. " | Cost: " .. Gear.ToolOrder[nextToolIdx].cost)
    end

    local upgraded = false

    while Gear.tryUpgradeBackpack() do
        upgraded = true
        print("[Gear] Upgraded backpack!")
        task.wait(0.3)
    end

    while Gear.tryUpgradeTool() do
        upgraded = true
        print("[Gear] Upgraded tool!")
        task.wait(0.3)
    end

    return upgraded
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local QuestsModule = require(ReplicatedStorage.Quests)
local NPCsModule = require(ReplicatedStorage.NPCs)

Quest = Quest or {}

local function getStats()
    return GetStats()
end

local function forceRefreshStats()
end

local function getItemCount(itemName)
    local stats = getStats()
    if not stats or not stats.Eggs then return 0 end
    return stats.Eggs[itemName] or 0
end

local function getHoney()
    local ok, val = pcall(function()
        return plr:FindFirstChild("CoreStats") and plr.CoreStats:FindFirstChild("Honey") and plr.CoreStats.Honey.Value
    end)
    if ok and val then return val end
    local stats = getStats()
    if stats and stats.Honey then return stats.Honey end
    return 0
end

local function moveToField(fieldName)
    if Tween then
        Tween.moveToField(fieldName)
    end
end

local function moveToNPC(npcName)
    if Tween then
        Tween.moveToNPC(npcName)
    end
end

local function hasNPCAlert(npcName)
    if NPC then
        return NPC.alert(npcName)
    end
    return false
end

local function talkToNPC(npcName)
    if NPC then
        return NPC.talkTo(npcName)
    end
    return false
end

local function feedBee(x, y, itemType, amount)
    if HiveManager and HiveManager.Feed then
        return HiveManager.Feed(x, y, itemType, amount)
    end
    return false
end

local function buyTreat(amount)
    if ItemManager and ItemManager.buyTreat then
        ItemManager.buyTreat(amount)
    end
end

local function countBeesAtLevel(minLevel)
    if not HiveManager or not HiveManager.GetBee then return 0 end
    local bees = HiveManager.GetBee()
    local count = 0
    for _, bee in ipairs(bees) do
        if bee.Level >= minLevel then
            count = count + 1
        end
    end
    return count
end

local function getTopBees(count)
    if not HiveManager or not HiveManager.GetBee then return {} end
    local bees = HiveManager.GetBee()
    table.sort(bees, function(a, b)
        return a.Level > b.Level
    end)
    local result = {}
    for i = 1, math.min(count or 7, #bees) do
        table.insert(result, bees[i])
    end
    return result
end

local function getBeeCount()
    local bees = HiveManager.GetBee()
    return #bees
end

Quest.FieldTiers = {
    {min = 0,  Red = "Mushroom Field",     Blue = "Sunflower Field",   White = "Sunflower Field"},
    {min = 5,  Red = "Strawberry Field",   Blue = "Bamboo Field",      White = "Bamboo Field"},
    {min = 10, Red = "Strawberry Field",   Blue = "Bamboo Field",      White = "Pineapple Patch"},
    {min = 15, Red = "Rose Field",         Blue = "Pine Tree Forest",  White = "Pumpkin Patch"},
    {min = 25, Red = "Rose Field",         Blue = "Pine Tree Forest",  White = "Pumpkin Patch"},
    {min = 35, Red = "Pepper Patch",       Blue = "Pine Tree Forest",  White = "Coconut Field"},
}

Quest.FieldColors = {
    ["Sunflower Field"]    = "White",
    ["Dandelion Field"]    = "White",
    ["Spider Field"]       = "White",
    ["Pineapple Patch"]    = "White",
    ["Pumpkin Patch"]      = "White",
    ["Coconut Field"]      = "White",
    ["Blue Flower Field"]  = "Blue",
    ["Bamboo Field"]       = "Blue",
    ["Pine Tree Forest"]   = "Blue",
    ["Stump Field"]        = "Blue",
    ["Mushroom Field"]     = "Red",
    ["Clover Field"]       = "Red",
    ["Strawberry Field"]   = "Red",
    ["Cactus Field"]       = "Red",
    ["Rose Field"]         = "Red",
    ["Pepper Patch"]       = "Red",
    ["Mountain Top Field"] = "Red",
    ["Ant Field"]          = "Red",
}

Quest.MotherBearStopQuest = Config.MotherBearStopQuest or "Seven To Seven"

function Quest.getSmartField(color)
    local bee = getBeeCount()
    local chosen = Quest.FieldTiers[1]
    for _, tier in ipairs(Quest.FieldTiers) do
        if bee >= tier.min then chosen = tier end
    end
    if color == "Red" then return chosen.Red end
    if color == "Blue" then return chosen.Blue end
    return chosen.Blue
end

function Quest.getFieldForQuest(questName)
    local def = nil
    pcall(function() def = QuestsModule:Get(questName) end)
    if not def or not def.Tasks then return Quest.getSmartField("Blue") end

    for _, t in ipairs(def.Tasks) do
        if t.Zone then return t.Zone end
    end
    for _, t in ipairs(def.Tasks) do
        if t.Color then return Quest.getSmartField(t.Color) end
    end
    return Quest.getSmartField("Blue")
end

function Quest.hasItemTask(questName, itemType)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return false, 0 end
    for _, t in ipairs(progress.tasks) do
        if not t.complete then
            local typ = string.lower(t.taskType)
            local desc = string.lower(t.description)
            if string.find(typ, string.lower(itemType)) or string.find(desc, string.lower(itemType)) then
                return true, t.remaining
            end
        end
    end
    return false, 0
end

function Quest.getActiveQuests()
    local stats = getStats()
    if not stats or not stats.Quests then return {} end
    return stats.Quests.Active or {}
end

function Quest.getQuestProgress(questName)
    local stats = getStats()
    if not stats then return nil end

    local ok, progressData = pcall(function()
        return QuestsModule:Progress(questName, stats)
    end)
    if not ok then return nil end

    local questDef = nil
    pcall(function()
        questDef = QuestsModule:Get(questName)
    end)

    local result = { name = questName, tasks = {}, allComplete = true }

    if questDef and questDef.Tasks and progressData then
        for i, taskDef in ipairs(questDef.Tasks) do
            local prog = progressData[i]
            if prog and type(prog) == "table" then
                local percent = math.floor((prog[1] or 0) * 100)
                local current = math.floor(prog[2] or 0)
                local amount = taskDef.Amount or taskDef.Goal or 0
                local remaining = math.max(0, amount - current)
                table.insert(result.tasks, {
                    description = taskDef.Description or taskDef.Type or "Task",
                    taskType   = taskDef.Type or "",
                    taskAmount = amount,
                    remaining  = remaining,
                    percent    = percent,
                    current    = current,
                    complete   = percent >= 100,
                })
                if percent < 100 then
                    result.allComplete = false
                end
            end
        end
    end

    return result
end

function Quest.isQuestComplete(questName)
    local prog = Quest.getQuestProgress(questName)
    return prog and prog.allComplete
end

function Quest.handleTreatTask(questName)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return false, false end

    for _, t in ipairs(progress.tasks) do
        if not t.complete then
            local desc = string.lower(t.description)
            local typ  = string.lower(t.taskType)
            local isTreatFeed = string.find(desc, "treat") or string.find(typ, "feed") or string.find(typ, "treat")
            if isTreatFeed and t.remaining > 0 then
                local have = Stats.getItemCount("Treat")
                if have < t.remaining then
                    local needed = t.remaining - have
                    local treatCost = ItemManager.checkPrice("Treat")
                    if treatCost and treatCost.Category == "Honey" then
                        local totalCost = treatCost.Amount * needed
                        local honey = Stats.getHoney()
                        if honey < totalCost then
                            return false, true
                        end
                    end
                    ItemManager.buyTreat(needed)
                    task.wait(1)
                    have = Stats.getItemCount("Treat")
                end

                if have >= t.remaining then
                    local bees = HiveManager.GetBee()
                    if #bees == 0 then return false, false end
                    local bee = bees[math.random(1, #bees)]
                    HiveManager.Feed(bee.X, bee.Y, "Treat", t.remaining)
                    task.wait(1)
                    return true, false
                end
                return false, true
            end
        end
    end
    return false, false
end

function Quest.handleRoyalJellyTask(questName)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return false, false end

    for _, t in ipairs(progress.tasks) do
        if not t.complete then
            local desc = string.lower(t.description)
            local typ = string.lower(t.taskType)
            local isRJ = string.find(desc, "royal jelly") or string.find(typ, "royal jelly")
            if isRJ and t.remaining > 0 then
                local have = Stats.getItemCount("Royal Jelly")
                if have < t.remaining then
                    local needed = t.remaining - have
                    local rjCost = ItemManager.checkPrice("Royal Jelly")
                    if rjCost and rjCost.Category == "Honey" then
                        local totalCost = rjCost.Amount * needed
                        local honey = Stats.getHoney()
                        if honey < totalCost then
                            return false, true -- need honey
                        end
                    end
                    ItemManager.purchase("Eggs", "Royal Jelly", needed)
                    task.wait(1)
                    have = Stats.getItemCount("Royal Jelly")
                end

                if have >= t.remaining then
                    local bees = HiveManager.GetBee()
                    if #bees == 0 then return false, false end
                    local bee = bees[math.random(1, #bees)]
                    HiveManager.Feed(bee.X, bee.Y, "RoyalJelly", t.remaining)
                    task.wait(1)
                    return true, false
                end
                return false, true
            end
        end
    end
    return false, false
end

function Quest.handleFeedItemTask(questName)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return false end

    for _, t in ipairs(progress.tasks) do
        if not t.complete then
            local typ = string.lower(t.taskType)
            if (string.find(typ, "use items") or string.find(typ, "feed")) and t.remaining > 0 then
                local desc = string.lower(t.description)
                local items = {"Strawberry", "Blueberry", "Pineapple", "SunflowerSeed", "Moon Charm"}
                for _, item in ipairs(items) do
                    if string.find(desc, string.lower(item)) or string.find(typ, string.lower(item)) then
                        local have = Stats.getItemCount(item)
                        if have >= t.remaining then
                            local bees = HiveManager.GetBee()
                            if #bees > 0 then
                                local bee = bees[math.random(1, #bees)]
                                HiveManager.Feed(bee.X, bee.Y, item, t.remaining)
                                task.wait(1)
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

function Quest.getFeedCostForQuest(questName)
    if not questName then return 0 end
    local progress = Quest.getQuestProgress(questName)
    if not progress then return 0 end

    local totalCost = 0
    for _, t in ipairs(progress.tasks) do
        if not t.complete then
            local desc = string.lower(t.description)
            local typ = string.lower(t.taskType)

            local isTreat = string.find(desc, "treat") or string.find(typ, "feed") or string.find(typ, "treat")
            if isTreat and t.remaining > 0 then
                local have = Stats.getItemCount("Treat")
                local need = math.max(0, t.remaining - have)
                if need > 0 then
                    local treatCost = ItemManager.checkPrice("Treat")
                    if treatCost and treatCost.Category == "Honey" then
                        totalCost = totalCost + (treatCost.Amount * need)
                    end
                end
            end

            local isRJ = string.find(desc, "royal jelly") or string.find(typ, "royal jelly")
            if isRJ and t.remaining > 0 then
                local have = Stats.getItemCount("RoyalJelly")
                local need = math.max(0, t.remaining - have)
                if need > 0 then
                    local rjCost = ItemManager.checkPrice("RoyalJelly")
                    if rjCost and rjCost.Category == "Honey" then
                        totalCost = totalCost + (rjCost.Amount * need)
                    end
                end
            end
        end
    end
    return totalCost
end

function Quest.getCurrentQuestOf(npcName)
    local ok, questName = pcall(function()
        local eventIdx, phase = NPCsModule.ResolveEventPhase(npcName)
        if not eventIdx then return nil end
        if phase ~= "Ongoing" and phase ~= "Finish" then return nil end

        local npcData = NPCsModule.Get(npcName)
        if not npcData or not npcData.Events then return nil end

        local event = npcData.Events[eventIdx]
        if not event then return nil end

        if event.Quest then
            return type(event.Quest) == "table" and event.Quest.Name or event.Quest
        end
        return nil
    end)
    return ok and questName or nil
end

function Quest.getNPCPhase(npcName)
    local ok, phase = pcall(function()
        local _, p = NPCsModule.ResolveEventPhase(npcName)
        return p
    end)
    return ok and phase or nil
end

function Quest.hasQuestToAccept(npcName)
    local phase = Quest.getNPCPhase(npcName)
    return phase == "Start"
end

function Quest.executeFarmAction(action)
    local fieldName = action.field or Quest.getSmartField("Blue")
    Quest.doFarmLoop(fieldName, Config.FarmDuration or 30)
end

function Quest.feedItemsAtHive(questName)
    if not questName then return end
    local progress = Quest.getQuestProgress(questName)
    if not progress then return end

    local bees = HiveManager.GetBee()
    if #bees == 0 then return end

    for _, t in ipairs(progress.tasks) do
        if not t.complete and t.remaining > 0 then
            local desc = string.lower(t.description)
            local typ = string.lower(t.taskType)

            local isTreat = string.find(desc, "treat") or string.find(typ, "treat")
            if isTreat then
                local have = Stats.getItemCount("Treat")
                if have > 0 then
                    local amount = math.min(have, t.remaining)
                    local bee = bees[math.random(1, #bees)]
                    print("[Feed] Feeding " .. amount .. " Treat")
                    HiveManager.Feed(bee.X, bee.Y, "Treat", amount)
                    task.wait(1)
                end
            end

            local isRJ = string.find(desc, "royal jelly") or string.find(typ, "royal jelly")
            if isRJ then
                local have = Stats.getItemCount("RoyalJelly")
                if have > 0 then
                    local amount = math.min(have, t.remaining)
                    local bee = bees[math.random(1, #bees)]
                    print("[Feed] Feeding " .. amount .. " RoyalJelly")
                    HiveManager.Feed(bee.X, bee.Y, "RoyalJelly", amount)
                    task.wait(1)
                end
            end

            local items = {
                {name = "Strawberry", remote = "Strawberry"},
                {name = "Blueberry", remote = "Blueberry"},
                {name = "Pineapple", remote = "Pineapple"},
                {name = "Sunflower Seed", remote = "SunflowerSeed"},
                {name = "Moon Charm", remote = "Moon Charm"},
            }
            for _, item in ipairs(items) do
                if string.find(desc, string.lower(item.name)) or string.find(typ, string.lower(item.name)) then
                    local have = Stats.getItemCount(item.name)
                    if have > 0 then
                        local amount = math.min(have, t.remaining)
                        local bee = bees[math.random(1, #bees)]
                        print("[Feed] Feeding " .. amount .. " " .. item.name)
                        HiveManager.Feed(bee.X, bee.Y, item.remote, amount)
                        task.wait(1)
                    end
                end
            end
        end
    end
end

function Quest.completeQuest(npcName, questName)
    if NPC then
        NPC.goAndTurnIn(npcName, questName)
    end
    task.wait(2)
end

function Quest.processQuest(npcName, questName)
    local progress = Quest.getQuestProgress(questName)
    if not progress then return end

    if progress.allComplete then
        Quest.completeQuest(npcName, questName)
        task.wait(2)
        if NPC then
            NPC.goAndAccept(npcName)
        end
        return
    end

    local treated, needHoneyTreat = Quest.handleTreatTask(questName)
    if treated then print("[Quest] Fed treats for: " .. questName) end

    local fedRJ, needHoneyRJ = Quest.handleRoyalJellyTask(questName)
    if fedRJ then print("[Quest] Fed royal jelly for: " .. questName) end

    local fedItem = Quest.handleFeedItemTask(questName)
    if fedItem then print("[Quest] Fed item for: " .. questName) end

    if needHoneyTreat or needHoneyRJ then
        Quest._reservedHoney = Quest.getFeedCostForQuest(questName)
        print("[Quest] Need honey for feed items (reserving " .. Quest._reservedHoney .. ") - farming...")
    end

    local questField = Quest.getFieldForQuest(questName)
    Quest.executeFarmAction({ field = questField })
end

function Quest.isMotherBearDone()
    local ok, result = pcall(function()
        local eventIdx, phase = NPCsModule.ResolveEventPhase("Mother Bear")
        if not eventIdx then return true end 

        local npcData = NPCsModule.Get("Mother Bear")
        if not npcData or not npcData.Events then return false end

        local stopIdx = nil
        for i, event in ipairs(npcData.Events) do
            if event.Quest then
                local qName = type(event.Quest) == "table" and event.Quest.Name or event.Quest
                if qName == Quest.MotherBearStopQuest then
                    stopIdx = i
                    break
                end
            end
        end

        if not stopIdx then return false end

        if eventIdx > stopIdx then return true end

        return false
    end)

    if ok then return result end

    local motherQuest = Quest.getCurrentQuestOf("Mother Bear")
    if not motherQuest and not NPC.alert("Mother Bear") then
        return true
    end
    return false
end

function Quest.determinePhase()
    local motherQuest = Quest.getCurrentQuestOf("Mother Bear")
    local blackBearQuest = Quest.getCurrentQuestOf("Black Bear")

    if Config.EnableMotherBear and motherQuest and not Quest.isMotherBearDone() then
        return "active", motherQuest, "Mother Bear"
    end

    if Config.EnableBlackBear and blackBearQuest then
        return "active", blackBearQuest, "Black Bear"
    end

    if Config.EnableMotherBear and not motherQuest and not Quest.isMotherBearDone() then
        if Quest.hasQuestToAccept("Mother Bear") or NPC.alert("Mother Bear") then
            return "accept_mother", nil, "Mother Bear"
        end
    end

    if Config.EnableBlackBear and not blackBearQuest then
        if Quest.hasQuestToAccept("Black Bear") or NPC.alert("Black Bear") then
            return "accept_black", nil, "Black Bear"
        end
    end

    return "idle", nil, nil
end

function Quest.doFarmLoop(fieldName, duration)
    duration = duration or 30
    while SellManager and SellManager.isSelling do task.wait(0.5) end
    moveToField(fieldName)
    task.wait(1)

    local loopStart = tick()
    while tick() - loopStart < duration do
        if SellManager and SellManager.isSelling then
            task.wait(1)
        elseif Config.EnableMobAvoidance and MobManager.isMobNearby() then
            MobManager.avoidMobs()
            moveToField(fieldName)
            task.wait(0.5)
        else
            if AutoDig then AutoDig.digFor(1.5) end

            local token = TokenManager.findNearestFieldToken(fieldName)
            if token and TokenManager.isToken(token) then
                TokenManager.walkTo(token.Position, token)
                task.wait(0.1)
            else
                local rndPos = TokenManager.getRandomFieldPosition(fieldName)
                if rndPos then
                    TokenManager.walkTo(rndPos)
                end
            end

            if AutoDig then AutoDig.digFor(1) end

            TokenManager.collectTokensInField(Config.MaxTokensPerScan)
        end
    end
end

function Quest.run()
    local statsReady = false
    for attempt = 1, 30 do
        local stats = getStats()
        if stats and stats.Quests then
            statsReady = true
            break
        end
        warn("[Quest] Waiting for stats to load... attempt " .. attempt)
        task.wait(2)
    end

    if not statsReady then
        warn("[Quest] Stats never loaded, starting anyway...")
    end

    print("=== [Quest] Startup - Detecting quests ===")
    local mbQuest = Quest.getCurrentQuestOf("Mother Bear")
    local bbQuest = Quest.getCurrentQuestOf("Black Bear")
    print("[Quest] Mother Bear: " .. tostring(mbQuest or "(none)") .. " | Phase: " .. tostring(Quest.getNPCPhase("Mother Bear")))
    print("[Quest] Black Bear: " .. tostring(bbQuest or "(none)") .. " | Phase: " .. tostring(Quest.getNPCPhase("Black Bear")))
    print("[Quest] Mother Bear done: " .. tostring(Quest.isMotherBearDone()))
    local active = Quest.getActiveQuests()
    for idx, q in pairs(active) do
        local name = type(q) == "table" and q.Name or tostring(q)
        print("[Quest] Raw Active[" .. tostring(idx) .. "] = " .. tostring(name))
    end
    print("=== [Quest] Starting main loop ===")

    while Config.EnableQuest do
        local phase, questName, npcName = Quest.determinePhase()
        print("[Quest] Phase: " .. tostring(phase) .. " | Quest: " .. tostring(questName) .. " | NPC: " .. tostring(npcName))

        Quest._reservedHoney = 0
        local feedCost = 0
        if phase == "active" and questName then
            feedCost = Quest.getFeedCostForQuest(questName)
            local honey = Stats.getHoney()
            if honey >= feedCost and feedCost > 0 then
                Quest._reservedHoney = feedCost
                print("[Quest] Reserving " .. feedCost .. " honey for feed items")
            elseif feedCost > 0 then
                print("[Quest] Can't afford feed cost (" .. feedCost .. "), allowing lower priorities to spend honey")
            end
        end

        if phase == "accept_mother" then
            NPC.goAndAccept("Mother Bear")
            task.wait(2)
            local check = Quest.getCurrentQuestOf("Mother Bear")
            if check then
                print("[Quest] Accepted Mother Bear quest: " .. check)
            else
                warn("[Quest] Failed to accept Mother Bear quest, will retry...")
            end
        elseif phase == "accept_black" then
            NPC.goAndAccept("Black Bear")
            task.wait(2)
            local check = Quest.getCurrentQuestOf("Black Bear")
            if check then
                print("[Quest] Accepted Black Bear quest: " .. check)
            else
                warn("[Quest] Failed to accept Black Bear quest, will retry...")
            end
        elseif phase == "active" and questName then
            Quest.processQuest(npcName, questName)
        else
            Quest._reservedHoney = 0
            local farmField = Config.FarmField or Quest.getSmartField("Blue")
            Quest.doFarmLoop(farmField, Config.FarmDuration or 30)
        end

        if Config.EnableAutoEgg then
            pcall(function()
                local cost = ItemManager.checkPrice("Basic")
                local honey = Stats.getHoney()
                local available = honey - (Quest._reservedHoney or 0)
                if cost and cost.Category == "Honey" and available >= cost.Amount then
                    HiveManager.buyAndPlaceBasicEgg()
                else
                    if Quest._reservedHoney > 0 then
                        print("[Egg] Skipped - honey reserved for feed items")
                    end
                end
            end)
        end

        if Config.EnableGearUpgrade then
            pcall(function() Gear.upgradeAll() end)
        end

        task.wait(3)
    end
end
SellManager = SellManager or {}
SellManager.isSelling = false
SellManager.enabled = Config.EnableAutoSell ~= false

local function getPollen()
    local core = plr:FindFirstChild("CoreStats")
    if core and core:FindFirstChild("Pollen") then
        return core.Pollen.Value
    end
    return 0
end

function SellManager.tpToHive()
    if not (plr:FindFirstChild("SpawnPos") and plr.SpawnPos.Value) then
        return false
    end

    local sp = plr.SpawnPos.Value.Position
    local hiveCF =
        CFrame.new(sp.X, sp.Y, sp.Z, -0.996, 0, 0.02, 0, 1, 0, -0.02, 0, -0.9)
        + Vector3.new(0, 0, 8)

    if Tween and Tween.tweenTo then
        Tween.tweenTo(hiveCF)
        return true
    end

    return false
end

function SellManager.sell()
    if SellManager.isSelling then return false end
    if getPollen() <= 0 then return false end
    if not (plr:FindFirstChild("SpawnPos") and plr.SpawnPos.Value) then
        return false
    end

    SellManager.isSelling = true

    SellManager.tpToHive()
    task.wait(0.3)

    pcall(function()
        Events:WaitForChild("PlayerHiveCommand"):FireServer("ToggleHoneyMaking")
    end)

    local startTime = tick()
    local timeout = Config.SellTimeout

    while tick() - startTime < timeout do
        if getPollen() <= 0 then
            break
        end

        pcall(function()
            local gui = plr:FindFirstChild("PlayerGui")
            if not gui then return end

            local screen = gui:FindFirstChild("ScreenGui")
            if not screen then return end

            local activate = screen:FindFirstChild("ActivateButton")
            if not activate then return end

            if activate.AbsolutePosition.Y ~= 4 then
                Events.PlayerHiveCommand:FireServer("ToggleHoneyMaking")
                SellManager.tpToHive()
                task.wait(0.5)
                return
            end

            local textBox = activate:FindFirstChild("TextBox")
            if textBox then
                local txt = textBox.Text or ""
                if not string.find(txt, "Stop")
                    and not string.find(txt, "Collect")
                    and not string.find(txt, "Talk") then
                    Events.PlayerHiveCommand:FireServer("ToggleHoneyMaking")
                end
            end
        end)

        task.wait(0.2)
    end

    task.wait(1)

    pcall(function()
        local phase, questName = Quest.determinePhase()
        if questName then
            print("[Sell] At hive - checking feed items for: " .. questName)
            Quest.feedItemsAtHive(questName)
        end
    end)

    if Config.EnableGearUpgrade and Gear and Gear.upgradeAll then
        pcall(function()
            Gear.upgradeAll()
        end)
    end

    SellManager.isSelling = false
    return true
end
-- local hive = HiveManager.GetPlayerHive()
-- if hive then
--     local hiveID = hive:FindFirstChild("HiveID") and hive.HiveID.Value
--     local spawnPos = hive:FindFirstChild("SpawnPos") and hive.SpawnPos.Value

--     print("Hive ID:", hiveID or "N/A")
--     print("SpawnPos:", spawnPos or "N/A")
-- end


Stats._cachedStats = nil
Stats._lastStatRefresh = 0

local StatCache = require(ReplicatedStorage:WaitForChild("ClientStatCache"))

function Stats.refresh()
    local ok, stats = pcall(function()
        return Events:WaitForChild("RetrievePlayerStats"):InvokeServer()
    end)

    if ok and stats then
        Stats._cachedStats = stats
        Stats._lastStatRefresh = tick()
        return stats
    end

    return Stats._cachedStats
end

function Stats.get()
    if Stats._cachedStats and (tick() - Stats._lastStatRefresh) < 3 then
        return Stats._cachedStats
    end

    local fresh = Stats.refresh()
    if fresh then return fresh end

    local ok, fallback = pcall(function()
        return StatCache:Get()
    end)

    if ok and fallback then
        return fallback
    end

    return nil
end

function Stats.forceRefresh()
    return Stats.refresh()
end

function Stats.getItemCount(itemName)
    local stats = Stats.get()
    if not stats then return 0 end

    if stats.Eggs and stats.Eggs[itemName] then
        return stats.Eggs[itemName]
    end

    if stats.Items and stats.Items[itemName] then
        return stats.Items[itemName]
    end

    if stats.Inventory and stats.Inventory[itemName] then
        return stats.Inventory[itemName]
    end

    return 0
end

function Stats.getHoney()
    local ok, val = pcall(function()
        return plr:FindFirstChild("CoreStats")
            and plr.CoreStats:FindFirstChild("Honey")
            and plr.CoreStats.Honey.Value
    end)

    if ok and val then
        return val
    end

    local stats = Stats.get()
    if stats and stats.Totals and stats.Totals.Honey then
        return stats.Totals.Honey
    end

    if stats and stats.Honey then
        return stats.Honey
    end

    return 0
end

function Stats.getTickets()
    return Stats.getItemCount("Ticket")
end

function Stats.getPlayerHive()
    local honeycombs = workspace:FindFirstChild("Honeycombs")
    if not honeycombs then return nil end

    for _, hive in pairs(honeycombs:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and (owner.Value == plr or owner.Value == plr.Name) then
            return hive
        end
    end

    return nil
end

GetStats = function()
    return Stats.get()
end

task.spawn(function()
    while true do
        pcall(function()
            Stats.refresh()
        end)
        task.wait(2)
    end
end)

local EggTypes = {"Basic", "Silver", "Gold", "Diamond", "Mythic", "Star"}

task.spawn(function()
    task.wait(5)
    while true do
        pcall(function()
            local stats = SC:Get()
            if not stats or not stats.Eggs then return end
            for _, eggName in ipairs(EggTypes) do
                local count = stats.Eggs[eggName] or 0
                if count > 0 then
                    local x, y = HiveManager.getEmptySlot()
                    if not x then return end
                    print("[Egg] Placing " .. eggName .. " egg at [" .. x .. "," .. y .. "]")
                    HiveManager.PlaceEgg(x, y, eggName, 1)
                    task.wait(1)
                end
            end
        end)
        task.wait(5)
    end
end)

function MobManager.isMobNearby()
    local character = plr.Character
    if not character then return false end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local monsters = workspace:FindFirstChild("Monsters")
    if not monsters then return false end

    for _, mob in ipairs(monsters:GetChildren()) do
        if mob:FindFirstChild("Head")
            and not string.match(mob.Name, "Vici")
            and not string.match(mob.Name, "Windy")
            and not string.match(mob.Name, "Mondo") then

            local targeting = false

            if mob:FindFirstChild("Target")
                and tostring(mob.Target.Value) == plr.Name then
                targeting = true
            end

            if mob:FindFirstChild("KaiTunMobTag") then
                targeting = true
            end

            if targeting then
                local dist = (hrp.Position - mob.Head.Position).Magnitude
                if dist < (Config.MobDetectRange or 50) then
                    if not mob:FindFirstChild("KaiTunMobTag") then
                        local tag = Instance.new("BoolValue")
                        tag.Name = "KaiTunMobTag"
                        tag.Parent = mob
                    end
                    return true
                end
            end
        end
    end

    return false
end

function MobManager.avoidMobs()
    local character = plr.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    if not MobManager.isMobNearby() then return end

    local oldJumpPower = humanoid.JumpPower
    humanoid:MoveTo(humanoid.RootPart.Position)

    local timeout = tick()
    repeat
        task.wait(0.05)
        if plr.Character and plr.Character:FindFirstChild("Humanoid") then
            plr.Character.Humanoid.JumpPower = 80
            plr.Character.Humanoid.Jump = true
        end
    until not MobManager.isMobNearby() or (tick() - timeout > 10)

    if plr.Character and plr.Character:FindFirstChild("Humanoid") and oldJumpPower then
        plr.Character.Humanoid.JumpPower = oldJumpPower
    end
    task.wait(0.1)
end

task.spawn(function()
    while true do
        if Config.EnableMobAvoidance then
            pcall(function()
                if MobManager.isMobNearby() then
                    local hum = plr.Character and plr.Character:FindFirstChild("Humanoid")
                    if hum then
                        hum.Jump = true
                    end
                end
            end)
        end
        task.wait(0.1)
    end
end)


TokenManager.TokenIds = {
    ["Ticket"] = "1674871631",
    ["Glue"] = "2504978518",
    ["Pineapple"] = "1952796032",
    ["Strawberry"] = "1952740625",
    ["Blueberry"] = "2028453802",
    ["SunflowerSeed"] = "1952682401",
    ["Treat"] = "2028574353",
    ["Gumdrop"] = "1838129169",
    ["Red Extract"] = "2495935291",
    ["Blue Extract"] = "2495936060",
    ["Oil"] = "2545746569",
    ["Glitter"] = "2542899798",
    ["Enzymes"] = "2584584968",
    ["TropicalDrink"] = "3835877932",
    ["Diamond Egg"] = "1471850677",
    ["Gold Egg"] = "1471849394",
    ["Mythic Egg"] = "4520739302",
    ["Star Treat"] = "2028603146",
    ["Royal Jelly"] = "1471882621",
    ["Star Jelly"] = "2319943273",
    ["Moon Charm"] = "2306224708",
    ["Super Smoothie"] = "5144657109",
    ["Bitterberry"] = "4483236276",
    ["Festive Bean"] = "4483230719",
    ["Ginger Bread"] = "6077173317",
    ["Honey Token"] = "1472135114",
    ["Purple Potion"] = "4935580111",
    ["Snowflake"] = "6087969886",
    ["Magic Bean"] = "2529092020",
    ["Neonberry"] = "4483267595",
    ["Swirled Wax"] = "8277783113",
    ["Soft Wax"] = "8277778300",
    ["Hard Wax"] = "8277780065",
    ["Caustic Wax"] = "827778166"
}

TokenManager.PrioritizeIds = {
    ["Token Link"] = "1629547638",
    ["Inspire"] = "2000457501",
    ["Bear Morph"] = "177997841",
    ["Pollen Bomb"] = "1442725244",
    ["Fuzz Bomb"] = "4889322534",
    ["Pollen Haze"] = "4889470194",
    ["Triangulate"] = "4519523935",
    ["Inferno"] = "4519549299",
    ["Summon Frog"] = "4528414666",
    ["Tornado"] = "3582519526",
    ["Cross Hair"] = "8173559749",
    ["Red Boost"] = "1442859163",
    ["Inflate Balloon"] = "8083437090"
}

function TokenManager.isToken(obj)
    return obj
        and obj:IsA("Part")
        and obj.Name == "C"
        and obj.Parent
        and obj.Orientation.Z == 0
        and obj:FindFirstChild("FrontDecal")
end

function TokenManager.isPriorityToken(obj)
    if not obj:FindFirstChild("FrontDecal") then return false end
    local texture = obj.FrontDecal.Texture

    for _, id in pairs(TokenManager.PrioritizeIds) do
        if string.find(texture, id) then return true end
    end

    for _, id in pairs(TokenManager.TokenIds) do
        if string.find(texture, id) then return true end
    end

    return false
end

function TokenManager.getNearestField(position)
    local zones = workspace:FindFirstChild("FlowerZones")
    if not zones then return "Sunflower Field" end

    local bestField = "Sunflower Field"
    local bestDist = math.huge

    for _, field in pairs(zones:GetChildren()) do
        if field.Name ~= "PuffField" then
            local dist = (position - field.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestField = field.Name
            end
        end
    end

    return bestField
end

function TokenManager.isTokenInField(token, fieldName)
    local zones = workspace:FindFirstChild("FlowerZones")
    if not zones then return false end

    local field = zones:FindFirstChild(fieldName)
    if not field then return false end

    local range = field:FindFirstChild("Range") and field.Range.Value or 60
    return (token.Position - field.Position).Magnitude < range
end

function TokenManager.moveTo(position)
    local character = plr.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    local Tween = Tween
    if Tween and Tween.tweenTo then
        Tween.tweenTo(CFrame.new(position))
        return
    end

    humanoid:MoveTo(position)
    local start = tick()

    while (hrp.Position - position).Magnitude > 3 and tick() - start < 5 do
        task.wait()
    end

    if (hrp.Position - position).Magnitude > 5 then
        hrp.CFrame = CFrame.new(position)
    end
end

function TokenManager.walkTo(position, tokenRef)
    local character = plr.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    local done = false
    humanoid:MoveTo(position)
    local conn = humanoid.MoveToFinished:Connect(function()
        done = true
    end)
    local start = tick()
    while not done do
        task.wait()
        if tokenRef and not TokenManager.isToken(tokenRef) then
            humanoid:Move(Vector3.new(0, 0, 0))
            conn:Disconnect()
            return
        end
        if tick() - start >= 5 then
            humanoid:Move(Vector3.new(0, 0, 0))
            hrp.CFrame = CFrame.new(position)
            break
        end
    end
    conn:Disconnect()
end

function TokenManager.getFlowerTile(pos)
    local flowers = workspace:FindFirstChild("Flowers")
    if not flowers then return nil end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {flowers}
    rayParams.FilterType = Enum.RaycastFilterType.Include
    local result = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -30, 0), rayParams)
    if result and result.Instance then
        return result.Instance
    end
    return nil
end

function TokenManager.getRandomFieldPosition(fieldName)
    local character = plr.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local tile = TokenManager.getFlowerTile(hrp.Position)
    if not tile then return nil end

    local parts = tile.Name:split("-")
    if #parts < 3 then return nil end
    local field = parts[1]
    local x = tonumber(parts[2])
    local y = tonumber(parts[3])
    if not x or not y then return nil end

    local flowers = workspace:FindFirstChild("Flowers")
    if not flowers then return nil end

    local n = 4
    for _ = 1, 10 do
        local nx = math.random(x - n, x + n)
        local ny = math.random(y - n, y + n)
        local newTile = flowers:FindFirstChild(field .. "-" .. nx .. "-" .. ny)
        if newTile then
            return newTile.Position + Vector3.new(0, 2, 0)
        end
    end
    return nil
end

function TokenManager.findNearestFieldToken(fieldName, maxDist)
    maxDist = maxDist or 80
    local character = plr.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local collectibles = workspace:FindFirstChild("Collectibles")
    if not collectibles then return nil end

    local bestPriority = nil
    local bestNormal = nil
    local bestPriDist = math.huge
    local bestNormDist = math.huge

    for _, obj in pairs(collectibles:GetChildren()) do
        if TokenManager.isToken(obj) and TokenManager.isTokenInField(obj, fieldName) then
            local dist = (obj.Position - hrp.Position).Magnitude
            if dist <= maxDist then
                if TokenManager.isPriorityToken(obj) then
                    if dist < bestPriDist then
                        bestPriority = obj
                        bestPriDist = dist
                    end
                else
                    if dist < bestNormDist then
                        bestNormal = obj
                        bestNormDist = dist
                    end
                end
            end
        end
    end

    return bestPriority or bestNormal
end

function TokenManager.collectTokensInField(maxTokens)
    maxTokens = maxTokens or Config.MaxTokensPerScan

    local character = plr.Character
    if not character then return 0 end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end

    local collectibles = workspace:FindFirstChild("Collectibles")
    if not collectibles then return 0 end

    local currentField = TokenManager.getNearestField(hrp.Position)
    local tokens = {}

    for _, obj in pairs(collectibles:GetChildren()) do
        if TokenManager.isToken(obj)
            and TokenManager.isTokenInField(obj, currentField) then

            table.insert(tokens, {
                obj = obj,
                dist = (obj.Position - hrp.Position).Magnitude,
                priority = TokenManager.isPriorityToken(obj)
            })
        end
    end

    table.sort(tokens, function(a, b)
        if a.priority ~= b.priority then
            return a.priority
        end
        return a.dist < b.dist
    end)

    local collected = 0

    for _, data in ipairs(tokens) do
        if collected >= maxTokens then break end

        local obj = data.obj
        if obj.Parent and TokenManager.isToken(obj) then
            TokenManager.moveTo(obj.Position)
            collected += 1
            task.wait(0.1)
        end
    end

    return collected
end

function TokenManager.collectHiveTokens()
    local hive = HiveManager.GetPlayerHive()
    if not hive then return 0 end
    local spawnPos = hive:FindFirstChild("SpawnPos") and hive.SpawnPos.Value
    if not spawnPos then return 0 end
    local hivePos = spawnPos.Position

    local collectibles = workspace:FindFirstChild("Collectibles")
    if not collectibles then return 0 end

    local tokens = {}
    for _, obj in pairs(collectibles:GetChildren()) do
        if TokenManager.isToken(obj) and (obj.Position - hivePos).Magnitude <= 40 then
            table.insert(tokens, {
                obj      = obj,
                dist     = (obj.Position - hivePos).Magnitude,
                priority = TokenManager.isPriorityToken(obj),
            })
        end
    end

    table.sort(tokens, function(a, b)
        if a.priority ~= b.priority then return a.priority end
        return a.dist < b.dist
    end)

    local collected = 0
    for _, data in ipairs(tokens) do
        local obj = data.obj
        if obj.Parent and TokenManager.isToken(obj) then
            Tween.tweenTo(CFrame.new(obj.Position))
            collected += 1
            task.wait(0.1)
        end
    end
    return collected
end

local function getMaxBeeLevel()
    if HiveManager and HiveManager.getMaxBeeLevel then
        return HiveManager.getMaxBeeLevel()
    end
    return 0
end

local function getMonsterLevel(monster)
    if monster:FindFirstChild("Level") then
        return monster.Level.Value
    end

    local humanoid = monster:FindFirstChild("Humanoid")
    if humanoid then
        local hp = humanoid.MaxHealth

        if hp <= 20 then return 1
        elseif hp <= 50 then return 2
        elseif hp <= 100 then return 3
        elseif hp <= 200 then return 4
        elseif hp <= 500 then return 5
        elseif hp <= 1000 then return 6
        elseif hp <= 2000 then return 7
        elseif hp <= 5000 then return 8
        else return 9 end
    end

    return 1
end

function MobManager.canFight(monsterLevel)
    return getMaxBeeLevel() >= monsterLevel
end

function MobManager.shouldEngage(monster)
    if not monster then return false end
    if not monster:FindFirstChild("Humanoid") then return false end
    if monster.Humanoid.Health <= 0 then return false end

    local level = getMonsterLevel(monster)
    return MobManager.canFight(level)
end

function MobManager.scanNearby(range)
    range = range or Config.MobDetectRange

    local character = plr.Character
    if not character then return nil end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local monsters = workspace:FindFirstChild("Monsters")
    if not monsters then return nil end

    for _, monster in pairs(monsters:GetChildren()) do
        if monster:FindFirstChild("Humanoid")
            and monster.Humanoid.Health > 0 then

            local dist = (monster:GetPivot().Position - root.Position).Magnitude
            if dist <= range then
                if MobManager.shouldEngage(monster) then
                    return monster
                end
            end
        end
    end

    return nil
end
task.spawn(function()
    HiveManager.claimHive()
    Quest.run()
end)

task.spawn(function()
    while true do
        if Config.EnableAutoSell and AutoDig.isBackpackFull() then
            SellManager.sell()
        end
        TokenManager.collectHiveTokens()
        task.wait(5)
    end
end) 

