-------------------------------------------------------------------------------
-- init

aura_env.bracketConstants = {
    -- A map from the index into 'aura_env.config.brackets' to the display name
    -- and the bracket index to be passed to 'GetPersonalRatedInfo'.

    [1] = { ["name"] = "2v2",   ["bracketIndex"] = 1 },
    [2] = { ["name"] = "3v3",   ["bracketIndex"] = 2 },
    [3] = { ["name"] = "10v10", ["bracketIndex"] = 4 }
}

RequestRatedInfo()

-------------------------------------------------------------------------------
-- trigger

function()
    return true
end

-------------------------------------------------------------------------------
-- untrigger

function()
    return false
end

-------------------------------------------------------------------------------
-- name

function()
    local output = ""

    for k, v in pairs(aura_env.config.brackets) do
        if v then
            local bracketConstants = aura_env.bracketConstants[k]
            local currentRating, _ = GetPersonalRatedInfo(bracketConstants.bracketIndex)

            if currentRating ~= 0 or aura_env.config.showZeroes then
                output = output .. "\n" .. bracketConstants.name .. ": " .. currentRating
            end
        end
    end

    return output
end
