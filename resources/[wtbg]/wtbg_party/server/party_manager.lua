WTBG.Party = {}

local parties = {}
local nextPartyId = 1
local byPlayer = {}
local invites = {}

local function maxSize()
    return Config.PartyMaxSize or 10
end

local function inviteTimeout()
    return Config.PartyInviteTimeout or 30
end

local function online(source)
    return type(GetPlayerName(source)) == 'string'
end

local function fighting(source)
    local state = exports.wtbg_core:GetPlayerState(source)
    if not state then
        return true
    end

    return state.state == WTBG.PlayerStates.MATCH
        or state.state == WTBG.PlayerStates.KNOCKED
        or state.state == WTBG.PlayerStates.DEAD
        or state.state == WTBG.PlayerStates.RESULT
end

local function snapshot(party)
    if not party then
        return nil
    end

    local members = {}
    for i = 1, #party.members do
        local src = party.members[i]
        members[#members + 1] = {
            source = src,
            name = WTBG.PlayerName(src),
            leader = src == party.leader
        }
    end

    return {
        id = party.id,
        leader = party.leader,
        size = #party.members,
        maxSize = maxSize(),
        members = members
    }
end

local function setMembership(source, partyId)
    byPlayer[source] = partyId
    exports.wtbg_core:SetParty(source, partyId)
end

local function sync(party)
    local data = snapshot(party)
    for i = 1, #party.members do
        TriggerClientEvent('wtbg:ui:party', party.members[i], data)
    end
end

local function clearUi(source)
    TriggerClientEvent('wtbg:ui:party', source, nil)
    TriggerClientEvent('wtbg:ui:partyInvite', source, nil)
end

local function notify(source, message)
    exports.wtbg_core:Notify(source, message)
end

local function removeInvite(target)
    invites[target] = nil
    TriggerClientEvent('wtbg:ui:partyInvite', target, nil)
end

local function memberIndex(party, source)
    for i = 1, #party.members do
        if party.members[i] == source then
            return i
        end
    end
    return nil
end

local function destroyParty(partyId)
    local party = parties[partyId]
    if not party then
        return
    end

    for i = 1, #party.members do
        local src = party.members[i]
        setMembership(src, nil)
        clearUi(src)
    end

    for target, inv in pairs(invites) do
        if inv.partyId == partyId then
            removeInvite(target)
        end
    end

    parties[partyId] = nil
    WTBG.Debug('party destroyed', partyId)
end

local function nextLeader(party, except)
    for i = 1, #party.members do
        local src = party.members[i]
        if src ~= except and online(src) then
            return src
        end
    end
    return nil
end

function WTBG.Party.Get(partyId)
    return snapshot(parties[tonumber(partyId)])
end

function WTBG.Party.GetPlayerParty(source)
    source = tonumber(source)
    local partyId = byPlayer[source]
    if not partyId then
        return nil
    end

    return snapshot(parties[partyId])
end

function WTBG.Party.IsLeader(source)
    source = tonumber(source)
    local party = parties[byPlayer[source]]
    return party ~= nil and party.leader == source
end

function WTBG.Party.Create(source)
    source = tonumber(source)
    if not source or not online(source) then
        return nil, 'invalid'
    end

    if byPlayer[source] then
        return nil, 'already_in_party'
    end

    local state = exports.wtbg_core:GetPlayerState(source)
    if not state then
        return nil, 'no_session'
    end

    local id = nextPartyId
    nextPartyId = nextPartyId + 1

    local party = {
        id = id,
        leader = source,
        members = { source },
        createdAt = os.time()
    }

    parties[id] = party
    setMembership(source, id)
    sync(party)
    WTBG.Debug('party created', id, source)
    return id, nil
end

