-- ================== ANTI-IDLE ==================
pcall(function()
    local vu = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end)

-- ============= AUTO TELEPORT 1/2/3 (giữ nguyên) =============
local Players=game:GetService("Players")
local lp=Players.LocalPlayer
local function tpTo(cf)
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        lp.Character:SetPrimaryPartCFrame(cf)
    end
end
local function checkTeleporter(obj)
    local g=obj:FindFirstChild("BillboardHolder")
    if g and g:FindFirstChild("BillboardGui") and g.BillboardGui:FindFirstChild("Players") then
        local t=g.BillboardGui.Players.Text
        local x,y=t:match("(%d+)/(%d+)"); x,y=tonumber(x),tonumber(y)
        if x and y and x>=2 then
            local enter=obj:FindFirstChildWhichIsA("BasePart")
            if enter and lp.Character and lp.Character:FindFirstChild("Humanoid") then
                local hrp=lp.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    lp.Character.Humanoid:MoveTo(enter.Position)
                    if (hrp.Position-enter.Position).Magnitude>10 then
                        tpTo(enter.CFrame+Vector3.new(0,3,0))
                    end
                end
            end
        end
    end
end
task.spawn(function()
    while task.wait(0.5) do
        for _,obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
                pcall(checkTeleporter, obj)
            end
        end
    end
end)

-- ===================== CONFIG =====================
local Config = {
    RegionFilterEnabled = false,
    RegionList = {"singapore","tokyo","us-east"},
    MaxPromptTime = 10,
    WaitDiamondTimeout = 20,
    UIScanInterval = 0.2,
    RetryHttpDelay = 2,
    ChestName = "Stronghold Diamond Chest",
    -- NEW ( chống die / kẹt )
    StuckTimeout = 60,           -- nếu 60s không có “tiến triển” -> hop
    PostTeleportGrace = 15,      -- thời gian ân hạn sau khi teleport xong
    JoinTimeout = 45             -- quá 45s chưa có nhân vật/UI -> hop
}

-- ===================== SERVICES =====================
local StarterGui       = game:GetService("StarterGui")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local Replicated       = game:GetService("ReplicatedStorage")

-- có thể chờ sẵn; nếu không tồn tại thì pcall trong lúc dùng
local Remote = nil
pcall(function()
    Remote = Replicated:WaitForChild("RemoteEvents"):WaitForChild("RequestTakeDiamonds", 10)
end)

local Interface, DiamondCount
pcall(function()
    Interface = lp:WaitForChild("PlayerGui", 10) and lp.PlayerGui:WaitForChild("Interface",10)
    DiamondCount = Interface and Interface:WaitForChild("DiamondCount",10):WaitForChild("Count",10)
end)

-- ===================== STATE =====================
local PlaceID = game.PlaceId
local AllIDs = {}
local lastProgress = tick()
local lastTeleportOk = 0
local joinedAt = tick()

local function markProgress(reason)
    lastProgress = tick()
    --print("Progress:", reason)
end
markProgress("init")

local function notify(t)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Notification", Text = tostring(t), Duration = 3 })
    end)
end

-- ===================== UI (nhỏ gọn) =====================
do
    if game.CoreGui:FindFirstChild("DiamondFarmUI") then
        game.CoreGui.DiamondFarmUI:Destroy()
    end
    local a = Instance.new("ScreenGui")
    a.Name = "DiamondFarmUI"
    a.ResetOnSpawn = false
    a.Parent = game.CoreGui

    local frame = Instance.new("Frame", a)
    frame.Size = UDim2.new(0, 240, 0, 110)
    frame.Position = UDim2.new(0, 80, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(35,35,35)
    frame.BorderSizePixel = 0
    frame.Active = true; frame.Draggable = true
    local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, 8)

    local status = Instance.new("TextLabel", frame)
    status.Name="Status"; status.Size = UDim2.new(1,-12,0,28)
    status.Position = UDim2.new(0,6,0,6)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamBold; status.TextSize = 14; status.TextColor3 = Color3.new(1,1,1)
    status.Text = "Status: init..."

    local diamonds = Instance.new("TextLabel", frame)
    diamonds.Name="Diamonds"; diamonds.Size = UDim2.new(1,-12,0,24)
    diamonds.Position = UDim2.new(0,6,0,40)
    diamonds.BackgroundTransparency = 1
    diamonds.Font = Enum.Font.Gotham; diamonds.TextSize = 14; diamonds.TextColor3 = Color3.new(1,1,1)
    diamonds.Text = "Diamonds: ..."

    local info = Instance.new("TextLabel", frame)
    info.Name="Info"; info.Size = UDim2.new(1,-12,0,24)
    info.Position = UDim2.new(0,6,0,66)
    info.BackgroundTransparency = 1
    info.Font = Enum.Font.Gotham; info.TextSize = 13; info.TextColor3 = Color3.fromRGB(200,200,200)
    info.Text = "Watchdog ON"

    task.spawn(function()
        while task.wait(Config.UIScanInterval) do
            pcall(function()
                if DiamondCount and DiamondCount.Text then
                    diamonds.Text = "Diamonds: " .. DiamondCount.Text
                end
                local left = math.max(0, Config.StuckTimeout - math.floor(tick()-lastProgress))
                status.Text = ("Status: alive | reset in ~%ss"):format(left)
            end)
        end
    end)
