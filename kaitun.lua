-- ================== HOP SERVER API (NEW, drop-in) ==================
-- Giữ nguyên STATE, no-rejoin-same-server, tránh full, đa host, có excludeFullGames
-- Không sửa các chức năng farm/GUI/noclip của bạn – chỉ thay lớp chọn server & teleport

local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players         = game:GetService("Players")
local LP              = Players.LocalPlayer

-- Reuse/extend STATE nếu đã tồn tại
_STATE = _STATE or {}
local STATE = _STATE
STATE.BusyTeleport = false
STATE.Visited = STATE.Visited or {}        -- jobId -> lastSeenTime
STATE.VisitedTTL = 6 * 3600                -- 6 giờ không quay lại server cũ

-- ========= Helpers =========
local function now() return os.time() end

local function vacancy(sv)
    -- Chuẩn hoá số liệu
    local maxp = tonumber(sv.maxPlayers or sv.maxPlayerCount or sv.maximumPlayerCount or 0) or 0
    local playing = tonumber(sv.playing or sv.playerCount or sv.currentPlayers or 0) or 0
    local open = math.max(0, maxp - playing)
    return open, playing, maxp
end

local function notVisited(jobId)
    if not jobId or jobId == "" then return false end
    if jobId == game.JobId then return false end
    local t = STATE.Visited[jobId]
    if t and (now() - t) <= (STATE.VisitedTTL or 21600) then return false end
    return true
end

local function markVisited(jobId)
    if jobId and jobId ~= "" then
        STATE.Visited[jobId] = now()
    end
end

local http_request = rawget(getfenv(), "http_request")
                  or rawget(getfenv(), "request")
                  or (rawget(getfenv(), "syn") and syn.request)
                  or (http and http.request)

local function fetch(url)
    -- Ưu tiên game:HttpGet; fallback qua executor http_request
    do
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" and #body > 0 then
            return body
        end
    end
    if http_request then
        local ok2, res = pcall(function() return http_request({ Url = url, Method = "GET" }) end)
        if ok2 and res and (res.StatusCode == 200 or res.StatusCode == 201) and res.Body and #res.Body > 0 then
            return res.Body
        end
    end
    return nil
end

local function jdec(s)
    local ok, d = pcall(function() return HttpService:JSONDecode(s) end)
    return ok and d or nil
end

-- Nhiều host để sống sót khi admin đổi proxy / region
local HOSTS = {
    "https://games.roblox.com",      -- chính chủ
    "https://games.roproxy.com",     -- roproxy
    "https://apis.roproxy.com",      -- roproxy alt
    "https://games.rprxy.xyz",       -- rprxy alt
    "https://games.roproxy.xyz"      -- roproxy alt 2
}

-- ---- Lọc theo region (nếu bạn có Config["Setting"]["Select Region"]) ----
local function regionAllowed(server)
    local ok = true
    local cfg = rawget(getgenv(), "Config")
    if cfg and cfg["Setting"] and cfg["Setting"]["Select Region"] == true and cfg["Setting"]["Select Region"]["Region"] then
        local sr = tostring(server.region or server.ping or ""):lower()
        ok = false
        for _, wanted in ipairs(cfg["Setting"]["Select Region"]["Region"]) do
            if sr:find(tostring(wanted):lower()) then
                ok = true
                break
            end
        end
    end
    return ok
end

-- ---- Trình lấy trang server (có excludeFullGames) ----
local function getPage(host, placeId, cursor, order)
    local url = ("%s/v1/games/%d/servers/Public?limit=100&excludeFullGames=true&sortOrder=%s")
                :format(host, placeId, order or "Asc")
    if cursor then
        url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
    end
    local body = fetch(url)
    if not body then return nil end
    local data = jdec(body)
    if not (data and type(data.data) == "table") then return nil end
    return data
end

