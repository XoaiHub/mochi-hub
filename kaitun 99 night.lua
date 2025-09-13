-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI) - FULL
-- + Fast Hop After Collect (nhảy ngay sau khi nhặt xong)
-- + Anti-DEAD + Skip Server Full + No-Rejoin-Same-Server
-- + Hop engine: Asc/Desc + cursor (đã gia cố) + guard, grace windows
-- + Khi rương/Stronghold KHÔNG mở được -> Hop ngay (không đứng yên)
-- (Hardened for all executors incl. Wave/PC/Emu)
-- ================================================================

-- ===== CONFIG =====
local Config = {
    RegionFilterEnabled     = false,
    RegionList              = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay          = 2,

    StrongholdChestName     = "Stronghold Diamond Chest",
    StrongholdPromptTime    = 6,
    StrongholdDiamondWait   = 10,

    FarmPlaceId             = 126509999114328, -- map farm
    LobbyCheckInterval      = 2.0,
    FarmTick                = 1.0,
    DiamondTick             = 0.35,

    HopBackoffMin           = 1.5,
    HopBackoffMax           = 3.0,

    -- Fast hop sau khi NHẶT xong
    HopAfterStronghold      = true,
    HopAfterNormalChest     = true,
    HopPostDelay            = 0.20,

    -- Anti-DEAD
    DeadHopTimeout          = 6.0,
    DeadUiKeywords          = { "dead", "you died", "respawn", "revive" },

    -- Harden
    MaxConsecutiveHopFail   = 5,
    ConsecutiveHopCooloff   = 6.0,
    MaxPagesPrimary         = 8,
    MaxPagesFallback        = 12,

    -- Giảm tỉ lệ hop vào server full (tự tăng yêu cầu slot tạm thời khi fail)
    MinFreeSlotsDefault     = 1,
    MinFreeSlotsCeil        = 3,

    -- Chọn kiểu server khi HopClassic
    ClassicMode             = "Low", -- "Low" hoặc "High"

    -- Chống hop quá sớm (grace windows)
    JoinGraceSeconds        = 4.0,   -- sau khi vừa vào map farm
    FirstDiamondGrace       = 2.5,   -- sau khi nhặt viên kim cương đầu
}

-- ===== SERVICES =====
local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RS              = g:GetService("ReplicatedStorage")
local RunService      = g:GetService("RunService")
local HttpService     = g:GetService("HttpService")
local TeleportService = g:GetService("TeleportService")

-- ===== UTILS =====
local function WaitForChar(timeout)
    timeout = timeout or 15
    local t = 0
    while t < timeout do
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChild("Humanoid") then
            return c
        end
        t = t + 0.25
        task.wait(0.25)
    end
    return LocalPlayer.Character
end

local function HRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function rand(a,b) return a + (b-a)*math.random() end

-- HTTP getter tương thích
local function http_get(url)
    local ok1, res1 = pcall(function() return g:HttpGet(url) end)
    if ok1 and type(res1) == "string" and #res1 > 0 then return res1 end
    local req = (syn and syn.request) or (http and http.request) or (request)
    if req then
        local ok2, res2 = pcall(function() return req({Url = url, Method = "GET"}) end)
        if ok2 and res2 and (res2.Success == nil or res2.Success == true) and type(res2.Body) == "string" then
            return res2.Body
        end
    end
    return nil
end

-- queue_on_teleport tương thích
local function queue_on_teleport_compat(code)
    local f = (syn and syn.queue_on_teleport)
          or  queue_on_teleport
          or  (fluxus and fluxus.queue_on_teleport)
          or  (KRNL_LOADED and queue_on_teleport)
    if f then pcall(f, code) end
end
-- ví dụ: queue_on_teleport_compat([[loadstring(game:HttpGet("https://yourdomain/Init.lua"))()]])

