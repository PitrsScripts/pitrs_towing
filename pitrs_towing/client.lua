local towingData = {
    vehicle = nil,
    targetVehicle = nil,
    rope = nil,
    firstIsRear = false,
    ropeProp = nil,
    handRope = nil,
    ropeType = nil
}

local frontTargetShown = false

local winchData = {
    vehicle = nil,
    anchorObject = nil,
    rope = nil,
    isWinching = false
}

local function HasRopeItem()
    local result = lib.callback.await('pitrs_towing:hasRope', false)
    if result then
        towingData.ropeType = result
        return true
    end
    return false
end

local function GetVehicleBonePosition(vehicle, boneName)
    local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
    if boneIndex ~= -1 then
        return GetWorldPositionOfEntityBone(vehicle, boneIndex)
    end
    return GetEntityCoords(vehicle)
end

local function IsSameVehicleType(veh1, veh2)
    local class1 = GetVehicleClass(veh1)
    local class2 = GetVehicleClass(veh2)
    local isBike1 = class1 == 8 or class1 == 13
    local isBike2 = class2 == 8 or class2 == 13
    return isBike1 == isBike2
end

local function AttachRope(veh1, veh2)
    local rearPos = GetVehicleBonePosition(veh1, 'boot')
    local frontPos = GetVehicleBonePosition(veh2, 'bumper_f')
    
    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do Wait(0) end
    
    local rope = AddRope(rearPos.x, rearPos.y, rearPos.z, 0.0, 0.0, 0.0, Config.RopeLength, 1, Config.RopeLength, 1.0, 0.5, false, false, false, 1.0, false)
    
    AttachEntitiesToRope(rope, veh1, veh2, rearPos.x, rearPos.y, rearPos.z, frontPos.x, frontPos.y, frontPos.z, Config.RopeLength, false, false, nil, nil)
    
    return rope
end

local function StartTowing(vehicle, targetVehicle)
    if towingData.ropeProp then
        DeleteEntity(towingData.ropeProp)
        towingData.ropeProp = nil
    end
    
    if towingData.handRope then
        DeleteRope(towingData.handRope)
        towingData.handRope = nil
    end
    
    TriggerServerEvent('pitrs_towing:removeRope', towingData.ropeType)
    
    towingData.vehicle = vehicle
    towingData.targetVehicle = targetVehicle
    towingData.rope = AttachRope(vehicle, targetVehicle)
    
    AttachVehicleToTowTruck(targetVehicle, vehicle, false, 0.0, -2.0, 0.0)
    DetachVehicleFromTowTruck(targetVehicle, vehicle)
    
    lib.notify({title = Config.Locale['title'], description = Config.Locale['notify_connected'], type = 'success'})
end

