-- ================================================================
-- Mochi Farm (FULL, no UI) — Hop API FIX + Lobby Auto Join/Create
-- + Chỉ hop khi ở MAP FARM và SAU KHI NHẶT XONG
-- + Tránh full, tránh trùng JobId (Visited TTL 3h), region filter (optional)
-- + Anti TeleportFailed, safe-spawn, FPS boost AN TOÀN (không "tẩy trắng" map)
-- + Farm Chest + hút Diamond; ổn định Emulator/PC
-- ================================================================

repeat task.wait() until game:IsLoaded()

-- ================== CONFIG ==================
local Config = {
  FarmPlaceId = 126509999114328,      -- map farm của Mochi
  ChestNameExclude = "Snow",           -- bỏ chest tuyết nếu có
  HopCheckPromptTimeout = 10,          -- giây bấm ProximityPrompt tối đa cho 1 chest
  VisitedTTL = 3*60*60,                -- 3 giờ không rejoin lại JobId đó
  HopBackoffMin = 1.2,
  HopBackoffMax = 2.2,
  HopAfterCollect = true,              -- CHỈ hop sau khi nhặt xong (hết chest/diamond)
  SelectRegion = {
    Enabled = false,
    Regions = { "singapore", "tokyo", "us-east" }, -- lọc mềm theo chuỗi
  },
  -- API pool: thử lần lượt để "sống dai" khi Roblox đổi
  ServerAPIs = {
    "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100&cursor=%s",
    "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
  },
}

