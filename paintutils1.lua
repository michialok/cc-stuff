local tColourLookup = {}
for n = 1, 16 do
    tColourLookup[string.byte("0123456789abcdef", n, n)] = 2 ^ (n - 1)
end

local function parseLine(tImageArg, sLine)
    local tLine = {}
    
    for x = 1, sLine:len() do
        tLine[x] = tColourLookup[string.byte(sLine, x, x)] or 0
    end

    table.insert(tImageArg, tLine)
end

function parseImage(image)
    local tImage = {}

    -- OLD
    --for sLine in (image.."\n"):gmatch("(.-)\n") do
    --    parseLine(tImage, sLine)
    --end

    for sLine in string.gmatch(image.."/", "([^/]+)") do
        parseLine(tImage, sLine)
    end
    
    return tImage
end