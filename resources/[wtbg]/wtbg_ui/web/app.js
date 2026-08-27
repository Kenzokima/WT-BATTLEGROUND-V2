const app = document.getElementById('app');
const lobby = document.getElementById('lobby');
const menu = document.getElementById('menu');
const profile = document.getElementById('profile');
const invite = document.getElementById('invite');
const hud = document.getElementById('hud');
const result = document.getElementById('result');
const killfeed = document.getElementById('killfeed');
const toasts = document.getElementById('toasts');
const partySlots = document.getElementById('party-slots');
const squadSlots = document.getElementById('squad-slots');
const squadPanel = document.getElementById('squad-panel');
const vitals = document.getElementById('vitals');
let invitePartyId = null;
let vitalsAllowed = false;

const downed = document.getElementById('downed');
const prompt = document.getElementById('prompt');
const promptBar = document.getElementById('prompt-bar');
const promptText = document.getElementById('prompt-text');
const inventory = document.getElementById('inventory');
const heal = document.getElementById('heal');
const healBar = document.getElementById('heal-bar');
const hudKeys = document.getElementById('hud-keys');
const dropHud = document.getElementById('drop');
const specPanel = document.getElementById('spec');
let specTarget = null;
let bleedTimer = null;
let healTimer = null;
let bagId = null;
let lastInv = null;
let lastVicinity = [];
let lastBag = null;
let lastSquad = null;
const dropMembers = {};

function stopHeal() {
    if (healTimer) {
        clearInterval(healTimer);
        healTimer = null;
    }
    show(heal, false);
    healBar.style.animation = 'none';
}

function startHeal(label, ms) {
    stopHeal();
    const total = Math.max(200, Number(ms) || 0);
    let left = total;
    document.getElementById('heal-text').textContent = label || 'USING';
    document.getElementById('heal-time').textContent = `${(left / 1000).toFixed(1)}s`;
    show(heal, true);
    healBar.style.animation = 'none';
    void healBar.offsetWidth;
    healBar.style.animation = `fill ${total}ms linear forwards`;
    healTimer = setInterval(() => {
        left -= 100;
        if (left <= 0) {
            document.getElementById('heal-time').textContent = '0.0s';
            stopHeal();
            return;
        }
        document.getElementById('heal-time').textContent = `${(left / 1000).toFixed(1)}s`;
    }, 100);
}

function slotLabel(slot) {
    return slot && slot.label ? slot.label : 'Empty';
}

function ammoFor(inv, type) {
    if (!inv || !inv.ammo) return 0;
    return inv.ammo[type] || 0;
}

function cardRow(row) {
    const item = document.createElement('li');
    if (row.rarity) {
        item.classList.add(`rarity-${row.rarity}`);
    }
    const name = document.createElement('span');
    name.textContent = row.amount ? `${row.label}  x${row.amount}` : row.label;
    item.appendChild(name);
    (row.actions || []).forEach((act) => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.textContent = act.label;
        btn.addEventListener('click', (event) => {
            event.stopPropagation();
            act.run();
        });
        item.appendChild(btn);
    });
    item.addEventListener('contextmenu', (event) => {
        event.preventDefault();
        const acts = row.actions || [];
        if (acts.length) {
            acts[0].run();
        }
    });
    return item;
}

function fillCards(el, rows) {
    el.innerHTML = '';
    if (!rows.length) {
        const empty = document.createElement('li');
        empty.className = 'empty';
        empty.textContent = 'Empty';
        el.appendChild(empty);
        return;
    }
    rows.forEach((row) => el.appendChild(cardRow(row)));
}