-- ===== FPS BOOST =====
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
        elseif v:IsA("Explosion") then
            v.BlastPressure = 1; v.BlastRadius = 1
        elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("SpecialMesh") or v:IsA("SurfaceAppearance") or v:IsA("PostEffect") then
            pcall(function() v:Destroy() end)
        end
    end
    task.spawn(function()
        for _, v in ipairs(g:GetDescendants()) do optimize(v); task.wait(0.0005) end
    end)
    g.DescendantAdded:Connect(optimize)
end

-- ===== STATE =====
local strongholdTried, chestTried = {}, {}
local StrongholdCount, NormalChestCount = 0, 0

-- MinFreeSlots động
local DynamicMinFreeSlots = Config.MinFreeSlotsDefault
local MinFreeSlotsDecayAt = 0
local function getEffectiveMinFreeSlots()
    if MinFreeSlotsDecayAt > 0 and os.clock() > MinFreeSlotsDecayAt then
        DynamicMinFreeSlots = Config.MinFreeSlotsDefault
        MinFreeSlotsDecayAt = 0
    end
    return math.clamp(DynamicMinFreeSlots, Config.MinFreeSlotsDefault, Config.MinFreeSlotsCeil)
end

-- ===== VISITED / NO-REJOIN-SAME-SERVER =====
do
    getgenv().VisitedServers = getgenv().VisitedServers or { hour = -1, ids = {} }
end
local function nowHourUTC() return os.date("!*t").hour end
local function rotateVisitedIfHourChanged()
    local h = nowHourUTC()
    if getgenv().VisitedServers.hour ~= h then
        getgenv().VisitedServers.hour = h
        getgenv().VisitedServers.ids  = {}
    end
end
local function wasVisited(sid)
    rotateVisitedIfHourChanged()
    return getgenv().VisitedServers.ids[sid] == true
end
local function markVisited(sid)
    rotateVisitedIfHourChanged()
    getgenv().VisitedServers.ids[sid] = true
end

task.delay(2, function()
    pcall(function()
        if g.JobId and g.JobId ~= "" then markVisited(g.JobId) end
    end)
end)

queue_on_teleport_compat([[
    task.wait(1)
    pcall(function()
        getgenv().VisitedServers = getgenv().VisitedServers or { hour = -1, ids = {} }
        local h = os.date("!*t").hour
        if getgenv().VisitedServers.hour ~= h then
            getgenv().VisitedServers.hour = h
            getgenv().VisitedServers.ids  = {}
        end
        if game.JobId and game.JobId ~= "" then
            getgenv().VisitedServers.ids[game.JobId] = true
        end
    end)
]])

-- ===== GRACE WINDOWS =====
local JoinedFarmAt = 0
local FirstDiamondAt = 0
local function inJoinGrace() return (JoinedFarmAt > 0) and ((os.clock() - JoinedFarmAt) < Config.JoinGraceSeconds) end
local function inFirstDiamondGrace() return (FirstDiamondAt > 0) and ((os.clock() - FirstDiamondAt) < Config.FirstDiamondGrace) end

-- ===== Teleport wrapper (Async-first; fallback) =====
local function tp_to_instance(placeId, serverId)
    -- Ưu tiên TeleportAsync + TeleportOptions
    local ok, err = pcall(function()
        local TeleportOptions = Instance.new("TeleportOptions")
        TeleportOptions.ServerInstanceId = serverId
        TeleportService:TeleportAsync(placeId, { LocalPlayer }, TeleportOptions)
    end)
    if ok then return true end

    -- Fallback: TeleportToPlaceInstance
    local ok2, err2 = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, serverId, LocalPlayer)
    end)
    if ok2 then return true end

    warn("[TP] Async fail:", err, " | Fallback fail:", err2)
    return false, tostring(err2 or err)
end

-- ===== HOP CORE =====
local ConsecutiveHopFail, LastHopFailAt = 0, 0
local BadIDs = {}
local LastAttemptSID = nil
local isTeleporting = false
local HopRequested  = false

