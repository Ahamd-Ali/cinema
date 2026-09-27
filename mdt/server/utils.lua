-- ============================================================================
-- Fv_MDT — Server utilities (audit log, webhook, sanitisation)
-- ============================================================================

Utils = {}

-- Trim + cap a string to guard against oversized NUI payloads.
function Utils.clean(str, max)
    if str == nil then return nil end
    str = tostring(str):gsub('^%s+', ''):gsub('%s+$', '')
    max = max or 5000
    if #str > max then str = str:sub(1, max) end
    return str
end

function Utils.toInt(v, default, min, max)
    v = tonumber(v) or default or 0
    v = math.floor(v)
    if min and v < min then v = min end
    if max and v > max then v = max end
    return v
end

-- Look up a charge definition from Config by id.
function Utils.getChargeDef(id)
    for _, c in ipairs(Config.Charges) do
        if c.id == id then return c end
    end
    return nil
end

-- Validate & total a client-submitted charge list against the penal code.
-- Returns sanitised charges, totalFine, totalMonths.
function Utils.resolveCharges(list)
    local out, fine, months = {}, 0, 0
    if type(list) ~= 'table' then return out, 0, 0 end
    for _, entry in ipairs(list) do
        local def = Utils.getChargeDef(tonumber(entry.id))
        if def then
            local count = Utils.toInt(entry.count, 1, 1, 20)
            out[#out+1] = {
                id = def.id, title = def.title, type = def.type,
                count = count, fine = def.fine * count, months = def.months * count,
            }
            fine = fine + (def.fine * count)
            months = months + (def.months * count)
        end
    end
    return out, fine, months
end

-- Audit trail: DB row + optional Discord webhook.
function Utils.audit(officer, name, action, detail)
    MySQL.insert(
        'INSERT INTO mdt_audit (officer, officer_name, action, detail) VALUES (?, ?, ?, ?)',
        { officer, name, action, detail }
    )
    if Config.Webhook and Config.Webhook ~= '' then
        local payload = {
            username = Config.WebhookName,
            embeds = { {
                title = action,
                description = ('**Officer:** %s\n%s'):format(name or 'Unknown', detail or ''),
                color = 3447003,
                footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
            } },
        }
        PerformHttpRequest(Config.Webhook, function() end, 'POST',
            json.encode(payload), { ['Content-Type'] = 'application/json' })
    end
end

return Utils