function renderInventory(data) {
    lastInv = data || null;
    const ammoEl = document.getElementById('inv-ammo');
    const healEl = document.getElementById('inv-heal');
    const throwEl = document.getElementById('inv-throw');
    if (!data) {
        document.getElementById('inv-primary').textContent = 'Empty';
        document.getElementById('inv-secondary').textContent = 'Empty';
        document.getElementById('inv-sidearm').textContent = 'Empty';
        document.getElementById('eq-primary-ammo').textContent = '';
        document.getElementById('eq-secondary-ammo').textContent = '';
        document.getElementById('eq-sidearm-ammo').textContent = '';
        document.getElementById('inv-armor').textContent = '0 / 100';
        fillCards(ammoEl, []);
        fillCards(healEl, []);
        fillCards(throwEl, []);
        return;
    }
    document.getElementById('inv-primary').textContent = slotLabel(data.primary);
    document.getElementById('inv-secondary').textContent = slotLabel(data.secondary);
    document.getElementById('inv-sidearm').textContent = slotLabel(data.sidearm);
    document.getElementById('eq-primary-ammo').textContent = data.primary ? String(ammoFor(data, data.primary.ammoType || 'rifle')) : '';
    document.getElementById('eq-secondary-ammo').textContent = data.secondary ? String(ammoFor(data, data.secondary.ammoType || 'smg')) : '';
    document.getElementById('eq-sidearm-ammo').textContent = data.sidearm ? String(ammoFor(data, data.sidearm.ammoType || 'pistol')) : '';
    document.getElementById('inv-armor').textContent = `${data.armor ?? 0} / 100`;
    const ammo = data.ammo || {};
    fillCards(ammoEl, [
        { label: 'Rifle Ammo', key: 'rifle', amount: ammo.rifle || 0, dropAmount: Math.min(30, ammo.rifle || 0) },
        { label: 'SMG Ammo', key: 'smg', amount: ammo.smg || 0, dropAmount: Math.min(30, ammo.smg || 0) },
        { label: 'Shotgun Ammo', key: 'shotgun', amount: ammo.shotgun || 0, dropAmount: Math.min(8, ammo.shotgun || 0) },
        { label: 'Pistol Ammo', key: 'pistol', amount: ammo.pistol || 0, dropAmount: Math.min(24, ammo.pistol || 0) }
    ].filter((r) => r.amount > 0).map((r) => ({
        ...r,
        actions: [{ label: 'Drop', run: () => post('dropItem', { kind: 'ammo', key: r.key, amount: r.dropAmount || 1 }) }]
    })));
    const healing = data.healing || {};
    const healRows = [];
    if (healing.bandage > 0) {
        healRows.push({
            label: 'Bandage',
            amount: healing.bandage,
            actions: [
                { label: 'Use', run: () => post('useItem', { itemId: 'bandage' }) },
                { label: 'Drop', run: () => post('dropItem', { kind: 'heal', key: 'bandage', amount: 1 }) }
            ]
        });
    }
    if (healing.medkit > 0) {
        healRows.push({
            label: 'Medkit',
            amount: healing.medkit,
            actions: [
                { label: 'Use', run: () => post('useItem', { itemId: 'medkit' }) },
                { label: 'Drop', run: () => post('dropItem', { kind: 'heal', key: 'medkit', amount: 1 }) }
            ]
        });
    }
    fillCards(healEl, healRows);
    const throws = data.throwables || {};
    fillCards(throwEl, [
        { label: 'Grenade', key: 'grenade', amount: throws.grenade || 0 },
        { label: 'Molotov', key: 'molotov', amount: throws.molotov || 0 },
        { label: 'Smoke', key: 'smoke', amount: throws.smoke || 0 }
    ].filter((r) => r.amount > 0).map((r) => ({
        ...r,
        actions: [{ label: 'Drop', run: () => post('dropItem', { kind: 'throwable', key: r.key, amount: 1 }) }]
    })));
}

