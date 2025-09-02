--// ===== CONFIG =====
local Config = {
    RegionFilterEnabled     = false,
    RegionList              = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay          = 2,

    -- Stronghold
    StrongholdChestName     = "Stronghold Diamond Chest",
    StrongholdPromptTime    = 10,
    StrongholdDiamondWait   = 20,

    -- Chest thường
    NormalPromptTime        = 10,

    -- Watchdog chống kẹt toàn server
    ServerStallTimeout      = 75,   -- nếu >75s không có "tiến triển" -> hop
}

--// ===== SERVICES =====
local g = game
local Players = g:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS = g:GetService("ReplicatedStorage")
local RunService = g:GetService("RunService")
local HttpService = g:GetService("HttpService")
local TeleportService = g:GetService("TeleportService")

--// ===== FPS BOOST =====
local function optimize(v)
    if v:IsA("BasePart") or v:IsA("MeshPart") then
        v.Material = Enum.Material.Plastic
        v.Reflectance = 0
        v.CastShadow = false
        if v:IsA("MeshPart") then v.TextureID = "" end
        v.Transparency = 1
    elseif v:IsA("Decal") or v:IsA("Texture") then
        v.Transparency = 1
    elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
        v.Enabled = false
    elseif v:IsA("SpecialMesh") or v:IsA("SurfaceAppearance") then
        v:Destroy()
    end
end
for _, v in ipairs(g:GetDescendants()) do optimize(v) end
g.DescendantAdded:Connect(optimize)

--// ===== HỖ TRỢ CƠ BẢN =====
local function isReady()
    return game:IsLoaded()
        and LocalPlayer
        and LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

local function tpCF(cf)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character:SetPrimaryPartCFrame(cf)
    end
end

--// ===== UI (Rainbow Border + Diamond Counter) =====
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
local gui = Instance.new("ScreenGui", g:GetService("CoreGui")); gui.Name = "gg"
local frame = Instance.new("Frame", gui); frame.Size = UDim2.new(1,0,1,0); frame.BackgroundTransparency=1
local stroke = Instance.new("UIStroke", frame); stroke.Thickness = 2; rainbowStroke(stroke)
local label = Instance.new("TextLabel", frame)
label.Size = UDim2.new(1,0,1,0); label.BackgroundTransparency=1
label.Text = "0"; label.TextColor3 = Color3.fromRGB(255,255,255)
label.Font = Enum.Font.GothamBold; label.TextScaled = true; label.TextStrokeTransparency = 0.6
task.spawn(function()
    while task.wait(0.2) do
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local cnt = pg:FindFirstChild("Interface")
                    and pg.Interface:FindFirstChild("DiamondCount")
                    and pg.Interface.DiamondCount:FindFirstChild("Count")
            if cnt and cnt:IsA("TextLabel") then label.Text = cnt.Text end
        end
    end
end)

--// ===== NOCLIP =====
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    if getgenv().NoClip then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    else
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = true end
        end
    end
end)

--// ===== SERVER HOP =====
local PlaceID = g.PlaceId
local AllIDs, cursor, isTeleporting = {}, "", false
local function hasValue(tab, val) for _, v in ipairs(tab) do if v==val then return true end end return false end

local function fetchServerPage(nextCursor)
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100%s")
        :format(PlaceID, nextCursor ~= "" and ("&cursor="..nextCursor) or "")
    local ok, data = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if not ok then task.wait(2) return nil end
    return data
end