function WTBG.Party.Invite(source, target)
    source = tonumber(source)
    target = tonumber(target)

    if not source or not target then
        return false, 'invalid'
    end

    if source == target then
        return false, 'self'
    end

    if not online(target) then
        return false, 'offline'
    end

    if fighting(source) or fighting(target) then
        return false, 'in_match'
    end

    local targetState = exports.wtbg_core:GetPlayerState(target)
    if not targetState then
        return false, 'offline'
    end

    if byPlayer[target] then
        return false, 'target_in_party'
    end

    local partyId = byPlayer[source]
    if not partyId then
        local id, err = WTBG.Party.Create(source)
        if not id then
            return false, err
        end
        partyId = id
    end

    local party = parties[partyId]
    if not party then
        return false, 'not_found'
    end

    if party.leader ~= source then
        return false, 'not_leader'
    end

    if #party.members >= maxSize() then
        return false, 'full'
    end

    local existing = invites[target]
    if existing and existing.partyId == partyId then
        return false, 'already_invited'
    end

    invites[target] = {
        partyId = partyId,
        from = source,
        expires = os.time() + inviteTimeout()
    }

    TriggerClientEvent('wtbg:ui:partyInvite', target, {
        partyId = partyId,
        from = source,
        fromName = WTBG.PlayerName(source),
        timeout = inviteTimeout()
    })

    notify(target, ('%s invited you to party %s.'):format(WTBG.PlayerName(source), partyId))
    notify(source, ('Invite sent to %s.'):format(WTBG.PlayerName(target)))

    local capturedParty = partyId
    local capturedFrom = source
    SetTimeout(inviteTimeout() * 1000, function()
        local inv = invites[target]
        if not inv or inv.partyId ~= capturedParty or inv.from ~= capturedFrom then
            return
        end

        removeInvite(target)
        notify(target, 'Party invite expired.')
        if online(capturedFrom) then
            notify(capturedFrom, 'Party invite expired.')
        end
    end)

    return true, nil
end

