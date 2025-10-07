local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local VirtualInputManagerService = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

function AutoJoinGame()
    getgenv().config = getgenv().config or {}
    if getgenv().config["Follow Join Player"] == nil then getgenv().config["Follow Join Player"] = false end
    getgenv().config["Follow Target"] = getgenv().config["Follow Target"] or ""
    getgenv().config["Teams"] = getgenv().config["Teams"] or {}
    getgenv().config["Team Start Delay"] = getgenv().config["Team Start Delay"] or 10
    getgenv().config["Team Near Distance"] = getgenv().config["Team Near Distance"] or 30
    getgenv().config["Follower Scan Timeout"] = getgenv().config["Follower Scan Timeout"] or 25
    getgenv().config["Follower Fallback"] = getgenv().config["Follower Fallback"] or false
    getgenv().config["Leader Wait Timeout"] = getgenv().config["Leader Wait Timeout"] or 10
    getgenv().config["Leader Retry Delay"] = getgenv().config["Leader Retry Delay"] or 1

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local lp = Players.LocalPlayer

    local function getHRP(plr)
        local p = plr or lp
        local char = p.Character or p.CharacterAdded:Wait()
        return char:WaitForChild("HumanoidRootPart")
    end

    local function safeTouch(part)
        local hrp = getHRP(lp)
        if typeof(firetouchinterest) == "function" and part and part:IsA("BasePart") then
            firetouchinterest(hrp, part, 0)
            task.wait(0.1)
            firetouchinterest(hrp, part, 1)
            return true
        end
        return false
    end

    local function rf(name)
        return ReplicatedStorage:WaitForChild("RemoteFunctions"):FindFirstChild(name)
    end

    local function lobbyInvoke(lobbyId, setMapName, setMaxPlayersTo, doStart)
        local suffix = tostring(lobbyId)
        if setMapName then
            local r = rf(("LobbySetMap_%s"):format(suffix))
            if r then r:InvokeServer("map_back_garden") end
        end
        if setMaxPlayersTo then
            local r = rf(("LobbySetMaxPlayers_%s"):format(suffix))
            if r then r:InvokeServer(setMaxPlayersTo) end
        end
        if doStart then
            local r = rf(("StartLobby_%s"):format(suffix))
            if r then r:InvokeServer() end
        end
    end

    local function lobbyLeave(lobbyId)
        local r = rf(("LeaveLobby_%s"):format(tostring(lobbyId)))
        if r then r:InvokeServer() end
    end

    local function readLobbyAttrs(lobbyModel)
        return lobbyModel:GetAttribute("MaxPlayers"), lobbyModel:GetAttribute("Players"), lobbyModel:GetAttribute("LobbyId")
    end

    local function getLobbiesRoot()
        local root = workspace:FindFirstChild("Map")
        return root and root:FindFirstChild("LobbiesFarm") or nil
    end

    local function getAllLobbies()
        local root = getLobbiesRoot()
        if not root then return {} end
        local out = {}
        for _, m in ipairs(root:GetChildren()) do
            if m:IsA("Model") and m.Name == "GameLobby" then
                table.insert(out, m)
            end
        end
        return out
    end

    local function findCagePart(lobbyModel)
        local cage = lobbyModel:FindFirstChild("Cage")
        if not cage then return nil end
        return cage:FindFirstChildWhichIsA("BasePart")
    end

    local function getLobbyAABB(lobbyModel)
        local cframe, size = lobbyModel:GetPivot(), lobbyModel:GetExtentsSize()
        local half = size * 0.5
        local minV = (cframe.Position - half)
        local maxV = (cframe.Position + half)
        return minV, maxV
    end

    local function posInsideLobby(pos, lobbyModel)
        local minV, maxV = getLobbyAABB(lobbyModel)
        return pos.X >= minV.X and pos.X <= maxV.X and pos.Y >= minV.Y and pos.Y <= maxV.Y and pos.Z >= minV.Z and pos.Z <= maxV.Z
    end

    local function getLobbyContainingPosition(pos)
        for _, lobby in ipairs(getAllLobbies()) do
            if posInsideLobby(pos, lobby) then
                local _, _, lobbyId = readLobbyAttrs(lobby)
                return lobby, lobbyId
            end
        end
        return nil, nil
    end

    local function isNear(p1, p2, dist)
        return (p1 - p2).Magnitude <= (dist or getgenv().config["Team Near Distance"])
    end

    local function eq(a,b)
        if not a or not b then return false end
        return tostring(a):lower() == tostring(b):lower()
    end

    local function detectTeamRole()
        local me = lp.Name
        for _, team in pairs(getgenv().config["Teams"]) do
            local target = team["Target Player"]
            local followers = team["Player Follow Target"] or {}
            if eq(target, me) then
                local size = 1 + #followers
                return "Leader", target, followers, size
            end
            for _, f in ipairs(followers) do
                if eq(f, me) then
                    local size = 1 + #followers
                    return "Follower", target, followers, size
                end
            end
        end
        if getgenv().config["Follow Join Player"] and getgenv().config["Follow Target"] ~= "" then
            return "Follower", getgenv().config["Follow Target"], {}, nil
        end
        return "None", nil, nil, nil
    end

    local function anyOutsiderInside(lobbyModel, allowedSet)
        for _, p in ipairs(Players:GetPlayers()) do
            local name = p.Name
            if not allowedSet[name:lower()] then
                local ok, hrp = pcall(getHRP, p)
                if ok and hrp and posInsideLobby(hrp.Position, lobbyModel) then
                    return true
                end
            end
        end
        return false
    end

    local function followersInsideAndNear(lobbyModel, followers)
        local leaderPos = getHRP(lp).Position
        for _, name in ipairs(followers) do
            local p = Players:FindFirstChild(name)
            if not p or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then
                return false
            end
            local pos = p.Character.HumanoidRootPart.Position
            if not posInsideLobby(pos, lobbyModel) then
                return false
            end
            if not isNear(leaderPos, pos) then
                return false
            end
        end
        return true
    end

    local function pickEmptyLobby(teamSize)
        local exact, exactId, exactPart = nil, nil, nil
        local fallback, fallbackId, fallbackPart = nil, nil, nil
        for _, lobby in ipairs(getAllLobbies()) do
            local maxP, curP, lobbyId = readLobbyAttrs(lobby)
            if maxP and curP and lobbyId and curP == 0 then
                local part = findCagePart(lobby)
                if part then
                    if maxP == teamSize and not exact then
                        exact, exactId, exactPart = lobby, lobbyId, part
                    elseif maxP >= teamSize and not fallback then
                        fallback, fallbackId, fallbackPart = lobby, lobbyId, part
                    end
                end
            end
        end
        if exact then return exact, exactId, exactPart end
        if fallback then return fallback, fallbackId, fallbackPart end
        return nil, nil, nil
    end

    local function leaderJoinAndGuard(teamSize, followers)
        local allow = {}
        allow[lp.Name:lower()] = true
        for _, n in ipairs(followers) do allow[tostring(n):lower()] = true end
        local waitTimeout = tonumber(getgenv().config["Leader Wait Timeout"]) or 10
        local retryDelay = tonumber(getgenv().config["Leader Retry Delay"]) or 1
        while true do
            local lobby, lobbyId, part = pickEmptyLobby(teamSize)
            if not lobby or not lobbyId or not part then
                task.wait(retryDelay)
            else
                if safeTouch(part) then
                    lobbyInvoke(lobbyId, true, teamSize, false)
                    local t0 = os.clock()
                    while true do
                        local maxP, curP = readLobbyAttrs(lobby)
                        if not maxP or not curP then
                            lobbyLeave(lobbyId)
                            break
                        end
                        if curP > teamSize then
                            lobbyLeave(lobbyId)
                            break
                        end
                        if anyOutsiderInside(lobby, allow) then
                            lobbyLeave(lobbyId)
                            break
                        end
                        if curP == teamSize and followersInsideAndNear(lobby, followers) then
                            lobbyInvoke(lobbyId, false, false, true)
                            return true
                        end
                        if os.clock() - t0 > waitTimeout then
                            lobbyLeave(lobbyId)
                            break
                        end
                        task.wait(0.25)
                    end
                end
                task.wait(retryDelay)
            end
        end
    end

    local function getLobbyForPlayer(plrName)
        local p = Players:FindFirstChild(plrName)
        if not p or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then return nil, nil end
        local pos = p.Character.HumanoidRootPart.Position
        return getLobbyContainingPosition(pos)
    end

    local function followerShadowLeader(targetName, timeout)
        local limit = timeout or getgenv().config["Follower Scan Timeout"]
        local t0 = os.clock()
        local joinedLobbyId = nil
        local function tryFollow()
            local lobby, lobbyId = getLobbyForPlayer(targetName)
            if not lobby or not lobbyId then return false end
            local part = findCagePart(lobby)
            if not part then return false end
            if joinedLobbyId and joinedLobbyId ~= lobbyId then
                lobbyLeave(joinedLobbyId)
                joinedLobbyId = nil
                task.wait(0.2)
            end
            if safeTouch(part) then
                joinedLobbyId = lobbyId
                return true
            end
            return false
        end
        while os.clock() - t0 <= limit do
            if tryFollow() then break end
            task.wait(1)
        end
        if not joinedLobbyId then return false end
        while true do
            local lobby, lobbyId = getLobbyForPlayer(targetName)
            if not lobby or not lobbyId or lobbyId ~= joinedLobbyId then
                lobbyLeave(joinedLobbyId)
                return false
            end
            task.wait(0.5)
        end
    end

    local function joinIndependent()
        local lobbies = getAllLobbies()
        local pick, pickId = nil, nil
        for _, lobby in ipairs(lobbies) do
            local maxP, curP, lobbyId = readLobbyAttrs(lobby)
            if maxP and curP and lobbyId and curP == 0 then
                pick, pickId = lobby, lobbyId
                break
            end
        end
        if not pick then
            for _, lobby in ipairs(lobbies) do
                local maxP, curP, lobbyId = readLobbyAttrs(lobby)
                if maxP and curP and lobbyId and curP < maxP then
                    pick, pickId = lobby, lobbyId
                    break
                end
            end
        end
        if pick and pickId then
            local part = findCagePart(pick)
            if part and safeTouch(part) then
                lobbyInvoke(pickId, true, false, true)
                return true
            end
        end
        return false
    end

    local role, target, followers, teamSize = detectTeamRole()
    local ok = false
    if role == "Leader" and teamSize and teamSize >= 1 then
        ok = leaderJoinAndGuard(teamSize, followers)
        if not ok then ok = false end
    elseif role == "Follower" and target then
        ok = followerShadowLeader(target, getgenv().config["Follower Scan Timeout"])
        if not ok and getgenv().config["Follower Fallback"] then ok = joinIndependent() end
    else
        if getgenv().config["Follow Join Player"] and getgenv().config["Follow Target"] ~= "" then
            ok = followerShadowLeader(getgenv().config["Follow Target"], getgenv().config["Follower Scan Timeout"])
            if not ok and getgenv().config["Follower Fallback"] then ok = joinIndependent() end
        else
            ok = joinIndependent()
        end
    end
    if not ok then warn("[Lobby] No suitable lobby found or join failed.") end
