os.loadAPI("paintutils1.lua")
local monitorsNumbers = {8,9,10,11}
local monitors = {}

for i, v in pairs(monitorsNumbers) do
    monitors[i] = peripheral.wrap("monitor_"..v)
end

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

local lastData = nil

while true do
    local b = http.get("http://localhost:5000/get")

    if b then
        b = b.readAll()

        if b ~= lastData then
            lastData = b
            
            if soloMonitor then
                local img = paintutils1.parseImage(b)
                paintutils.drawImage(img, 1, 1)
            else
                -- splitting the image into monitors
                local monitorsImages = {}
        
                local sqrt = math.sqrt(#monitors) - 1
                for y = 0, sqrt do
                    for x = 0, sqrt do
                        local imgResult = {}
                        local splits = string.split(b, "/")
        
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
                    sleep(.05)
                end
            end
        end
    end
    
    sleep(1/15)
end