function renderVicinity(list, bag) {
    lastVicinity = list || [];
    lastBag = bag || null;
    bagId = bag && bag.id ? bag.id : null;
    const sub = document.getElementById('vicinity-sub');
    const el = document.getElementById('inv-vicinity');
    const rows = [];
    if (bag && bag.contents) {
        sub.textContent = 'LOOT BAG';
        show(sub, true);
        bag.contents.forEach((row) => {
            rows.push({
                label: row.label,
                amount: row.amount,
                rarity: row.rarity,
                actions: [{ label: 'Take', run: () => post('bagTake', { lootId: bag.id, uid: row.uid }) }]
            });
        });
    } else {
        show(sub, false);
    }
    lastVicinity.forEach((row) => {
        if (bag && row.id === bag.id) {
            return;
        }
        rows.push({
            label: row.label,
            amount: row.amount,
            rarity: row.rarity,
            actions: [{
                label: row.bag ? 'Open' : 'Pick Up',
                run: () => post('pickupLoot', { lootId: row.id })
            }]
        });
    });
    fillCards(el, rows);
}

function stopBleed() {
    if (bleedTimer) {
        clearInterval(bleedTimer);
        bleedTimer = null;
    }
    show(downed, false);
}

function startBleed(seconds) {
    stopBleed();
    let left = Math.max(0, Math.ceil(Number(seconds) || 0));
    document.getElementById('bleed-time').textContent = formatClock(left);
    show(downed, true);
    bleedTimer = setInterval(() => {
        left -= 1;
        if (left <= 0) {
            document.getElementById('bleed-time').textContent = '00:00';
            stopBleed();
            return;
        }
        document.getElementById('bleed-time').textContent = formatClock(left);
    }, 1000);
}

function promptLabel(kind) {
    if (kind === 'revive' || kind === 'reviveHint') return 'Hold E  Revive';
    if (kind === 'finish' || kind === 'finishHint') return 'Hold E  Finish';
    if (kind === 'beingRevived') return 'BEING REVIVED';
    if (kind === 'beingFinished') return 'BEING FINISHED';
    return '';
}

function setPrompt(data) {
    if (!data || !data.show) {
        show(prompt, false);
        promptBar.style.animation = 'none';
        return;
    }
    promptText.textContent = promptLabel(data.kind);
    show(prompt, true);
    const ms = Number(data.ms) || 0;
    if (ms <= 0) {
        promptBar.style.animation = 'none';
        promptBar.style.transform = 'scaleX(0)';
        return;
    }
    promptBar.style.animation = 'none';
    void promptBar.offsetWidth;
    promptBar.style.animation = `fill ${Math.max(200, ms)}ms linear forwards`;
}

function resourceName() {
    if (typeof GetParentResourceName === 'function') {
        return GetParentResourceName();
    }
    return 'wtbg_ui';
}