-- ---- Quét nhiều trang / nhiều host, chọn server tốt nhất ----
-- mode = "Low" (ít người nhất) | "High" (đông hơn một chút, tránh server chết)
local function pickBestServer(placeId, mode)
    local best, bestScore = nil, math.huge
    local cursor = nil
    local order = (mode == "High") and "Desc" or "Asc"
    local pagesScanned = 0

    for scan = 1, 10 do
        local page = nil
        -- Quay vòng host cho mỗi lần quét để tăng tỉ lệ thành công
        for _, host in ipairs(HOSTS) do
            page = getPage(host, placeId, cursor, order)
            if page then break end
            task.wait(0.1)
        end
        if not page then break end
        pagesScanned += 1

        for _, sv in ipairs(page.data) do
            local jobId = sv.id or sv.Id or sv.jobId
            local open, playing, maxp = vacancy(sv)
            if jobId and open >= 1 and notVisited(jobId) and regionAllowed(sv) then
                -- Score: ưu tiên ít người (mode Low); với High thì ưu tiên vừa/đông nhưng còn slot
                local score
                if mode == "High" then
                    -- Muốn hạn chế hop vào server “chết”: phạt server quá vắng
                    score = math.abs((maxp * 0.6) - playing) + (sv.ping or 0)/1000
                else
                    -- Ưu tiên server ít người nhất
                    score = playing + (sv.ping or 0)/1000
                end
                if score < bestScore then
                    best, bestScore = sv, score
                end
            end
        end

        cursor = page.nextPageCursor
        if not cursor or cursor == "null" or cursor == "" then break end
        task.wait(0.05)
    end

    return best
end

-- ========= Teleport wrappers =========
local bound = false
local function bindTeleportGuards()
    if bound then return end
    bound = true
    TeleportService.TeleportInitFailed:Connect(function()
        task.wait(2); STATE.BusyTeleport = false
    end)
    LP.OnTeleport:Connect(function(st)
        if st == Enum.TeleportState.Failed or st == Enum.TeleportState.Cancelled then
            task.wait(2); STATE.BusyTeleport = false
        end
    end)
    -- Ẩn prompt “Teleport Failed” nếu hiện
    local function hush(v)
        if v.Name == "ErrorPrompt" then
            if v.Visible and v.TitleFrame and v.TitleFrame:FindFirstChild("ErrorTitle")
               and v.TitleFrame.ErrorTitle.Text == "Teleport Failed" then
                v.Visible = false
            end
            v:GetPropertyChangedSignal("Visible"):Connect(function()
                if v.Visible and v.TitleFrame and v.TitleFrame:FindFirstChild("ErrorTitle")
                   and v.TitleFrame.ErrorTitle.Text == "Teleport Failed" then
                    v.Visible = false
                end
            end)
        end
    end
    local Gui = game:GetService("CoreGui")
    local overlay = Gui:FindFirstChild("RobloxPromptGui") and Gui.RobloxPromptGui:FindFirstChild("promptOverlay")
    if overlay then
        for _, v in ipairs(overlay:GetChildren()) do hush(v) end
        overlay.ChildAdded:Connect(hush)
    end
end

local function teleportToJob(jobId)
    if not jobId or STATE.BusyTeleport then return false end
    STATE.BusyTeleport = true; bindTeleportGuards(); markVisited(jobId)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LP)
    end)
    if not ok then
        task.wait(2); STATE.BusyTeleport = false; return false
    end
    task.delay(15, function() STATE.BusyTeleport = false end)
    return true
end

local function softRejoin()
    if STATE.BusyTeleport then return false end
    STATE.BusyTeleport = true; bindTeleportGuards()
    local ok = pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    if not ok then task.wait(2); STATE.BusyTeleport = false; return false end
    task.delay(15, function() STATE.BusyTeleport = false end)
    return true
end

-- ========= API công khai để gọi hop =========
-- Gọi HopAPI("Low") để tìm server ít người nhất còn slot (mặc định)
-- Gọi HopAPI("High") nếu muốn né server "chết"
getgenv().HopAPI = function(mode)
    mode = mode or "Low"
    local tries = 0
    while tries < 6 do
        tries += 1
        local best = pickBestServer(game.PlaceId, mode)
        if best and teleportToJob(best.id or best.Id or best.jobId) then
            return true
        end
        -- Nếu chọn không thành công, thử rejoin mềm rồi lặp
        softRejoin()
        task.wait(2 + math.random())
    end
    return false
end

-- Tuỳ nhu cầu: bạn có thể giữ vòng lặp hop nền nếu trước đây có.
-- Nếu trước đó bạn dùng vòng while true do ... pickServer ... tp..., thay bằng:
-- (Bỏ nếu bạn đã tự gọi HopAPI từ logic farm sau khi nhặt xong)
task.spawn(function()
    -- Chỉ chạy canh hop nếu bạn thực sự muốn auto-hop nền.
    -- Mặc định mình để idle; bật bằng cách đổi flag dưới đây.
    local ENABLE_BACKGROUND_HOP = false
    if not ENABLE_BACKGROUND_HOP then return end
    while task.wait(5) do
        if not STATE.BusyTeleport then
            getgenv().HopAPI("Low")
        end
    end
end)

-- ================== END HOP SERVER API (NEW) ==================