-- ================== SERVICES ==================
local Http = game:GetService("HttpService")
local TS   = game:GetService("TeleportService")
local RunS = game:GetService("RunService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- ================== STATE ==================
local STATE = {
  BusyTeleport = false,
  Visited = {},          -- [jobId] = lastTime
  Cursor = "",
  LastHop = 0,
}

local function now() return os.time() end
local function rnd(a,b) return a + math.random()*(b-a) end

-- ================== NOTIFY ==================
local function notify(t)
  pcall(function()
    game.StarterGui:SetCore("SendNotification", { Title = "Mochi Farm", Text = t, Duration = 3 })
  end)
end

-- ================== ANTI TELEPORT PROMPT ==================
local function suppressTeleportErrors()
  local gui = game.CoreGui:FindFirstChild("RobloxPromptGui", true)
  if not gui then return end
  local overlay = gui:FindFirstChild("promptOverlay")
  if not overlay then return end
  local function hook(v)
    if v.Name == "ErrorPrompt" then
      local function hide()
        local ok, has = pcall(function()
          return v.Visible and v:FindFirstChild("TitleFrame") and v.TitleFrame:FindFirstChild("ErrorTitle")
        end)
        if ok and has and v.TitleFrame.ErrorTitle.Text == "Teleport Failed" then
          v.Visible = false
        end
      end
      hide()
      v:GetPropertyChangedSignal("Visible"):Connect(hide)
    end
  end
  for _,c in ipairs(overlay:GetChildren()) do hook(c) end
  overlay.ChildAdded:Connect(hook)
end
pcall(suppressTeleportErrors)

-- ================== FPS BOOST (AN TOÀN) ==================
pcall(function() settings().Rendering.QualityLevel = "Level01" end)
local g = game
g.Lighting.GlobalShadows = false
g.Lighting.FogEnd = 1e10
g.Lighting.Brightness = 0

local SAFE_FOLDERS = {
  "workspace.Map", "workspace.Items", "workspace.Teleporters",
  "workspace.Teleporter", "workspace.Spawns", "workspace.Characters"
}

local function isInSafeFolder(inst)
  local cur, full = inst, ""
  while cur do
    full = (cur.Name .. (full == "" and "" or "." .. full))
    cur = cur.Parent
  end
  for _, p in ipairs(SAFE_FOLDERS) do
    if string.find(full, p, 1, true) then return true end
  end
  return false
end

local function optimize(inst)
  if isInSafeFolder(inst) then return end
  if inst:IsA("PostEffect") then inst.Enabled=false return end
  if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then inst.Enabled=false return end
  if inst:IsA("Explosion") then inst.BlastPressure,inst.BlastRadius=1,1 return end
  if inst:IsA("Fire") or inst:IsA("SpotLight") or inst:IsA("Smoke") or inst:IsA("Sparkles") then inst.Enabled=false return end
  if inst:IsA("BasePart") or inst:IsA("MeshPart") then
    inst.CastShadow=false
    if inst.Material ~= Enum.Material.SmoothPlastic then inst.Material = Enum.Material.SmoothPlastic end
  elseif inst:IsA("Decal") or inst:IsA("Texture") then
    inst.Transparency = math.max(inst.Transparency, 0.15)
  end
end
for _, v in ipairs(g:GetDescendants()) do optimize(v) end
g.DescendantAdded:Connect(optimize)
for _, e in ipairs(g.Lighting:GetDescendants()) do if e:IsA("PostEffect") then e.Enabled=false end end
g.Lighting.DescendantAdded:Connect(function(e) if e:IsA("PostEffect") then e.Enabled=false end end)

-- ================== NOCLIP (bật sau khi đã safe-spawn) ==================
getgenv().NoClip = false
RunS.Stepped:Connect(function()
  if not getgenv().NoClip then return end
  local ch = LP.Character
  if not ch then return end
  for _,v in ipairs(ch:GetDescendants()) do
    if v:IsA("BasePart") then v.CanCollide=false end
  end
end)

-- ================== HUD COUNT GEMS ==================
task.spawn(function()
  local screen = Instance.new("ScreenGui")
  screen.Name = "MochiHUD"
  screen.ResetOnSpawn = false
  screen.Parent = game:GetService("CoreGui")
  local tl = Instance.new("TextLabel", screen)
  tl.Size = UDim2.new(1,0,1,0)
  tl.BackgroundTransparency = 1
  tl.TextColor3 = Color3.new(1,1,1)
  tl.TextStrokeTransparency = 0.6
  tl.Font = Enum.Font.GothamBold
  tl.TextScaled = true
  tl.Text = "0"
  while task.wait(0.25) do
    local pg = LP:FindFirstChild("PlayerGui")
    local count = pg and pg:FindFirstChild("Interface") and pg.Interface:FindFirstChild("DiamondCount")
                  and pg.Interface.DiamondCount:FindFirstChild("Count")
    if count and count:IsA("TextLabel") then tl.Text = count.Text end
  end
end)

-- ================== SAFE SPAWN TRONG FARM ==================
local function getAnySpawn()
  for _, v in ipairs(workspace:GetDescendants()) do
    if v:IsA("SpawnLocation") or (v:IsA("BasePart") and (v.Name:lower():find("spawn") or v.Name:lower():find("safe"))) then
      return v
    end
  end
  return nil
end

local function safeSpawnInFarm()
  if game.PlaceId ~= Config.FarmPlaceId then return end
  local ch = LP.Character or LP.CharacterAdded:Wait()
  local hrp = ch:WaitForChild("HumanoidRootPart", 10)
  task.wait(0.4)
  if not hrp then return end
  local y = hrp.Position.Y
  if (y < -20) or (y > 1e5) then
    local sp = getAnySpawn()
    if sp then hrp.CFrame = sp.CFrame + Vector3.new(0,5,0) else hrp.CFrame = CFrame.new(0,15,0) end
    task.wait(0.2)
  end
  -- bật noclip sau khi đứng an toàn
  getgenv().NoClip = true
end

-- ================== DIAMOND & CHEST HELPERS ==================
local FogCF, FogSize
pcall(function()
  local b = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Boundaries")
  local fog = b and b:FindFirstChild("Fog")
  if fog then FogCF, FogSize = fog:GetBoundingBox() end
end)

local function outsideFog(pos)
  if not (FogCF and FogSize) then return true end
  local a = FogCF.Position - FogSize/2
  local b = FogCF.Position + FogSize/2
  return (pos.X < a.X or pos.Y < a.Y or pos.Z < a.Z or pos.X > b.X or pos.Y > b.Y or pos.Z > b.Z)
end

local function tpCFrame(cf)
  local ch = LP.Character
  if ch and ch:FindFirstChild("HumanoidRootPart") then
    ch:SetPrimaryPartCFrame(cf)
  end
end

local function collectDiamondsOnce()
  local RS = game:GetService("ReplicatedStorage")
  local ev = RS:FindFirstChild("RemoteEvents", true)
  local take = ev and ev:FindFirstChild("RequestTakeDiamonds")
  if not take then return end
  for _,d in ipairs(workspace:GetDescendants()) do
    if d:IsA("Model") and d.Name == "Diamond" and game.PlaceId == Config.FarmPlaceId then
      local pv = d:GetPivot()
      tpCFrame(CFrame.new(pv.Position))
      pcall(function() take:FireServer(d) end)
      task.wait(0.05)
    end
  end
end

local function findNearestChest()
  local ch = LP.Character
  local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
  if not hrp then return nil end
  local best, bestD
  for _, v in ipairs(workspace:GetDescendants()) do
    if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find(Config.ChestNameExclude) then
      local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
      if prox then
        local p = v:GetPivot().Position
        if outsideFog(p) then
          local d = (hrp.Position - p).Magnitude
          if not bestD or d < bestD then best, bestD = v, d end
        end
      end
    end
  end
  return best
end

-- ================== HOP SERVER (API MỚI ROBLOX) ==================
local function getCounts(sv)
  local maxp = tonumber(sv.maxPlayers or sv.maxPlayerCount or 0) or 0
  local playing = tonumber(sv.playing or sv.playerCount or 0) or 0
  return maxp, playing
end

local function markVisited(id) if id then STATE.Visited[id] = now() end end
local function isVisited(id)
  if not id or id == game.JobId then return true end
  local t = STATE.Visited[id]
  return t and (now() - t) <= Config.VisitedTTL
end

local function regionPass(sv)
  if not Config.SelectRegion.Enabled then return true end
  local cand = tostring(sv.region or sv.ping or ""):lower()
  for _, r in ipairs(Config.SelectRegion.Regions) do
    if string.find(cand, tostring(r):lower()) then return true end
  end
  return false
end

local function fetchServers(placeId, cursor)
  for _,fmt in ipairs(Config.ServerAPIs) do
    local url = (fmt):format(placeId, cursor or "")
    local ok, data = pcall(function() return Http:JSONDecode(game:HttpGet(url)) end)
    if ok and data and type(data)=="table" and data.data then return data end
  end
  return nil
end

local function chooseServer(placeId)
  for _=1,20 do
    local data = fetchServers(placeId, STATE.Cursor)
    if not data then return nil end
    if data.nextPageCursor and data.nextPageCursor ~= "null" then STATE.Cursor = data.nextPageCursor else STATE.Cursor = "" end

    local cand = {}
    for _,sv in ipairs(data.data or {}) do
      local id = tostring(sv.id or "")
      local maxp, playing = getCounts(sv)
      local hasRoom = maxp > 0 and playing < maxp
      if id ~= "" and hasRoom and (not isVisited(id)) and regionPass(sv) then
        table.insert(cand, { id=id, playing=playing })
      end
    end
    table.sort(cand, function(a,b) return a.playing < b.playing end)
    if #cand > 0 then return cand[1] end
  end
  return nil
end

local function safeTeleport(placeId, jobId)
  if STATE.BusyTeleport then return end
  STATE.BusyTeleport = true
  notify("Đang hop server...")
  markVisited(jobId)
  local ok = pcall(function() TS:TeleportToPlaceInstance(placeId, jobId, LP) end)
  if not ok then STATE.BusyTeleport = false end
end

local function hopNow(reason)
  if (now() - STATE.LastHop) < 2 then return end
  STATE.LastHop = now()
  local target = chooseServer(Config.FarmPlaceId)
  if not target then notify("Không tìm thấy server phù hợp (thử lại sau)."); return end
  markVisited(target.id)
  task.wait(rnd(Config.HopBackoffMin, Config.HopBackoffMax))
  safeTeleport(Config.FarmPlaceId, target.id)
end

-- Đánh dấu server hiện tại để không quay lại
markVisited(game.JobId)

-- ================== LOBBY: AUTO JOIN / CREATE ==================
local TryingLobby = false

local function clickIfButton(btn)
  if not (btn and (btn:IsA("GuiButton"))) then return false end
  local ok = pcall(function()
    if firesignal then
      firesignal(btn.MouseButton1Click)
      firesignal(btn.MouseButton1Down)
      firesignal(btn.MouseButton1Up)
    else
      btn:Activate()
    end
  end)
  return ok
end

local function findLobbyButtons()
  local pg = LP:FindFirstChild("PlayerGui")
  if not pg then return nil, nil end
  local root = pg:FindFirstChild("Interface") or pg:FindFirstChildOfClass("ScreenGui")
  if not root then return nil, nil end
  local joinBtn, createBtn
  for _, d in ipairs(root:GetDescendants()) do
    if d:IsA("TextButton") or d:IsA("ImageButton") then
      local t = ((d.Text and d.Text ~= "") and d.Text or d.Name):lower()
      if (t:find("join") or t:find("play")) and not joinBtn then joinBtn = d end
      if (t:find("create") or t:find("host") or t:find("start")) and not createBtn then createBtn = d end
    end
  end
  return joinBtn, createBtn
end

local function fireTeleporter()
  for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("Model") and (obj.Name:lower():find("teleporter")) then
      local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
      local pad = obj:FindFirstChildWhichIsA("BasePart")
      if pad and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        LP.Character.HumanoidRootPart.CFrame = pad.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.1)
        if prompt then pcall(function() fireproximityprompt(prompt) end) end
        return true
      end
    end
  end
  return false
