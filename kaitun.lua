--// ================== CONFIG ==================
local Config = {
    RegionFilterEnabled   = false,
    RegionList            = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay        = 2,

    StrongholdChestName   = "Stronghold Diamond Chest",
    StrongholdPromptTime  = 6,   -- spam mở Stronghold tối đa 6s
    StrongholdDiamondWait = 10,  -- sau khi mở, chờ diamond spawn tối đa 10s

    FarmPlaceId           = 126509999114328, -- ID map farm
}

--// ================== SERVICES ==================
local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RS              = g:GetService("ReplicatedStorage")
local RunService      = g:GetService("RunService")
local HttpService     = g:GetService("HttpService")
local TeleportService = g:GetService("TeleportService")
local StarterGui      = g:GetService("StarterGui")
local UIS             = g:GetService("UserInputService")

--// ================== COUNTERS ==================
local StrongholdCount, NormalChestCount = 0, 0

-- giữ tham chiếu fireproximityprompt an toàn khi obf
local FPP = rawget(getfenv(0), "fireproximityprompt") or getgenv().fireproximityprompt or fireproximityprompt

--// ================== FPS BOOST ==================
local function optimize(v)
    if v:IsA("BasePart") or v:IsA("MeshPart") then
        v.Material = Enum.Material.Plastic
        v.Reflectance = 0
        v.CastShadow  = false
        if v:IsA("MeshPart") then v.TextureID = "" end
        v.Transparency = 1
    elseif v:IsA("Decal") or v:IsA("Texture") then
        v.Transparency = 1
    elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
        v.Enabled = false
    elseif v:IsA("SpecialMesh") or v:IsA("SurfaceAppearance") then
        pcall(function() v:Destroy() end)
    end
end
task.spawn(function()
    for _, v in ipairs(g:GetDescendants()) do
        pcall(optimize, v)
    end
end)
g.DescendantAdded:Connect(function(v) pcall(optimize, v) end)

--// ================== UTILS ==================
local function isReady()
    return g:IsLoaded()
       and LocalPlayer
       and LocalPlayer.Character
       and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

local function hasValue(tab, val)
    for _, v in ipairs(tab) do if v==val then return true end end
    return false
end

local function regionMatch(serverEntry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(serverEntry.region or ""):lower()
    for _, key in ipairs(Config.RegionList) do
        if string.find(raw, tostring(key):lower(), 1, true) then return true end
    end
    return false
end

local function L_V1(cf)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character:SetPrimaryPartCFrame(cf)
    end
end

--// ================== NOCLIP ==================
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    if getgenv().NoClip then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide=false end
        end
    else
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide=true end
        end
    end
end)

--// ================== SERVER HOP (fixed anti-dead) ==================
local PlaceID = g.PlaceId
local AllIDs, cursor, isTeleporting = {}, "", false
local hopSort = "Desc" -- sẽ đảo Desc <-> Asc thật sự
local strongholdTried, chestTried = {}, {}  -- cache skip
local lastTry = tick()

local function resetHop(full)
    cursor, isTeleporting = "", false
    if full then AllIDs = {} end
end

local function fetchServerPage(nextCursor, sortOrder)
    sortOrder = sortOrder or hopSort
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100%s")
        :format(PlaceID, sortOrder, nextCursor ~= "" and ("&cursor="..nextCursor) or "")
    local ok, data = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if not ok then task.wait(Config.RetryHttpDelay) return nil end
    return data
end

local function tryTeleportOnce()
    if not isReady() then return false end
    if #AllIDs > 500 then AllIDs = {} end

    local page = fetchServerPage(cursor, hopSort)
    if not page or not page.data then resetHop(false) return false end
    cursor = page.nextPageCursor or ""

    for _, v in ipairs(page.data) do
        local sid = tostring(v.id)
        if tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers then
            if not hasValue(AllIDs, sid) and regionMatch(v) then
                table.insert(AllIDs, sid)
                isTeleporting = true
                lastTry = tick()
                local ok, err = pcall(function()
                    -- reset toàn bộ cache trước khi rời server
                    resetHop(true)
                    strongholdTried, chestTried = {}, {}
                    TeleportService:TeleportToPlaceInstance(PlaceID, sid, LocalPlayer)
                end)
                if not ok then
                    warn("[Hop] Teleport error: "..tostring(err))
                    isTeleporting = false
                end
                return true
            end
        end
    end

    -- hết trang hiện tại → đảo sort thật sự
    if cursor == "" then
        hopSort = (hopSort == "Desc") and "Asc" or "Desc"
        resetHop(false)
        warn("[Hop] Đổi sortOrder → "..hopSort)
    end
    return false
