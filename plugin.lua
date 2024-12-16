---@diagnostic disable: lowercase-global, need-check-nil, param-type-mismatch, undefined-global
--- @class HitObjectInfo
--- @field StartTime number
--- @field Lane number
--- @field EndTime number
--- @field HitSound any
--- @field EditorLayer integer

--- @class ScrollVelocityInfo
--- @field StartTime number
--- @field Multiplier number

local lastStartTimeOfFirstNote = 0
local lastPosition = { 1635, 95 }
local lastLaneOfFirstNote = 0
local lastSize = { 0, 200 }
local lastSelectables = {}
local lastCustomFunction
local lastCustomString
local lastSelected = 0
local lastShow = false
local lastPeriod = 0
local lastCount = 0
local lastEase = ""
local lastFrom = 0
local lastMode = 0
local lastTerm = 0
local heightValues
local lastOp = 0
local lastAmp = 0
local lastTo = 0
local heightMax
local heightMin
local textFlags
local lastOrder
local lastSort

local dirs = { "in", "out", "inOut", "outIn" }
local modes = { "absolute", "relative" }
local inclusives = { "unfiltered", "within", "not within" }

local ops = {
    "multiply", "add", "subtract", "divide",
    "modulo", "pow", "replace"
}

local orders = { "ascending", "descending" }
local terms = { "sort nm", "sort nsv" }
local sorts = { "time", "position" }

local types = {
    "linear", "quad", "cubic", "quart", "quint", "sine",
    "expo", "circ", "elastic", "back", "bounce", "custom"
}

local keybinds = read()

if not keybinds then
    keybinds = {
        swap = "U",
        section = "I",
        note = "O",
        ["eat mulch"] = "P",
    }

    write(keybinds)
end

for _, value in pairs(keybinds) do
    if not keys[value] then
        error("Unrecognized key: " .. value)
    end
end

