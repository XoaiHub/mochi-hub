-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI) + FAST HOP AFTER COLLECT
-- ================================================================

-- ===== CONFIG =====
local Config = {
    RegionFilterEnabled   = false,
    RegionList            = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay        = 2,

    StrongholdChestName   = "Stronghold Diamond Chest",
    StrongholdPromptTime  = 6,
    StrongholdDiamondWait = 10,

    FarmPlaceId           = 126509999114328, -- map farm
    LobbyCheckInterval    = 2.0,   -- giãn nhịp cho giả lập
    FarmTick              = 1.0,   -- vòng lặp farm
    DiamondTick           = 0.35,  -- vòng lặp nhặt diamond
    HopBackoffMin         = 1.5,   -- backoff ngẫu nhiên khi hop
    HopBackoffMax         = 3.0,

    -- === FAST HOP AFTER COLLECT ===
    HopAfterStronghold    = true,  -- nhặt xong stronghold -> hop nhanh
    HopAfterNormalChest   = true,  -- mở chest thường, nhặt xong -> hop nhanh
    HopPostDelay          = 0.20,  -- delay rất ngắn trước khi hop (để remote xử lý nhặt)
}

-- ===== SERVICES =====
local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RS              = g:GetService("ReplicatedStorage")
local RunService      = g:GetService("RunService")
local HttpService     = g:GetService("HttpService")
local TeleportService = g:GetService("TeleportService")
local StarterGui      = g:GetService("StarterGui")

-- ===== UTILS: Safe waiters =====
local function WaitForChar(timeout)
    timeout = timeout or 15
    local t = 0
    while t < timeout do
        if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            return LocalPlayer.Character
        end
        t += 0.25
        task.wait(0.25)
    end
    return LocalPlayer.Character
end

local function HRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function rand(a,b) return a + (b-a)*math.random() end

-- ===== Queue-on-teleport (hợp nhiều executor & Luarmor) =====
local function queue_on_teleport_compat(code)
    local f = (syn and syn.queue_on_teleport)
          or  queue_on_teleport
          or  (fluxus and fluxus.queue_on_teleport)
          or  (KRNL_LOADED and queue_on_teleport)
    if f then
        pcall(f, code)
    end
end

-- Bạn có thể gắn loader của Luarmor vào đây để tự chạy lại sau teleport:
-- queue_on_teleport_compat([[loadstring(game:HttpGet("https://yourdomain.com/Init.lua"))()]])

-- ===== FPS BOOST (nhẹ hơn cho giả lập) =====
do
    g.Lighting.GlobalShadows = false
    g.Lighting.Brightness = 0
    g.Lighting.FogEnd = 1e10
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)

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
            optimize(v)
            task.wait(0.0005)
        end
    end)
    g.DescendantAdded:Connect(optimize)
end

-- ===== STATE =====
local PlaceID = g.PlaceId
local AllIDs, cursor, isTeleporting = {}, "", false
local strongholdTried, chestTried = {}, {}
local StrongholdCount, NormalChestCount = 0, 0

local function resetState()
    AllIDs, cursor, isTeleporting = {}, "", false
    strongholdTried, chestTried = {}, {}
    warn("[Hop] Reset state.")
end

local function hasValue(tab, val)
    for _, v in ipairs(tab) do if v == val then return true end end
    return false
end

-- ===== SERVER HOP (an toàn/ít request cho giả lập) =====
local function fetchServerPage(nextCursor, sortOrder)
    sortOrder = sortOrder or "Desc"
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100%s")
        :format(PlaceID, sortOrder, nextCursor ~= "" and ("&cursor="..nextCursor) or "")
    local ok, data = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if not ok then
        task.wait(Config.RetryHttpDelay)
        return nil
    end
    return data
end

