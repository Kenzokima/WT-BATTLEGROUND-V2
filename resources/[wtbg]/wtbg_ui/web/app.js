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

const CUT = 'fill="rgba(0,0,0,.55)"';

const WEAPON_SVG = {
    carbine: `<polygon points="2,17 13,14.5 13,22 2,24"/><rect x="13" y="14.5" width="27" height="7.5" rx="1"/><rect x="19" y="10.5" width="17" height="3" rx="1"/><rect x="40" y="17" width="19" height="3"/><rect x="52" y="11.5" width="2" height="5.5"/><polygon points="24,22 32,22 33,32 26,32"/><polygon points="16.5,22 23,22 21,31 14.5,31"/><rect x="15" y="17.4" width="23" height="1.3" ${CUT}/><rect x="21" y="11.6" width="13" height="1" ${CUT}/>`,
    ak: `<polygon points="2,18 15,15 15,22 2,25"/><rect x="15" y="14.5" width="23" height="7.5" rx="1"/><rect x="38" y="15.8" width="13" height="4.4" rx="1"/><rect x="51" y="17" width="9" height="2.2"/><rect x="44.5" y="10.5" width="3" height="6"/><path d="M23 22h9.5l3.5 7.5c.3 2-1.5 3.5-3.5 3.5h-6c-2 0-3.5-1.5-3.5-3.5z"/><polygon points="16.5,22 23,22 21,31 14.5,31"/><rect x="17" y="17.4" width="20" height="1.3" ${CUT}/><rect x="39" y="17.3" width="11" height="1.2" ${CUT}/>`,
    smg: `<rect x="19" y="12.5" width="21" height="9.5" rx="1"/><rect x="40" y="16" width="10" height="3"/><rect x="26" y="22" width="6.5" height="11" rx="1"/><polygon points="18,22 24.5,22 22.5,31 16,31"/><rect x="7" y="15.8" width="12" height="3" rx="1"/><rect x="21" y="16.4" width="17" height="1.3" ${CUT}/><rect x="27.2" y="24" width="4" height="7" ${CUT}/>`,
    microsmg: `<rect x="22" y="11.5" width="18" height="10.5" rx="1"/><rect x="40" y="15.8" width="6" height="3"/><rect x="26.5" y="22" width="6" height="9" rx="1"/><polygon points="20.5,22 26,22 24,30.5 18.5,30.5"/><rect x="24" y="8.5" width="10" height="3" rx="1"/><rect x="23.5" y="15.6" width="15" height="1.3" ${CUT}/>`,
    shotgun: `<polygon points="2,18 15,15.5 15,22 2,25"/><rect x="15" y="15.5" width="21" height="6.5" rx="1"/><rect x="36" y="16.6" width="23" height="3"/><rect x="38" y="21" width="12" height="3" rx="1"/><polygon points="16.5,22 23,22 21,30.5 14.5,30.5"/><rect x="17" y="17.8" width="18" height="1.2" ${CUT}/><rect x="39" y="21.8" width="10" height="1.2" ${CUT}/>`,
    pistol: `<rect x="24" y="12.5" width="22" height="5.5" rx="1"/><rect x="24" y="18" width="15" height="3.5"/><polygon points="26.5,21.5 35,21.5 32,32 23.5,32"/><rect x="45" y="16.5" width="4" height="2"/><rect x="26" y="17.6" width="18" height="1.2" ${CUT}/><path d="M29 21.5h6v3h-6z" ${CUT}/>`,
    pistol2: `<rect x="23" y="11.5" width="24" height="6.5" rx="1"/><rect x="23" y="18" width="16" height="3.5"/><polygon points="25.5,21.5 35,21.5 32,32 22.5,32"/><rect x="29" y="8.5" width="13" height="2.5" rx="1"/><rect x="46" y="16.5" width="4" height="2"/><rect x="25" y="17.6" width="19" height="1.2" ${CUT}/><path d="M28 21.5h6.5v3H28z" ${CUT}/>`,
    ammo: `<rect x="16" y="15" width="32" height="18" rx="2"/><rect x="23" y="6" width="5.5" height="9" rx="2.5"/><rect x="31.5" y="6" width="5.5" height="9" rx="2.5"/><rect x="16" y="19.5" width="32" height="1.6" ${CUT}/><rect x="30" y="21.1" width="4" height="11.9" ${CUT}/>`,
    bandage: `<rect x="10" y="16.5" width="44" height="11" rx="5.5"/><rect x="25" y="14" width="7" height="16" transform="rotate(18 28.5 22)" ${CUT}/><rect x="36" y="14" width="7" height="16" transform="rotate(18 39.5 22)" ${CUT}/>`,
    medkit: `<rect x="13" y="13" width="38" height="20" rx="3"/><rect x="26" y="8" width="12" height="5" rx="2"/><rect x="29.5" y="16.5" width="5" height="13" ${CUT}/><rect x="24.5" y="20.5" width="15" height="5" ${CUT}/>`,
    armor: `<path d="M32 6 15 11.5v10.5c0 7.5 7.5 12.5 17 15.5 9.5-3 17-8 17-15.5V11.5z"/><rect x="30.5" y="12" width="3" height="24" ${CUT}/><rect x="19" y="19" width="26" height="2.4" ${CUT}/>`,
    grenade: `<circle cx="32" cy="24.5" r="10.5"/><rect x="29" y="7" width="6" height="7.5" rx="2"/><rect x="34.5" y="8" width="8" height="3" rx="1.5"/><rect x="22" y="19.5" width="20" height="1.4" ${CUT}/><rect x="22" y="23.6" width="20" height="1.4" ${CUT}/><rect x="22" y="27.7" width="20" height="1.4" ${CUT}/>`,
    molotov: `<path d="M27 13h10v5.5l4 7V36c0 1.5-1 2.5-2.5 2.5h-13C24 38.5 23 37.5 23 36V25.5l4-7z"/><rect x="27.5" y="5" width="9" height="8" rx="3.5"/><rect x="25" y="27" width="14" height="6" ${CUT}/>`,
    smoke: `<rect x="24" y="10" width="16" height="25" rx="4"/><rect x="28" y="5" width="8" height="5" rx="2"/><rect x="27" y="16" width="10" height="1.8" ${CUT}/><rect x="27" y="21" width="10" height="1.8" ${CUT}/><rect x="27" y="26" width="10" height="1.8" ${CUT}/>`,
    bag: `<path d="M26 15v-2.5a6 6 0 0 1 12 0V15" fill="none" stroke="currentColor" stroke-width="2.6"/><rect x="9" y="15" width="46" height="19" rx="5"/><rect x="9" y="22" width="46" height="2.2" ${CUT}/>`
};

