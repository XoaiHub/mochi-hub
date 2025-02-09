-- Function to join a specific lobby
function joinLobby(lobbyName)
    local args = {
        [1] = lobbyName
    }
    local success, err = pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("endpoints"):WaitForChild("client_to_server"):WaitForChild("request_join_lobby"):InvokeServer(unpack(args))
    end)
    if not success then
        warn("Error joining lobby: ", err)
    end
end

-- Function to lock a level in the lobby
function lockLevel(lobbyName, levelName, isLocked, difficulty)
    local args = {
        [1] = lobbyName,
        [2] = levelName,
        [3] = isLocked,
        [4] = difficulty
    }
    local success, err = pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("endpoints"):WaitForChild("client_to_server"):WaitForChild("request_lock_level"):InvokeServer(unpack(args))
    end)
    if not success then
        warn("Error locking level: ", err)
    end
end

-- Tham gia lobby "_lobbytemplategreen4"
joinLobby("_lobbytemplategreen4")

-- Khóa level "namek_level_1" trong lobby với độ khó "Normal"
lockLevel("_lobbytemplategreen4", "namek_level_1", true, "Normal")
