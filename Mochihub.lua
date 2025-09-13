-- ================================================================
-- MOCHI FARM — HOTFIX FULL (robust prompt/items/remotes)
-- - Hop CHỈ sau khi nhặt xong gems
-- - Prompt/Items/Remote tìm linh hoạt -> hết cảnh "không hoạt động"
-- - Skip full + nâng slot tạm, no-rejoin-same-server, anti-dead, region filter
-- - FPS boost an toàn (không chạm UI/Prompt)
-- ================================================================

local Config = {
  RegionFilterEnabled   = false,
  RegionList            = {"singapore","tokyo","us-east"},

  StrongholdChestName   = "Stronghold Diamond Chest",
  StrongholdPromptTime  = 7,
  StrongholdDiamondWait = 12,
  NormalChestPromptTime = 10,

  FarmPlaceId           = 126509999114328,
  LobbyCheckInterval    = 2.0,
  FarmTick              = 1.0,
  DiamondTick           = 0.35,

  HopBackoffMin         = 1.5,
  HopBackoffMax         = 3.0,
  HopPostDelay          = 0.20,
  NoChestGraceSeconds   = 6.0,

  DeadHopTimeout        = 6.0,
  DeadUiKeywords        = {"dead","you died","respawn","revive"},

  MaxConsecutiveHopFail = 5,
  ConsecutiveHopCooloff = 6.0,
  MaxPagesPrimary       = 8,
  MaxPagesFallback      = 12,
  TeleportFailBackoffMax= 8,

  MinFreeSlotsDefault   = 1,
  MinFreeSlotsCeil      = 3,

  ClassicMode           = "Low",
  DEBUG                 = false,  -- bật log chi tiết
}

-- ===== Services
local g,Players,RS,RunService,HttpService,TeleportService =
  game, game:GetService("Players"), game:GetService("ReplicatedStorage"),
  game:GetService("RunService"), game:GetService("HttpService"), game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local function log(...) if Config.DEBUG then print("[HOTFIX]", ...) end end

-- ===== FPS BOOST (SAFE: chỉ workspace + Lighting, không đụng UI/Prompt)
do
  local function optimize(v)
    if v:IsA("BillboardGui") or v:IsA("SurfaceGui") or v:IsA("ProximityPrompt")
      or v:IsA("Attachment") or v:IsA("ProximityPromptService") then return end
    if v:IsA("BasePart") or v:IsA("MeshPart") then
      v.Material = Enum.Material.Plastic; v.Reflectance=0; v.CastShadow=false; v.Transparency=1
      if v:IsA("MeshPart") then v.TextureID="" end
    elseif v:IsA("Decal") or v:IsA("Texture") then
      v.Transparency = 1
    elseif v:IsA("Explosion") then
      v.BlastPressure=1; v.BlastRadius=1
    elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
      v.Enabled=false
    elseif v:IsA("SpecialMesh") or v:IsA("SurfaceAppearance") or v:IsA("PostEffect") then
      if v:IsDescendantOf(workspace) or v:IsDescendantOf(g.Lighting) then pcall(function() v:Destroy() end) end
    end
  end
  g.Lighting.GlobalShadows=false; g.Lighting.Brightness=0; g.Lighting.FogEnd=1e10
  pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
  local function apply(root)
    for _,v in ipairs(root:GetDescendants()) do optimize(v) task.wait(0.0005) end
    root.DescendantAdded:Connect(optimize)
  end
  apply(workspace); apply(g.Lighting)
end

-- ===== Small utils
local function WaitForChar(timeout)
  timeout=timeout or 15; local t=0
  while t<timeout do local c=LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChild("Humanoid") then return c end
    t+=0.25; task.wait(0.25)
  end
  return LocalPlayer.Character
end
local function HRP() local c=LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function tpCFrame(cf) local r=HRP(); if r then r.CFrame=cf end end
local function rand(a,b) return a + (b-a)*math.random() end

