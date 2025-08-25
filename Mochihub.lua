-- ⚡ Function check slot còn trống
function checkcanplantegg()
    local cntt = 0
    for i, v in getplace().Important.Objects_Physical:GetChildren() do
        if string.find(v.Name, "Egg") then
            cntt = cntt + 1
        end
    end
    return cntt
end

-- ⚡ Function chọn egg trong túi để đặt
function haveegg()
    local v_u_1 = game:GetService("ReplicatedStorage")
    local v_u_3 = require(v_u_1.Modules.DataService)
    local v33 = v_u_3:GetData()

    if checkcanplantegg() < v33.PetsData.PurchasedEggSlots + 3 then
        local function collectEggs(container)
            for _, egg in ipairs(container:GetChildren()) do
                local eggName = egg:GetAttribute(invobf["EggName"])
                if eggName and getgenv().EggConfig[eggName] then
                    return egg -- 🔥 tìm đúng tên egg trong config thì trả về luôn
                end
            end
        end

        return collectEggs(plr.Backpack) or collectEggs(plr.Character)
    end
end
