-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI)
-- + CHỈ hop sau khi NHẶT XONG gems (Stronghold & Chest thường)
-- + Fix FULL lỗi Prompt: không còn 'attempt to index nil with FindFirstChild'
-- + Skip server full (tăng slot tạm), no-rejoin-same-server (VisitedServers UTC)
-- + Anti-DEAD, Region filter, TeleportAsync→fallback, Wave/PC safe
-- ================================================================

-- ========== CONFIG ==========
local Config = {
    RegionFilterEnabled     = false,
    RegionList              = { "singapore", "tokyo", "us-east" },

    RetryHttpDelay          = 2,

    StrongholdChestName     = "Stronghold Diamond Chest",
    StrongholdPromptTime    = 6,     -- thời gian cố mở stronghold
    StrongholdDiamondWait   = 10,    -- chờ diamond spawn sau mở stronghold
    NormalChestPromptTime   = 10,    -- thời gian cố mở chest thường

    FarmPlaceId             = 126509999114328,
    LobbyCheckInterval      = 2.0,
    FarmTick                = 1.0,
    DiamondTick             = 0.35,

    HopBackoffMin           = 1.5,
    HopBackoffMax           = 3.0,
    HopPostDelay            = 0.20,
    NoChestGraceSeconds     = 6.0,   -- không thấy chest liên tục ≥ N giây mới hop

    DeadHopTimeout          = 6.0,
    DeadUiKeywords          = { "dead", "you died", "respawn", "revive" },

    MaxConsecutiveHopFail   = 5,
    ConsecutiveHopCooloff   = 6.0,
    MaxPagesPrimary         = 8,
    MaxPagesFallback        = 12,
    TeleportFailBackoffMax  = 8,

    MinFreeSlotsDefault     = 1,     -- tối thiểu slot trống
    MinFreeSlotsCeil        = 3,     -- có thể tăng tạm khi gặp GameFull

    ClassicMode             = "Low"  -- "Low" (ít người) hoặc "High" (đông người ≥5)
}

-- ========== SERVICES ==========
local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RS              = g:GetService("ReplicatedStorage")
local RunService      = g:GetService("RunService")
local HttpService     = g:GetService("HttpService")
local TeleportService = g:GetService("TeleportService")

-- ========== UTILS ==========
local function WaitForChar(timeout)
    timeout = timeout or 15
    local t = 0
    while t < timeout do
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChild("Humanoid") then
            return c
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

-- ========== FPS BOOST (SAFE: KHÔNG đụng UI/Prompt) ==========
do
    local function optimize(v)
        -- Không đụng ProximityPrompt/UI/Attachment/PlayerScripts/PlayerGui
        if v:IsA("BillboardGui") or v:IsA("SurfaceGui") or v:IsA("ProximityPrompt")
           or v:IsA("Attachment") or v:IsA("ProximityPromptService") then
            return
        end
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
            if v:IsDescendantOf(workspace) or v:IsDescendantOf(g.Lighting) then
                pcall(function() v:Destroy() end)
            end
        end
    end

    g.Lighting.GlobalShadows = false
    g.Lighting.Brightness = 0
    g.Lighting.FogEnd = 1e10
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)

    local function apply(root)
        for _, v in ipairs(root:GetDescendants()) do
            optimize(v); task.wait(0.0005)
        end
        root.DescendantAdded:Connect(optimize)
    end
    apply(workspace)
    apply(g.Lighting)
end

-- ========== STATE ==========
local PlaceID = g.PlaceId
local strongholdTried, chestTried = {}, {}
local StrongholdCount, NormalChestCount = 0, 0

-- Cửa an toàn hop: chỉ hop khi KHÔNG collecting
local State = {
    Collecting     = false,
    PendingHop     = nil,
    LastCollectAt  = 0,
    LastNoChestAt  = 0,
}
local function BeginCollect() State.Collecting = true end
local function EndCollect()
    State.Collecting = false
    State.LastCollectAt = os.clock()
    if State.PendingHop then
        local mode = State.PendingHop; State.PendingHop = nil
        task.defer(function() task.wait(Config.HopPostDelay); _G.__HOP_IMPL(mode) end)
    end
end

