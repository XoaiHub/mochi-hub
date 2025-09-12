-- ================================================================
-- Mochi Farm (No UI) — Hop API FIXED (Roblox games API changes)
-- + Chỉ hop khi ở MAP FARM và SAU KHI NHẶT XONG
-- + Tránh full, tránh trùng JobId, cache Visited 3h
-- + Ưu tiên region (tùy chọn)
-- + Chống TeleportFailed prompt, chống hop quá sớm
-- + Làm việc khi field API đổi tên (playing/playerCount, maxPlayers/maxPlayerCount)
-- ================================================================

repeat task.wait() until game:IsLoaded()

-- ================== CONFIG ==================
local Config = {
  FarmPlaceId = 126509999114328,   -- map farm
  ChestNameExclude = "Snow",        -- bỏ chest tuyết nếu có
  HopCheckDiamondsTimeout = 10,     -- giây chờ 1 chest
  VisitedTTL = 3*60*60,             -- 3 giờ
  HopBackoffMin = 1.2,
  HopBackoffMax = 2.2,

  -- Chỉ hop SAU KHI nhặt xong (đủ tiêu chí không còn chest/diamond)
  HopAfterCollect = true,

  -- Lọc region (tùy chọn)
  SelectRegion = {
    Enabled = false,
    Regions = { "singapore", "tokyo", "us-east" }, -- text match mềm
  },

  -- API endpoints (thử lần lượt để “sống dai” khi Roblox đổi)
  ServerAPIs = {
    -- có excludeFullGames
    "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100&cursor=%s",
    -- bản phổ thông
    "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
  },
}

-- ================== SERVICES & UTILS ==================
local Http = game:GetService("HttpService")
local TS   = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local STATE = {
  BusyTeleport = false,
  Visited = {},           -- [jobId] = lastTime
  Cursor = "",            -- nextPageCursor saver
  LastHop = 0,
}

local function now() return os.time() end
local function between(a, x, b) return (x.X>=a.X and x.Y>=a.Y and x.Z>=a.Z and x.X<=b.X and x.Y<=b.Y and x.Z<=b.Z) end
local function rnd(a,b) return a + math.random()*(b-a) end

-- chống TeleportFailed prompt
local function suppressTeleportErrors()
  local gui = game.CoreGui:FindFirstChild("RobloxPromptGui", true)
  if not gui then return end
  local overlay = gui:FindFirstChild("promptOverlay")
  if not overlay then return end
  local function hook(v)
    if v.Name == "ErrorPrompt" then
      if v.Visible and v:FindFirstChild("TitleFrame") and v.TitleFrame:FindFirstChild("ErrorTitle") then
        if v.TitleFrame.ErrorTitle.Text == "Teleport Failed" then v.Visible = false end
      end
      v:GetPropertyChangedSignal("Visible"):Connect(function()
        if v.Visible and v:FindFirstChild("TitleFrame") and v.TitleFrame:FindFirstChild("ErrorTitle") then
          if v.TitleFrame.ErrorTitle.Text == "Teleport Failed" then v.Visible = false end
        end
      end)
    end
  end
  for _,v in ipairs(overlay:GetChildren()) do hook(v) end
  overlay.ChildAdded:Connect(hook)
end
pcall(suppressTeleportErrors)

-- hacky notif (không crash khi executors cũ)
local function notify(t)
  pcall(function() game.StarterGui:SetCore("SendNotification", {Title="Mochi Farm", Text=t, Duration=3}) end)
end

-- Vacancies + field fallback
local function getCounts(sv)
  local maxp = tonumber(sv.maxPlayers or sv.maxPlayerCount or 0) or 0
  local playing = tonumber(sv.playing or sv.playerCount or 0) or 0
  return maxp, playing
end

local function isVisited(id)
  if not id or id == game.JobId then return true end
  local t = STATE.Visited[id]
  if t and (now() - t) <= Config.VisitedTTL then return true end
  return false
end

local function markVisited(id) if id then STATE.Visited[id] = now() end end

local function regionPass(sv)
  if not Config.SelectRegion.Enabled then return true end
  local cand = tostring(sv.region or sv.ping or ""):lower()
  for _, r in ipairs(Config.SelectRegion.Regions) do
    if string.find(cand, tostring(r):lower()) then return true end
  end
  return false
end