end

-- ===================== HELPERS =====================
local function regionMatch(entry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(entry.ping or entry.region or ""):lower()
    if raw == "" then return false end
    for _, key in ipairs(Config.RegionList) do
        if string.find(raw, tostring(key):lower(), 1, true) then
            return true
        end
    end
    return false
end

local function fetchPage(cursor)
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100%s")
        :format(PlaceID, (cursor and cursor ~= "") and ("&cursor="..cursor) or "")
    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok then return nil end
    return data
end

local function hopNow()
    markProgress("hopNow called")
    local cursor = ""
    for _try = 1, 6 do
        local page = fetchPage(cursor)
        if not page or not page.data then
            task.wait(Config.RetryHttpDelay)
        else
            cursor = (page.nextPageCursor and page.nextPageCursor ~= "null") and page.nextPageCursor or ""
            for _, v in ipairs(page.data) do
                local sid = tostring(v.id)
                if tonumber(v.playing) and tonumber(v.maxPlayers)
                   and tonumber(v.playing) < tonumber(v.maxPlayers)
                   and not table.find(AllIDs, sid)
                   and regionMatch(v) then
                    table.insert(AllIDs, sid)
                    notify(("Teleport -> %s (%s/%s)"):format(sid, tostring(v.playing), tostring(v.maxPlayers)))
                    markProgress("teleporting")
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(PlaceID, sid, lp)
                    end)
                    return
                end
            end
        end
    end
    -- fallback:
    pcall(function() TeleportService:Teleport(PlaceID, lp) end)
end

local function waitCharacter(timeout)
    local t0 = tick()
    repeat
        task.wait(0.2)
        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
            return true
        end
    until (tick()-t0) > (timeout or Config.JoinTimeout)
    return false
end

local function safeGetRemote()
    if Remote and Remote.Parent then return Remote end
    local ok, r = pcall(function()
        return Replicated:WaitForChild("RemoteEvents",10):WaitForChild("RequestTakeDiamonds",10)
    end)
    if ok then Remote = r end
    return Remote
end

local function findChest()
    local items = workspace:FindFirstChild("Items")
    if not items then return nil end
    return items:FindFirstChild(Config.ChestName)
end

local function findProximityPromptInChest(chest)
    local main = chest and chest:FindFirstChild("Main")
    if not main then return nil end
    local attach = main:FindFirstChild("ProximityAttachment")
    if not attach then return nil end
    return attach:FindFirstChild("ProximityInteraction")
end

local function pressPromptWithTimeout(prompt, timeout)
    local t0 = tick()
    while prompt and prompt.Parent and (tick() - t0) < (timeout or Config.MaxPromptTime) do
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.2)
    end
    return prompt and prompt.Parent == nil
end

local function waitDiamonds(timeout)
    local t0 = tick()
    while (tick() - t0) < (timeout or Config.WaitDiamondTimeout) do
        local found = workspace:FindFirstChild("Diamond", true)
        if found then return true end
        task.wait(0.2)
    end
    return false
end

local function collectAllDiamonds()
    local count = 0
    local rem = safeGetRemote()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.ClassName == "Model" and v.Name == "Diamond" then
            pcall(function()
                if rem then rem:FireServer(v) end
                count += 1
            end)
        end
    end
    return count