-- MinFreeSlots động (tăng tạm khi GameFull)
local DynamicMinFreeSlots = Config.MinFreeSlotsDefault
local MinFreeSlotsDecayAt = 0
local function getEffectiveMinFreeSlots()
    if MinFreeSlotsDecayAt > 0 and os.clock() > MinFreeSlotsDecayAt then
        DynamicMinFreeSlots = Config.MinFreeSlotsDefault
        MinFreeSlotsDecayAt = 0
    end
    return math.clamp(DynamicMinFreeSlots, Config.MinFreeSlotsDefault, Config.MinFreeSlotsCeil)
end

-- ========== Teleport wrapper ==========
local function tp_to_instance(placeId, serverId)
    local ok, err = pcall(function()
        local TeleportOptions = Instance.new("TeleportOptions")
        TeleportOptions.ServerInstanceId = serverId
        TeleportService:TeleportAsync(placeId, { LocalPlayer }, TeleportOptions)
    end)
    if ok then return true end
    local ok2, err2 = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, serverId, LocalPlayer)
    end)
    if ok2 then return true end
    warn("[TP] Async fail:", err, " | Fallback fail:", err2)
    return false, tostring(err2 or err)
end

-- ========== VISITED / NO-REJOIN-SAME-SERVER ==========
do getgenv().VisitedServers = getgenv().VisitedServers or { hour = -1, ids = {} } end
local function nowHourUTC() return os.date("!*t").hour end
local function rotateVisitedIfHourChanged()
    local h = nowHourUTC()
    if getgenv().VisitedServers.hour ~= h then
        getgenv().VisitedServers.hour = h
        getgenv().VisitedServers.ids  = {}
    end
end
local function wasVisited(sid) rotateVisitedIfHourChanged(); return getgenv().VisitedServers.ids[sid] == true end
local function markVisited(sid) rotateVisitedIfHourChanged(); getgenv().VisitedServers.ids[sid] = true end
task.delay(2, function() pcall(function() if g.JobId and g.JobId ~= "" then markVisited(g.JobId) end end) end)
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

