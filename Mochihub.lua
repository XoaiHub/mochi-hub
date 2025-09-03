-- ================== CONFIG ==================
local Config = {
    RegionFilterEnabled = false,
    RegionList = { 'singapore', 'tokyo', 'us-east' },
    RetryHttpDelay = 2,
    FarmPlaceId = 126509999114328,
    ArriveTimeout = 30,       -- thời gian tối đa chờ hạ cánh sau khi gọi Teleport
    MapReadyTimeout = 25,     -- thời gian tối đa chờ map ready sau khi đã hạ cánh
    ChestPromptTimeout = 10,
    ChestSeenWindow = 10,
    InactiveCheckPlayers = 5,
}

-- ================== SERVICES ==================
local g = game
local Players = g:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local RS = g:GetService('ReplicatedStorage')
local RunService = g:GetService('RunService')
local HttpService = g:GetService('HttpService')
local TeleportService = g:GetService('TeleportService')
local StarterGui = g:GetService('StarterGui')
local ContentProvider = g:GetService('ContentProvider')

-- ================== FPS BOOST (giữ nguyên) ==================
g.Lighting.GlobalShadows = false
g.Lighting.FogEnd = 1e10
g.Lighting.Brightness = 0
settings().Rendering.QualityLevel = 'Level01'
local function optimize(v)
    if v:IsA('Model') then
        for _, c in ipairs(v:GetDescendants()) do
            if c:IsA('BasePart') or c:IsA('MeshPart') then
                c.Material = Enum.Material.Plastic
                c.Reflectance = 0
                c.CastShadow = false
                if c:IsA('MeshPart') then c.TextureID = '' end
                c.Transparency = 1
            elseif c:IsA('Decal') or c:IsA('Texture') then
                c.Transparency = 1
            elseif c:IsA('SpecialMesh') or c:IsA('SurfaceAppearance') then
                pcall(function() c:Destroy() end)
            end
        end
    elseif v:IsA('BasePart') or v:IsA('MeshPart') then
        v.Material = Enum.Material.Plastic
        v.Reflectance = 0
        v.CastShadow = false
        if v:IsA('MeshPart') then v.TextureID = '' end
        v.Transparency = 1
    elseif v:IsA('Decal') or v:IsA('Texture') then
        v.Transparency = 1
    elseif v:IsA('Explosion') then
        v.BlastPressure = 1
        v.BlastRadius = 1
    elseif v:IsA('Fire') or v:IsA('SpotLight') or v:IsA('Smoke') or v:IsA('Sparkles') then
        v.Enabled = false
    elseif v:IsA('SpecialMesh') or v:IsA('SurfaceAppearance') then
        pcall(function() v:Destroy() end)
    end
end
for _, v in ipairs(g:GetDescendants()) do optimize(v) end
g.DescendantAdded:Connect(optimize)
for _, e in ipairs(g.Lighting:GetDescendants()) do if e:IsA('PostEffect') then e.Enabled = false end end
g.Lighting.DescendantAdded:Connect(function(e) if e:IsA('PostEffect') then e.Enabled = false end end)

getgenv().fps = true
repeat task.wait() until getgenv().fps

-- ================== STATE (FIXED) ==================
local PlaceID = game.PlaceId
local AllIDs, cursor = {}, ''
local isTeleporting = false
local hasArrived = (TeleportService:GetLocalPlayerTeleportData() ~= nil) and true or false
local mapReady = false

-- Khi thực sự hạ cánh vào server mới
TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
    hasArrived = true
    isTeleporting = false
end)

-- Khi Teleport init fail -> cho phép thử lại
TeleportService.TeleportInitFailed:Connect(function(player, result, placeId, msg)
    warn('[TP] Teleport failed:', result, msg or '')
    isTeleporting = false
end)

