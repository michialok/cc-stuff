local chests = {}

local totalSpace = 0
local currentOccupied = 0

local PREFIX = ""

local CONFIG = {
    APPROX_CHEST_SPACE = true, -- instead of checking the actual item limit it just assumes everything takes up a stack
}

function math.clamp(x, min, max)
    if x > max then
        return max
    elseif x < min then
        return min
    else
        return x
    end
end

function string.split(inputstr, sep)
    if not sep then
        sep = "%s"
    end

    local result = {}

    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(result, str)
    end

    return result
end

function table.clone(t)
    local newt = {}

    for i, v in pairs(newt) do
        newt[i] = v
    end

    return newt
end

function table.length(t)
    local c = 0

    for _ in pairs(t) do
        c = c + 1
    end

    return c
end

local function getBooleanFromString(string)
    if string:lower() == "true" then
        return true
    elseif string:lower() == "false" then
        return false
    end

    return string
end

-- .list() format: {[slot]: {name: string, count: number}}
local function getItems(chestName)
    local list = chests[chestName].list()

    local items = {}

    for slot, slotInfo in pairs(list) do
        if not items[slotInfo.name] then
            items[slotInfo.name] = {
                count = 0,
                slots = {},
            }
        end
        items[slotInfo.name].count = items[slotInfo.name].count + slotInfo.count
        table.insert(items[slotInfo.name].slots, slot)
    end

    return items
end

local function getAllItems()
    local allItems = {}

    for chestName in pairs(chests) do
        local list = getItems(chestName)
        -- lv list format: {[itemName]: {slots: {number}, count: number}}

        for itemName, itemInfo in pairs(list) do
            if not allItems[itemName] then
                allItems[itemName] = {
                    count = 0,
                    chests = {}
                }
            end
            allItems[itemName].count = allItems[itemName].count + itemInfo.count
            allItems[itemName].chests[chestName] = itemInfo.slots
        end
    end

    return allItems
end

local IOChest = peripheral.wrap("minecraft:chest_1")

local function prettyItemRead(itemName)
    local str = itemName:match(".+:(.+)")
    return str
end

local function initializeChests()
    chests = {}

    for _, name in pairs(peripheral.getNames()) do
        if name:find("quark:variant_chest") then
            local peripheralChest = peripheral.wrap(name)
            chests[name] = peripheralChest
        end
    end
end

local function checkTotalSpace()
    totalSpace = 0

    for _, peripheralChest in pairs(chests) do
        local chestTotalSpace = 0

        if CONFIG.APPROX_CHEST_SPACE then
            chestTotalSpace = peripheralChest.size() * 64
        else
            for i = 1, peripheralChest.size() do
                chestTotalSpace = peripheralChest.getItemLimit(i)
            end
        end

        totalSpace = totalSpace + chestTotalSpace
    end
end

local function checkOccupation()
    -- allItems format: {[itemName]: {count: number, chests: {[chestName]: {slotNumber}}}}
    local list = getAllItems()

    currentOccupied = 0

    for itemName, itemInfo in pairs(list) do
        currentOccupied = currentOccupied + itemInfo.count
    end

    return currentOccupied
end

local function search(inputString)
    local list = getAllItems()

    local found = {}

    for itemName, itemInfo in pairs(list) do
        if itemName:find(inputString) then
            found[itemName] = itemInfo
        end
    end

    return found
end

local function pushAll()
    local allItems = getAllItems()

    local IOContentList = IOChest.list()

    local totalCountLocal = 0
    for slot, itemInfo in pairs(IOContentList) do
        totalCountLocal = totalCountLocal + itemInfo.count
    end

    -- allItems format: {[itemName]: {count: number, chests: {[chestName]: {slotNumber}}}}

    for slot, itemInfo in pairs(IOContentList) do
        local countLocal = itemInfo.count
        if allItems[itemInfo.name] then
            for chestName, slots in pairs(allItems[itemInfo.name].chests) do
                local transferredItemsA = 0

                for _, toSlot in pairs(slots) do
                    transferredItemsA = IOChest.pushItems(chestName, slot, nil, toSlot)
                end

                countLocal = countLocal - transferredItemsA
                totalCountLocal = totalCountLocal - transferredItemsA

                if countLocal <= 0 then
                    break
                end
            end

            if countLocal ~= 0 then
                for chestName, peripheralChest in pairs(chests) do
                    local transferredItemsB = IOChest.pushItems(chestName, slot)
                    countLocal = countLocal - transferredItemsB
                    totalCountLocal = totalCountLocal - transferredItemsB
                end
            end
        else
            for chestName in pairs(chests) do
                local transferredItems = IOChest.pushItems(chestName, slot)
                totalCountLocal = totalCountLocal - transferredItems

                if totalCountLocal <= 0 then
                    break
                end
            end
        end
    end
    return totalCountLocal
