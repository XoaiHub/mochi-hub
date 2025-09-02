local FARM_PLACEID = 126509999114328
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- ===== Teleport service =====
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
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(FARM_PLACEID, sid, lp)
                end)
                task.delay(5, function() isTeleporting = false end)
                return true
            end
        end
    end
    return false
end

-- ===== Teleport lại khi có người Create =====
local function backToCreate()
    for _, tele in ipairs(workspace:GetChildren()) do
        if tele:IsA("Model") and tele.Name:find("Teleporter") then
            local billboardHolder = tele:FindFirstChild("BillboardHolder")
            if billboardHolder then
                local gui = billboardHolder:FindFirstChildOfClass("BillboardGui")
                if gui then
                    local txt = gui:FindFirstChildOfClass("TextLabel")
                    if txt and txt.Text:lower():find("create") then
                        local entryPart = tele:FindFirstChildWhichIsA("BasePart")
                        if entryPart and lp.Character then
                            lp.Character:PivotTo(entryPart.CFrame + Vector3.new(0,3,0))
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
        if game.PlaceId ~= FARM_PLACEID then
            backToCreate()
        end
    end
end)

-- ===== Chest Farm fix =====
local chestSeen = {}
local function getClosestChest()
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local closest, dist
    for _, v in pairs(workspace.Items:GetDescendants()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find("Snow") then
            local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prox then
                local d = (hrp.Position - v:GetPivot().Position).Magnitude
                if not dist or d < dist then
                    closest, dist = v, d
                end
            end
        end
    end
    return closest, dist
end

spawn(function()
    while task.wait(1) do
        if game.PlaceId == FARM_PLACEID then
            local chest = getClosestChest()
            if not chest then
                warn("[ChestFarm] Không tìm thấy chest, hop...")
                tryTeleportOnce()
            else
                local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prox then
                    lp.Character:PivotTo(chest:GetPivot())
                    fireproximityprompt(prox)
                end
            end
        end
    end
end)