-- Chặn prompt "Teleport Failed"
local function hookTeleportErrorPrompt()
    local function bQ(v)
        if v.Name=="ErrorPrompt" then
            if v.Visible and v:FindFirstChild("TitleFrame") and v.TitleFrame:FindFirstChild("ErrorTitle") and v.TitleFrame.ErrorTitle.Text=="Teleport Failed" then
                v.Visible=false
            end
            v:GetPropertyChangedSignal("Visible"):Connect(function()
                if v.Visible and v:FindFirstChild("TitleFrame") and v.TitleFrame:FindFirstChild("ErrorTitle")
                   and v.TitleFrame.ErrorTitle.Text=="Teleport Failed" then
                    v.Visible=false
                end
            end)
        end
    end
    pcall(function()
        local overlay = game.CoreGui:WaitForChild("RobloxPromptGui",5)
        overlay = overlay and overlay:FindFirstChild("promptOverlay")
        if overlay then
            for _,v in pairs(overlay:GetChildren()) do bQ(v) end
            overlay.ChildAdded:Connect(bQ)
        end
    end)
end
hookTeleportErrorPrompt()

-- Lọc region
local function regionMatch(entry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(entry.region or entry.ping or ""):lower()
    for _, key in ipairs(Config.RegionList) do
        if raw:find(tostring(key):lower(), 1, true) then return true end
    end
    return false
end

-- Tải trang server
local function fetchServerList(cursor, sort)
    local sortOrder = sort or "Asc"
    local base = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100")
                 :format(tostring(Config.FarmPlaceId), sortOrder)
    local url  = (cursor and cursor ~= "") and (base .. "&cursor="..cursor) or base
    url = url .. "&_t=" .. HttpService:GenerateGUID(false)
    local body = http_get(url)
    if not body then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if ok and data and data.data then return data end
    return nil
end

-- Chọn phòng & Teleport
local function chooseAndTeleportFromPage(siteData, mode)
    if not siteData or not siteData.data then return false end
    local needFree = getEffectiveMinFreeSlots()
    local serverList = {}

    for _, v in pairs(siteData.data) do
        local id = tostring(v.id)
        local maxp = tonumber(v.maxPlayers or v.maxPlayerCount or 0) or 0
        local playing = tonumber(v.playing or v.playerCount or 0) or 0
        local free = maxp - playing
        if maxp > 0
           and free >= needFree
           and id ~= g.JobId
           and not wasVisited(id)
           and not BadIDs[id]
           and regionMatch(v) then
            table.insert(serverList, { id=id, players=playing, free=free, ping=tonumber(v.ping or 9999) })
        end
    end

    if mode == "Low" then
        table.sort(serverList, function(a,b)
            if a.free ~= b.free then return a.free > b.free end
            return a.players < b.players
        end)
    else
        table.sort(serverList, function(a,b)
            if a.players ~= b.players then return a.players > b.players end
            return a.free > b.free
        end)
        local filtered = {}
        for _, s in ipairs(serverList) do
            if s.players >= 5 then table.insert(filtered, s) end
        end
        if #filtered > 0 then serverList = filtered end
    end

    if #serverList == 0 then return false end

    -- tránh stampede: đảo ngẫu nhiên top 3
    if #serverList >= 3 then
        local i = math.random(1, math.min(3, #serverList))
        serverList[1], serverList[i] = serverList[i], serverList[1]
    end

    local chosen = serverList[1]
    if not chosen then return false end

    isTeleporting  = true
    LastAttemptSID = chosen.id

    task.wait(rand(Config.HopBackoffMin, Config.HopBackoffMax))
    local ok = tp_to_instance(Config.FarmPlaceId, chosen.id)
    if not ok then
        isTeleporting = false
        BadIDs[chosen.id] = true
        ConsecutiveHopFail = ConsecutiveHopFail + 1
        LastHopFailAt = os.clock()
        return false
    else
        ConsecutiveHopFail = 0
        return true
    end
end

-- Hop Classic (Asc/Desc + multi pages)
local function HopClassic(mode, reason)
    if isTeleporting then return end
    mode = mode or Config.ClassicMode

    -- Guard lobby: không hop ở lobby (lobby chỉ auto join/create)
    if g.PlaceId ~= Config.FarmPlaceId then return end

    -- Grace windows: tránh hop quá sớm trừ lý do “an toàn”
    local bypass = false
    if reason == "after-collect" or reason == "anti-dead" or reason == "retry" or reason == "locked" then
        bypass = true
    end
    if not bypass then
        if inJoinGrace() or inFirstDiamondGrace() then
            return
        end
    end

    -- cooldown khi fail liên tiếp
    if ConsecutiveHopFail >= Config.MaxConsecutiveHopFail then
        local since = os.clock() - LastHopFailAt
        if since < Config.ConsecutiveHopCooloff then
            task.wait(Config.ConsecutiveHopCooloff - since)
        end
        ConsecutiveHopFail = 0
    end

    -- Primary pass
    local cursor, sort = "", "Asc"
    for _=1, Config.MaxPagesPrimary do
        local site = fetchServerList(cursor, sort)
        if not site then break end
        if chooseAndTeleportFromPage(site, mode) then return end
        cursor = site.nextPageCursor or ""
        if not cursor or cursor == "" then break end
    end

    -- Fallback: đổi chiều
    cursor, sort = "", (mode == "Low" and "Desc" or "Asc")
    for _=1, Config.MaxPagesFallback do
        local site = fetchServerList(cursor, sort)
        if not site then break end
        if chooseAndTeleportFromPage(site, mode) then return end
        cursor = site.nextPageCursor or ""
        if not cursor or cursor == "" then break end
    end

    task.wait(1 + math.random()) -- nhường CPU, tránh spam
end

-- ===== PUBLIC HOP API =====
local function Hop(reason_or_mode)
    local mode = (reason_or_mode == "High") and "High" or "Low"
    HopClassic(mode, "manual")
end

-- Fast-hop sau collect hoặc khi lock
local function HopFast(reason)
    if isTeleporting or HopRequested then return end
    if getgenv and getgenv().PauseHop then
        local t0 = os.clock()
        while getgenv().PauseHop and os.clock()-t0 < 10 do task.wait(0.25) end
    end
    HopRequested = true
    task.spawn(function()
        task.wait(Config.HopPostDelay)
        if not isTeleporting then
            pcall(function() _G._force_hop = true end)
            -- nếu là case "locked", truyền hint để bypass grace
            local why = (reason and tostring(reason):find("locked")) and "locked" or "after-collect"
            HopClassic(Config.ClassicMode, why)
        end
        HopRequested = false
    end)
end

-- Mark visited khi teleport bắt đầu & set JoinedFarmAt khi vào map
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        if LastAttemptSID then markVisited(LastAttemptSID) end
        isTeleporting = false
    end
end)

g.Loaded:Connect(function()
    task.delay(1.0, function()
        if g.PlaceId == Config.FarmPlaceId then
            JoinedFarmAt = os.clock()
            FirstDiamondAt = 0
        end
    end)
end)

-- Bắt TeleportInitFailed → tự xử lý full / unauthorized
TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
    local rstr = tostring(result)
    warn("[Hop] TeleportInitFailed:", rstr, msg or "")

    -- Server full → nâng yêu cầu slot tạm (60s)
    if rstr:find("GameFull") or (type(msg)=="string" and msg:lower():find("requested experience is full")) then
        DynamicMinFreeSlots = math.min((DynamicMinFreeSlots or 1) + 1, Config.MinFreeSlotsCeil)
        MinFreeSlotsDecayAt = os.clock() + 60
    end
    -- Unauthorized / RequestRejected → bỏ JobId hiện tại
    if LastAttemptSID then BadIDs[LastAttemptSID] = true end

    isTeleporting = false
    ConsecutiveHopFail = ConsecutiveHopFail + 1
    LastHopFailAt = os.clock()
    task.delay(0.25, function() HopClassic(Config.ClassicMode, "retry") end)
end)

-- ===== NOCLIP =====
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local c = LocalPlayer.Character
    if not c then return end
    local on = getgenv().NoClip
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not on end
    end
end)