end

local function ensureInFarm()
  if game.PlaceId == Config.FarmPlaceId then return true end
  if TryingLobby then return false end
  TryingLobby = true
  local t0 = tick()
  while game.PlaceId ~= Config.FarmPlaceId and (tick() - t0) < 60 do
    local joinBtn, createBtn = findLobbyButtons()
    if joinBtn then clickIfButton(joinBtn) task.wait(1.0) end
    if game.PlaceId == Config.FarmPlaceId then break end
    if createBtn then clickIfButton(createBtn) task.wait(1.0) end
    if game.PlaceId == Config.FarmPlaceId then break end
    fireTeleporter()
    task.wait(1.5)
  end
  TryingLobby = false
  return (game.PlaceId == Config.FarmPlaceId)
end

-- ================== MAIN LOOP ==================
notify("Khởi động Mochi Farm (FULL).")

task.spawn(function()
  while task.wait(0.15) do
    if game.PlaceId ~= Config.FarmPlaceId then
      -- Ở LOBBY: tự Join/Create để vào farm (không hop bừa ở lobby)
      ensureInFarm()
    else
      -- Đã vào FARM: chuẩn bị
      safeSpawnInFarm()
      collectDiamondsOnce()

      -- Đếm số chest hợp lệ
      local total = 0
      for _,v in ipairs(workspace:FindFirstChild("Items") and workspace.Items:GetChildren() or {}) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find(Config.ChestNameExclude) then
          local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
          if prox then
            local p = v:GetPivot().Position
            if outsideFog(p) then total += 1 end
          end
        end
      end

      -- Không còn chest và cũng không có diamond -> hop
      local anyDiamond = workspace:FindFirstChild("Diamond", true) ~= nil
      if total == 0 and not anyDiamond and Config.HopAfterCollect then
        notify("Hết chest/diamond → Hop server mới.")
        hopNow("no-loot")
        break
      end

      -- Farm từng chest
      local chest = findNearestChest()
      if not chest and Config.HopAfterCollect then
        notify("Không thấy chest hợp lệ → Hop.")
        hopNow("no-chest")
        break
      end
      if chest then
        local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
        local st = os.time()
        while prox and prox.Parent and (os.time() - st) < Config.HopCheckPromptTimeout do
          local pv = chest:GetPivot()
          tpCFrame(CFrame.new(pv.Position))
          pcall(function() fireproximityprompt(prox) end)
          task.wait(0.35)
          prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
      end

      -- Hút diamond còn lại rồi đánh giá hop
      collectDiamondsOnce()
      local leftDiamond = workspace:FindFirstChild("Diamond", true) ~= nil
      if Config.HopAfterCollect and (not findNearestChest()) and (not leftDiamond) then
        hopNow("after-collect")
        break
      end
    end
  end
end)