function post(name, data) {
    fetch(`https://${resourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    });
}

function show(el, visible) {
    el.classList.toggle('hidden', !visible);
}

function setScreen(name) {
    show(lobby, name === 'lobby');
    show(hud, name === 'match');
    show(result, name === 'result');
    vitalsAllowed = name === 'lobby' || name === 'match';
    show(vitals, vitalsAllowed);
    app.classList.remove('hidden');
}

function setBar(kind, value, max) {
    const safeMax = Math.max(1, Number(max) || 100);
    const safeValue = Math.max(0, Math.min(safeMax, Math.round(Number(value) || 0)));
    const pct = (safeValue / safeMax) * 100;
    document.getElementById(`${kind}-fill`).style.width = `${pct}%`;
    document.getElementById(`${kind}-text`).textContent = `${safeValue} | ${safeMax}`;
    document.getElementById(`vital-${kind}-row`).classList.toggle('is-empty', safeValue <= 0);
}

function updateVitals(data) {
    setBar('health', data.health, data.maxHealth);
    setBar('armor', data.armor, data.maxArmor);
}

let profileOpen = false;
let lastProfile = null;
let historyTab = 'overview';
let historyState = 'idle';
let historyRows = null;
let historyOpenId = null;

function fmt(n, digits) {
    const v = Number(n);
    if (!Number.isFinite(v)) return '0';
    if (digits == null) return String(Math.floor(v));
    return v.toFixed(digits);
}

function setProfileRow(grid, label, value) {
    const wrap = document.createElement('div');
    const dt = document.createElement('dt');
    dt.textContent = label;
    const dd = document.createElement('dd');
    dd.textContent = value;
    wrap.appendChild(dt);
    wrap.appendChild(dd);
    grid.appendChild(wrap);
}

function renderProfile(stats) {
    lastProfile = stats || null;
    const nameEl = document.getElementById('profile-name');
    const noteEl = document.getElementById('profile-note');
    const grid = document.getElementById('profile-grid');
    grid.innerHTML = '';
    if (!stats) {
        nameEl.textContent = 'PROFILE';
        noteEl.textContent = 'Stats unavailable.';
        return;
    }
    nameEl.textContent = stats.name || 'PLAYER';
    noteEl.textContent = stats.persist === false ? 'Session stats only — not saved.' : '';
    const rows = [
        ['Matches', fmt(stats.matches)],
        ['Wins', fmt(stats.wins)],
        ['Win Rate', `${fmt(stats.winRate, 1)}%`],
        ['Kills', fmt(stats.kills)],
        ['Deaths', fmt(stats.deaths)],
        ['K/D', fmt(stats.kd, 2)],
        ['Assists', fmt(stats.assists)],
        ['Damage', fmt(stats.damage)],
        ['Headshots', fmt(stats.headshots)],
        ['Top 3', fmt(stats.top3)],
        ['Avg Place', fmt(stats.avgPlacement, 1)],
        ['Longest Kill', `${fmt(stats.longestKill, 1)} m`]
    ];
    rows.forEach(([label, value]) => setProfileRow(grid, label, value));
}

function pad2(n) {
    return String(n).padStart(2, '0');
}

function fmtDuration(seconds) {
    const s = Math.max(0, Math.floor(Number(seconds) || 0));
    const m = Math.floor(s / 60);
    return `${m}:${pad2(s % 60)}`;
}

function fmtFinished(value) {
    if (!value) return '';
    const d = new Date(String(value).replace(' ', 'T') + 'Z');
    if (Number.isNaN(d.getTime())) return '';
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return `${pad2(d.getUTCDate())} ${months[d.getUTCMonth()]} ${d.getUTCFullYear()}  ${pad2(d.getUTCHours())}:${pad2(d.getUTCMinutes())}`;
}

function setHistoryTab(tab) {
    historyTab = tab === 'history' ? 'history' : 'overview';
    document.getElementById('tab-overview').classList.toggle('is-on', historyTab === 'overview');
    document.getElementById('tab-history').classList.toggle('is-on', historyTab === 'history');
    show(document.getElementById('profile-grid'), historyTab === 'overview');
    show(document.getElementById('profile-history'), historyTab === 'history');
    if (historyTab === 'history' && (historyState === 'idle' || historyState === 'stale')) {
        historyState = 'loading';
        renderHistory();
        post('requestHistory');
    }
}

function renderHistory() {
    const status = document.getElementById('history-status');
    const list = document.getElementById('history-list');
    list.innerHTML = '';
    if (historyState === 'loading') {
        status.textContent = 'Loading';
        return;
    }
    if (historyState === 'fail') {
        status.textContent = 'Match history unavailable';
        return;
    }
    if (!historyRows || !historyRows.length) {
        status.textContent = 'No match history';
        return;
    }
    status.textContent = '';
    historyRows.forEach((row) => {
        const item = document.createElement('button');
        item.type = 'button';
        item.className = 'history-item' + (row.won ? ' is-win' : '');
        const top = document.createElement('div');
        top.className = 'history-top';
        const left = document.createElement('span');
        left.textContent = `#${row.matchId}  ${row.mode || 'SQUAD'}`;
        const place = document.createElement('span');
        place.className = 'history-place';
        place.textContent = row.won ? `WIN  #${row.placement}` : `#${row.placement}`;
        top.append(left, place);
        const sub = document.createElement('div');
        sub.className = 'history-sub';
        sub.innerHTML = '';
        const k = document.createElement('span');
        k.textContent = `${fmt(row.kills)} KILLS`;
        const rest = document.createElement('span');
        rest.textContent = `${fmt(row.damage)} DMG  ${fmtDuration(row.duration)}`;
        sub.append(k, rest);
        item.append(top, sub);
        item.addEventListener('click', () => {
            historyOpenId = historyOpenId === row.matchId ? null : row.matchId;
            renderHistory();
        });
        if (historyOpenId === row.matchId) {
            const detail = document.createElement('div');
            detail.className = 'history-detail';
            const bits = [
                ['Kills', fmt(row.kills)],
                ['Deaths', fmt(row.deaths)],
                ['Assists', fmt(row.assists)],
                ['Damage', fmt(row.damage)],
                ['Headshots', fmt(row.headshots)],
                ['Longest', `${fmt(row.longestKill, 1)} m`],
                ['Team', row.teamId == null ? '-' : String(row.teamId)],
                ['Date', fmtFinished(row.finishedAt)]
            ];
            if (row.disconnected) {
                bits.push(['Left', 'Disconnect']);
            }
            bits.forEach(([label, value]) => {
                const line = document.createElement('p');
                line.textContent = `${label} `;
                const span = document.createElement('span');
                span.textContent = value;
                line.appendChild(span);
                detail.appendChild(line);
            });
            item.appendChild(detail);
        }
        list.appendChild(item);
    });
}