function WTBG.Party.Accept(source, partyId)
    source = tonumber(source)
    local inv = invites[source]
    if not inv then
        return false, 'no_invite'
    end

    partyId = WTBG.ParseMatchId(partyId) or inv.partyId
    if inv.partyId ~= partyId then
        return false, 'no_invite'
    end

    if fighting(source) then
        return false, 'in_match'
    end

    if byPlayer[source] then
        return false, 'already_in_party'
    end

    local party = parties[partyId]
    if not party then
        removeInvite(source)
        return false, 'not_found'
    end

    if #party.members >= maxSize() then
        removeInvite(source)
        return false, 'full'
    end

    removeInvite(source)
    party.members[#party.members + 1] = source
    setMembership(source, partyId)
    sync(party)
    notify(source, ('Joined party %s.'):format(partyId))
    notify(party.leader, ('%s joined the party.'):format(WTBG.PlayerName(source)))
    return true, nil
end

function WTBG.Party.Decline(source, partyId)
    source = tonumber(source)
    local inv = invites[source]
    if not inv then
        return false, 'no_invite'
    end

    partyId = WTBG.ParseMatchId(partyId) or inv.partyId
    if inv.partyId ~= partyId then
        return false, 'no_invite'
    end

    local from = inv.from
    removeInvite(source)
    notify(source, 'Invite declined.')
    if online(from) then
        notify(from, ('%s declined the invite.'):format(WTBG.PlayerName(source)))
    end
    return true, nil
end

function WTBG.Party.Leave(source)
    source = tonumber(source)
    local partyId = byPlayer[source]
    if not partyId then
        return false, 'not_in_party'
    end

    local party = parties[partyId]
    if not party then
        setMembership(source, nil)
        clearUi(source)
        return true, nil
    end

    local index = memberIndex(party, source)
    if not index then
        setMembership(source, nil)
        return false, 'not_in_party'
    end

    table.remove(party.members, index)
    setMembership(source, nil)
    clearUi(source)
    notify(source, 'Left the party.')

    if #party.members == 0 then
        destroyParty(partyId)
        return true, nil
    end

    if party.leader == source then
        local leader = nextLeader(party)
        party.leader = leader
        if leader then
            notify(leader, 'You are now party leader.')
        end
    end

    sync(party)
    return true, nil
end

function WTBG.Party.Kick(source, target)
    source = tonumber(source)
    target = tonumber(target)
    if not source or not target or source == target then
        return false, 'invalid'
    end

    local party = parties[byPlayer[source]]
    if not party then
        return false, 'not_in_party'
    end

    if party.leader ~= source then
        return false, 'not_leader'
    end

    if not memberIndex(party, target) then
        return false, 'not_member'
    end

    local index = memberIndex(party, target)
    table.remove(party.members, index)
    setMembership(target, nil)
    clearUi(target)
    notify(target, 'You were kicked from the party.')
    notify(source, ('Kicked %s.'):format(WTBG.PlayerName(target)))

    if #party.members == 0 then
        destroyParty(party.id)
        return true, nil
    end

    sync(party)
    return true, nil
end

function WTBG.Party.Promote(source, target)
    source = tonumber(source)
    target = tonumber(target)
    if not source or not target or source == target then
        return false, 'invalid'
    end

    local party = parties[byPlayer[source]]
    if not party then
        return false, 'not_in_party'
    end

    if party.leader ~= source then
        return false, 'not_leader'
    end

    if not memberIndex(party, target) then
        return false, 'not_member'
    end

    party.leader = target
    sync(party)
    notify(target, 'You are now party leader.')
    notify(source, ('Promoted %s.'):format(WTBG.PlayerName(target)))
    return true, nil
end

function WTBG.Party.Disband(source)
    source = tonumber(source)
    local party = parties[byPlayer[source]]
    if not party then
        return false, 'not_in_party'
    end

    if party.leader ~= source then
        return false, 'not_leader'
    end

    destroyParty(party.id)
    notify(source, 'Party disbanded.')
    return true, nil
end

function WTBG.Party.HandleDisconnect(source)
    source = tonumber(source)
    removeInvite(source)

    local partyId = byPlayer[source]
    if not partyId then
        return
    end

    WTBG.Party.Leave(source)
end

AddEventHandler('wtbg:core:playerDropped', function(source)
    WTBG.Party.HandleDisconnect(source)
end)

AddEventHandler('wtbg:core:returnedToLobby', function(source)
    local party = parties[byPlayer[tonumber(source)]]
    if party then
        TriggerClientEvent('wtbg:ui:party', source, snapshot(party))
    else
        clearUi(source)
    end
end)

RegisterNetEvent('wtbg:party:requestSync', function()
    local source = tonumber(source)
    local party = parties[byPlayer[source]]
    if party then
        TriggerClientEvent('wtbg:ui:party', source, snapshot(party))
    else
        clearUi(source)
    end

    local inv = invites[source]
    if inv then
        TriggerClientEvent('wtbg:ui:partyInvite', source, {
            partyId = inv.partyId,
            from = inv.from,
            fromName = WTBG.PlayerName(inv.from),
            timeout = math.max(1, inv.expires - os.time())
        })
    end
end)

exports('GetParty', function(partyId)
    return WTBG.Party.Get(partyId)
end)

exports('GetPlayerParty', function(source)
    return WTBG.Party.GetPlayerParty(source)
end)

exports('IsLeader', function(source)
    return WTBG.Party.IsLeader(source)
end)

exports('CreateParty', function(source)
    return WTBG.Party.Create(source)
end)

exports('InvitePlayer', function(source, target)
    return WTBG.Party.Invite(source, target)
end)

exports('AcceptInvite', function(source, partyId)
    return WTBG.Party.Accept(source, partyId)
end)

exports('LeaveParty', function(source)
    return WTBG.Party.Leave(source)
end)

exports('DeclineInvite', function(source, partyId)
    return WTBG.Party.Decline(source, partyId)
end)

exports('KickMember', function(source, target)
    return WTBG.Party.Kick(source, target)
end)

exports('PromoteLeader', function(source, target)
    return WTBG.Party.Promote(source, target)
end)

exports('DisbandParty', function(source)
    return WTBG.Party.Disband(source)
end)
