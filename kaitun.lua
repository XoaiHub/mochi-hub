--// ===================== CONFIG =====================
local Config = {
    RegionFilter = {           -- để trống {} nếu không lọc; ví dụ: {"singapore","us-east","tokyo"}
        -- "singapore", "tokyo"
    },
    TeleporterNames = {"Teleporter1","Teleporter2","Teleporter3"},
    TeleporterNeeded = 2,      -- số người tối thiểu trên bảng "x/y" để tự chạy vào cổng
    HopIfNoChest = true,       -- không có chest thì hop
    ChestName = "Stronghold Diamond Chest",
    MaxPromptTime = 10,        -- tối đa 10s bấm ProximityPrompt
    WaitDiamondTimeout = 20,   -- chờ tối đa 20s để Diamond spawn
    ScanInterval = 0.5,
    UILoopInterval = 0.2,
    HopLoopDelay = 1.0         -- delay nhẹ giữa các lần thử hop
}
--// ===================== SERVICES & SHORTCUTS =====================
local Players            = game:GetService("Players")
local LocalPlayer        = Players.LocalPlayer
local StarterGui         = game:GetService("StarterGui")
local HttpService        = game:GetService("HttpService")
local TeleportService    = game:GetService("TeleportService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")

-- Nhiều game cần chờ load đầy đủ
repeat task.wait() until game:IsLoaded() and LocalPlayer and LocalPlayer.Character

--// Interface & Remote an toàn
local function safeWaitPath(root, pathArray, timeout)
    timeout = timeout or 15
    local t0 = tick()
    local cur = root
    for _,name in ipairs(pathArray) do
        while cur and not cur:FindFirstChild(name) and tick() - t0 < timeout do
            task.wait(0.2)
        end
        if not cur or not cur:FindFirstChild(name) then
            return nil
        end
        cur = cur:FindFirstChild(name)
    end
    return cur
end

local Remote = safeWaitPath(ReplicatedStorage, {"RemoteEvents","RequestTakeDiamonds"}, 10)
local Interface = safeWaitPath(LocalPlayer, {"PlayerGui","Interface"}, 10)
local DiamondCount = Interface and safeWaitPath(Interface, {"DiamondCount","Count"}, 10)

--// ===================== UI NHO NHẸ =====================
local function rainbowStroke(stroke)
    task.spawn(function()
        while stroke and stroke.Parent do
            for hue = 0, 1, 0.01 do
                if not stroke or not stroke.Parent then break end
                stroke.Color = Color3.fromHSV(hue, 1, 1)
                task.wait(0.02)
            end
        end
    end)
end

if not game.CoreGui:FindFirstChild("gg") then
    local gui = Instance.new("ScreenGui")
    gui.Name = "gg"
    gui.ResetOnSpawn = false
    gui.Parent = game.CoreGui

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromOffset(220, 110)
    frame.Position = UDim2.new(0, 80, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(35,35,35)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    local c1 = Instance.new("UICorner", frame) c1.CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame) stroke.Thickness = 1.5
    rainbowStroke(stroke)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1,0,0,30)
    title.BackgroundTransparency = 1
    title.Text = "Farm Diamond | Cáo Mod"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextStrokeTransparency = 0.6

    local counter = Instance.new("TextLabel", frame)
    counter.Size = UDim2.new(1,-20,0,35)
    counter.Position = UDim2.new(0,10,0,40)
    counter.BackgroundColor3 = Color3.fromRGB(0,0,0)
    counter.TextColor3 = Color3.new(1,1,1)
    counter.Font = Enum.Font.GothamBold
    counter.TextSize = 14
    counter.BorderSizePixel = 0
    local c2 = Instance.new("UICorner", counter) c2.CornerRadius = UDim.new(0,6)

    task.spawn(function()
        while counter and counter.Parent do
            local txt = (DiamondCount and DiamondCount.Text) or "?"
            counter.Text = "Diamonds: " .. tostring(txt)
            task.wait(Config.UILoopInterval)
        end
    end)
end

local function notify(t)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Notification",
            Text = tostring(t),
            Duration = 3
        })
    end)
end

--// ===================== TIỆN ÍCH DỊ CHUYỂN =====================
local function tpTo(cf)
    local ch = LocalPlayer.Character
    if ch and ch:FindFirstChild("HumanoidRootPart") then
        -- PivotTo an toàn hơn SetPrimaryPartCFrame
        ch:PivotTo(cf)
    end
end

-- Check teleporter x/y >= TeleporterNeeded → tự đi vào
local function parsePlayersText(txt)
    -- chấp nhận dạng "2/6" hoặc "Players: 2/6"
    local x,y = string.match(txt,"%s*(%d+)%s*/%s*(%d+)")
    x,y = tonumber(x), tonumber(y)
    return x,y
end

local function tryEnterTeleporter(model)
    local bb = model:FindFirstChild("BillboardHolder")
    local gui = bb and bb:FindFirstChild("BillboardGui")
    local playersLbl = gui and gui:FindFirstChild("Players")
    local t = playersLbl and playersLbl.Text
    if not t then return end

    local cur, max = parsePlayersText(t)
    if cur and max and cur >= Config.TeleporterNeeded then
        local enter = model:FindFirstChildWhichIsA("BasePart")
        local ch = LocalPlayer.Character
        local hum = ch and ch:FindFirstChildWhichIsA("Humanoid")
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if enter and hum and hrp then
            hum:MoveTo(enter.Position)
            task.wait(0.25)
            if (hrp.Position - enter.Position).Magnitude > 10 then
                tpTo(enter.CFrame + Vector3.new(0,3,0))
            end
        end
    end