end

-- ===================== TELEPORT EVENTS (CHỐNG DIE) =====================
pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(_, result)
        notify("Teleport thất bại, thử lại...")
        task.delay(2, function()
            hopNow()
        end)
    end)
end)

pcall(function()
    TeleportService.TeleportSuccess:Connect(function(_, placeId, jobId)
        lastTeleportOk = tick()
        markProgress("teleport success")
        -- tránh vòng lại cùng server
        if jobId then
            table.insert(AllIDs, tostring(jobId))
        end
        joinedAt = tick()
    end)
end)

-- Nếu GUI/Interface sinh sau teleport, gắn lại tham chiếu
lp.CharacterAdded:Connect(function()
    markProgress("CharacterAdded")
    task.delay(1, function()
        pcall(function()
            Interface = lp:WaitForChild("PlayerGui", 10):WaitForChild("Interface",10)
            DiamondCount = Interface:WaitForChild("DiamondCount",10):WaitForChild("Count",10)
        end)
    end)
end)

-- ===================== WATCHDOG LOOP =====================
task.spawn(function()
    while task.wait(1) do
        local since = tick() - lastProgress

        -- chưa có character/UI quá lâu sau join -> hop
        if (tick()-joinedAt) > Config.JoinTimeout then
            if not (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")) then
                notify("Kẹt lúc join (no character) -> hop")
                hopNow()
                joinedAt = tick()
                markProgress("rejoin due to no character")
                continue
            end
            if not (Interface and DiamondCount) then
                notify("Kẹt UI (Interface) -> hop")
                hopNow()
                joinedAt = tick()
                markProgress("rejoin due to no UI")
                continue
            end
        end

        -- quá StuckTimeout không có tiến triển -> hop
        if since > Config.StuckTimeout then
            notify("Watchdog: kẹt logic -> hop server")
            hopNow()
            markProgress("watchdog hop")
            joinedAt = tick()
        end
    end
end)

-- ===================== MAIN FARM LOOP =====================
task.spawn(function()
    while true do
        markProgress("loop start")
        if not waitCharacter(Config.JoinTimeout) then
            notify("Không spawn được nhân vật -> hop")
            hopNow()
            joinedAt = tick()
            markProgress("no character hop")
            task.wait(3)
            continue
        end

        -- đảm bảo Interface/DiamondCount sau mỗi server
        pcall(function()
            if not (Interface and DiamondCount) then
                Interface = lp:WaitForChild("PlayerGui", 10):WaitForChild("Interface",10)
                DiamondCount = Interface:WaitForChild("DiamondCount",10):WaitForChild("Count",10)
            end
        end)

        -- tìm chest
        local chest = findChest()
        if not chest then
            notify("Không thấy chest -> hop")
            hopNow()
            joinedAt = tick()
            markProgress("no chest hop")
            task.wait(3)
            continue
        end

        -- move tới chest
        local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local piv = chest:GetPivot()
            lp.Character:PivotTo(CFrame.new(piv.Position + Vector3.new(0, 3, 0)))
        end
        markProgress("moved to chest")

        -- bấm prompt
        local prompt = findProximityPromptInChest(chest)
        if prompt then
            pressPromptWithTimeout(prompt, Config.MaxPromptTime)
            markProgress("pressed prompt")
        end

        -- nếu prompt còn -> stronghold đang chạy
        prompt = findProximityPromptInChest(chest)
        if prompt and prompt.Parent then
            notify("Stronghold đang chạy -> hop")
            hopNow()
            joinedAt = tick()
            markProgress("stronghold running hop")
            task.wait(3)
            continue
        end

        -- chờ diamonds
        if not waitDiamonds(Config.WaitDiamondTimeout) then
            notify("Không thấy Diamond -> hop")
            hopNow()
            joinedAt = tick()
            markProgress("no diamonds hop")
            task.wait(3)
            continue
        end

        -- nhặt
        local got = collectAllDiamonds()
        task.wait(0.5)
        got = got + collectAllDiamonds()
        notify(("Nhặt xong %d Diamond -> hop tiếp"):format(got))
        markProgress("collected diamonds")

        -- hop ngay khi xong
        hopNow()
        joinedAt = tick()
        task.wait(3)
    end
end)