end

local ReplicatedStorageService = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local WorkspaceService = game:GetService("Workspace")

local PlaceUnitRemote = (ReplicatedStorageService:WaitForChild("RemoteFunctions"):FindFirstChild("PlaceUnit"))
    or (ReplicatedStorageService.RemoteFunctions:FindFirstChild("PlaceUnitRemote"))

local function eq(a,b) if not a or not b then return false end return tostring(a):lower()==tostring(b):lower() end

local function detectTeamRoleAndIndex()
    local me = LocalPlayer.Name
    local teams = (getgenv().config and getgenv().config["Teams"]) or {}
    for _, team in pairs(teams) do
        local leader = team["Target Player"]
        local followers = team["Player Follow Target"] or {}
        if eq(me, leader) then return "Leader", 0, leader, followers end
        for i,name in ipairs(followers) do
            if eq(me, name) then return "Follower", i, leader, followers end
        end
    end
    return "None", 0, nil, {}
end

local ROLE_POS = {
    Leader  = Vector3.new(-845.3312377929688, 61.93030548095703, -165.91140747070312),
    Member1 = Vector3.new(-854.4274291992188, 61.93030548095703, -125.76570892333984),
    Member2 = Vector3.new(-810.5430908203125, 61.93030548095703, -120.365478515625),
    Member3 = Vector3.new(-904.057861328125, 61.93030548095703, -120.10423278808594),
}

