local Config = {
    RegionFilterEnabled = false,
    RegionList = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay = 2,
}

-- ===== FPS BOOST =====
local g = game
g.Lighting.GlobalShadows = false
g.Lighting.FogEnd = 1e10
g.Lighting.Brightness = 0
settings().Rendering.QualityLevel = "Level01"
local function optimize(v)
    if v:IsA("Model") then
        for _, c in ipairs(v:GetDescendants()) do
            if c:IsA("BasePart") or c:IsA("MeshPart") then
                c.Material = Enum.Material.Plastic
                c.Reflectance = 0
                c.CastShadow = false
                if c:IsA("MeshPart") then c.TextureID = "" end
                c.Transparency = 1
            elseif c:IsA("Decal") or c:IsA("Texture") then
                c.Transparency = 1
            elseif c:IsA("SpecialMesh") or c:IsA("SurfaceAppearance") then
                c:Destroy()
            end
        end
    elseif v:IsA("BasePart") or v:IsA("MeshPart") then
        v.Material = Enum.Material.Plastic
        v.Reflectance = 0
        v.CastShadow = false
        if v:IsA("MeshPart") then v.TextureID = "" end
        v.Transparency = 1
    elseif v:IsA("Decal") or v:IsA("Texture") then
        v.Transparency = 1
    elseif v:IsA("Explosion") then
        v.BlastPressure, v.BlastRadius = 1, 1
    elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
        v.Enabled = false
    elseif v:IsA("SpecialMesh") or v:IsA("SurfaceAppearance") then
        v:Destroy()
    end
end
for _, v in ipairs(g:GetDescendants()) do optimize(v) end
g.DescendantAdded:Connect(optimize)
for _, e in ipairs(g.Lighting:GetDescendants()) do if e:IsA("PostEffect") then e.Enabled = false end end
g.Lighting.DescendantAdded:Connect(function(e) if e:IsA("PostEffect") then e.Enabled = false end end)

getgenv().fps = true
repeat task.wait() until getgenv().fps

-- ===== TELEPORT SERVICE =====
local PlaceID = game.PlaceId
local FARM_PLACEID = 126509999114328 -- id map farm
local AllIDs, cursor, isTeleporting = {}, "", false
local TeleportService  = game:GetService("TeleportService")

local function fetchServerPage(nextCursor)
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100%s")
        :format(PlaceID, nextCursor ~= "" and ("&cursor="..nextCursor) or "")
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet(url))
    end)
    if not ok then task.wait(Config.RetryHttpDelay) return nil end
    return data
end
local function hasValue(t, v) for _,x in ipairs(t) do if x == v then return true end end return false end
local function regionMatch(serverEntry)
    if not Config.RegionFilterEnabled then return true end
    local raw = tostring(serverEntry.ping or serverEntry.region or ""):lower()
    if raw == "" then return false end
    for _, key in ipairs(Config.RegionList) do
        if string.find(raw, tostring(key):lower(), 1, true) then return true end
    end
    return false
end

-- ✅ chỉ hop khi đang ở farm map
local function tryTeleportOnce()
    if game.PlaceId ~= FARM_PLACEID then
        warn("[ChestFarm] Ở lobby, không hop.")
        return false
    end
    local page = fetchServerPage(cursor)
    if not page or not page.data then return false end
    cursor = (page.nextPageCursor and page.nextPageCursor ~= "null") and page.nextPageCursor or ""
    for _, v in ipairs(page.data) do
        local sid = tostring(v.id)
        if tonumber(v.playing) and tonumber(v.maxPlayers) and tonumber(v.playing) < tonumber(v.maxPlayers) then
            if not hasValue(AllIDs, sid) and regionMatch(v) then
                table.insert(AllIDs, sid)
                isTeleporting = true
                pcall(function() TeleportService:TeleportToPlaceInstance(PlaceID, sid, game:GetService("Players").LocalPlayer) end)
                task.delay(5, function() isTeleporting = false end)
                return true
            end
        end
    end
    return false
end

-- ===== Noclip =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
getgenv().NoClip = true
RunService.Stepped:Connect(function()
    pcall(function()
        local char, head = LocalPlayer.Character, LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
        if not (char and head) then return end
        if getgenv().NoClip then
            if not head:FindFirstChild("BodyClip") then
                local bv = Instance.new("BodyVelocity")
                bv.Name = "BodyClip"; bv.Velocity = Vector3.new(0,0,0)
                bv.MaxForce = Vector3.new(9e9,9e9,9e9); bv.P = 15000; bv.Parent = head
            end
            for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end
        else
            local clip = head:FindFirstChild("BodyClip"); if clip then clip:Destroy() end
            for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=true end end
        end
    end)
end)

-- ===== Teleport lại khi có người Create =====
local lp = Players.LocalPlayer
local function L_V1(pos) if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then lp.Character:SetPrimaryPartCFrame(pos) end end
local function backToCreate()
    for _, tele in ipairs(workspace:GetChildren()) do
        if tele:IsA("Model") and tele.Name:find("Teleporter") then
            local gui = tele:FindFirstChild("BillboardHolder", true)
            if gui and gui:FindFirstChildOfClass("BillboardGui") then
                local txt = gui:FindFirstChildOfClass("TextLabel")
                if txt and txt.Text:lower():find("create") then
                    local entryPart = tele:FindFirstChildWhichIsA("BasePart")
                    if entryPart and lp.Character then
                        L_V1(entryPart.CFrame + Vector3.new(0,3,0))
                        warn("[ChestFarm] Teleport lại chỗ Create")
                        return
                    end
                end
            end
        end
    end
end
spawn(function()
    while task.wait(1) do
        if game.PlaceId ~= FARM_PLACEID then backToCreate() end
    end
end)

-- ===== Chest Farm (giữ nguyên phần cũ) =====
-- ... (toàn bộ logic farm chest, diamond, hop server khi thiếu chest, bạn giữ nguyên như file trước, chỉ thay tryTeleportOnce mới)


