-- ============================================================================
-- Fv_MDT — Data access layer (oxmysql). All queries are parameterised.
-- ============================================================================

DB = {}

local function decode(s, fallback)
    if not s or s == '' then return fallback end
    local ok, v = pcall(json.decode, s)
    if ok and v ~= nil then return v end
    return fallback
end

-- ---------------------------------------------------------------- PROFILES ---
function DB.SearchProfiles(query)
    local like = '%' .. (query or '') .. '%'
    local rows = MySQL.query.await([[
        SELECT citizenid, firstname, lastname, dob, phone, is_wanted
        FROM mdt_profiles
        WHERE citizenid LIKE ? OR firstname LIKE ? OR lastname LIKE ? OR phone LIKE ?
        ORDER BY lastname ASC LIMIT 50
    ]], { like, like, like, like })
    return rows or {}
end

function DB.GetProfile(citizenid)
    local row = MySQL.single.await(
        'SELECT * FROM mdt_profiles WHERE citizenid = ?', { citizenid })
    if not row then return nil end
    row.flags = decode(row.flags, {})
    row.records  = DB.GetRecords(citizenid)
    row.warrants = DB.GetWarrantsFor(citizenid)
    return row
end

function DB.UpsertProfile(p)
    MySQL.insert.await([[
        INSERT INTO mdt_profiles (citizenid, firstname, lastname, dob, phone, image)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE firstname=VALUES(firstname), lastname=VALUES(lastname),
            dob=VALUES(dob), phone=VALUES(phone)
    ]], { p.citizenid, p.firstname, p.lastname, p.dob, p.phone, p.image })
end

function DB.UpdateProfileNotes(citizenid, notes, flags, isWanted)
    MySQL.update.await([[
        UPDATE mdt_profiles SET notes = ?, flags = ?, is_wanted = ? WHERE citizenid = ?
    ]], { notes, json.encode(flags or {}), isWanted and 1 or 0, citizenid })
end

-- ----------------------------------------------------------------- RECORDS ---
function DB.GetRecords(citizenid)
    local rows = MySQL.query.await(
        'SELECT * FROM mdt_records WHERE citizenid = ? AND expunged = 0 ORDER BY created_at DESC',
        { citizenid }) or {}
    for _, r in ipairs(rows) do r.charges = decode(r.charges, {}) end
    return rows
end

function DB.CreateRecord(r)
    return MySQL.insert.await([[
        INSERT INTO mdt_records (citizenid, charges, fine, jail, narrative, officer, officer_name)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { r.citizenid, json.encode(r.charges), r.fine, r.jail, r.narrative, r.officer, r.officer_name })
end

function DB.ExpungeRecord(id)
    MySQL.update.await('UPDATE mdt_records SET expunged = 1 WHERE id = ?', { id })
end

-- ---------------------------------------------------------------- WARRANTS ---
function DB.GetWarrants(status)
    local rows = MySQL.query.await(
        'SELECT * FROM mdt_warrants WHERE status = ? ORDER BY created_at DESC', { status or 'active' })
    return rows or {}
end

function DB.GetWarrantsFor(citizenid)
    local rows = MySQL.query.await(
        'SELECT * FROM mdt_warrants WHERE citizenid = ? ORDER BY created_at DESC', { citizenid })
    return rows or {}
end

function DB.CreateWarrant(w)
    return MySQL.insert.await([[
        INSERT INTO mdt_warrants (citizenid, name, reason, officer, officer_name)
        VALUES (?, ?, ?, ?, ?)
    ]], { w.citizenid, w.name, w.reason, w.officer, w.officer_name })
end

function DB.CloseWarrant(id)
    MySQL.update.await(
        "UPDATE mdt_warrants SET status = 'closed', closed_at = NOW() WHERE id = ?", { id })
end

-- ------------------------------------------------------------------- BOLOS ---
function DB.GetBolos(status)
    local rows = MySQL.query.await(
        'SELECT * FROM mdt_bolos WHERE status = ? ORDER BY created_at DESC', { status or 'active' })
    return rows or {}
end

function DB.CreateBolo(b)
    return MySQL.insert.await([[
        INSERT INTO mdt_bolos (title, body, plate, image, officer, officer_name)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { b.title, b.body, b.plate, b.image, b.officer, b.officer_name })
end

function DB.CloseBolo(id)
    MySQL.update.await("UPDATE mdt_bolos SET status = 'closed' WHERE id = ?", { id })
end

-- ----------------------------------------------------------------- REPORTS ---
function DB.GetReports(query)
    local like = '%' .. (query or '') .. '%'
    local rows = MySQL.query.await([[
        SELECT * FROM mdt_reports WHERE title LIKE ? OR body LIKE ?
        ORDER BY created_at DESC LIMIT 50
    ]], { like, like }) or {}
    for _, r in ipairs(rows) do
        r.tags = decode(r.tags, {})
        r.involved = decode(r.involved, {})
    end
    return rows
end

function DB.CreateReport(r)
    return MySQL.insert.await([[
        INSERT INTO mdt_reports (title, body, tags, involved, officer, officer_name)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { r.title, r.body, json.encode(r.tags or {}), json.encode(r.involved or {}),
          r.officer, r.officer_name })
end

function DB.UpdateReport(r)
    MySQL.update.await([[
        UPDATE mdt_reports SET title = ?, body = ?, tags = ?, involved = ? WHERE id = ?
    ]], { r.title, r.body, json.encode(r.tags or {}), json.encode(r.involved or {}), r.id })
end

function DB.DeleteReport(id)
    MySQL.update.await('DELETE FROM mdt_reports WHERE id = ?', { id })
end

-- ---------------------------------------------------------------- VEHICLES ---
function DB.GetVehicleFlag(plate)
    return MySQL.single.await('SELECT * FROM mdt_vehicle_flags WHERE plate = ?', { plate })
end

function DB.SetVehicleFlag(v)
    MySQL.insert.await([[
        INSERT INTO mdt_vehicle_flags (plate, flag, note, officer, officer_name)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE flag=VALUES(flag), note=VALUES(note),
            officer=VALUES(officer), officer_name=VALUES(officer_name)
    ]], { v.plate, v.flag, v.note, v.officer, v.officer_name })
end

-- ---------------------------------------------------------------- EVIDENCE ---
function DB.GetEvidence(reportId)
    return MySQL.query.await(
        'SELECT * FROM mdt_evidence WHERE report_id = ? ORDER BY created_at DESC', { reportId }) or {}
end

function DB.CreateEvidence(e)
    return MySQL.insert.await([[
        INSERT INTO mdt_evidence (report_id, label, type, detail, officer, officer_name)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { e.report_id, e.label, e.type, e.detail, e.officer, e.officer_name })
end

-- ------------------------------------------------------------------- AUDIT ---
function DB.GetAudit(limit)
    return MySQL.query.await(
        'SELECT * FROM mdt_audit ORDER BY created_at DESC LIMIT ?', { limit or 100 }) or {}
end

return DB