local function SpiralPlacement(origin, idx)
    local spacing = 1

    local r = math.ceil((math.sqrt(idx) - 1) / 2)
    local base = (2 * r - 1) ^ 2 + 1
    local k = idx - base
    local edge = r * 2
    local x, z

    if k < edge then
        x, z = r, -r + k
    elseif k < edge * 2 then
        x, z = r - (k - edge), r
    elseif k < edge * 3 then
        x, z = -r, r - (k - edge * 2)
    else
        x, z = -r + (k - edge * 3), -r
    end

    return origin + Vector3.new(x * spacing, 0, z * spacing)
end


local function IsInsideAnyPart(pos, parts)
    for _, p in ipairs(parts) do
        if p:IsA("BasePart") then
            local s = p.Size
            local cf = p.CFrame
            local lp = cf:PointToObjectSpace(pos)
            if math.abs(lp.X) <= s.X/2 and math.abs(lp.Y) <= s.Y/2 and math.abs(lp.Z) <= s.Z/2 then
                return true
            end
        end
    end
    return false
end

local function getCash() return tonumber(LocalPlayer:GetAttribute("Cash")) or 0 end
local function getMaxUnitsCap() return tonumber(LocalPlayer:GetAttribute("MaxUnitsPlaced")) or 0 end

local function countPlacedUnitsInMap(entitiesFolder)
    local c=0
    for _,ch in ipairs(entitiesFolder:GetChildren()) do
        if typeof(ch.Name)=="string" and ch.Name:sub(1,5)=="unit_" then c+=1 end
    end
    return c
