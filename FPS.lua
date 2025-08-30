--== FPS BOOST ONLY ==--
-- Bật/tắt nhanh bằng getgenv().FPSBoost = true/false trước khi chạy
if getgenv().__FPS_CLEANER_RUNNING then return end
getgenv().__FPS_CLEANER_RUNNING = true
if getgenv().FPSBoost == nil then getgenv().FPSBoost = true end
if not getgenv().FPSBoost then return end

repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer
local g = game

-- Áp cấu hình ánh sáng/render cơ bản
pcall(function()
    g.Lighting.GlobalShadows = false
    g.Lighting.FogEnd = 1e10
    g.Lighting.Brightness = 0
    settings().Rendering.QualityLevel = "Level01"
end)

local function optimize(v)
    if not getgenv().FPSBoost then return end
    local ok, _ = pcall(function()
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
            v.BlastPressure = 1
            v.BlastRadius = 1
        elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("SpecialMesh") or v:IsA("SurfaceAppearance") then
            v:Destroy()
        end
    end)
end

-- Chạy 1 lượt cho toàn map
for _, v in ipairs(g:GetDescendants()) do
    optimize(v)
end

-- Theo dõi đối tượng mới sinh
if not getgenv().__FPS_Conn1 then
    getgenv().__FPS_Conn1 = g.DescendantAdded:Connect(optimize)
end

-- Tắt toàn bộ PostEffect trong Lighting
for _, e in ipairs(g.Lighting:GetDescendants()) do
    if e:IsA("PostEffect") then e.Enabled = false end
end
if not getgenv().__FPS_Conn2 then
    getgenv().__FPS_Conn2 = g.Lighting.DescendantAdded:Connect(function(e)
        if e:IsA("PostEffect") then e.Enabled = false end
    end)
end

-- Hàm stop nếu muốn tắt giữa chừng (gọi: getgenv().StopFPSBoost())
getgenv().StopFPSBoost = function()
    getgenv().FPSBoost = false
    if getgenv().__FPS_Conn1 then getgenv().__FPS_Conn1:Disconnect() getgenv().__FPS_Conn1 = nil end
    if getgenv().__FPS_Conn2 then getgenv().__FPS_Conn2:Disconnect() getgenv().__FPS_Conn2 = nil end
end