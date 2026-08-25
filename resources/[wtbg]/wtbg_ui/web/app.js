const app = document.getElementById('app');
const lobby = document.getElementById('lobby');
const menu = document.getElementById('menu');
const hud = document.getElementById('hud');
const result = document.getElementById('result');
const killfeed = document.getElementById('killfeed');
const toasts = document.getElementById('toasts');

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
    app.classList.toggle('focus', open);
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

window.addEventListener('message', (event) => {
    const data = event.data || {};

    switch (data.action) {
        case 'hide':
            app.classList.add('hidden');
            setMenu(false);
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
            document.getElementById('result-place').textContent = data.placement
                ? `${data.placement} / ${data.totalPlayers || data.placement}`
                : '-';
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

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        post('closeMenu');
    }
});
