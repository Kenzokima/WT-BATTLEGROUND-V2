# WhiteTiger Battleground V2 (WTBG)

Prototype standalone **battleground / last-team-standing** untuk **FiveM (GTA5)**.

Milestone saat ini: **M5B — Match History**.

Pemain mulai di lobby, opsional membentuk party, membuat atau bergabung ke match, lalu bertarung di routing bucket terpisah sampai tersisa satu tim hidup. Match memakai knock/revive, loot BR, zone, dan HUD kompetitif. Profil lifetime dan history match selesai disimpan di MariaDB lewat oxmysql.

| | |
|---|---|
| **Author** | WhiteTiger |
| **Versi** | `0.1.0` |
| **Platform** | FiveM / GTA5 |
| **Lua** | Lua 5.4 (`lua54 'yes'`) |
| **Remote** | `https://github.com/Kenzokima/WT-BATTLEGROUND-V2.git` |

---

## Daftar Isi

1. [Ringkasan](#ringkasan)
2. [Struktur Repository](#struktur-repository)
3. [Resource Custom `[wtbg]`](#resource-custom-wtbg)
4. [Resource CFX Default](#resource-cfx-default)
5. [Alur Gameplay](#alur-gameplay)
6. [State Machine](#state-machine)
7. [Konfigurasi](#konfigurasi)
8. [Perintah & Kontrol](#perintah--kontrol)
9. [Squad Rules](#squad-rules)
10. [Events & Exports](#events--exports)
11. [UI (NUI)](#ui-nui)
12. [Setup Server](#setup-server)
13. [Dependensi Antar Resource](#dependensi-antar-resource)
14. [Testing](#testing)
15. [Catatan Pengembangan](#catatan-pengembangan)
16. [M5A Persistence](#m5a-persistence)
17. [M5B Match History](#m5b-match-history)

---

## Ringkasan

Repo ini berisi:

1. **`resources/[wtbg]/`** — logika utama WhiteTiger Battleground V2 (core, party, match, combat, UI).
2. **Resource CFX default** — aset standar `cfx-server-data` yang dipakai live (`spawnmanager`, `mapmanager`, `baseevents`, maps, `playernames`).

Mode permainan saat ini:

- Lobby bersama (routing bucket `0`)
- Party / squad opsional (max 4), membership bertahan setelah match
- Match terisolasi per instance (routing bucket = match ID)
- Mode `SQUAD` (party = satu tim) atau `FFA` (setiap pemain = tim sendiri)
- Loadout tetap (carbine + pistol)
- Death → eliminate → last alive team menang
- Layar result singkat, lalu kembali ke lobby (party tetap ada)

Mode permainan saat ini mencakup lobby, party, match bucket, combat DOWN/revive/finish, loot BR, zone, plane drop, kendaraan, teammate spectator, HUD/inventory, dan profil/stat lifetime. Belum ada ranked, match history, cosmetics, atau framework (ESX/QBCore/Qbox).

---

## Struktur Repository

```
WT-BATTLEGROUND-V2/
├── server.cfg
├── resources.cfg
└── resources/
    ├── [wtbg]/                 # Logika custom WTBG
    │   ├── wtbg_core/          # Session, lobby, player state, ped, profiles
    │   ├── wtbg_party/         # Party membership & invites
    │   ├── wtbg_match/         # Match lifecycle & commands
    │   ├── wtbg_combat/        # Loadout, DOWN / revive / finish
    │   ├── wtbg_loot/          # BR inventory and world loot
    │   ├── wtbg_zone/          # Play zone
    │   ├── wtbg_drop/          # Plane / jump / parachute
    │   ├── wtbg_vehicle/       # Match vehicles
    │   ├── wtbg_spectator/     # Teammate spectator
    │   └── wtbg_ui/            # NUI lobby / party / HUD / result
    ├── [gamemodes]/            # CFX: basic-gamemode + maps
    ├── [gameplay]/             # CFX: playernames
    ├── [managers]/             # CFX: mapmanager, spawnmanager
    ├── [system]/               # CFX: baseevents
    └── [local]/                # Resource tambahan
```

---

## Resource Custom `[wtbg]`

### 1. `wtbg_core` — Session, Lobby, Profiles

**Peran:** fondasi session pemain, spawn lobby, ped freemode, kontrol dunia, dan persistence profil.

| Path | Fungsi |
|------|--------|
| `shared/config.lua` | Konfigurasi global |
| `shared/utils.lua` | State enums, helper debug/parse |
| `sql/001_players.sql` | Schema `wtbg_players` (idempotent) |
| `sql/002_match_history.sql` | Schema `wtbg_matches` + `wtbg_match_players` |
| `server/database.lua` | Tunggu oxmysql, apply schema 001 lalu 002 |
| `server/players.lua` | Registry pemain + exports |
| `server/profiles.lua` | Load/create/cache/save profil |
| `server/match_history.lua` | Persist + query history match |
| `server/stats.lua` | Match runtime stats, lifetime merge, snapshot history |
| `server/main.lua` | Session ready, player drop, resource lifecycle |
| `client/appearance.lua` | Freemode ped, friendly fire, unlock combat |
| `client/main.lua` | Spawn lobby, teleport, strip weapons, world cleanup |

**Player state fields:**

```lua
{
  source, state, matchId, teamId, partyId, alive, name
}
```

**States pemain:** `LOBBY` | `MATCH` | `DEAD` | `RESULT`

---

### 2. `wtbg_party` — Party / Squad

**Peran:** party server-authoritative, invite, kick, promote, leave.

| Path | Fungsi |
|------|--------|
| `server/party_manager.lua` | Engine party lengkap |
| `server/commands.lua` | Chat commands party |
| `client/party.lua` | Client bridge party |

Party membership **bertahan** setelah match cleanup. Match `teamId` di-clear; `partyId` tetap.

---

### 3. `wtbg_match` — Match Manager

**Peran:** create / join / leave / start match, isolasi bucket, countdown, win condition, history.

| Path | Fungsi |
|------|--------|
| `server/match_manager.lua` | Engine match lengkap |
| `server/commands.lua` | Chat commands + net events (dev-gated) |
| `client/match.lua` | Enter match, freeze countdown, spectator-ish dead state |

**Match object (internal):**

```lua
{
  id, state, bucket, host, players, teams,
  alivePlayers, winner, winnerName, createdAt, nextSpawn
}
```

**Match member:**

```lua
{
  source, teamId, alive, kills, placement, spawnIndex, name, joinedAt
}
```

**Match ID** mulai dari `1001` dan naik. **Routing bucket** = match ID (populasi NPC dimatikan).

Di mode `SQUAD`, leader party membawa seluruh party saat create/join (atomic). Di mode `FFA`, tiap pemain adalah tim sendiri.

---

### 4. `wtbg_combat` — Combat & Loadout

**Peran:** loadout, knock / bleedout / finish / revive, lalu eliminate ke match manager.

| Path | Fungsi |
|------|--------|
| `shared/weapons.lua` | `Weapons.ApplyLoadout(ped)` |
| `server/combat.lua` | Loadout, knock, revive, finish, bleedout |
| `client/combat.lua` | Deteksi down, pose knock, hold E |

Knock terjadi di match `ACTIVE`. Player downed masih `alive` (tim belum tereliminasi). Kill credit hanya saat finish atau bleedout. Revive hanya sesama tim di mode `SQUAD`.

---

### 5. `wtbg_ui` — Interface (NUI)

**Peran:** overlay lobby, menu F6, party panel, HUD match / squad, killfeed, result screen, toast notify.

| Path | Fungsi |
|------|--------|
| `client/ui.lua` | Bridge Lua ↔ NUI + keybind F6 |
| `web/index.html` | Struktur layar |
| `web/style.css` | Styling |
| `web/app.js` | Logic NUI + callbacks |

---

### 6. `wtbg_spectator` — Teammate Spectator

**Peran:** setelah `DEAD`, kamera follow teammate `ALIVE`/`DOWN` yang divalidasi server. Tidak ada enemy spectate, FFA, atau solo.

| Path | Fungsi |
|------|--------|
| `server/spectator.lua` | Eligibility, kandidat tim, next/prev |
| `client/spectator.lua` | Third-person follow cam, hide local ped |

Kontrol: `←` / `→` ganti teammate. Spectator berhenti saat squad wipe, match `FINISHED`, leave, atau disconnect.

---

### 7. Balance (`wtbg_core/shared/balance.lua`)

Gameplay values live in `WTBG.Balance`. Resource configs read them; do not copy the same number into combat/loot/UI separately.

GTA ped health is offset by 100 (`NativeOffset`). Gameplay 100 HP = native 200. Helpers: `WTBG.NativeHealth` / `WTBG.GameplayHealth`.

Set `WTBG.Balance.Preset = 'FAST_TEST'` to shorten plane/zone/result waits only. Combat damage is unchanged.

Dev: `/balanceinfo` (`Config.Debug` or `wtbg.dev`).

---

## Resource CFX Default

Resource di luar `[wtbg]` adalah bagian dari paket default **Cfx.re / cfx-server-data**. Jangan diubah kecuali sadar konsekuensinya.

| Folder | Resource | Kegunaan singkat |
|--------|----------|------------------|
| `[managers]` | `spawnmanager` | Spawn player terpusat (dipakai `wtbg_core`) |
| `[managers]` | `mapmanager` | Manajemen map / gametype |
| `[gamemodes]` | `basic-gamemode` | Gametype freeroam dasar |
| `[gamemodes]/[maps]` | `fivem-map-hipster`, `fivem-map-skater` | Spawn map |
| `[system]` | `baseevents` | Event death/vehicle (dipakai combat) |
| `[gameplay]` | `playernames` | Nama pemain di atas kepala |
| `[local]` | — | Tempat resource tambahan |

Untuk WTBG, yang paling relevan: **`spawnmanager`** dan **`baseevents`**. Auto-spawn dinonaktifkan oleh `wtbg_core` jika spawnmanager ada.

---

## Alur Gameplay

```
Join server
    │
    ▼
wtbg:core:sessionReady
    │
    ▼
LOBBY (bucket 0, ped freemode, no weapons)
    │
    ├─ party invite / accept (opsional)
    ├─ creatematch / F6 → Create Match (leader bawa party)
    ├─ joinmatch <id> / F6 → Join Match (leader bawa party)
    └─ startmatch / F6 → Start (min players + teams)
            │
            ▼
       STARTING
       (teleport spawn point, freeze, countdown)
            │
            ▼
         ACTIVE
       (loadout diberikan, combat unlocked)
            │
            ├─ player mati → DEAD, placement dihitung
            ├─ leave / disconnect saat aktif → treat as death
            └─ alive teams <= 1
                    │
                    ▼
                 FINISHED
               (UI result, ResultDuration detik)
                    │
                    ▼
                 CLEANUP
               (semua kembali lobby, match dihapus, party tetap)
```

**Win condition:** tersisa ≤ 1 tim `alive` di match `ACTIVE`.

---

## State Machine

### Player States (`WTBG.PlayerStates`)

| State | Arti |
|-------|------|
| `LOBBY` | Di lobby, siap create/join |
| `MATCH` | Sedang dalam match (hidup) |
| `DEAD` | Tereleminasi / leave saat aktif |
| `RESULT` | Layar hasil match |

### Match States (`WTBG.MatchStates`)

| State | Arti |
|-------|------|
| `WAITING` | Menunggu pemain / start |
| `STARTING` | Countdown sebelum combat |
| `ACTIVE` | Pertandingan berjalan |
| `FINISHED` | Ada pemenang, tampilkan result |
| `CLEANUP` | Kembalikan ke lobby, destroy match |

---

## Konfigurasi

File: `resources/[wtbg]/wtbg_core/shared/config.lua`

| Key | Default | Keterangan |
|-----|---------|------------|
| `Config.Debug` | `true` | Log debug + **semua pemain bisa pakai command/dev menu** |
| `Config.LobbyBucket` | `0` | Routing bucket lobby |
| `Config.LobbyCoords` | `vector4(1747.48, 3273.73, 41.15, 195.0)` | Spawn lobby (Sandy Shores airfield area) |
| `Config.MatchSpawnPoints` | 8 titik | Spawn match (rotasi round-robin) |
| `Config.MinPlayers` | `2` | Minimum untuk start |
| `Config.MaxPlayers` | `16` | Kapasitas match |
| `Config.StartingHealth` | `200` | HP awal |
| `Config.StartingArmor` | `100` | Armor saat loadout match |
| `Config.Loadout` | Carbine 250 + Pistol 120 | Senjata awal |
| `Config.StartCountdown` | `5` | Detik freeze sebelum match aktif |
| `Config.ResultDuration` | `8` | Detik layar hasil sebelum cleanup |
| `Config.DevAce` | `'wtbg.dev'` | ACE permission untuk command (jika `Debug=false`) |
| `Config.PedModel` | `'mp_m_freemode_01'` | Model ped default |
| `Config.PartyMaxSize` | `4` | Maks anggota party |
| `Config.PartyInviteTimeout` | `30` | Detik timeout invite |
| `Config.SquadSize` | `4` | Ukuran squad |
| `Config.FriendlyFire` | `false` | FF antar tim-mate |
| `Config.MatchMode` | `'SQUAD'` | `'SQUAD'` atau `'FFA'` |
| `Config.BleedoutTime` | `25` | Detik knock sebelum eliminate |
| `Config.ReviveTime` | `6` | Detik hold E revive |
| `Config.FinishTime` | `2` | Detik hold E finish |
| `Config.ReviveRange` | `2.75` | Jarak revive (meter) |
| `Config.FinishRange` | `2.5` | Jarak finish (meter) |
| `Config.ReviveHealth` | `140` | HP setelah revive |

- **`SQUAD`**: party join sebagai satu tim. Solo dapat tim sendiri. Last alive team menang.
- **`FFA`**: tiap pemain = tim sendiri. Last alive tetap lewat logika tim yang sama.

Ubah koordinat / loadout / angka di file ini — resource lain membaca config lewat `@wtbg_core/shared/config.lua`.

---

## Perintah & Kontrol

### Match commands

| Command | Akses | Fungsi |
|---------|-------|--------|
| `/creatematch` | Dev (`Debug` atau ACE `wtbg.dev`) | Buat match. Party leader membawa seluruh party |
| `/joinmatch <id>` | Dev | Solo join sendiri. Party leader join seluruh party. Member tidak bisa join |
| `/startmatch [id]` | Dev | Mulai match (min 2 players & 2 teams) |
| `/leavematch` | Semua | Keluar match / kembali lobby. Saat ACTIVE = eliminasi |
| `/matches` | Dev / console | List match aktif |
| `/wtbgmenu` | Client | Toggle menu lobby (sama dengan F6) |
| `/profileinfo` `/statsinfo` | Dev (`Debug` atau ACE `wtbg.dev`) | Print cached profile snapshot |

### Party commands

| Command | Akses | Fungsi |
|---------|-------|--------|
| `/partyinvite [serverId]` | In-game | Invite. Buat party jika belum punya |
| `/partyaccept [partyId]` | In-game | Terima invite |
| `/partydecline [partyId]` | In-game | Tolak invite |
| `/partyleave` | In-game | Keluar party. Leader ditransfer jika perlu |
| `/partykick [serverId]` | Leader | Kick member |
| `/partypromote [serverId]` | Leader | Promote leader baru |
| `/party` | In-game | Print party saat ini |

### Keybind

| Key | Aksi |
|-----|------|
| **SPACE** | Plane: jump. Freefall: deploy parachute (GTA). |
| **F2** / **TAB** | Inventory (after landing only) |
| **E** | Ambil loot / buka loot bag (dekat objek) |
| **Hold E** | Revive teammate DOWN, atau Finish musuh DOWN |
| **1 / 2 / 3** | Weapon slot Primary / Secondary / Sidearm (loadout server) |
| **F6** | Buka/tutup menu Match Controls (hanya layar lobby) |
| **Esc** | Tutup inventory / menu NUI |

Inventory memakai klik tombol **Pick Up / Use / Drop / Take**. Klik kanan pada kartu item menjalankan aksi pertama. Drag-and-drop tidak dipakai.

**G** tidak di-bind untuk drop (bentrok grenade GTA). Drop lewat tombol inventory.

Slot **4 / 5** (throwable / heal) tidak ditambah; grenade/smoke/heal tetap lewat inventory **Use** / GTA throw.

> Binding lama **I** untuk inventory sudah dihapus.

### Menu NUI (F6)

- **Create Match**
- **Join** (input Match ID)
- **Start Match**
- **Leave Match**
- **Stats** — panel profil lifetime (snapshot server, bukan query DB)

> Saat `Config.Debug = true`, gate `canDev` selalu lolos. Untuk production, set `Debug = false` dan berikan ACE `wtbg.dev` ke admin.

Contoh `server.cfg`:

```cfg
add_ace group.admin wtbg.dev allow
add_principal identifier.fivem:XXXX group.admin
```

---

## Squad Rules

- Max party size 4.
- Hanya leader yang invite, kick, promote, dan create/join match untuk party.
- Party join ke match bersifat **atomic** — jika satu member gagal, tidak ada yang join.
- Mode `SQUAD`: seluruh party memakai `teamId` yang sama.
- Friendly fire off by default. Kill same-team tidak dapat credit.
- Party survive match cleanup. Match `teamId` di-clear; `partyId` tetap.

---

## Events & Exports

### Events penting

#### Client ← Server

| Event | Sumber | Kegunaan |
|-------|--------|----------|
| `wtbg:core:spawnLobby` | core | Teleport + setup lobby |
| `wtbg:core:notify` | core | Chat + toast |
| `wtbg:match:enter` | match | Masuk arena + countdown freeze |
| `wtbg:match:begin` | match | Combat mulai |
| `wtbg:match:playerDied` | match | Local dead state |
| `wtbg:match:finished` | match | Match selesai |
| `wtbg:combat:applyLoadout` | combat | Beri senjata di client |
| `wtbg:ui:showLobby` | core/match | UI lobby |
| `wtbg:ui:showMatch` / `wtbg:ui:hud` | match | HUD |
| `wtbg:ui:killfeed` | match | Killfeed |
| `wtbg:ui:showResult` | match | Result screen |

#### Server ← Client

| Event | Kegunaan |
|-------|----------|
| `wtbg:core:sessionReady` | Client siap, minta lobby |
| `wtbg:match:create` / `join` / `start` / `leave` | Aksi match (dev-gated kecuali leave) |
| `wtbg:combat:playerDied` | Laporan kematian |

#### Server internal

| Event | Kegunaan |
|-------|----------|
| `wtbg:core:playerDropped` | Player disconnect (match cleanup) |
| `wtbg:core:returnedToLobby` | Reset death lock dll. |
| `wtbg:match:applyLoadout` | Trigger pemberian loadout |

### Exports

Returned tables are copies. Gameplay state tidak diambil dari client.

#### `wtbg_core`

| Export | Deskripsi |
|--------|-----------|
| `GetPlayerState(source)` | Snapshot state (termasuk `matchId`, `teamId`, `partyId`) |
| `GetPlayerMatch(source)` | Match ID |
| `GetPlayerPartyId(source)` | Party ID |
| `IsPlayerAlive(source)` | Status alive |
| `SendToLobby(source)` | Kirim ke lobby |
| `SetSessionState(source, state)` | Set state |
| `SetMatch(source, matchId, teamId)` | Bind ke match |
| `SetAlive(source, alive)` | Set alive flag |
| `SetParty(source, partyId)` | Bind ke party |
| `Notify(source, message)` | Notifikasi |
| `GetPrimaryIdentifier(source)` | Canonical `license:` (fallback `license2:`) |
| `GetProfile(source)` | Copy profil cache (bukan table internal) |
| `GetStats(source)` | Snapshot derived (K/D, win rate, avg placement) |
| `IsProfileLoaded(source)` | Cache siap (`loaded`) |
| `GetRecentMatchHistory(source, limit, cb)` | Recent self-history (async, sanitized) |
| `EnsureFreemodePed` (client) | Pastikan model ped |
| `UnlockCombat` (client) | Unfreeze + enable control |
| `EnableFriendlyFire` (client) | Friendly fire on |

#### `wtbg_party`

| Export | Deskripsi |
|--------|-----------|
| `GetParty(partyId)` | Snapshot party |
| `GetPlayerParty(source)` | Party pemain |
| `IsLeader(source)` | Apakah leader |
| `CreateParty(source)` | Buat party |
| `InvitePlayer(source, target)` | Invite |
| `AcceptInvite(source, partyId)` | Terima invite |
| `DeclineInvite(source, partyId)` | Tolak invite |
| `LeaveParty(source)` | Keluar party |
| `KickMember(source, target)` | Kick |
| `PromoteLeader(source, target)` | Promote |
| `DisbandParty(source)` | Bubarkan party |

#### `wtbg_match`

| Export | Deskripsi |
|--------|-----------|
| `GetMatch(matchId)` | Snapshot match |
| `CreateMatch(source)` | Buat match → `id, err` |
| `JoinMatch(source, matchId)` | Join → `ok, err` |
| `LeaveMatch(source)` | Leave → `ok, err` |
| `StartMatch(source, matchId)` | Start → `ok, err` |
| `ReportDeath(victim, killer, weapon)` | Proses kill |
| `ListMatches()` | Daftar match aktif |

#### `wtbg_combat`

| Export | Deskripsi |
|--------|-----------|
| `ApplyLoadout(source)` | Apply loadout ke pemain |

---

## UI (NUI)

Layar:

1. **Lobby** — branding *WHITE TIGER BATTLEGROUND V2*, status, hint command
2. **Menu (F6)** — create / join / start / leave / stats
3. **Profile** — lifetime stats + recent match history (F6 Stats)
3. **Party panel** — anggota / invite status
4. **Match HUD** — `ALIVE` count + `KILLS` (+ squad info)
5. **Spectator** — target name / ALIVE|DOWN / kills, `←` `→`
6. **Killfeed** — max 5 item, auto-remove
7. **Result** — winner team / placement / kills
8. **Toasts** — notifikasi singkat

NUI callbacks: `closeMenu`, `createMatch`, `joinMatch`, `startMatch`, `leaveMatch`, `requestProfile`, `requestHistory`.

---

## Setup Server

Repo ini adalah **server-data** (bukan binary FXServer). Remote GitHub: `https://github.com/Kenzokima/WT-BATTLEGROUND-V2`.

1. Arahkan txAdmin ke folder ini, atau jalankan FXServer dari sini dengan `+exec server.cfg`.
2. OneSync sudah `on` di `server.cfg`. Jangan start ESX, QBCore, atau Qbox bersama stack ini.
3. Install **oxmysql** (Overextended) di resources, lalu `ensure oxmysql` sebelum `wtbg_core` (sudah di `resources.cfg`).
4. Set `mysql_connection_string` di `server.cfg` / oxmysql. Jangan taruh password di resource WTBG.
5. Import schema sekali jika perlu: `sql/001_players.sql` lalu `sql/002_match_history.sql`. `wtbg_core` menjalankan `CREATE TABLE IF NOT EXISTS` berurutan saat oxmysql ready — tidak ada DROP.
6. Jangan commit `sv_licenseKey` atau Steam Web API key. txAdmin yang mengisi license.

`chat`, `sessionmanager`, `hardcap`, dan `rconlog` datang dari artifact FXServer. Spawnmanager tetap di-start; `wtbg_core` mematikan auto-spawn.

Restart server setelah mengubah `[wtbg]`.

### 3. Uji cepat (dengan `Config.Debug = true`)

1. Dua client join server → keduanya di lobby.
2. (Opsional) A invite B, B accept → `/party`.
3. Client A: `/creatematch` → dapat Match ID (mis. `1001`); party ikut jika ada.
4. Client B / party lain: `/joinmatch 1001`.
5. Client A: `/startmatch`.
6. Countdown → loadout → bertarung.
7. Satu tim tersisa → result → kembali lobby (party tetap).

Atau gunakan **F6** untuk menu match yang sama.

---

## Dependensi Antar Resource

```
oxmysql
    ↑
wtbg_core
    ↑
    ├── wtbg_party  (dependency wtbg_core)
    ├── wtbg_match  (dependency wtbg_core [+ party])
    │       ↑
    │       ├── wtbg_combat  (dependency wtbg_core + wtbg_match)
    │       ├── wtbg_loot
    │       ├── wtbg_zone
    │       ├── wtbg_drop
    │       ├── wtbg_vehicle
    │       └── wtbg_spectator  (dependency wtbg_core + wtbg_match)
    │
    └── wtbg_ui     (dependency wtbg_core)

CFX eksternal yang dipakai:
  spawnmanager  ← wtbg_core (setAutoSpawn / spawnPlayer)
  baseevents    ← wtbg_combat (onPlayerKilled / onPlayerDied)
  chat          ← wtbg_core notify (chat:addMessage)
  oxmysql       ← wtbg_core (profil / stats)
```

---

## Testing

### Party

1. A invite B (`/partyinvite [id]`).
2. B accepts.
3. `/party` shows A as LEADER.
4. A leaves. B becomes leader.

### Squad match

1. Party ABCD. Party EFGH.
2. A `/creatematch`. Whole party A enters waiting match.
3. E `/joinmatch [id]`. Whole party E enters as team 2.
4. `/startmatch`.
5. Eliminate team 1. Team 2 wins. Result shows TEAM id, team kills, your kills, placement.
6. After result, both parties still exist in lobby.

### Spectator (M4C)

1. Squad AB. A dies fully. A spectates B. F2/TAB and E do nothing.
2. B goes DOWN. A stays on B, HUD shows DOWN. Revive B. HUD shows ALIVE.
3. Add C. A cycles `←` `→` between B and C. Cannot spectate enemies.
4. B dies while watched. Camera switches to C. C dies. Spectator ends, result shows.
5. FFA death does not spectate enemies.
6. `ensure wtbg_spectator` mid-spectate: camera cleans; if still DEAD with a teammate, spectator restores. Combat stays blocked.

### Profile / stats (M5A)

1. Join baru: satu row `wtbg_players`, level 1, xp 0, stats 0.
2. Reconnect: row yang sama, bukan duplikat license.
3. Ganti display name, reconnect: nama ter-update, stats sama.
4. Selesaikan match (contoh 3 kill / 1 death / placement 2): `matches +1`, lifetime += match stats, `top3 +1` di SQUAD, `total_placement +2`. Result UI tidak menunggu SQL.
5. Menang: `wins +1`, placement 1, `top3 +1`.
6. DOWN lalu revive: deaths tidak bertambah. Full eliminate: deaths +1 sekali.
7. Mati zone: death +1, tanpa kill/damage pemain.
8. A damage, B finish dalam 15s (≥20 dmg): B kill, A assist. Revive dulu: kontribusi lama dibersihkan.
9. Longest kill memakai jarak ped server. Lifetime memakai max.
10. Disconnect saat ACTIVE: eliminasi existing, stats tetap finalize tanpa source.
11. DB down: log, gameplay lanjut, profil ephemeral, tidak retry tiap frame.
12. Dua session license sama: satu owner; session kedua tidak menulis DB.
13. Restart `wtbg_core` di luar match ACTIVE: schema tidak di-drop, profil reload.

### Match history (M5B)

1. Selesaikan 1 match: 1 row `wtbg_matches`, 1 row `wtbg_match_players` per peserta ber-profile.
2. Squad 4 finish #2: `match_id` + `team_id` sama, `placement = 2`, kills/damage unik.
3. Winner squad: `winner_team_id` benar, semua anggota `won = 1`, `placement = 1`.
4. Member mati awal, tim #3: history member itu `placement = 3`.
5. Disconnect ACTIVE: row tetap ada, `disconnected = 1`, stats + placement final.
6. Cancel sebelum result: tidak ada row history.
7. Dua match bersamaan: history terpisah, tidak tercampur.
8. Ganti nama: history match lama menyimpan nama saat itu.
9. F6 Stats → Recent: 10 terbaru, tanpa license/profile id.
10. DB down saat buka history: `MATCH HISTORY UNAVAILABLE`; Overview lifetime tetap dari cache.

History **tidak di-backfill** dari lifetime M5A. Match sebelum M5B tidak punya row history.

### Edge cases

- Party full, duplicate invite, expired invite, invite self
- Member tries `/joinmatch` (rejected)
- Leader disconnect, member disconnect
- Disconnect during ACTIVE match (counts as elimination)
- Whole squad eliminated, solo joining a squad match
- Duplicate death, `/leavematch` while ACTIVE
- Resource restart returns players to lobby; parties reset with the resource

---

## Catatan Pengembangan

### Status proyek

Ini **standalone prototype** (`0.1.0`) — milestone **M5B Match History**:

- Belum ada matchmaking otomatis / queue publik
- Command create/join/start masih **dev-gated**
- Lifetime profile + completed match history ada; **belum** ranked, leaderboard, season, XP gain
- Belum ada freecam / admin observer / killcam
- Belum ada auto squad fill
- Party membership masih in-memory
- Restart `wtbg_core` saat match ACTIVE tidak merekonstruksi history in-progress

### Next milestone

**M5C+** — bukan bagian M5B:

- Ranked / MMR / leaderboard / season
- Cosmetics / Battle Pass / Tournament tools

### BALANCE NOTES

Current baseline (gameplay values):

| | |
|---|---|
| Health | 100 gameplay HP (native 200) |
| Max armor | 100, plates +25 |
| Bandage | 3s, +25, cap 75 HP |
| Medkit | 6s, full heal |
| Bleedout | 30s |
| Revive | 6s, 50 HP, 0 armor |
| Finish | 2.5s |
| Plane | 80s full-map route, jump delay 3s, force chute 92m AGL |
| Vehicles | 40 world spawns (Draugur-majority mix) |
| Result | 6s |
| Killfeed | 5s, max 5 |
| Zone | full GTA land, ~11–12 min at `TimeScale = 1.0` |

Weapon **damage, spread, and headshots use GTA defaults**. WTBG only applies recoil-shake feel (stronger while sprinting/jumping). No weapons.meta / handling.meta.

Weapon pool: Carbine, Assault Rifle, SMG, Micro SMG, Pump Shotgun, Pistol, Combat Pistol, grenade/molotov/smoke.

Provisional — needs 8–16 player tests:

- Vehicle density (40) vs populated matches
- Zone damage on full map
- Weapon TTK with GTA defaults + armor
- Plane 80s jump distribution
- Loot spawn weights (pistols/SMGs more common than AR/shotgun)

FAST_TEST shortens waits only. Do not treat current zone/vehicle numbers as ranked production values.

### Error codes (match)

| Code | Arti |
|------|------|
| `invalid` / `invalid_source` | Input tidak valid |
| `busy` | Operasi sedang diproses |
| `no_session` | Session belum siap |
| `already_in_match` / `already_joined` | Sudah di match |
| `not_in_lobby` | Harus di lobby |
| `not_found` | Match tidak ada |
| `not_joinable` | Match bukan `WAITING` |
| `full` | Capai `MaxPlayers` |
| `not_in_match` | Belum di match |
| `match_ending` | Sudah finishing/cleanup |
| `not_member` | Bukan anggota match |
| `not_waiting` | Bukan state waiting |
| `not_enough_players` | Di bawah `MinPlayers` |

### Isolasi match

Setiap match memakai **routing bucket sendiri** (`bucket = match.id`) agar pemain antar match tidak saling lihat/tembak. Lobby memakai bucket `0`.

### History

Match yang selesai disimpan di memory (max 20 entri) untuk debug internal — belum di-expose ke UI. Lifetime totals ada di `wtbg_players`. Per-match history adalah M5B.

---

## M5A Persistence

oxmysql + MariaDB/MySQL. Credential hanya di server config, bukan di resource WTBG.

**Identifier:** `license:` Rockstar (fallback `license2:` jika `license:` tidak ada). Bukan source, bukan nama. Satu session aktif per license.

**Lifecycle:**

```
playerJoining / sessionReady
→ async load/create wtbg_players
→ cache memory

match becameActive
→ MatchStats[matchId][source] (license/profileId snapshot)

combat events
→ memory only

serverFinished
→ merge lifetime sekali (idempotent)
→ async UPDATE
→ result UI tidak menunggu SQL

disconnect
→ flush dirty profile
→ participant stats tetap di match pack sampai finalize
```

**Match cancelled / destroyed sebelum result:** tidak persist match stats, tidak increment `matches`.

**Stats:**

| Field | Sumber |
|------|--------|
| kills / deaths | `wtbg:match:playerEliminated` setelah `ReportDeath` (DOWN bukan death) |
| damage / assists / headshots | OneSync `weaponDamageEvent` ter-validasi |
| longest kill | jarak `GetEntityCoords` killer/victim saat eliminate |
| placement / win / top3 | `wtbg_match` result; top3 hanya mode `SQUAD` |
| K/D, win rate, avg placement | derived, tidak disimpan |

**Assist:** musuh lain, ≥20 damage tervalidasi, 15 detik sebelum eliminate, bukan killer. Revive sukses menghapus contributor lama.

**Headshot:** `weaponDamageEvent.hitComponent == 20` per hit yang lolos clamp. Bukan anti-cheat penuh; jika event tidak ada, stat tetap 0.

**Damage:** tidak dari client event. Clamp ke sisa HP/armor efektif. Friendly fire dan zone tidak dihitung.

**DB gagal:** log, profil ephemeral `persist=false`, tidak membuat row palsu, tidak retry per frame. Gameplay tetap jalan.

**Save:** satu UPDATE per participant saat finalize; flush dirty tiap 5 menit; flush saat drop / `onResourceStop`. Crash keras tidak dijamin. SQL parameterized.

**Asumsi:** satu owner profil per license. Session kedua tidak menulis stats.

---

## M5B Match History

Completed matches only. Snapshot diambil dari finalisasi M5A yang sama (bukan tracker kedua).

```
serverFinished
→ snapshot (identity + stats + placement + timestamps)
→ lifetime merge (async)
→ history transaction (async)
→ result UI tidak menunggu SQL
```

**Tables:** `wtbg_matches` (unique `match_id` runtime), `wtbg_match_players` (unique `match_id, profile_id`). FK `match_db_id → wtbg_matches.id`.

**Timestamps:** start = `becameActive` (UTC), finish = `serverFinished`. `duration_seconds` integer. Nama di history adalah nama saat match, bukan nama profil terbaru.

**Disconnect:** `disconnected = 1` hanya jika player drop saat pack ACTIVE. `/leavematch` dan result cleanup bukan disconnect. Peserta offline tetap tersimpan lewat snapshot `profileId/license/name`.

**Cancelled / destroy tanpa result:** tidak ada history.

**Query:** self only, `profile_id` dari cache server, default 10 / max 20, cooldown 2s, tidak load on join. NUI tidak menerima license atau DB id.

**Gagal history:** lifetime tetap. Gagal lifetime: history tetap. Duplikat `match_id` dianggap sudah tersimpan. Retry 2x, tidak infinite.

**Headshot** tetap definisi M5A (`weaponDamageEvent` component 20).

---

## Lisensi / Attribution

- Resource **`[wtbg]`**: WhiteTiger / WT Battleground V2.
- Resource di folder lain: bagian dari **Cfx.re cfx-server-data** (lihat header tiap `fxmanifest.lua`).

---

*Dokumentasi ini mengikuti struktur kode pada commit terkini branch `main`.*
