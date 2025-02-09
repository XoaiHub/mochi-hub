-- Dịch vụ ReplicatedStorage
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local endpoints = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server")

-- Giới hạn số lượng unit tối đa được đặt
local unitLimit = 12  -- ⚠️ Chỉnh giới hạn theo game

-- Danh sách unit, vị trí và giá tiền (⚠️ Chỉnh sửa theo game)
local unitsToPlace = {
    {id = "{c88b58c5-d278-491a-940e-630c6bcbc913}", cost = 1300, position = CFrame.new(-2845.318359375, 94.41859436035156, -730.7412109375, 0, 0, 1, 0, 1, -0, -1, 0, -0)},
    {id = "{c88b58c5-d278-491a-940e-630c6bcbc913}", cost = 1300, position = CFrame.new(-2846.082275390625, 94.41859436035156, -733.5582885742188, 0, 0, 1, 0, 1, -0, -1, 0, -0)},
    {id = "{c88b58c5-d278-491a-940e-630c6bcbc913}", cost = 1300, position = CFrame.new(-2846.72119140625, 94.41859436035156, -735.7947998046875, 0, 0, 1, 0, 1, -0, -1, 0, -0)},
    {id = "{2e68f2b7-f9b2-4ba4-a24e-2763f8b23ae7}", cost = 1300, position = CFrame.new(-2846.55029296875, 94.41859436035156, -737.9866943359375, 0, 0, 1, 0, 1, -0, -1, 0, -0)},
    {id = "{2e68f2b7-f9b2-4ba4-a24e-2763f8b23ae7}", cost = 1300, position = CFrame.new(-2878.486328125, 94.39076232910156, -737.4174194335938, 0, 0, 1, 0, 1, -0, -1, 0, -0)},
    {id = "{2e68f2b7-f9b2-4ba4-a24e-2763f8b23ae7}", cost = 1300, position = CFrame.new(-2880.523681640625, 94.39076232910156, -736.2767944335938, 0, 0, 1, 0, 1, -0, -1, 0, -0)},
    {id = "{2e68f2b7-f9b2-4ba4-a24e-2763f8b23ae7}", cost = 1300, position = CFrame.new(-2882.70556640625, 94.39076232910156, -735.5355224609375, 0, 0, 1, 0, 1, -0, -1, 0, -0)},
    {id = "{2e68f2b7-f9b2-4ba4-a24e-2763f8b23ae7}", cost = 1300, position = CFrame.new(-2877.359375, 94.39076232910156, -739.0300903320312, 0, 0, 1, 0, 1, -0, -1, 0, -0)}
}

-- Function: Lấy số tiền hiện tại của người chơi
function getPlayerMoney()
    local player = game.Players.LocalPlayer
    local stats = player:FindFirstChild("leaderstats")  -- Có thể là "Cash" hoặc "Money"
    if stats and stats:FindFirstChild("Money") then
        return stats.Money.Value
    end
    return 0
end

-- Function: Vote Skip Wave
function voteSkipWave(times)
    for i = 1, times do
        local success, err = pcall(function()
            endpoints:WaitForChild("vote_wave_skip"):InvokeServer()
        end)
        if not success then
            warn("Error skipping wave: ", err)
        end
    end
end

-- Function: Đếm số unit đang tồn tại
function countUnits()
    local unitFolder = workspace:FindFirstChild("_UNITS")
    if unitFolder then
        return #unitFolder:GetChildren() -- Đếm số lượng unit trong thư mục
    end
    return 0
end

-- Function: Spawn Unit (Chỉ khi có đủ tiền và chưa đạt giới hạn)
function spawnUnit(unitID, position, cost)
    if countUnits() < unitLimit and getPlayerMoney() >= cost then
        local args = {
            [1] = unitID,
            [2] = position
        }
        local success, err = pcall(function()
            endpoints:WaitForChild("spawn_unit"):InvokeServer(unpack(args))
        end)
        if success then
            print("✅ Đã đặt unit:", unitID)
        else
            warn("Error spawning unit: ", err)
        end
    else
        warn("⚠️ Không thể đặt unit! Có thể do chưa đủ tiền hoặc đã đạt giới hạn.")
    end
end

-- Function: Auto đặt unit khi có đủ tiền
function autoSpawnUnits()
    while true do
        wait(5) -- Đợi 5 giây để tránh spam
        for _, unit in ipairs(unitsToPlace) do
            if countUnits() < unitLimit and getPlayerMoney() >= unit.cost then
                spawnUnit(unit.id, unit.position, unit.cost)
            end
        end
    end
end

-- Function: Upgrade Unit
function upgradeUnit(unitName, times)
    local unit = workspace:WaitForChild("_UNITS"):FindFirstChild(unitName)
    if unit then
        for i = 1, times do
            local args = { [1] = unit }
            local success, err = pcall(function()
                endpoints:WaitForChild("upgrade_unit_ingame"):InvokeServer(unpack(args))
            end)
            if not success then
                warn("Error upgrading unit: ", err)
            end
        end
    else
        warn("Unit not found: ", unitName)
    end
end

-- Function: Auto Switch Map when Finished
function autoSwitchMap()
    local mapSwitching = false -- Biến để tránh gọi chuyển map liên tục
    while true do
        wait(5) -- Đợi 5 giây để tránh spam
        if not mapSwitching then
            local args = {
                [1] = "next_story"
            }
            local success, err = pcall(function()
                endpoints:WaitForChild("set_game_finished_vote"):InvokeServer(unpack(args))
            end)
            if success then
                mapSwitching = true
                print("✅ Chuyển map thành công!")
            else
                warn("Error switching map: ", err)
            end
        end
    end
end

-- Function: Start Vote
function startVote()
    local success, err = pcall(function()
        endpoints:WaitForChild("vote_start"):InvokeServer()
    end)
    if not success then
        warn("Error starting vote: ", err)
    else
        print("✅ Đã bắt đầu vote!")
    end
end

-- Vote skip wave multiple times
voteSkipWave(8)

-- Final vote skip wave
voteSkipWave(3)

-- Bắt đầu vote khi game sẵn sàng
startVote()

-- Chạy tự động đặt unit khi có tiền
spawn(function()
    autoSpawnUnits()
end)

-- Start auto-switching map process in a separate thread
spawn(function()
    autoSwitchMap()
end)
