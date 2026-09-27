-- ============================================================================
-- Fv_MDT — Server action handlers (authoritative permission enforcement)
-- ----------------------------------------------------------------------------
-- Every action here re-derives the caller's job/grade server-side and checks
-- the required permission. The NUI is NEVER trusted for authorization.
-- ============================================================================

-- Build the "actor" (identity of the requesting officer) from the source.
local function getActor(src)
    local can, job = Bridge.CanAccess(src)
    if not can then return nil end
    return {
        src   = src,
        job   = job.name,
        grade = job.grade,
        cid   = Bridge.GetIdentifier(src),
        name  = Bridge.GetName(src),
    }
end

-- Guard: returns actor if allowed, else nil (and logs the denial).
local function guard(src, perm)
    local actor = getActor(src)
    if not actor then return nil end
    if not Permissions.Has(actor.job, actor.grade, perm) then
        print(('[Fv_MDT] DENIED %s (%s:%d) lacks %s'):format(actor.name, actor.job, actor.grade, perm))
        return nil
    end
    return actor
end

-- Expose the guard/actor for the callback transport.
MDT = { getActor = getActor, guard = guard }

-- ============================================================================
-- ACTIONS  — table of { permission, handler(actor, data) -> result }
-- ============================================================================
Actions = {}

-- Bootstrap payload the NUI needs when it opens.
Actions.bootstrap = { perm = 'mdt.open', fn = function(actor)
    return {
        me = {
            name = actor.name, cid = actor.cid,
            job = actor.job, grade = actor.grade,
            group = Permissions.GetGroup(actor.job, actor.grade),
        },
        permissions = Permissions.List(actor.job, actor.grade),
        charges = Config.Charges,
        currency = Config.Currency,
        activeWarrants = DB.GetWarrants('active'),
        activeBolos = DB.GetBolos('active'),
    }
end }

-- -------- profiles --------
Actions.searchProfiles = { perm = 'profiles.view', fn = function(_, d)
    return DB.SearchProfiles(Utils.clean(d.query, 64))
end }

Actions.getProfile = { perm = 'profiles.view', fn = function(_, d)
    return DB.GetProfile(Utils.clean(d.citizenid, 64))
end }

Actions.saveProfile = { perm = 'profiles.edit', fn = function(actor, d)
    local cid = Utils.clean(d.citizenid, 64)
    DB.UpdateProfileNotes(cid, Utils.clean(d.notes, 5000), d.flags, d.is_wanted)
    Utils.audit(actor.cid, actor.name, 'profile.edit', ('Edited profile %s'):format(cid))
    return { ok = true }
end }

-- -------- criminal records / charges --------
Actions.fileRecord = { perm = 'records.create', fn = function(actor, d)
    local cid = Utils.clean(d.citizenid, 64)
    if not cid then return { ok = false, error = 'no_citizen' } end
    local charges, fine, months = Utils.resolveCharges(d.charges)
    if #charges == 0 then return { ok = false, error = 'no_charges' } end

    fine = Utils.toInt(fine, 0, 0, Config.MaxFine)
    local jailMin = Utils.toInt(months, 0, 0, Config.MaxJailMinutes)

    local id = DB.CreateRecord({
        citizenid = cid, charges = charges, fine = fine, jail = jailMin,
        narrative = Utils.clean(d.narrative, 5000),
        officer = actor.cid, officer_name = actor.name,
    })

    -- Apply fine / jail to the target if they're online and we're allowed.
    local targetSrc = Bridge.FindOnline(cid)
    if targetSrc then
        if Config.AutoBillOnCharge and fine > 0 and Permissions.Has(actor.job, actor.grade, 'fines.issue') then
            Bridge.ChargeMoney(targetSrc, fine, 'MDT Fine')
        end
        if jailMin > 0 and Permissions.Has(actor.job, actor.grade, 'jail.issue') then
            Bridge.Jail(targetSrc, jailMin, 'MDT Sentence')
        end
    end

    Utils.audit(actor.cid, actor.name, 'record.create',
        ('Filed record #%s on %s (fine %d, jail %dm)'):format(id, cid, fine, jailMin))
    return { ok = true, id = id, fine = fine, jail = jailMin }
end }

Actions.expungeRecord = { perm = 'records.expunge', fn = function(actor, d)
    DB.ExpungeRecord(Utils.toInt(d.id))
    Utils.audit(actor.cid, actor.name, 'record.expunge', ('Expunged record #%s'):format(d.id))
    return { ok = true }
end }

-- -------- warrants --------
Actions.getWarrants = { perm = 'warrants.view', fn = function(_, d)
    return DB.GetWarrants(d.status == 'closed' and 'closed' or 'active')
end }

Actions.createWarrant = { perm = 'warrants.create', fn = function(actor, d)
    local id = DB.CreateWarrant({
        citizenid = Utils.clean(d.citizenid, 64),
        name = Utils.clean(d.name, 96),
        reason = Utils.clean(d.reason, 2000),
        officer = actor.cid, officer_name = actor.name,
    })
    Utils.audit(actor.cid, actor.name, 'warrant.create', ('Warrant #%s for %s'):format(id, d.name or d.citizenid))
    return { ok = true, id = id }
end }

