local addonName = select(1, ...)
local addon = select(2, ...)

local Data = {}
addon.Data = Data

local Util = addon.Util
local LEM = addon.LibEditMode
local AceDB = LibStub('AceDB-3.0')

Data.defaultTrackedSpellsBySpec = {
    -- Death Knight: Blood
    [250] = {
        50842, -- Blood boil
        43265, -- Death and Decay
        48265, -- Death's Advance
        49576 -- Death Grip
    },

    -- Death Knight: Frost
    [251] = {
        47568, -- Empower rune weapon
        43265, -- Death and Decay
        48265, -- Death's Advance
        49576 -- Death Grip
    },

    -- Death Knight: Unholy
    [252] = {
        1247378, -- Putrefy
        43265, -- Death and Decay
        48265, -- Death's Advance
        49576 -- Death Grip
    },

    -- Demon Hunter: Havoc
    [577] = {
        195072, -- Fel Rush
        258920 -- Immolation Aura
    },

    -- Demon Hunter: Vengeance
    [581] = {
        189110, -- Infernal Strike
        204157, -- Throw Glaive
        263642, -- Fracture
        204021, -- Fiery Brand
    },

    -- Demon Hunter: Devourer
    [1480] = {
        1226019, -- Reap
        1234796, -- Shift
        198589 -- Blur
    },

    -- Druid: Balance
    [102] = {
        1233346, -- Solar Eclipse
        -- 1233272, -- Lunar Eclipse. Tracking 1 spell tracks both. I think?
    },

    -- Druid: Feral
    [103] = {},

    -- Druid: Guardian
    [104] = {
        61336, -- Survival Instincts
        22842 -- Frenzied Regeneration
    },

    -- Druid: Restoration
    [105] = {},

    -- Evoker: Devastation
    [1467] = {
        358267, -- Hover
    },

    -- Evoker: Preservation
    [1468] = {
        366155, -- Reversion
        358267, -- Hover
    },

    -- Evoker: Augmentation
    [1473] = {
        358267, -- Hover
        409311, -- Prescience
    },

    -- Hunter: Beast Mastery
    [253] = {
        34026, -- Kill Command
        217200, -- Barbed Shot
    },

    -- Hunter: Marksmanship
    [254] = {
        19434, -- Aimed Shot
    },

    -- Hunter: Survival
    [255] = {
        259495, -- Wildfire Bomb
    },

    -- Mage: Arcane
    [62] = {
        153626, -- Arcane Orb
        212653, -- Shimmer
    },

    -- Mage: Fire
    [63] = {
        108853, -- Fire Blast
        212653, -- Shimmer
    },

    -- Mage: Frost
    [64] = {
        44614, -- Flurry
        212653, -- Shimmer
    },

    -- Monk: Brewmaster
    [268] = {
        119582, -- Purifying Brew
        322507, -- Celestial Brew
        121253, -- Keg Smash
        109132, -- Roll
    },

    -- Monk: Mistweaver
    [270] = {
        115151, -- Renewing Mists
        109132, -- Roll
    },

    -- Monk: Windwalker
    [269] = {
        1249625, -- Zenith
        109132, -- Roll
    },

    -- Paladin: Holy
    [65] = {
        20473, -- Holy Shock
        190784 -- Divine Steed
    },

    -- Paladin: Protection
    [66] = {
        275779, -- Judgment
        204019, -- Blessed Hammer
        53595, -- Hammer of the Righteous
        190784 -- Divine Steed
    },

    -- Paladin: Retribution
    [70] = {
        20271, -- Judgment
        190784 -- Divine Steed
    },

    -- Priest: Discipline
    [256] = {
        194509, -- Power Word: Radiance
        121536 -- Angelic Feather
    },

    -- Priest: Holy
    [257] = {
        2050, -- Holy Word: Serenity
        121536 -- Angelic Feather
    },

    -- Priest: Shadow
    [258] = {
        8092, -- Mind Blast
        1227280, -- Tentacle Slam
        121536 -- Angelic Feather
    },

    -- Rogue: Assassination
    [259] = {
        1966, -- Feint
        381623, -- Thistle Tea
    },

    -- Rogue: Outlaw
    [260] = {
        195457, -- Grappling Hook
        381623, -- Thistle Tea
        1966 -- Feint
    },

    -- Rogue: Subtlety
    [261] = {
        1966, -- Feint,
        36554, -- Shadowstep
        185313, -- Shadow Dance
        381623 -- Thistle Tea
    },

    -- Shaman: Elemental
    [262] = {
        51505, -- Lava Burst
    },

    -- Shaman: Enhancement
    [263] = {
        17364 -- Stormstrike
    },

    -- Shaman: Restoration
    [264] = {
        61295, -- Riptide
        51505, -- Lava Burst
    },

    -- Warlock: Affliction
    [265] = {},

    -- Warlock: Demonology
    [266] = {},

    -- Warlock: Destruction
    [267] = {
        17962, -- Conflagration
    },

    -- Warrior: Arms
    [71] = {
        100, -- Charge
        7384 -- Overpower
    },

    -- Warrior: Fury
    [72] = {
        100, -- Charge
        85288 -- Raging Blow
    },

    -- Warrior: Protection
    [73] = {
        100, -- Charge
        2565 -- Shield Block
    },
}

Data.defaultSpellColors = {
    -- Lava Burst
    [51505] = {255/255, 147/255, 85/255, 1},
    -- Riptide
    [61295] = {38/255, 220/255, 1, 1}
}

function Data:InitDB()
    ---@class AceDBObject-3.0
    self.db = AceDB:New(
        addonName.."DB"
    )
end

function Data:GetLayoutBarSettings(layoutName, spellId)
    local specId = Util:GetActiveSpecId()
    assert(self.db.global[layoutName][specId].specBars[spellId], string.format("SpellId %d not found in layout '%s' settings for specId %d!", spellId, layoutName, specId))

    return self.db.global[layoutName][specId].specBars[spellId]
end

function Data:GetActiveLayoutBarSettings(spellId)
    local layoutName = LEM:GetActiveLayoutName()
    return self:GetLayoutBarSettings(layoutName, spellId)
end