end

local function pull(itemName, amount)
    local allItems = getAllItems()

    -- allItems format: {[itemName]: {count: number, chests: {[chestName]: {slotNumber}}}}

    if allItems[itemName] then
        local countLeft = math.clamp(amount or 1, 0, allItems[itemName].count)

        print(countLeft)

        for chestName, slots in pairs(allItems[itemName].chests) do
            for _, slot in pairs(slots) do
                local transferredItems = IOChest.pullItems(chestName, slot, math.min(countLeft, chests[chestName].getItemDetail(slot).count))
                print(transferredItems)
                countLeft = countLeft - transferredItems

                if countLeft <= 0 then
                    break
                end
            end

            if countLeft <= 0 then
                break
            end
        end
    end
end

local returnTypes = {
    ERROR = "ERR: ",
    MSG = "",
    WARN = "WARN: ",
}

local function getReturnMessage(type, message)
    return "> "..string.format("%s%s", type, message)
end

local commands
commands = {
    ["pushall"] = {
        Description = "IOChest",
        Use = "pushall",
        Aliases = {
            "store",
            "push",
        },
        Function = pushAll,
    },
    ["search"] = {
        Description = "List Items",
        Use = "search <itemName:string> <page:number?>",
        Aliases = {
            "list",
        },
        Function = function(args)
            if not args[1] then
                return getReturnMessage(returnTypes.ERROR, "NO ITEM NAME")
            end

            local foundItems = search(args[1])

            local list = {}
            
            for itemName, itemInfo in pairs(foundItems) do
                table.insert(list, {itemName, itemInfo.count})
            end

            if #list == 0 then
                return getReturnMessage(returnTypes.MSG, "NO ITEMS FOUND")
            end

            table.sort(list, function(a,b)
                return a[2] > b[2]
            end)

            local displayString = ""

            local PAGE_SIZE = 10
            local PAGE = (tonumber(args[2]) or 1)

            if PAGE * PAGE_SIZE > #list then
                PAGE = math.ceil(#list / 10)
            end

            for i = (PAGE - 1) * PAGE_SIZE + 1, PAGE * PAGE_SIZE do
                if not list[i] then
                    break
                end
                displayString = displayString.. string.format("- %s: %d\n", prettyItemRead(list[i][1]), list[i][2])
            end
            displayString = displayString.. string.format("-- PAGE %d/%d", PAGE, math.ceil(#list / 10))

            return displayString
        end,
    },
    ["pull"] = {
        Description = "IOChest",
        Use = "pull <itemName:string> <amount:number>",
        Aliases = {
            "get",
        },
        Function = function(args)
            if not args[1] then
                return getReturnMessage(returnTypes.ERROR, "NO ITEM NAME")
            elseif not args[2] then
                return getReturnMessage(returnTypes.ERROR, "NO AMOUNT GIVEN")
            end

            local allItems = getAllItems()

            local selectedItem = nil

            if not allItems[args[1]:lower()] then
                for itemName, itemInfo in pairs(allItems) do
                    if itemName:match(".+:(.+)") == itemName then
                        selectedItem = itemName
                        break
                    end
                end

                if not selectedItem then
                    for itemName, itemInfo in pairs(allItems) do
                        if itemName:find(args[1]) then
                            selectedItem = itemName
                            break
                        end
                    end
                end
            else
                selectedItem = args[1]:lower()
            end

            if not selectedItem then
                return getReturnMessage(returnTypes.ERROR, "NO ITEM FOUND")
            end

            io.write(string.format("%s? (y/n): ", selectedItem))
            local r = read():lower()

            if r == "y" then
                pull(selectedItem, tonumber(args[2]))
            end
        end,
    },
    ["terminate"] = {
        Description = "Terminates the program",
        Use = "",
        Aliases = {
            "stop",
            "exit",
            "quit",
            "break"
        },
        Function = function()
            print("> Bye bye!")
            return "__FORCE_QUIT_PROGRAM__"
        end,
    },
    ["commands"] = {
        Description = "Shows you all commands",
        Use = "",
        Aliases = {
            "cmds",
            "help",
        },
        Function = function()
            local resultString = ""

            for commandName, commandInfo in pairs(commands) do
                resultString = resultString.. string.format("> %s [%s] - %s\n", commandName, commandInfo.Use, commandInfo.Description)
            end

            return resultString
        end,
    },
    ["totalspace"] = {
        Description = "Total space of storage",
        Use = "",
        Aliases = {
            "total",
            "totalstorage"
        },
        Function = function()
            print("> Please wait while it's counting your storage.")
            checkTotalSpace()

            return getReturnMessage(returnTypes.MSG, totalSpace)
        end,
    },
    ["occupiedspace"] = {
        Description = "Occupied space",
        Use = "",
        Aliases = {
            "occupied",
        },
        Function = function()
            print("> Please wait while it's counting your occupied space.")
            checkOccupation()

            return getReturnMessage(returnTypes.MSG, string.format("%s/%s -> %.2f%%", currentOccupied, totalSpace, (currentOccupied/(totalSpace == 0 and 1 or totalSpace))*100))
        end,
    },
}

local function searchForCommands(inputString)
    local foundCommands = {}

    for commandName, commandInfo in pairs(commands) do
        if commandName:find(inputString) then
            table.insert(foundCommands, {
                Name = commandName,
            })
        end
    end

    return foundCommands
end

local function initializeCommandLine()
    local function executeCommand(command, args)
        for commandName, commandInfo in pairs(commands) do
            if commandName == command then
                return commandInfo.Function(args)
            end
            for _, alias in pairs(commandInfo.Aliases) do
                if alias == command then
                    return commandInfo.Function(args)
                end
            end
        end
    end

    while true do
        io.write(">> ")
        local input = read():lower()

        local newInput = input

        if PREFIX ~= "" and PREFIX ~= nil then
            newInput = newInput:sub(2, #newInput)
        end

        local splits = string.split(newInput)

        local command, args = splits[1], nil

        table.remove(splits, 1)

        args = table.pack(splits)[1]

        local result = executeCommand(command, args)

        if result then
            if result == "__FORCE_QUIT_PROGRAM__" then
                break
            else
                print(result)
            end
        end
    end
end

local function readConfig()
    local config = fs.open("_CONFIG/config.txt", "r")
    local configContent = config.readAll()

    if not configContent or #(configContent:gsub("%s","")) == 0 then
        return CONFIG
    end

    local splits

    if configContent:find(";") then
        splits = string.split(configContent, ";")
    else
        splits = {configContent}
    end
    
    local configTable = {}

    for _, str in pairs(splits) do
        local configName, configValue = string.match(str, "(.+):(.+)")
        configTable[configName or "N/A"] = getBooleanFromString(configValue)
    end

    config.close()

    if table.length(configTable) == 0 then
        return CONFIG
    end

    for configName, configValue in pairs(CONFIG) do
        if not configTable[configName] then
            configTable[configName] = configValue
        end
    end

    return configTable
end

local function startOS()
    if not fs.find("_CONFIG")[1] then
        shell.run("mkdir _CONFIG")
        local configFile = fs.open("_CONFIG/config.txt", "w")
        configFile.write("")
        configFile.close()
    end

    local changeConfigBool = nil
    repeat
        io.write("Change config? (y/n): ")
        local changeConfig = read():lower()

        if changeConfig == "y" then
            changeConfigBool = true
        elseif changeConfig == "n" then
            changeConfigBool = false
        end
    until changeConfigBool ~= nil

    local curConfig = readConfig()

    if changeConfigBool then
        while true do
            print("'exit' - exit; <name> <value> - edit")
            for i, v in pairs(curConfig) do
                print(string.format("%s: %s", i, v))
            end
            local commandLine = read()

            if commandLine:lower() == "exit" then
                local saveChanges
                repeat
                    io.write("Save Changes? (y/n/c):")
                    local input = read():lower()

                    if input == "c" then
                        break
                    else
                        if input == "y" then
                            saveChanges = true
                        elseif input == "n" then
                            saveChanges = false
                        end
                    end
                until saveChanges ~= nil
                
                if saveChanges then
                    local encodedString = nil

                    for i, v in pairs(curConfig) do
                        if encodedString ~= nil then
                            encodedString = encodedString..";"..string.format("%s:%s",i, v)
                        else
                            encodedString = string.format("%s:%s",i, v)
                        end
                    end

                    local configFile = fs.open("_CONFIG/config.txt", "w")
                    configFile.write(encodedString)
                    configFile.close()
                end

                if saveChanges ~= nil then
                    break
                end
            else
                local args = string.split(commandLine)
                if args[1] and args[2] then
                    if curConfig[args[1]] ~= nil then
                        if type(curConfig[args[1]]) == "boolean" and type(getBooleanFromString(args[2])) == "boolean" then
                            curConfig[args[1]] = getBooleanFromString(args[2])
                        end
                    end
                end
            end
        end
    end
    
    CONFIG = curConfig

    initializeChests()
    initializeCommandLine()
end

startOS()