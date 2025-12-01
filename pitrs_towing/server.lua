lib.callback.register('pitrs_towing:hasRope', function(source)
    local rope = exports.ox_inventory:GetItem(source, Config.RopeItem, nil, true)
    local steelRope = exports.ox_inventory:GetItem(source, Config.SteelRopeItem, nil, true)
    
    if rope and rope > 0 then
        return Config.RopeItem
    elseif steelRope and steelRope > 0 then
        return Config.SteelRopeItem
    end
    
    return false
end)

RegisterNetEvent('pitrs_towing:removeRope', function(ropeType)
    local src = source
    exports.ox_inventory:RemoveItem(src, ropeType, 1)
end)

RegisterNetEvent('pitrs_towing:addRope', function(ropeType)
    local src = source
    exports.ox_inventory:AddItem(src, ropeType, 1)
end)


