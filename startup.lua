os.loadAPI("paintutils1.lua")
local monitors = {peripheral.wrap("monitor_8"),peripheral.wrap("monitor_9"),peripheral.wrap("monitor_10"),peripheral.wrap("monitor_11")}

local monitor = peripheral.find("monitor")
local soloMonitor = false -- set to true if only using 1 monitor

if soloMonitor then
    monitor.setTextScale(.5)
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    term.redirect(monitor)
else
    for _, monitor in pairs(monitors) do
        monitor.setTextScale(.5) -- gives us better resolution
        monitor.setBackgroundColor(colors.black)
        monitor.clear()
    end
end


-- 328, 162
-- each mon: 164, 81

function string.split(i, s)
    if s == nil then
        s = "%s" -- whitespace
    end

    local result = {}

    for str in string.gmatch(i, "([^"..s.."]+)") do
        table.insert(result, str)
    end

    return result
end

while true do
    local b = http.get("http://localhost:5000/get").readAll()
    
    local c = string.sub(b, 2, #b-1) -- remove the quotes at the beginning and end of the string (caused by json encoding)

    if soloMonitor then
        local img = paintutils1.parseImage(c)
        paintutils.drawImage(img, 1, 1)
    else
        -- splitting the image into monitors
        local monitorsImages = {}

        for y = 0, 1 do
            for x = 0, 1 do
                local imgResult = {}
                local splits = string.split(c, "/")

                local xF, xT = 164*x+1, 164*(x+1)
                local yF, yT = 81*y+1, 81*(y+1)

                for yc = yF, yT do
                    table.insert(imgResult, string.sub(splits[yc], xF, xT))
                end

                table.insert(monitorsImages, table.concat(imgResult, "/"))
            end
        end

        for index, monitor in pairs(monitors) do
            local img = paintutils1.parseImage(monitorsImages[index])
            term.redirect(monitor)
            paintutils.drawImage(img, 1, 1)
        end
    end

    sleep(1/15)
end