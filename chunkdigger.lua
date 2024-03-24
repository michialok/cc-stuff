local WHITELIST = {
    "minecraft:coal",
    "minecraft:deepslate_iron_ore",
    "minecraft:iron_ore",
    "minecraft:redstone",
    "minecraft:diamond",
    "minecraft:emerald",
    "minecraft:gold_ore",
    "minecraft:deepslate_gold_ore",
}

function table.find(haystack, needle)
    for i, v in pairs(haystack) do
        if v == needle then
            return i
        end
    end
end

local function checkSlots()
    for slot = 1, 16 do
        local currentSlot = turtle.getItemDetail(slot)

        if type(currentSlot) == "table" and currentSlot.name then
            if not table.find(WHITELIST, currentSlot.name) then
                turtle.select(slot)
                turtle.drop()
            end
        end
    end
end

local chunkWidth = 16

local BLOCK_X = 4
local BLOCK_Z = 4


local turnRight = true

local function turn()
    if turnRight then
        turtle.turnRight()
    else
        turtle.turnLeft()
    end
end

local y_level = 0

repeat
    for Z = 1, BLOCK_Z do
        for X = 1, BLOCK_X do
            if X ~= BLOCK_X then
                turtle.dig()
            end
            turtle.digDown()
            turtle.forward()
        end

        if Z ~= BLOCK_Z then
            turn()
            turtle.dig()
            turtle.forward()
            turn()
            turtle.dig()
        end

        checkSlots()

        turnRight = not turnRight
    end
    turnRight = not turnRight

    local success = false

    for i = 1, 4 do
        if i <= 2 then
            turtle.digDown()
            local downResult = turtle.down()
            success = success or downResult
        elseif i > 2 then
            turn()
        end
    end

    if not success then
        break
    end
until turtle.getFuelLevel() < BLOCK_X * BLOCK_Z