local function StopTowing()
    if towingData.rope then
        DeleteRope(towingData.rope)
        RopeUnloadTextures()
    end
    
    if towingData.ropeProp then
        DeleteEntity(towingData.ropeProp)
        towingData.ropeProp = nil
    end
    
    if towingData.handRope then
        DeleteRope(towingData.handRope)
        towingData.handRope = nil
    end
    
    towingData.vehicle = nil
    towingData.targetVehicle = nil
    towingData.rope = nil
    towingData.firstIsRear = false
    
    lib.notify({title = Config.Locale['title'], description = Config.Locale['notify_disconnected'], type = 'success'})
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'attach_rope_rear',
        icon = 'fa-solid fa-link',
        label = Config.Locale['attach_rear'],
        bones = {'wheel_lr', 'wheel_rr'},
        distance = 4.5,
        canInteract = function(entity)
            if not HasRopeItem() then return false end
            if towingData.vehicle or towingData.targetVehicle then return false end
            local playerPed = PlayerPedId()
            local playerVeh = GetVehiclePedIsIn(playerPed, false)
            return playerVeh == 0 and DoesEntityExist(entity) and IsEntityAVehicle(entity)
        end,
        onSelect = function(data)
            local ped = PlayerPedId()
            lib.requestModel(Config.RopeProp)
            towingData.ropeProp = CreateObject(GetHashKey(Config.RopeProp), 0, 0, 0, true, true, true)
            AttachEntityToEntity(towingData.ropeProp, ped, 61, 0.21236287593877, -0.015105864412862, -0.093269506059142, 28.454237413852, 46.483631952722, -142.1679835736, true, true, false, true, 1, true)
            
            RopeLoadTextures()
            while not RopeAreTexturesLoaded() do Wait(0) end
            local propPos = GetEntityCoords(towingData.ropeProp)
            local vehPos = GetVehicleBonePosition(data.entity, 'boot')
            towingData.handRope = AddRope(propPos.x, propPos.y, propPos.z, 0.0, 0.0, 0.0, Config.RopeLength, 1, Config.RopeLength, 1.0, 0.5, false, false, false, 1.0, false)
            ActivatePhysics(towingData.handRope)
            AttachEntitiesToRope(towingData.handRope, towingData.ropeProp, data.entity, propPos.x, propPos.y, propPos.z, vehPos.x, vehPos.y, vehPos.z, Config.RopeLength, false, false, nil, nil)
            
            towingData.vehicle = data.entity
            towingData.firstIsRear = true
            lib.notify({title = Config.Locale['title'], description = Config.Locale['notify_aim_front'], type = 'inform'})
        end
    },
    {
        name = 'attach_rope_front',
        icon = 'fa-solid fa-link',
        label = Config.Locale['attach_front'],
        bones = {'wheel_lf', 'wheel_rf'},
        distance = 4.5,
        canInteract = function(entity)
            if towingData.rope ~= nil then return false end
            if towingData.targetVehicle == entity then return false end
            local playerPed = PlayerPedId()
            local playerVeh = GetVehiclePedIsIn(playerPed, false)
            if playerVeh ~= 0 or not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then return false end
            if towingData.vehicle and towingData.firstIsRear then
                if towingData.vehicle == entity then return false end
                if not IsSameVehicleType(towingData.vehicle, entity) then return false end
                local veh1Pos = GetEntityCoords(towingData.vehicle)
                local veh2Pos = GetEntityCoords(entity)
                return #(veh1Pos - veh2Pos) <= Config.MaxDistance
            end
            

            if not HasRopeItem() then return false end
            if towingData.vehicle then return false end
            return true
        end,
        onSelect = function(data)
            if towingData.vehicle and towingData.firstIsRear then
                StartTowing(towingData.vehicle, data.entity)
            else
                local ped = PlayerPedId()
                lib.requestModel(Config.RopeProp)
                towingData.ropeProp = CreateObject(GetHashKey(Config.RopeProp), 0, 0, 0, true, true, true)
                AttachEntityToEntity(towingData.ropeProp, ped, 61, 0.21236287593877, -0.015105864412862, -0.093269506059142, 28.454237413852, 46.483631952722, -142.1679835736, true, true, false, true, 1, true)
                
                RopeLoadTextures()
                while not RopeAreTexturesLoaded() do Wait(0) end
                local propPos = GetEntityCoords(towingData.ropeProp)
                local vehPos = GetVehicleBonePosition(data.entity, 'bumper_f')
                towingData.handRope = AddRope(propPos.x, propPos.y, propPos.z, 0.0, 0.0, 0.0, Config.RopeLength, 1, Config.RopeLength, 1.0, 0.5, false, false, false, 1.0, false)
                ActivatePhysics(towingData.handRope)
                AttachEntitiesToRope(towingData.handRope, towingData.ropeProp, data.entity, propPos.x, propPos.y, propPos.z, vehPos.x, vehPos.y, vehPos.z, Config.RopeLength, false, false, nil, nil)
                
                towingData.targetVehicle = data.entity
                towingData.firstIsRear = false
                lib.notify({title = Config.Locale['title'], description = Config.Locale['notify_aim_rear'], type = 'inform'})
            end
        end
    },
    {
        name = 'attach_rope_to_rear',
        icon = 'fa-solid fa-link',
        label = Config.Locale['connect_vehicle'],
        bones = {'wheel_lr', 'wheel_rr'},
        distance = 4.5,
        canInteract = function(entity)
            if towingData.rope ~= nil then return false end
            if not towingData.targetVehicle then return false end
            if towingData.targetVehicle == entity then return false end
            local playerPed = PlayerPedId()
            local playerVeh = GetVehiclePedIsIn(playerPed, false)
            if playerVeh ~= 0 or not DoesEntityExist(entity) then return false end
            if not IsSameVehicleType(towingData.targetVehicle, entity) then return false end
            
            local veh1Pos = GetEntityCoords(towingData.targetVehicle)
            local veh2Pos = GetEntityCoords(entity)
            return #(veh1Pos - veh2Pos) <= Config.MaxDistance
        end,
        onSelect = function(data)
            StartTowing(data.entity, towingData.targetVehicle)
        end
    },
    {
        name = 'detach_rope_front',
        icon = 'fa-solid fa-unlink',
        label = Config.Locale['detach_rope'],
        distance = 5.0,
        canInteract = function(entity)
            return towingData.targetVehicle == entity and towingData.rope ~= nil
        end,
        onSelect = function()
            TriggerServerEvent('pitrs_towing:addRope', towingData.ropeType)
            StopTowing()
        end
    },
    {
        name = 'cancel_rope',
        icon = 'fa-solid fa-xmark',
        label = Config.Locale['cancel_rope'],
        bones = {'wheel_lr', 'wheel_rr'},
        distance = 3.5,
        canInteract = function(entity)
            return towingData.vehicle == entity and towingData.rope == nil
        end,
        onSelect = function()
            if towingData.ropeProp then
                DeleteEntity(towingData.ropeProp)
                towingData.ropeProp = nil
            end
            if towingData.handRope then
                DeleteRope(towingData.handRope)
                towingData.handRope = nil
            end
            towingData.vehicle = nil
            towingData.firstIsRear = false
            lib.notify({title = Config.Locale['title'], description = Config.Locale['notify_cancelled'], type = 'inform'})
        end
    },
    {
        name = 'cancel_rope_front',
        icon = 'fa-solid fa-xmark',
        label = Config.Locale['cancel_rope'],
        distance = 5.0,
        canInteract = function(entity)
            return towingData.targetVehicle == entity and not towingData.firstIsRear and towingData.rope == nil
        end,
        onSelect = function()
            if towingData.ropeProp then
                DeleteEntity(towingData.ropeProp)
                towingData.ropeProp = nil
            end
            if towingData.handRope then
                DeleteRope(towingData.handRope)
                towingData.handRope = nil
            end
            towingData.targetVehicle = nil
            towingData.firstIsRear = false
            lib.notify({title = Config.Locale['title'], description = Config.Locale['notify_cancelled'], type = 'inform'})
        end
    },
    {
        name = 'detach_rope',
        icon = 'fa-solid fa-unlink',
        label = Config.Locale['detach_rope'],
        bones = {'wheel_lr', 'wheel_rr'},
        distance = 3.5,
        canInteract = function(entity)
            return towingData.vehicle == entity and towingData.rope ~= nil
        end,
        onSelect = function()
            TriggerServerEvent('pitrs_towing:addRope', towingData.ropeType)
            StopTowing()
        end
    }
})

CreateThread(function()
    while true do
        Wait(1000)
        if towingData.rope and towingData.vehicle then
            local speed = GetEntitySpeed(towingData.vehicle) * 2.23694
            local maxSpeed = towingData.ropeType == Config.SteelRopeItem and Config.SteelRopeMaxSpeed or Config.RopeMaxSpeed
            
            if speed > maxSpeed then
                lib.notify({title = Config.Locale['title'], description = Config.Locale['notify_rope_broke'], type = 'error'})
                StopTowing()
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if towingData.rope then
            StopTowing()
        end
    end
end)
