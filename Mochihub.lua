local Config = {
    RegionFilterEnabled = false,
    RegionList = { 'singapore', 'tokyo', 'us-east' },
    RetryHttpDelay = 2,
}

local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local HttpService = game:GetService('HttpService')
local TeleportService = game:GetService('TeleportService')
local lp = Players.LocalPlayer

-- ================== KEEP OLD GUI UPDATE ==================
task.spawn(function()
    while task.wait(0.2) do
        local gui = lp and lp:FindFirstChild('PlayerGui')
        if gui then
            local iface = gui:FindFirstChild('Interface')
            local countLabel = iface and iface:FindFirstChild('DiamondCount') and iface.DiamondCount:FindFirstChild('Count')
            if countLabel and countLabel:IsA('TextLabel') then
                if type(e) ~= 'nil' and e:IsA('TextLabel') then
                    pcall(function()
                        e.Text = countLabel.Text
                    end)
                end
            end
        end
    end
end)

-- ================== TELEPORT TO POS ==================
local function safeSetCFrame(partCFrame)
    if not (lp and lp.Character and lp.Character.PrimaryPart) then return end
    pcall(function()
        lp.Character:SetPrimaryPartCFrame(partCFrame)
    end)
end

local function L_V1(pos)
    if not pos then return end
    if typeof(pos) == 'CFrame' then
        safeSetCFrame(pos)
    elseif typeof(pos) == 'Vector3' then
        safeSetCFrame(CFrame.new(pos))
    elseif typeof(pos) == 'Instance' and pos:IsA('BasePart') then
        safeSetCFrame(pos.CFrame)
    end
end

-- ================== CHECK TELEPORTER ==================
local function checkTeleporter(obj)
    if not obj or not obj:IsA('Model') then return end
    local g = obj:FindFirstChild('BillboardHolder')
    if not (g and g:FindFirstChild('BillboardGui') and g.BillboardGui:FindFirstChild('Players')) then return end
    local t = g.BillboardGui.Players.Text
    if not t then return end
    local x, y = t:match('(%d+)/(%d+)')
    x, y = tonumber(x), tonumber(y)
    if not (x and y and x >= 2) then return end
    local enter = obj:FindFirstChildWhichIsA('BasePart')
    if not (enter and lp and lp.Character and lp.Character:FindFirstChild('Humanoid')) then return end
    local hrp = lp.Character:FindFirstChild('HumanoidRootPart')
    if not hrp then return end
    local dist = (hrp.Position - enter.Position).Magnitude
    if dist > 10 then
        L_V1(enter.CFrame + Vector3.new(0, 3, 0))
    else
        lp.Character.Humanoid:MoveTo(enter.Position)
    end
end

task.spawn(function()
    while task.wait(0.5) do
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA('Model') and (obj.Name == 'Teleporter1' or obj.Name == 'Teleporter2' or obj.Name == 'Teleporter3') then
                pcall(function() checkTeleporter(obj) end)
            end
        end
    end
end)

-- ================== FOG CHECK ==================
local FogCF, FogSize = nil, nil
if workspace:FindFirstChild('Map') and workspace.Map:FindFirstChild('Boundaries') and workspace.Map.Boundaries:FindFirstChild('Fog') then
    local ok, bb = pcall(function() return workspace.Map.Boundaries.Fog:GetBoundingBox() end)
    if ok and bb then
        FogCF, FogSize = bb.Position, bb.Size
    end
end

local function pointInFog(p)
    if not (FogCF and FogSize) then return false end
    local minP = FogCF - FogSize / 2
    local maxP = FogCF + FogSize / 2
    return p.X >= minP.X and p.Y >= minP.Y and p.Z >= minP.Z and p.X <= maxP.X and p.Y <= maxP.Y and p.Z <= maxP.Z
end

-- ================== CHEST SCAN ==================
local chestSeen = {}
local function L_V3()
    local hrp = lp and lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
    if not hrp then return nil, nil end
    local closest, dist
    for _, v in ipairs(workspace.Items:GetDescendants()) do
        if v:IsA('Model') and v.Name:find('Chest') and not v.Name:find('Snow') then
            local prox = v:FindFirstChild('ProximityInteraction', true) or v:FindFirstChildWhichIsA('ProximityPrompt', true)
            if prox then
                local id = v:GetDebugId()
                if not chestSeen[id] then chestSeen[id] = tick() end
                if tick() - chestSeen[id] <= 10 then
                    local ok, pivot = pcall(function() return v:GetPivot().Position end)
                    if ok and pivot and not pointInFog(pivot) then
                        local d = (hrp.Position - pivot).Magnitude
                        if not dist or d < dist then
                            closest, dist = v, d
                        end
                    end
                end
            else
                chestSeen[v:GetDebugId()] = nil
            end
        end
    end
    return closest, dist
end

