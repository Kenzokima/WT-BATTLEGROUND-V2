const app = document.getElementById('app');
const lobby = document.getElementById('lobby');
const menu = document.getElementById('menu');
const invite = document.getElementById('invite');
const hud = document.getElementById('hud');
const result = document.getElementById('result');
const killfeed = document.getElementById('killfeed');
const toasts = document.getElementById('toasts');
const partySlots = document.getElementById('party-slots');
const squadSlots = document.getElementById('squad-slots');
const squadPanel = document.getElementById('squad-panel');

let invitePartyId = null;

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
    app.classList.remove('hidden');
}

function setMenu(open) {
    show(menu, open);
    app.classList.toggle('focus', open || !invite.classList.contains('hidden'));
}

function toast(message) {
    const item = document.createElement('div');
    item.className = 'toast';
    item.textContent = message;
    toasts.appendChild(item);
    setTimeout(() => item.remove(), 3200);
}

function addKill(killer, victim) {
    const item = document.createElement('div');
    item.className = 'feed-item';
    const left = document.createElement('span');
    left.textContent = killer || 'World';
    const arrow = document.createElement('em');
    arrow.textContent = '>';
    const right = document.createElement('span');
    right.textContent = victim || '';
    item.append(left, arrow, right);
    killfeed.prepend(item);
    while (killfeed.children.length > 5) {
        killfeed.removeChild(killfeed.lastChild);
    }
    setTimeout(() => item.remove(), 4000);
}

function fillSlots(listEl, members, maxSize) {
    listEl.innerHTML = '';
    const size = maxSize || 4;
    for (let i = 0; i < size; i += 1) {
        const member = members && members[i];
        const row = document.createElement('li');
        if (!member) {
            row.className = 'empty';
            row.textContent = 'Empty';
        } else {
            const name = document.createElement('span');
            name.textContent = member.name || 'Player';
            const tag = document.createElement('em');
            tag.textContent = member.leader ? 'LEADER' : (member.alive === false ? 'DEAD' : (member.alive === true ? 'ALIVE' : ''));
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
    if (!squad || !squad.length) {
        show(squadPanel, false);
        return;
    }
    show(squadPanel, true);
    fillSlots(squadSlots, squad.map((m) => ({
        name: m.name,
        alive: m.alive,
        leader: false
    })), Math.max(4, squad.length));
}

function renderResultSquad(teammates) {
    const list = document.getElementById('result-squad');
    list.innerHTML = '';
    if (!teammates || !teammates.length) {
        return;
    }
    teammates.forEach((m) => {
        const row = document.createElement('li');
        row.textContent = `${m.name}  ${m.alive ? 'ALIVE' : 'DEAD'}`;
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
            break;
        case 'menu':
            setMenu(Boolean(data.open));
            break;
        case 'showLobby':
            setScreen('lobby');
            setMenu(false);
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
            addKill(data.killer, data.victim);
            break;
        case 'showResult':
            setScreen('result');
            killfeed.innerHTML = '';
            document.getElementById('result-kicker').textContent = data.isWinner ? 'MATCH COMPLETE' : 'MATCH OVER';
            document.getElementById('result-title').textContent = data.isWinner ? 'WINNER' : 'MATCH OVER';
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
document.getElementById('btn-accept').addEventListener('click', () => {
    post('acceptInvite', { partyId: invitePartyId });
    show(invite, false);
});
document.getElementById('btn-decline').addEventListener('click', () => {
    post('declineInvite', { partyId: invitePartyId });
    show(invite, false);
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        post('closeMenu');
        if (invitePartyId) {
            post('declineInvite', { partyId: invitePartyId });
            show(invite, false);
        }
    }
});

renderParty(null);
