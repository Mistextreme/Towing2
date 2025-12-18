-- ════════════════════════════════════════════════════════════════
-- ATTACH/DETACH SYSTEM - VEHICLE LOADING
-- ════════════════════════════════════════════════════════════════

Attach = {
    attachedVehicles = {} -- {[towVehicle] = {vehicle, originalPos}}
}

-- ════════════════════════════════════════════════════════════════
-- MAIN ATTACH/DETACH FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Attach:CanAttachVehicle(towVehicle, targetVehicle)
    if not DoesEntityExist(towVehicle) or not DoesEntityExist(targetVehicle) then
        return false, 'Vehicle does not exist'
    end
    
    if towVehicle == targetVehicle then
        return false, 'Cannot attach vehicle to itself'
    end
    
    if IsEntityAttached(targetVehicle) then
        return false, 'Vehicle is already attached'
    end
    
    -- Check if it's a compatible vehicle
    if not Utils.IsMovableRampVehicle(towVehicle) and not Utils.IsStaticRampVehicle(towVehicle) then
        return false, 'This is not a tow vehicle'
    end
    
    -- For movable ramps, check if bed is extended
    if Utils.IsMovableRampVehicle(towVehicle) then
        if not Ramps:IsMovableRampExtended(towVehicle) then
            return false, 'Bed must be fully extended to attach vehicles'
        end
    end
    
    -- For static ramps, check if ramp is deployed
    if Utils.IsStaticRampVehicle(towVehicle) then
        if not Ramps:IsStaticRampDeployed(towVehicle) then
            return false, 'Ramp must be deployed to attach vehicles'
        end
    end
    
    return true, nil
end

function Attach:AttachVehicle(towVehicle, targetVehicle)
    local canAttach, reason = self:CanAttachVehicle(towVehicle, targetVehicle)
    
    if not canAttach then
        Utils.Notify(reason or 'Cannot attach vehicle', 'error')
        return false
    end
    
    local config = Utils.GetVehicleConfig(towVehicle)
    if not config or not config.attachOffset then
        Utils.Notify('Vehicle configuration missing!', 'error')
        return false
    end
    
    -- Get vehicle dimensions for height adjustment
    local vehicleHeightMin, vehicleHeightMax = GetModelDimensions(GetEntityModel(targetVehicle))
    
    -- Calculate attach position
    local boneIndex = GetEntityBoneIndexByName(towVehicle, config.bone or 'chassis')
    
    -- Get current bed position for movable ramps
    local heightAdjustment = 0.0
    if Utils.IsMovableRampVehicle(towVehicle) then
        local rampPosition = Ramps:GetMovableRampPosition(towVehicle)
        -- Adjust height based on ramp position
        heightAdjustment = (rampPosition - config.minPosition) * 2.0
    end
    
    -- Calculate rotation offset
    local towRotation = GetEntityRotation(towVehicle, 2)
    local targetRotation = GetEntityRotation(targetVehicle, 2)
    local rotationOffset = targetRotation.z - towRotation.z
    
    -- Store original position for potential detach
    self.attachedVehicles[towVehicle] = {
        vehicle = targetVehicle,
        originalPos = GetEntityCoords(targetVehicle),
        originalRot = targetRotation
    }
    
    -- Attach vehicle
    AttachEntityToEntity(
        targetVehicle, towVehicle, boneIndex,
        config.attachOffset.x,
        config.attachOffset.y,
        config.attachOffset.z - vehicleHeightMin.z + heightAdjustment,
        2.0, 0.0, rotationOffset,
        false, false, true, false, 0, true
    )
    
    Utils.Notify(Config.Notifications.vehicleAttached.message, 'success')
    TriggerServerEvent('flatbed:syncAttachment', NetworkGetNetworkIdFromEntity(towVehicle), NetworkGetNetworkIdFromEntity(targetVehicle), true)
    
    return true
end

function Attach:DetachVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    
    if not IsEntityAttached(vehicle) then
        Utils.Notify('Vehicle is not attached!', 'error')
        return false
    end
    
    -- Find tow vehicle
    local towVehicle = nil
    for tow, data in pairs(self.attachedVehicles) do
        if data.vehicle == vehicle then
            towVehicle = tow
            break
        end
    end
    
    -- Detach vehicle
    DetachEntity(vehicle, true, true)
    
    -- Apply slight upward velocity to prevent clipping
    SetEntityVelocity(vehicle, 0.0, 0.0, 0.5)
    
    if towVehicle then
        self.attachedVehicles[towVehicle] = nil
        TriggerServerEvent('flatbed:syncAttachment', NetworkGetNetworkIdFromEntity(towVehicle), NetworkGetNetworkIdFromEntity(vehicle), false)
    end
    
    Utils.Notify(Config.Notifications.vehicleDetached.message, 'success')
    
    return true
