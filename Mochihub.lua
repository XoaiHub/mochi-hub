-- ===== CONFIG =====
local Config = {
    RegionFilterEnabled = false,
    RegionList = { "singapore", "tokyo", "us-east" },
    RetryHttpDelay = 2,
}
local FARM_PLACEID = 126509999114328

-- ===== FPS BOOST =====
local g = game
g.Lighting.GlobalShadows = false
g.Lighting.FogEnd = 1e10
g.Lighting.Brightness = 0
settings().Rendering.QualityLevel = "Level01"

local function optimize(v)
    if v:IsA("BasePart") or v:IsA("MeshPart") then
        v.Material, v.Reflectance, v.CastShadow = Enum.Material.Plastic, 0, false
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
    elseif v:IsA("Model") then
        for _, c in ipairs(v:GetDescendants()) do optimize(c) end
    end
end
for _, v in ipairs(g:GetDescendants()) do optimize(v) end
g.DescendantAdded:Connect(optimize)
for _, e in ipairs(g.Lighting:GetDescendants()) do if e:IsA("PostEffect") then e.Enabled=false end end
g.Lighting.DescendantAdded:Connect(function(e) if e:IsA("PostEffect") then e.Enabled=false end end)

-- ===== SERVICES =====
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- ===== TELEPORT SERVICE =====
local AllIDs, cursor, isTeleporting = {}, "", false
local function fetchServerPage(nextCursor)
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100%s")
        :format(FARM_PLACEID, nextCursor ~= "" and ("&cursor="..nextCursor) or "")
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet(url))
    end)
    if not ok then return nil end
    return data
end
local function tryTeleportOnce()
    if game.PlaceId ~= FARM_PLACEID then
        warn("[ChestFarm] Ở lobby, không hop.")
        return false
    end
    local page = fetchServerPage(cursor)
    if not page or not page.data then return false end
    cursor = (page.nextPageCursor and page.nextPageCursor ~= "null") and page.nextPageCursor or ""
    for _, v in ipairs(page.data) do
        if v.playing < v.maxPlayers then
            local sid = tostring(v.id)
            if not table.find(AllIDs, sid) then
                table.insert(AllIDs, sid)
                warn("[ChestFarm] Hop server:", sid)
                isTeleporting = true
                pcall(function() TeleportService:TeleportToPlaceInstance(FARM_PLACEID, sid, lp) end)
                task.delay(5, function() isTeleporting=false end)
                return true
            end
        end
    end
    return false
end

-- ===== Noclip =====
getgenv().NoClip = true
game:GetService("RunService").Stepped:Connect(function()
    pcall(function()
        local char, head = lp.Character, lp.Character and lp.Character:FindFirstChild("Head")
        if not (char and head) then return end
        if getgenv().NoClip then
            if not head:FindFirstChild("BodyClip") then
                local bv = Instance.new("BodyVelocity")
                bv.Name="BodyClip"; bv.Velocity=Vector3.new(0,0,0)
                bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.P=15000; bv.Parent=head
            end
            for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end
        else
            local clip=head:FindFirstChild("BodyClip"); if clip then clip:Destroy() end
            for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=true end end
        end
    end)
end)

-- ===== TELEPORT TO CREATE =====
local function backToCreate()
    for _, tele in ipairs(workspace:GetChildren()) do
        if tele:IsA("Model") and tele.Name:find("Teleporter") then
            local holder=tele:FindFirstChild("BillboardHolder")
            if holder then
                local gui=holder:FindFirstChildOfClass("BillboardGui")
                if gui then
                    local txt=gui:FindFirstChildOfClass("TextLabel")
                    if txt and txt.Text:lower():find("create") then
                        local entryPart=tele:FindFirstChildWhichIsA("BasePart")
                        if entryPart and lp.Character then
                            lp.Character:PivotTo(entryPart.CFrame+Vector3.new(0,3,0))
                            warn("[ChestFarm] Teleport lại chỗ Create")
                            return
                        end
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

-- ===== CHEST FARM =====
local function getClosestChest()
    local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local closest, dist
    for _, v in pairs(workspace.Items:GetDescendants()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local prox=v:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prox then
                local d=(hrp.Position - v:GetPivot().Position).Magnitude
                if not dist or d<dist then closest,dist=v,d end
            end
        end
    end
    return closest, dist
end

-- ===== DIAMOND FARM =====
local function collectDiamonds()
    for _,d in pairs(workspace:GetDescendants()) do
        if d:IsA("Model") and d.Name=="Diamond" and game.PlaceId==FARM_PLACEID then
            lp.Character:PivotTo(CFrame.new(d:GetPivot().Position))
            RS.RemoteEvents.RequestTakeDiamonds:FireServer(d)
            warn("[DiamondFarm] Collect diamond")
        end
    end
end

-- ===== LOOP FARM =====
spawn(function()
    while task.wait(1) do
        if game.PlaceId==FARM_PLACEID then
            local chest=getClosestChest()
            if not chest then
                warn("[ChestFarm] Không có chest, hop...")
                tryTeleportOnce()
            else
                local prox=chest:FindFirstChildWhichIsA("ProximityPrompt",true)
                if prox then
                    lp.Character:PivotTo(chest:GetPivot())
                    fireproximityprompt(prox)
                    warn("[ChestFarm] Open chest:", chest.Name)
                end
            end
        end
    end
end)

spawn(function()
    while task.wait(0.5) do
        if game.PlaceId==FARM_PLACEID then collectDiamonds() end
    end
end)