-- ===== HTTP (safe)
local function http_get(url)
  local ok1,res1=pcall(function() return g:HttpGet(url) end)
  if ok1 and type(res1)=="string" and #res1>0 then return res1 end
  local req = (syn and syn.request) or (http and http.request) or request
  if req then
    local ok2,res2=pcall(function() return req({Url=url,Method="GET"}) end)
    if ok2 and res2 and (res2.Success==nil or res2.Success==true) and type(res2.Body)=="string" then return res2.Body end
  end
  return nil
end

-- ===== Visited (no rejoin same JobId)
do getgenv().VisitedServers = getgenv().VisitedServers or {hour=-1, ids={}} end
local function nowHourUTC() return os.date("!*t").hour end
local function rotateVisitedIfHourChanged()
  local h=nowHourUTC(); if getgenv().VisitedServers.hour~=h then getgenv().VisitedServers.hour=h; getgenv().VisitedServers.ids={} end
end
local function wasVisited(s) rotateVisitedIfHourChanged(); return getgenv().VisitedServers.ids[s]==true end
local function markVisited(s) rotateVisitedIfHourChanged(); getgenv().VisitedServers.ids[s]=true end
task.delay(2,function() pcall(function() if game.JobId~="" then markVisited(game.JobId) end end) end)

-- ===== Region filter
local function regionMatch(entry)
  if not Config.RegionFilterEnabled then return true end
  local raw=tostring(entry.region or entry.ping or ""):lower()
  for _,k in ipairs(Config.RegionList) do if raw:find(tostring(k):lower(),1,true) then return true end end
  return false
end

-- ===== Teleport wrapper
local function tp_to_instance(placeId, serverId)
  local ok=pcall(function() local opt=Instance.new("TeleportOptions"); opt.ServerInstanceId=serverId
    TeleportService:TeleportAsync(placeId,{LocalPlayer},opt) end)
  if ok then return true end
  local ok2=pcall(function() TeleportService:TeleportToPlaceInstance(placeId,serverId,LocalPlayer) end)
  return ok2
end

-- ===== Skip full (+ raise min free slots temporarily)
local DynamicMinFreeSlots, MinFreeSlotsDecayAt = Config.MinFreeSlotsDefault, 0
local function effectiveFree()
  if MinFreeSlotsDecayAt>0 and os.clock()>MinFreeSlotsDecayAt then
    DynamicMinFreeSlots=Config.MinFreeSlotsDefault; MinFreeSlotsDecayAt=0
  end
  return math.clamp(DynamicMinFreeSlots, Config.MinFreeSlotsDefault, Config.MinFreeSlotsCeil)
end
TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
  local s=tostring(result)..":"..tostring(msg or "")
  if s:lower():find("gamefull") or s:lower():find("requested experience is full") then
    DynamicMinFreeSlots=math.min((DynamicMinFreeSlots or 1)+1, Config.MinFreeSlotsCeil)
    MinFreeSlotsDecayAt=os.clock()+60
  end
end)

-- ===== Robust Items root & iterators
local ItemsRootCache=nil
local function findItemsRoot()
  if ItemsRootCache and ItemsRootCache.Parent then return ItemsRootCache end
  local root=workspace:FindFirstChild("Items")
  if not root then
    -- quét fallback: folder chứa nhiều Model tên *Chest* hoặc *Diamond*
    local best=nil; local bestScore=0
    for _,d in ipairs(workspace:GetDescendants()) do
      if d:IsA("Folder") then
        local cChest = #d:GetDescendants()
        local score=0
        for _,x in ipairs(d:GetChildren()) do
          if x:IsA("Model") and (x.Name:lower():find("chest") or x.Name=="Diamond") then score+=1 end
        end
        if score>bestScore then bestScore=score; best=d end
      end
    end
    root=best
  end
  ItemsRootCache=root
  if Config.DEBUG then log("ItemsRoot:", root and root:GetFullName() or "nil") end
  return root
