# Fv_MDT — Police Mobile Data Terminal (CFW Core)

A complete Mobile Data Terminal for FiveM police roleplay, built for the **CFW**
framework core with a full **rank / permission system** ("جميع الصلاحيات").

## Features
- **Citizen profiles** — search, view, officer notes, wanted flag.
- **Criminal records & charges** — penal-code charge picker with live fine/jail
  totals; optional auto-billing and jailing of online suspects.
- **Warrants** — issue, list, close; shown on the suspect's profile.
- **BOLOs** — post/close be-on-the-lookout notices (with plate).
- **Reports** — searchable incident reports, create/edit/delete.
- **Vehicle registry** — plate lookup, flag stolen / impound / BOLO, "scan nearby".
- **Evidence** — attach evidence items to reports.
- **Roster** — on-duty department members and their access level.
- **Audit log** — every action is recorded (DB + optional Discord webhook).

## Permission tiers (edit in `shared/permissions.lua`)
| Group | Who | Access |
|-------|-----|--------|
| `officer` | cadet–senior officer | everyday policing |
| `supervisor` | sergeant / lieutenant | + editing, dispatch, close warrants/BOLOs |
| `command` | captain / chief | **all permissions** (`*`) |
| `ems` | ambulance | profiles + reports (no LEO powers) |
| `doj` | judges / lawyers | records + expunge + close warrants + audit |

Permissions are **always enforced on the server** — the NUI only hides controls
the user can't use; it is never trusted for authorization.

## Install
1. Copy the `mdt/` folder into your `resources/` directory.
2. Import the database schema: run `sql/mdt.sql` (uses **oxmysql**).
3. In `config.lua`, set `Config.Core`/`Config.CoreExport` to your CFW core, and
   list your police jobs in `Config.Jobs`.
4. In `shared/permissions.lua`, map your job **grades** to permission groups.
5. Add `ensure mdt` to your `server.cfg` (after your core and oxmysql).
6. Open with `/mdt` or the `F6` key (re-bindable in FiveM keybind settings).

## Adapting to your CFW core
Every framework-specific call lives in **`shared/bridge.lua`** (get player, job,
identifier, charge money, jail). If your CFW export names differ, change them
there only — the rest of the resource is framework-agnostic.
