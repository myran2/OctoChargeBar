local addonName = select(1, ...)
local addon = select(2, ...)

local Data = addon.Data
local ChargeBar = addon.ChargeBar
local Util = addon.Util
local LEM = LibStub('LibEditMode')

local Core = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
addon.Core = Core

function Core:OnInitialize()
    Data:InitDB()
    Core.chargeBars = {}
end

function Core:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self:RegisterEvent("SPELL_UPDATE_CHARGES")

    LEM:RegisterCallback('enter', function()
        self:onEnterEditMode()
    end)
    LEM:RegisterCallback('exit', function()
        self:onExitEditMode()
    end)
    LEM:RegisterCallback('layout', function(layoutName)
        self:SetupBars(layoutName)
    end)
end

function Core:OnDisable()
    self:UnregisterAllEvents()
end

function Core:SPELL_UPDATE_CHARGES(event)
    for spellId, chargeBar in pairs(Core.chargeBars) do
        chargeBar:HandleSpellUpdateCharges()
    end
end

function Core:PLAYER_ENTERING_WORLD(event, isLogin, isReload)
    if InCombatLockdown() then return end

    -- Possible that we can run this too early on initial login, so we delay a second in those cases.
    C_Timer.After(isLogin and 1 or 0, function()
        for spellId, chargeBar in pairs(Core.chargeBars) do
            chargeBar:SetupCharges()
        end
    end)
end

function Core:TRAIT_CONFIG_UPDATED(event, configId)
    if InCombatLockdown() then return end

    for i, chargeBar in pairs(Core.chargeBars) do
        chargeBar:Init()
        chargeBar:HandleSpellUpdateCharges()
    end
end

function Core:SetupBars(layoutName)
    local specId = Util:GetActiveSpecId()

    Data.db.global[layoutName] = Data.db.global[layoutName] or {}
    Data.db.global[layoutName][specId] = Data.db.global[layoutName][specId] or {specBars = {}}

    local specBarSettings = Data.db.global[layoutName][specId].specBars

    -- pull default spells and add to SV if missing for this spec.
    for _, spellId in pairs(Data.defaultTrackedSpellsBySpec[specId]) do
        if not specBarSettings[spellId] then
            print('setting up spec bar for', spellId)
            local settings = Util:TableCopy(Data.defaultBarSettings)
            settings.spellId = spellId
            specBarSettings[spellId] = settings
        end
    end

    -- setup bars from SV
    for _, barSettings in pairs(specBarSettings) do
        local chargeBar = ChargeBar:Init(barSettings)
        Core.chargeBars[chargeBar.spellId] = chargeBar
    end
end

function Core:onEnterEditMode()
    -- show everything even if disabled
    for i, chargeBar in pairs(Core.chargeBars) do
        chargeBar:Show()
    end
end

function Core:onExitEditMode()
    for spellId, chargeBar in pairs(Core.chargeBars) do
        local settings = Data:GetActiveLayoutBarSettings(chargeBar.spellId)
        chargeBar:Init(settings)
    end
end