end

local function forEachDiamond(fn)
  local root=findItemsRoot(); if not root then return 0 end
  local n=0
  for _,v in ipairs(root:GetChildren()) do
    if v.Name=="Diamond" then n+=1; fn(v) end
  end
  return n
end

local function findStrongholdChest()
  local root=findItemsRoot(); if not root then return nil end
  local exact=root:FindFirstChild(Config.StrongholdChestName)
  if exact then return exact end
  -- fallback: bất cứ model nào có "stronghold" và "chest"
  for _,v in ipairs(root:GetChildren()) do
    if v:IsA("Model") then
      local name=v.Name:lower()
      if name:find("stronghold") and name:find("chest") then return v end
    end
  end
  return nil
end

local function findUsableChest()
  local r=HRP(); if not r then return nil end
  local root=findItemsRoot(); if not root then return nil end
  local best,dist
  for _,v in ipairs(root:GetChildren()) do
    if v:IsA("Model") and v.Name:lower():find("chest") and not v.Name:lower():find("snow") then
      local prox
      -- cố tìm prompt dưới mọi nhánh
      prox = v:FindFirstChildWhichIsA("ProximityPrompt", true)
      if not prox then
        local main=v:FindFirstChild("Main")
        local att=main and main:FindFirstChild("ProximityAttachment")
        prox=att and att:FindFirstChild("ProximityInteraction")
      end
      if prox and prox.Enabled then
        local p=v:GetPivot().Position; local d=(r.Position-p).Magnitude
        if not dist or d<dist then best,dist=v,d end
      end
    end
  end
  return best
end

-- ===== Robust Prompt helpers
local function getPromptFromChest(chest)
  if not (chest and chest.Parent) then return nil end
  local p = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
  if p then return p end
  local main = chest:FindFirstChild("Main"); local att = main and main:FindFirstChild("ProximityAttachment")
  local pi = att and att:FindFirstChild("ProximityInteraction")
  if pi and pi:IsA("ProximityPrompt") then return pi end
  return nil
end

local function firePromptSafe(prompt)
  if not (prompt and prompt.Parent and prompt.Enabled and prompt:IsDescendantOf(workspace)) then return false end
  if typeof(fireproximityprompt)=="function" then
    local ok=pcall(function() fireproximityprompt(prompt,1) end)
    return ok
  end
  return false
end

local function pressPromptWithTimeout(chest, timeout)
  local t0=tick()
  while (tick()-t0)<(timeout or 6) do
    local prox=getPromptFromChest(chest)
    if not (prox and prox.Enabled) then return true end -- đã mở
    if not firePromptSafe(prox) then break end
    task.wait(0.3)
  end
  local prox2=getPromptFromChest(chest)
  return not (prox2 and prox2.Enabled)
end

-- ===== Diamond helpers (robust RemoteEvent)
local DiamondRemoteCache=nil
local function findDiamondRemote()
  if DiamondRemoteCache and DiamondRemoteCache.Parent then return DiamondRemoteCache end
  local cand={}
  local function push(re) table.insert(cand, re) end
  local function scan(root)
    for _,v in ipairs(root:GetDescendants()) do
      if v:IsA("RemoteEvent") then
        local n=v.Name:lower()
        if n:find("diamond") or n:find("gem") or n:find("take") then push(v) end
        if v.Name=="RequestTakeDiamonds" then table.insert(cand,1,v) end
      end
    end
  end
  if RS then scan(RS) end
  scan(game)
  DiamondRemoteCache=cand[1]
  if Config.DEBUG then log("DiamondRemote:", DiamondRemoteCache and DiamondRemoteCache:GetFullName() or "nil") end
  return DiamondRemoteCache
end

local function diamondsLeft()
  local any=false
  forEachDiamond(function() any=true end)
  return any
end

