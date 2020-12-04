-------------------------------------------------------------------------------
-- init

-- "Default" tracked auras, as a map from spell ID to a non-'nil' value.  This
-- value is a "mine-only" boolean.  If the value is 'false' (or otherwise
-- "falsey"), the aura will be tracked from all sources.  Otherwise, if the
-- value is 'true' (or otherwise "truthy"), the aura will be tracked only when
-- the aura instance is cast by you (i.e., "player").

aura_env.spells = {
    -- Racial
    [65116] = false,    -- Stoneform
    [58984] = false,    -- Shadowmeld

    -- Monk
    -- Notably missing Breath of Fire and Exploding Keg (on enemies)
    [120954] = false,   -- Fortifying Brew
    [243435] = false,   -- Fortifying Brew
    [115176] = false,   -- Zen Meditation
    [122278] = false,   -- Dampen Harm
    [116849] = false,   -- Life Cocoon
    [122783] = false,   -- Diffuse Magic
    [125174] = false,   -- Touch of Karma
    [261769] = false,   -- Inner Strength
    [132578] = false,   -- Invoke Niuzo, the Black Ox

    -- Demon Hunter
    -- Notably missing Fiery Brand (on enemies)
    [187827] = false,   -- Metamorphosis
    [162264] = false,   -- Metamorphosis
    [203819] = false,   -- Demon Spikes
    [196555] = false,   -- Netherwalk
    [212800] = false,   -- Blur
    [209426] = false,   -- Darkness

    -- Warrior
    -- Notably missing Demoralizing Shout and Punish (on enemies)
    [132404] = false,   -- Shield Block
    [12975] = false,    -- Last Stand
    [871] = false,      -- Shield Wall
    [107574] = false,   -- Avatar
    [97463] = false,    -- Rallying Cry
    [18499] = false,    -- Berserker Rage
    [23920] = false,    -- Spell Reflection
    [184364] = false,   -- Enraged Regeneration
    [118038] = false,   -- Die by the Sword
    [197690] = false,   -- Defensive Stance
    [147833] = false,   -- Intervene

    -- Druid
    -- Notably missing Pulverize and Tooth and Claw (on enemies)
    [192081] = false,   -- Ironfur
    [22842] = false,    -- Frenzied Regeneration
    [22812] = false,    -- Barkskin
    [61336] = false,    -- Survival Instincts
    [102342] = false,   -- Ironbark
    [102558] = false,   -- Incarnation: Guardian of Ursoc
    [203975] = false,   -- Earthwarden
    [5215] = false,     -- Prowl
    [50334] = false,    -- Berserk

    -- Death Knight
    -- Notably missing Blooddrinker (channeled onto enemies)
    [195181] = false,   -- Bone Shield
    [48707] = false,    -- Anti-Magic Shell
    [81256] = false,    -- Dancing Rune Weapon
    [55233] = false,    -- Vampiric Blood
    [48792] = false,    -- Icebound Fortitude
    [194679] = false,   -- Rune Tap
    [194844] = false,   -- Bonestorm
    [49039] = false,    -- Lichborne
    [145629] = false,   -- Anti-Magic Zone

    -- Paladin
    [280375] = false,   -- Redoubt
    [132403] = false,   -- Shield of the Righteous
    [86659] = false,    -- Guardian of Ancient Kings
    [31850] = false,    -- Ardent Defender
    [31884] = false,    -- Avenging Wrath
    [642] = false,      -- Divine Shield
    [188370] = false,   -- Consecration
    [1022] = false,     -- Blessing of Protection
    [204018] = false,   -- Blessing of Spellwarding
    [6940] = false,     -- Blessing of Sacrifice
    [152262] = false,   -- Seraphim
    [205191] = false,   -- Eye for an Eye
    [498] = false,      -- Divine Protection

    -- Rogue
    [185311] = false,   -- Crimson Vial
    [5277] = false,     -- Evasion
    [1966] = false,     -- Feint
    [31224] = false,    -- Cloak of Shadows
    [1784] = false,     -- Stealth

    -- Mage
    -- Notably missing Mirror Image
    [45438] = false,    -- Ice Block
    [32612] = false,    -- Invisibility
    [342246] = false,   -- Alter Time
    [235450] = false,   -- Prismatic Barrier
    [11426] = false,    -- Ice Barrier (Increases armor with talent)
    [110960] = false,   -- Greater Invisibility
    [113862] = false,   -- Greater Invisibility (Damage Reduction)

    -- Hunter
    [186265] = false,   -- Aspect of the Turtle
    [5384] = false,     -- Feign Death
    [264735] = false,   -- Survival of the Fittest
    [281195] = false,   -- Survival of the Fittest
    [199483] = false,   -- Camouflage

    -- Priest
    [33206] = false,    -- Pain Suppression
    [81782] = false,    -- Power Word: Barrier
    [586] = false,      -- Fade
    [19236] = false,    -- Desperate Prayer
    [47788] = false,    -- Guardian Spirit
    [47585] = false,    -- Dispersion
    [15286] = false,    -- Vampiric Embrace
    [45242] = false,    -- Focused Will
    [193065] = false,   -- Masochism

    -- Shaman
    [108271] = false,   -- Astral Shift
    [325174] = false,   -- Spirit Link Totem
    [207498] = false,   -- Ancestral Protection
    [108281] = false,   -- Ancestral Guidance
    [207400] = false,   -- Ancestral Vigor

    -- Warlock
    [104773] = false,   -- Unending Resolve
    [132413] = false    -- Shadow Bulwark
}

