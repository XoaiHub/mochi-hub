--// ================== CONFIG ==================
local Config = {
    RegionFilterEnabled   = false,
    RegionList            = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay        = 2,

    StrongholdChestName   = "Stronghold Diamond Chest",
    StrongholdPromptTime  = 10,
    StrongholdDiamondWait = 20,

    FarmPlaceId           = 126509999114328, -- ID map farm
}

--// ================== SERVICES ==================
local g               = game
local Players         = g:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RS              = g:GetService("ReplicatedStorage")
local RunService      = g:GetService("RunService")
local HttpService     = g:GetService("HttpService")
local TeleportService = g:GetService("TeleportService")

--// ================== COUNTERS ==================
local StrongholdCount, NormalChestCount = 0, 0

--// ================== FPS BOOST ==================
local function optimize(v)
    if v:IsA("BasePart") or v:IsA("MeshPart") then
        v.Material = Enum.Material.Plastic
        v.Reflectance = 0
        v.CastShadow  = false
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

--// ================== SERVER HOP ==================
local PlaceID = g.PlaceId
local AllIDs, cursor, isTeleporting = {}, "", false
local function hasValue(tab, val) for _, v in ipairs(tab) do if v==val then return true end end return false end

local function fetchServerPage(nextCursor, sortOrder)
    sortOrder = sortOrder or "Desc"
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100%s")
        :format(PlaceID, sortOrder, nextCursor ~= "" and ("&cursor="..nextCursor) or "")
    local ok, data = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if not ok then task.wait(Config.RetryHttpDelay) return nil end
    return data
end

local function isReady()
    return game:IsLoaded() and LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
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
    if #AllIDs > 200 then AllIDs = {}; warn("[Hop] Reset AllIDs list.") end

    local page = fetchServerPage(cursor)
    if not page or not page.data then cursor = "" return false end
    cursor = page.nextPageCursor or ""

    for _, v in ipairs(page.data) do
        local sid = tostring(v.id)
        if tonumber(v.playing) and tonumber(v.maxPlayers) and tonumber(v.playing) < tonumber(v.maxPlayers) then
            if not hasValue(AllIDs, sid) and regionMatch(v) then
                table.insert(AllIDs, sid)
                warn(("[Hop] Teleport -> %s (%s/%s)"):format(sid, tostring(v.playing), tostring(v.maxPlayers)))
                isTeleporting = true
                local ok = pcall(function()
                    TeleportService:TeleportToPlaceInstance(PlaceID, sid, LocalPlayer)
                end)
                if not ok then
                    warn("[Hop] Teleport error, retrying...")
                    isTeleporting = false
                end
                task.delay(5, function() isTeleporting = false end)
                return true
            end
        end
    end
    if cursor == "" then warn("[Hop] No valid server found, reset cursor.") end
    return false
end

function Hop()
    if not isReady() then repeat task.wait(1) until isReady() end
    for i = 1, 5 do if tryTeleportOnce() then return end task.wait(2) end
    cursor = "" -- reset
    fetchServerPage("", "Asc")
    warn("[Hop] Không tìm thấy server, thử lại với sortOrder khác.")
end

--// ================== NOCLIP ==================
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    if getgenv().NoClip then
        for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end
    else
        for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=true end end
    end
end)

--// ================== UI ==================
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
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundTransparency = 1
local stroke = Instance.new("UIStroke", frame); stroke.Thickness = 2; rainbowStroke(stroke)

local diamondLabel = Instance.new("TextLabel", frame)
diamondLabel.Size = UDim2.new(1, 0, 0.3, 0)
diamondLabel.Position = UDim2.new(0, 0, 0.30, 0)
diamondLabel.BackgroundTransparency = 1
diamondLabel.Text = "Diamonds: 0"
diamondLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
diamondLabel.Font = Enum.Font.GothamBold
diamondLabel.TextScaled = true

local normalLabel = Instance.new("TextLabel", frame)
normalLabel.Size = UDim2.new(1, 0, 0.15, 0)
normalLabel.Position = UDim2.new(0, 0, 0.65, 0)
normalLabel.BackgroundTransparency = 1
normalLabel.Text = "Normal Chest: 0"
normalLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
normalLabel.Font = Enum.Font.GothamBold
normalLabel.TextScaled = true

local strongholdLabel = Instance.new("TextLabel", frame)
strongholdLabel.Size = UDim2.new(1, 0, 0.15, 0)
strongholdLabel.Position = UDim2.new(0, 0, 0.80, 0)
strongholdLabel.BackgroundTransparency = 1
strongholdLabel.Text = "Stronghold Chest: 0"
strongholdLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
strongholdLabel.Font = Enum.Font.GothamBold
strongholdLabel.TextScaled = true