-- ================== WAIT HELPERS (FIXED) ==================
local function waitForCharacter(timeout)
    local t0 = tick()
    while tick() - t0 <= (timeout or 15) do
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hrp = char:FindFirstChild('HumanoidRootPart')
        local hum = char:FindFirstChildOfClass('Humanoid')
        if char and hrp and hum then return char, hrp, hum end
        task.wait(0.1)
    end
    return nil, nil, nil
end

local function waitForMapReady(timeout)
    -- điều kiện: đã vào đúng FarmPlaceId, có workspace.Items, PlayerGui.Interface.DiamondCount (nếu có), HRP
    local t0 = tick()
    repeat
        if game.PlaceId ~= Config.FarmPlaceId then return false end
        local char, hrp = waitForCharacter(2)
        local itemsReady = workspace:FindFirstChild('Items')
        local pg = LocalPlayer:FindFirstChild('PlayerGui')
        local dc = pg and pg:FindFirstChild('Interface') and pg.Interface:FindFirstChild('DiamondCount')
        if char and hrp and itemsReady then
            -- preload nhẹ các instance trọng yếu để đảm bảo không "đen màn"
            pcall(function() ContentProvider:PreloadAsync({itemsReady}) end)
            return true
        end
        task.wait(0.25)
    until tick() - t0 >= (timeout or Config.MapReadyTimeout)
    return false
end

-- ================== SERVER BROWSER (giữ hầu hết, thêm guard) ==================
local function fetchServerPage(nextCursor)
    local url = ('https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100%s'):format(
        Config.FarmPlaceId,
        nextCursor ~= '' and ('&cursor=' .. nextCursor) or ''
    )
    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok then
        task.wait(Config.RetryHttpDelay)
        return nil
    end
    return data
end

local function hasValue(t, v)
    for _, x in ipairs(t) do if x == v then return true end end
    return false
end

local function regionMatch(serverEntry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(serverEntry.ping or serverEntry.region or ''):lower()
    if raw == '' then return false end
    for _, key in ipairs(Config.RegionList) do
        if string.find(raw, tostring(key):lower(), 1, true) then return true end
    end
    return false
end

-- GỌI TELEPORT chỉ khi đang ở đúng place và không teleport chồng (FIXED)
local function tryTeleportOnce()
    if isTeleporting then
        return false
    end
    if game.PlaceId ~= Config.FarmPlaceId then
        -- nếu lạc place khác, về đúng place trước (join map trước khi hop)
        isTeleporting = true
        hasArrived = false
        warn('[TP] Returning to FarmPlaceId first...')
        pcall(function()
            TeleportService:Teleport(Config.FarmPlaceId, LocalPlayer)
        end)
        -- chờ hạ cánh/timeout
        local t0 = tick()
        while not hasArrived and tick() - t0 < Config.ArriveTimeout do task.wait(0.2) end
        isTeleporting = false
        return false
    end

    local page = fetchServerPage(cursor)
    if not page or not page.data then
        warn('[TP] Wait hop server, retry...')
        return false
    end
    cursor = (page.nextPageCursor and page.nextPageCursor ~= 'null') and page.nextPageCursor or ''

    for _, v in ipairs(page.data) do
        local sid = tostring(v.id)
        if tonumber(v.playing) and tonumber(v.maxPlayers) and tonumber(v.playing) < tonumber(v.maxPlayers) then
            if not hasValue(AllIDs, sid) and regionMatch(v) then
                table.insert(AllIDs, sid)
                warn(('[TP] Teleport -> %s (%s/%s)'):format(sid, tostring(v.playing), tostring(v.maxPlayers)))
                isTeleporting = true
                hasArrived = false
                -- gọi một lần, đợi kết quả (FIXED: bỏ vòng lặp spam 10s)
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(Config.FarmPlaceId, sid, LocalPlayer)
                end)
                -- chờ hạ cánh hoặc timeout
                local t0 = tick()
                while not hasArrived and tick() - t0 < Config.ArriveTimeout do task.wait(0.2) end
                if not hasArrived then
                    warn('[TP] Arrive timeout, will allow retry.')
                    isTeleporting = false
                    return false
                end
                isTeleporting = false
                return true
            end
        end
    end
    return false