local function regionMatch(serverEntry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(serverEntry.region or ""):lower()
    for _, key in ipairs(Config.RegionList) do
        if raw:find(tostring(key):lower(), 1, true) then return true end
    end
    return false
end

local function tryTeleportOnce()
    if not HRP() then return false end
    if #AllIDs > 200 then AllIDs = {} end

    local page = fetchServerPage(cursor)
    if not page or not page.data then cursor = "" return false end
    cursor = page.nextPageCursor or ""

    for _, v in ipairs(page.data) do
        local sid = tostring(v.id)
        local playing, maxp = tonumber(v.playing), tonumber(v.maxPlayers)
        if playing and maxp and playing < maxp then
            if not hasValue(AllIDs, sid) and regionMatch(v) then
                table.insert(AllIDs, sid)
                isTeleporting = true
                resetState()
                task.wait(rand(Config.HopBackoffMin, Config.HopBackoffMax))
                local ok, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(PlaceID, sid, LocalPlayer)
                end)
                if not ok then
                    warn("[Hop] Teleport error:", err)
                    isTeleporting = false
                end
                return true
            end
        end
    end
    return false
end

function Hop()
    WaitForChar()
    for _ = 1, 4 do
        if tryTeleportOnce() then return end
        task.wait(rand(1.0, 2.0))
    end
    cursor = ""
    fetchServerPage("", "Asc")
    task.wait(rand(1.0, 2.0))
end

TeleportService.TeleportInitFailed:Connect(function(_, _, msg)
    warn("[Hop] TeleportInitFailed:", msg)
    isTeleporting = false
    task.delay(2.0, Hop)
end)

Players.LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        resetState()
    end
end)

-- ===== NOCLIP (nhẹ) =====
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local c = LocalPlayer.Character
    if not c then return end
    local on = getgenv().NoClip
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not on end
    end
end)

-- ===== MOVE HELPER =====
local function tpCFrame(cf)
    local r = HRP()
    if r then r.CFrame = cf end
end

-- ===== DIAMOND HELPERS =====
local function diamondsLeft()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.ClassName == "Model" and v.Name == "Diamond" then
            return true
        end
    end
    return false
end

local function waitNoDiamonds(timeout)
    local t0 = tick()
    while tick() - t0 < (timeout or 1.2) do
        if not diamondsLeft() then return true end
        task.wait(0.1)
    end
    return not diamondsLeft()
end

local function collectAllDiamonds()
    local n = 0
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.ClassName == "Model" and v.Name == "Diamond" then
            pcall(function() RS.RemoteEvents.RequestTakeDiamonds:FireServer(v) end)
            n += 1
        end
    end
    return n
end

-- ===== FAST HOP TRIGGER =====
local HopRequested = false
local function HopFast(reason)
    if isTeleporting or HopRequested then return end
    -- nếu bạn đang hiến gems & đã dùng Donate module trước đó
    if getgenv and getgenv().PauseHop then
        local t0 = os.clock()
        while getgenv().PauseHop and os.clock() - t0 < 10 do task.wait(0.25) end
    end
    HopRequested = true
    task.spawn(function()
        task.wait(Config.HopPostDelay)
        if not isTeleporting then
            warn("[HopFast] "..tostring(reason or ""))
            Hop()
        end
        HopRequested = false
    end)
end

-- ===== FINDERS =====
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

local function findUsableChest()
    local r = HRP()
    if not r then return nil end
    local closest, dist
    local items = workspace:FindFirstChild("Items")
    if not items then return nil end
    for _, v in pairs(items:GetDescendants()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local id = v:GetDebugId()
            if not chestTried[id] then
                local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prox and prox.Enabled then
                    local d = (r.Position - v:GetPivot().Position).Magnitude
                    if not dist or d < dist then closest, dist = v, d end
                end
            end
        end
    end
    return closest
end

-- ===== PROMPT HELPERS =====
local function pressPromptWithTimeout(prompt, timeout)
    local t0 = tick()
    while prompt and prompt.Parent and prompt.Enabled and (tick()-t0) < timeout do
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.3)
    end
    return not (prompt and prompt.Parent and prompt.Enabled)
end

local function waitDiamonds(timeout)
    local t0 = tick()
    while (tick()-t0) < (timeout or 2.0) do
        if workspace:FindFirstChild("Diamond", true) then return true end
        task.wait(0.2)
    end
    return false
end

