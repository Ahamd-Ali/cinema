-- ============================================================================
-- Fv_MDT — Client NUI transport
-- ----------------------------------------------------------------------------
-- Bridges NUI fetch() calls <-> server actions using a request/response id.
-- ============================================================================

local pending = {}
local seq = 0

-- Fire an action at the server and resolve the NUI callback with the result.
local function relay(action, data, cb)
    seq = seq + 1
    local id = seq
    pending[id] = cb
    TriggerServerEvent('fv_mdt:server:request', id, action, data)

    -- Safety timeout so the UI never hangs forever.
    SetTimeout(10000, function()
        if pending[id] then
            pending[id]({ ok = false, error = 'timeout' })
            pending[id] = nil
        end
    end)
end

RegisterNetEvent('fv_mdt:client:response', function(id, result)
    local cb = pending[id]
    if cb then
        cb(result)
        pending[id] = nil
    end
end)

-- Generic NUI endpoint: { action = 'searchProfiles', data = {...} }
RegisterNUICallback('action', function(payload, cb)
    relay(payload.action, payload.data or {}, cb)
end)

-- Close from within the UI.
RegisterNUICallback('close', function(_, cb)
    CloseMDT()          -- defined in client/main.lua
    cb({ ok = true })
end)

-- Ping the plate of the vehicle the officer is looking at / in (helper).
RegisterNUICallback('scanPlate', function(_, cb)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 12.0, 0, 71)
    end
    if veh and veh ~= 0 then
        cb({ ok = true, plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+$', '') })
    else
        cb({ ok = false })
    end
end)
