script_author('https://www.blast.hk/members/209662/')
script_version('1.2.1')

local JsonStatus, Json = pcall(require, 'carbjsonconfig');
assert(JsonStatus, 'carbJsonConfg lib not found');

local jsonSettings = {
    x = 130,
    y = 180,
    sleepTime = 250,
}
Json.load(getWorkingDirectory() .. "\\config\\cassistant_config.json", jsonSettings);
jsonSettings()

local sampEvents = require('lib.samp.events')
local imgui = require 'mimgui'
local ffi = require 'ffi'
local faicons = require('fAwesome6')

local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local renderWindow = imgui.new.bool(false)
local isNearestCraftingBench = false

-- Константы которые удобно в случае чего заменить
local td_data = {
    categoty = {
        ['first'] = {id = -1, x = 153, y = 181},
        ['second'] = {id = -1, x = 198, y = 181},
        ['third'] = {id = -1, x = 243, y = 181},
        ['fourth'] = {id = -1, x = 289, y = 181},
        ['fifth'] = {id = -1, x = 334, y = 181},
    },

    control = {
        ['button'] = {id = -1, x = 323, y = 326},
        ['input'] = {id = -1, x = 288, y = 329},
        ['next-page'] = {id = -1, x = 222, y = 332},
        ['prev-page'] = {id = -1, x = 179, y = 332},
    },

    items = {},
}

local cData = {
    singleTip = true, -- Подсказка рядом с верстаком
    categoty_item = -1, -- Вкладка "Аксессуары"
    selected_item = -1, -- Предмет
    limit = '10', -- Крафтов за 1 раз
    page_counter = 1,
    inputed = 0,
    crafting = false,
    waitCrafting = true,
    waitInputData = true,
    moving = false,
}

local IStats = {
    completed = 0,
    maximum = 0,
    good = 0,
    bad = 0,
    elapsedTime = 0,
    animationTime = -1,
    craftTime = -1,
}

function IStats:reset()
    self.completed = 0
    self.good = 0
    self.bad = 0
    self.elapsedTime = 0
    self.animationTime = -1
    self.craftTime = -1
end

local caInfo = {
    '{ffd200}/cset [кол-во] - {ffffff}чтобы изменить кол-во крафтов за раз',
    '{ffd200}/cwait [кол-во] - {ffffff}задержка в {ffd200}милисекундах {ffffff}перед действиями. Изначально {ffd200}250 мс.',
    '{ffd200}/caupdate - {ffffff}обновить скрипт до актуальной версии',
}

function sampEvents.onSendPlayerSync(data)
    if cData.crafting and data.keysData == 1024 then -- Запрет на нажатие альта при крафте
        data.keysData = 0
    end
end

function sampEvents.onShowTextDraw(textdrawId, data)
    if cData.crafting then return true end

    -- Категория предмета
    for key, value in pairs(td_data.categoty) do
        if math.floor(data.position.x) == value.x and math.floor(data.position.y) == value.y then
            value.id = textdrawId
        end
    end

    -- Предметы
    if math.floor(data.position.x) == 162 and isInRange(data.position.y, 201, 320) then
        table.insert(td_data.items, textdrawId)
    end

    -- Элементы управления
    for key, value in pairs(td_data.control) do
        if math.floor(data.position.x) == value.x and math.floor(data.position.y) == value.y then
            value.id = textdrawId
        end
    end

    if textdrawId == td_data.control['next-page'].id then
        cData.page_counter = 1
    end
end

function sampEvents.onApplyPlayerAnimation(playerId, animLib, animName, frameDelta, loop, lockX, lockY, freeze, time)
    if (animLib == 'SCRATCHING' or animLib == 'BSKTBALL' or animLib == 'CASINO')
        and playerId == sampGetLocalPlayerId() and IStats.animationTime == -1 and isNearestCraftingBench then
        IStats.animationTime = os.clock()
    end
end