-- Selectively enable/disable the defaults and the spells added in Custom
-- Options.

if not aura_env.config.enableDefaults then
    aura_env.spells = {}
end

if aura_env.config.enableAdded then
    for _,spellOption in ipairs(aura_env.config.addedSpells) do
        if spellOption.spellId ~= 0 then
            aura_env.spells[spellOption.spellId] = spellOption.mineOnly
        end
    end
end

-- Initialize an empty table mapping from unit GUIDs to their currently visible
-- states in the 'allstates' parameter.

aura_env.unitAuras = {}

-------------------------------------------------------------------------------
-- trigger: UNIT_AURA

function(allstates, event, unit)
    if unit == nil then
        return false
    end

    -- Do nothing if 'unit' is not in our group.

    if UnitInRaid(unit) == nil and not UnitInParty(unit) then
        return false
    end

    local unitGuid = UnitGUID(unit)

    -- Iterate through each of the unit's auras.  Keep track of what the return
    -- value should be and of what state IDs we've found for this occurrence of
    -- 'UNIT_AURA' for 'unit'.

    local changed = false
    local seenStateIds = {}

    for i=1,40 do
        local _, icon, stacks, _, duration, expirationTime, source, _, _, spellId = UnitAura(unit, i)
        local mineOnly = aura_env.spells[spellId]
        if mineOnly ~= nil and (not mineOnly or (source and UnitIsUnit(source, "player"))) then
            -- This spell is tracked, and it is tracked from all sources, or
            -- it is tracked only from the player, but this spell originates
            -- from the player.  Ensure that there is an entry in 'allstates'
            -- for this spell on this unit.

            local stateId = unitGuid .. ((source and UnitGUID(source)) or "") .. spellId
            seenStateIds[stateId] = true

            local state = allstates[stateId]
            if state == nil then
                state = {}
                allstates[stateId] = state

                changed = true

                state.changed = true
                state.show = true
                state.unit = unit
                state.icon = icon
                state.stacks = stacks
                state.spellId = spellId
                state.progressType = "timed"
                state.autoHide = true
                state.duration = duration
                state.expirationTime = expirationTime
            elseif state.stacks ~= stacks or state.expirationTime ~= expirationTime then
                changed = true

                state.changed = true
                state.stacks = stacks
                state.duration = duration
                state.expirationTime = expirationTime
            end
        end
    end

    -- Iterate through 'aura_env.unitAuras' to find auras for this 'unit' that
    -- were not seen for this 'UNIT_AURA' event.  Hide any such auras in
    -- 'allstates'.

    local previousSeenStateIds = aura_env.unitAuras[unitGuid]
    if previousSeenStateIds ~= nil then
        for stateId,_ in pairs(previousSeenStateIds) do
            if seenStateIds[stateId] == nil then
                local state = allstates[stateId]
                if state ~= nil then
                    changed = true

                    state.changed = true
                    state.show = false
                end
            end
        end
    end

    -- Save the seen new set of state IDs into 'aura_env.unitAuras'.

    aura_env.unitAuras[unitGuid] = seenStateIds

    return changed
end