-- ===== MOVE =====
local function tpCFrame(cf)
    local r = HRP()
    if r then r.CFrame = cf end
end

-- ===== DIAMOND HELPERS =====
local function diamondsLeft()
    local items = workspace:FindFirstChild("Items")
    if not items then return false end
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then return true end
    end
    return false
end

local function waitNoDiamonds(timeout)
    local t0 = os.clock()
    local limit = timeout or 1.2
    while (os.clock() - t0) < limit do
        if not diamondsLeft() then return true end
        task.wait(0.1)
    end
    return not diamondsLeft()
end

local function collectAllDiamonds()
    local n = 0
    local items = workspace:FindFirstChild("Items")
    if not items then return 0 end
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then
            pcall(function()
                local ev = RS:FindFirstChild("RemoteEvents")
                local re = ev and ev:FindFirstChild("RequestTakeDiamonds")
                if re and re.FireServer then
                    re:FireServer(v)
                    n = n + 1
                end
            end)
        end
    end
    -- Ghi nhận lần đầu nhặt kim cương → kích hoạt FirstDiamondGrace
    if n > 0 and FirstDiamondAt == 0 then
        FirstDiamondAt = os.clock()
    end
    return n
end

-- ===== FINDERS / PROMPTS =====
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
    local r = HRP(); if not r then return nil end
    local closest, dist
    local items = workspace:FindFirstChild("Items"); if not items then return nil end
    for _, v in ipairs(items:GetChildren()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local id = v:GetDebugId()
            if not chestTried[id] then
                local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prox and prox.Enabled then
                    local pv = v:GetPivot()
                    local d = (r.Position - pv.Position).Magnitude
                    if not dist or d < dist then closest, dist = v, d end
                end
            end
        end
    end
    return closest
end

local function firePromptSafe(prompt)
    if typeof(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(prompt, 1) end)
    else
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and prompt and prompt.HoldDuration == 0 then
                hum:MoveTo(prompt.Parent and prompt.Parent.Position or (HRP() and HRP().Position))
            end
        end)
    end
