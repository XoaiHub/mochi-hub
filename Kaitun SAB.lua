LinkHook = "https://discord.com/api/webhooks/1262249617353867324/OuN1VE0amvk4do956KJyB_BD9XwLWaeOnlf0PAghXr88PUrMqEiDfSu6ayKpsaKI4jjH" -- webhook URL

-- Chỉ giữ Full 🌕 và gần Full 🌖
local Moon = {
    ['8'] = "http://www.roblox.com/asset/?id=9709149431", -- 🌕
    ['7'] = "http://www.roblox.com/asset/?id=9709149052", -- 🌖
}

-- Xác định MoonIcon + phần trăm
local Sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
local MoonIcon, MoonPercent = "?", 0
if Sky then
    for i,v in pairs(Moon) do
        if Sky.MoonTextureId == v then
            MoonPercent = i/8*100
            local icons = {['7']='🌖',['8']='🌕'}
            MoonIcon = icons[i] or "?"
        end
    end
end

local PlayersMin = #game.Players:GetPlayers()
local MoonMessage = "```"..tostring(MoonPercent).."% : "..MoonIcon.."```"
local CodeServer = 'game:GetService("TeleportService"):TeleportToPlaceInstance('..game.PlaceId..",'"..game.JobId.."')"

-- Chuẩn bị dữ liệu webhook
local Embed = {
    ["username"] = "Full Moon Notify",
    ["avatar_url"] = "https://cdn.discordapp.com/attachments/1258228428881137677/1258228644959096907/1705502093042.jpg",
    ["embeds"] = {{
        ["title"] = "**Full Moon Notify**",
        ["color"] = tonumber(000000),
        ["type"] = "rich",
        ["fields"] = {
            {["name"]="Players",["value"]="```"..PlayersMin.."/12```",["inline"]=false},
            {["name"]="Job Id",["value"]="```"..tostring(game.JobId).."```",["inline"]=false},
            {["name"]="Code",["value"]="```"..CodeServer.."```",["inline"]=true},
            {["name"]="Moon",["value"]=MoonMessage,["inline"]=true}
        },
        ["thumbnail"] = {["url"]="https://cdn.discordapp.com/attachments/1258228428881137677/1258228644959096907/1705502093042.jpg"},
        ["footer"] = {["text"]="Moon phase notifier"}
    }}
}

local Data = game:GetService("HttpService"):JSONEncode(Embed)
local Headers = {["Content-Type"] = "application/json"}
local Send = http_request or request or HttpPost or syn.request

-- Chỉ gửi webhook khi Moon là 🌖 hoặc 🌕
if LinkHook ~= "" and MoonPercent >= 87.5 then
    pcall(function()
        Send({Url=LinkHook,Body=Data,Method="POST",Headers=Headers})
    end)
end

-- ServerHop (giữ nguyên chức năng cũ)
local function Hop()
    local PlaceID = game.PlaceId
    local AllIDs, foundAnything = {}, ""
    local actualHour = os.date("!*t").hour

    local function TPReturner()
        local Site
        if foundAnything == "" then
            Site = game.HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..PlaceID.."/servers/Public?sortOrder=Asc&limit=100"))
        else
            Site = game.HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..PlaceID.."/servers/Public?sortOrder=Asc&limit=100&cursor="..foundAnything))
        end
        if Site.nextPageCursor then
            foundAnything = Site.nextPageCursor
        end
        for _,v in pairs(Site.data) do
            if v.playing < v.maxPlayers then
                local ID = tostring(v.id)
                if not table.find(AllIDs, ID) then
                    table.insert(AllIDs, ID)
                    pcall(function()
                        game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
                    end)
                    task.wait(5)
                end
            end
        end
    end

    while task.wait(1) do
        pcall(TPReturner)
    end
end

_G.ServerHop = true
task.spawn(function()
    while _G.ServerHop do
        Hop()
    end
end)