end

local function parseUnitFromTool(tool)
    local itemId = tool:GetAttribute("ItemID")
    if not itemId or type(itemId)~="string" then return nil end
    local id = itemId:gsub("^tl_unitplacer_", "")
    local desc = tool:GetAttribute("Description")
    local cost = 0
    if type(desc)=="string" then
        local n = desc:gsub("[^0-9]", "")
        cost = tonumber(n) or 0
    end
    return {id=id, cost=cost, tool=tool}
end

local function getUnitsFromBackpack()
    local t = {}
    local bp = LocalPlayer:WaitForChild("Backpack")
    for _,tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") then
            local u = parseUnitFromTool(tool)
            if u and u.id and u.cost and u.cost>=0 then table.insert(t,u) end
        end
    end
    table.sort(t, function(a,b) return a.cost<b.cost end)
    return t
end

local function roleOrigin(role, idx)
    if role=="Leader" then return ROLE_POS.Leader end
    if role=="Follower" then
        if idx==1 then return ROLE_POS.Member1 end
        if idx==2 then return ROLE_POS.Member2 end
        if idx==3 then return ROLE_POS.Member3 end
    end
    return ROLE_POS.Leader
end
local GameScreen = lp.PlayerGui.GameGui.Screen.Middle
function ClickUI(v57, v58)
    local v59 = workspace.CurrentCamera.ViewportSize

    if v58 == "bottom-left" then
        local v60, v61 = 50, v59.Y - 50
        VirtualInputManagerService:SendMouseButtonEvent(v60, v61, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManagerService:SendMouseButtonEvent(v60, v61, 0, false, game, 0)
        return
    end

    local v62 = nil
    local v63 = lp.PlayerGui.GameGuiNoInset:FindFirstChild("Screen")
    local v64 = lp.PlayerGui.GameGuiNoInset.Screen.Top:FindFirstChild("WaveControls")
    if v63 and v63:FindFirstChild("Top") and v63.Top:FindFirstChild("WaveControls") then
        v62 = v63.Top.WaveControls:FindFirstChild(v57, true)
    elseif v64 and v64:FindFirstChild("TickSpeed") and v64.TickSpeed:FindFirstChild("Items") then
        v62 = v64.TickSpeed.Items:FindFirstChild(v57, true)
    end

    if v62 then
        GuiService.SelectedObject = v62
        VirtualInputManagerService:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        VirtualInputManagerService:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        task.wait(0.1)
        GuiService.SelectedObject = nil
    else
        warn("Button not found: " .. v57)
    end
end

local function getUnitsPlaced()
    local v = LocalPlayer:GetAttribute("UnitsPlaced")
    return typeof(v)=="number" and v or 0
end

local function getModelPosition(m)
    if m.PrimaryPart then return m.PrimaryPart.Position end
    local cf = m:GetPivot()
    return cf.Position
end

local function findNewUnitIdNear(entitiesFolder, nearPos, radius)
    local best, bestDist = nil, math.huge
    for _, ch in ipairs(entitiesFolder:GetChildren()) do
        if typeof(ch.Name)=="string" and ch.Name:sub(1,5)=="unit_" then
            local ok, pos = pcall(getModelPosition, ch)
            if ok and pos then
                local d = (pos - nearPos).Magnitude
                if d < (radius or 15) then
                    local idAttr = ch:GetAttribute("ID")
                    if typeof(idAttr)=="number" then
                        if d < bestDist then
                            bestDist = d
                            best = idAttr
                        end
                    end
                end
            end
        end
    end
    return best
end

function eb()
    if not getgenv().config["FPSBoost"] then return end
    local rs = game:GetService("RunService")
    local plr = game:GetService("Players")
    local lgt = game:GetService("Lighting")
    local ws = game:GetService("Workspace")
    local done = {}

    local function fx(v)
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            v:Destroy()
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v:Destroy()
        elseif v:IsA("MeshPart") or v:IsA("Part") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
            v.Transparency = 1
        elseif v:IsA("SurfaceGui") or v:IsA("BillboardGui") then
            v.Enabled = false
        elseif v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then
            v:Destroy()
        elseif v:IsA("Model") then
            local n = v.Name:lower()
            if n:match("tree") or n:match("bush") or n:match("deco") then
                v:Destroy()
            end
        end
    end

    lgt.FogEnd = 1e5
    lgt.FogStart = 1e5
    lgt.GlobalShadows = false
    lgt.Brightness = 0
    lgt.ClockTime = 14
    pcall(function()
        game:GetService("UserInputService").MouseDeltaSensitivity = 1
        local b = lgt:FindFirstChildOfClass("BlurEffect")
        if b then b:Destroy() end
    end)

    local t = ws:FindFirstChildOfClass("Terrain")
    if t then
        t.WaterWaveSize = 0
        t.WaterWaveSpeed = 0
        t.WaterReflectance = 0
        t.WaterTransparency = 1
    end

    for _, p in pairs(plr:GetPlayers()) do
        local c = p.Character
        if c then
            for _, d in ipairs(c:GetDescendants()) do
                fx(d)
            end
        end
    end

    for _, o in ipairs(game:GetDescendants()) do
        if not done[o] then
            fx(o)
            done[o] = true
        end
    end

    game.DescendantAdded:Connect(function(o)
        task.wait()
        if not done[o] then
            fx(o)
            done[o] = true
        end
    end)

    plr.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function(c)
            task.wait(1)
            for _, d in ipairs(c:GetDescendants()) do
                fx(d)
            end
        end)
    end)
