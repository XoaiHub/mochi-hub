-- ===================== HOTFIX: FORCE HOP ANYWAY =====================
-- Đặt sau CONFIG, trước các định nghĩa Hop cũ để override:

local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local TeleportService = g:GetService("TeleportService")
local HttpService     = g:GetService("HttpService")

-- Trạng thái chung (nếu bản cũ đã có, dùng lại):
local PlaceID = g.PlaceId
local isTeleporting  = false
local LastAttemptSID = nil
local BadIDs         = BadIDs or {}
local AllIDs         = AllIDs or {}
local ConsecutiveHopFail = ConsecutiveHopFail or 0
local LastHopFailAt      = LastHopFailAt or 0
local SortAsc            = SortAsc or false
local cursor             = cursor or ""
local HopRequested       = HopRequested or false

-- Bổ sung tham số hotfix:
local HOTFIX = {
    PostVerifyWait         = Config.PostTeleportVerifyWait or 6,
    HardStuckTimeout       = 30,  -- sau khi phát lệnh hop 30s mà chưa rời JobId => ép random hop
    LowerBarPages          = 4,   -- số trang thử lại khi hạ yêu cầu slot
    RandomHopBackoff       = 1.0, -- delay rất ngắn trước khi random hop
    CooloffOnSpam          = 4.0, -- nghỉ tí khi spam fail
}

-- Dùng lại getEffectiveMinFreeSlots nếu có:
local function _getMinFreeSlots()
    if typeof(getEffectiveMinFreeSlots) == "function" then
        return getEffectiveMinFreeSlots()
    end
    return (Config.MinFreeSlotsDefault or 1)
end

-- Fallback: random hop sang public server bất kỳ của cùng Place
local function _random_hop(reason)
    if isTeleporting then return end
    isTeleporting = true
    local beforeJob = g.JobId
    warn("[HOTFIX][RandomHop]", reason or "")
    task.wait(HOTFIX.RandomHopBackoff)
    local ok, err = pcall(function()
        -- Teleport(placeId) → Roblox chọn 1 public server (thường khác JobId)
        TeleportService:Teleport(Config.FarmPlaceId, LocalPlayer)
    end)
    -- Post-verify: nếu vẫn ở cùng JobId sau vài giây -> coi như fail
    task.delay(HOTFIX.PostVerifyWait, function()
        if g.JobId == beforeJob then
            warn("[HOTFIX] RandomHop post-verify FAILED (still same JobId).")
            isTeleporting = false
            ConsecutiveHopFail += 1
            LastHopFailAt = os.clock()
        end
    end)
    return ok
end

-- Bọc Teleport tới 1 instance cụ thể: nếu fail → đánh dấu bad và trả false
local function _tp_to_instance(placeId, serverId)
    local beforeJob = g.JobId
    local okAsync, errA = pcall(function()
        local TeleportOptions = Instance.new("TeleportOptions")
        TeleportOptions.ServerInstanceId = serverId
        TeleportService:TeleportAsync(placeId, { LocalPlayer }, TeleportOptions)
    end)
    if okAsync then
        task.delay(HOTFIX.PostVerifyWait, function()
            if g.JobId == beforeJob then
                -- coi như fail
                BadIDs[serverId] = true
                isTeleporting = false
                ConsecutiveHopFail += 1
                LastHopFailAt = os.clock()
            end
        end)
        return true
    end

    local okFB, errB = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, serverId, LocalPlayer)
    end)
    if okFB then
        task.delay(HOTFIX.PostVerifyWait, function()
            if g.JobId == beforeJob then
                BadIDs[serverId] = true
                isTeleporting = false
                ConsecutiveHopFail += 1
                LastHopFailAt = os.clock()
            end
        end)
        return true
    end

    warn("[HOTFIX] tp_to_instance failed:", errA, errB)
    return false
end

-- Thay thế tryFindAndTeleport với 2 pha:
--  (A) yêu cầu slot bình thường
--  (B) nếu không có → hạ yêu cầu slot về 0 và thử vài trang
local function _fetch_page(nextCursor, sortAsc)
    local sortOrder = sortAsc and "Asc" or "Desc"
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100")
        :format(PlaceID, sortOrder)
    if nextCursor and nextCursor ~= "" then
        url = url .. "&cursor=" .. nextCursor
    end
    url = url .. "&_t=" .. HttpService:GenerateGUID(false)
    local ok, body = pcall(function() return (game:HttpGet(url)) end)
    if not ok or not body or #body==0 then return nil end
    local ok2, data = pcall(function() return game:GetService("HttpService"):JSONDecode(body) end)
    if not ok2 then return nil end
    return data