function sampEvents.onSendClickTextDraw(textdrawId)
    if cData.crafting then return true end
    
    if textdrawId == td_data.control['button'].id then
        cData.crafting = true
        if IStats.completed >= IStats.maximum then
            IStats:reset() -- Обнуляем статистику только если крафт закончился
        end
    end

    for key, value in pairs(td_data.categoty) do
        if textdrawId == value.id then
            cData.page_counter = 1
            cData.categoty_item = textdrawId
            break
        end
    end

    for key, data in pairs(td_data.items) do
        if textdrawId == data then
            cData.selected_item = textdrawId
            break
        end
    end

    if td_data.control['prev-page'].id == textdrawId then
        cData.page_counter = cData.page_counter - 1
    end

    if td_data.control['next-page'].id == textdrawId then
        cData.page_counter = cData.page_counter + 1
    end
end

function sampEvents.onSendDialogResponse(dialogId, button, listboxId, input)
    if dialogId == 8475 and not cData.crafting then
        IStats.maximum = tonumber(input)
        if tonumber(input) < tonumber(cData.limit) then
            cData.inputed = input
        else
            cData.inputed = input
            return {dialogId, button, listboxId, cData.limit}
        end
    end
end

-- Это такой пиздец вычислительных мыслей, что пускай оно работает так как есть.
-- Буду рад если меня отпинают и сделают нормально.
function sampEvents.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 8475 and cData.crafting then 
        if tonumber(cData.inputed) >= (IStats.maximum - IStats.completed) then
            if IStats.maximum - IStats.completed > tonumber(cData.limit) then
                sampSendDialogResponse(dialogId, 1, nil, cData.limit)
            else
                sampSendDialogResponse(dialogId, 1, nil, tostring(IStats.maximum - IStats.completed))
            end
            cData.waitInputData = false
            return false
        else
            sampSendDialogResponse(dialogId, 1, nil, cData.inputed)
            cData.waitInputData = false
            return false
        end
    end
end

function sampEvents.onServerMessage(color, text)
    if text:find('Вы успешно создали предмет') and not text:find('%[%d+%]') then
        if IStats.craftTime == -1 then
            IStats.craftTime = os.clock()
        end
        IStats.completed = IStats.completed + 1
        IStats.good = IStats.good + 1
        cData.waitCrafting = false
    end

    if text:find('не удалось') and text:find('шанс') and not text:find('%[%d+%]') then
        if IStats.craftTime == -1 then
            IStats.craftTime = os.clock()
        end
        IStats.completed = IStats.completed + 1
        IStats.bad = IStats.bad + 1
        cData.waitCrafting = false
    end

    if text:find('Вы прервали процесс создания предмета!') and color == -10270721 then
        cData.crafting = false
        sampAddChatMessage('{ffd200}[Инфомарция] {ffffff}Крафт был прерван', -1)
    end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil

    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true

    local iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    imgui.GetIO().Fonts:Clear()
    imgui.GetIO().Fonts:AddFontFromFileTTF('moonloader/resource/fonts/EagleSans Regular Regular.ttf', 16.0, nil, glyph_ranges)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('regular'), 16, config, iconRanges)

    SoftBlueTheme()
end)

local controlFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(control)
        control.HideCursor = true
        local chatPosition = getChatCoord()
        local sizeX, sizeY = 260, 60
        imgui.SetNextWindowPos(imgui.ImVec2(chatPosition[1] + jsonSettings.x - 10, chatPosition[2] + jsonSettings.y + 120), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.26, 0.59, 0.98, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.26, 0.59, 0.98, 0.40))


        if imgui.Begin('##controlFrame', renderWindow, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar) then
            if imgui.Button(faicons('ARROWS_UP_DOWN_LEFT_RIGHT'), imgui.ImVec2(30, 30)) then
                cData.moving = true
                sampAddChatMessage('{ffd200}[craftAssistant]: {ffffff}Нажмите {ffd200}правую кнопку мыши {ffffff}чтобы закрепить окно', -1)
            end
            imgui.SameLine()

            if imgui.Button(faicons('TRASH'), imgui.ImVec2(30, 30)) then
                cData.crafting = false
                IStats:reset()
                sampAddChatMessage('{ffd200}[craftAssistant]: {ffffff}Статистика сброшена', -1)
            end
     
            imgui.End()
        end

        imgui.PopStyleColor(4)
    end
)

local statsFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(main)
        main.HideCursor = true
        local chatPosition = getChatCoord()
        local sizeX, sizeY = 260, 200
        imgui.SetNextWindowPos(imgui.ImVec2(chatPosition[1] + jsonSettings.x, chatPosition[2] + jsonSettings.y), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        if imgui.Begin('##statsFrame', renderWindow, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar) then
            imgui.TextColoredRGB(u8('Сделано {ffd200}%d из %d'):format(IStats.completed, IStats.maximum))  
            imgui.TextColoredRGB(u8('- По {ffd200}%s {ffffff}крафтов за раз'):format(cData.limit))  
            imgui.TextColoredRGB(u8('- Успешных {8bff00}%d'):format(IStats.good))
            imgui.TextColoredRGB(u8('- Неудачных {ff0000}%d'):format(IStats.bad))
            imgui.NewLine()
            local calculatedTime = (IStats.craftTime - IStats.animationTime) < 0 and 0 or IStats.craftTime - IStats.animationTime
            IStats.elapsedTime = formatTime((calculatedTime) * (IStats.maximum - IStats.completed))
            imgui.TextColoredRGB(u8('Будет затрачено {00fbff}%s'):format(IStats.elapsedTime))

            imgui.TextColoredRGB(u8('Фактический шанс крафта {00fbff}%.2f'):format(
                (IStats.completed > 0) and (
                    (IStats.good > 0) and (100 * (IStats.good / IStats.completed)) 
                    or (-100 / IStats.completed)
                ) or 0
            ))
     
            imgui.End()
        end
    end
)