end

local function pressPromptWithTimeout(prompt, timeout)
    local t0 = os.clock()
    local limit = timeout or 6
    while prompt and prompt.Parent and prompt.Enabled and (os.clock()-t0) < limit do
        firePromptSafe(prompt)
        task.wait(0.3)
    end
    return not (prompt and prompt.Parent and prompt.Enabled)
end

local function waitDiamonds(timeout)
    local t0 = os.clock()
    local limit = timeout or 2.0
    while (os.clock()-t0) < limit do
        local items = workspace:FindFirstChild("Items")
        if items and items:FindFirstChild("Diamond") then return true end
        task.wait(0.2)
    end
    return false
end

-- ===== AUTO JOIN / CREATE (Lobby-only) =====
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
                    if enter and HRP() then tpCFrame(enter.CFrame + Vector3.new(0, 3, 0)); joined = true; break end
                end
            end
        end
    end
    if not joined then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
                local enter = obj:FindFirstChildWhichIsA("BasePart")
                if enter and HRP() then tpCFrame(enter.CFrame + Vector3.new(0, 3, 0)); break end
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

-- ===== ANTI-DEAD =====
local IsDead, DeadSince = false, 0

local function hasDeadUi()
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return false end
    local lower = string.lower
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local t = tostring(gui.Text or ""):gsub("%s+", " ")
            for _, k in ipairs(Config.DeadUiKeywords) do
                if lower(t):find(lower(k), 1, true) then return true end
            end
        end
    end
    return false
end

local function bindDeathWatcher(char)
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    hum.Died:Connect(function()
        IsDead = true
        DeadSince = os.clock()
    end)
end

