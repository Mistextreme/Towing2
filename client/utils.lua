-- ════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ════════════════════════════════════════════════════════════════

Utils = {}

-- ════════════════════════════════════════════════════════════════
-- PLAYER & JOB FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.HasJob()
    local playerData = ESX.GetPlayerData()
    if not playerData.job then return false end
    
    for _, job in ipairs(Config.AllowedJobs) do
        if playerData.job.name == job then
            return true
        end
    end
    return false
end

-- ════════════════════════════════════════════════════════════════
-- VEHICLE FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.GetVehicleInDirection()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local offset = vector3(
        math.sin(math.rad(heading)) * 5.0,
        math.cos(math.rad(heading)) * 5.0,
        0.0
    )
    local targetCoords = coords + offset
    
    local rayHandle = StartShapeTestRay(
        coords.x, coords.y, coords.z,
        targetCoords.x, targetCoords.y, targetCoords.z,
        10, ped, 0
    )
    
    local _, hit, _, _, entity = GetShapeTestResult(rayHandle)
    
    if hit and DoesEntityExist(entity) and IsEntityAVehicle(entity) then
        return entity
    end
    return nil
end

function Utils.GetClosestVehicle(coords, maxDistance)
    coords = coords or GetEntityCoords(PlayerPedId())
    maxDistance = maxDistance or 10.0
    
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = nil
    local closestDistance = maxDistance
    
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehicleCoords)
            
            if distance < closestDistance then
                closestVehicle = vehicle
                closestDistance = distance
            end
        end
    end
    
    return closestVehicle, closestDistance
end

function Utils.IsMovableRampVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    return Config.MovableRampVehicles[displayName:lower()] ~= nil
end

function Utils.IsStaticRampVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    return Config.StaticRampVehicles[displayName:lower()] ~= nil
end

function Utils.GetVehicleConfig(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model):lower()
    
    return Config.MovableRampVehicles[displayName] or Config.StaticRampVehicles[displayName]
end

function Utils.GetVehicleBelowRaycast(fromCoords, toCoords)
    local rayHandle = CastRayPointToPoint(
        fromCoords.x, fromCoords.y, fromCoords.z,
        toCoords.x, toCoords.y, toCoords.z,
        10, PlayerPedId(), 0
    )
    local _, _, _, _, vehicle = GetRaycastResult(rayHandle)
    return vehicle
end

-- ════════════════════════════════════════════════════════════════
-- RAYCAST FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    
    return {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
end

function Utils.RaycastCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = Utils.RotationToDirection(cameraRotation)
    
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    
    local rayHandle = StartShapeTestRay(
        cameraCoord.x, cameraCoord.y, cameraCoord.z,
        destination.x, destination.y, destination.z,
        -1, PlayerPedId(), 0
    )
    
    local _, hit, coords, _, entity = GetShapeTestResult(rayHandle)
    return hit, coords, entity
end

-- ════════════════════════════════════════════════════════════════
-- OFFSET CALCULATIONS
-- ════════════════════════════════════════════════════════════════

function Utils.GetOffsetBetweenEntities(entity, targetCoords)
    if not DoesEntityExist(entity) then return vector3(0, 0, 0) end
    return GetOffsetFromEntityGivenWorldCoords(entity, targetCoords.x, targetCoords.y, targetCoords.z)
end

function Utils.GetWorldCoordsFromOffset(entity, offset)
    if not DoesEntityExist(entity) then return vector3(0, 0, 0) end
    return GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
end

-- ════════════════════════════════════════════════════════════════
-- VISUAL FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.DrawText3D(coords, text, scale)
    scale = scale or 0.35
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    
    if onScreen then
        local camCoords = GetGameplayCamCoord()
        local distance = #(camCoords - coords)
        local fov = (1 / GetGameplayCamFov()) * 100
        local scaleMultiplier = (scale / distance) * 2 * fov
        
        SetTextScale(0.0, scaleMultiplier)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(x, y)
    end
end

function Utils.DrawLine3D(from, to, r, g, b, a)
    DrawLine(from.x, from.y, from.z, to.x, to.y, to.z, r, g, b, a)
end

function Utils.DrawSphere3D(coords, radius, r, g, b, a)
    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
               radius, radius, radius, r, g, b, a, false, false, 2, false, nil, nil, false)
end

function Utils.DrawMarker3D(coords, markerType, size, r, g, b, a)
    markerType = markerType or 0
    size = size or vector3(0.5, 0.5, 0.5)
    DrawMarker(markerType, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
               size.x, size.y, size.z, r, g, b, a, false, false, 2, nil, nil, false)
end

-- ════════════════════════════════════════════════════════════════
-- NOTIFICATION FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.Notify(message, type, duration)
    if not message then return end
    type = type or 'info'
    duration = duration or 5000
    
    ESX.ShowNotification(message, type, duration)
end

function Utils.ShowHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ════════════════════════════════════════════════════════════════
-- SOUND FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.PlayHydraulicSound(entity, soundType)
    if not Config.Visual.playHydraulicSounds then return end
    if not DoesEntityExist(entity) then return end
    
    local soundName = soundType == 'up' and 'Hydraulics_Up' or 'Hydraulics_Down'
    PlaySoundFromEntity(-1, soundName, entity, 'Lowrider_Super_Mod_Garage_Sounds', 0, 0)
end

-- ════════════════════════════════════════════════════════════════
-- CLIPBOARD FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.CopyToClipboard(text)
    SendNUIMessage({
        type = 'copyToClipboard',
        text = tostring(text)
    })
end

-- ════════════════════════════════════════════════════════════════
-- TABLE FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.TableContains(table, element)
    if not table then return false end
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function Utils.TableCount(table)
    if not table then return 0 end
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

-- ════════════════════════════════════════════════════════════════
-- MATH FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.Round(number, decimals)
    decimals = decimals or 2
    local power = 10 ^ decimals
    return math.floor(number * power + 0.5) / power
end

function Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- ════════════════════════════════════════════════════════════════
-- STRING FUNCTIONS
-- ════════════════════════════════════════════════════════════════

function Utils.FormatVector3(vec, decimals)
    decimals = decimals or 2
    return string.format(
        'vec3(%.'..(decimals)..'f, %.'..(decimals)..'f, %.'..(decimals)..'f)',
        vec.x, vec.y, vec.z
    )
end

return Utils