local function regionMatch(serverEntry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(serverEntry.region or ""):lower()
    for _, key in ipairs(Config.RegionList) do
        if string.find(raw, tostring(key):lower(), 1, true) then return true end
    end
    return false
end

local function tryTeleportOnce()
    if not isReady() then return false end
    local page = fetchServerPage(cursor)
    if not page or not page.data then return false end
    cursor = page.nextPageCursor or ""
    for _, v in ipairs(page.data) do
        local sid = tostring(v.id)
        if tonumber(v.playing) and tonumber(v.maxPlayers)
           and tonumber(v.playing) < tonumber(v.maxPlayers)
           and not hasValue(AllIDs, sid)
           and regionMatch(v)
        then
            table.insert(AllIDs, sid)
            warn(("[Hop] Teleport -> %s (%s/%s)"):format(sid, tostring(v.playing), tostring(v.maxPlayers)))
            isTeleporting = true
            pcall(function() TeleportService:TeleportToPlaceInstance(PlaceID, sid, LocalPlayer) end)
            task.delay(5, function() isTeleporting = false end)
            return true
        end
    end
    return false
end

function Hop()
    if not isReady() then repeat task.wait(0.5) until isReady() end
    for i = 1, 5 do
        if tryTeleportOnce() then return end
        task.wait(1.5)
    end
    warn("[Hop] Không tìm thấy server phù hợp.")
end

--// ===== AUTO JOIN PARTY (Teleporter1/2/3) =====
local function autoJoinParty()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
            local bh = obj:FindFirstChild("BillboardHolder")
            if bh and bh:FindFirstChild("BillboardGui") and bh.BillboardGui:FindFirstChild("Players") then
                local t = bh.BillboardGui.Players.Text
                local x, y = t:match("(%d+)/(%d+)")
                x, y = tonumber(x), tonumber(y)
                if x and y and x >= 2 then
                    local enter = obj:FindFirstChildWhichIsA("BasePart")
                    if enter and LocalPlayer.Character then
                        tpCF(enter.CFrame + Vector3.new(0,3,0))
                        warn("[Party] Auto join:", obj.Name)
                    end
                end
            end
        end
    end
end
spawn(function()
    while task.wait(2) do
        if g.PlaceId ~= 126509999114328 then
            pcall(autoJoinParty)
        end
    end
end)

--// ===== UTILS: CHESTS & DIAMONDS =====
local function chestPrompt(chest)
    if not chest then return nil end
    -- stronghold có structure khác, nhưng mặc định: thử prompt gắn trong cây con
    local p = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
    if p then return p end
    -- stronghold dạng Main/ProximityAttachment/ProximityInteraction
    local main = chest:FindFirstChild("Main")
    if main then
        local attach = main:FindFirstChild("ProximityAttachment")
        if attach then
            local alt = attach:FindFirstChild("ProximityInteraction")
            if alt and alt:IsA("ProximityPrompt") then return alt end
        end
    end
    return nil
end

local bannedChests = {}  -- [debugId] = true (đã thử mà không mở được)
local function chestId(chest) return chest and chest:GetDebugId() or "?" end

local function isUsableChest(v)
    if not (v and v:IsA("Model")) then return false end
    if not v.Name:find("Chest") then return false end
    if v.Name:find("Snow") then return false end
    local id = chestId(v)
    if bannedChests[id] then return false end
    local prox = chestPrompt(v)
    return prox and prox.Enabled
end

local function findUsableChest()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local items = workspace:FindFirstChild("Items")
    if not items then return nil end
    local closest, dist
    for _, v in ipairs(items:GetDescendants()) do
        if isUsableChest(v) then
            local d = (hrp.Position - v:GetPivot().Position).Magnitude
            if not dist or d < dist then closest, dist = v, d end
        end
    end
    return closest
end

local function findStrongholdChest()
    local items = workspace:FindFirstChild("Items")
    if not items then return nil end
    return items:FindFirstChild(Config.StrongholdChestName)
end

local function pressPromptWithTimeout(prompt, timeout)
    local t0 = tick()
    local okOnce = false
    while prompt and prompt.Parent and prompt.Enabled and (tick()-t0) < timeout do
        pcall(function() fireproximityprompt(prompt) end)
        okOnce = true
        task.wait(0.25)
    end
    -- trả về true nếu prompt biến mất (thường là mở được)
    return okOnce and (not (prompt and prompt.Parent and prompt.Enabled))
end

local function diamondsExist()
    return workspace:FindFirstChild("Diamond", true) ~= nil
end

local function waitDiamonds(timeout)
    local t0 = tick()
    while (tick()-t0) < timeout do
        if diamondsExist() then return true end
        task.wait(0.2)
    end
    return false
end

local function collectAllDiamonds()
    local count = 0
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.ClassName == "Model" and v.Name == "Diamond" then
            pcall(function() RS.RemoteEvents.RequestTakeDiamonds:FireServer(v) end)
            count += 1
        end
    end
    return count
end

--// ===== WATCHDOG: theo dõi "tiến triển" để tránh kẹt =====
local lastProgress = tick()
local function markProgress()
    lastProgress = tick()
end

-- diamonds collector song song + cập nhật tiến triển
spawn(function()
    while task.wait(0.25) do
        if g.PlaceId == 126509999114328 then
            local got = collectAllDiamonds()
            if got > 0 then markProgress() end
        end
    end
end)

--// ===== MAIN FARM LOOP (Ưu tiên Stronghold, skip khoá, hop khi hết usable) =====
spawn(function()
    while task.wait(1) do
        if g.PlaceId ~= 126509999114328 then continue end
        if not isReady() then continue end

        -- 1) Thử Stronghold trước nếu có
        local stronghold = findStrongholdChest()
        if stronghold then
            local proxS = chestPrompt(stronghold)
            if proxS and proxS.Enabled then
                warn("[Farm] Ưu tiên Stronghold...")
                tpCF(stronghold:GetPivot() + Vector3.new(0,3,0))
                local opened = pressPromptWithTimeout(proxS, Config.StrongholdPromptTime)
                if opened then
                    markProgress()
                    if waitDiamonds(Config.StrongholdDiamondWait) then
                        local got = collectAllDiamonds()
                        if got > 0 then markProgress() end
                        warn("[Farm] Đã lấy diamond từ Stronghold:", got)
                    else
                        warn("[Farm] Stronghold không spawn diamond -> tiếp tục farm chest thường")
                    end
                else
                    -- không mở được -> BAN stronghold để không dính lại, rồi qua chest thường
                    bannedChests[chestId(stronghold)] = true
                    warn("[Farm] Stronghold khoá / timeout -> skip stronghold, farm chest thường")
                end
            else
                -- prompt khoá -> ban stronghold (tránh lặp)
                bannedChests[chestId(stronghold)] = true
                warn("[Farm] Stronghold khoá -> bỏ qua, farm chest thường")
            end
        end

        -- 2) Farm chest thường cho đến khi hết usable
        while true do
            -- watchdog: nếu quá lâu không tiến triển -> hop
            if tick() - lastProgress > Config.ServerStallTimeout then
                warn("[Watchdog] Server kẹt (không tiến triển) -> hop")
                Hop()
                break
            end

            local chest = findUsableChest()
            if not chest then
                warn("[ChestFarm] Hết chest usable -> hop")
                Hop()
                break
            end

            local prox = chestPrompt(chest)
            if not (prox and prox.Enabled) then
                -- đánh dấu cấm nếu prompt không usable để khỏi thử lại
                bannedChests[chestId(chest)] = true
                task.wait(0.1)
                continue
            end

            -- thử mở chest thường
            tpCF(chest:GetPivot() + Vector3.new(0,3,0))
            local opened = pressPromptWithTimeout(prox, Config.NormalPromptTime)
            if opened then
                markProgress()
            else
                -- timeout/không mở được -> BAN chest này, tiếp tục chest khác
                bannedChests[chestId(chest)] = true
            end

            task.wait(0.25)
        end
    end
end)

--// ===== KẾT THÚC =====
-- Script giữ nguyên các tính năng:
-- - FPS boost + NoClip
-- - UI rainbow + diamond counter
-- - Auto join party
-- - Ưu tiên Stronghold; nếu Stronghold khoá => bỏ qua; nếu mở được => lấy xong mới làm chest thường
-- - Chest thường: chỉ mở prompt Enabled; chest khoá/timeout => ban, không thử lại
-- - Watchdog: không tiến triển trong ServerStallTimeout => hop