task.spawn(function()
    while task.wait(0.2) do
        local guiPlayer = LocalPlayer:FindFirstChild("PlayerGui")
        if guiPlayer then
            local countLabel = guiPlayer:FindFirstChild("Interface")
                and guiPlayer.Interface:FindFirstChild("DiamondCount")
                and guiPlayer.Interface.DiamondCount:FindFirstChild("Count")
            if countLabel and countLabel:IsA("TextLabel") then
                diamondLabel.Text = "Diamonds: " .. countLabel.Text
            end
        end
        normalLabel.Text     = "Normal Chest: " .. tostring(NormalChestCount)
        strongholdLabel.Text = "Stronghold Chest: " .. tostring(StrongholdCount)
    end
end)

--// ================== UTILS ==================
local function L_V1(cf)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character:SetPrimaryPartCFrame(cf)
    end
end

local function findUsableChest()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest, dist
    local items = workspace:FindFirstChild("Items")
    if not items then return nil end
    for _, v in pairs(items:GetDescendants()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prox and prox.Enabled then
                local d = (hrp.Position - v:GetPivot().Position).Magnitude
                if not dist or d < dist then closest, dist = v, d end
            end
        end
    end
    return closest
end

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

local function pressPromptWithTimeout(prompt, timeout)
    local t0 = tick()
    while prompt and prompt.Parent and prompt.Enabled and (tick()-t0)<timeout do
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.3)
    end
    return not (prompt and prompt.Parent and prompt.Enabled)
end

local function waitDiamonds(timeout)
    local t0 = tick()
    while (tick()-t0)<timeout do
        if workspace:FindFirstChild("Diamond", true) then return true end
        task.wait(0.2)
    end
    return false
end

local function collectAllDiamonds()
    local count=0
    for _,v in ipairs(workspace:GetDescendants()) do
        if v.ClassName=="Model" and v.Name=="Diamond" then
            pcall(function() RS.RemoteEvents.RequestTakeDiamonds:FireServer(v) end)
            count+=1
        end
    end
    return count
end

--// ================== AUTO JOIN PARTY ==================
local function autoJoinParty()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and (obj.Name=="Teleporter1" or obj.Name=="Teleporter2" or obj.Name=="Teleporter3") then
            local gui = obj:FindFirstChild("BillboardHolder")
            if gui and gui:FindFirstChild("BillboardGui") and gui.BillboardGui:FindFirstChild("Players") then
                local txt = gui.BillboardGui.Players.Text
                local x, y = txt:match("(%d+)/(%d+)")
                x, y = tonumber(x), tonumber(y)
                if x and y and x >= 2 then
                    local enter = obj:FindFirstChildWhichIsA("BasePart")
                    if enter and LocalPlayer.Character then
                        L_V1(enter.CFrame + Vector3.new(0,3,0))
                        warn("[Party] Auto join vào:", obj.Name)
                    end
                end
            end
        end
    end
end
spawn(function()
    while task.wait(2) do
        if g.PlaceId ~= Config.FarmPlaceId then
            pcall(autoJoinParty)
        end
    end
end)

--// ================== MAIN FARM ==================
spawn(function()
    while task.wait(1) do
        if g.PlaceId ~= Config.FarmPlaceId then continue end

        -- Ưu tiên Stronghold
        local stronghold = findStrongholdChest()
        if stronghold then
            local prox = findProximityPromptInChest(stronghold)
            if prox and prox.Enabled then
                warn("[Farm] Ưu tiên Stronghold chest...")
                L_V1(CFrame.new(stronghold:GetPivot().Position + Vector3.new(0,3,0)))
                local opened = pressPromptWithTimeout(prox, Config.StrongholdPromptTime)

                prox = findProximityPromptInChest(stronghold)
                if not opened and (prox and prox.Parent and prox.Enabled) then
                    warn("[Farm] Stronghold khoá -> bỏ qua")
                else
                    if waitDiamonds(Config.StrongholdDiamondWait) then
                        local got = collectAllDiamonds()
                        StrongholdCount += 1
                        warn("[Farm] Nhặt diamond stronghold:", got)
                    else
                        warn("[Farm] Không thấy diamond stronghold -> skip")
                    end
                end
            else
                warn("[Farm] Stronghold khoá/không khả dụng -> bỏ qua")
            end
        end

        -- Farm chest thường
        while true do
            local chest = findUsableChest()
            if not chest then
                warn("[ChestFarm] Hết chest usable -> hop server")
                Hop()
                break
            end

            local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            local start = os.time()
            local success = false

            -- thử mở chest trong 10s
            while prox and prox.Parent and prox.Enabled and os.time()-start < 10 do
                L_V1(CFrame.new(chest:GetPivot().Position))
                fireproximityprompt(prox)
                task.wait(0.5)
                prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            end

            if not (prox and prox.Parent and prox.Enabled) then
                success = true
            end

            if success then
                NormalChestCount += 1
                warn("[ChestFarm] Mở chest thường thành công")
            else
                warn("[ChestFarm] Chest bị kẹt/không mở được -> bỏ qua")
            end
            task.wait(0.5)
        end
    end
end)

-- Diamonds farm song song
spawn(function()
    while task.wait(0.2) do
        if g.PlaceId == Config.FarmPlaceId then
            collectAllDiamonds()
        end
    end
end)
