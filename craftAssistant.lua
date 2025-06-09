script_author('https://www.blast.hk/members/209662/')
script_version('1.0.1')

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
local encoding = require 'encoding'
local ffi = require 'ffi'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local renderWindow = imgui.new.bool(false)
local isNearestCraftingBench = false

-- ��������� ������� ������ � ������ ���� ��������
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
    singleTip = true, -- ��������� ����� � ���������
    categoty_item = -1, -- ������� "����������"
    selected_item = -1, -- �������
    limit = '10', -- ������� �� 1 ���
    page_counter = 1,
    inputed = 0,
    crafting = false,
    waitCrafting = true,
    waitInputData = true,
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
    '{ffd200}/cset_x [����.] - {ffffff}�������� �������� ���� � ����������� �� ��� {00fbff}X',
    '{ffd200}/cset_y [����.] - {ffffff}�������� �������� ���� � ����������� �� ��� {00fbff}Y',
    '{ffd200}/cset [���-��] - {ffffff}����� �������� ���-�� ������� �� ���',
    '{ffd200}/cwait [���-��] - {ffffff}�������� � {ffd200}������������ {ffffff}����� ����������. ���������� {ffd200}250 ��.',
}

function sampEvents.onSendPlayerSync(data)
    if cData.crafting and data.keysData == 1024 then -- ������ �� ������� ����� ��� ������
        data.keysData = 0
    end
end

function sampEvents.onShowTextDraw(textdrawId, data)
    if cData.crafting then return true end

    -- ��������� ��������
    for key, value in pairs(td_data.categoty) do
        if math.floor(data.position.x) == value.x and math.floor(data.position.y) == value.y then
            value.id = textdrawId
        end
    end

    -- ��������
    if math.floor(data.position.x) == 162 and isInRange(data.position.y, 201, 320) then
        table.insert(td_data.items, textdrawId)
    end

    -- �������� ����������
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
        IStats:reset()
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

-- ��� ����� ������ �������������� ������, ��� ������ ��� �������� ��� ��� ����.
-- ���� ��� ���� ���� �������� � ������� ���������.
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
    if text:find('�� ������� ������� �������') and not text:find('%[%d+%]') then
        if IStats.craftTime == -1 then
            IStats.craftTime = os.clock()
        end
        IStats.completed = IStats.completed + 1
        IStats.good = IStats.good + 1
        cData.waitCrafting = false
    end

    if text:find('�� �������') and text:find('����') and not text:find('%[%d+%]') then
        if IStats.craftTime == -1 then
            IStats.craftTime = os.clock()
        end
        IStats.completed = IStats.completed + 1
        IStats.bad = IStats.bad + 1
        cData.waitCrafting = false
    end

    if text:find('�� �������� ������� �������� ��������!') and color == -10270721 then
        cData.crafting = false
        sampAddChatMessage('{ffd200}[����������] {ffffff}����� ��� �������', -1)
    end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil

    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true

    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    imgui.GetIO().Fonts:Clear()
    imgui.GetIO().Fonts:AddFontFromFileTTF('moonloader/resource/fonts/EagleSans Regular Regular.ttf', 16.0, nil, glyph_ranges)

    SoftBlueTheme()
end)

local statsFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(main)
        main.HideCursor = true
        local chatPosition = getChatCoord()
        local sizeX, sizeY = 260, 200
        imgui.SetNextWindowPos(imgui.ImVec2(chatPosition[1] + jsonSettings.x, chatPosition[2] + jsonSettings.y), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        if imgui.Begin('##statsFrame', renderWindow, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar) then
            imgui.TextColoredRGB(u8('������� {ffd200}%d �� %d'):format(IStats.completed, IStats.maximum))  
            imgui.TextColoredRGB(u8('- �� {ffd200}%s {ffffff}������� �� ���'):format(cData.limit))  
            imgui.TextColoredRGB(u8('- �������� {8bff00}%d'):format(IStats.good))
            imgui.TextColoredRGB(u8('- ��������� {ff0000}%d'):format(IStats.bad))
            imgui.NewLine()
            local calculatedTime = (IStats.craftTime - IStats.animationTime) < 0 and 0 or IStats.craftTime - IStats.animationTime
            IStats.elapsedTime = formatTime((calculatedTime) * (IStats.maximum - IStats.completed))
            imgui.TextColoredRGB(u8('����� ��������� {00fbff}%s {ffffff}�����'):format(IStats.elapsedTime))

            imgui.TextColoredRGB(u8('����������� ���� ������ {00fbff}%.2f'):format(
                (IStats.completed > 0) and (
                    (IStats.good > 0) and (100 * (IStats.good / IStats.completed)) 
                    or (-100 / IStats.completed)
                ) or 0
            ))

            imgui.End()
        end
    end
)