const ITEM_META = {
    rifle_carbine: { icon: 'carbine', rarity: 'epic', slot: 'primary' },
    rifle_assault: { icon: 'ak', rarity: 'epic', slot: 'primary' },
    smg_standard: { icon: 'smg', rarity: 'rare', slot: 'secondary' },
    smg_micro: { icon: 'microsmg', rarity: 'uncommon', slot: 'secondary' },
    shotgun_pump: { icon: 'shotgun', rarity: 'rare', slot: 'secondary' },
    pistol_standard: { icon: 'pistol', rarity: 'common', slot: 'sidearm' },
    pistol_combat: { icon: 'pistol2', rarity: 'uncommon', slot: 'sidearm' },
    ammo_rifle: { icon: 'ammo', rarity: 'common' },
    ammo_smg: { icon: 'ammo', rarity: 'common' },
    ammo_shotgun: { icon: 'ammo', rarity: 'common' },
    ammo_pistol: { icon: 'ammo', rarity: 'common' },
    bandage: { icon: 'bandage', rarity: 'common' },
    medkit: { icon: 'medkit', rarity: 'rare' },
    armor_plate: { icon: 'armor', rarity: 'rare' },
    grenade: { icon: 'grenade', rarity: 'uncommon' },
    molotov: { icon: 'molotov', rarity: 'uncommon' },
    smoke: { icon: 'smoke', rarity: 'common' }
};

const KIND_ICON = {
    weapon: 'carbine',
    ammo: 'ammo',
    heal: 'medkit',
    armor: 'armor',
    throwable: 'grenade',
    bag: 'bag'
};

const MAG_SIZE = { rifle: 30, smg: 30, shotgun: 8, pistol: 24 };

function metaOf(itemId, kind) {
    const meta = ITEM_META[itemId];
    if (meta) return meta;
    return { icon: KIND_ICON[kind] || 'ammo', rarity: 'common' };
}

function iconMarkup(name) {
    const body = WEAPON_SVG[name] || WEAPON_SVG.ammo;
    return `<svg viewBox="0 0 64 40" aria-hidden="true">${body}</svg>`;
}

function slotLabel(slot) {
    return slot && slot.label ? slot.label : 'Empty';
}

