# WhiteTiger Battleground V2

Standalone FiveM battleground prototype.

Current milestone: **M2 - Party / Squad**

M1 is complete: lobby, match buckets, FFA/team combat loop, results, return to lobby.

## Gameplay loop

**Connect -> Lobby -> Party (optional) -> Create / Join Match -> Fight -> Last Alive Team -> Result -> Return to Lobby**

Party membership survives the match. Team and match are destroyed after cleanup.

This is not a battle royale yet. There is no loot, zone, plane, knock/revive, ranked queue, cosmetics, clans, or framework dependency.

## Resources

| Resource | Role |
| --- | --- |
| `wtbg_core` | Session state, lobby spawn, shared config, player cleanup |
| `wtbg_party` | Server-authoritative party membership and invites |
| `wtbg_match` | Match manager, routing buckets, teams, winner detection |
| `wtbg_combat` | Loadout, validated death handling, kill tracking |
| `wtbg_ui` | Lobby overlay, party panel, squad HUD, kill feed, result screen |

## Install

This folder is txAdmin / FXServer **server-data** (not the FXServer binaries).

1. Point txAdmin at this folder, or run FXServer from this directory with `+exec server.cfg`.
2. OneSync is already enabled in `server.cfg`.
3. Do not start ESX, QBCore, or Qbox with this stack.
4. Resource start order lives in `resources.cfg`.

`chat`, `sessionmanager`, `hardcap`, and `rconlog` come from the FXServer artifact. Spawnmanager stays started; `wtbg_core` disables auto-spawn.

Restart the server after changing `[wtbg]`.

## Config

`resources/[wtbg]/wtbg_core/shared/config.lua`

- `LobbyCoords`, `MatchSpawnPoints`
- `MaxPlayers`, `MinPlayers`
- `StartingHealth`, `StartingArmor`, `Loadout`
- `ResultDuration`, `StartCountdown`
- `PedModel` (`mp_m_freemode_01` or `mp_f_freemode_01`)
- `PartyMaxSize` (4)
- `PartyInviteTimeout` (30 seconds)
- `SquadSize` (4)
- `FriendlyFire` (false)
- `MatchMode` (`SQUAD` or `FFA`)

`SQUAD`: a party joins as one team. Solos get their own team. Last alive team wins.

`FFA`: each player is their own team. Last alive player still wins through the same team logic.

## Dev commands

Work when `Config.Debug = true`, or ACE `wtbg.dev` for match commands. Party commands are available in-game.

### Match

| Command | Action |
| --- | --- |
| `/creatematch` | Create a waiting match. Party leader brings the whole party. |
| `/joinmatch [id]` | Solo joins alone. Party leader joins the whole party. Members cannot join. |
| `/startmatch [id]` | Start (needs 2 players and 2 teams) |
| `/leavematch` | Leave. During ACTIVE this counts as elimination. |
| `/matches` | List matches |

F6: Create / Join / Start / Leave.

### Party

| Command | Action |
| --- | --- |
| `/partyinvite [serverId]` | Invite. Creates a party if you do not have one. |
| `/partyaccept [partyId]` | Accept invite |
| `/partydecline [partyId]` | Decline invite |
| `/partyleave` | Leave party. Leader is transferred if needed. |
| `/partykick [serverId]` | Leader kick |
| `/partypromote [serverId]` | Leader promote |
| `/party` | Print current party |

## Squad rules

- Max party size 4.
- Only the leader invites, kicks, promotes, and joins/creates matches for the party.
- Party join into a match is atomic. If any member cannot join, nobody joins.
- Same `teamId` for the whole party in `SQUAD` mode.
- Friendly fire off by default. Same-team kills do not award credit.
- Party survives match cleanup. Match `teamId` is cleared. `partyId` remains.

## Server API

`wtbg_core`

- `GetPlayerState(source)` (includes `matchId`, `teamId`, `partyId`)
- `GetPlayerMatch(source)`
- `GetPlayerPartyId(source)`
- `IsPlayerAlive(source)`
- `SendToLobby(source)`
- `SetParty(source, partyId)`

`wtbg_party`

- `GetParty(partyId)`
- `GetPlayerParty(source)`
- `IsLeader(source)`
- `CreateParty(source)`
- `InvitePlayer(source, target)`
- `AcceptInvite(source, partyId)`
- `DeclineInvite(source, partyId)`
- `LeaveParty(source)`
- `KickMember(source, target)`
- `PromoteLeader(source, target)`
- `DisbandParty(source)`

`wtbg_match`

- `GetMatch(matchId)`
- `CreateMatch(source)`
- `JoinMatch(source, matchId)`
- `LeaveMatch(source)`
- `StartMatch(source, matchId)`
- `ReportDeath(victim, killer, weapon)`
- `ListMatches()`

Returned tables are copies. Gameplay state is not taken from the client.

## Testing

### Party

1. A invites B (`/partyinvite [id]`).
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

### Edge cases

- Party full, duplicate invite, expired invite, invite self
- Member tries `/joinmatch` (rejected)
- Leader disconnect, member disconnect
- Disconnect during ACTIVE match (counts as elimination)
- Whole squad eliminated, solo joining a squad match
- Duplicate death, `/leavematch` while ACTIVE
- Resource restart returns players to lobby; parties reset with the resource

## Known limitations

- No spectate camera. Dead players stay down / locked out.
- No knock / revive, loot, zone, vehicles, plane, or persistence.
- No auto squad fill.
- Party and match results are in-memory only.
- Dev commands are not a public matchmaking UI.
- This repo does not include FXServer binaries. Use txAdmin or a local artifact build.

## Next milestone

**M3 - Loot / Knock / Revive / Zone**

Then:

- M4 Plane / Drop / Vehicles / Spectate
- M5 Stats / Ranked / Leaderboard
- M6 Cosmetics / Battle Pass / Tournament tools
