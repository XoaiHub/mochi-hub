-- ====== Anti-kick Tween (speed governor + ground snap) ======
local RunService       = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace        = game:GetService("Workspace")

-- Lấy ping để tự động giảm tốc khi lag
local function getPingMs()
    local stats = game:GetService("Stats")
    local net = stats and stats.Network
    local pingItem = net and net.ServerStatsItem and net.ServerStatsItem["Data Ping"]
    local v = pingItem and pingItem:GetValue() or 80
    return math.clamp(v, 20, 300)
end

-- Raycast thẳng xuống để lấy mặt đất
local function getGroundY(pos)
    local origin = pos + Vector3.new(0, 20, 0)
    local dir    = Vector3.new(0, -200, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LP.Character} -- tránh dính chính mình
    local r = Workspace:Raycast(origin, dir, params)
    if r then
        return r.Position.Y
    end
    return pos.Y
end

-- Đi theo path nếu có vật cản (an toàn nhất)
local function tryPathMove(targetPos, stepTimeout)
    if not Humanoid or Humanoid.Health <= 0 then return false end
    local path = PathfindingService:CreatePath({
        AgentCanJump = true,
        AgentRadius = 2,
        AgentHeight = 5
    })
    path:ComputeAsync(HRP.Position, targetPos)
    if path.Status ~= Enum.PathStatus.Success then
        return false
    end
    local waypoints = path:GetWaypoints()
    for i = 1, #waypoints do
        local wp = waypoints[i]
        local p  = wp.Position
        local gy = getGroundY(p)
        p = Vector3.new(p.X, gy + 2.7, p.Z)

        Humanoid:MoveTo(p)
        local t0 = os.clock()
        while (HRP.Position - p).Magnitude > 2 do
            if os.clock() - t0 > (stepTimeout or 2.5) then return false end
            if Humanoid.Health <= 0 then return false end
            RunService.Heartbeat:Wait()
        end
        if wp.Action == Enum.PathWaypointAction.Jump then
            Humanoid.Jump = true
        end
    end
    return true
end

-- Di chuyển theo các ĐOẠN NGẮN + tween nhẹ, hạn tốc theo ping
local function safeTP(targetPart)
    if not (HRP and targetPart and targetPart.CFrame and Humanoid) then return end
    if Humanoid.Sit then Humanoid.Sit = false end

    local ping   = getPingMs()
    -- Ping càng cao => tốc độ càng thấp
    local maxSpeed = 26 - math.clamp((ping - 60) / 40, 0, 6)   -- 26 -> 20
    local stepMax  = 10                                        -- tối đa 10 studs/đoạn
    local timeoutPerStep = 2.2

    local function moveOneStep(toPos)
        toPos = Vector3.new(toPos.X, getGroundY(toPos) + 2.7, toPos.Z)

        -- Ưu tiên MoveTo (hợp lệ với server), thêm tween nhỏ để mượt
        Humanoid:MoveTo(toPos)
        local d = (HRP.Position - toPos).Magnitude
        local dur = math.max(d / maxSpeed, 0.12)

        local tw = TweenService:Create(HRP, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = CFrame.new(toPos)})
        tw:Play()

        local start = os.clock()
        while (HRP.Position - toPos).Magnitude > 2 do
            if os.clock() - start > timeoutPerStep then
                tw:Cancel()
                return false
            end
            -- nếu bị lôi ra lobby/không còn nhân vật thì dừng
            if not HRP.Parent or Humanoid.Health <= 0 then
                tw:Cancel()
                return false
            end
            RunService.Heartbeat:Wait()
        end
        return true
    end

    local dest = targetPart.Position
    -- Chia tuyến thẳng thành nhiều đoạn ≤ stepMax
    while true do
        local cur = HRP.Position
        local vec = dest - cur
        local dist = vec.Magnitude
        if dist <= 3 then
            -- chấm dứt gần coin
            moveOneStep(dest)
            break
        end

        local dir = vec.Unit
        local nextPos = cur + dir * math.min(stepMax, dist)

        -- thử path khi có khả năng kẹt (cao độ chênh > 6 studs) hoặc đoạn dài
        if math.abs(dest.Y - cur.Y) > 6 or dist > 40 then
            local ok = tryPathMove(dest, timeoutPerStep + 1)
            if ok then break end
        end

        if not moveOneStep(nextPos) then
            -- nếu thất bại, giảm step và thử lại
            stepMax = math.max(6, stepMax - 2)
        end

        -- micro delay + jitter rất nhỏ để hợp thức hoá (tránh pattern cố định)
        task.wait(math.random(30, 60) / 1000)
    end
end