end

eb()


















local function PlaceUnitsLoop()
    local role, memberIdx = detectTeamRoleAndIndex()
    local baseOrigin = roleOrigin(role, memberIdx)

    local mapRoot = WorkspaceService:WaitForChild("Map")
    local pathFolder = mapRoot:WaitForChild("Path")
    local entitiesFolder = mapRoot:WaitForChild("Entities")
    local pathParts = pathFolder:GetChildren()

    local units = getUnitsFromBackpack()
    local cap = getMaxUnitsCap()
    if cap <= 0 then cap = ConfigData and ConfigData.MaxUnits or 1 end

    local tryIndex, unitCursor = 0, 1
    local placedIDs = {}

    while getUnitsPlaced() < cap do
        if GameScreen:WaitForChild("GameEnd").Visible then return end
        if unitCursor > #units then unitCursor = 1 end
        local u = units[unitCursor]
        if not u then break end

        while getCash() < u.cost do
            if GameScreen:WaitForChild("GameEnd").Visible then return end
            task.wait(0.2)
        end

        local pos, attempts = nil, 0
        repeat
            tryIndex += 1
            pos = SpiralPlacement(baseOrigin, tryIndex)
            attempts += 1
            if attempts > 100 then break end
        until not IsInsideAnyPart(pos, pathParts)

        if attempts > 100 then
            warn("cant place unit")
            break
        end

        local payload = {
            [1] = u.id,
            [2] = {
                Valid = true,
                Position = pos,
                CF = CFrame.new(pos) * CFrame.Angles(math.pi, 0, math.pi),
                Rotation = 180
            }
        }

        local ok = false
        if PlaceUnitRemote then
            ok = pcall(function() return PlaceUnitRemote:InvokeServer(unpack(payload)) end)
        else
            ok = pcall(function() return ReplicatedStorageService.RemoteFunctions.PlaceUnit:InvokeServer(unpack(payload)) end)
        end

        task.wait(0.4)

        do
            local id = findNewUnitIdNear(entitiesFolder, pos, 18)
            if id and not table.find(placedIDs, id) then
                table.insert(placedIDs, id)
            end
        end

        unitCursor += 1
        task.wait(0.1)
    end

    if #placedIDs == 0 then return end
    task.spawn(function()
        local UpgradeRF = ReplicatedStorageService.RemoteFunctions:FindFirstChild("UpgradeUnit")
        if not UpgradeRF then return end
        local idx = 1
        while not GameScreen:WaitForChild("GameEnd").Visible do
            local id = placedIDs[idx]
            if id then
                for i=1,10 do
                    pcall(function()
                        return UpgradeRF:InvokeServer(id)
                    end)
                    task.wait(0.15)
                    if GameScreen:WaitForChild("GameEnd").Visible then return end
                end
            end
            idx = idx + 1
            if idx > #placedIDs then idx = 1 end
            task.wait(0.2)
        end
    end)