-- ========== REGION FILTER ==========
local function regionMatch(entry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(entry.region or entry.ping or ""):lower()
    for _, key in ipairs(Config.RegionList) do
        if raw:find(tostring(key):lower(), 1, true) then return true end
    end
    return false
end

-- ========== HOP ENGINE (classic + gia cố) ==========
local ConsecutiveHopFail, LastHopFailAt = 0, 0
local BadIDs = {}
local LastAttemptSID = nil
local isTeleporting = false
local HopRequested  = false

-- Ẩn "Teleport Failed"
local function hookTeleportErrorPrompt()
    local function bQ(v)
        if v.Name=="ErrorPrompt" then
            local ok,title = pcall(function() return v.TitleFrame.ErrorTitle.Text end)
            if v.Visible and ok and title=="Teleport Failed" then v.Visible=false end
            v:GetPropertyChangedSignal("Visible"):Connect(function()
                local ok2,t2 = pcall(function() return v.TitleFrame.ErrorTitle.Text end)
                if v.Visible and ok2 and t2=="Teleport Failed" then v.Visible=false end
            end)
        end
    end
    pcall(function()
        local gui = game.CoreGui:FindFirstChild("RobloxPromptGui")
        local overlay = gui and gui:FindFirstChild("promptOverlay")
        if overlay then
            for _,c in ipairs(overlay:GetChildren()) do bQ(c) end
            overlay.ChildAdded:Connect(bQ)
        end
    end)
end
hookTeleportErrorPrompt()

local function fetchServerList(cursor, sort)
    local sortOrder = sort or "Asc"
    local base = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100"):format(PlaceID, sortOrder)
    local url  = cursor and cursor ~= "" and (base .. "&cursor="..cursor) or base
    url = url .. "&_t=" .. HttpService:GenerateGUID(false)
    local body = http_get(url); if not body then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if ok and data and data.data then return data end
    return nil
end

local function getEffectiveMinFreeSlots() -- re-declare for locality in this block (same func above is used too)
    if MinFreeSlotsDecayAt > 0 and os.clock() > MinFreeSlotsDecayAt then
        DynamicMinFreeSlots = Config.MinFreeSlotsDefault
        MinFreeSlotsDecayAt = 0
    end
    return math.clamp(DynamicMinFreeSlots, Config.MinFreeSlotsDefault, Config.MinFreeSlotsCeil)
end

local function chooseAndTeleportFromPage(siteData, mode)
    if not siteData or not siteData.data then return false end
    local needFree = getEffectiveMinFreeSlots()
    local serverList = {}

    for _, v in pairs(siteData.data) do
        local id = tostring(v.id)
        local maxp = tonumber(v.maxPlayers or v.maxPlayerCount or 0) or 0
        local playing = tonumber(v.playing or v.playerCount or 0) or 0
        local free = maxp - playing
        if maxp > 0 and free >= needFree and id ~= g.JobId
           and not wasVisited(id) and not BadIDs[id] and regionMatch(v) then
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
        for _, s in ipairs(serverList) do if s.players >= 5 then table.insert(filtered, s) end end
        if #filtered > 0 then serverList = filtered end
    end

    if #serverList == 0 then return false end
    if #serverList >= 3 then
        local i = math.random(1, math.min(3, #serverList))
        serverList[1], serverList[i] = serverList[i], serverList[1]
    end

    local chosen = serverList[1]; if not chosen then return false end
    isTeleporting  = true
    LastAttemptSID = chosen.id

    task.wait(rand(Config.HopBackoffMin, Config.HopBackoffMax))
    local ok = tp_to_instance(PlaceID, chosen.id)
    if not ok then
        isTeleporting = false
        BadIDs[chosen.id] = true
        ConsecutiveHopFail += 1
        LastHopFailAt = os.clock()
        return false
    else
        ConsecutiveHopFail = 0
        return true
    end
end

_G.__HOP_IMPL = function(mode)
    if isTeleporting then return end
    mode = (mode == "High") and "High" or "Low"

    if ConsecutiveHopFail >= Config.MaxConsecutiveHopFail then
        local since = os.clock() - LastHopFailAt
        if since < Config.ConsecutiveHopCooloff then
            task.wait(Config.ConsecutiveHopCooloff - since)
        end
        ConsecutiveHopFail = 0
    end

    local cursor, sort = "", "Asc"
    for _=1, Config.MaxPagesPrimary do
        local site = fetchServerList(cursor, sort)
        if not site then break end
        if chooseAndTeleportFromPage(site, mode) then return end
        cursor = site.nextPageCursor or ""
        if not cursor or cursor == "" then break end
    end

    cursor, sort = "", (mode == "Low" and "Desc" or "Asc")
    for _=1, Config.MaxPagesFallback do
        local site = fetchServerList(cursor, sort)
        if not site then break end
        if chooseAndTeleportFromPage(site, mode) then return end
        cursor = site.nextPageCursor or ""
        if not cursor or cursor == "" then break end
    end

    task.wait(1 + math.random())
end

-- Yêu cầu hop: nếu đang collecting → xếp hàng
local function requestHop(mode_or_reason)
    local mode = (mode_or_reason == "High") and "High" or "Low"
    if State.Collecting then State.PendingHop = mode; return end
    _G.__HOP_IMPL(mode)
end

local function Hop(mode_or_reason) requestHop(mode_or_reason or Config.ClassicMode) end
local function HopFast()
    if isTeleporting or HopRequested then return end
    HopRequested = true
    task.spawn(function()
        task.wait(Config.HopPostDelay)
        requestHop(Config.ClassicMode)
        HopRequested = false
    end)
end

LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        if LastAttemptSID then markVisited(LastAttemptSID) end
        isTeleporting = false
    end
end)

TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
    local rstr = tostring(result)
    warn("[Hop] TeleportInitFailed:", rstr, msg or "")
    if rstr:find("GameFull") or (type(msg)=="string" and msg:lower():find("requested experience is full")) then
        DynamicMinFreeSlots = math.min((DynamicMinFreeSlots or 1) + 1, Config.MinFreeSlotsCeil)
        MinFreeSlotsDecayAt = os.clock() + 60
    end
    if LastAttemptSID then BadIDs[LastAttemptSID] = true end
    isTeleporting = false
    ConsecutiveHopFail += 1
    LastHopFailAt = os.clock()
    requestHop(Config.ClassicMode)
end)

-- ========== NOCLIP ==========
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local c = LocalPlayer.Character
    if not c then return end
    local on = getgenv().NoClip
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not on end
    end
end)

