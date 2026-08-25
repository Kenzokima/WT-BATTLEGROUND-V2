# WhiteTiger Battleground V2 (WTBG)

Prototype standalone **battleground / last-player-standing** untuk **FiveM (GTA5)**.

Pemain mulai di lobby, membuat atau bergabung ke match, lalu bertarung di routing bucket terpisah sampai tersisa satu pemain hidup.

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
9. [Events & Exports](#events--exports)
10. [UI (NUI)](#ui-nui)
11. [Setup Server](#setup-server)
12. [Dependensi Antar Resource](#dependensi-antar-resource)
13. [Catatan Pengembangan](#catatan-pengembangan)

---

## Ringkasan

Repo ini berisi:

1. **`resources/[wtbg]/`** — logika utama WhiteTiger Battleground V2 (core, match, combat, UI).
2. **Resource CFX default** — aset standar `cfx-server-data` (spawnmanager, mapmanager, baseevents, maps, contoh gameplay, dll.) sebagai fondasi server FiveM.

Mode permainan saat ini:

- Lobby bersama (routing bucket `0`)
- Match terisolasi per instance (routing bucket = match ID)
- Loadout tetap (carbine + pistol)
- Death → eliminate → last alive menang
- Layar result singkat, lalu kembali ke lobby

---

## Struktur Repository

```
WT-BATTLEGROUND-V2/
└── resources/
    ├── [wtbg]/                 # ★ Logika custom WTBG
    │   ├── wtbg_core/          # Session, lobby, player state, ped
    │   ├── wtbg_match/         # Match lifecycle & commands
    │   ├── wtbg_combat/        # Loadout, death reporting
    │   └── wtbg_ui/            # NUI lobby / HUD / result
    │
    ├── [gamemodes]/            # CFX: gametype & maps
    ├── [gameplay]/             # CFX: chat theme, playernames, examples
    ├── [managers]/             # CFX: mapmanager, spawnmanager
    ├── [system]/               # CFX: baseevents, runcode
    └── [test]/                 # CFX: example loadscreen
```

---

## Resource Custom `[wtbg]`

### 1. `wtbg_core` — Session & Lobby

**Peran:** fondasi session pemain, spawn lobby, ped freemode, kontrol dunia (wanted/dispatch/density).

| Path | Fungsi |
|------|--------|
| `shared/config.lua` | Konfigurasi global |
| `shared/utils.lua` | State enums, helper debug/parse |
| `server/players.lua` | Registry pemain + exports |
| `server/main.lua` | Session ready, player drop, resource lifecycle |
| `client/appearance.lua` | Freemode ped, friendly fire, unlock combat |
| `client/main.lua` | Spawn lobby, teleport, strip weapons, world cleanup |

**Player state fields:**

```lua
{
  source, state, matchId, teamId, alive, name
}
```

**States pemain:** `LOBBY` | `MATCH` | `DEAD` | `RESULT`

---

### 2. `wtbg_match` — Match Manager

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

---

### 3. `wtbg_combat` — Combat & Loadout

**Peran:** memberi senjata sesuai `Config.Loadout`, mendeteksi kematian, melaporkan ke match manager.

| Path | Fungsi |
|------|--------|
| `shared/weapons.lua` | `Weapons.ApplyLoadout(ped)` |
| `server/combat.lua` | Apply loadout + handle death report + lock |
| `client/combat.lua` | Deteksi death (game event, baseevents, poll) |

Death detection multi-path agar tidak miss:

- `CEventNetworkEntityDamage`
- `baseevents:onPlayerKilled` / `onPlayerDied`
- Polling `IsEntityDead` / `IsPedDeadOrDying` setiap 200ms

Server memakai `deathLock` agar satu kematian tidak dilaporkan berulang.

---

### 4. `wtbg_ui` — Interface (NUI)

**Peran:** overlay lobby, menu F6, HUD match, killfeed, result screen, toast notify.

| Path | Fungsi |
|------|--------|
| `client/ui.lua` | Bridge Lua ↔ NUI + keybind F6 |
| `web/index.html` | Struktur layar |
| `web/style.css` | Styling |
| `web/app.js` | Logic NUI + callbacks |

---

## Resource CFX Default

Resource di luar `[wtbg]` adalah bagian dari paket default **Cfx.re / cfx-server-data**. Jangan diubah kecuali sadar konsekuensinya.

| Folder | Resource | Kegunaan singkat |
|--------|----------|------------------|
| `[managers]` | `spawnmanager` | Spawn player terpusat (dipakai `wtbg_core`) |
| `[managers]` | `mapmanager` | Manajemen map / gametype |
| `[gamemodes]` | `basic-gamemode` | Gametype freeroam dasar |
| `[gamemodes]/[maps]` | `fivem-map-hipster`, `fivem-map-skater`, `redm-map-one` | Spawn map |
| `[system]` | `baseevents` | Event death/vehicle (dipakai combat) |
| `[system]` | `runcode` | Eksekusi kode runtime (dev) |
| `[gameplay]` | `playernames` | Nama pemain di atas kepala |
| `[gameplay]` | `player-data` | Storage identifier dasar |
| `[gameplay]` | `chat-theme-example` | Tema chat contoh |
| `[gameplay]/[examples]` | `money`, `money-fountain`, `ped-money-drops`, … | Contoh scripting CFX |
| `[test]` | `example-loadscreen` | Contoh loading screen |

Untuk WTBG, yang paling relevan: **`spawnmanager`** dan **`baseevents`**.

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
    ├─ creatematch / F6 → Create Match
    ├─ joinmatch <id> / F6 → Join Match
    └─ startmatch / F6 → Start (min players)
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
            └─ alivePlayers <= 1
                    │
                    ▼
                 FINISHED
               (UI result, ResultDuration detik)
                    │
                    ▼
                 CLEANUP
               (semua kembali lobby, match dihapus)
```

**Win condition:** tersisa ≤ 1 pemain `alive` di match `ACTIVE`.

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

Ubah koordinat / loadout / angka di file ini — resource lain membaca config lewat `@wtbg_core/shared/config.lua`.

---

## Perintah & Kontrol

### In-game commands

| Command | Akses | Fungsi |
|---------|-------|--------|
| `/creatematch` | Dev (`Debug` atau ACE `wtbg.dev`) | Buat match baru, jadi host |
| `/joinmatch <id>` | Dev | Gabung match (contoh `/joinmatch 1001`) |
| `/startmatch [id]` | Dev | Mulai match (harus anggota + min players) |
| `/leavematch` | Semua | Keluar match / kembali lobby |
| `/matches` | Dev / console | List match aktif |
| `/wtbgmenu` | Client | Toggle menu lobby (sama dengan F6) |

### Keybind

| Key | Aksi |
|-----|------|
| **F6** | Buka/tutup menu Match Controls (hanya saat layar lobby) |
| **Esc** | Tutup menu NUI |

### Menu NUI (F6)

- **Create Match**
- **Join** (input Match ID)
- **Start Match**
- **Leave Match**

> Saat `Config.Debug = true`, gate `canDev` selalu lolos. Untuk production, set `Debug = false` dan berikan ACE `wtbg.dev` ke admin.

Contoh `server.cfg`:

```cfg
add_ace group.admin wtbg.dev allow
add_principal identifier.fivem:XXXX group.admin
```

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

#### `wtbg_core`

| Export | Deskripsi |
|--------|-----------|
| `GetPlayerState(source)` | Snapshot state pemain |
| `GetPlayerMatch(source)` | Match ID |
| `IsPlayerAlive(source)` | Status alive |
| `SendToLobby(source)` | Kirim ke lobby |
| `SetSessionState(source, state)` | Set state |
| `SetMatch(source, matchId, teamId)` | Bind ke match |
| `SetAlive(source, alive)` | Set alive flag |
| `Notify(source, message)` | Notifikasi |
| `EnsureFreemodePed` (client) | Pastikan model ped |
| `UnlockCombat` (client) | Unfreeze + enable control |
| `EnableFriendlyFire` (client) | Friendly fire on |

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
2. **Menu (F6)** — create / join / start / leave
3. **Match HUD** — `ALIVE` count + `KILLS`
4. **Killfeed** — max 5 item, auto-remove
5. **Result** — winner / placement / kills
6. **Toasts** — notifikasi singkat

NUI callbacks: `closeMenu`, `createMatch`, `joinMatch`, `startMatch`, `leaveMatch`.

---

## Setup Server

### 1. Letakkan resource

Pastikan folder `resources/[wtbg]` ada di `server-data/resources/` (atau path resource server Anda).

### 2. `server.cfg` (contoh minimal)

```cfg
# CFX basics (sesuaikan dengan setup Anda)
ensure mapmanager
ensure spawnmanager
ensure basic-gamemode
ensure fivem-map-hipster
ensure baseevents

# WTBG stack (urutkan sesuai dependency)
ensure wtbg_core
ensure wtbg_match
ensure wtbg_combat
ensure wtbg_ui
```

### 3. Uji cepat (dengan `Config.Debug = true`)

1. Dua client join server → keduanya di lobby.
2. Client A: `/creatematch` → dapat Match ID (mis. `1001`).
3. Client B: `/joinmatch 1001`.
4. Client A: `/startmatch`.
5. Countdown → loadout → bertarung.
6. Satu mati → result → kembali lobby.

Atau gunakan **F6** untuk menu yang sama.

---

## Dependensi Antar Resource

```
wtbg_core
    ↑
    ├── wtbg_match  (dependency wtbg_core)
    │       ↑
    │       └── wtbg_combat  (dependency wtbg_core + wtbg_match)
    │
    └── wtbg_ui     (dependency wtbg_core)

CFX eksternal yang dipakai:
  spawnmanager  ← wtbg_core (setAutoSpawn / spawnPlayer)
  baseevents    ← wtbg_combat (onPlayerKilled / onPlayerDied)
  chat          ← wtbg_core notify (chat:addMessage)
```

---

## Catatan Pengembangan

### Status proyek

Ini **standalone prototype** (`0.1.0`):

- Belum ada matchmaking otomatis / queue publik
- Command create/join/start masih **dev-gated**
- Belum ada persistence (stats, inventory, DB)
- Belum ada team mode (field `teamId` sudah ada, belum dipakai)
- Map spawn masih hardcode di area airfield

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

Match yang selesai disimpan di memory (max 20 entri) untuk debug internal — belum di-expose ke UI.

---

## Lisensi / Attribution

- Resource **`[wtbg]`**: WhiteTiger / WT Battleground V2.
- Resource di folder lain: bagian dari **Cfx.re cfx-server-data** (lihat header tiap `fxmanifest.lua`).

---

*Dokumentasi ini mengikuti struktur kode pada commit terkini branch `main`.*
