-- ============================================================================
-- Fv_MDT — CFW Core bridge
-- ----------------------------------------------------------------------------
-- All framework-specific calls live here. If your CFW export names differ,
-- change them ONLY in this file. The rest of the resource uses Bridge.*.
-- ============================================================================

Bridge = {}

local Core

local function resolveCore()
    if Core then return Core end
    local ok, obj = pcall(function()
        return exports[Config.Core][Config.CoreExport]()
    end)
    if ok and obj then
        Core = obj
    end
    return Core
end

CreateThread(function()
    while not resolveCore() do Wait(250) end
end)

function Bridge.GetCore()
    return resolveCore()
end

-- ------------------------------------------------------------------ SERVER ---
if IsDuplicityVersion() then

    -- Returns a player object for a server id, or nil.
    function Bridge.GetPlayer(src)
        local core = resolveCore()
        if not core then return nil end
        return core.GetPlayer and core.GetPlayer(src) or core.getPlayer and core.getPlayer(src)
    end

    -- { job = 'police', grade = 3 } for a server id.
    function Bridge.GetJob(src)
        local p = Bridge.GetPlayer(src)
        if not p then return nil end
        local job = p.job or (p.getJob and p:getJob()) or p.PlayerData and p.PlayerData.job
        if not job then return nil end
        return {
            name  = job.name or job.job or job.id,
            grade = tonumber(job.grade or job.level or (job.grade and job.grade.level) or 0) or 0,
            label = job.label,
        }
    end

    -- Stable citizen identifier (used as the DB key linking MDT records to a
    -- character). CFW usually exposes a citizenid / identifier.
    function Bridge.GetIdentifier(src)
        local p = Bridge.GetPlayer(src)
        if not p then return nil end
        return p.citizenid or p.identifier
            or (p.getIdentifier and p:getIdentifier())
            or (p.PlayerData and (p.PlayerData.citizenid or p.PlayerData.identifier))
    end

    -- Character display name.
    function Bridge.GetName(src)
        local p = Bridge.GetPlayer(src)
        if not p then return ('Unknown (%s)'):format(src) end
        local ci = p.charinfo or (p.PlayerData and p.PlayerData.charinfo)
        if ci and ci.firstname then
            return ci.firstname .. ' ' .. (ci.lastname or '')
        end
        return p.name or ('Player %s'):format(src)
    end

    -- Charge a player's bank account (fines). Return true on success.
    function Bridge.ChargeMoney(src, amount, reason)
        local p = Bridge.GetPlayer(src)
        if not p then return false end
        amount = math.max(0, math.floor(amount or 0))
        if amount == 0 then return true end
        if p.removeMoney then return p.removeMoney('bank', amount, reason) ~= false end
        if p.Functions and p.Functions.RemoveMoney then
            return p.Functions.RemoveMoney('bank', amount, reason) ~= false
        end
        return false
    end

    -- Jail a player (delegates to your jail resource / core function).
    function Bridge.Jail(src, minutes, reason)
        local core = resolveCore()
        if core and core.Jail then return core.Jail(src, minutes, reason) end
        -- Fallback: emit an event your jail script can listen to.
        TriggerEvent('fv_mdt:server:jail', src, minutes, reason)
        return true
    end

    -- Find an online player's server id by (partial) name or citizen id.
    function Bridge.FindOnline(query)
        query = tostring(query or ''):lower()
        for _, src in ipairs(GetPlayers()) do
            src = tonumber(src)
            local id = tostring(Bridge.GetIdentifier(src) or ''):lower()
            local nm = tostring(Bridge.GetName(src) or ''):lower()
            if id == query or nm:find(query, 1, true) then
                return src
            end
        end
        return nil
    end

    -- Does this player have LEO/allowed access right now?
    function Bridge.CanAccess(src)
        local job = Bridge.GetJob(src)
        if not job then return false, nil end
        local cfg = Config.Jobs[job.name]
        if not cfg then return false, job end
        return true, job
    end

-- ------------------------------------------------------------------ CLIENT ---
else

    function Bridge.GetJob()
        local core = resolveCore()
        if not core then return nil end
        local pd = core.GetPlayerData and core.GetPlayerData()
            or core.PlayerData
            or (core.getPlayerData and core.getPlayerData())
        if not pd or not pd.job then return nil end
        return {
            name  = pd.job.name or pd.job.job or pd.job.id,
            grade = tonumber(pd.job.grade or pd.job.level or (pd.job.grade and pd.job.grade.level) or 0) or 0,
            label = pd.job.label,
        }
    end

    function Bridge.Notify(msg, kind)
        local core = resolveCore()
        if core and core.Notify then core.Notify(msg, kind) return end
        -- Fallback native notification.
        SetNotificationTextEntry('STRING')
        AddTextComponentSubstringPlayerName(msg)
        DrawNotification(false, true)
    end
end

return Bridge
