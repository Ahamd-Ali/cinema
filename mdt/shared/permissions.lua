-- ============================================================================
-- Fv_MDT — Permission system ("جميع الصلاحيات")
-- ----------------------------------------------------------------------------
-- Every capability in the MDT is a named permission. Permissions are bundled
-- into groups, groups are assigned to a job+grade. The server ALWAYS re-checks
-- permissions authoritatively (never trusts the NUI), see server/main.lua.
-- ============================================================================

Permissions = {}

-- Master list of every permission flag the resource understands.
Permissions.All = {
    'mdt.open',            -- open the terminal at all
    'profiles.view',       -- view citizen profiles
    'profiles.edit',       -- edit citizen notes / flags
    'records.view',        -- view criminal records
    'records.create',      -- file a charge / arrest report
    'records.expunge',     -- remove/expunge a record (senior)
    'warrants.view',
    'warrants.create',
    'warrants.close',
    'bolo.view',
    'bolo.create',
    'bolo.close',
    'reports.view',
    'reports.create',
    'reports.edit',
    'reports.delete',
    'vehicles.view',       -- registry lookup
    'vehicles.flag',       -- flag stolen / impound
    'dispatch.view',       -- see the call board
    'dispatch.manage',     -- assign / close calls
    'evidence.view',
    'evidence.manage',
    'roster.view',         -- see department roster
    'roster.manage',       -- hire / fire / promote (command)
    'fines.issue',         -- issue a fine
    'jail.issue',          -- send to jail
    'admin.audit',         -- read the audit log
    'admin.penalcode',     -- edit penal code live (highest)
}

-- Permission groups. `'*'` means "all permissions" (full access).
Permissions.Groups = {
    -- Line officer / cadet: everyday policing
    ['officer'] = {
        'mdt.open', 'profiles.view', 'records.view', 'records.create',
        'warrants.view', 'warrants.create', 'bolo.view', 'bolo.create',
        'reports.view', 'reports.create', 'vehicles.view', 'vehicles.flag',
        'dispatch.view', 'evidence.view', 'roster.view',
        'fines.issue', 'jail.issue',
    },
    -- Supervisor / sergeant: officer + editing & dispatch management
    ['supervisor'] = {
        'mdt.open', 'profiles.view', 'profiles.edit', 'records.view',
        'records.create', 'warrants.view', 'warrants.create', 'warrants.close',
        'bolo.view', 'bolo.create', 'bolo.close', 'reports.view',
        'reports.create', 'reports.edit', 'vehicles.view', 'vehicles.flag',
        'dispatch.view', 'dispatch.manage', 'evidence.view', 'evidence.manage',
        'roster.view', 'fines.issue', 'jail.issue',
    },
    -- Command / chief: everything
    ['command'] = { '*' },

    -- EMS: medical read access, own reports, no law-enforcement powers
    ['ems'] = {
        'mdt.open', 'profiles.view', 'reports.view', 'reports.create',
        'dispatch.view', 'roster.view',
    },
    -- DOJ (judges/lawyers): read records/warrants, expunge, close warrants
    ['doj'] = {
        'mdt.open', 'profiles.view', 'records.view', 'records.expunge',
        'warrants.view', 'warrants.close', 'reports.view', 'roster.view',
        'admin.audit',
    },
}

-- Map job -> grade -> group. Grades not listed fall back to `default`.
-- Edit these to match your CFW job grades.
Permissions.JobGrades = {
    ['police'] = {
        default = 'officer',
        [0] = 'officer',      -- Cadet
        [1] = 'officer',      -- Officer
        [2] = 'officer',      -- Senior Officer
        [3] = 'supervisor',   -- Sergeant
        [4] = 'supervisor',   -- Lieutenant
        [5] = 'command',      -- Captain
        [6] = 'command',      -- Chief
    },
    ['sheriff'] = {
        default = 'officer',
        [3] = 'supervisor',
        [4] = 'supervisor',
        [5] = 'command',
        [6] = 'command',
    },
    ['ambulance'] = { default = 'ems' },
    ['doj']       = { default = 'doj' },
}

-- Resolve the permission group for a job+grade.
function Permissions.GetGroup(job, grade)
    local jobMap = Permissions.JobGrades[job]
    if not jobMap then return nil end
    return jobMap[grade] or jobMap.default
end

-- Does (job, grade) have `perm`? Returns boolean.
function Permissions.Has(job, grade, perm)
    local group = Permissions.GetGroup(job, grade)
    if not group then return false end
    local flags = Permissions.Groups[group]
    if not flags then return false end
    for _, f in ipairs(flags) do
        if f == '*' or f == perm then return true end
    end
    return false
end

-- Full flattened permission list for a job+grade (used to send to NUI so the
-- UI can hide controls the user can't use — the server still enforces).
function Permissions.List(job, grade)
    local group = Permissions.GetGroup(job, grade)
    if not group then return {} end
    local flags = Permissions.Groups[group]
    if not flags then return {} end
    if flags[1] == '*' then
        return Permissions.All
    end
    return flags
end

return Permissions