end


local function GameLoop()
    while true do
        while GameScreen:WaitForChild("DifficultyVote").Visible do
            task.wait(0.5)
        end
        while GameScreen:WaitForChild("GameEnd").Visible do
            task.wait(0.5)
        end

        task.wait(1)
        PlaceUnitsLoop()
        while not GameScreen:WaitForChild("GameEnd").Visible do
            task.wait(1)
        end
        
    end
end
local function AutoRestartGame()
    local v69 = GameScreen:WaitForChild("GameEnd")
    local v70 = ReplicatedStorageService.RemoteFunctions.RestartGame
    local v71 = 108533757090220

    task.spawn(function()
        while true do
            if v69.Visible then
                task.wait(2)
                v70:InvokeServer()

                local v72 = tick()
                while v69.Visible do
                    task.wait(0.2)
                    if tick() - v72 > 10 then
                        TeleportService:Teleport(v71, LocalPlayer)
                        return
                    end
                end
            else
                task.wait(0.2)
            end
        end
    end)
end
local function AutoVoteDifficulty()
    local voteGui = GameScreen:WaitForChild("DifficultyVote")
    local PlaceDifficultyVote = ReplicatedStorageService.RemoteFunctions:WaitForChild("PlaceDifficultyVote")

    task.spawn(function()
        while true do
            if voteGui.Visible then
                task.wait(0.2)
                local bp = LocalPlayer:WaitForChild("Backpack")
                local hasSaw = bp:FindFirstChild("Gnomatic Saw") ~= nil

                local diff = hasSaw and "dif_impossible" or "dif_easy"
                pcall(function()
                    PlaceDifficultyVote:InvokeServer(diff)
                end)
                while voteGui.Visible do
                    task.wait(0.2)
                end
            else
                task.wait(0.2)
            end
        end
    end)
end

local function getSeedsCount()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local sv = ls and ls:FindFirstChild("Seeds")
    if sv and typeof(sv.Value) == "string" then
        local n = tonumber((sv.Value:gsub(",", ""))) or 0
        return n
    end
    return 0
end
local function AutoBuyUnit()
    task.spawn(function()
        local BUY_RF = ReplicatedStorageService:WaitForChild("RemoteFunctions"):WaitForChild("BuyUnitWithSeeds")
        local TARGET_UNIT_ID = "unit_mech_saw"
        local THRESHOLD = 150000

        local lastT = 0
        while true do
            if os.clock() - lastT < 0.5 then
                task.wait(0.2)
            end
            lastT = os.clock()

            local seeds = getSeedsCount()
            if seeds >= THRESHOLD then
                local args = { [1] = TARGET_UNIT_ID }
                pcall(function()
                    BUY_RF:InvokeServer(unpack(args))
                end)
                task.wait(1.0)
            else
                task.wait(0.25)
            end
        end
    end)
end

function SetupLobby()
    AutoJoinGame()
end
function SetupGame()
    AutoVoteDifficulty()
    AutoRestartGame()
    task.spawn(function()
        local diffVote = GameScreen:WaitForChild("DifficultyVote")
        local gameEnd = GameScreen:WaitForChild("GameEnd")
        while task.wait(0.5) do
            if diffVote.Visible == false and gameEnd.Visible == false then
                ClickUI("AutoSkip")
                ClickUI("2")
                break
            end
        end
    end)
    task.spawn(GameLoop)
end
function Main()
    if game.PlaceId == 108533757090220 then
        task.spawn(AutoBuyUnit)
        SetupLobby()
    elseif game.PlaceId == 123516946198836 then
      task.spawn(AutoBuyUnit)
        SetupGame()
    else 
        print("Not Supported")
    end
end
Main()
