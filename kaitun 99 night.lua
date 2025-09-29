-- ================================================================
-- Mochi Farm (Luarmor-ready & Emulator-stable, no UI) - FULL (FIX)
-- + Chỉ mở rương 1 gem và 5 gems (lọc chest)
-- + Fast Hop After Collect (nhảy ngay sau khi nhặt xong)
-- + Anti-DEAD + Skip Server Full + No-Rejoin-Same-Server
-- + Hop engine: Asc/Desc + cursor (gia cố) + guard, grace windows
-- + Stronghold KHÔNG mở được -> Hop ngay
-- + Auto Lobby Create Join: nếu lobby không có người create thì hop tìm
-- + Vá "Teleport Failed"
-- + Overlay đếm gems farm
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
    LobbyPlaceId            = 12073775378,     -- map lobby

    ChestFilter             = { ["1 Gem Chest"] = true, ["5 Gem Chest"] = true },

    TeleportTimeout         = 15,
    ServerHopDelay          = 3,
    OverlayEnabled          = true,
}

-- ===== SERVICES =====
local Players            = game:GetService("Players")
local TeleportService    = game:GetService("TeleportService")
local HttpService        = game:GetService("HttpService")
local CoreGui            = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ===== STATE =====
local AllIDs = {}
local GemsFarmed = 0
local Teleporting = false

-- ===== OVERLAY =====
local function createOverlay()
    if not Config.OverlayEnabled then return end
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FarmOverlay"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = CoreGui

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0,200,0,50)
    Label.Position = UDim2.new(0,10,0,10)
    Label.BackgroundTransparency = 0.4
    Label.BackgroundColor3 = Color3.fromRGB(0,0,0)
    Label.TextColor3 = Color3.fromRGB(0,255,0)
    Label.TextScaled = true
    Label.Name = "GemCounter"
    Label.Parent = ScreenGui

    task.spawn(function()
        while task.wait(1) and ScreenGui.Parent do
            Label.Text = "💎 Gems farmed: "..tostring(GemsFarmed)
        end
    end)
end
createOverlay()

-- ===== UTIL =====
local function tp(placeId, jobId)
    if Teleporting then return end
    Teleporting = true
    local s,e = pcall(function()
        if jobId then
            TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
        else
            TeleportService:Teleport(placeId, LocalPlayer)
        end
    end)
    if not s then
        Teleporting = false
    end
end

-- ===== SERVER HOP ENGINE =====
local cursor = ""
local function serverHop(placeId)
    task.wait(Config.ServerHopDelay)
    local url = "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100"..(cursor~="" and "&cursor="..cursor or "")
    local body = game:HttpGet(url)
    local data = HttpService:JSONDecode(body)

    for _,srv in pairs(data.data) do
        if srv.playing < srv.maxPlayers then
            if not table.find(AllIDs,srv.id) then
                table.insert(AllIDs,srv.id)
                tp(placeId,srv.id)
                return
            end
        end
    end
    if data.nextPageCursor then
        cursor = data.nextPageCursor
    else
        cursor = ""
    end
    serverHop(placeId)
end

-- ===== FARM CHEST =====
local function farmChests()
    while task.wait(2) do
        local chests = workspace:FindFirstChild("Chests")
        if chests then
            for _,chest in pairs(chests:GetChildren()) do
                if Config.ChestFilter[chest.Name] then
                    fireproximityprompt(chest.ProximityPrompt, Config.StrongholdPromptTime)
                    GemsFarmed = GemsFarmed + (chest.Name=="1 Gem Chest" and 1 or 5)
                    task.wait(Config.StrongholdDiamondWait)
                    serverHop(Config.FarmPlaceId)
                end
            end
        end
    end
end

-- ===== AUTO LOBBY CREATE JOIN =====
local function joinCreate()
    while task.wait(5) do
        if game.PlaceId ~= Config.LobbyPlaceId then return end
        local teleporter = workspace:FindFirstChild("Teleporters")
        if teleporter then
            local found = false
            for _,gate in pairs(teleporter:GetChildren()) do
                if gate:FindFirstChild("BillboardGui") and tonumber(gate.BillboardGui.TextLabel.Text) > 0 then
                    found = true
                    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, gate.Part, 0)
                    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, gate.Part, 1)
                    break
                end
            end
            if not found then
                serverHop(Config.LobbyPlaceId)
            end
        else
            serverHop(Config.LobbyPlaceId)
        end
    end
end

-- ===== START =====
if game.PlaceId == Config.FarmPlaceId then
    task.spawn(farmChests)
elseif game.PlaceId == Config.LobbyPlaceId then
    task.spawn(joinCreate)
end

-- ===== FIX TELEPORT FAILED =====
TeleportService.TeleportInitFailed:Connect(function(_,err)
    warn("Teleport failed:",err)
    Teleporting = false
    task.wait(2)
    serverHop(Config.FarmPlaceId)
end)

