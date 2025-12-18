-- ════════════════════════════════════════════════════════════════
-- WINCH SYSTEM - ROPE MECHANICS
-- ════════════════════════════════════════════════════════════════

Winch = {
    active = false,
    carryingCable = false,
    towVehicle = nil,
    rope = nil,
    ropeCoords = nil,
    targetSelectionActive = false
}

-- ════════════════════════════════════════════════════════════════
-- MAIN WINCH FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Winch:TakeCable(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    if self.carryingCable then
        Utils.Notify('You are already carrying a cable!', 'error')
        return false
    end
    
    local config = Utils.GetVehicleConfig(vehicle)
    if not config or not config.winchPoint then
        Utils.Notify('This vehicle does not have a winch!', 'error')
        return false
    end
    
    self.towVehicle = vehicle
    self.carryingCable = true
    
    -- Create rope
    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Wait(100)
    end
    
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local winchWorldCoords = Utils.GetWorldCoordsFromOffset(vehicle, config.winchPoint)
    
    -- Create rope
    self.rope = AddRope(
        winchWorldCoords.x, winchWorldCoords.y, winchWorldCoords.z,
        0.0, 0.0, 0.0,
        Config.Winch.maxLength,
        Config.Winch.ropeType,
        Config.Winch.maxLength,
        Config.Winch.ropeLength,
        0.5, false, false, false, 1.0, false
    )
    
    -- Attach rope to vehicle
    local boneIndex = GetEntityBoneIndexByName(vehicle, config.bone or 'chassis')
    self.ropeCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
    AttachRopeToEntity(self.rope, vehicle, self.ropeCoords.x, self.ropeCoords.y, self.ropeCoords.z, 1)
    
    -- Attach rope to player
    AttachEntitiesToRope(self.rope, vehicle, ped, 
        self.ropeCoords.x, self.ropeCoords.y, self.ropeCoords.z,
        pedCoords.x, pedCoords.y, pedCoords.z,
        Config.Winch.maxLength
    )
    
    Utils.Notify('Cable taken! Press NUM 6 to select attach point on vehicle.', 'success')
    
    -- Start target selection thread
    self.targetSelectionActive = true
    CreateThread(function()
        self:TargetSelectionLoop()
    end)
    
    return true
end

function Winch:ReleaseCable()
    if not self.carryingCable then return false end
    
    if self.rope then
        DeleteRope(self.rope)
        self.rope = nil
    end
    
    self.carryingCable = false
    self.targetSelectionActive = false
    self.towVehicle = nil
    self.ropeCoords = nil
    
    Utils.Notify('Cable released.', 'info')
    return true
end

function Winch:TargetSelectionLoop()
    while self.targetSelectionActive and self.carryingCable do
        local sleep = 0
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        
        -- Raycast for target selection
        local hit, coords, entity = Utils.RaycastCamera(Config.Winch.laserDistance)
        
        if hit then
            -- Draw laser line
            Utils.DrawLine3D(pedCoords, coords, 
                Config.Winch.laserColor.r,
                Config.Winch.laserColor.g,
                Config.Winch.laserColor.b,
                Config.Winch.laserColor.a
            )
            
            -- Draw target sphere
            if entity and IsEntityAVehicle(entity) and entity ~= self.towVehicle then
                Utils.DrawSphere3D(coords, 0.2, 0, 255, 0, 200)
                
                if Config.Visual.use3DText then
                    Utils.DrawText3D(coords + vector3(0, 0, 0.5), 
                        '[NUM 6] Attach Cable Here'
                    )
                else
                    Utils.ShowHelpText('[~g~NUM 6~w~] Attach Cable to Vehicle')
                end
                
                -- Attach cable
                if IsControlJustPressed(0, Config.Keys.AttachWinchCable) then
                    self:AttachCableToVehicle(entity, coords)
                end
            end
        else
            Utils.ShowHelpText(
                '~y~Carrying Winch Cable~w~\n' ..
                'Aim at a vehicle and press ~g~NUM 6~w~ to attach'
            )
        end
        
        -- Cancel cable
        if IsControlJustPressed(0, Config.Keys.CancelEditor) then
            self:ReleaseCable()
        end
        
        Wait(sleep)
    end
end

function Winch:AttachCableToVehicle(targetVehicle, targetCoords)
    if not DoesEntityExist(targetVehicle) or not DoesEntityExist(self.towVehicle) then
        self:ReleaseCable()
        return false
    end
    
    local ped = PlayerPedId()
    
    -- Get target bone position
    local targetBoneIndex = GetEntityBoneIndexByName(targetVehicle, Config.Winch.targetBone)
    local targetBoneCoords = GetWorldPositionOfEntityBone(targetVehicle, targetBoneIndex)
    
    -- Detach rope from player
    DetachRopeFromEntity(self.rope, ped)
    
    -- Attach rope to target vehicle
    AttachEntitiesToRope(self.rope, self.towVehicle, targetVehicle,
        self.ropeCoords.x, self.ropeCoords.y, self.ropeCoords.z,
        targetBoneCoords.x, targetBoneCoords.y, targetBoneCoords.z,
        100
    )
    
    Utils.Notify('Cable attached! Winching vehicle...', 'success')
    
    -- Start winching
    self:WindVehicle(targetVehicle, targetBoneCoords)
    
    return true
end

function Winch:WindVehicle(targetVehicle, targetBoneCoords)
    if not self.rope or not DoesEntityExist(targetVehicle) then return end
    
    self.carryingCable = false
    self.targetSelectionActive = false
    
    CreateThread(function()
        -- Freeze target vehicle
        FreezeEntityPosition(targetVehicle, true)
        
        -- Start winding
        StartRopeWinding(self.rope)
        
        -- Wait until rope is short enough
        while RopeGetDistanceBetweenEnds(self.rope) >= Config.Winch.minDistance do
            local currentDist = RopeGetDistanceBetweenEnds(self.rope)
            RopeForceLength(self.rope, currentDist - Config.Winch.windingSpeed)
            Wait(50)
        end
        
        -- Unfreeze target vehicle
        FreezeEntityPosition(targetVehicle, false)
        
        -- Attach vehicle to tow vehicle
        local config = Utils.GetVehicleConfig(self.towVehicle)
        if config and config.attachOffset then
            local vehicleHeightMin, vehicleHeightMax = GetModelDimensions(GetEntityModel(targetVehicle))
            local boneIndex = GetEntityBoneIndexByName(self.towVehicle, config.bone or 'chassis')
            
            AttachEntityToEntity(
                targetVehicle, self.towVehicle, boneIndex,
                config.attachOffset.x,
                config.attachOffset.y,
                config.attachOffset.z - vehicleHeightMin.z + Config.Winch.attachHeight,
                2.0, 0.0, 0.0,
                true, true, true, false, 0, true
            )
        end
        
        -- Clean up rope
        if self.rope then
            DeleteRope(self.rope)
            self.rope = nil
        end
        
        self.towVehicle = nil
        self.ropeCoords = nil
        
        Utils.Notify('Vehicle secured on bed!', 'success')
    end)
end

-- ════════════════════════════════════════════════════════════════
-- WINCH CONTROL THREAD
-- ════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        
        if not IsPedInAnyVehicle(ped, false) and not self.carryingCable then
            local coords = GetEntityCoords(ped)
            local vehicle, distance = Utils.GetClosestVehicle(coords, 10.0)
            
            if vehicle and (Utils.IsMovableRampVehicle(vehicle) or Utils.IsStaticRampVehicle(vehicle)) then
                local config = Utils.GetVehicleConfig(vehicle)
                if config and config.winchPoint then
                    local winchCoords = Utils.GetWorldCoordsFromOffset(vehicle, config.winchPoint)
                    local distToWinch = #(coords - winchCoords)
                    
                    if distToWinch < 2.5 then
                        sleep = 0
                        
                        -- Check if bed is extended (for movable ramps)
                        local canUseWinch = true
                        if Utils.IsMovableRampVehicle(vehicle) then
                            canUseWinch = Ramps:IsMovableRampExtended(vehicle)
                        end
                        
                        if canUseWinch then
                            if Config.Visual.use3DText then
                                Utils.DrawText3D(winchCoords, '[NUM 4] Take Winch Cable')
                            else
                                Utils.ShowHelpText('[~g~NUM 4~w~] Take Winch Cable')
                            end
                            
                            if IsControlJustPressed(0, Config.Keys.TakeWinchCable) then
                                if Utils.HasJob() then
                                    Winch:TakeCable(vehicle)
                                else
                                    Utils.Notify(Config.Notifications.noPermission.message, 'error')
                                end
                            end
                        else
                            if Config.Visual.use3DText then
                                Utils.DrawText3D(winchCoords, '~r~Extend bed to use winch~w~')
                            end
                        end
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if Winch.rope then
        DeleteRope(Winch.rope)
    end
end)