local function countDiamonds()
  local n=0
  forEachDiamond(function() n+=1 end)
  return n
end

local function collectAllDiamonds()
  local re=findDiamondRemote(); if not re then return 0 end
  local got=0
  forEachDiamond(function(v)
    local ok = pcall(function() re:FireServer(v) end)               -- kiểu 1: (instance)
    if not ok then ok=pcall(function() re:FireServer(LocalPlayer,v) end) end -- kiểu 2: (player,instance)
    if ok then got+=1 end
  end)
  return got
end

local function waitNoDiamonds(timeout)
  local t0=tick()
  while tick()-t0<(timeout or 1.2) do if not diamondsLeft() then return true end task.wait(0.1) end
  return not diamondsLeft()
end

-- ===== Collecting gate (cấm hop khi đang nhặt)
local State = { Collecting=false, PendingHop=nil, LastNoChestAt=0 }
local function BeginCollect() State.Collecting=true end
local function EndCollect()
  State.Collecting=false
  if State.PendingHop then local m=State.PendingHop; State.PendingHop=nil; task.defer(function() task.wait(Config.HopPostDelay) _G.__HOP_IMPL(m) end) end
end

-- ===== Hop engine (classic + hardened)
local PlaceID=game.PlaceId
local ConsecutiveHopFail,LastHopFailAt=0,0
local BadIDs,LastAttemptSID,isTeleporting,HopRequested={},{},false,false

local function fetchServerList(cursor, sort)
  local sortOrder=sort or "Asc"
  local base=("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100"):format(PlaceID, sortOrder)
  local url=(cursor and cursor~="" and (base.."&cursor="..cursor) or base).."&_t="..HttpService:GenerateGUID(false)
  local body=http_get(url); if not body then return nil end
  local ok,data=pcall(function() return HttpService:JSONDecode(body) end)
  if ok and data and data.data then return data end
  return nil
end

local function chooseAndTeleportFromPage(siteData, mode)
  if not siteData or not siteData.data then return false end
  local needFree=effectiveFree()
  local list={}
  for _,v in ipairs(siteData.data) do
    local id=tostring(v.id)
    local maxp=tonumber(v.maxPlayers or v.maxPlayerCount or 0) or 0
    local playing=tonumber(v.playing or v.playerCount or 0) or 0
    local free=maxp-playing
    if maxp>0 and free>=needFree and id~=game.JobId and not wasVisited(id) and not BadIDs[id] and regionMatch(v) then
      table.insert(list,{id=id,players=playing,free=free})
    end
  end
  if mode=="Low" then
    table.sort(list,function(a,b) if a.free~=b.free then return a.free>b.free end return a.players<b.players end)
  else
    table.sort(list,function(a,b) if a.players~=b.players then return a.players>b.players end return a.free>b.free end)
    local filt={} for _,s in ipairs(list) do if s.players>=5 then table.insert(filt,s) end end
    if #filt>0 then list=filt end
  end
  if #list==0 then return false end
  if #list>=3 then local i=math.random(1,math.min(3,#list)); list[1],list[i]=list[i],list[1] end
  local chosen=list[1]; if not chosen then return false end
  isTeleporting=true; LastAttemptSID=chosen.id
  task.wait(rand(Config.HopBackoffMin, Config.HopBackoffMax))
  local ok=tp_to_instance(PlaceID, chosen.id)
  if not ok then isTeleporting=false; BadIDs[chosen.id]=true; ConsecutiveHopFail+=1; LastHopFailAt=os.clock(); return false end
  ConsecutiveHopFail=0; return true
end

