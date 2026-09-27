/* ==========================================================================
 * Fv_MDT — NUI application logic
 * ========================================================================== */
const RES = (function () {
    try { return window.GetParentResourceName ? GetParentResourceName() : 'fv_mdt'; }
    catch (e) { return 'fv_mdt'; }
})();

const State = { me: null, perms: [], charges: [], currency: '$' };

/* ---- transport ---- */
async function api(action, data = {}) {
    try {
        const res = await fetch(`https://${RES}/action`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ action, data }),
        });
        return await res.json();
    } catch (e) { return { ok: false, error: 'net' }; }
}
async function nui(cb, data = {}) {
    try {
        const res = await fetch(`https://${RES}/${cb}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await res.json();
    } catch (e) { return {}; }
}

/* ---- helpers ---- */
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => State.currency + Number(n || 0).toLocaleString();
const has = (perm) => State.perms.includes(perm);

function toast(msg, kind = 'ok') {
    const t = $('#toast');
    t.textContent = msg;
    t.className = `toast ${kind}`;
    setTimeout(() => t.classList.add('hidden'), 2600);
}

/* ---- open / close ---- */
window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.type === 'open') openApp();
    else if (d.type === 'close') closeApp();
    else if (d.type === 'broadcast') handleBroadcast(d);
});
document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && !$('#app').classList.contains('hidden')) doClose();
});

async function openApp() {
    $('#app').classList.remove('hidden');
    const boot = await api('bootstrap');
    if (!boot || boot.ok === false) { toast('Failed to load MDT', 'error'); return; }
    State.me = boot.me;
    State.perms = boot.permissions || [];
    State.charges = boot.charges || [];
    State.currency = boot.currency || '$';
    applyPermissions();
    renderMe();
    renderDashboard(boot);
    switchTab('dashboard');
}
function closeApp() { $('#app').classList.add('hidden'); }
async function doClose() { await nui('close'); closeApp(); }

/* ---- permissions: hide controls the user can't use ---- */
function applyPermissions() {
    $$('[data-perm]').forEach(el => {
        el.classList.toggle('no-perm', !has(el.dataset.perm));
    });
}
function renderMe() {
    $('#meName').textContent = State.me.name || '—';
    $('#meRank').textContent = `${(State.me.job || '').toUpperCase()} · ${State.me.group || ''} (grade ${State.me.grade})`;
    $('#dashGroup').textContent = State.me.group || '—';
}

/* ---- tabs ---- */
function switchTab(name) {
    $$('.nav-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === name));
    $$('.tab').forEach(t => t.classList.toggle('active', t.id === `tab-${name}`));
    const btn = $(`.nav-btn[data-tab="${name}"]`);
    $('#pageTitle').textContent = btn ? btn.textContent.trim() : name;
    loaders[name] && loaders[name]();
}
$$('.nav-btn').forEach(b => b.addEventListener('click', () => switchTab(b.dataset.tab)));
$('#btnClose').addEventListener('click', doClose);

/* ==========================================================================
 * DASHBOARD
 * ========================================================================== */
function renderDashboard(boot) {
    const w = boot.activeWarrants || [];
    const b = boot.activeBolos || [];
    $('#dashWarrants').textContent = w.length;
    $('#dashBolos').textContent = b.length;
    $('#dashWarrantList').innerHTML = w.slice(0, 6).map(x =>
        `<div class="row"><div><div class="r-title">${esc(x.name || x.citizenid)}</div>
        <div class="r-sub">${esc(x.reason || '')}</div></div></div>`).join('') || '<div class="empty">None</div>';
    $('#dashBoloList').innerHTML = b.slice(0, 6).map(x =>
        `<div class="row"><div><div class="r-title">${esc(x.title)}</div>
        <div class="r-sub">${esc(x.plate || '')}</div></div></div>`).join('') || '<div class="empty">None</div>';
}

/* ==========================================================================
 * PROFILES
 * ========================================================================== */
async function searchProfiles() {
    const q = $('#profSearch').value.trim();
    const rows = await api('searchProfiles', { query: q });
    $('#profResults').innerHTML = (rows || []).map(r => `
        <div class="row" data-cid="${esc(r.citizenid)}">
            <div><div class="r-title">${esc(r.firstname || '')} ${esc(r.lastname || '')}</div>
            <div class="r-sub">${esc(r.citizenid)}</div></div>
            ${r.is_wanted ? '<span class="badge wanted">WANTED</span>' : ''}
        </div>`).join('') || '<div class="empty">No results</div>';
    $$('#profResults .row').forEach(el =>
        el.addEventListener('click', () => openProfile(el.dataset.cid)));
}
async function openProfile(cid) {
    const p = await api('getProfile', { citizenid: cid });
    if (!p) { $('#profDetail').innerHTML = '<div class="empty">Not found</div>'; return; }
    const recs = (p.records || []).map(r => `
        <div class="row"><div>
            <div class="r-title">${(r.charges || []).map(c =>
                `<span class="badge ${c.type}">${esc(c.title)}${c.count > 1 ? ' ×' + c.count : ''}</span>`).join(' ')}</div>
            <div class="r-sub">${esc(r.narrative || '')} — ${esc(r.officer_name || '')} · ${esc((r.created_at || '').slice(0, 16))}</div>
        </div>
        <div>${money(r.fine)} · ${r.jail}m
            ${has('records.expunge') ? `<button class="btn btn-ghost" data-expunge="${r.id}">Expunge</button>` : ''}
        </div></div>`).join('') || '<div class="empty">No records</div>';
    const warr = (p.warrants || []).filter(w => w.status === 'active').map(w =>
        `<div class="row"><div class="r-title">${esc(w.reason || '')}</div><div class="r-sub">${esc(w.officer_name || '')}</div></div>`
    ).join('') || '<div class="empty">No active warrants</div>';

    $('#profDetail').innerHTML = `
        <div style="display:flex;justify-content:space-between;align-items:center">
          <h3>${esc(p.firstname || '')} ${esc(p.lastname || '')} ${p.is_wanted ? '<span class="badge wanted">WANTED</span>' : ''}</h3>
          <div>
            ${has('records.create') ? `<button class="btn" id="chargeBtn">File Charge</button>` : ''}
            ${has('warrants.create') ? `<button class="btn btn-warn" id="warrantBtn">Warrant</button>` : ''}
          </div>
        </div>
        <div class="kv"><b>Citizen ID</b> ${esc(p.citizenid)}</div>
        <div class="kv"><b>Date of Birth</b> ${esc(p.dob || '—')}</div>
        <div class="kv"><b>Phone</b> ${esc(p.phone || '—')}</div>
        <div class="section-title">Officer Notes</div>
        <textarea class="input" id="profNotes" ${has('profiles.edit') ? '' : 'readonly'}>${esc(p.notes || '')}</textarea>
        ${has('profiles.edit') ? `<div style="margin-top:8px">
            <label><input type="checkbox" id="profWanted" ${p.is_wanted ? 'checked' : ''}> Flag as wanted</label>
            <button class="btn" id="saveNotes" style="float:right">Save</button></div>` : ''}
        <div class="section-title">Active Warrants</div>${warr}
        <div class="section-title">Criminal Record</div>${recs}`;

    if (has('profiles.edit')) $('#saveNotes').addEventListener('click', async () => {
        const r = await api('saveProfile', {
            citizenid: cid, notes: $('#profNotes').value,
            is_wanted: $('#profWanted').checked, flags: [],
        });
        toast(r.ok ? 'Profile saved' : 'Save failed', r.ok ? 'ok' : 'error');
    });
    if (has('records.create')) $('#chargeBtn').addEventListener('click', () => openChargeModal(p));
    if (has('warrants.create')) $('#warrantBtn').addEventListener('click', () => openWarrantModal(p));
    $$('#profDetail [data-expunge]').forEach(b => b.addEventListener('click', async (e) => {
        e.stopPropagation();
        const r = await api('expungeRecord', { id: b.dataset.expunge });
        if (r.ok) { toast('Record expunged'); openProfile(cid); }
    }));
}
$('#profSearchBtn').addEventListener('click', searchProfiles);
$('#profSearch').addEventListener('keyup', e => { if (e.key === 'Enter') searchProfiles(); });

/* ---- charge modal ---- */
function openChargeModal(profile) {
    const rows = State.charges.map(c => `
        <div class="charge-item">
            <span><span class="badge ${c.type}">${c.type}</span> ${esc(c.title)}
                <small style="color:var(--muted)">(${money(c.fine)} · ${c.months}m)</small></span>
            <input type="number" min="0" max="20" value="0" data-charge="${c.id}"
                data-fine="${c.fine}" data-months="${c.months}">
        </div>`).join('');
    openModal(`Charge ${esc(profile.firstname || '')} ${esc(profile.lastname || '')}`, `
        <div class="charge-grid">${rows}</div>
        <div class="totals"><span>Fine: <span id="tFine">${money(0)}</span></span>
            <span>Jail: <span id="tJail">0</span>m</span></div>
        <div class="field"><label>Narrative</label><textarea class="input" id="chargeNarr"></textarea></div>
    `, [
        { label: 'Cancel', cls: 'btn-ghost', fn: closeModal },
        { label: 'File Charges', cls: '', fn: async () => {
            const charges = $$('#modalBody [data-charge]').filter(i => +i.value > 0)
                .map(i => ({ id: +i.dataset.charge, count: +i.value }));
            if (!charges.length) { toast('Select at least one charge', 'error'); return; }
            const r = await api('fileRecord', {
                citizenid: profile.citizenid, charges,
                narrative: $('#chargeNarr').value,
            });
            if (r.ok) { toast(`Filed — ${money(r.fine)} / ${r.jail}m`); closeModal(); openProfile(profile.citizenid); }
            else toast('Failed: ' + (r.error || ''), 'error');
        } },
    ]);
    const recompute = () => {
        let f = 0, m = 0;
        $$('#modalBody [data-charge]').forEach(i => {
            const n = +i.value || 0; f += n * +i.dataset.fine; m += n * +i.dataset.months;
        });
        $('#tFine').textContent = money(f); $('#tJail').textContent = m;
    };
    $$('#modalBody [data-charge]').forEach(i => i.addEventListener('input', recompute));
}
function openWarrantModal(profile) {
    openModal(`New Warrant — ${esc(profile.firstname || '')} ${esc(profile.lastname || '')}`, `
        <div class="field"><label>Reason</label><textarea class="input" id="wReason"></textarea></div>
    `, [
        { label: 'Cancel', cls: 'btn-ghost', fn: closeModal },
        { label: 'Issue Warrant', cls: 'btn-warn', fn: async () => {
            const r = await api('createWarrant', {
                citizenid: profile.citizenid,
                name: `${profile.firstname || ''} ${profile.lastname || ''}`.trim(),
                reason: $('#wReason').value,
            });
            if (r.ok) { toast('Warrant issued'); closeModal(); }
            else toast('Failed', 'error');
        } },
    ]);
}

/* ==========================================================================
 * WARRANTS
 * ========================================================================== */
async function loadWarrants() {
    const status = $('#warrantFilter').value;
    const rows = await api('getWarrants', { status });
    $('#warrantList').innerHTML = (rows || []).map(w => `
        <div class="row"><div>
            <div class="r-title">${esc(w.name || w.citizenid)}</div>
            <div class="r-sub">${esc(w.reason || '')} — ${esc(w.officer_name || '')} · ${esc((w.created_at || '').slice(0, 16))}</div>
        </div>
        ${w.status === 'active' && has('warrants.close') ? `<button class="btn btn-ghost" data-close="${w.id}">Close</button>` : ''}
        </div>`).join('') || '<div class="empty">No warrants</div>';
    $$('#warrantList [data-close]').forEach(b => b.addEventListener('click', async () => {
        const r = await api('closeWarrant', { id: b.dataset.close });
        if (r.ok) { toast('Warrant closed'); loadWarrants(); }
    }));
}
$('#warrantFilter').addEventListener('change', loadWarrants);
$('#newWarrantBtn').addEventListener('click', () => openModal('New Warrant', `
    <div class="field"><label>Citizen ID</label><input class="input" id="wCid"></div>
    <div class="field"><label>Name</label><input class="input" id="wName"></div>
    <div class="field"><label>Reason</label><textarea class="input" id="wReason2"></textarea></div>
`, [
    { label: 'Cancel', cls: 'btn-ghost', fn: closeModal },
    { label: 'Issue', cls: 'btn-warn', fn: async () => {
        const r = await api('createWarrant', {
            citizenid: $('#wCid').value.trim(), name: $('#wName').value.trim(), reason: $('#wReason2').value,
        });
        if (r.ok) { toast('Warrant issued'); closeModal(); loadWarrants(); } else toast('Failed', 'error');
    } },
]));

/* ==========================================================================
 * BOLOS
 * ========================================================================== */
async function loadBolos() {
    const rows = await api('getBolos', { status: $('#boloFilter').value });
    $('#boloList').innerHTML = (rows || []).map(b => `
        <div class="card" style="width:340px">
            <div style="display:flex;justify-content:space-between;align-items:center">
                <h3>${esc(b.title)}</h3>
                ${b.status === 'active' && has('bolo.close') ? `<button class="btn btn-ghost" data-close="${b.id}">Close</button>` : ''}
            </div>
            ${b.plate ? `<div class="kv"><b>Plate</b> ${esc(b.plate)}</div>` : ''}
            <div class="r-sub">${esc(b.body || '')}</div>
            <div class="r-sub" style="margin-top:8px">${esc(b.officer_name || '')} · ${esc((b.created_at || '').slice(0, 16))}</div>
        </div>`).join('') || '<div class="empty">No BOLOs</div>';
    $$('#boloList [data-close]').forEach(bt => bt.addEventListener('click', async () => {
        const r = await api('closeBolo', { id: bt.dataset.close });
        if (r.ok) { toast('BOLO closed'); loadBolos(); }
    }));
}
$('#boloFilter').addEventListener('change', loadBolos);
$('#newBoloBtn').addEventListener('click', () => openModal('New BOLO', `
    <div class="field"><label>Title</label><input class="input" id="bTitle"></div>
    <div class="field"><label>Plate (optional)</label><input class="input" id="bPlate" maxlength="8"></div>
    <div class="field"><label>Details</label><textarea class="input" id="bBody"></textarea></div>
`, [
    { label: 'Cancel', cls: 'btn-ghost', fn: closeModal },
    { label: 'Post BOLO', cls: 'btn-danger', fn: async () => {
        const r = await api('createBolo', {
            title: $('#bTitle').value.trim(), plate: $('#bPlate').value.trim().toUpperCase(), body: $('#bBody').value,
        });
        if (r.ok) { toast('BOLO posted'); closeModal(); loadBolos(); } else toast('Failed', 'error');
    } },
]));

/* ==========================================================================
 * REPORTS
 * ========================================================================== */
async function loadReports() {
    const rows = await api('getReports', { query: $('#reportSearch').value.trim() });
    $('#reportList').innerHTML = (rows || []).map(r => `
        <div class="row" data-report='${esc(JSON.stringify({ id: r.id, title: r.title, body: r.body }))}'>
            <div><div class="r-title">${esc(r.title)}</div>
            <div class="r-sub">${esc(r.officer_name || '')} · ${esc((r.created_at || '').slice(0, 16))}</div></div>
            ${has('reports.delete') ? `<button class="btn btn-ghost" data-del="${r.id}">Delete</button>` : ''}
        </div>`).join('') || '<div class="empty">No reports</div>';
    $$('#reportList .row').forEach(el => el.addEventListener('click', () => {
        const rep = JSON.parse(el.dataset.report);
        openModal(esc(rep.title), `<div style="white-space:pre-wrap">${esc(rep.body || '')}</div>`,
            [{ label: 'Close', cls: 'btn-ghost', fn: closeModal }]);
    }));
    $$('#reportList [data-del]').forEach(b => b.addEventListener('click', async (e) => {
        e.stopPropagation();
        const r = await api('deleteReport', { id: b.dataset.del });
        if (r.ok) { toast('Report deleted'); loadReports(); }
    }));
}
$('#reportSearchBtn').addEventListener('click', loadReports);
$('#reportSearch').addEventListener('keyup', e => { if (e.key === 'Enter') loadReports(); });
$('#newReportBtn').addEventListener('click', () => openModal('New Report', `
    <div class="field"><label>Title</label><input class="input" id="rTitle"></div>
    <div class="field"><label>Body</label><textarea class="input" id="rBody" style="min-height:200px"></textarea></div>
`, [
    { label: 'Cancel', cls: 'btn-ghost', fn: closeModal },
    { label: 'Save Report', cls: '', fn: async () => {
        const r = await api('createReport', { title: $('#rTitle').value.trim(), body: $('#rBody').value });
        if (r.ok) { toast('Report saved'); closeModal(); loadReports(); } else toast('Failed', 'error');
    } },
]));

/* ==========================================================================
 * VEHICLES
 * ========================================================================== */
async function lookupPlate(plate) {
    plate = (plate || $('#plateInput').value).trim().toUpperCase();
    if (!plate) return;
    $('#plateInput').value = plate;
    const res = await api('lookupVehicle', { plate });
    const f = res && res.flag;
    $('#vehicleResult').innerHTML = `
        <div style="display:flex;justify-content:space-between;align-items:center">
            <h3>Plate ${esc(plate)}</h3>
            <span class="badge ${f ? f.flag : 'clean'}">${(f ? f.flag : 'clean').toUpperCase()}</span>
        </div>
        ${f ? `<div class="kv"><b>Note</b> ${esc(f.note || '—')}</div>
               <div class="kv"><b>Flagged by</b> ${esc(f.officer_name || '—')}</div>` : '<div class="r-sub">No flags on record.</div>'}
        ${has('vehicles.flag') ? `
        <div class="section-title">Set Flag</div>
        <div class="toolbar">
            <select class="input" id="vFlag">
                <option value="clean">Clean</option><option value="stolen">Stolen</option>
                <option value="impound">Impound</option><option value="bolo">BOLO</option>
            </select>
            <input class="input" id="vNote" placeholder="Note…">
            <button class="btn" id="vSet">Apply</button>
        </div>` : ''}`;
    if (has('vehicles.flag')) $('#vSet').addEventListener('click', async () => {
        const r = await api('flagVehicle', { plate, flag: $('#vFlag').value, note: $('#vNote').value });
        if (r.ok) { toast('Flag updated'); lookupPlate(plate); }
    });
}
$('#plateLookupBtn').addEventListener('click', () => lookupPlate());
$('#plateInput').addEventListener('keyup', e => { if (e.key === 'Enter') lookupPlate(); });
$('#plateScanBtn').addEventListener('click', async () => {
    const r = await nui('scanPlate');
    if (r && r.ok && r.plate) lookupPlate(r.plate);
    else toast('No vehicle nearby', 'error');
});

/* ==========================================================================
 * ROSTER / AUDIT
 * ========================================================================== */
async function loadRoster() {
    const rows = await api('getRoster');
    $('#rosterList').innerHTML = (rows || []).map(r => `
        <div class="row"><div><div class="r-title">${esc(r.name)}</div>
        <div class="r-sub">${esc(r.group)} · grade ${r.grade}</div></div>
        <span class="badge I">ONLINE</span></div>`).join('') || '<div class="empty">No one on duty</div>';
}
async function loadAudit() {
    const rows = await api('getAudit', { limit: 150 });
    $('#auditList').innerHTML = (rows || []).map(a => `
        <div class="row"><div><div class="r-title">${esc(a.action)}</div>
        <div class="r-sub">${esc(a.detail || '')}</div></div>
        <div class="r-sub">${esc(a.officer_name || '')}<br>${esc((a.created_at || '').slice(0, 16))}</div></div>`
    ).join('') || '<div class="empty">Empty</div>';
}

/* ==========================================================================
 * MODAL + broadcast
 * ========================================================================== */
function openModal(title, body, buttons = []) {
    $('#modalTitle').innerHTML = title;
    $('#modalBody').innerHTML = body;
    const foot = $('#modalFoot'); foot.innerHTML = '';
    buttons.forEach(b => {
        const el = document.createElement('button');
        el.className = `btn ${b.cls || ''}`; el.textContent = b.label;
        el.addEventListener('click', b.fn); foot.appendChild(el);
    });
    $('#modal').classList.remove('hidden');
}
function closeModal() { $('#modal').classList.add('hidden'); }
$('#modalClose').addEventListener('click', closeModal);

function handleBroadcast(d) {
    if (d.kind === 'bolo') toast('New BOLO posted');
    else if (d.kind === 'warrant') toast('New warrant issued');
}

/* per-tab loaders */
const loaders = {
    dashboard: null,
    profiles: null,
    warrants: loadWarrants,
    bolos: loadBolos,
    reports: loadReports,
    vehicles: null,
    roster: loadRoster,
    audit: loadAudit,
};
