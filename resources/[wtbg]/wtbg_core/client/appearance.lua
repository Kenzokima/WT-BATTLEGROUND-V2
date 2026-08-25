function WTBG.EnableFriendlyFire()
    local ped = PlayerPedId()
    NetworkSetFriendlyFireOption(true)
    SetCanAttackFriendly(ped, true, false)
    SetPedCanBeTargetted(ped, true)
end

function WTBG.UnlockCombat()
    local ped = PlayerPedId()
    local player = PlayerId()

    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(player, false)
    SetPlayerControl(player, true, 0)
    SetPedCanRagdoll(ped, true)
    EnableAllControlActions(0)
    DisplayHud(true)
    DisplayRadar(true)
    WTBG.EnableFriendlyFire()
end

local function applyMaleDefaults(ped)
    SetPedHeadBlendData(ped, 21, 0, 0, 21, 0, 0, 0.5, 0.5, 0.0, false)
    SetPedComponentVariation(ped, 2, 4, 0, 0)
    SetPedComponentVariation(ped, 3, 0, 0, 0)
    SetPedComponentVariation(ped, 4, 1, 0, 0)
    SetPedComponentVariation(ped, 6, 1, 0, 0)
    SetPedComponentVariation(ped, 8, 15, 0, 0)
    SetPedComponentVariation(ped, 11, 14, 0, 0)
    ClearAllPedProps(ped)
end

local function applyFemaleDefaults(ped)
    SetPedHeadBlendData(ped, 21, 0, 0, 21, 0, 0, 0.5, 0.5, 0.0, false)
    SetPedComponentVariation(ped, 2, 4, 0, 0)
    SetPedComponentVariation(ped, 3, 14, 0, 0)
    SetPedComponentVariation(ped, 4, 1, 0, 0)
    SetPedComponentVariation(ped, 6, 1, 0, 0)
    SetPedComponentVariation(ped, 8, 2, 0, 0)
    SetPedComponentVariation(ped, 11, 8, 0, 0)
    ClearAllPedProps(ped)
end

function WTBG.ExpectedPedModel()
    return joaat(Config.PedModel or 'mp_m_freemode_01')
end

function WTBG.EnsureFreemodePed()
    local modelName = Config.PedModel or 'mp_m_freemode_01'
    local model = joaat(modelName)

    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        RequestModel(model)
        Wait(0)
    end

    if not HasModelLoaded(model) then
        WTBG.Debug('failed to load ped model', modelName)
        return false
    end

    if GetEntityModel(PlayerPedId()) ~= model then
        SetPlayerModel(PlayerId(), model)

        local switchTimeout = GetGameTimer() + 3000
        while GetEntityModel(PlayerPedId()) ~= model and GetGameTimer() < switchTimeout do
            SetPlayerModel(PlayerId(), model)
            Wait(50)
        end
    end

    local ped = PlayerPedId()
    if GetEntityModel(ped) ~= model then
        WTBG.Debug('failed to switch ped model', modelName)
        return false
    end

    SetPedDefaultComponentVariation(ped)
    if model == joaat('mp_f_freemode_01') then
        applyFemaleDefaults(ped)
    else
        applyMaleDefaults(ped)
    end

    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetModelAsNoLongerNeeded(model)
    WTBG.EnableFriendlyFire()
    return true
end

exports('EnsureFreemodePed', function()
    return WTBG.EnsureFreemodePed()
end)

exports('UnlockCombat', function()
    WTBG.UnlockCombat()
end)

exports('EnableFriendlyFire', function()
    WTBG.EnableFriendlyFire()
end)