--- The main function
function draw()
    textFlags = imgui_input_text_flags.CharsScientific
    imgui.Begin("mulch", imgui_window_flags.AlwaysAutoResize)
    Theme()

    local padding = 10
    local dropdownWidth = 100
    local from = get("from", 0) ---@type number
    local to = get("to", 1) ---@type number
    local count = get("count", 2) ---@type integer
    local type = get("type", 0) ---@type integer
    local direction = get("direction", 0) ---@type integer
    local amp = get("amp", 1) ---@type number
    local period = get("period", 1) ---@type number
    local op = get("op", 0) ---@type number
    local show = get("show", false) ---@type boolean
    local advanced = get("advanced", false) ---@type boolean
    local mulchmax = get("mulchmax", false) ---@type boolean
    local custom = get("custom", "") ---@type string
    local ssf = get("ssf", false) ---@type boolean

    imgui.BeginTabBar("mode", imgui_tab_bar_flags.NoTooltip)

    if imgui.BeginTabItem("simple") then
    	imgui.EndTabItem()
    	advanced = false
        mulchmax = false
    end

    if imgui.BeginTabItem("advanced") then
    	imgui.EndTabItem()
    	advanced = true
        mulchmax = false
    end

    if imgui.BeginTabItem("mulchmax") then
    	imgui.EndTabItem()
        mulchmax = true
    end

    imgui.EndTabBar()

    if not mulchmax then
        if advanced then
            ActionButton(
                "swap",
                keybinds.swap,
                function()
                    from, to = to, from
                end,
                { },
                "Swaps the parameters for the 'from' and 'to' values."
            )

            imgui.SameLine(0, padding)
        end

        imgui.PushItemWidth(150)
        local _, ft = imgui.InputFloat2("", { from, to }, "%.2f", textFlags)
        imgui.PopItemWidth()
        from = ft[1]
        to = ft[2]

        local ease

        if advanced then
            imgui.PushItemWidth(dropdownWidth)
            _, type = imgui.Combo("##type", type, types, #types)
            imgui.PopItemWidth()

            if not ({ custom = 0, linear = 0 })[types[type + 1]] then
                imgui.SameLine(0, padding)
                imgui.PushItemWidth(dropdownWidth)
                _, direction = imgui.Combo("##direction", direction, dirs, #dirs)
                imgui.PopItemWidth()
            end

            if types[type + 1] == "elastic" then
                imgui.PushItemWidth(150)

                local _, vs = imgui.InputFloat2(
                    "amp/period",
                    { amp, period },
                    "%.2f",
                    textFlags
                )

                imgui.PopItemWidth()
                Tooltip("The elasticity severity, and frequency, respectively.")
                amp = vs[1]
                period = vs[2]
            end

            if types[type + 1] == "custom" then
                Tooltip(
                    "Specify a custom easing function here.\n" ..
                    "$t = time: [0, 1]\n" ..
                    "$b = begin: 'from' parameter\n" ..
                    "$c = change: 'to' - 'from'\n" ..
                    "$d = duration: always 1\n" ..
                    "$v = velocity: current SV multiplier"
                )

                _, custom = imgui.InputTextMultiline("", custom, 1000, {240, 70})
            end

            imgui.Separator()
            imgui.PushItemWidth(dropdownWidth)
            _, op = imgui.Combo("##op", op, ops, #ops)
            imgui.PopItemWidth()

            if advanced then
                imgui.SameLine(0, padding)
                _, ssf = imgui.Checkbox("ssf", ssf)
                Tooltip("Apply changes to SSFs instead of SVs.")
            end

            ease = fulleasename(type, direction)
        else
            Tooltip(
                "The left field is 'from', which is used at the start of the " ..
                "selection. The right value is 'to', for the end. Within the " ..
                "selection, the value used is an interpolation between the " ..
                "'from' and 'to' values."
            )

            ease = "linear"
        end

        imgui.Separator()

        ActionButton(
            "section",
            keybinds.section,
            section,
            { from, to, op, amp, period, ease, custom, ssf },
            "'from' is applied from the start of the selection.\n" ..
            "'to' is applied to the end of the selection."
        )

        imgui.SameLine(0, padding)

        ActionButton(
            "note",
            keybinds.note,
            perNote,
            { from, to, op, amp, period, ease, custom, ssf },
            "'from' is applied from the selected note.\n" ..
            "'to' is applied just before next selected note."
        )

        Plot(from, to, op, amp, period, ease, count, custom)
    else
        imgui.PushItemWidth(170)
        _, count = imgui.InputInt("count", count, 1, 1, textFlags)
        imgui.PopItemWidth()
        Tooltip("The number of SVs to place between each SV in 'sv'")
        count = clamp(count, 1, 2000)
        imgui.Separator()

        ActionButton(
            "eat mulch",
            keybinds["eat mulch"],
            perSV,
            { from, to, op, ease, amp, period, count, custom, ssf },
            "Smear tool, adds SVs in-between existing SVs." ..
            "'from' and 'to' function identically to 'section'."
        )
    end

    if advanced or mulchmax then
        imgui.SameLine(0, padding)
        _, show = imgui.Checkbox("info", show)
        ShowNoteInfo(show)
    end

    state.SetValue("from", from)
    state.SetValue("to", to)
    state.SetValue("count", count)
    state.SetValue("type", type)
    state.SetValue("direction", direction)
    state.SetValue("amp", amp)
    state.SetValue("period", period)
    state.SetValue("op", op)
    state.SetValue("show", show)
    state.SetValue("advanced", advanced)
    state.SetValue("mulchmax", mulchmax)
    state.SetValue("custom", custom)
    state.SetValue("ssf", ssf)

    imgui.End()
end

--- Applies the tween over the entire selected region.
--- @param from number
--- @param to number
--- @param op number
--- @param ease string
--- @param ssf boolean
function section(from, to, op, amp, period, ease, custom, ssf)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets], ssf)

    if not svs[1] then
        print("Please select the region to modify before pressing this button.")
        return
    end

    local svsToAdd = {}
    svsToAdd[#svs] = nil

    for i, sv in ipairs(svs) do
        local f = (sv.StartTime - svs[1].StartTime) /
            (svs[#svs].StartTime - svs[1].StartTime)

        local fm = tween(f, from, to, amp, period, ease, sv.Multiplier, custom)
        local v = handleOperation(sv.Multiplier, fm, op)

        if ssf then
            svsToAdd[i] = utils.CreateScrollSpeedFactor(sv.StartTime, v)
        else
            svsToAdd[i] = utils.CreateScrollVelocity(sv.StartTime, v)
        end
    end

    actions.PerformBatch({
        utils.CreateEditorAction(ternary(ssf, action_type.RemoveScrollSpeedFactorBatch, action_type.RemoveScrollVelocityBatch), svs),
        utils.CreateEditorAction(ternary(ssf, action_type.AddScrollSpeedFactorBatch, action_type.AddScrollVelocityBatch), svsToAdd)
    })
end

--- Applies the tween over each note selected.
--- @param from number
--- @param to number
--- @param op number
--- @param ease string
--- @param ssf boolean
function perNote(from, to, op, amp, period, ease, custom, ssf)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets], ssf)

    if not svs[1] then
        print("Please select the region to modify before pressing this button.")
        return
    end

    local svsToAdd = {}
    svsToAdd[#svs] = nil

    for i, sv in ipairs(svs) do
        local b, e = findAdjacentNotes(sv, offsets)
        local f = (sv.StartTime - b) / (e - b)
        local fm = tween(f, from, to, amp, period, ease, sv.Multiplier, custom)
        local v = handleOperation(sv.Multiplier, fm, op)

        if ssf then
            svsToAdd[i] = utils.CreateScrollSpeedFactor(sv.StartTime, v)
        else
            svsToAdd[i] = utils.CreateScrollVelocity(sv.StartTime, v)
        end
    end

    actions.PerformBatch({
        utils.CreateEditorAction(ternary(ssf, action_type.RemoveScrollSpeedFactorBatch, action_type.RemoveScrollVelocityBatch), svs),
        utils.CreateEditorAction(ternary(ssf, action_type.AddScrollSpeedFactorBatch, action_type.AddScrollVelocityBatch), svsToAdd)
    })
end

--- Applies the tween over each SV selected.
--- @param from number
--- @param to number
--- @param op number
--- @param ease string
--- @param count integer
--- @param ssf boolean
function perSV(from, to, op, ease, amp, period, count, custom, ssf)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets], ssf)

    if not svs[2] then
        print("The selected region must contain at least 2 SV points.")
        return
    end

    local svsToAdd = {}
    local last = 0

    for i, sv in ipairs(svs) do
        local multiplier = sv.Multiplier
        local n = svs[i + 1]

        if not n then
            break
        end

        svsToAdd[last + count + 1] = nil

        for j = 0, count - 1, 1 do
            local gEase = "linear"
            local f = j / (count - 1.0)
            local g = j / (count - 0.0)
            local fm = tween(f, from, to, amp, period, ease, multiplier, custom)
            local gm = tween(g, sv.StartTime, n.StartTime, 0, 0, gEase, 0, "")
            local v = handleOperation(sv.Multiplier, fm, op)
            last = last + 1

            if ssf then
                svsToAdd[last] = utils.CreateScrollSpeedFactor(gm, v)
            else
                svsToAdd[last] = utils.CreateScrollVelocity(gm, v)
            end
        end
    end

    local final = svs[#svs]

    if ssf then
        svsToAdd[#svsToAdd + 1] = utils.CreateScrollSpeedFactor(
            final.StartTime,
            final.Multiplier
        )
    else
        svsToAdd[#svsToAdd + 1] = utils.CreateScrollVelocity(
            final.StartTime,
            final.Multiplier
        )
    end

    actions.PerformBatch({
        utils.CreateEditorAction(ternary(ssf, action_type.RemoveScrollSpeedFactorBatch, action_type.RemoveScrollVelocityBatch), svs),
        utils.CreateEditorAction(ternary(ssf, action_type.AddScrollSpeedFactorBatch, action_type.AddScrollVelocityBatch), svsToAdd)
    })
end

--- Creates a function that steps through the SVs to return the position for the
--- note passed as milliseconds. If `nsv` is `false`, you must pass each number
--- in ascending order, or else the function will return incorrect values.
--- @param nsv boolean
--- @param relative boolean
--- @return function
function positionMarkers(nsv, relative)
    local first

    if not relative then
        first = 0
    end

    if nsv then
        return function(time)
            first = first or time
            return math.floor(utils.ToFloat((time - first) * 100))
        end
    end

    -- We pay for the cost of loading SVs up-front, however we are assuming the
    -- caller will not call this function in a loop or without using the
    -- returned function at least once. If this changes, consider removing the
    -- initialization and putting `svs = svs or map.ScrollVelocities` as the
    -- first statement in the returned function.
    local svs = map.ScrollVelocities
    local initial = map.InitialScrollVelocity
    local index = 2
    local pos

    return function(time)
        if not first and relative then
            while index < #svs and time >= svs[index].StartTime do
                index = index + 1
            end
        end

        if #svs == 0 or time < svs[1].StartTime then
            first = first or time
            local next = utils.ToFloat((time - first) * initial)
            return math.floor(utils.ToFloat(next * 100))
        end

        if not pos then
            if relative then
                pos = 0
            else
                pos = math.floor(utils.ToFloat(svs[1].StartTime * 100))
            end
        end

        while index < #svs and time >= svs[index].StartTime do
            local prev = svs[index - 1]
            local next = utils.ToFloat(svs[index].StartTime - prev.StartTime)
            next = utils.ToFloat(next * prev.Multiplier)
            next = utils.ToFloat(next * 100)
            pos = math.floor(utils.ToFloat(pos + next))
            index = index + 1
        end

        local sv = svs[index - 1] or svs[#svs]
        local t = utils.ToFloat(time - sv.StartTime)
        t = utils.ToFloat(t * sv.Multiplier)
        local ret = pos + math.floor(utils.ToFloat(t * 100))
        first = first or ret
        return ret - first
    end
end

--- Removes duplicates from a table.
--- @param list table
--- @return table
function removeDuplicateValues(list)
    local hash = {}
    local newList = {}

    for _, value in ipairs(list) do
        if not hash[value] then
            newList[#newList + 1] = value
            hash[value] = true
        end
    end

    return newList
end

--- Returns the list of unique offsets (in increasing order) of selected notes
--- @return number[]
function uniqueSelectedNoteOffsets()
    local offsets = {}

    for i, hitObject in ipairs(state.SelectedHitObjects) do
        offsets[i] = hitObject.StartTime
    end

    offsets = removeDuplicateValues(offsets)
    return offsets
end

--- Returns the chronologically ordered list of SVs between two offsets/times
--- @param startOffset number
--- @param endOffset number
--- @param ssf boolean
--- @return ScrollVelocityInfo[]
function getSVsBetweenOffsets(startOffset, endOffset, ssf)
    if startOffset == nil or endOffset == nil then
        return {}
    end

    local svsBetweenOffsets = {}
    local svs

    if ssf then
        svs = map.ScrollSpeedFactors
    else
        svs = map.ScrollVelocities
    end

    if not svs then
        return {}
    end

    for _, sv in ipairs(svs) do
        if sv.StartTime >= startOffset and sv.StartTime < endOffset then
            table.insert(svsBetweenOffsets, sv)
        end
    end

    return svsBetweenOffsets
end

--- Constructs the clipboard from the last selected objects.
--- @param field string
--- @param message string
--- @param inclusive number
--- @param min number
--- @param max number
function fullClipboard(field, message, inclusive, min, max)
    if #lastSelectables == 0 then
        print("Nothing to copy. Please select notes first.")
        return
    end

    local first = lastSelectables[1]
    local clipboard = ""

    if first and (inclusive == 0 or ((inclusive == 1) ==
        (first.position >= min and first.position <= max))) then
        clipboard = first[field]

        if field == "time" then
            clipboard = clipboard .. "|" .. first.lane
        end
    end

    if #lastSelectables == 1 then
        imgui.SetClipboardText(clipboard)
        print(message)
        return clipboard
    else
        local separator = "\n"

        if field == "time" then
            separator = ","
        end

        for i = 2, #lastSelectables, 1 do
            local next = lastSelectables[i]

            if next and (inclusive == 0 or ((inclusive == 1) ==
                (next.position >= min and next.position <= max))) then
                clipboard = clipboard .. separator .. next[field]

                if field == "time" then
                    clipboard = clipboard .. "|" .. next.lane
                end
            end
        end
    end

    if #clipboard == 0 then
        if inclusive == 1 then
            print(
                "Nothing to copy. Please select notes " ..
                "from within the time frame first."
            )
        elseif inclusive == 2 then
            print(
                "Nothing to copy. Please select notes " ..
                "outside of the time frame first."
            )
        else
            error("Not implemented: " .. inclusive)
        end

        return
    end

    imgui.SetClipboardText(clipboard)
    print("Copied all " .. message .. " to clipboard.")
end

--- Finds the closest note to a scroll velocity point.
--- @param sv ScrollVelocityInfo
--- @param notes HitObjectInfo
--- @return HitObjectInfo
--- @return HitObjectInfo
function findAdjacentNotes(sv, notes)
    local p = notes[1]

    for _, n in pairs(notes) do
        if n > sv.StartTime then
            return p, n
        end

        p = n
    end

    return p, p
end

--- Calculates the tween between a range.
--- @param f number
--- @param from number
--- @param to number
--- @param ease string
--- @param sv number
--- @param custom string
--- @return number
function tween(f, from, to, amp, period, ease, sv, custom)
    if ease == "custom" then
        if not lastCustomFunction or custom ~= lastCustomString then
            lastCustomString = custom
            lastCustomFunction = easer[ease](custom)
        end

        return lastCustomFunction(f, from, to - from, 1, sv)
    end

    -- Lossless path: This prevents slight floating point inaccuracies.
    if from == to then
        return from
    end

    return easer[ease](f, from, to - from, 1, amp, period)
end

--- Gets the full ease name applicable in `easing`.
--- @param type string
--- @param direction number
--- @return string
function fulleasename(type, direction)
    local t = types[type + 1]

    if ({ custom = 0, linear = 0 })[types[type + 1]] then
        return t
    end

    return dirs[direction + 1] .. t:gsub("^%l", string.upper)
end

--- Handles the binary operation of two numbers.
--- @param x number
--- @param y number
--- @param op number
--- @return number
function handleOperation(x, y, op)
    if op == 0 then
        return x * y
    end

    if op == 1 then
        return x + y
    end

    if op == 2 then
        return x - y
    end

    if op == 3 then
        return x / y
    end

    if op == 4 then
        return x % y
    end

    if op == 5 then
        return x ^ y
    end

    if op == 6 then
        return y
    end

    error("Not implemented: " .. op)
end

--- Converts a note to a string.
--- @param obj HitObjectInfo
--- @param pos number
--- @param fromEnd boolean
function noteString(obj, pos, fromEnd)
    if fromEnd then
        return obj.EndTime .. "^  = " .. pos .. " msx"
    end

    return obj.StartTime .. "|" .. obj.Lane .. " = " .. pos .. " msx"
end

--- Converts a note to a string.
--- @param obj HitObjectInfo
--- @param fromEnd boolean
function noteRawString(obj, fromEnd)
    local time = obj.StartTime

    if fromEnd then
        time = obj.EndTime
    end

    return time .. "|" .. obj.Lane
end

--- Gets the RGBA object of the provided hex value.
--- @param hex string
--- @return number[]
function rgb(hex)
    hex = hex:gsub("#", "")

    local alpha

    if #hex > 6 then
        alpha = tonumber("0x" .. hex:sub(7, 8), 16) / 255.0
    else
        alpha = 255
    end

    return {
        tonumber("0x" .. hex:sub(1, 2), 16) / 255.0,
        tonumber("0x" .. hex:sub(3, 4), 16) / 255.0,
        tonumber("0x" .. hex:sub(5, 6), 16) / 255.0,
        alpha
    }
end

--- Clamps the value between a minimum and maximum value.
--- @param value number
--- @param min number
--- @param max number
--- @return number
function clamp(value, min, max)
    if value < min then
        return min
    end

    if value > max then
        return max
    end

    return value
end

--- Performs the ternary operation.
--- @generic T
--- @param condition boolean
--- @param consequent T
--- @param alternative T
--- @return T
function ternary(condition, consequent, alternative)
    if condition then
        return consequent
    end

    return alternative
end

--- Gets the value from the current state.
--- @param identifier string
--- @param defaultValue any
--- @return any
function get(identifier, defaultValue)
    return state.GetValue(identifier) or defaultValue
end

--- Returns the argument (identity function).
--- @param x any
--- @return any
function id(x)
    return x
end

--- Creates a button that runs a function using `from` and `to`.
--- @param label string
--- @param key string
--- @param fn function
--- @param tbl table
--- @param msg string
function ActionButton(label, key, fn, tbl, msg)
    if imgui.Button(label) or utils.IsKeyPressed(keys[key]) then
        fn(table.unpack(tbl))
    end

    Tooltip(
        msg .. " Alternatively, press " .. key .. " to perform this action."
    )
end

--- Creates a plot with the given parameters.
--- @param from number
--- @param to number
--- @param op number
--- @param ease string
--- @param count number
--- @param custom string
function Plot(from, to, op, amp, period, ease, count, custom)
    if ease == "linear" then
        return
    end

    imgui.Begin("mulch plot", imgui_window_flags.AlwaysAutoResize)
    count = 256

    if from ~= lastFrom or to ~= lastTo or op ~= lastOp or
        amp ~= lastAmp or period ~= lastPeriod or ease ~= lastEase or
        count ~= lastCount or custom ~= lastCustomString then
        lastFrom = from
        lastTo = to
        lastOp = op
        lastAmp = amp
        lastPeriod = period
        lastEase = ease
        lastCount = count

        heightValues = {}
        heightValues[count + 1] = nil
        heightMax = -1 / 0
        heightMin = 1 / 0

        for i = 0, count, 1 do
            local f = i / count
            local fm = tween(f, from, to, amp, period, ease, 1, custom)
            local v = handleOperation(1, fm, op)
            heightValues[i + 1] = v

            if v > heightMax then
                heightMax = v
            end

            if v < heightMin then
                heightMin = v
            end
        end

        -- Custom needs to be updated after the calls to 'tween', because
        -- it compares the assigned value, however it doesn't update the
        -- value if we have a different ease other than 'custom'.
        lastCustomString = custom
    end

    imgui.PlotLines(
        "",
        heightValues,
        #heightValues,
        0,
        ease .. ", " .. math.floor(heightMin * 100 + 0.5) / 100 .. " to " ..
        math.floor(heightMax * 100 + 0.5) / 100,
        heightMin,
        heightMax,
        { 300, 150 }
    )

    imgui.End()
end

--- Shows the note info window.
--- @param show boolean
function ShowNoteInfo(show)
    local refresh = show and not lastShow
    lastShow = show

    if not show then
        return
    end

    local objects = state.SelectedHitObjects
    local name = "mulch measure"

    imgui.PushStyleVar(imgui_style_var.WindowMinSize, { 235, 465 })
    imgui.Begin(name)
    imgui.PopStyleVar(imgui_style_var.WindowMinSize)

    if #objects ~= lastSelected then
        imgui.SetWindowPos(name, lastPosition)
        imgui.SetWindowSize(name, lastSize)
    end

    local term = get("term", 0) ---@type number
    local mode = get("mode", 0) ---@type number
    local order = get("order", 0) ---@type number
    local sort = get("sort", 0) ---@type number
    local inclusive = get("inclusive", 0) ---@type number
    local from = get("positionFrom", 0) ---@type number
    local to = get("positionTo", 1000) ---@type number

    imgui.PushItemWidth(120)
    _, term = imgui.Combo("by", term, terms, #terms)
    Tooltip("Whether distance is measured with or without considering SVs.")

    local modeLabel = "time in##mode"

    if term == 0 then
        modeLabel = "##mode"
    end

    _, mode = imgui.Combo(modeLabel, mode, modes, #modes)

    Tooltip(
        "Refers to categorization of 0. Either the first note's position, " ..
        "which is considered relative, or from the start of the chart, " ..
        "which is considered absolute."
    )

    if term == 0 then
        _, sort = imgui.Combo("in", sort, sorts, #sorts)

        Tooltip(
            "Whether to sort based on the time of each note, or the " ..
            "position in which a note is placed in the chart."
        )
    end

    _, order = imgui.Combo("order", order, orders, #orders)

    Tooltip(
        "Ascending refers to lowest to highest, " ..
        "while descending refers to highest to lowest."
    )

    _, inclusive = imgui.Combo("##include", inclusive, inclusives, #inclusives)
    Tooltip("Allows filtering of notes based on position.")
    imgui.PopItemWidth()

    if inclusive ~= 0 then
        imgui.PushItemWidth(170)
        local _, vs = imgui.InputFloat2("msx", { from, to }, "%.2f", textFlags)
        imgui.PopItemWidth()
        from = vs[1]
        to = vs[2]
    end

    local min, max

    if from <= to then
        min = from
        max = to
    else
        min = to
        max = from
    end

    imgui.Separator()
    local selectCountLabel

    if #objects == 0 then
        selectCountLabel = "No hit objects selected."
    elseif #objects == 1 then
        selectCountLabel = "1 hit object selected."
    else
        selectCountLabel = #objects .. " hit objects selected."
    end

    if imgui.Selectable(selectCountLabel) then
        fullClipboard("position", "msx values", inclusive, min, max)
    elseif imgui.IsItemClicked(1) then
        fullClipboard("time", "object timestamps", inclusive, min, max)
    elseif imgui.IsItemClicked(2) then
        fullClipboard("string", "text", inclusive, min, max)
    end

    Tooltip(
        "Any of the numbers below can be left-clicked to copy their msx " ..
        "value onto your clipboard. Use the right mouse button to copy the " ..
        "note instead, usable in \"Tools\" > \"Go To Objects\", and the " ..
        "middle button to copy the whole text. Clicking this label will " ..
        "perform the listed action on every selected note."
    )

    imgui.Separator()

    if sort ~= lastSort or order ~= lastOrder then
        lastSort = sort
        lastOrder = order

        table.sort(
            lastSelectables,
            function(x, y)
                if not x then
                    return false
                end

                if not y then
                    return true
                end

                local xValue
                local yValue
                local value

                if sort == 0 then
                    xValue = x.time
                    yValue = y.time
                else
                    xValue = x.position
                    yValue = y.position
                end

                if order == 0 then
                    value = xValue < yValue
                else
                    value = xValue > yValue
                end

                return value or xValue == yValue and x.lane < y.lane
            end
        )
    end

    if #objects == 0 then
    elseif #objects == lastSelected and
        objects[1].StartTime == lastStartTimeOfFirstNote and
        objects[1].Lane == lastLaneOfFirstNote and
        mode == lastMode and
        term == lastTerm and
        not refresh then
        for _, v in ipairs(lastSelectables) do
            if v and
                (inclusive == 0 or ((inclusive == 1) ==
                (v.position >= min and v.position <= max))) then
                if imgui.Selectable(v.string) then
                    imgui.SetClipboardText(v.position)
                    print("Copied '" .. v.position .. "' to clipboard.")
                elseif imgui.IsItemClicked(1) then
                    imgui.SetClipboardText(v.clipboard)
                    print("Copied '" .. v.clipboard .. "' to clipboard.")
                elseif imgui.IsItemClicked(2) then
                    imgui.SetClipboardText(v.string)
                    print("Copied '" .. v.string .. "' to clipboard.")
                end
            end

        end
    else
        lastSelectables = {}
        lastSelectables[#objects * 2] = nil
        local markers = positionMarkers(term == 1, mode == 1)

        for i = 1, #objects, 1 do
            local obj = objects[i]
            local position = markers(obj.StartTime) / 100

            local start = {
                clipboard = noteRawString(obj, false),
                lane = obj.Lane,
                time = obj.StartTime,
                position = position,
                string = noteString(obj, position, false)
            }

            lastSelectables[i * 2 - 1] = start

            if (inclusive == 0 or ((inclusive == 1) ==
                (position >= min and position <= max))) then
                if imgui.Selectable(start.string) then
                    imgui.SetClipboardText(position)
                    print("Copied '" .. position .. "' to clipboard.")
                elseif imgui.IsItemClicked(1) then
                    imgui.SetClipboardText(start.clipboard)
                    print("Copied '" .. start.clipboard .. "' to clipboard.")
                elseif imgui.IsItemClicked(2) then
                    imgui.SetClipboardText(start.string)
                    print("Copied '" .. start.string .. "' to clipboard.")
                end
            end

            if obj.EndTime == 0 then
                -- Has to be false so that if statements that check for the
                -- object's existence fail, but at the same time, iterators
                -- that check for nil for halting continue the iteration.
                lastSelectables[i * 2] = false
            else
                local endPosition = markers(obj.EndTime) / 100

                local ending = {
                    clipboard = noteRawString(obj, true),
                    lane = obj.Lane,
                    time = obj.EndTime,
                    position = endPosition,
                    string = noteString(obj, endPosition, true)
                }

                lastSelectables[i * 2] = ending

                if (inclusive == 0 or ((inclusive == 1) ==
                    (position >= min and position <= max))) then
                    if imgui.Selectable(ending.string) then
                        imgui.SetClipboardText(endPosition)
                        print("Copied '" .. endPosition .. "' to clipboard.")
                    elseif imgui.IsItemClicked(1) then
                        imgui.SetClipboardText(ending.clipboard)

                        print(
                            "Copied '" .. ending.clipboard .. "' to clipboard."
                        )
                    elseif imgui.IsItemClicked(2) then
                        imgui.SetClipboardText(ending.string)
                        print("Copied '" .. ending.string .. "' to clipboard.")
                    end
                end
            end
        end

        lastSort = nil
        lastOrder = nil
    end

    state.SetValue("mode", mode)
    state.SetValue("term", term)
    state.SetValue("order", order)
    state.SetValue("sort", sort)
    state.SetValue("inclusive", inclusive)
    state.SetValue("positionFrom", from)
    state.SetValue("positionTo", to)
    lastPosition = imgui.GetWindowPos(name)
    lastSize = imgui.GetWindowSize(name)
    lastSelected = #objects
    lastMode = mode
    lastTerm = term
    lastStartTimeOfFirstNote = (objects[1] or { StartTime = 0 }).StartTime
    lastLaneOfFirstNote = (objects[1] or { Lane = 0 }).Lane
    imgui.End()
end

--- Creates a tooltip hoverable element.
--- @param text string
--- @param paddingOverride number | nil
function Tooltip(text, paddingOverride)
    if paddingOverride then
        imgui.SameLine(paddingOverride, 0)
    else
        imgui.SameLine(0, 5)
    end

    imgui.TextDisabled("(?)")

    if not imgui.IsItemHovered() then
        return
    end

    imgui.BeginTooltip()
    imgui.PushTextWrapPos(imgui.GetFontSize() * 20)
    imgui.Text(text)
    imgui.PopTextWrapPos()
    imgui.EndTooltip()
end

--- Applies the theme.
function Theme()
    -- Accent colors are unused, but are here if you wish to change that.
    -- local green = rgb("#50FA7B")
    -- local orange = rgb("#FFB86C")
    -- local pink = rgb("#FF79C6")
    -- local purple = rgb("#BD93F9")
    -- local red = rgb("#FF5555")
    -- local yellow = rgb("#F1FA8C")

    local cyan = rgb("#8BE9FD")
    local morsels = rgb("#191A21")
    local background = rgb("#282A36")
    local current = rgb("#44475A")
    local foreground = rgb("#F8F8F2")
    local comment = rgb("#6272A4")
    local rounding = 10
    local spacing = { 10, 10 }

    imgui.PushStyleColor(imgui_col.Text, foreground)
    imgui.PushStyleColor(imgui_col.TextDisabled, comment)
    imgui.PushStyleColor(imgui_col.WindowBg, morsels)
    imgui.PushStyleColor(imgui_col.ChildBg, morsels)
    imgui.PushStyleColor(imgui_col.PopupBg, morsels)
    imgui.PushStyleColor(imgui_col.Border, background)
    imgui.PushStyleColor(imgui_col.BorderShadow, background)
    imgui.PushStyleColor(imgui_col.FrameBg, background)
    imgui.PushStyleColor(imgui_col.FrameBgHovered, current)
    imgui.PushStyleColor(imgui_col.FrameBgActive, current)
    imgui.PushStyleColor(imgui_col.TitleBg, background)
    imgui.PushStyleColor(imgui_col.TitleBgActive, current)
    imgui.PushStyleColor(imgui_col.TitleBgCollapsed, current)
    imgui.PushStyleColor(imgui_col.MenuBarBg, background)
    imgui.PushStyleColor(imgui_col.ScrollbarBg, background)
    imgui.PushStyleColor(imgui_col.ScrollbarGrab, background)
    imgui.PushStyleColor(imgui_col.ScrollbarGrabHovered, current)
    imgui.PushStyleColor(imgui_col.ScrollbarGrabActive, current)
    imgui.PushStyleColor(imgui_col.CheckMark, cyan)
    imgui.PushStyleColor(imgui_col.SliderGrab, current)
    imgui.PushStyleColor(imgui_col.SliderGrabActive, comment)
    imgui.PushStyleColor(imgui_col.Button, current)
    imgui.PushStyleColor(imgui_col.ButtonHovered, comment)
    imgui.PushStyleColor(imgui_col.ButtonActive, comment)
    imgui.PushStyleColor(imgui_col.Header, background)
    imgui.PushStyleColor(imgui_col.HeaderHovered, current)
    imgui.PushStyleColor(imgui_col.HeaderActive, current)
    imgui.PushStyleColor(imgui_col.Separator, background)
    imgui.PushStyleColor(imgui_col.SeparatorHovered, background)
    imgui.PushStyleColor(imgui_col.SeparatorActive, background)
    imgui.PushStyleColor(imgui_col.ResizeGrip, background)
    imgui.PushStyleColor(imgui_col.ResizeGripHovered, background)
    imgui.PushStyleColor(imgui_col.ResizeGripActive, background)
    imgui.PushStyleColor(imgui_col.Tab, background)
    imgui.PushStyleColor(imgui_col.TabHovered, current)
    imgui.PushStyleColor(imgui_col.TabActive, current)
    imgui.PushStyleColor(imgui_col.TabUnfocused, current)
    imgui.PushStyleColor(imgui_col.TabUnfocusedActive, current)
    imgui.PushStyleColor(imgui_col.PlotLines, cyan)
    imgui.PushStyleColor(imgui_col.PlotLinesHovered, foreground)
    imgui.PushStyleColor(imgui_col.PlotHistogram, cyan)
    imgui.PushStyleColor(imgui_col.PlotHistogramHovered, foreground)
    imgui.PushStyleColor(imgui_col.TextSelectedBg, comment)
    imgui.PushStyleColor(imgui_col.DragDropTarget, current)
    imgui.PushStyleColor(imgui_col.NavHighlight, current)
    imgui.PushStyleColor(imgui_col.NavWindowingHighlight, current)
    imgui.PushStyleColor(imgui_col.NavWindowingDimBg, current)
    imgui.PushStyleColor(imgui_col.ModalWindowDimBg, current)

    imgui.PushStyleVar(imgui_style_var.Alpha, 1)
    imgui.PushStyleVar(imgui_style_var.WindowBorderSize, 0)
    imgui.PushStyleVar(imgui_style_var.WindowMinSize, { 0, 0 })
    imgui.PushStyleVar(imgui_style_var.WindowTitleAlign, { 0, 0.4 })
    imgui.PushStyleVar(imgui_style_var.ChildRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.ChildBorderSize, 0)
    imgui.PushStyleVar(imgui_style_var.PopupRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.PopupBorderSize, { 0, 0 })
    imgui.PushStyleVar(imgui_style_var.FramePadding, spacing)
    imgui.PushStyleVar(imgui_style_var.FrameRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.FrameBorderSize, 0)
    imgui.PushStyleVar(imgui_style_var.ItemSpacing, spacing)
    imgui.PushStyleVar(imgui_style_var.ItemInnerSpacing, spacing)
    imgui.PushStyleVar(imgui_style_var.ItemInnerSpacing, spacing)
    imgui.PushStyleVar(imgui_style_var.IndentSpacing, spacing)
    imgui.PushStyleVar(imgui_style_var.ScrollbarSize, 10)
    imgui.PushStyleVar(imgui_style_var.ScrollbarRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.GrabMinSize, 0)
    imgui.PushStyleVar(imgui_style_var.GrabRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.TabRounding, rounding)
    imgui.PushStyleVar(imgui_style_var.ButtonTextAlign, { 0.5, 0.5 })
end

--- Returns an object for easings.
function easings()
    --
    -- Adapted from
    -- Tweener's easing functions (Penner's Easing Equations)
    -- and http://code.google.com/p/tweener/ (jstweener javascript version)
    --

    --[[
	Disclaimer for Robert Penner's Easing Equations license:

	TERMS OF USE - EASING EQUATIONS

	Open source under the BSD License.

	Copyright © 2001 Robert Penner
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

	    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	    * Neither the name of the author nor the names of contributors may be used to endorse or promote products derived from this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	]]

    -- For all easing functions:
    -- t = elapsed time
    -- b = begin
    -- c = change == ending - beginning
    -- d = duration (total time)

    local pow  = function(x, y) return x ^ y end
    local sin  = math.sin
    local cos  = math.cos
    local pi   = math.pi
    local sqrt = math.sqrt
    local abs  = math.abs
    local asin = math.asin

    local function linear(t, b, c, d)
        return c * t / d + b
    end

    local function inQuad(t, b, c, d)
        t = t / d
        return c * pow(t, 2) + b
    end

    local function outQuad(t, b, c, d)
        t = t / d
        return -c * t * (t - 2) + b
    end

    local function inOutQuad(t, b, c, d)
        t = t / d * 2
        if t < 1 then
            return c / 2 * pow(t, 2) + b
        else
            return -c / 2 * ((t - 1) * (t - 3) - 1) + b
        end
    end

    local function outInQuad(t, b, c, d)
        if t < d / 2 then
            return outQuad(t * 2, b, c / 2, d)
        else
            return inQuad((t * 2) - d, b + c / 2, c / 2, d)
        end
    end

    local function inCubic(t, b, c, d)
        t = t / d
        return c * pow(t, 3) + b
    end

    local function outCubic(t, b, c, d)
        t = t / d - 1
        return c * (pow(t, 3) + 1) + b
    end

    local function inOutCubic(t, b, c, d)
        t = t / d * 2
        if t < 1 then
            return c / 2 * t * t * t + b
        else
            t = t - 2
            return c / 2 * (t * t * t + 2) + b
        end
    end

    local function outInCubic(t, b, c, d)
        if t < d / 2 then
            return outCubic(t * 2, b, c / 2, d)
        else
            return inCubic((t * 2) - d, b + c / 2, c / 2, d)
        end
    end

    local function inQuart(t, b, c, d)
        t = t / d
        return c * pow(t, 4) + b
    end

    local function outQuart(t, b, c, d)
        t = t / d - 1
        return -c * (pow(t, 4) - 1) + b
    end

    local function inOutQuart(t, b, c, d)
        t = t / d * 2
        if t < 1 then
            return c / 2 * pow(t, 4) + b
        else
            t = t - 2
            return -c / 2 * (pow(t, 4) - 2) + b
        end
    end

    local function outInQuart(t, b, c, d)
        if t < d / 2 then
            return outQuart(t * 2, b, c / 2, d)
        else
            return inQuart((t * 2) - d, b + c / 2, c / 2, d)
        end
    end

    local function inQuint(t, b, c, d)
        t = t / d
        return c * pow(t, 5) + b
    end

    local function outQuint(t, b, c, d)
        t = t / d - 1
        return c * (pow(t, 5) + 1) + b
    end

    local function inOutQuint(t, b, c, d)
        t = t / d * 2
        if t < 1 then
            return c / 2 * pow(t, 5) + b
        else
            t = t - 2
            return c / 2 * (pow(t, 5) + 2) + b
        end
    end

    local function outInQuint(t, b, c, d)
        if t < d / 2 then
            return outQuint(t * 2, b, c / 2, d)
        else
            return inQuint((t * 2) - d, b + c / 2, c / 2, d)
        end
    end

    local function inSine(t, b, c, d)
        return -c * cos(t / d * (pi / 2)) + c + b
    end

    local function outSine(t, b, c, d)
        return c * sin(t / d * (pi / 2)) + b
    end

    local function inOutSine(t, b, c, d)
        return -c / 2 * (cos(pi * t / d) - 1) + b
    end

    local function outInSine(t, b, c, d)
        if t < d / 2 then
            return outSine(t * 2, b, c / 2, d)
        else
            return inSine((t * 2) - d, b + c / 2, c / 2, d)
        end
    end

    local function inExpo(t, b, c, d)
        if t == 0 then
            return b
        else
            return c * pow(2, 10 * (t / d - 1)) + b - c * 0.001
        end
    end

    local function outExpo(t, b, c, d)
        if t == d then
            return b + c
        else
            return c * 1.001 * (-pow(2, -10 * t / d) + 1) + b
        end
    end

    local function inOutExpo(t, b, c, d)
        if t == 0 then return b end
        if t == d then return b + c end
        t = t / d * 2
        if t < 1 then
            return c / 2 * pow(2, 10 * (t - 1)) + b - c * 0.0005
        else
            t = t - 1
            return c / 2 * 1.0005 * (-pow(2, -10 * t) + 2) + b
        end
    end

    local function outInExpo(t, b, c, d)
        if t < d / 2 then
            return outExpo(t * 2, b, c / 2, d)
        else
            return inExpo((t * 2) - d, b + c / 2, c / 2, d)
        end
    end

    local function inCirc(t, b, c, d)
        t = t / d
        return (-c * (sqrt(1 - pow(t, 2)) - 1) + b)
    end

    local function outCirc(t, b, c, d)
        t = t / d - 1
        return (c * sqrt(1 - pow(t, 2)) + b)
    end

    local function inOutCirc(t, b, c, d)
        t = t / d * 2
        if t < 1 then
            return -c / 2 * (sqrt(1 - t * t) - 1) + b
        else
            t = t - 2
            return c / 2 * (sqrt(1 - t * t) + 1) + b
        end
    end

    local function outInCirc(t, b, c, d)
        if t < d / 2 then
            return outCirc(t * 2, b, c / 2, d)
        else
            return inCirc((t * 2) - d, b + c / 2, c / 2, d)
        end
    end

    local function inElastic(t, b, c, d, a, p)
        if t == 0 then return b end

        t = t / d

        if t == 1 then return b + c end

        if not p then p = d * 0.3 end

        local s

        if not a or a < abs(c) then
            a = c
            s = p / 4
        else
            s = p / (2 * pi) * asin(c / a)
        end

        t = t - 1

        return -(a * pow(2, 10 * t) * sin((t * d - s) * (2 * pi) / p)) + b
    end

    -- a: amplitud
    -- p: period
    local function outElastic(t, b, c, d, a, p)
        if t == 0 then return b end

        t = t / d

        if t == 1 then return b + c end

        if not p then p = d * 0.3 end

        local s

        if not a or a < abs(c) then
            a = c
            s = p / 4
        else
            s = p / (2 * pi) * asin(c / a)
        end

        return a * pow(2, -10 * t) * sin((t * d - s) * (2 * pi) / p) + c + b
    end

    -- p = period
    -- a = amplitud
    local function inOutElastic(t, b, c, d, a, p)
        if t == 0 then return b end

        t = t / d * 2

        if t == 2 then return b + c end

        if not p then p = d * (0.3 * 1.5) end
        if not a then a = 0 end

        local s

        if not a or a < abs(c) then
            a = c
            s = p / 4
        else
            s = p / (2 * pi) * asin(c / a)
        end

        if t < 1 then
            t = t - 1
            return -0.5 * (a * pow(2, 10 * t) * sin((t * d - s) * (2 * pi) / p)) + b
        else
            t = t - 1
            return a * pow(2, -10 * t) * sin((t * d - s) * (2 * pi) / p) * 0.5 + c + b
        end
    end

    -- a: amplitud
    -- p: period
    local function outInElastic(t, b, c, d, a, p)
        if t < d / 2 then
            return outElastic(t * 2, b, c / 2, d, a, p)
        else
            return inElastic((t * 2) - d, b + c / 2, c / 2, d, a, p)
        end
    end

    local function inBack(t, b, c, d, s)
        if not s then s = 1.70158 end
        t = t / d
        return c * t * t * ((s + 1) * t - s) + b
    end

    local function outBack(t, b, c, d, s)
        if not s then s = 1.70158 end
        t = t / d - 1
        return c * (t * t * ((s + 1) * t + s) + 1) + b
    end

    local function inOutBack(t, b, c, d, s)
        if not s then s = 1.70158 end
        s = s * 1.525
        t = t / d * 2
        if t < 1 then
            return c / 2 * (t * t * ((s + 1) * t - s)) + b
        else
            t = t - 2
            return c / 2 * (t * t * ((s + 1) * t + s) + 2) + b
        end
    end

    local function outInBack(t, b, c, d, s)
        if t < d / 2 then
            return outBack(t * 2, b, c / 2, d, s)
        else
            return inBack((t * 2) - d, b + c / 2, c / 2, d, s)
        end
    end

    local function outBounce(t, b, c, d)
        t = t / d
        if t < 1 / 2.75 then
            return c * (7.5625 * t * t) + b
        elseif t < 2 / 2.75 then
            t = t - (1.5 / 2.75)
            return c * (7.5625 * t * t + 0.75) + b
        elseif t < 2.5 / 2.75 then
            t = t - (2.25 / 2.75)
            return c * (7.5625 * t * t + 0.9375) + b
        else
            t = t - (2.625 / 2.75)
            return c * (7.5625 * t * t + 0.984375) + b
        end
    end

    local function inBounce(t, b, c, d)
        return c - outBounce(d - t, 0, c, d) + b
    end

    local function inOutBounce(t, b, c, d)
        if t < d / 2 then
            return inBounce(t * 2, 0, c, d) * 0.5 + b
        else
            return outBounce(t * 2 - d, 0, c, d) * 0.5 + c * .5 + b
        end
    end

    local function outInBounce(t, b, c, d)
        if t < d / 2 then
            return outBounce(t * 2, b, c / 2, d)
        else
            return inBounce((t * 2) - d, b + c / 2, c / 2, d)
        end
    end

    return {
        linear       = linear,
        inQuad       = inQuad,
        outQuad      = outQuad,
        inOutQuad    = inOutQuad,
        outInQuad    = outInQuad,
        inCubic      = inCubic,
        outCubic     = outCubic,
        inOutCubic   = inOutCubic,
        outInCubic   = outInCubic,
        inQuart      = inQuart,
        outQuart     = outQuart,
        inOutQuart   = inOutQuart,
        outInQuart   = outInQuart,
        inQuint      = inQuint,
        outQuint     = outQuint,
        inOutQuint   = inOutQuint,
        outInQuint   = outInQuint,
        inSine       = inSine,
        outSine      = outSine,
        inOutSine    = inOutSine,
        outInSine    = outInSine,
        inExpo       = inExpo,
        outExpo      = outExpo,
        inOutExpo    = inOutExpo,
        outInExpo    = outInExpo,
        inCirc       = inCirc,
        outCirc      = outCirc,
        inOutCirc    = inOutCirc,
        outInCirc    = outInCirc,
        inElastic    = inElastic,
        outElastic   = outElastic,
        inOutElastic = inOutElastic,
        outInElastic = outInElastic,
        inBack       = inBack,
        outBack      = outBack,
        inOutBack    = inOutBack,
        outInBack    = outInBack,
        inBounce     = inBounce,
        outBounce    = outBounce,
        inOutBounce  = inOutBounce,
        outInBounce  = outInBounce,
        custom       = function(x)
            return function(t, b, c, d, v)
                if x == "" then
                    return 0 / 0
                end

                local value, _ = eval(
                    "return " ..
                    x:gsub("$t", t)
                    :gsub("$b", b)
                    :gsub("$c", c)
                    :gsub("$d", d)
                    :gsub("$v", v)
                )

                return tonumber(value) or (0 / 0)
            end
        end
    }
end

easer = easings()