Actions.closeWarrant = { perm = 'warrants.close', fn = function(actor, d)
    DB.CloseWarrant(Utils.toInt(d.id))
    Utils.audit(actor.cid, actor.name, 'warrant.close', ('Closed warrant #%s'):format(d.id))
    return { ok = true }
end }

-- -------- BOLOs --------
Actions.getBolos = { perm = 'bolo.view', fn = function(_, d)
    return DB.GetBolos(d.status == 'closed' and 'closed' or 'active')
end }

Actions.createBolo = { perm = 'bolo.create', fn = function(actor, d)
    local id = DB.CreateBolo({
        title = Utils.clean(d.title, 128), body = Utils.clean(d.body, 4000),
        plate = Utils.clean(d.plate, 16), image = Utils.clean(d.image, 512),
        officer = actor.cid, officer_name = actor.name,
    })
    Utils.audit(actor.cid, actor.name, 'bolo.create', ('BOLO #%s: %s'):format(id, d.title))
    return { ok = true, id = id }
end }

Actions.closeBolo = { perm = 'bolo.close', fn = function(actor, d)
    DB.CloseBolo(Utils.toInt(d.id))
    Utils.audit(actor.cid, actor.name, 'bolo.close', ('Closed BOLO #%s'):format(d.id))
    return { ok = true }
end }

-- -------- reports --------
Actions.getReports = { perm = 'reports.view', fn = function(_, d)
    return DB.GetReports(Utils.clean(d.query, 64))
end }

Actions.createReport = { perm = 'reports.create', fn = function(actor, d)
    local id = DB.CreateReport({
        title = Utils.clean(d.title, 160), body = Utils.clean(d.body, 20000),
        tags = d.tags, involved = d.involved,
        officer = actor.cid, officer_name = actor.name,
    })
    Utils.audit(actor.cid, actor.name, 'report.create', ('Report #%s: %s'):format(id, d.title))
    return { ok = true, id = id }
end }

Actions.updateReport = { perm = 'reports.edit', fn = function(actor, d)
    DB.UpdateReport({
        id = Utils.toInt(d.id), title = Utils.clean(d.title, 160),
        body = Utils.clean(d.body, 20000), tags = d.tags, involved = d.involved,
    })
    Utils.audit(actor.cid, actor.name, 'report.edit', ('Edited report #%s'):format(d.id))
    return { ok = true }
end }

Actions.deleteReport = { perm = 'reports.delete', fn = function(actor, d)
    DB.DeleteReport(Utils.toInt(d.id))
    Utils.audit(actor.cid, actor.name, 'report.delete', ('Deleted report #%s'):format(d.id))
    return { ok = true }
end }

-- -------- vehicles --------
Actions.lookupVehicle = { perm = 'vehicles.view', fn = function(_, d)
    local plate = Utils.clean((d.plate or ''):upper(), 16)
    return { plate = plate, flag = DB.GetVehicleFlag(plate) }
end }

Actions.flagVehicle = { perm = 'vehicles.flag', fn = function(actor, d)
    DB.SetVehicleFlag({
        plate = Utils.clean((d.plate or ''):upper(), 16),
        flag = ({ stolen=1, impound=1, bolo=1, clean=1 })[d.flag] and d.flag or 'clean',
        note = Utils.clean(d.note, 1000), officer = actor.cid, officer_name = actor.name,
    })
    Utils.audit(actor.cid, actor.name, 'vehicle.flag', ('Plate %s -> %s'):format(d.plate, d.flag))
    return { ok = true }
end }

-- -------- evidence --------
Actions.getEvidence = { perm = 'evidence.view', fn = function(_, d)
    return DB.GetEvidence(Utils.toInt(d.report_id))
end }

Actions.addEvidence = { perm = 'evidence.manage', fn = function(actor, d)
    local id = DB.CreateEvidence({
        report_id = d.report_id and Utils.toInt(d.report_id) or nil,
        label = Utils.clean(d.label, 160), type = Utils.clean(d.type, 48),
        detail = Utils.clean(d.detail, 4000), officer = actor.cid, officer_name = actor.name,
    })
    Utils.audit(actor.cid, actor.name, 'evidence.add', ('Evidence #%s: %s'):format(id, d.label))
    return { ok = true, id = id }
end }

-- -------- roster --------
Actions.getRoster = { perm = 'roster.view', fn = function(actor)
    local list = {}
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local job = Bridge.GetJob(src)
        if job and job.name == actor.job then
            list[#list+1] = {
                name = Bridge.GetName(src), grade = job.grade,
                group = Permissions.GetGroup(job.name, job.grade),
                online = true,
            }
        end
    end
    return list
end }

-- -------- audit log --------
Actions.getAudit = { perm = 'admin.audit', fn = function(_, d)
    return DB.GetAudit(Utils.toInt(d.limit, 100, 1, 500))
end }

-- Sync a player's own profile row when they load (call from your core if wanted)
RegisterNetEvent('fv_mdt:server:syncProfile', function()
    local src = source
    local cid = Bridge.GetIdentifier(src)
    if not cid then return end
    local p = Bridge.GetPlayer(src)
    local ci = p and (p.charinfo or (p.PlayerData and p.PlayerData.charinfo))
    DB.UpsertProfile({
        citizenid = cid,
        firstname = ci and ci.firstname or nil,
        lastname  = ci and ci.lastname or nil,
        dob       = ci and ci.birthdate or nil,
        phone     = ci and ci.phone or nil,
    })
end)
