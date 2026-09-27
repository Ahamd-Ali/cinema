Config = {}

-- ============================================================================
-- CORE / FRAMEWORK
-- ----------------------------------------------------------------------------
-- The name of your CFW core resource. The bridge (shared/bridge.lua) resolves
-- the framework object from this. If your CFW export names differ, edit the
-- bridge — everything else in the resource goes through it.
-- ============================================================================
Config.Core          = 'cfw-core'      -- resource name of your CFW core
Config.CoreExport    = 'getCore'       -- export used to fetch the core object
Config.Locale        = 'ar'            -- 'ar' or 'en' (UI labels come from html)

-- ============================================================================
-- ACCESS
-- ----------------------------------------------------------------------------
-- Jobs that are allowed to open the MDT at all. Per-job the actual capabilities
-- are decided by grade -> permission group (see shared/permissions.lua).
-- ============================================================================
Config.Jobs = {
    ['police'] = { label = 'LSPD',  type = 'leo' },
    ['sheriff']= { label = 'BCSO',  type = 'leo' },
    ['ambulance'] = { label = 'EMS', type = 'ems' },
    ['doj']    = { label = 'DOJ',   type = 'doj' }, -- judges / lawyers (read-mostly)
}

-- Command + key to open the MDT
Config.OpenCommand   = 'mdt'
Config.OpenKeybind   = 'F6'            -- registered as a keymapping (user re-bindable)

-- Item required in inventory to open (set to false to disable the item check)
Config.RequireItem   = false           -- e.g. 'tablet'

-- Distance (m) another player must be within to be added to a report/charge
Config.InteractDistance = 5.0

-- ============================================================================
-- FINE / CHARGE SETTINGS
-- ============================================================================
Config.Currency      = '$'
Config.MaxFine       = 250000          -- safety cap on a single fine
Config.MaxJailMinutes= 240             -- safety cap on jail time per charge set
Config.AutoBillOnCharge = true         -- send fine to player's bank via core

-- ============================================================================
-- DISPATCH
-- ============================================================================
Config.Dispatch = {
    autoAssignCallSign = true,         -- generate call signs like "1-ADAM-12"
    maxActiveCalls     = 100,
    blipSprite         = 60,
    blipColor          = 1,
}

-- ============================================================================
-- LOGGING (Discord webhook — leave empty to disable)
-- ============================================================================
Config.Webhook = ''                    -- Discord webhook URL for audit log
Config.WebhookName = 'Fv_MDT'

-- ============================================================================
-- CHARGE / PENAL CODE
-- Add or edit charges here. `type`: F=Felony, M=Misdemeanor, I=Infraction.
-- ============================================================================
Config.Charges = {
    { id = 1,  title = 'Speeding',                type = 'I', fine = 350,   months = 0,  points = 1 },
    { id = 2,  title = 'Reckless Driving',        type = 'M', fine = 1200,  months = 1,  points = 3 },
    { id = 3,  title = 'Driving Without License', type = 'M', fine = 800,   months = 0,  points = 2 },
    { id = 4,  title = 'Evading Police',          type = 'F', fine = 5000,  months = 10, points = 6 },
    { id = 5,  title = 'Assault',                 type = 'M', fine = 2500,  months = 5,  points = 4 },
    { id = 6,  title = 'Aggravated Assault',      type = 'F', fine = 6000,  months = 15, points = 7 },
    { id = 7,  title = 'Armed Robbery',           type = 'F', fine = 15000, months = 30, points = 10 },
    { id = 8,  title = 'Grand Theft Auto',        type = 'F', fine = 10000, months = 20, points = 8 },
    { id = 9,  title = 'Possession (Class 1)',    type = 'M', fine = 1500,  months = 3,  points = 3 },
    { id = 10, title = 'Drug Trafficking',        type = 'F', fine = 20000, months = 40, points = 10 },
    { id = 11, title = 'Murder (1st Degree)',     type = 'F', fine = 50000, months = 120,points = 15 },
    { id = 12, title = 'Kidnapping',              type = 'F', fine = 18000, months = 35, points = 9 },
    { id = 13, title = 'Resisting Arrest',        type = 'M', fine = 1000,  months = 2,  points = 2 },
    { id = 14, title = 'Illegal Firearm',         type = 'F', fine = 8000,  months = 18, points = 6 },
    { id = 15, title = 'Public Intoxication',     type = 'I', fine = 400,   months = 0,  points = 1 },
}

return Config