function ammoFor(inv, type) {
    if (!inv || !inv.ammo) return 0;
    return inv.ammo[type] || 0;
}

function tileEl(item) {
    const li = document.createElement('li');
    li.className = `tile rar-${item.rarity || 'common'}`;
    const icon = document.createElement('div');
    icon.className = 'tile-icon';
    icon.innerHTML = iconMarkup(item.icon);
    const meta = document.createElement('div');
    meta.className = 'tile-meta';
    const name = document.createElement('strong');
    name.textContent = item.label;
    meta.appendChild(name);
    if (item.sub) {
        const sub = document.createElement('span');
        sub.textContent = item.sub;
        meta.appendChild(sub);
    }
    li.append(icon, meta);
    if (item.amount > 1) {
        const qty = document.createElement('b');
        qty.className = 'tile-qty';
        qty.textContent = `x${item.amount}`;
        li.appendChild(qty);
    }
    const acts = document.createElement('div');
    acts.className = 'tile-acts';
    (item.actions || []).forEach((act) => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.textContent = act.label;
        btn.addEventListener('mousedown', (event) => event.stopPropagation());
        btn.addEventListener('click', (event) => {
            event.stopPropagation();
            act.run();
        });
        acts.appendChild(btn);
    });
    li.appendChild(acts);
    bindTile(li, item);
    return li;
}

function fillTiles(el, rows) {
    el.innerHTML = '';
    if (!rows.length) {
        const empty = document.createElement('li');
        empty.className = 'tile is-empty';
        empty.textContent = 'Empty';
        el.appendChild(empty);
        return;
    }
    rows.forEach((row) => el.appendChild(tileEl(row)));
}

function setEquipSlot(key, slot, inv, fallbackAmmo) {
    const label = document.getElementById(`inv-${key}`);
    const ammoEl = document.getElementById(`eq-${key}-ammo`);
    const iconEl = document.getElementById(`eq-${key}-icon`);
    const wrap = document.getElementById(`eq-${key}`);
    label.textContent = slotLabel(slot);
    wrap.classList.toggle('is-filled', Boolean(slot));
    if (!slot) {
        ammoEl.textContent = '';
        iconEl.innerHTML = '';
        wrap.className = wrap.className.replace(/\brar-\w+/g, '').trim();
        return;
    }
    const meta = metaOf(slot.id, 'weapon');
    iconEl.innerHTML = iconMarkup(meta.icon);
    ammoEl.textContent = `${ammoFor(inv, slot.ammoType || fallbackAmmo)} ROUNDS`;
    wrap.className = wrap.className.replace(/\brar-\w+/g, '').trim();
    wrap.classList.add(`rar-${meta.rarity}`);
}