-- ========== MOVE ==========
local function tpCFrame(cf) local r = HRP(); if r then r.CFrame = cf end end

-- ========== DIAMOND HELPERS ==========
local function diamondsLeft()
    local items = workspace:FindFirstChild("Items")
    if not items then return false end
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then return true end
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

local function countDiamonds()
    local items = workspace:FindFirstChild("Items")
    if not items then return 0 end
    local n = 0
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then n += 1 end
    end
    return n
end

local function collectAllDiamonds()
    local n = 0
    local items = workspace:FindFirstChild("Items")
    if not items then return 0 end
    for _, v in ipairs(items:GetChildren()) do
        if v.Name == "Diamond" then
            pcall(function()
                local ev = RS:FindFirstChild("RemoteEvents")
                local re = ev and (ev:FindFirstChild("RequestTakeDiamonds") or ev:FindFirstChildWhichIsA("RemoteEvent"))
                if re and re.FireServer then re:FireServer(v); n += 1 end
            end)
        end
    end
    return n
end

-- ========== PROMPTS (SAFE) ==========
-- Luôn lấy lại prompt từ chest để tránh dùng tham chiếu cũ → nil
local function getPromptFromChest(chest)
    if not chest or not chest:IsDescendantOf(workspace) then return nil end
    local main = chest:FindFirstChild("Main")
    if main then
        local attach = main:FindFirstChild("ProximityAttachment")
        if attach then
            local p = attach:FindFirstChild("ProximityInteraction")
            if p and p:IsA("ProximityPrompt") then return p end
        end
    end
    return chest:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function firePromptSafe(prompt)
    if not (prompt and prompt.Parent and prompt:IsDescendantOf(workspace) and prompt.Enabled) then return false end
    if typeof(fireproximityprompt) == "function" then
        return pcall(function() fireproximityprompt(prompt, 1) end)
    end
    return false
end

local function pressPromptWithTimeout(chest, timeout)
    local t0 = tick()
    while (tick()-t0) < (timeout or 6) do
        local prox = getPromptFromChest(chest)
        if not (prox and prox.Enabled) then return true end -- đã mở
        if not firePromptSafe(prox) then break end
        task.wait(0.3)
    end
    local prox2 = getPromptFromChest(chest)
    return not (prox2 and prox2.Enabled) -- true nếu mở xong
end

-- ========== FINDERS ==========
local function findStrongholdChest()
    local items = workspace:FindFirstChild("Items")
    if not items then return nil end
    return items:FindFirstChild(Config.StrongholdChestName)
end

local function findUsableChest()
    local r = HRP(); if not r then return nil end
    local closest, dist
    local items = workspace:FindFirstChild("Items"); if not items then return nil end
    for _, v in ipairs(items:GetChildren()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local id = v:GetDebugId()
            if not chestTried[id] then
                local prox = getPromptFromChest(v)
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

-- ========== AUTO JOIN / CREATE (Lobby) ==========
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
        if g.PlaceId ~= Config.FarmPlaceId then pcall(autoJoinOrCreate) end
    end
end)

-- ========== ANTI-DEAD ==========
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
    hum.Died:Connect(function() IsDead = true; DeadSince = tick() end)
end
if LocalPlayer.Character then bindDeathWatcher(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(c)
    IsDead = false; DeadSince = 0; task.wait(0.5); bindDeathWatcher(c)
end)
task.spawn(function()
    while task.wait(0.5) do
        if g.PlaceId ~= Config.FarmPlaceId then continue end
        if not IsDead and not hasDeadUi() then continue end
        if DeadSince == 0 then DeadSince = tick() end
        if tick() - DeadSince >= Config.DeadHopTimeout then
            requestHop(Config.ClassicMode) -- vẫn tôn trọng Collecting
        end
    end
end)