end

function Hop()
    if not isReady() then repeat task.wait(1) until isReady() end
    for _ = 1, 6 do
        if tryTeleportOnce() then return end
        task.wait(1.5)
    end
    -- vẫn chưa được → reset mạnh và đảo chiều
    hopSort = (hopSort == "Desc") and "Asc" or "Desc"
    resetHop(true)
    tryTeleportOnce()
end

TeleportService.TeleportInitFailed:Connect(function(_, _, msg)
    warn("[Hop] TeleportInitFailed: ".. tostring(msg))
    isTeleporting = false
    task.delay(2, Hop)
end)

Players.LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        resetHop(true)
        strongholdTried, chestTried = {}, {}
    end
end)

-- watchdog: 90s không teleport được thì reset/đảo chiều
task.spawn(function()
    while task.wait(5) do
        if g.PlaceId == Config.FarmPlaceId and (tick() - lastTry) > 90 and not isTeleporting then
            hopSort = (hopSort == "Desc") and "Asc" or "Desc"
            resetHop(true)
            warn("[Hop] Watchdog reset (90s)")
            Hop()
        end
    end
end)

--// ================== UI (compact + obf-safe + toggle F4) ==================
local UI_ENABLED = true
local gui = Instance.new("ScreenGui"); gui.Name = "MochiHUD"; gui.ResetOnSpawn = false
gui.Parent = g:GetService("CoreGui")

local panel = Instance.new("Frame", gui)
panel.AnchorPoint = Vector2.new(0,1)
panel.Position = UDim2.new(0, 12, 1, -12)
panel.Size = UDim2.new(0, 300, 0, 92)
panel.BackgroundColor3 = Color3.fromRGB(15,15,20)
panel.BackgroundTransparency = 0.2
panel.Visible = UI_ENABLED
local corner = Instance.new("UICorner", panel); corner.CornerRadius = UDim.new(0,12)
local padding = Instance.new("UIPadding", panel); padding.PaddingLeft = UDim.new(0,12); padding.PaddingTop = UDim.new(0,8)

local function mkLabel(y, text, c)
    local l = Instance.new("TextLabel", panel)
    l.BackgroundTransparency = 1
    l.Position = UDim2.new(0, 0, 0, y)
    l.Size = UDim2.new(1, 0, 0, 24)
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 20
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = c
    l.Text = text
    return l
end

local diamondLabel    = mkLabel(0,  "Diamonds: 0",         Color3.fromRGB(255,255,255))
local normalLabel     = mkLabel(26, "Normal Chest: 0",     Color3.fromRGB(170,255,170))
local strongholdLabel = mkLabel(52, "Stronghold Chest: 0", Color3.fromRGB(255,170,170))

-- Toggle F4
UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.F4 then
        UI_ENABLED = not UI_ENABLED
        panel.Visible = UI_ENABLED
    end
end)

-- đọc số kim cương an toàn khi obf đổi tên mid-level
local function readDiamondCount()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    local iface = pg:FindFirstChild("Interface")
    if not iface then return end
    local dc = nil
    if iface:FindFirstChild("DiamondCount") then
        dc = iface.DiamondCount:FindFirstChild("Count")
    end
    if not (dc and dc:IsA("TextLabel")) then
        for _,d in ipairs(iface:GetDescendants()) do
            if d:IsA("TextLabel") and d.Name:lower():find("count") and d.Text:match("^%d+$") then
                dc = d; break
            end
        end
    end
    if dc and dc:IsA("TextLabel") then
        diamondLabel.Text = "Diamonds: " .. dc.Text
    end
end

task.spawn(function()
    while task.wait(0.25) do
        pcall(readDiamondCount)
        normalLabel.Text     = ("Normal Chest: %d"):format(NormalChestCount)
        strongholdLabel.Text = ("Stronghold Chest: %d"):format(StrongholdCount)
    end
end)