function renderInventory(data) {
    lastInv = data || null;
    const ammoEl = document.getElementById('inv-ammo');
    const healEl = document.getElementById('inv-heal');
    const throwEl = document.getElementById('inv-throw');
    const armorBar = document.getElementById('armor-bar');
    const armor = Math.max(0, Math.min(100, Number(data && data.armor) || 0));
    document.getElementById('inv-armor').textContent = `${armor} / 100`;
    armorBar.style.width = `${armor}%`;
    setEquipSlot('primary', data && data.primary, data, 'rifle');
    setEquipSlot('secondary', data && data.secondary, data, 'smg');
    setEquipSlot('sidearm', data && data.sidearm, data, 'pistol');
    if (!data) {
        fillTiles(ammoEl, []);
        fillTiles(healEl, []);
        fillTiles(throwEl, []);
        document.getElementById('bag-count').textContent = '0';
        return;
    }

    const ammo = data.ammo || {};
    const ammoRows = [
        { key: 'rifle', itemId: 'ammo_rifle', label: 'Rifle Ammo' },
        { key: 'smg', itemId: 'ammo_smg', label: 'SMG Ammo' },
        { key: 'shotgun', itemId: 'ammo_shotgun', label: 'Shotgun Ammo' },
        { key: 'pistol', itemId: 'ammo_pistol', label: 'Pistol Ammo' }
    ].filter((r) => (ammo[r.key] || 0) > 0).map((r) => {
        const total = ammo[r.key] || 0;
        const mag = Math.min(MAG_SIZE[r.key] || 1, total);
        const meta = metaOf(r.itemId, 'ammo');
        return {
            source: 'bag',
            kind: 'ammo',
            label: r.label,
            sub: `MAG ${MAG_SIZE[r.key] || 1}`,
            amount: total,
            icon: meta.icon,
            rarity: meta.rarity,
            drop: (all) => post('dropItem', { kind: 'ammo', key: r.key, amount: all ? total : mag }),
            actions: [{ label: 'Drop', run: () => post('dropItem', { kind: 'ammo', key: r.key, amount: mag }) }]
        };
    });
    fillTiles(ammoEl, ammoRows);

    const healing = data.healing || {};
    const healRows = [
        { key: 'bandage', label: 'Bandage' },
        { key: 'medkit', label: 'Medkit' }
    ].filter((r) => (healing[r.key] || 0) > 0).map((r) => {
        const total = healing[r.key] || 0;
        const meta = metaOf(r.key, 'heal');
        return {
            source: 'bag',
            kind: 'heal',
            label: r.label,
            amount: total,
            icon: meta.icon,
            rarity: meta.rarity,
            use: () => post('useItem', { itemId: r.key }),
            drop: (all) => post('dropItem', { kind: 'heal', key: r.key, amount: all ? total : 1 }),
            actions: [
                { label: 'Use', run: () => post('useItem', { itemId: r.key }) },
                { label: 'Drop', run: () => post('dropItem', { kind: 'heal', key: r.key, amount: 1 }) }
            ]
        };
    });
    fillTiles(healEl, healRows);

    const throws = data.throwables || {};
    const throwRows = [
        { key: 'grenade', label: 'Grenade' },
        { key: 'molotov', label: 'Molotov' },
        { key: 'smoke', label: 'Smoke' }
    ].filter((r) => (throws[r.key] || 0) > 0).map((r) => {
        const total = throws[r.key] || 0;
        const meta = metaOf(r.key, 'throwable');
        return {
            source: 'bag',
            kind: 'throwable',
            label: r.label,
            amount: total,
            icon: meta.icon,
            rarity: meta.rarity,
            drop: (all) => post('dropItem', { kind: 'throwable', key: r.key, amount: all ? total : 1 }),
            actions: [{ label: 'Drop', run: () => post('dropItem', { kind: 'throwable', key: r.key, amount: 1 }) }]
        };
    });
    fillTiles(throwEl, throwRows);
    document.getElementById('bag-count').textContent = String(ammoRows.length + healRows.length + throwRows.length);
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
            const meta = metaOf(row.itemId, row.kind);
            rows.push({
                source: 'ground',
                kind: row.kind,
                slot: meta.slot,
                label: row.label,
                amount: row.amount,
                icon: meta.icon,
                rarity: meta.rarity,
                take: () => post('bagTake', { lootId: bag.id, uid: row.uid }),
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
        const kind = row.bag ? 'bag' : row.kind;
        const meta = row.bag ? { icon: 'bag', rarity: 'rare' } : metaOf(row.itemId, kind);
        rows.push({
            source: 'ground',
            kind: kind,
            slot: meta.slot,
            label: row.label,
            amount: row.amount,
            icon: meta.icon,
            rarity: meta.rarity,
            take: () => post('pickupLoot', { lootId: row.id }),
            actions: [{
                label: row.bag ? 'Open' : 'Take',
                run: () => post('pickupLoot', { lootId: row.id })
            }]
        });
    });
    fillTiles(el, rows);
    document.getElementById('vicinity-count').textContent = String(rows.length);
}

const ghostEl = document.getElementById('drag-ghost');
let press = null;
let dragItem = null;
let hoverZone = null;
let suppressClick = false;

function zoneList() {
    return Array.prototype.slice.call(document.querySelectorAll('#inventory [data-zone]'));
}

function zoneAccepts(item, zone) {
    const kind = zone.dataset.zone;
    if (item.source === 'ground') {
        if (kind === 'bag') return Boolean(item.take);
        if (kind === 'equip') {
            return Boolean(item.take) && item.kind === 'weapon' && zone.dataset.slot === item.slot;
        }
        return false;
    }
    return kind === 'ground' && Boolean(item.drop);
}

function clearZones() {
    zoneList().forEach((zone) => zone.classList.remove('zone-ok', 'zone-hot'));
    hoverZone = null;
}

function endDrag() {
    if (dragItem && dragItem.el) {
        dragItem.el.classList.remove('is-dragged');
    }
    dragItem = null;
    press = null;
    clearZones();
    show(ghostEl, false);
    ghostEl.innerHTML = '';
    document.body.classList.remove('is-dragging');
}

