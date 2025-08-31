-- >>> Người dùng PHẢI dán key nhận từ /getscript vào đây <<<
-- ví dụ: script_key = "ABCD1234...."
if not script_key or #script_key < 8 then
    return warn("[Mochi] Missing or invalid script_key. Get it via /getscript on Discord.")
end

local http = game:GetService("HttpService")
local API_BASE = "http://127.0.0.1:8000"  -- cùng với .env API_BASE
local function auth(k)
    local ok, res = pcall(function()
        local url = string.format("%s/v1/authorize?script_key=%s", API_BASE, k)
        local body = game:HttpGet(url)
        return http:JSONDecode(body)
    end)
    if not ok then
        warn("[Mochi] Auth error: ", res)
        return false, "auth_request_failed"
    end
    if res and res.allowed == true then
        return true, "ok"
    end
    return false, res and res.message or "unauthorized"
end

local allowed, reason = auth(script_key)
if not allowed then
    return error("[Mochi] Unauthorized: ".. tostring(reason))
end

-- ĐÃ AUTH OK -> tải core script thật
local CORE_URL = "https://raw.githubusercontent.com/XoaiHub/mochi-hub/refs/heads/master/kaitun.lua"
local ok, err = pcall(function()
    loadstring(game:HttpGet(CORE_URL))()
end)
if not ok then
    error("[Mochi] Load core failed: ".. tostring(err))
end