-- ===== AUTO JOIN / CREATE (Lobby) =====
local function autoJoinOrCreate()
    local joined = false
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
            local gui  = obj:FindFirstChild("BillboardHolder")
            local board= gui and gui:FindFirstChild("BillboardGui")
            local lab  = board and board:FindFirstChild("Players")
            if lab and typeof(lab.Text) == "string" then
                local x, y = lab.Text:match("(%d+)/(%d+)")
                x, y = tonumber(x), tonumber(y)
                if x and y and x >= 2 and x < y then
                    local enter = obj:FindFirstChildWhichIsA("BasePart")
                    if enter and HRP() then
                        tpCFrame(enter.CFrame + Vector3.new(0, 3, 0))
                        joined = true
                        warn("[Party] Join room:", obj.Name)
                        break
                    end
                end
            end
        end
    end

    if not joined then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
                local enter = obj:FindFirstChildWhichIsA("BasePart")
                if enter and HRP() then
                    tpCFrame(enter.CFrame + Vector3.new(0, 3, 0))
                    warn("[Party] Create room:", obj.Name)
                    break
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(Config.LobbyCheckInterval) do
        if g.PlaceId ~= Config.FarmPlaceId then
            pcall(autoJoinOrCreate)
        end
    end
end)

-- ===== MAIN FARM (giãn tick cho giả lập) =====
task.spawn(function()
    while task.wait(Config.FarmTick) do
        if g.PlaceId ~= Config.FarmPlaceId then continue end
        WaitForChar()

        -- 1) Stronghold ưu tiên
        local sh = findStrongholdChest()
        if sh then
            local sid = sh:GetDebugId()
            if not strongholdTried[sid] then
                local prox = findProximityPromptInChest(sh)
                if prox and prox.Enabled then
                    tpCFrame(CFrame.new(sh:GetPivot().Position + Vector3.new(0,3,0)))
                    local opened = pressPromptWithTimeout(prox, Config.StrongholdPromptTime)

                    prox = findProximityPromptInChest(sh)
                    if not opened and (prox and prox.Parent and prox.Enabled) then
                        strongholdTried[sid] = true -- khoá/bug
                    else
                        -- chờ có diamond xuất hiện, nhặt sạch, rồi hop nhanh
                        if waitDiamonds(Config.StrongholdDiamondWait) then
                            collectAllDiamonds()
                            waitNoDiamonds(1.1) -- đợi nhặt sạch
                            StrongholdCount += 1
                            if Config.HopAfterStronghold then
                                HopFast("after-stronghold-collect")
                            end
                        else
                            strongholdTried[sid] = true -- không spawn
                        end
                    end
                else
                    strongholdTried[sid] = true
                end
            end
        end

        -- 2) Chest thường (khoá/bug -> skip; hết usable -> hop)
        local chest = findUsableChest()
        if not chest then
            Hop()
        else
            local id   = chest:GetDebugId()
            local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            local t0   = os.clock()
            local okOpen = false

            while prox and prox.Parent and prox.Enabled and (os.clock() - t0) < 10 do
                tpCFrame(CFrame.new(chest:GetPivot().Position))
                pcall(function() fireproximityprompt(prox) end)
                task.wait(0.45)
                prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            end

            if not (prox and prox.Parent and prox.Enabled) then okOpen = true end

            if okOpen then
                -- đợi diamonds spawn, gom sạch rồi hop nhanh
                StrongholdCount = StrongholdCount -- no-op để giữ biến cục bộ không unused
                NormalChestCount += 1
                -- gọi gom ngay (phòng khi tick diamonds chưa kịp)
                collectAllDiamonds()
                waitNoDiamonds(1.0)
                if Config.HopAfterNormalChest then
                    HopFast("after-normalchest-collect")
                end
            else
                chestTried[id] = true
            end
        end
    end
end)

-- 3) Diamonds song song (giãn tick an toàn)
task.spawn(function()
    while task.wait(Config.DiamondTick) do
        if g.PlaceId == Config.FarmPlaceId then
            collectAllDiamonds()
        end
    end
end)

-- 4) Re-attach khi nhân vật respawn (giả lập hay bị rớt HRP)
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.0)
    WaitForChar()
end)

-- 5) Anti AFK nhẹ (giả lập ít tương tác)
pcall(function()
    local vu = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        task.wait(math.random(30, 60))
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end)
