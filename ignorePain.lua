-------------------------------------------------------------------------------
-- init

local numberOfDecimalPlaces = false
if aura_env.config.numberOfDecimalPlaces == 2 then
    numberOfDecimalPlaces = 0
elseif aura_env.config.numberOfDecimalPlaces == 3 then
    numberOfDecimalPlaces = 1
elseif aura_env.config.numberOfDecimalPlaces == 4 then
    numberOfDecimalPlaces = 2
elseif aura_env.config.numberOfDecimalPlaces == 5 then
    numberOfDecimalPlaces = 3
end

aura_env.shortenNumber = function(number)

    local shortenedNumber = number

    local wasNegative = false
    if number < 0 then
        number = number * -1
        wasNegative = true
    end

    local suffix = ""
    if number >= 1000000 then
        shortenedNumber = shortenedNumber / 1000000
        suffix = "m"
    elseif number >= 1000 then
        shortenedNumber = shortenedNumber / 1000
        suffix = "k"
    end

    if not numberOfDecimalPlaces then
        if shortenedNumber >= 100 then
            shortenedNumber = string.format("%.0f", shortenedNumber)
        elseif shortenedNumber >= 10 then
            shortenedNumber = string.format("%.1f", shortenedNumber)
        elseif shortenedNumber >= 1 then
            shortenedNumber = string.format("%.2f", shortenedNumber)
        end
    else
        if number >= 1000 then
            shortenedNumber = string.format("%."..numberOfDecimalPlaces.."f", shortenedNumber)
        end
    end

    if aura_env.config.dontShortenThousands and (number >= 1000 and number < 10000) then
        if wasNegative then
            number = number * -1
        end
        return number
    else
        return shortenedNumber..suffix
    end
end

aura_env.roundPercent = function(number)
    local power = math.pow(10, aura_env.config.percentNumOfDecimalPlaces)
    return math.floor(number * power) / power
end

-------------------------------------------------------------------------------
-- trigger activation

function(triggers)
    return triggers[1]
end

-------------------------------------------------------------------------------
-- trigger1: status: UNIT_AURA:player

function(event, unit)
    if unit ~= "player" then
        return false
    end

    local currentIP = select(16, WA_GetUnitBuff("player", 190456)) or 0
    aura_env.currentIP = currentIP

    if aura_env.config.alwaysShow then
        return true
    end

    return currentIP ~= 0
end

-------------------------------------------------------------------------------
-- trigger1: untrigger

function(arg1, arg2)
    if arg1 == "UNIT_AURA" and arg2 ~= "player" then
        return false
    end

    if aura_env.config.alwaysShow then
        return false
    end

    return aura_env.currentIP == 0
end

-------------------------------------------------------------------------------
-- trigger1: duration

function()
    -- Never Surrender
    local curHP = UnitHealth("player")
    local maxHP = UnitHealthMax("player")
    local percHPMissing = (maxHP - curHP) / maxHP
    local NSPerc = aura_env.hasNeverSurrender and (1 + percHPMissing) or 1

    local currentIP = aura_env.currentIP or 0

    local descriptionAmount = GetSpellDescription(190456):match("%%.+%d")
    if descriptionAmount == nil then
        -- On game restart, the returned description is sometimes an empty
        -- string, so the match is 'nil'.  When it is, use an arbitrary,
        -- nonzero amount.
        descriptionAmount = 1
    else
        -- Note that 'string.gsub' returns two values, and 'tonumber' accepts
        -- an optional second parameter, so we do not inline the call to
        -- 'tonumber'.
        descriptionAmount = descriptionAmount:gsub("%D","")
        descriptionAmount = tonumber(descriptionAmount)
    end

    local castIP = descriptionAmount * NSPerc

    local IPCap = math.floor(castIP * 1.3)

    local additionalAbsorb = IPCap - currentIP

    -- account for a tiny bit of mathematical rounding
    if additionalAbsorb == -1 or additionalAbsorb == -2 then
        IPCap = currentIP
        additionalAbsorb = 0
    end

    local percentOfCap = currentIP / IPCap * 100
    percentOfCap = aura_env.roundPercent(percentOfCap)

    local percentOfMaxHP = currentIP / UnitHealthMax("player") * 100
    percentOfMaxHP = aura_env.roundPercent(percentOfMaxHP)

    aura_env.calc = {}
    aura_env.calc.currentIP = currentIP
    aura_env.calc.castIP = castIP
    aura_env.calc.IPCap = IPCap
    aura_env.calc.percentOfCap = percentOfCap
    aura_env.calc.additionalAbsorb = additionalAbsorb
    aura_env.calc.percentOfMaxHP = percentOfMaxHP

    return percentOfCap, 100, true
end

-------------------------------------------------------------------------------
-- trigger2: status: PLAYER_TALENT_UPDATE

function()
    aura_env.hasNeverSurrender = select(4, GetTalentInfoByID(22384, 1))
end

-------------------------------------------------------------------------------
-- custom text

function()
    if not aura_env.calc then
        return "", ""
    end

    local currentIP = aura_env.calc.currentIP
    local castIP = aura_env.calc.castIP
    local IPCap = aura_env.calc.IPCap
    local percentOfCap = string.format("%."..aura_env.config.percentNumOfDecimalPlaces.."f%%", aura_env.calc.percentOfCap)
    local additionalAbsorb = aura_env.calc.additionalAbsorb
    local percentOfMaxHP = string.format("%."..aura_env.config.percentNumOfDecimalPlaces.."f%%", aura_env.calc.percentOfMaxHP)

    if aura_env.config.shortenText then
        currentIP = aura_env.shortenNumber(currentIP)
        additionalAbsorb = aura_env.shortenNumber(additionalAbsorb)
    end

    local text1 = ""

    if aura_env.config.text1 == 1 then
        text1 = currentIP
    elseif aura_env.config.text1 == 2 then
        text1 = percentOfCap
    elseif aura_env.config.text1 == 3 then
        text1 = additionalAbsorb
    elseif aura_env.config.text1 == 4 then
        text1 = percentOfMaxHP
    end

    local text2 = ""

    if aura_env.config.text2 == 1 then
        text2 = currentIP
    elseif aura_env.config.text2 == 2 then
        text2 = percentOfCap
    elseif aura_env.config.text2 == 3 then
        text2 = additionalAbsorb
    elseif aura_env.config.text2 == 4 then
        text2 = percentOfMaxHP
    end

    return text1, text2
end

-------------------------------------------------------------------------------
-- animation color

function(progress, r1, g1, b1, a1, r2, g2, b2, a2)
    if not aura_env.calc then
        return 0, 0, 0, 0
    end

    local currentIP = aura_env.calc.currentIP
    local castIP = aura_env.calc.castIP
    local IPCap = aura_env.calc.IPCap

    if currentIP + castIP <= IPCap then
        return aura_env.config.fullCastColor[1], aura_env.config.fullCastColor[2], aura_env.config.fullCastColor[3], aura_env.config.fullCastColor[4]
    elseif IPCap - currentIP > 0 then
        return aura_env.config.capColor[1], aura_env.config.capColor[2], aura_env.config.capColor[3], aura_env.config.capColor[4]
    elseif IPCap - currentIP <= 0 then
        return aura_env.config.clipColor[1], aura_env.config.clipColor[2], aura_env.config.clipColor[3], aura_env.config.clipColor[4]
    end
end