if LocalPlayer.Character then bindDeathWatcher(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(c)
    IsDead = false
    DeadSince = 0
    task.wait(0.5)
    bindDeathWatcher(c)
    if g.PlaceId == Config.FarmPlaceId then
        JoinedFarmAt = os.clock()
        FirstDiamondAt = 0
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if g.PlaceId == Config.FarmPlaceId then
            if (IsDead or hasDeadUi()) then
                if DeadSince == 0 then DeadSince = os.clock() end
                if (os.clock() - DeadSince) >= Config.DeadHopTimeout then
                    HopFast("anti-dead")
                end
            end
        end
    end
end)

-- ===== MAIN FARM =====
task.spawn(function()
    while task.wait(Config.FarmTick) do
        if g.PlaceId == Config.FarmPlaceId then
            WaitForChar()

            -- 1) Stronghold (KHÔNG mở được -> Hop ngay)
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
                            strongholdTried[sid] = true
                            HopFast("stronghold-locked")
                        else
                            if waitDiamonds(Config.StrongholdDiamondWait) then
                                collectAllDiamonds()
                                waitNoDiamonds(1.1)
                                StrongholdCount = StrongholdCount + 1
                                if Config.HopAfterStronghold then
                                    HopFast("after-stronghold-collect")
                                end
                            else
                                strongholdTried[sid] = true
                                HopFast("stronghold-no-diamonds")
                            end
                        end
                    else
                        strongholdTried[sid] = true
                    end
                end
            end

            -- 2) Chest thường (KHÔNG mở được -> Hop ngay)
            local chest = findUsableChest()
            if not chest then
                Hop("Low")
            else
                local id   = chest:GetDebugId()
                local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                local t0   = os.clock()
                local okOpen = false

                while prox and prox.Parent and prox.Enabled and (os.clock() - t0) < 10 do
                    tpCFrame(CFrame.new(chest:GetPivot().Position))
                    firePromptSafe(prox)
                    task.wait(0.45)
                    prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                end

                if not (prox and prox.Parent and prox.Enabled) then
                    okOpen = true
                end

                if okOpen then
                    NormalChestCount = NormalChestCount + 1
                    collectAllDiamonds()
                    waitNoDiamonds(1.0)
                    if Config.HopAfterNormalChest then
                        HopFast("after-normalchest-collect")
                    end
                else
                    chestTried[id] = true
                    HopFast("chest-locked")
                end
            end
        end
    end
end)

-- 3) Diamonds song song (nhẹ, không spam)
task.spawn(function()
    while task.wait(Config.DiamondTick) do
        if g.PlaceId == Config.FarmPlaceId then
            collectAllDiamonds()
        end
    end
end)

-- ===== OPTIONAL OVERLAY (đếm diamond GUI) =====
task.spawn(function()
    local a = Instance.new("ScreenGui")
    a.Name = "gg"
    a.ResetOnSpawn = false
    a.IgnoreGuiInset = true
    a.Parent = game:GetService("CoreGui")

    local b = Instance.new("Frame", a)
    b.Size = UDim2.new(1, 0, 1, 0)
    b.BackgroundTransparency = 1
    b.BorderSizePixel = 0

    local d = Instance.new("UIStroke", b); d.Thickness = 2
    local function rainbowStroke(stroke)
        task.spawn(function()
            while task.wait() do
                for i = 0, 1, 0.02 do
                    stroke.Color = Color3.fromHSV(i, 1, 1)
                    task.wait(0.03)
                end
            end
        end)
    end
    rainbowStroke(d)

    local e = Instance.new("TextLabel", b)
    e.Size = UDim2.new(1, 0, 1, 0)
    e.BackgroundTransparency = 1
    e.Text = "0"
    e.TextColor3 = Color3.fromRGB(255, 255, 255)
    e.Font = Enum.Font.GothamBold
    e.TextScaled = true
    e.TextStrokeTransparency = 0.6

    while task.wait(0.2) do
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg and pg:FindFirstChild("Interface")
               and pg.Interface:FindFirstChild("DiamondCount")
               and pg.Interface.DiamondCount:FindFirstChild("Count") then
            local lab = pg.Interface.DiamondCount.Count
            if lab and lab:IsA("TextLabel") then
                e.Text = lab.Text
            end
        end
    end
end)
