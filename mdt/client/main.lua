-- ============================================================================
-- Fv_MDT — Client entry (open/close, access gate, keybind, command)
-- ============================================================================

local isOpen = false

local function hasJobAccess()
    local job = Bridge.GetJob()
    if not job then return false end
    return Config.Jobs[job.name] ~= nil
end

local function hasItem()
    if not Config.RequireItem then return true end
    local core = Bridge.GetCore()
    if core and core.HasItem then return core.HasItem(Config.RequireItem) end
    return true -- if we can't check, don't block
end

function OpenMDT()
    if isOpen then return end
    if not hasJobAccess() then
        Bridge.Notify('You are not authorized to use the MDT.', 'error')
        return
    end
    if not hasItem() then
        Bridge.Notify('You need a tablet to open the MDT.', 'error')
        return
    end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'open' })
end

function CloseMDT()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

-- ESC / Backspace to close (handled inside NUI too, this is the native guard).
CreateThread(function()
    while true do
        if isOpen then
            if IsControlJustReleased(0, 322) or IsControlJustReleased(0, 177) then
                CloseMDT()
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- Command + keymapping
RegisterCommand(Config.OpenCommand, function()
    if isOpen then CloseMDT() else OpenMDT() end
end, false)

RegisterKeyMapping(Config.OpenCommand, 'Open Mobile Data Terminal', 'keyboard', Config.OpenKeybind)

-- Let the server push live BOLO/warrant broadcasts to open terminals.
RegisterNetEvent('fv_mdt:client:broadcast', function(kind, payload)
    if isOpen then
        SendNUIMessage({ type = 'broadcast', kind = kind, payload = payload })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then
        SetNuiFocus(false, false)
    end
end)