_G.__HOP_IMPL=function(mode)
  if isTeleporting then return end
  mode=(mode=="High") and "High" or "Low"
  if ConsecutiveHopFail>=Config.MaxConsecutiveHopFail then
    local since=os.clock()-LastHopFailAt
    if since<Config.ConsecutiveHopCooloff then task.wait(Config.ConsecutiveHopCooloff-since) end
    ConsecutiveHopFail=0
  end
  local cursor,sort="","Asc"
  for _=1,Config.MaxPagesPrimary do local site=fetchServerList(cursor,sort); if not site then break end
    if chooseAndTeleportFromPage(site,mode) then return end
    cursor=site.nextPageCursor or ""; if cursor=="" then break end
  end
  cursor,sort="",(mode=="Low" and "Desc" or "Asc")
  for _=1,Config.MaxPagesFallback do local site=fetchServerList(cursor,sort); if not site then break end
    if chooseAndTeleportFromPage(site,mode) then return end
    cursor=site.nextPageCursor or ""; if cursor=="" then break end
  end
  task.wait(1+math.random())
end

local function requestHop(mode_or_reason)
  local mode=(mode_or_reason=="High") and "High" or "Low"
  if State.Collecting then State.PendingHop=mode; return end
  _G.__HOP_IMPL(mode)
end
local function Hop(m) requestHop(m or Config.ClassicMode) end
local function HopFast()
  if isTeleporting or HopRequested then return end
  HopRequested=true; task.spawn(function() task.wait(Config.HopPostDelay) requestHop(Config.ClassicMode) HopRequested=false end)
end

LocalPlayer.OnTeleport:Connect(function(state) if state==Enum.TeleportState.Started then if LastAttemptSID then markVisited(LastAttemptSID) end isTeleporting=false end end)
TeleportService.TeleportInitFailed:Connect(function(_,result,msg)
  if LastAttemptSID then BadIDs[LastAttemptSID]=true end
  isTeleporting=false; ConsecutiveHopFail+=1; LastHopFailAt=os.clock()
  requestHop(Config.ClassicMode)
end)

-- ===== NOCLIP
getgenv().NoClip=true
RunService.Stepped:Connect(function()
  local c=LocalPlayer.Character; if not c then return end
  local on=getgenv().NoClip
  for _,v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=not on end end
end)

-- ===== ANTI-DEAD
local IsDead,DeadSince=false,0
local function hasDeadUi()
  local pg=LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return false end
  local lower=string.lower
  for _,gui in ipairs(pg:GetDescendants()) do
    if gui:IsA("TextLabel") or gui:IsA("TextButton") then
      local t=tostring(gui.Text or ""):gsub("%s+"," ")
      for _,k in ipairs(Config.DeadUiKeywords) do if lower(t):find(lower(k),1,true) then return true end end
    end
  end
  return false
end
local function bindDeathWatcher(c) local h=c:FindFirstChild("Humanoid"); if not h then return end; h.Died:Connect(function() IsDead=true; DeadSince=tick() end) end
if LocalPlayer.Character then bindDeathWatcher(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(c) IsDead=false; DeadSince=0; task.wait(0.5); bindDeathWatcher(c) end)
task.spawn(function()
  while task.wait(0.5) do
    if game.PlaceId~=Config.FarmPlaceId then continue end
    if not IsDead and not hasDeadUi() then continue end
    if DeadSince==0 then DeadSince=tick() end
    if tick()-DeadSince>=Config.DeadHopTimeout then requestHop(Config.ClassicMode) end
  end
end)

-- ===== MAIN FARM
local strongholdTried, chestTried = {}, {}
local StrongholdCount, NormalChestCount = 0, 0

local function waitDiamondsSpawn(timeout)
  local t0=tick()
  while (tick()-t0)<(timeout or 2.0) do if diamondsLeft() then return true end task.wait(0.2) end
  return false
end