end

task.spawn(function()
    while task.wait(Config.ScanInterval) do
        for _,obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") then
                for _,name in ipairs(Config.TeleporterNames) do
                    if obj.Name == name then
                        pcall(tryEnterTeleporter, obj)
                        break
                    end
                end
            end
        end
    end
end)

--// ===================== HOP SERVER THÔNG MINH =====================
local PlaceID          = game.PlaceId
local AllIDs           = {game.JobId} -- tránh quay lại server hiện tại
local Cursor           = ""
local IsTeleporting    = false

local function regionOk(v)
    if #Config.RegionFilter == 0 then return true end
    local region = string.lower(tostring(v.ping or v.region or ""))
    for _,kw in ipairs(Config.RegionFilter) do
        if string.find(region, string.lower(kw)) then
            return true
        end
    end
    return false
end

local function fetchServers(cursor)
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100%s")
        :format(PlaceID, cursor ~= "" and ("&cursor="..cursor) or "")
    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok then return nil end
    return data
end

local function hopServer()
    if IsTeleporting then return end
    local tried = 0
    while true do
        local data = fetchServers(Cursor)
        if not data or not data.data then
            task.wait(Config.HopLoopDelay)
        else
            Cursor = (data.nextPageCursor and data.nextPageCursor ~= "null") and data.nextPageCursor or ""
            for _,v in ipairs(data.data) do
                local id = tostring(v.id)
                if tonumber(v.playing) < tonumber(v.maxPlayers) and regionOk(v) then
                    local okDup = true
                    for _,ex in ipairs(AllIDs) do
                        if id == tostring(ex) then okDup = false break end
                    end
                    if okDup then
                        table.insert(AllIDs, id)
                        IsTeleporting = true
                        notify("Đang chuyển server...")
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(PlaceID, id, LocalPlayer)
                        end)
                        -- Nếu chưa chuyển được ngay (hiếm), chờ rồi thử tiếp
                        task.wait(3)
                        IsTeleporting = false
                    end
                end
            end
        end
        tried += 1
        task.wait(Config.HopLoopDelay)
        if tried >= 3 and Cursor == "" then
            -- reset vòng tìm server
            tried = 0
        end
    end
end

--// ===================== FARM CHEST & DIAMOND =====================
local function findChest()
    local items = workspace:FindFirstChild("Items")
    if not items then return nil end
    return items:FindFirstChild(Config.ChestName)
end

local function clickPromptFor(partWithAttachment, maxTime)
    local t0 = tick()
    local prompt
    local prox = partWithAttachment
    if prox and prox:FindFirstChild("ProximityAttachment") then
        prompt = prox.ProximityAttachment:FindFirstChild("ProximityInteraction")
    end
    while not prompt and tick()-t0 < maxTime do
        task.wait(0.1)
        if prox and prox:FindFirstChild("ProximityAttachment") then
            prompt = prox.ProximityAttachment:FindFirstChild("ProximityInteraction")
        end
    end
    if not prompt then return false end

    local ok = false
    local t1 = tick()
    while prompt and prompt.Parent and tick() - t1 < maxTime do
        pcall(function() fireproximityprompt(prompt) ok = true end)
        task.wait(0.2)
    end
    return ok
end

local function waitForDiamond(timeout)
    local t0 = tick()
    while tick() - t0 < timeout do
        local d = workspace:FindFirstChild("Diamond", true)
        if d then return true end
        task.wait(0.2)
    end
    return false
end

local function takeAllDiamonds()
    if not Remote then return end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Diamond" then
            pcall(function()
                Remote:FireServer(v)
            end)
        end
    end
end

--// ===================== LUỒNG CHÍNH =====================
task.spawn(function()
    -- đợi HRP
    repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- tìm chest
    local chest = findChest()
    if not chest then
        if Config.HopIfNoChest then
            notify("Không thấy chest → hop server")
            hopServer()
            return
        else
            notify("Không thấy chest (bỏ qua hop theo config)")
            return
        end
    end

    -- tới chest
    local pivot = chest:GetPivot()
    LocalPlayer.Character:PivotTo(CFrame.new(pivot.Position + Vector3.new(0,3,0)))
    task.wait(0.25)

    -- tìm & bấm prompt
    local main = chest:FindFirstChild("Main")
    if main then
        local pressed = clickPromptFor(main, Config.MaxPromptTime)
        if pressed then
            notify("Đã kích hoạt Stronghold (đợi Diamond)")
        else
            notify("Không kích hoạt được Stronghold → hop server")
            hopServer()
            return
        end
    else
        notify("Thiếu phần Main của chest → hop server")
        hopServer()
        return
    end

    -- chờ Diamond xuất hiện
    local ok = waitForDiamond(Config.WaitDiamondTimeout)
    if not ok then
        notify("Không thấy Diamond spawn → hop server")
        hopServer()
        return
    end

    -- nhặt Diamond
    takeAllDiamonds()
    notify("Đã nhặt Diamond xong → hop server")
    task.wait(1)
    hopServer()
end)
