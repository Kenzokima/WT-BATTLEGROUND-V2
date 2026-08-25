local errors = {
    invalid = 'Invalid player or party.',
    self = 'You cannot invite yourself.',
    offline = 'That player is not online.',
    in_match = 'Cannot do that during a match.',
    target_in_party = 'That player is already in a party.',
    already_in_party = 'You are already in a party.',
    already_invited = 'They already have a pending invite.',
    not_leader = 'Only the party leader can do that.',
    not_found = 'Party does not exist.',
    full = 'The party is full.',
    no_invite = 'No pending invite.',
    not_in_party = 'You are not in a party.',
    not_member = 'That player is not in your party.',
    no_session = 'Session is not ready.'
}

local function tell(source, message)
    exports.wtbg_core:Notify(source, message)
end

local function fail(source, err)
    tell(source, errors[err] or 'Cannot do that.')
end

RegisterNetEvent('wtbg:party:invite', function(target)
    local source = tonumber(source)
    local ok, err = WTBG.Party.Invite(source, target)
    if not ok then
        fail(source, err)
    end
end)

RegisterNetEvent('wtbg:party:accept', function(partyId)
    local source = tonumber(source)
    local ok, err = WTBG.Party.Accept(source, partyId)
    if not ok then
        fail(source, err)
    end
end)

RegisterNetEvent('wtbg:party:decline', function(partyId)
    local source = tonumber(source)
    local ok, err = WTBG.Party.Decline(source, partyId)
    if not ok then
        fail(source, err)
    end
end)

RegisterCommand('partyinvite', function(source, args)
    if source == 0 then
        return
    end

    local ok, err = WTBG.Party.Invite(source, args[1])
    if not ok then
        fail(source, err)
    end
end, false)

RegisterCommand('partyaccept', function(source, args)
    if source == 0 then
        return
    end

    local ok, err = WTBG.Party.Accept(source, args[1])
    if not ok then
        fail(source, err)
    end
end, false)

RegisterCommand('partydecline', function(source, args)
    if source == 0 then
        return
    end

    local ok, err = WTBG.Party.Decline(source, args[1])
    if not ok then
        fail(source, err)
    end
end, false)

RegisterCommand('partyleave', function(source)
    if source == 0 then
        return
    end

    local ok, err = WTBG.Party.Leave(source)
    if not ok then
        fail(source, err)
    end
end, false)

RegisterCommand('partykick', function(source, args)
    if source == 0 then
        return
    end

    local ok, err = WTBG.Party.Kick(source, args[1])
    if not ok then
        fail(source, err)
    end
end, false)

RegisterCommand('partypromote', function(source, args)
    if source == 0 then
        return
    end

    local ok, err = WTBG.Party.Promote(source, args[1])
    if not ok then
        fail(source, err)
    end
end, false)

RegisterCommand('party', function(source)
    if source == 0 then
        return
    end

    local party = WTBG.Party.GetPlayerParty(source)
    if not party then
        tell(source, 'You are not in a party.')
        return
    end

    tell(source, ('Party %s  %s/%s'):format(party.id, party.size, party.maxSize))
    for i = 1, #party.members do
        local member = party.members[i]
        local tag = member.leader and 'LEADER' or 'MEMBER'
        tell(source, ('  %s  [%s]  %s'):format(member.name, member.source, tag))
    end
end, false)