task.spawn(function()
  while task.wait(Config.FarmTick) do
    if game.PlaceId~=Config.FarmPlaceId then continue end
    WaitForChar()

    -- Stronghold (rương 5 gems)
    local sh=findStrongholdChest()
    if sh then
      local sid=sh:GetDebugId()
      if not strongholdTried[sid] then
        local prox=getPromptFromChest(sh)
        if not (prox and prox.Enabled) then
          strongholdTried[sid]=true; log("[Stronghold] locked/no prompt -> hop")
          requestHop("Low")
        else
          tpCFrame(CFrame.new(sh:GetPivot().Position+Vector3.new(0,3,0)))
          local opened=pressPromptWithTimeout(sh,Config.StrongholdPromptTime)
          if opened then
            if not waitDiamondsSpawn(Config.StrongholdDiamondWait) then
              strongholdTried[sid]=true; log("[Stronghold] opened but no diamonds -> hop")
              requestHop("Low")
            else
              BeginCollect()
              local before=countDiamonds()
              local got=collectAllDiamonds()
              waitNoDiamonds(1.2)
              local after=countDiamonds()
              EndCollect()
              if got>0 or after<before or after==0 then StrongholdCount+=1; requestHop("Low")
              else strongholdTried[sid]=true; log("[Stronghold] diamonds not collectible -> hop"); requestHop("Low") end
            end
          else
            strongholdTried[sid]=true; log("[Stronghold] prompt timeout -> hop"); requestHop("Low")
          end
        end
      end
    end

    -- Chest thường
    local chest=findUsableChest()
    if not chest then
      if State.LastNoChestAt==0 then State.LastNoChestAt=os.clock() end
      if (os.clock()-State.LastNoChestAt)>=Config.NoChestGraceSeconds then
        if not State.Collecting then requestHop("Low") end
        State.LastNoChestAt=0
      end
    else
      State.LastNoChestAt=0
      local id=chest:GetDebugId()
      local prox=getPromptFromChest(chest)
      if not (prox and prox.Enabled) then
        chestTried[id]=true; log("[Chest] locked/no prompt -> hop"); requestHop("Low")
      else
        local opened=pressPromptWithTimeout(chest,Config.NormalChestPromptTime)
        if opened then
          BeginCollect()
          local before=countDiamonds()
          local got=collectAllDiamonds()
          waitNoDiamonds(1.0)
          local after=countDiamonds()
          EndCollect()
          if got>0 or after<before or after==0 then NormalChestCount+=1; requestHop("Low")
          else chestTried[id]=true; log("[Chest] no diamonds -> hop"); requestHop("Low") end
        else
          chestTried[id]=true; log("[Chest] prompt timeout -> hop"); requestHop("Low")
        end
      end
    end
  end
end)

-- Diamond worker nền (không tự hop)
task.spawn(function()
  while task.wait(Config.DiamondTick) do
    if game.PlaceId==Config.FarmPlaceId then pcall(collectAllDiamonds) end
  end
end)

-- (Tùy chọn) overlay đếm gems
task.spawn(function()
  local a=Instance.new("ScreenGui",game:GetService("CoreGui")); a.Name="gg"
  local b=Instance.new("Frame",a); b.Size=UDim2.new(1,0,1,0); b.BackgroundTransparency=1
  local stroke=Instance.new("UIStroke",b); stroke.Thickness=2
  task.spawn(function() while task.wait() do for i=0,1,0.01 do stroke.Color=Color3.fromHSV(i,1,1) task.wait(0.03) end end end)
  local e=Instance.new("TextLabel",b); e.Size=UDim2.new(1,0,1,0); e.BackgroundTransparency=1
  e.Text="0"; e.TextColor3=Color3.new(1,1,1); e.Font=Enum.Font.GothamBold; e.TextScaled=true; e.TextStrokeTransparency=0.6
  while task.wait(0.2) do
    local pg=LocalPlayer:FindFirstChild("PlayerGui")
    local lab = pg and pg:FindFirstChild("Interface") and pg.Interface:FindFirstChild("DiamondCount")
                and pg.Interface.DiamondCount:FindFirstChild("Count")
    if lab and lab:IsA("TextLabel") then e.Text=lab.Text end
  end
end)