-- ========== MAIN FARM ==========
task.spawn(function()
    while task.wait(Config.FarmTick) do
        if g.PlaceId ~= Config.FarmPlaceId then continue end
        WaitForChar()

        -- 1) Stronghold (rương 5 gems) — mở được → phải nhặt xong mới hop
        local sh = findStrongholdChest()
        if sh then
            local sid = sh:GetDebugId()
            if not strongholdTried[sid] then
                local prox = getPromptFromChest(sh)
                if not (prox and prox.Enabled) then
                    strongholdTried[sid] = true
                    warn("[Stronghold] Locked/no prompt → requestHop")
                    requestHop("Low")
                else
                    tpCFrame(CFrame.new(sh:GetPivot().Position + Vector3.new(0,3,0)))
                    local opened = pressPromptWithTimeout(sh, Config.StrongholdPromptTime)
                    if opened then
                        local seen = (function()
                            local t0 = tick()
                            while (tick()-t0) < Config.StrongholdDiamondWait do
                                if diamondsLeft() then return true end
                                task.wait(0.2)
                            end
                            return false
                        end)()
                        if not seen then
                            strongholdTried[sid] = true
                            warn("[Stronghold] Opened but no diamonds spawned → requestHop")
                            requestHop("Low")
                        else
                            BeginCollect()
                            local before = countDiamonds()
                            local got    = collectAllDiamonds()
                            waitNoDiamonds(1.2)
                            local after  = countDiamonds()
                            EndCollect()
                            if got > 0 or after < before or after == 0 then
                                StrongholdCount += 1
                                requestHop("Low")
                            else
                                strongholdTried[sid] = true
                                warn("[Stronghold] Diamonds not collectible → requestHop")
                                requestHop("Low")
                            end
                        end
                    else
                        strongholdTried[sid] = true
                        warn("[Stronghold] Prompt timeout/locked → requestHop")
                        requestHop("Low")
                    end
                end
            end
        end

        -- 2) Chest thường — nhặt xong mới hop; khóa/timeout → hop
        local chest = findUsableChest()
        if not chest then
            if State.LastNoChestAt == 0 then State.LastNoChestAt = os.clock() end
            if (os.clock() - State.LastNoChestAt) >= Config.NoChestGraceSeconds then
                if not State.Collecting then requestHop("Low") end
                State.LastNoChestAt = 0
            end
        else
            State.LastNoChestAt = 0
            local id = chest:GetDebugId()
            local prox = getPromptFromChest(chest)
            if not (prox and prox.Enabled) then
                chestTried[id] = true
                warn("[Chest] Locked/no prompt → requestHop")
                requestHop("Low")
            else
                local opened = pressPromptWithTimeout(chest, Config.NormalChestPromptTime)
                if opened then
                    BeginCollect()
                    local before = countDiamonds()
                    local got    = collectAllDiamonds()
                    waitNoDiamonds(1.0)
                    local after  = countDiamonds()
                    EndCollect()
                    if got > 0 or after < before or after == 0 then
                        NormalChestCount += 1
                        requestHop("Low")
                    else
                        chestTried[id] = true
                        warn("[Chest] Diamonds not collectible/none spawned → requestHop")
                        requestHop("Low")
                    end
                else
                    chestTried[id] = true
                    warn("[Chest] Prompt timeout/cannot open → requestHop")
                    requestHop("Low")
                end
            end
        end
    end
end)

-- 3) Diamonds song song (nhặt nền, KHÔNG tự hop)
task.spawn(function()
    while task.wait(Config.DiamondTick) do
        if g.PlaceId == Config.FarmPlaceId then collectAllDiamonds() end
    end
end)

-- ========== OPTIONAL OVERLAY (đếm diamond GUI) ==========
task.spawn(function()
    local a = Instance.new("ScreenGui", game:GetService("CoreGui")); a.Name = "gg"
    local b = Instance.new("Frame", a); b.Size = UDim2.new(1, 0, 1, 0); b.BackgroundTransparency = 1; b.BorderSizePixel = 0
    local d = Instance.new("UIStroke", b); d.Thickness = 2
    local function rainbowStroke(stroke)
        task.spawn(function()
            while task.wait() do
                for i = 0, 1, 0.01 do
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
            if lab:IsA("TextLabel") then e.Text = lab.Text end
        end
    end
end)