-- robust fetch (thử nhiều endpoint + cursor)
local function fetchServers(placeId, cursor)
  local lastErr
  for _,fmt in ipairs(Config.ServerAPIs) do
    local url = (fmt):format(placeId, cursor or "")
    local ok, data = pcall(function()
      return Http:JSONDecode(game:HttpGet(url))
    end)
    if ok and data and type(data)=="table" and data.data then
      return data
    end
    lastErr = data
  end
  return nil, lastErr
end

local function chooseServer(placeId)
  -- vòng qua nhiều trang đến khi tìm thấy server hợp lệ
  for _page=1,20 do
    local data = fetchServers(placeId, STATE.Cursor)
    if not data then return nil end

    -- cập nhật cursor
    if data.nextPageCursor and data.nextPageCursor ~= "null" then
      STATE.Cursor = data.nextPageCursor
    else
      STATE.Cursor = "" -- reset về đầu cho vòng sau
    end

    -- gom candidate
    local cand = {}
    for _,sv in ipairs(data.data or {}) do
      local id = tostring(sv.id or "")
      local maxp, playing = getCounts(sv)
      local hasRoom = maxp > 0 and playing < maxp
      if id ~= "" and hasRoom and (not isVisited(id)) and regionPass(sv) then
        table.insert(cand, { id=id, playing=playing, maxp=maxp })
      end
    end

    -- chọn ưu tiên: ít người trước (ổn định nhặt, ít tranh chấp)
    table.sort(cand, function(a,b) return a.playing < b.playing end)

    if #cand > 0 then
      return cand[1]
    end
  end
  return nil
end

local function safeTeleport(placeId, jobId)
  if STATE.BusyTeleport then return end
  STATE.BusyTeleport = true
  notify("Đang hop server...")
  markVisited(jobId) -- đánh dấu ngay để tránh spam
  local ok = pcall(function()
    TS:TeleportToPlaceInstance(placeId, jobId, LP)
  end)
  if not ok then
    STATE.BusyTeleport = false
  end
end

local function hopNow(reason)
  if (now() - STATE.LastHop) < 2 then return end
  STATE.LastHop = now()

  local target = chooseServer(Config.FarmPlaceId)
  if not target then
    notify("Không tìm thấy server phù hợp (sẽ thử lại).")
    return
  end
  -- đánh dấu đã ghé
  markVisited(target.id)
  -- backoff nhẹ tránh race Teleport
  task.wait(rnd(Config.HopBackoffMin, Config.HopBackoffMax))
  safeTeleport(Config.FarmPlaceId, target.id)
end

-- ================== FARM LOGIC (giữ nguyên tinh thần cũ) ==================
-- Tắt hiệu ứng & tối ưu đơn giản (giữ các tuỳ chỉnh của bạn)
local g = game
g.Lighting.GlobalShadows = false
g.Lighting.FogEnd = 1e10
g.Lighting.Brightness = 0
pcall(function() settings().Rendering.QualityLevel = "Level01" end)

local function optimize(v)
  if v:IsA("Model") then
    for _, c in ipairs(v:GetDescendants()) do
      if c:IsA("BasePart") or c:IsA("MeshPart") then
        c.Transparency = 1
      elseif c:IsA("Decal") or c:IsA("Texture") then
        c.Transparency = 1
      end
    end
  elseif v:IsA("BasePart") or v:IsA("MeshPart") then
    v.Transparency = 1
  elseif v:IsA("Decal") or v:IsA("Texture") then
    v.Transparency = 1
  elseif v:IsA("Explosion") then
    v.BlastPressure = 1
    v.BlastRadius = 1
  elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
    v.Enabled = false
  end
end
for _,v in ipairs(g:GetDescendants()) do optimize(v) end
g.DescendantAdded:Connect(optimize)
for _,e in ipairs(g.Lighting:GetDescendants()) do if e:IsA("PostEffect") then e.Enabled=false end end
g.Lighting.DescendantAdded:Connect(function(e) if e:IsA("PostEffect") then e.Enabled=false end end)

-- NoClip (nhẹ nhàng)
getgenv().NoClip = true
game:GetService("RunService").Stepped:Connect(function()
  pcall(function()
    if not getgenv().NoClip then return end
    local char = LP.Character
    if not char then return end
    for _,v in ipairs(char:GetDescendants()) do
      if v:IsA("BasePart") then v.CanCollide=false end
    end
  end)
end)

-- Hiển thị đếm gems (re-use GUI cũ nếu cần)
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
    if pg and pg:FindFirstChild("Interface") and pg.Interface:FindFirstChild("DiamondCount") then
      local count = pg.Interface.DiamondCount:FindFirstChild("Count")
      if count and count:IsA("TextLabel") then tl.Text = count.Text end
    end
  end