function setMenu(open) {
    if (!open) {
        profileOpen = false;
    }
    show(profile, open && profileOpen);
    show(menu, open && !profileOpen);
    app.classList.toggle('focus', open || !invite.classList.contains('hidden') || !inventory.classList.contains('hidden'));
}

function openProfile() {
    profileOpen = true;
    historyTab = 'overview';
    setHistoryTab('overview');
    show(menu, false);
    show(profile, true);
    if (lastProfile) {
        renderProfile(lastProfile);
    }
    post('requestProfile');
}

function closeProfile() {
    profileOpen = false;
    show(profile, false);
    show(menu, true);
}

function toast(message) {
    const item = document.createElement('div');
    item.className = 'toast';
    item.textContent = message;
    toasts.appendChild(item);
    setTimeout(() => item.remove(), 3200);
}

function addKill(killer, victim, kind, ms) {
    const item = document.createElement('div');
    item.className = 'feed-item';
    const left = document.createElement('span');
    const arrow = document.createElement('em');
    const right = document.createElement('span');
    if (kind === 'down') {
        left.textContent = killer || 'World';
        arrow.textContent = 'DOWN';
        right.textContent = victim || '';
    } else if (kind === 'bleed') {
        left.textContent = victim || '';
        arrow.textContent = 'OUT';
        right.textContent = '';
    } else {
        left.textContent = killer || 'World';
        arrow.textContent = '>';
        right.textContent = victim || '';
    }
    item.append(left, arrow, right);
    killfeed.prepend(item);
    while (killfeed.children.length > 5) {
        killfeed.removeChild(killfeed.lastChild);
    }
    setTimeout(() => item.remove(), Math.max(2000, Number(ms) || 5000));
}

function fillSlots(listEl, members, maxSize, numbered) {
    listEl.innerHTML = '';
    const size = maxSize || 4;
    for (let i = 0; i < size; i += 1) {
        const member = members && members[i];
        const row = document.createElement('li');
        if (!member) {
            row.className = 'empty';
            if (numbered) {
                const num = document.createElement('span');
                num.className = 'num';
                num.textContent = String(i + 1);
                const name = document.createElement('span');
                name.textContent = 'Empty';
                row.append(num, name);
            } else {
                row.textContent = 'Empty';
            }
        } else {
            if (numbered) {
                const num = document.createElement('span');
                num.className = 'num';
                num.textContent = String(i + 1);
                row.appendChild(num);
            }
            const name = document.createElement('span');
            name.textContent = member.name || 'Player';
            const tag = document.createElement('em');
            const downed = member.downed;
            const dead = member.alive === false;
            tag.textContent = member.leader ? 'LEADER' : (downed ? 'DOWN' : (dead ? 'DEAD' : (
                member.drop === 'PLANE' ? 'PLANE' : (
                    (member.drop === 'FREEFALL' || member.drop === 'PARACHUTE') ? 'AIR' : (
                        member.alive === true ? 'ALIVE' : ''
                    )
                )
            )));
            if (downed) row.classList.add('is-down');
            if (dead) row.classList.add('is-dead');
            if (specTarget && member.source === specTarget) row.classList.add('is-spec');
            row.append(name, tag);
        }
        listEl.appendChild(row);
    }
}