-- При разработке не пострадала ни одна аптечка.
function main()
    while not isSampAvailable() do wait(0) end

    contentManager():checkFiles()

    local serverVersion = updater():getLastVersion()
    if thisScript().version ~= serverVersion then
        updater():printChatMessage(('Вышла версия {ffd200}%s. {ffffff}Используйте команду {ffd200}/caupdate'):format(serverVersion))
    else
        sampAddChatMessage('{ffd200}[craftAssistant]: {ffffff}/chelp - список доступных команд', -1)
    end

    sampRegisterChatCommand('caupdate', function(arg)
        updater():download()    
    end)

    sampRegisterChatCommand('chelp', function(arg)
        for key, data in pairs(caInfo) do
            sampAddChatMessage(data, -1)
        end
    end)

    sampRegisterChatCommand('cwait', function(arg)
        jsonSettings.sleepTime = (arg:match('(%d+)') == nil) and 250 or arg:match('(%d+)')
        jsonSettings()
    end)

    sampRegisterChatCommand('cset', function(arg)
        cData.limit = tostring((arg:match('(%d+)') == nil) and 5 or arg:match('(%d+)'))
    end)
    
    lua_thread.create(function()
        while true do
            wait(10)
            if cData.moving then
                if isKeyDown(0x2) then
                    cData.moving = false
                    jsonSettings()
                end
                local cursorPos =  {getCursorPos()}
                jsonSettings.x = cursorPos[1]
                jsonSettings.y = cursorPos[2]
            end
        end
    end)

    lua_thread.create(function()
        while true do
            wait(0)
            if cData.crafting and (IStats.completed <= IStats.maximum) then
                cData.waitCrafting = true
                cData.waitInputData = true
                while cData.waitCrafting do wait(0) end

                -- Ждем пока вновь не появится окно крафта
                while not sampTextdrawIsExists(td_data.control['button'].id) do
                    wait(jsonSettings.sleepTime)
                end

                -- А мы уже накрафтились
                if IStats.completed >= IStats.maximum then
                    sampAddChatMessage('{ffd200}[Инфомарция] {ffffff}Крафт закончен', -1)
                    cData.crafting = false
                    goto exitThread
                end
   
                -- Выбираем категорию
                wait(jsonSettings.sleepTime)
                sampSendClickTextdraw(cData.categoty_item)

                -- Выбираем страницу
                for i = 1, cData.page_counter - 1 do
                    wait(jsonSettings.sleepTime)
                    sampSendClickTextdraw(td_data.control['next-page'].id)
                end

                -- Выбрали предмет
                wait(jsonSettings.sleepTime)
                sampSendClickTextdraw(cData.selected_item)

                -- Жмем на инпут и ждем пока данные введутся
                wait(jsonSettings.sleepTime)
                sampSendClickTextdraw(td_data.control['input'].id)
                while cData.waitInputData do
                    wait(jsonSettings.sleepTime)
                end

                wait(jsonSettings.sleepTime)
                sampSendClickTextdraw(td_data.control['button'].id)
            end
            ::exitThread::
        end
    end)


    lua_thread.create(function()
        while true do
            wait(150)
            local charPos = {getCharCoordinates(PLAYER_PED)}
            isNearestCraftingBench = Search3Dtext(charPos[1], charPos[2], charPos[3], 3, 'Чтобы воспользоваться верстаком') or Search3Dtext(charPos[1], charPos[2], charPos[3], 3, 'Переносной верстак')
            renderWindow[0] = isNearestCraftingBench

            if isNearestCraftingBench and cData.singleTip then
                cData.singleTip = false
                sampAddChatMessage('{ffd200}[Инфомарция] {ffffff}Используйте {ffd200}/cset [кол-во] {ffffff}чтобы изменить кол-во крафтов за раз', -1)
                elseif not isNearestCraftingBench then
                    cData.singleTip = true
            end
        end
    end)

    wait(-1)
end

function formatTime(seconds)
    return string.format(u8("%02d мин. %02d сек."), math.floor(seconds / 60), math.floor(seconds % 60))
end

function getChatCoord()
    if not isSampAvailable() then -- Иначе access violation скажет НЫА
        return {100, 100}
    end
    local chatInfoPtr = getStructElement(sampGetInputInfoPtr(), 0x8, 4)
    return {getStructElement(chatInfoPtr, 0x8, 4), getStructElement(chatInfoPtr, 0xC, 4)}
end

local SAMP = getModuleHandle("samp.dll")
local CPlayerPool__GetLocalPlayerName = ffi.cast("const char*(__thiscall*)(uintptr_t)", SAMP + 0xA170)
local CNetGame__GetPlayerPool = ffi.cast("uintptr_t(__thiscall*)(uintptr_t)", SAMP + 0x1160)

function sampGetLocalPlayerId()
    local pNetGame = ffi.cast("uintptr_t*", SAMP + 0x26E8DC)[0]
    local pPlayerPool = CNetGame__GetPlayerPool(pNetGame)
    return ffi.cast("uint16_t*", pPlayerPool + 0x2F1C)[0]
end

function isInRange(num, minVal, maxVal)
    return num >= minVal and num <= maxVal
end

