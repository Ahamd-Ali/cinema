-- ============================================================================
-- Fv_MDT — Request transport (framework-agnostic callback bridge)
-- ----------------------------------------------------------------------------
-- The NUI sends one net event per action with a request id; the server runs
-- the matching entry in `Actions`, enforcing its permission, and replies.
-- ============================================================================

RegisterNetEvent('fv_mdt:server:request', function(reqId, action, data)
    local src = source
    local def = Actions[action]

    if not def then
        return TriggerClientEvent('fv_mdt:client:response', src, reqId,
            { ok = false, error = 'unknown_action' })
    end

    -- Authoritative permission check for THIS action.
    local actor = MDT.guard(src, def.perm)
    if not actor then
        return TriggerClientEvent('fv_mdt:client:response', src, reqId,
            { ok = false, error = 'forbidden' })
    end

    local ok, result = pcall(def.fn, actor, data or {})
    if not ok then
        print(('[Fv_MDT] action %s errored: %s'):format(action, result))
        return TriggerClientEvent('fv_mdt:client:response', src, reqId,
            { ok = false, error = 'server_error' })
    end

    TriggerClientEvent('fv_mdt:client:response', src, reqId, result)
end)