function renderParty(party) {
    const maxSize = (party && party.maxSize) || 4;
    document.getElementById('party-size').textContent = party
        ? `${party.size} / ${maxSize}`
        : `0 / ${maxSize}`;
    fillSlots(partySlots, party && party.members, maxSize);
}

function renderSquad(squad) {
    lastSquad = squad || null;
    if (!squad || !squad.length) {
        show(squadPanel, false);
        return;
    }
    show(squadPanel, true);
    fillSlots(squadSlots, squad.map((m) => ({
        name: m.name,
        source: m.source,
        alive: m.alive,
        downed: m.downed,
        drop: dropMembers[m.source],
        leader: false
    })), Math.max(4, squad.length), true);
}

function formatClock(seconds) {
    const n = Math.max(0, Math.floor(Number(seconds) || 0));
    const m = String(Math.floor(n / 60)).padStart(2, '0');
    const s = String(n % 60).padStart(2, '0');
    return `${m}:${s}`;
}

function setZone(data) {
    const box = document.getElementById('zone');
    const warn = document.getElementById('zone-warn');
    if (!data || !data.show) {
        show(box, false);
        show(warn, false);
        return;
    }
    document.getElementById('zone-phase').textContent = `ZONE ${data.phase || 1}`;
    let label = 'SHRINKS IN';
    if (data.waiting) label = 'STANDBY';
    else if (data.state === 'SHRINKING') label = 'SHRINKING';
    else if (data.state === 'HOLDING') label = 'SHRINKS IN';
    document.getElementById('zone-state').textContent = label;
    document.getElementById('zone-time').textContent = formatClock(data.remaining);
    show(box, true);
    show(warn, Boolean(data.outside));
}

function setDrop(data) {
    if (!data || !data.phase) {
        show(dropHud, false);
        return;
    }
    document.getElementById('drop-phase').textContent = data.phase;
    let line = '';
    if (data.phase === 'PLANE') {
        line = `${data.key || 'SPACE'}  ${data.label || 'JUMP'}`;
        if (data.autoDrop != null) {
            line += `   AUTO ${formatClock(data.autoDrop)}`;
        }
    } else if (data.phase === 'FREEFALL' && data.key) {
        line = `${data.key}  ${data.label || 'PARACHUTE'}`;
    } else if (data.phase === 'LANDED') {
        line = '';
    }
    document.getElementById('drop-line').textContent = line;
    show(dropHud, true);
    if (data.phase !== 'LANDED') {
        setGuide([]);
    }
}

function setContext(data) {
    const box = document.getElementById('context');
    if (!data || !data.show) {
        show(box, false);
        return;
    }
    document.getElementById('context-key').textContent = data.key || 'E';
    document.getElementById('context-action').textContent = data.verb || '';
    document.getElementById('context-detail').textContent = data.detail || '';
    show(box, true);
}

function setGuide(rows) {
    hudKeys.innerHTML = '';
    (rows || []).forEach((row) => {
        const line = document.createElement('div');
        const key = document.createElement('em');
        key.textContent = row.key;
        line.append(key, document.createTextNode(row.label));
        hudKeys.appendChild(line);
    });
}