end)

-- Helpers
local function tpCFrame(cf)
  local ch = LP.Character
  if ch and ch:FindFirstChild("HumanoidRootPart") then
    ch:SetPrimaryPartCFrame(cf)
  end
end

-- Tự collect diamond trong map farm
local RS = game:GetService("ReplicatedStorage")
local function collectDiamondsOnce()
  for _,d in ipairs(workspace:GetDescendants()) do
    if d:IsA("Model") and d.Name == "Diamond" and game.PlaceId == Config.FarmPlaceId then
      local pv = d:GetPivot()
      tpCFrame(CFrame.new(pv.Position))
      pcall(function()
        local ev = RS:FindFirstChild("RemoteEvents", true)
        if ev and ev:FindFirstChild("RequestTakeDiamonds") then
          ev.RequestTakeDiamonds:FireServer(d)
        end
      end)
      task.wait(0.05)
    end
  end
end

-- Tìm chest gần nhất (bỏ vùng Fog & bỏ chest snow)
local FogCF, FogSize = nil, nil
pcall(function()
  local b = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Boundaries")
  local fog = b and b:FindFirstChild("Fog")
  if fog then
    local cf, size = fog:GetBoundingBox()
    FogCF, FogSize = cf, size
  end
end)

local chestSeen = {}
local function nearChest()
  local ch = LP.Character
  local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
  if not hrp then return nil end
  local closest, dist
  for _, v in ipairs(workspace:GetDescendants()) do
    if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find(Config.ChestNameExclude) then
      local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
      if prox then
        local id = v:GetDebugId()
        if not chestSeen[id] then chestSeen[id] = tick() end
        -- bỏ chest mới spawn quá lâu khỏi sương mù
        local p = v:GetPivot().Position
        if not (FogCF and FogSize and between(FogCF.Position - FogSize/2, p, FogCF.Position + FogSize/2)) then
          local d = (hrp.Position - p).Magnitude
          if not dist or d < dist then closest, dist = v, d end
        end
      end
    end
  end
  return closest
end

-- ====== FARM LOOP ======
task.spawn(function()
  while task.wait(0.15) do
    if game.PlaceId ~= Config.FarmPlaceId then
      -- Không farm ở lobby; không hop bừa: chỉ hop vào MAP FARM
      -- Nếu lobby dead/đông? Bạn có thể thêm logic riêng, nhưng ưu tiên giữ hành vi cũ: đợi join map farm
    else
      -- Đang ở map farm
      collectDiamondsOnce()

      -- pre-scan chest hữu dụng
      local total = 0
      for _,v in ipairs(workspace.Items:GetChildren()) do
        if v:IsA("Model") and v.Name:find("Chest") and not v.Name:find(Config.ChestNameExclude) then
          local prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
          if prox then
            local p = v:GetPivot().Position
            if not (FogCF and FogSize and between(FogCF.Position - FogSize/2, p, FogCF.Position + FogSize/2)) then
              total += 1
            end
          end
        end
      end

      -- nếu không có chest và cũng không có diamond -> hop
      local anyDiamond = workspace:FindFirstChild("Diamond", true) ~= nil
      if total == 0 and not anyDiamond and Config.HopAfterCollect then
        notify("Hết chest/diamond -> Hop server mới.")
        hopNow("no-loot")
        break
      end

      -- farm chest tuần tự
      local chest = nearChest()
      if not chest and Config.HopAfterCollect then
        notify("Không thấy chest hợp lệ -> Hop.")
        hopNow("no-chest")
        break
      end

      if chest then
        local prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
        local st = os.time()
        while prox and prox.Parent and (os.time() - st) < Config.HopCheckDiamondsTimeout do
          local pv = chest:GetPivot()
          tpCFrame(CFrame.new(pv.Position))
          pcall(function() fireproximityprompt(prox) end)
          task.wait(0.35)
          prox = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
      end

      -- sau mỗi vòng, hút diamond còn lại
      collectDiamondsOnce()

      -- Sau khi nhặt xong nhiều vòng, nếu không còn loot -> hop
      local leftDiamond = workspace:FindFirstChild("Diamond", true) ~= nil
      if Config.HopAfterCollect and (not nearChest()) and (not leftDiamond) then
        hopNow("after-collect")
        break
      end
    end
  end
end)

-- ============== ANTI-REJOIN-SAME-SERVER seed ==============
-- đánh dấu server hiện tại để không quay lại trong 3h
markVisited(game.JobId)
notify("API hop đã FIX. Bắt đầu farm.")


