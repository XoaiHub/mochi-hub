-- === Mochi Loader (yêu cầu key) ===
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- API server của bạn (nên deploy HTTPS khi public)
local API_BASE = "http://127.0.0.1:8000"

-- ⚠️ Người dùng phải dán key vào đây
local script_key = "PASTE_YOUR_KEY_HERE"

-- Hàm kick kèm thông báo
local function Kick(msg)
    pcall(function() LocalPlayer:Kick(tostring(msg)) end)
    task.wait(0.1)
    return
end

-- 1) Kiểm tra key
if not script_key or type(script_key) ~= "string" or #script_key < 8 then
    return Kick("[Mochi] ❌ Chưa có key.\nVào Discord gõ /getscript để lấy key.")
end

-- 2) Gọi API getscript (server sẽ vừa check key, vừa trả script)
local function fetchScript(k)
    local hwid = tostring(LocalPlayer.UserId)
    local url = string.format("%s/api/getscript/%s/%s",
        API_BASE,
        HttpService:UrlEncode(k),
        HttpService:UrlEncode(hwid)
    )

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then
        return nil, "auth_request_failed"
    end

    local ok2, res = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok2 or type(res) ~= "table" then
        return nil, "bad_response"
    end

    if res.ok and res.script then
        return res.script, res.msg
    else
        return nil, tostring(res.msg or "unauthorized")
    end
end

-- 3) Lấy script thật nếu key hợp lệ
local coreScript, reason = fetchScript(script_key)
if not coreScript then
    local r = tostring(reason):lower()
    if r:find("max_tabs_exceeded") then
        return Kick("[Mochi] Key đã đạt giới hạn số tab.\nĐóng tab khác hoặc chờ admin reset HWID.")
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

-- 4) Chạy script thật
local ok, err = pcall(function()
    loadstring(coreScript)()
end)
if not ok then
    return Kick("[Mochi] Không chạy được core script.\nLỗi: " .. tostring(err))
end