-- ================== DIAMOND PICKUP ==================
local function L_V4()
    if game.PlaceId ~= 126509999114328 then return end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA('Model') and d.Name == 'Diamond' then
            local ok, pos = pcall(function() return d:GetPivot().Position end)
            if ok and pos then
                L_V1(CFrame.new(pos))
                if RS and RS:FindFirstChild('RemoteEvents') and RS.RemoteEvents:FindFirstChild('RequestTakeDiamonds') then
                    RS.RemoteEvents.RequestTakeDiamonds:FireServer(d)
                end
                task.wait()
            end
        end
    end
end

-- ================== MAIN FARM LOOP ==================
task.spawn(function()
    while task.wait(0.1) do
        if game.PlaceId == 126509999114328 then
            -- chờ chest spawn
            local start = os.time()
            while os.time() - start < 15 do
                local c = 0
                for _, v in ipairs(workspace.Items:GetChildren()) do
                    if v.Name:find('Chest') and not v.Name:find('Snow') then
                        local ok, p = pcall(function() return v:GetPivot().Position end)
                        if ok and p and not pointInFog(p) then
                            c = c + 1
                        end
                    end
                end
                if c > 0 then break end -- FIX ✅
                task.wait(5)
            end

            local c = 0
            for _, v in ipairs(workspace.Items:GetChildren()) do
                if v.Name:find('Chest') and v:FindFirstChildWhichIsA('ProximityPrompt', true) and not v.Name:find('Snow') then
                    local ok, p = pcall(function() return v:GetPivot().Position end)
                    if ok and p and not pointInFog(p) then
                        c = c + 1
                    end
                end
            end

            if c == 0 and not workspace:FindFirstChild('Diamond', true) then -- FIX ✅
                tryTeleportOnce()
                return
            end

            while true do
                local chest, dist = L_V3() -- FIX ✅
                if not chest and game.PlaceId == 126509999114328 then
                    tryTeleportOnce()
                    break
                end
                local prox = chest and chest:FindFirstChildWhichIsA('ProximityPrompt', true)
                local startPrompt = os.time()
                while prox and prox.Parent and os.time() - startPrompt < 10 do
                    L_V1(CFrame.new(chest:GetPivot().Position))
                    fireproximityprompt(prox)
                    task.wait(0.5)
                    prox = chest and chest:FindFirstChildWhichIsA('ProximityPrompt', true)
                end
                task.wait(0.5)
            end
        else
            -- hop server khi lobby rảnh
            local inactive = true
            if #Players:GetPlayers() >= 5 or game.PlaceId == 126509999114328 then
                inactive = false
            else
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= lp and pl.Character and pl.Character:FindFirstChild('HumanoidRootPart') then
                        if pl.Character.HumanoidRootPart.Velocity.Magnitude > 2 then
                            inactive = false
                            break
                        end
                    end
                end
            end
            if inactive and game.PlaceId ~= 126509999114328 then
                tryTeleportOnce()
                task.wait(1)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if game.PlaceId == 126509999114328 then
            pcall(L_V4)
        end
    end
end)

-- ================== SERVER HOP ==================
local PlaceID = game.PlaceId
local AllIDs, cursor = {}, ''
local isTeleporting = false

local function fetchServerPage(nextCursor)
    local url = ('https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100%s'):format(
        tostring(PlaceID),
        (nextCursor and nextCursor ~= '') and ('&cursor=' .. nextCursor) or ''
    )
    local ok, raw = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if not ok then
        task.wait(Config.RetryHttpDelay)
        return nil
    end
    return raw
end

local function hasValue(t, v)
    for _, x in ipairs(t) do
        if x == v then return true end
    end
    return false
end

local function regionMatch(serverEntry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(serverEntry.ping or serverEntry.region or ''):lower()
    if raw == '' then return false end
    for _, key in ipairs(Config.RegionList) do
        if string.find(raw, tostring(key):lower(), 1, true) then
            return true
        end
    end
    return false
end

function tryTeleportOnce()
    if isTeleporting then return false end
    isTeleporting = true
    local page = fetchServerPage(cursor)
    if not page or not page.data then
        isTeleporting = false
        task.wait(Config.RetryHttpDelay)
        return false
    end
    cursor = (page.nextPageCursor and page.nextPageCursor ~= 'null') and page.nextPageCursor or ''
    for _, v in ipairs(page.data) do
        local sid = tostring(v.id)
        local playing, maxPlayers = tonumber(v.playing), tonumber(v.maxPlayers)
        if playing and maxPlayers and playing < maxPlayers then
            if not hasValue(AllIDs, sid) and regionMatch(v) then
                table.insert(AllIDs, sid)
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(PlaceID, sid, lp)
                end)
                task.delay(5, function() isTeleporting = false end)
                return true
            end
        end
    end
    isTeleporting = false
    return false
end