function setSpectator(data) {
    if (!data || !data.show) {
        specTarget = null;
        hud.classList.remove('is-spec');
        show(specPanel, false);
        if (lastSquad) {
            renderSquad(lastSquad);
        }
        return;
    }
    specTarget = Number(data.target) || null;
    hud.classList.add('is-spec');
    document.getElementById('spec-name').textContent = data.name || 'Teammate';
    const state = document.getElementById('spec-state');
    state.textContent = data.downed ? 'DOWN' : 'ALIVE';
    state.classList.toggle('is-down', Boolean(data.downed));
    document.getElementById('spec-kills').textContent = `${Number(data.kills) || 0} KILLS`;
    show(specPanel, true);
    if (lastSquad) {
        renderSquad(lastSquad);
    }
}

function renderResultSquad(teammates) {
    const list = document.getElementById('result-squad');
    list.innerHTML = '';
    if (!teammates || !teammates.length) {
        return;
    }
    teammates.forEach((m) => {
        const row = document.createElement('li');
        row.textContent = `${m.name}  ${m.downed ? 'DOWN' : (m.alive ? 'ALIVE' : 'DEAD')}`;
        list.appendChild(row);
    });
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    switch (data.action) {
        case 'hide':
            app.classList.add('hidden');
            setMenu(false);
            show(invite, false);
            vitalsAllowed = false;
            show(vitals, false);
            stopBleed();
            setPrompt(null);
            stopHeal();
            show(inventory, false);
            renderVicinity([], null);
            setContext(null);
            setGuide([]);
            setDrop(null);
            setZone(null);
            break;
        case 'vitals':
            updateVitals(data);
            break;
        case 'menu':
            setMenu(Boolean(data.open));
            break;
        case 'profile':
            renderProfile(data.stats || null);
            break;
        case 'history':
            if (data.error) {
                historyState = 'fail';
                historyRows = null;
            } else {
                historyState = 'ok';
                historyRows = Array.isArray(data.rows) ? data.rows : [];
            }
            if (historyTab === 'history') {
                renderHistory();
            }
            break;
        case 'historyInvalidate':
            historyState = 'stale';
            if (profileOpen && historyTab === 'history') {
                historyState = 'loading';
                renderHistory();
                post('requestHistory');
            }
            break;
        case 'showLobby':
            setScreen('lobby');
            setMenu(false);
            stopBleed();
            setPrompt(null);
            stopHeal();
            show(inventory, false);
            renderVicinity([], null);
            setContext(null);
            setGuide([]);
            setDrop(null);
            setZone(null);
            setSpectator(null);
            killfeed.innerHTML = '';
            document.getElementById('lobby-status').textContent = `Status: ${data.status || 'Lobby'}`;
            document.getElementById('lobby-meta').textContent = data.matchId
                ? `Match ${data.matchId}  ${data.players}/${data.maxPlayers}`
                : '';
            break;
        case 'showMatch':
        case 'hud':
            setScreen('match');
            document.getElementById('hud-alive').textContent = String(data.alive ?? 0);
            document.getElementById('hud-kills').textContent = String(data.kills ?? 0);
            renderSquad(data.squad);
            break;
        case 'killfeed':
            addKill(data.killer, data.victim, data.kind, data.ms);
            break;
        case 'bleed':
            if (data.show) {
                startBleed(data.seconds);
            } else {
                stopBleed();
            }
            break;
        case 'prompt':
            setPrompt(data);
            break;
        case 'showResult':
            setScreen('result');
            stopBleed();
            setPrompt(null);
            stopHeal();
            show(inventory, false);
            renderVicinity([], null);
            setContext(null);
            setGuide([]);
            setDrop(null);
            setZone(null);
            setSpectator(null);
            killfeed.innerHTML = '';
            document.getElementById('result-kicker').textContent = data.isWinner ? 'VICTORY' : 'MATCH OVER';
            document.getElementById('result-title').textContent = data.isWinner ? 'VICTORY' : 'MATCH OVER';
            document.getElementById('result-winner').textContent = data.isWinner
                ? (data.winnerName || '')
                : (data.winnerName ? `Winner  ${data.winnerName}` : 'No winner');
            document.getElementById('result-kills').textContent = String(data.kills ?? 0);
            document.getElementById('result-teamkills').textContent = String(data.teamKills ?? 0);
            show(document.getElementById('result-teamkills-wrap'), data.mode === 'SQUAD');
            document.getElementById('result-place').textContent = data.placement
                ? `${data.placement} / ${data.totalTeams || data.totalPlayers || data.placement}`
                : '-';
            renderResultSquad(data.teammates);
            break;
        case 'party':
            renderParty(data.party);
            break;
        case 'partyInvite':
            if (!data.invite) {
                invitePartyId = null;
                show(invite, false);
                app.classList.toggle('focus', !menu.classList.contains('hidden'));
                break;
            }
            invitePartyId = data.invite.partyId;
            document.getElementById('invite-text').textContent = `${data.invite.fromName} invited you.`;
            show(invite, true);
            app.classList.add('focus');
            break;
        case 'notify':
            toast(data.message || '');
            break;
        case 'inventory':
            renderInventory(data.inventory || null);
            break;
        case 'inventoryOpen':
            show(inventory, Boolean(data.open));
            app.classList.toggle('focus', !inventory.classList.contains('hidden') || !menu.classList.contains('hidden') || !invite.classList.contains('hidden'));
            break;
        case 'vicinity':
            renderVicinity(data.list || [], lastBag);
            break;
        case 'bag':
            renderVicinity(lastVicinity, data.bag || null);
            if (data.bag) {
                show(inventory, true);
                app.classList.add('focus');
            }
            break;
        case 'context':
            setContext(data);
            break;
        case 'guide':
            setGuide(data.rows);
            break;
        case 'heal':
            if (data.show) {
                startHeal(data.label, data.ms);
            } else {
                stopHeal();
            }
            break;
        case 'zone':
            setZone(data);
            break;
        case 'drop':
            setDrop(data.drop);
            break;
        case 'dropMember':
            if (data.id) {
                dropMembers[data.id] = data.phase;
                if (lastSquad) {
                    renderSquad(lastSquad);
                }
            }
            break;
        case 'spectator':
            setSpectator(data);
            break;
        default:
            break;
    }
});

