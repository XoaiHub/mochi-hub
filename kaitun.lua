--// ===== CONFIG =====
local Config = {
    RegionFilterEnabled = false,
    RegionList = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay = 2,
    StrongholdChestName = "Stronghold Diamond Chest",
    StrongholdPromptTime = 10,
    StrongholdDiamondWait = 20,
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
    pcall(function()
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
    end)
end
task.spawn(function()
    for _, v in ipairs(g:GetDescendants()) do optimize(v) end
    g.DescendantAdded:Connect(optimize)
end)

--// ===== SERVER HOP =====
local PlaceID, AllIDs, cursor, isTeleporting = g.PlaceId, {}, "", false
local function hasValue(tab, val) for _, v in ipairs(tab) do if v==val then return true end end return false end
local function fetchServerPage(nextCursor)
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100%s")
        :format(PlaceID, nextCursor ~= "" and ("&cursor="..nextCursor) or "")
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
    local page = fetchServerPage(cursor)
    if not page or not page.data then return false end
    cursor = page.nextPageCursor or ""
    for _, v in ipairs(page.data) do
        local sid = tostring(v.id)
        if tonumber(v.playing) < tonumber(v.maxPlayers) then
            if not hasValue(AllIDs, sid) and regionMatch(v) then
                table.insert(AllIDs, sid)
                if #AllIDs > 200 then table.remove(AllIDs,1) end -- tránh memory leak
                warn(("[Hop] Teleport -> %s (%s/%s)"):format(sid, tostring(v.playing), tostring(v.maxPlayers)))
                isTeleporting = true
                TeleportService:TeleportToPlaceInstance(PlaceID, sid, LocalPlayer)
                task.delay(5, function() isTeleporting = false end)
                return true
            end
        end
    end
    return false
end
local function Hop()
    if not isReady() then repeat task.wait(1) until isReady() end
    for i = 1, 5 do if tryTeleportOnce() then return end task.wait(2) end
    warn("[Hop] Không tìm thấy server phù hợp.")
end

--// ===== NOCLIP =====
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not getgenv().NoClip end
    end
end)

--// ===== UI (Rainbow Border + Diamond Counter) =====
local gui = Instance.new("ScreenGui", g:GetService("CoreGui")); gui.Name = "gg"
local frame = Instance.new("Frame", gui); frame.Size = UDim2.new(1,0,1,0); frame.BackgroundTransparency=1
local stroke = Instance.new("UIStroke", frame); stroke.Thickness = 2
local label = Instance.new("TextLabel", frame)
label.Size = UDim2.new(1,0,1,0); label.BackgroundTransparency=1
label.Text = "0"; label.TextColor3 = Color3.fromRGB(255,255,255)
label.Font = Enum.Font.GothamBold; label.TextScaled = true; label.TextStrokeTransparency = 0.6
task.spawn(function()
    while task.wait(0.3) do
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                local countLabel = pg:FindFirstChild("Interface") and pg.Interface:FindFirstChild("DiamondCount") and pg.Interface.DiamondCount:FindFirstChild("Count")
                if countLabel and countLabel:IsA("TextLabel") then label.Text = countLabel.Text end
            end
        end)
    end
end)
task.spawn(function() -- rainbow border
    while task.wait() do
        for i = 0, 1, 0.01 do
            stroke.Color = Color3.fromHSV(i, 1, 1)
            task.wait(0.03)
        end
    end
end)

--// ===== UTILS =====
local function L_V1(cf)
    pcall(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
            LocalPlayer.Character:SetPrimaryPartCFrame(cf) 
        end
    end)
end
local function findUsableChest()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest, dist
    for _, v in pairs(workspace.Items:GetDescendants()) do
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
    local t0 = os.clock()
    while prompt and prompt.Parent and prompt.Enabled and (os.clock()-t0)<timeout do
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.3)
    end
end
local function waitDiamonds(timeout)
    local t0 = os.clock()
    while (os.clock()-t0)<timeout do
        if workspace:FindFirstChild("Diamond", true) then return true end
        task.wait(0.3)
    end
    return false
end
local function collectAllDiamonds()
    local count=0
    for _,v in ipairs(workspace:GetChildren()) do -- chỉ quét top-level cho nhẹ
        if v:IsA("Model") and v.Name=="Diamond" then 
            pcall(function() RS.RemoteEvents.RequestTakeDiamonds:FireServer(v) end)
            count+=1
        end 
    end
    return count
end

--// ===== AUTO JOIN PARTY =====
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            if g.PlaceId ~= 126509999114328 then
                for _, obj in ipairs(workspace:GetChildren()) do
                    if obj:IsA("Model") and obj.Name:match("Teleporter") then
                        local gui = obj:FindFirstChild("BillboardHolder")
                        if gui and gui:FindFirstChild("BillboardGui") and gui.BillboardGui:FindFirstChild("Players") then
                            local txt = gui.BillboardGui.Players.Text
                            local x, y = txt:match("(%d+)/(%d+)")
                            x, y = tonumber(x), tonumber(y)
                            if x and y and x >= 2 then
                                local enter = obj:FindFirstChildWhichIsA("BasePart")
                                if enter and LocalPlayer.Character then
                                    L_V1(enter.CFrame + Vector3.new(0,3,0))
                                    warn("[Party] Auto join:", obj.Name)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

--// ===== MAIN FARM LOOP =====
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if g.PlaceId == 126509999114328 then
                -- Ưu tiên Stronghold
                local stronghold = findStrongholdChest()
                if stronghold then
                    local prox = findProximityPromptInChest(stronghold)
                    if prox and prox.Enabled then
                        warn("[Farm] Ưu tiên Stronghold chest...")
                        L_V1(CFrame.new(stronghold:GetPivot().Position+Vector3.new(0,3,0)))
                        pressPromptWithTimeout(prox,Config.StrongholdPromptTime)

                        prox = findProximityPromptInChest(stronghold)
                        if not (prox and prox.Enabled) then
                            if waitDiamonds(Config.StrongholdDiamondWait) then
                                warn("[Farm] Nhặt diamond stronghold:", collectAllDiamonds())
                            end
                        end
                    end
                end

                -- Chest thường
                local chest = findUsableChest()
                while chest do
                    local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                    local start = os.clock()
                    while prox and prox.Parent and prox.Enabled and os.clock()-start<10 do
                        L_V1(CFrame.new(chest:GetPivot().Position))
                        fireproximityprompt(prox)
                        task.wait(0.3)
                        prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                    end
                    task.wait(0.3)
                    chest = findUsableChest()
                end
                warn("[ChestFarm] Hết chest usable -> hop server")
                Hop()

                -- Diamonds farm nhẹ
                collectAllDiamonds()
            end
        end)
    end
end)