function moveGhost(event) {
    ghostEl.style.left = `${event.clientX}px`;
    ghostEl.style.top = `${event.clientY}px`;
}

function startDrag(item, el, event) {
    dragItem = { item, el };
    el.classList.add('is-dragged');
    document.body.classList.add('is-dragging');
    ghostEl.className = `drag-ghost rar-${item.rarity || 'common'}`;
    ghostEl.innerHTML = `<div class="tile-icon">${iconMarkup(item.icon)}</div><strong>${item.label}</strong>`;
    moveGhost(event);
    zoneList().forEach((zone) => {
        if (zoneAccepts(item, zone)) {
            zone.classList.add('zone-ok');
        }
    });
}

function bindTile(el, item) {
    if (!item.take && !item.drop && !item.use) {
        return;
    }
    el.classList.add('can-drag');
    el.addEventListener('mousedown', (event) => {
        if (event.button !== 0) return;
        event.preventDefault();
        press = { item, el, x: event.clientX, y: event.clientY };
    });
    el.addEventListener('click', () => {
        if (suppressClick) return;
        if (item.use) {
            item.use();
        } else if (item.take) {
            item.take();
        }
    });
    el.addEventListener('contextmenu', (event) => {
        event.preventDefault();
        if (item.drop) {
            item.drop(event.shiftKey);
        } else if (item.take) {
            item.take();
        }
    });
}

function equipItem(slotKey) {
    const slot = lastInv && lastInv[slotKey];
    if (!slot) return null;
    const meta = metaOf(slot.id, 'weapon');
    return {
        source: 'equip',
        kind: 'weapon',
        slot: slotKey,
        label: slot.label,
        icon: meta.icon,
        rarity: meta.rarity,
        drop: () => post('dropItem', { kind: 'weapon', key: slotKey, amount: 1 })
    };
}

['primary', 'secondary', 'sidearm'].forEach((slotKey) => {
    const el = document.getElementById(`eq-${slotKey}`);
    el.addEventListener('mousedown', (event) => {
        if (event.button !== 0) return;
        const item = equipItem(slotKey);
        if (!item) return;
        event.preventDefault();
        press = { item, el, x: event.clientX, y: event.clientY };
    });
    el.addEventListener('contextmenu', (event) => {
        event.preventDefault();
        const item = equipItem(slotKey);
        if (item) {
            item.drop();
        }
    });
});

document.addEventListener('mousemove', (event) => {
    if (!dragItem && press) {
        if (Math.abs(event.clientX - press.x) + Math.abs(event.clientY - press.y) < 6) {
            return;
        }
        startDrag(press.item, press.el, event);
    }
    if (!dragItem) return;
    moveGhost(event);
    const under = document.elementFromPoint(event.clientX, event.clientY);
    const zone = under && under.closest ? under.closest('#inventory [data-zone]') : null;
    const next = zone && zoneAccepts(dragItem.item, zone) ? zone : null;
    if (next === hoverZone) return;
    if (hoverZone) hoverZone.classList.remove('zone-hot');
    hoverZone = next;
    if (hoverZone) hoverZone.classList.add('zone-hot');
});

document.addEventListener('mouseup', (event) => {
    if (!dragItem) {
        press = null;
        return;
    }
    const item = dragItem.item;
    const zone = hoverZone;
    suppressClick = true;
    setTimeout(() => { suppressClick = false; }, 0);
    endDrag();
    if (!zone) return;
    if (zone.dataset.zone === 'ground') {
        if (item.drop) item.drop(event.shiftKey);
    } else if (item.take) {
        item.take();
    }
});

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
    const size = maxSize || 10;
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
    const maxSize = (party && party.maxSize) || 10;
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
    })), Math.max(10, squad.length), true);
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
            endDrag();
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
            endDrag();
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
            endDrag();
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
            if (!data.open) {
                endDrag();
            }
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
    btn.addEventListener('mousedown', (event) => event.stopPropagation());
    btn.addEventListener('click', (event) => {
        event.stopPropagation();
        post('dropItem', { kind: btn.dataset.kind, key: btn.dataset.key, amount: 1 });
    });
});

document.getElementById('inv-close').addEventListener('click', () => {
    show(inventory, false);
    post('closeInventory');
});

document.addEventListener('keydown', (event) => {
    const invVisible = !inventory.classList.contains('hidden');
    if (dragItem && event.key === 'Escape') {
        event.preventDefault();
        endDrag();
        return;
    }
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