end

-- ================== PLAYER/PHYSICS (giữ nguyên) ==================
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild('Head')
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not (char and head and hrp) then return end
        if getgenv().NoClip then
            if not head:FindFirstChild('BodyClip') then
                local bv = Instance.new('BodyVelocity')
                bv.Name = 'BodyClip'; bv.Velocity = Vector3.new(0,0,0)
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.P = 15000; bv.Parent = head
            end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA('BasePart') then v.CanCollide = false end
            end
        else
            local existingClip = head and head:FindFirstChild('BodyClip')
            if existingClip then existingClip:Destroy() end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA('BasePart') then v.CanCollide = true end
            end
        end
    end)
end)

-- ================== HUD nhỏ (giữ nguyên) ==================
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
local a = Instance.new('ScreenGui', game:GetService('CoreGui')); a.Name = 'gg'
local b = Instance.new('Frame', a); b.Size = UDim2.new(1,0,1,0); b.BackgroundTransparency = 1; b.BorderSizePixel = 0
local d = Instance.new('UIStroke', b); d.Thickness = 2; rainbowStroke(d)
local e = Instance.new('TextLabel', b)
e.Size = UDim2.new(1,0,1,0); e.BackgroundTransparency = 1; e.Text = '0'
e.TextColor3 = Color3.fromRGB(255,255,255); e.Font = Enum.Font.GothamBold; e.TextScaled = true; e.TextStrokeTransparency = 0.6
task.spawn(function()
    while task.wait(0.2) do
        local pg = LocalPlayer:FindFirstChild('PlayerGui')
        local countLabel = pg and pg:FindFirstChild('Interface') and pg.Interface:FindFirstChild('DiamondCount') and pg.Interface.DiamondCount:FindFirstChild('Count')
        if countLabel and countLabel:IsA('TextLabel') then e.Text = countLabel.Text end
    end
end)

-- ================== TELEPORTER CHECK (giữ nguyên) ==================
local lp = LocalPlayer
local function L_V1(cf) -- tp ngắn
    local char = lp.Character
    if char and char.PrimaryPart then
        char:SetPrimaryPartCFrame(cf)
    elseif char and char:FindFirstChild('HumanoidRootPart') then
        char:MoveTo(cf.Position)
    end
end

local function checkTeleporter(obj)
    local g = obj:FindFirstChild('BillboardHolder')
    if g and g:FindFirstChild('BillboardGui') and g.BillboardGui:FindFirstChild('Players') then
        local t = g.BillboardGui.Players.Text
        local x, y = t:match('(%d+)/(%d+)')
        x, y = tonumber(x), tonumber(y)
        if x and y and x >= 2 then
            local enter = obj:FindFirstChildWhichIsA('BasePart')
            if enter and lp.Character and lp.Character:FindFirstChild('Humanoid') then
                local hrp = lp.Character:FindFirstChild('HumanoidRootPart')
                if hrp then
                    lp.Character.Humanoid:MoveTo(enter.Position)
                    if (hrp.Position - enter.Position).Magnitude > 10 then
                        L_V1(enter.CFrame + Vector3.new(0,3,0))
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.5) do
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA('Model') and (obj.Name == 'Teleporter1' or obj.Name == 'Teleporter2' or obj.Name == 'Teleporter3') then
                checkTeleporter(obj)
            end
        end
    end
end)

-- ================== FARM LOGIC (FIXED: chỉ chạy sau khi mapReady) ==================
local FogCF, FogSize = workspace.Map:FindFirstChild('Boundaries')
    and workspace.Map.Boundaries:FindFirstChild('Fog')
    and workspace.Map.Boundaries.Fog:GetBoundingBox()

local chestSeen = {}