-- ��� ���������� �� ���������� �� ���� �������.
function main()
    while not isSampAvailable() do wait(0) end

    sampAddChatMessage('{ffd200}[craftAssistant]: {ffffff}/chelp - ������ ��������� ������', -1)

    sampRegisterChatCommand('chelp', function(arg)
        for key, data in pairs(caInfo) do
            sampAddChatMessage(data, -1)
        end
    end)

    sampRegisterChatCommand('cwait', function(arg)
        jsonSettings.sleepTime = (arg:match('(%d+)') == nil) and 250 or arg:match('(%d+)')
        jsonSettings()
    end)

    sampRegisterChatCommand('cset_x', function(arg)
        jsonSettings.x = (arg:match('(%d+)') == nil) and 100 or arg:match('(%d+)')
        jsonSettings()
    end)

    sampRegisterChatCommand('cset_y', function(arg)
        jsonSettings.y = (arg:match('(%d+)') == nil) and 100 or arg:match('(%d+)')
        jsonSettings()
    end)

    sampRegisterChatCommand('cset', function(arg)
        cData.limit = tostring((arg:match('(%d+)') == nil) and 5 or arg:match('(%d+)'))
    end)

    lua_thread.create(function()
        while true do
            wait(0)
            if cData.crafting and (IStats.completed <= IStats.maximum) then
                cData.waitCrafting = true
                cData.waitInputData = true
                while cData.waitCrafting do wait(0) end

                -- ���� ���� ����� �� �������� ���� ������
                while not sampTextdrawIsExists(td_data.control['button'].id) do
                    wait(jsonSettings.sleepTime)
                end

                -- � �� ��� ������������
                if IStats.completed >= IStats.maximum then
                    sampAddChatMessage('{ffd200}[����������] {ffffff}����� ��������', -1)
                    cData.crafting = false
                    goto exitThread
                end
   
                -- �������� ���������
                sampSendClickTextdraw(cData.categoty_item)
                wait(jsonSettings.sleepTime)

                -- �������� ��������
                for i = 1, cData.page_counter - 1 do
                    sampSendClickTextdraw(td_data.control['next-page'].id)
                    wait(jsonSettings.sleepTime)
                end

                -- ������� �������
                sampSendClickTextdraw(cData.selected_item)
                wait(jsonSettings.sleepTime)

                -- ���� �� ����� � ���� ���� ������ ��������
                sampSendClickTextdraw(td_data.control['input'].id)
                while cData.waitInputData do
                    wait(jsonSettings.sleepTime)
                end

                sampSendClickTextdraw(td_data.control['button'].id)
            end
            ::exitThread::
        end
    end)


    lua_thread.create(function()
        while true do
            wait(150)
            local charPos = {getCharCoordinates(PLAYER_PED)}
            isNearestCraftingBench = Search3Dtext(charPos[1], charPos[2], charPos[3], 3, '����� ��������������� ���������') or Search3Dtext(charPos[1], charPos[2], charPos[3], 3, '���������� �������')
            renderWindow[0] = isNearestCraftingBench

            if isNearestCraftingBench and cData.singleTip then
                cData.singleTip = false
                sampAddChatMessage('{ffd200}[����������] {ffffff}����������� {ffd200}/cset [���-��] {ffffff}����� �������� ���-�� ������� �� ���', -1)
                elseif not isNearestCraftingBench then
                    cData.singleTip = true
            end
        end
    end)

    wait(-1)
end

function formatTime(seconds)
    return string.format("%02d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

function getChatCoord()
    if not isSampAvailable() then -- ����� access violation ������ ���
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
            for i = 1, 1 --[[������� ����]] do
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