end

function Attach:UpdateAttachedVehiclePosition(towVehicle)
    if not self.attachedVehicles[towVehicle] then return end
    
    local data = self.attachedVehicles[towVehicle]
    local targetVehicle = data.vehicle
    
    if not DoesEntityExist(targetVehicle) or not IsEntityAttached(targetVehicle) then
        self.attachedVehicles[towVehicle] = nil
        return
    end
    
    local config = Utils.GetVehicleConfig(towVehicle)
    if not config then return end
    
    -- Only update for movable ramps
    if Utils.IsMovableRampVehicle(towVehicle) then
        local rampPosition = Ramps:GetMovableRampPosition(towVehicle)
        local vehicleHeightMin, vehicleHeightMax = GetModelDimensions(GetEntityModel(targetVehicle))
        local heightAdjustment = (rampPosition - config.minPosition) * 2.0
        
        local boneIndex = GetEntityBoneIndexByName(towVehicle, config.bone or 'chassis')
        
        -- Detach and reattach with new position
        DetachEntity(targetVehicle, false, false)
        
        AttachEntityToEntity(
            targetVehicle, towVehicle, boneIndex,
            config.attachOffset.x,
            config.attachOffset.y,
            config.attachOffset.z - vehicleHeightMin.z + heightAdjustment,
            2.0, 0.0, 0.0,
            false, false, true, false, 0, true
        )
    end
end

-- ════════════════════════════════════════════════════════════════
-- ATTACH/DETACH CONTROL THREAD
-- ════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            if GetPedInVehicleSeat(vehicle, -1) == ped then -- Driver seat
                sleep = 0
                
                if IsEntityAttached(vehicle) then
                    -- Show detach prompt
                    Utils.ShowHelpText('[~r~E~w~] Detach Vehicle')
                    
                    if IsControlJustPressed(0, Config.Keys.AttachDetach) then
                        if Utils.HasJob() then
                            Attach:DetachVehicle(vehicle)
                        else
                            Utils.Notify(Config.Notifications.noPermission.message, 'error')
                        end
                    end
                else
                    -- Check for vehicle below (raycast)
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local vehicleOffset = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.0, -2.0)
                    local belowVehicle = Utils.GetVehicleBelowRaycast(vehicleCoords, vehicleOffset)
                    
                    if belowVehicle and DoesEntityExist(belowVehicle) and belowVehicle ~= vehicle then
                        if Utils.IsMovableRampVehicle(belowVehicle) or Utils.IsStaticRampVehicle(belowVehicle) then
                            -- Show attach prompt
                            Utils.ShowHelpText('[~g~E~w~] Attach Vehicle to Bed')
                            
                            if IsControlJustPressed(0, Config.Keys.AttachDetach) then
                                if Utils.HasJob() then
                                    Attach:AttachVehicle(belowVehicle, vehicle)
                                else
                                    Utils.Notify(Config.Notifications.noPermission.message, 'error')
                                end
                            end
                        end
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Update attached vehicle positions for movable ramps
CreateThread(function()
    while true do
        Wait(100)
        
        for towVehicle, data in pairs(Attach.attachedVehicles) do
            if DoesEntityExist(towVehicle) and Utils.IsMovableRampVehicle(towVehicle) then
                Attach:UpdateAttachedVehiclePosition(towVehicle)
            end
        end
    end
end)

-- Cleanup on vehicle deletion
CreateThread(function()
    while true do
        Wait(5000)
        
        for towVehicle, data in pairs(Attach.attachedVehicles) do
            if not DoesEntityExist(towVehicle) or not DoesEntityExist(data.vehicle) then
                Attach.attachedVehicles[towVehicle] = nil
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- NETWORK EVENTS
-- ════════════════════════════════════════════════════════════════

RegisterNetEvent('flatbed:syncAttachmentClient', function(towVehicleNetId, targetVehicleNetId, isAttached)
    local towVehicle = NetworkGetEntityFromNetworkId(towVehicleNetId)
    local targetVehicle = NetworkGetEntityFromNetworkId(targetVehicleNetId)
    
    if not DoesEntityExist(towVehicle) or not DoesEntityExist(targetVehicle) then return end
    
    if isAttached then
        Attach.attachedVehicles[towVehicle] = {
            vehicle = targetVehicle,
            originalPos = GetEntityCoords(targetVehicle),
            originalRot = GetEntityRotation(targetVehicle, 2)
        }
    else
        Attach.attachedVehicles[towVehicle] = nil
    end
end)