local function L_V3()
    local hrp = lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
    if not hrp then return nil, nil end
    local closest, dist
    for _, v in pairs(workspace.Items:GetDescendants()) do
        if v:IsA('Model') and v.Name:find('Chest') and not v.Name:find('Snow') then
            local prox = v:FindFirstChild('ProximityInteraction', true) or v:FindFirstChildWhichIsA('ProximityPrompt', true)
            if prox then
                local id = v:GetDebugId()
                if not chestSeen[id] then chestSeen[id] = tick() end
                if tick() - chestSeen[id] <= Config.ChestSeenWindow then
                    local p = v:GetPivot().Position
                    if not FogCF or not FogSize or not (p >= FogCF.Position - FogSize/2 and p <= FogCF.Position + FogSize/2) then
                        local d = (hrp.Position - p).Magnitude
                        if not dist or d < dist then closest, dist = v, d end
                    end
                else
                    chestSeen[id] = nil
                end
            end
        end
    end
    return closest, dist
end

local function L_V4()
    for _, dmd in pairs(workspace:GetDescendants()) do
        if dmd:IsA('Model') and dmd.Name == 'Diamond' and game.PlaceId == Config.FarmPlaceId then
            L_V1(CFrame.new(dmd:GetPivot().Position))
            pcall(function() RS.RemoteEvents.RequestTakeDiamonds:FireServer(dmd) end)
            warn('[FARM] collect diamond')
        end
    end
end

-- Vòng farm/chọn hop chỉ bắt đầu khi đã vào đúng map & mapReady (FIXED)
task.spawn(function()
    while task.wait(0.2) do
        if game.PlaceId ~= Config.FarmPlaceId then
            -- Luôn đảm bảo JOIN map trước
            if not isTeleporting then
                warn('[FLOW] Not in farm place → teleporting to FarmPlaceId...')
                isTeleporting = true
                hasArrived = false
                pcall(function() TeleportService:Teleport(Config.FarmPlaceId, LocalPlayer) end)
                local t0 = tick()
                while not hasArrived and tick() - t0 < Config.ArriveTimeout do task.wait(0.2) end
                isTeleporting = false
            end
            continue
        end

        if not mapReady then
            mapReady = waitForMapReady(Config.MapReadyTimeout)
            if not mapReady then
                warn('[FLOW] Map not ready → will hop once.')
                tryTeleportOnce() -- map lỗi → hop
                task.wait(2)
                continue
            end
            warn('[FLOW] Map is ready → start farming.')
        end

        -- Farm vòng chính
        -- 1) kiểm tra số chest trước khi farm; nếu quá ít → hop
        local chestCount = 0
        for _, v in pairs(workspace.Items:GetChildren()) do
            if v.Name:find('Chest') and not v.Name:find('Snow') and v:FindFirstChildWhichIsA('ProximityPrompt', true) then
                local p = v:GetPivot().Position
                if not FogCF or not FogSize or not (p >= FogCF.Position - FogSize/2 and p <= FogCF.Position + FogSize/2) then
                    chestCount += 1
                end
            end
        end

        if chestCount <= 0 then
            warn('[FARM] No chest here → hop.')
            tryTeleportOnce()
            mapReady = false
            continue
        end

        local chest = L_V3()
        if not chest then
            warn('[FARM] No chest found (scan) → hop.')
            tryTeleportOnce()
            mapReady = false
            continue
        end

        local prox = chest:FindFirstChildWhichIsA('ProximityPrompt', true)
        local start = os.time()
        while prox and prox.Parent and (os.time() - start < Config.ChestPromptTimeout) do
            L_V1(CFrame.new(chest:GetPivot().Position))
            pcall(function() fireproximityprompt(prox) end)
            task.wait(0.5)
            prox = chest:FindFirstChildWhichIsA('ProximityPrompt', true)
        end

        if os.time() - start >= Config.ChestPromptTimeout then
            warn('[FARM] Chest timeout → skip/hop soft.')
        end
    end
end)

-- Nhặt diamond liên tục khi đã ở farm map
while task.wait(0.1) do
    if game.PlaceId == Config.FarmPlaceId and mapReady then
        L_V4()
    end
end
