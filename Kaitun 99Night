-- === Mochi Loader (check key -> load script) ===
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Đổi sang API server public của bạn (nên dùng HTTPS)
local API_BASE = "http://127.0.0.1:8000"

local function Kick(msg)
    pcall(function() LocalPlayer:Kick(tostring(msg)) end)
    task.wait(0.1)
    return
end

-- 1) Kiểm tra key (yêu cầu dán trước vào biến script_key)
if not script_key or type(script_key) ~= "string" or #script_key < 8 then
    return Kick("[Mochi] Chưa có key.\nVào Discord gõ /getscript để lấy key.")
end

-- 2) Gọi API check key
local function checkAuth(k)
    local hwid = tostring(LocalPlayer.UserId)
    local url = string.format("%s/api/check/%s/%s",
        API_BASE,
        HttpService:UrlEncode(k),
        HttpService:UrlEncode(hwid)
    )

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then
        return false, "auth_request_failed"
    end

    local ok2, res = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok2 or type(res) ~= "table" then
        return false, "bad_response"
    end

    if res.ok then
        return true, res.msg or "ok"
    else
        return false, tostring(res.msg or "unauthorized")
    end
end

local allowed, reason = checkAuth(script_key)
if not allowed then
    local r = tostring(reason):lower()
    if r:find("max_tabs_exceeded") then
        return Kick("[Mochi] Key đã đạt giới hạn số tab.\nHãy đóng tab khác hoặc chờ admin reset HWID.")
    elseif r:find("hết tab") then
        return Kick("[Mochi] Key đã hết tab.")
    elseif r:find("đã đạt số máy tối đa") then
        return Kick("[Mochi] Key đã đạt số máy tối đa theo device_limit.")
    elseif r:find("key không tồn tại") then
        return Kick("[Mochi] Key không tồn tại hoặc sai.")
    elseif r:find("auth_request_failed") or r:find("bad_response") then
        return Kick("[Mochi] Không kết nối được API hoặc phản hồi lỗi.\nChi tiết: " .. tostring(reason))
    else
        return Kick("[Mochi] Key sai hoặc hết hạn.\nChi tiết: " .. tostring(reason))
    end
end

-- 3) Key hợp lệ -> tải script thật
-- ❌ KHÔNG hard-code master nữa
-- ✅ Trùng với SCRIPT_URL trong .env của server (branch main)
local CORE_URL = "https://raw.githubusercontent.com/XoaiHub/mochi-hub/refs/heads/main/Kaitun%2099Night"

local ok, err = pcall(function()
    loadstring(game:HttpGet(CORE_URL))()
end)
if not ok then
    return Kick("[Mochi] Không tải được core script.\nLỗi: " .. tostring(err))
end