function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local col = imgui.Col
    
    local designText = function(text__)
        local pos = imgui.GetCursorPos()
        if sampGetChatDisplayMode() == 2 then
            for i = 1, 1 --[[Степень тени]] do
                imgui.SetCursorPos(imgui.ImVec2(pos.x + i, pos.y))
                imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text__) -- shadow
                imgui.SetCursorPos(imgui.ImVec2(pos.x - i, pos.y))
                imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text__) -- shadow
                imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y + i))
                imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text__) -- shadow
                imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y - i))
                imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text__) -- shadow
            end
        end
        imgui.SetCursorPos(pos)
    end
    
    local text = text:gsub('{(%x%x%x%x%x%x)}', '{%1FF}')

    local color = colors[col.Text]
    local start = 1
    local a, b = text:find('{........}', start)   
    
    while a do
        local t = text:sub(start, a - 1)
        if #t > 0 then
            designText(t)
            imgui.TextColored(color, t)
            imgui.SameLine(nil, 0)
        end

        local clr = text:sub(a + 1, b - 1)
        if clr:upper() == 'STANDART' then color = colors[col.Text]
        else
            clr = tonumber(clr, 16)
            if clr then
                local r = bit.band(bit.rshift(clr, 24), 0xFF)
                local g = bit.band(bit.rshift(clr, 16), 0xFF)
                local b = bit.band(bit.rshift(clr, 8), 0xFF)
                local a = bit.band(clr, 0xFF)
                color = imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
            end
        end

        start = b + 1
        a, b = text:find('{........}', start)
    end
    imgui.NewLine()
    if #text >= start then
        imgui.SameLine(nil, 0)
        designText(text:sub(start))
        imgui.TextColored(color, text:sub(start))
    end
end

function SoftBlueTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
  
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 10.0
    style.ChildRounding = 6.0
    style.FramePadding = imgui.ImVec2(8, 7)
    style.FrameRounding = 8.0
    style.ItemSpacing = imgui.ImVec2(8, 8)
    style.ItemInnerSpacing = imgui.ImVec2(10, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 13.0
    style.ScrollbarRounding = 12.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 6.0
    style.PopupRounding = 8
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    local colors = style.Colors;

    colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00);
    colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.50, 0.50, 0.50, 1.00);
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.05, 0.10, 0.28, 0.90);
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.PopupBg] = imgui.ImVec4(0.05, 0.10, 0.28, 0.94);
    colors[imgui.Col.Border] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50);
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.13, 0.18, 0.38, 0.94);
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.12, 0.21, 0.53, 0.94);
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.14, 0.28, 0.83, 0.94);
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.05, 0.10, 0.28, 0.94);
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.05, 0.10, 0.28, 0.94);
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.00, 0.00, 0.00, 0.51);
    colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.53);
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.17, 0.19, 0.29, 0.94);
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.41, 0.41, 0.41, 1.00);
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.51, 0.51, 0.51, 1.00);
    colors[imgui.Col.CheckMark] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.24, 0.52, 0.88, 1.00);
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.Button] = imgui.ImVec4(0.26, 0.59, 0.98, 0.40);
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.06, 0.53, 0.98, 1.00);
    colors[imgui.Col.Header] = imgui.ImVec4(0.26, 0.59, 0.98, 0.31);
    colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.80);
    colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.Separator] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50);
    colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.10, 0.40, 0.75, 0.78);
    colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.10, 0.40, 0.75, 1.00);
    colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.05, 0.10, 0.28, 0.94);
    colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.05, 0.10, 0.28, 0.94);
    colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.05, 0.10, 0.28, 0.94);
    colors[imgui.Col.Tab] = imgui.ImVec4(0.25, 0.33, 0.63, 0.94);
    colors[imgui.Col.TabHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.80);
    colors[imgui.Col.TabActive] = imgui.ImVec4(0.20, 0.41, 0.68, 1.00);
    colors[imgui.Col.TabUnfocused] = imgui.ImVec4(0.07, 0.10, 0.15, 0.97);
    colors[imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.14, 0.26, 0.42, 1.00);
    colors[imgui.Col.PlotLines] = imgui.ImVec4(0.61, 0.61, 0.61, 1.00);
    colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(1.00, 0.43, 0.35, 1.00);
    colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.90, 0.70, 0.00, 1.00);
    colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(1.00, 0.60, 0.00, 1.00);
    colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.26, 0.59, 0.98, 0.35);
    colors[imgui.Col.DragDropTarget] = imgui.ImVec4(1.00, 1.00, 0.00, 0.90);
    colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70);
    colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.20);
    colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.35);