document.getElementById('btn-close').addEventListener('click', () => post('closeMenu'));
document.getElementById('btn-create').addEventListener('click', () => post('createMatch'));
document.getElementById('btn-join').addEventListener('click', () => {
    post('joinMatch', { matchId: document.getElementById('join-id').value });
});
document.getElementById('join-id').addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        post('joinMatch', { matchId: document.getElementById('join-id').value });
    }
});
document.getElementById('btn-start').addEventListener('click', () => post('startMatch'));
document.getElementById('btn-leave').addEventListener('click', () => post('leaveMatch'));
document.getElementById('btn-stats').addEventListener('click', () => openProfile());
document.getElementById('btn-profile-back').addEventListener('click', () => closeProfile());
document.getElementById('tab-overview').addEventListener('click', () => setHistoryTab('overview'));
document.getElementById('tab-history').addEventListener('click', () => setHistoryTab('history'));
document.getElementById('btn-accept').addEventListener('click', () => {
    post('acceptInvite', { partyId: invitePartyId });
    show(invite, false);
});
document.getElementById('btn-decline').addEventListener('click', () => {
    post('declineInvite', { partyId: invitePartyId });
    show(invite, false);
});

document.querySelectorAll('.eq-drop').forEach((btn) => {
    btn.addEventListener('click', () => {
        post('dropItem', { kind: btn.dataset.kind, key: btn.dataset.key, amount: 1 });
    });
});

document.addEventListener('keydown', (event) => {
    const invVisible = !inventory.classList.contains('hidden');
    if (invVisible && (event.key === 'Tab' || event.key === 'F2' || event.key === 'Escape')) {
        event.preventDefault();
        show(inventory, false);
        post('closeInventory');
        return;
    }
    if (event.key !== 'Escape') {
        return;
    }
    if (!app.classList.contains('focus')) {
        return;
    }
    post('closeMenu');
    if (invitePartyId) {
        post('declineInvite', { partyId: invitePartyId });
        show(invite, false);
    }
});

renderParty(null);