end

local function _pick_and_tp_from_page(page, needFree, localJob)
    if not page or not page.data then return false end
    local candidates = {}
    for _, v in ipairs(page.data) do
        local sid     = tostring(v.id)
        local playing = tonumber(v.playing)
        local maxp    = tonumber(v.maxPlayers)
        if playing and maxp then
            local free = maxp - playing
            if free >= needFree and sid ~= localJob and not BadIDs[sid] and not AllIDs[sid] then
                table.insert(candidates, {sid=sid, free=free, playing=playing})
            end
        end
    end
    table.sort(candidates, function(a,b)
        if a.free ~= b.free then return a.free > b.free end
        return a.playing < b.playing
    end)
    if #candidates >= 3 then
        local i = math.random(1, math.min(3, #candidates))
        candidates[1], candidates[i] = candidates[i], candidates[1]
    end
    for _, c in ipairs(candidates) do
        local sid = c.sid
        AllIDs[sid]   = true
        isTeleporting = true
        LastAttemptSID= sid
        task.wait(math.random() * 0.75 + 0.5) -- backoff nhẹ
        local ok = _tp_to_instance(PlaceID, sid)
        if not ok then
            isTeleporting = false
            BadIDs[sid]   = true
            ConsecutiveHopFail += 1
            LastHopFailAt = os.clock()
        else
            ConsecutiveHopFail = 0
        end
        return true
    end
    return false
end

local function _try_pages(maxPages, needFree)
    local pagesTried = 0
    local localJob   = g.JobId
    while pagesTried < maxPages do
        local page = _fetch_page(cursor, SortAsc)
        cursor = (page and page.nextPageCursor) or ""
        pagesTried += 1
        if _pick_and_tp_from_page(page, needFree, localJob) then
            return true
        end
    end
    SortAsc = not SortAsc
    cursor  = ""
    return false
end

-- ############ OVERRIDE HOP ############
function Hop(reason)
    if isTeleporting then return end

    -- spam-protection khi fail liên tục
    if ConsecutiveHopFail >= (Config.MaxConsecutiveHopFail or 5) then
        local since = os.clock() - (LastHopFailAt or 0)
        if since < HOTFIX.CooloffOnSpam then
            task.wait(HOTFIX.CooloffOnSpam - since)
        end
        ConsecutiveHopFail = 0
    end

    warn("[HOTFIX][Hop]", reason or "")

    local needFree = _getMinFreeSlots()
    -- (A) Thử hop với yêu cầu slot bình thường
    local ok = _try_pages((Config.MaxPagesPrimary or 8), needFree)
    if ok then
        -- hard watchdog: nếu 30s sau vẫn chưa rời JobId cũ -> ép random hop
        local baseJob = g.JobId
        task.delay(HOTFIX.HardStuckTimeout, function()
            if g.JobId == baseJob then
                isTeleporting = false
                warn("[HOTFIX] Hard-stuck after targeted hop -> force random hop")
                _random_hop("hard-stuck-after-targeted")
            end
        end)
        return
    end

    -- (B) Không có server phù hợp → hạ yêu cầu slot về 0 và thử vài trang
    ok = _try_pages(HOTFIX.LowerBarPages, 0)
    if ok then
        local baseJob = g.JobId
        task.delay(HOTFIX.HardStuckTimeout, function()
            if g.JobId == baseJob then
                isTeleporting = false
                warn("[HOTFIX] Hard-stuck after lower-bar hop -> force random hop")
                _random_hop("hard-stuck-lowerbar")
            end
        end)
        return
    end

    -- (C) Vẫn không được → random hop
    isTeleporting = false
    _random_hop("no-candidate-use-random")
end

-- TeleportInitFailed: đẩy sang random hop ngay nếu cần
TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
    warn("[HOTFIX] TeleportInitFailed:", tostring(result), msg or "")
    isTeleporting = false
    ConsecutiveHopFail += 1
    LastHopFailAt = os.clock()
    task.delay(0.25, function()
        -- tăng ngưỡng slot tạm thời nếu full
        local m = (msg or ""):lower()
        if m:find("full") or tostring(result):find("GameFull") then
            if Config.MinFreeSlotsCeil and Config.MinFreeSlotsDefault then
                -- không đụng tới biến động cũ; fallback sang random cho nhanh
            end
        end
        Hop("init-failed")
    end)
end)
-- =================== END HOTFIX: FORCE HOP ANYWAY ===================