end

function Search3Dtext(x, y, z, radius, pattern)
    local closestText = ""
    local closestColor = 0
    local closestPosX, closestPosY, closestPosZ = 0.0, 0.0, 0.0
    local closestDistance = 0.0
    local closestIgnoreWalls = false
    local closestPlayer, closestVehicle = -1, -1
    local found = false
    local minRadius = radius
    local patternLen = string.len(pattern)

    for id = 0, 2048 do
        if not sampIs3dTextDefined(id) then goto continue end

        local text, color, posX, posY, posZ, dist, ignoreWalls, player, vehicle = sampGet3dTextInfoById(id)
        local currentDist = getDistanceBetweenCoords3d(x, y, z, posX, posY, posZ)
        
        if currentDist >= minRadius then goto continue end

        if patternLen ~= 0 and not string.match(text, pattern) then goto continue end
        
        found = true
        closestText = text
        closestColor = color
        closestPosX, closestPosY, closestPosZ = posX, posY, posZ
        closestDistance = dist
        closestIgnoreWalls = ignoreWalls
        closestPlayer, closestVehicle = player, vehicle
        minRadius = currentDist

        ::continue::
    end

    return found, closestText, closestColor, closestPosX, closestPosY, closestPosZ, closestDistance, closestIgnoreWalls, closestPlayer, closestVehicle
end


function contentManager()
    local IClass = {}

    local reqireFiles = {
        ['EagleSans Regular Regular.ttf'] = {type = 'шрифт', path = '\\resource\\fonts\\'},
        ['fAwesome6.lua'] = {type = 'библиотека', path = '\\lib\\'},
    }

    function IClass:checkFiles()
        for file, data in pairs(reqireFiles) do
            if not doesFileExist(getWorkingDirectory() .. data.path .. file) then
                sampAddChatMessage(('{de0000}[Ошибка] {ffffff}Отсутствует {ffd200}%s - {a1de00}%s'):format(data.type, file), -1)
            end
        end
    end

    function IClass:updateFile(file)
        -- TODO
    end

    return IClass
end

function updater()
    local raw = 'https://raw.githubusercontent.com/lrami90/arz_craftassistant/refs/heads/main/version.json'
    local dlstatus = require('moonloader').download_status
    local requests = require('requests')
    local f = {}

    function f:printChatMessage(data)
        sampAddChatMessage('{ffd200}[craftAssistant]: {ffffff}' .. data, -1)
    end
    function f:getLastVersion()
        local response = requests.get(raw)
        if response.status_code == 200 then
            return decodeJson(response.text)['version']
        else
            return 'UNKNOWN'
        end
    end
    function f:download()
        local response = requests.get(raw)
        if response.status_code == 200 then
            	downloadUrlToFile(decodeJson(response.text)['url'], thisScript().path, function(id, status, p1, p2)
				if status == dlstatus.STATUSEX_ENDDOWNLOAD then
					local file = io.open(thisScript().path, "rb")
					if not file then
						self:printChatMessage('{ff0000}Ошибка: не удалось открыть файл')
						return
					end

					local serverFileContent = file:read("*a")
                    file:close()
					
					local outputFile = io.open(thisScript().path, "wb")
					if not outputFile then
						self:printChatMessage('{ff0000}Ошибка: не удалось записать в файл')
						return
					end
					
					outputFile:write(u8:decode(serverFileContent)) -- Очень сильный способ починить кодировку UTF8 -> Win 1251
					outputFile:close()
					
					self:printChatMessage('Скрипт обновлен до версии {ffd200}' .. decodeJson(response.text)['version'])
					self:printChatMessage('Больше информации в теме - {00ffff}' .. decodeJson(response.text)['bh_url'])
					thisScript():reload()
				end
			end)
        else
            self:printChatMessage('Ошибка при обновлении скрипта. Код от сервера ' .. response.status_code, -1)
        end
    end
    return f
end