--// ================== FINDERS ==================
local function findUsableChest()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest, dist
    local items = workspace:FindFirstChild("Items")
    if not items then return nil end
    for _, v in pairs(items:GetDescendants()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local id = v:GetDebugId()
            if not chestTried[id] then
                local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prox and prox.Enabled then
                    local d = (hrp.Position - v:GetPivot().Position).Magnitude
                    if not dist or d < dist then closest, dist = v, d end
                end
            end
        end
    end
    return closest
end

local function findStrongholdChest()
    local items = workspace:FindFirstChild("Items")
    if not items then return nil end
    return items:FindFirstChild(Config.StrongholdChestName)
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
    while prompt and prompt.Parent and prompt.Enabled and (tick()-t0)<timeout do
        pcall(function() FPP(prompt) end)
        task.wait(0.3)
    end
    return not (prompt and prompt.Parent and prompt.Enabled)
end

local function waitDiamonds(timeout)
    local t0 = tick()
    while (tick()-t0)<timeout do
        if workspace:FindFirstChild("Diamond", true) then return true end
        task.wait(0.2)
    end
    return false
end

local function collectAllDiamonds()
    local count=0
    for _,v in ipairs(workspace:GetDescendants()) do
        if v.ClassName=="Model" and v.Name=="Diamond" then
            pcall(function() RS.RemoteEvents.RequestTakeDiamonds:FireServer(v) end)
            count+=1
        end
    end
    return count
end

--// ================== AUTO JOIN PARTY (ở lobby) ==================
local function autoJoinParty()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
            local gui = obj:FindFirstChild("BillboardHolder")
            if gui and gui:FindFirstChild("BillboardGui") and gui.BillboardGui:FindFirstChild("Players") then
                local txt = gui.BillboardGui.Players.Text
                local x, y = txt:match("(%d+)/(%d+)")
                x, y = tonumber(x), tonumber(y)
                if x and y and x >= 2 then
                    local enter = obj:FindFirstChildWhichIsA("BasePart")
                    if enter and LocalPlayer.Character then
                        L_V1(enter.CFrame + Vector3.new(0,3,0))
                        warn("[Party] Auto join:", obj.Name)
                    end
                end
            end
        end
    end
end
task.spawn(function()
    while task.wait(2) do
        if g.PlaceId ~= Config.FarmPlaceId then
            pcall(autoJoinParty)
        end
    end
end)

--// ================== MAIN FARM ==================
task.spawn(function()
    while task.wait(1) do
        if g.PlaceId ~= Config.FarmPlaceId then
            -- không ở map farm
            continue
        end

        -- 1) ƯU TIÊN STRONGHOLD (skip vĩnh viễn nếu fail)
        local sh = findStrongholdChest()
        if sh then
            local sid = sh:GetDebugId()
            if not strongholdTried[sid] then
                local prox = findProximityPromptInChest(sh)
                if prox and prox.Enabled then
                    warn("[Stronghold] Thử mở chest...")
                    L_V1(CFrame.new(sh:GetPivot().Position + Vector3.new(0,3,0)))
                    local opened = pressPromptWithTimeout(prox, Config.StrongholdPromptTime)

                    prox = findProximityPromptInChest(sh)
                    if not opened and (prox and prox.Parent and prox.Enabled) then
                        strongholdTried[sid] = true
                        warn("[Stronghold] Khoá/bug -> skip")
                    else
                        if waitDiamonds(Config.StrongholdDiamondWait) then
                            local got = collectAllDiamonds()
                            StrongholdCount += 1
                            strongholdTried[sid] = true
                            warn("[Stronghold] Đã nhặt diamond:", got)
                        else
                            strongholdTried[sid] = true
                            warn("[Stronghold] Không thấy diamond -> skip")
                        end
                    end
                else
                    strongholdTried[sid] = true
                    warn("[Stronghold] Không khả dụng -> skip")
                end
            end
        end

        -- 2) FARM CHEST THƯỜNG (skip chest bug; hop khi hết usable)
        while g.PlaceId == Config.FarmPlaceId do
            local chest = findUsableChest()
            if not chest then
                warn("[ChestFarm] Hết chest usable -> hop server")
                Hop()
                break
            end

            local id   = chest:GetDebugId()
            if chestTried[id] then
                -- chest này đã fail trước đó, tìm cái khác
                if not findUsableChest() then
                    warn("[ChestFarm] Tất cả chest fail -> hop server")
                    Hop()
                    break
                end
                task.wait(0.4)
                continue
            end

            local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            local start = os.time()
            local success = false

            while prox and prox.Parent and prox.Enabled and os.time()-start < 10 do
                L_V1(CFrame.new(chest:GetPivot().Position))
                pcall(function() FPP(prox) end)
                task.wait(0.5)
                prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            end

            if not (prox and prox.Parent and prox.Enabled) then success = true end

            if success then
                NormalChestCount += 1
                warn("[ChestFarm] Mở chest thường thành công")
            else
                chestTried[id] = true
                warn("[ChestFarm] Chest kẹt/bug -> đánh dấu skip")
            end
            task.wait(0.4)
        end
    end
end)

-- 3) Diamonds farm song song
task.spawn(function()
    while task.wait(0.2) do
        if g.PlaceId == Config.FarmPlaceId then
            pcall(collectAllDiamonds)
        end
    end
end)
