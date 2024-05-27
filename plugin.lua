--- @class HitObjectInfo
--- @field StartTime number
--- @field Lane number
--- @field EndTime number
--- @field HitSound any
--- @field EditorLayer integer

--- @class ScrollVelocityInfo
--- @field StartTime number
--- @field Multiplier number

local lastPosition = { 1635, 95 }
local lastSize = { 0, 200 }
local lastSelectables = {}
local lastRelative = false
local lastSelected = 0
local lastShow = false
local lastNsv = false
local textFlags

local afters = {
    "none", "abs", "acos", "asin", "atan", "ceil", "cos", "deg",
    "exp", "floor", "frac", "int", "log", "max", "min", "modf",
    "pow", "rad", "random", "sin", "sqrt", "tan"
}

local dirs = { "in", "out", "inOut", "outIn" }

local types = {
    "linear", "quad", "cubic", "quart", "quint", "sine",
    "expo", "circ", "elastic", "back", "bounce"
}

--- The main function
function draw()
    textFlags = imgui_input_text_flags.CharsScientific
    imgui.Begin("mulch", imgui_window_flags.AlwaysAutoResize)
    Theme()

    local padding = 10
    local from = get("from", 0) ---@type number
    local to = get("to", 1) ---@type number
    local count = get("count", 64) ---@type integer
    local type = get("type", 0) ---@type integer
    local direction = get("direction", 0) ---@type integer
    local amp = get("amp", 1) ---@type number
    local period = get("period", 1) ---@type number
    local after = get("after", 0) ---@type integer
    local by = get("by", math.exp(1)) ---@type number
    local add = get("add", false) ---@type boolean
    local show = get("show", false) ---@type boolean

    ActionButton(
        "swap",
        "U",
        function()
            from, to = to, from
        end,
        { },
        "Swaps the parameters for the 'from' and 'to' values."
    )

    imgui.SameLine(0, padding)

    imgui.PushItemWidth(165)
    local _, ft = imgui.InputFloat2("from/to", { from, to }, "%.2f", textFlags)
    imgui.PopItemWidth()
    from = ft[1]
    to = ft[2]

    Tooltip(
        "The left field is 'from', which is used at the start of the " ..
        "selection. The right value is 'to', for the end. Within the " ..
        "selection, the value used is an interpolation between the " ..
        "'from' and 'to' values."
    )

    _, count = imgui.InputInt("count", count, 1, 1, textFlags)

    Tooltip(
        "The resolution of the plot, and the number of SVs " ..
        "to place between each SV when 'per SV' is used."
    )

    count = clamp(count, 1, 256)
    imgui.Separator()
    ShowCalculator()

    imgui.PushItemWidth(100)
    _, type = imgui.Combo("type", type, types, #types)
    imgui.PopItemWidth()

    if types[type + 1] ~= "linear" then
        imgui.SameLine(0, padding)
        imgui.PushItemWidth(100)
        _, direction = imgui.Combo("direction", direction, dirs, #dirs)
        imgui.PopItemWidth()
    end

    if types[type + 1] == "elastic" then
        imgui.PushItemWidth(215)

        _, ap = imgui.InputFloat2(
            "amp/period",
            { amp, period },
            "%.2f",
            textFlags
        )

        imgui.PopItemWidth()
        Tooltip("The elasticity severity, and frequency, respectively.")
        amp = ap[1]
        period = ap[2]
    end

    imgui.Separator()
    imgui.PushItemWidth(100)
    _, after = imgui.Combo("after", after, afters, #afters)
    imgui.PopItemWidth()

    Tooltip(
        "The mathematical operation to apply to every result " ..
        "of a tween calculation before SV placement."
    )

    local special = { atan = 0, log = 0, min = 0, max = 0, pow = 0 }

    if special[afters[after + 1]] then
        imgui.SameLine(0, padding)
        imgui.PushItemWidth(100)
        _, by = imgui.InputDouble("by", by, 0, 0, "%.2f", textFlags)
        imgui.PopItemWidth()

        Tooltip(
            "This 'after' option is a binary operation, which means requiring " ..
            "2 inputs. In this case, the first is the current SV, and the " ..
            "second is this field."
        )
    end

    imgui.Separator()

    _, add = imgui.Checkbox("add instead", add)

    Tooltip(
        "Determines whether to add to existing SV amounts, " ..
        "instead of multiplying them."
    )

    imgui.SameLine(0, padding)

    _, show = imgui.Checkbox("show note info", show)

    Tooltip(
        "When enabled, displays SV distance of selected notes in a window. " ..
        "Potentially laggy when selecting close to the end, " ..
        "hence disabled by default."
    )

    imgui.Separator()
    local ease = fulleasename(type, direction)

    ActionButton(
        "section",
        "I",
        section,
        { from, to, add, after, by, amp, period, ease },
        "'from' is applied from the start of the selection.\n" ..
        "'to' is applied to the end of the selection."
    )

    imgui.SameLine(0, padding)

    ActionButton(
        "per note",
        "O",
        perNote,
        { from, to, add, after, by, amp, period, ease },
        "'from' is applied from the selected note.\n" ..
        "'to' is applied just before next selected note."
    )

    imgui.SameLine(0, padding)

    ActionButton(
        "per sv",
        "P",
        perSV,
        { from, to, add, after, ease, by, amp, period, count },
        "Smear tool, adds SVs in-between existing SVs." ..
        "'from' and 'to' function identically to 'section'."
    )

    ShowNoteInfo(show)
    Plot(from, to, add, after, by, amp, period, ease, count)

    state.SetValue("from", from)
    state.SetValue("to", to)
    state.SetValue("count", count)
    state.SetValue("type", type)
    state.SetValue("direction", direction)
    state.SetValue("amp", amp)
    state.SetValue("period", period)
    state.SetValue("after", after)
    state.SetValue("by", by)
    state.SetValue("add", add)
    state.SetValue("show", show)

    imgui.End()
end

--- Applies the tween over the entire selected region.
--- @param from number
--- @param to number
--- @param add boolean
--- @param after integer
--- @param by number
--- @param ease string
function section(from, to, add, after, by, amp, period, ease)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])

    if not svs[1] then
        print("Please select the region to modify before pressing this button.")
        return
    end

    local svsToAdd = {}
    svsToAdd[#svs] = nil

    for i, sv in ipairs(svs) do
        local f = (sv.StartTime - svs[1].StartTime) /
            (svs[#svs].StartTime - svs[1].StartTime)

        local fm = tween(f, from, to, amp, period, ease)
        local a = addormul(sv.Multiplier, fm, add)
        local v = afterfn(after, by)(a)
        svsToAdd[i] = utils.CreateScrollVelocity(sv.StartTime, v)
    end

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
end

--- Applies the tween over each note selected.
--- @param from number
--- @param to number
--- @param add boolean
--- @param after integer
--- @param by number
--- @param ease string
function perNote(from, to, add, after, by, amp, period, ease)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])

    if not svs[1] then
        print("Please select the region to modify before pressing this button.")
        return
    end

    local svsToAdd = {}
    svsToAdd[#svs] = nil

    for i, sv in ipairs(svs) do
        local b, e = findAdjacentNotes(sv, offsets)
        local f = (sv.StartTime - b) / (e - b)
        local fm = tween(f, from, to, amp, period, ease)
        local a = addormul(sv.Multiplier, fm, add)
        local v = afterfn(after, by)(a)
        svsToAdd[i] = utils.CreateScrollVelocity(sv.StartTime, v)
    end

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
end

--- Applies the tween over each SV selected.
--- @param from number
--- @param to number
--- @param add boolean
--- @param after integer
--- @param by number
--- @param ease string
--- @param count integer
function perSV(from, to, add, after, ease, by, amp, period, count)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])

    if not svs[2] then
        print("The selected region must contain at least 2 SV points.")
        return
    end

    local svsToAdd = {}
    local last = 0

    for i, sv in ipairs(svs) do
        local n = svs[i + 1]

        if not n then
            break
        end

        svsToAdd[last + count + 1] = nil

        for j = 0, count - 1, 1 do
            local f = j / (count - 1.0)
            local g = j / (count - 0.0)
            local fm = tween(f, from, to, amp, period, ease)
            local gm = tween(g, sv.StartTime, n.StartTime, 0, 0, "linear")
            local a = addormul(sv.Multiplier, fm, add)
            local v = afterfn(after, by)(a)
            last = last + 1
            svsToAdd[last] = utils.CreateScrollVelocity(gm, v)
        end
    end

    local final = svs[#svs]

    svsToAdd[#svsToAdd + 1] = utils.CreateScrollVelocity(
        final.StartTime,
        final.Multiplier
    )

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
end

--- Creates a function that steps through the SVs to return the position for the
--- note passed as milliseconds. If `nsv` is `false`, you must pass each number
--- in ascending order, or else the function will return incorrect values.
--- @param relative boolean
--- @param nsv boolean
--- @return function
function positionMarkers(relative, nsv)
    local first

    if not relative then
        first = 0
    end

    if nsv then
        return function(time)
            first = first or time
            return math.floor(toF32((time - first) * 100))
        end
    end

    local index = 2
    local pos

    return function(time)
        local svs = map.ScrollVelocities

        if not first and relative then
            while index < #svs and time >= svs[index].StartTime do
                index = index + 1
            end
        end

        if #svs == 0 or time < svs[1].StartTime then
            first = first or time
            return math.floor(toF32((time - first) * 100))
        end

        if not pos then
            if relative then
                pos = 0
            else
                pos = math.floor(toF32(svs[1].StartTime * 100))
            end
        end

        while index < #svs and time >= svs[index].StartTime do
            local prev = svs[index - 1]
            local next = toF32(svs[index].StartTime - prev.StartTime)
            next = toF32(next * prev.Multiplier)
            next = toF32(next * 100)
            pos = math.floor(toF32(pos + next))
            index = index + 1
        end

        local sv = svs[index - 1] or svs[#svs]
        local t = toF32(time - sv.StartTime)
        t = toF32(t * sv.Multiplier)
        local ret = pos + math.floor(toF32(t * 100))
        first = first or ret
        return ret - first
    end
end

--- Casts the parameter to a single-precision float.
--- @param x number
--- @return number
function toF32(x)
    -- Lua doesn't support single-precision floats, which is tricky because
    -- the game uses them for positioning. If we want our measure tool to be
    -- accurate, we too need to convert our numbers to single-precision floats.
    --
    -- The following works because the function takes a single-precision float
    -- that we can later access back. The way this function is intended to be
    -- used is to wrap every calculation with this function.
    --
    -- This is because for any binary operation `(f32 x, f32 y) -> f32`,
    -- we can losslessly emulate it as `toF32((f64 x, f64 y) -> f64)`.
    -- This cast is required for every single operation, so `(x - y) * z`
    -- cannot be `toF32((x - y) * z)`, but `toF32(toF32(x - y) * z)`.
    --
    -- If you use this workaround in your own plugin, please refer to it as
    -- "I love sticking floats onto the heap!". (and credit me)
    return utils.CreateScrollVelocity(x, 0).StartTime
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
--- @return ScrollVelocityInfo[]
function getSVsBetweenOffsets(startOffset, endOffset)
    if startOffset == nil or endOffset == nil then
        return {}
    end

    local svsBetweenOffsets = {}

    for _, sv in ipairs(map.ScrollVelocities) do
        if sv.StartTime >= startOffset and sv.StartTime < endOffset then
            table.insert(svsBetweenOffsets, sv)
        end
    end

    return svsBetweenOffsets
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

--- Gets the function from the corresponding index returned by Combo.
--- @param after integer
--- @param by number
--- @return function
function afterfn(after, by)
    local name = afters[after + 1]

    local overrides = {
        atan = atan(by),
        frac = frac,
        int = int,
        log = log(by),
        max = max(by),
        min = min(by),
        none = id,
        pow = pow(by),
        random = random
    }

    return overrides[name] or math[name] or error("Not implemented: " .. name)
end

--- Calculates the tween between a range.
--- @param f number
--- @param from number
--- @param to number
--- @param ease string
--- @return number
function tween(f, from, to, amp, period, ease)
    -- Lossless path: This prevents slight floating point inaccuracies.
    if from == to then
        return from
    end

    return easings()[ease](f, from, to - from, 1, amp, period)
end

--- Gets the full ease name applicable in `easing`.
--- @param type string
--- @param direction number
--- @return string
function fulleasename(type, direction)
    if types[type + 1] == "linear" then
        return "linear"
    end

    return dirs[direction + 1] .. types[type + 1]:gsub("^%l", string.upper)
end

--- Adds or multiplies two numbers based on the condition.
--- @param x number
--- @param y number
--- @param condition boolean
--- @return number
function addormul(x, y, condition)
    if condition then
        return x + y
    end

    return x * y
end

--- Converts a note to a string.
--- @param obj HitObjectInfo
--- @param mark string
--- @param fromEnd boolean
function noteString(obj, mark, fromEnd)
    if fromEnd then
        return tostring(obj.EndTime) .. "^  = " .. mark
    end

    return tostring(obj.StartTime) .. "|" .. tostring(obj.Lane) .. " = " .. mark
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
    return math.min(math.max(value, min), max)
end

--- Gets the value from the current state.
--- @param identifier string
--- @param defaultValue any
--- @return any
function get(identifier, defaultValue)
    return state.GetValue(identifier) or defaultValue
end

--- Gives the function to take the arc tangent of
--- its argument by the argument passed in here.
--- @param by number
--- @return function
function atan(by)
    return function(x)
        return math.atan(x, by)
    end
end

--- Gets the fractional part of the number.
--- @param x number
--- @return number
function frac(x)
    local _, ret = math.modf(x)
    return ret
end

--- Returns the argument (identity function).
--- @param x any
--- @return any
function id(x)
    return x
end

--- Gets the integral part of the number.
--- @param x number
--- @return number
function int(x)
    local ret, _ = math.modf(x)
    return ret
end

--- Gives the function to take the logarithm of its argument
--- by the base of the argument passed in here.
--- @param by number
--- @return function
function log(by)
    return function(x)
        return math.log(x, by)
    end
end

--- Gives the function to take the max of its
--- argument or the argument passed in here.
--- @param by number
--- @return function
function max(by)
    return function(x)
        return math.max(x, by)
    end
end

--- Gives the function to take the min of its
--- argument or the argument passed in here.
--- @param by number
--- @return function
function min(by)
    return function(x)
        return math.min(x, by)
    end
end

--- Gives the function to take the its argument
--- to the power of the argument passed in here.
--- @param by number
--- @return function
function pow(by)
    return function(x)
        return x ^ by
    end
end

--- Generates a random number starting or ending
--- the number, depending on its sign.
--- @param x number
--- @return number
function random(x)
    return math.random() * x
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
--- @param add boolean
--- @param after integer
--- @param by number
--- @param ease string
--- @param count number
function Plot(from, to, add, after, by, amp, period, ease, count)
    imgui.Begin("mulch plot", imgui_window_flags.AlwaysAutoResize)

    local heightValues = {}
    heightValues[count + 1] = nil
    local max = -1 / 0
    local min = 1 / 0

    for i = 0, count, 1 do
        local f = i / count
        local fm = tween(f, from, to, amp, period, ease)
        local a = addormul(1, fm, add)
        local v = afterfn(after, by)(a)
        heightValues[i + 1] = v
        max = math.max(v, max)
        min = math.min(v, min)
    end

    imgui.PlotLines(
        "",
        heightValues,
        #heightValues,
        0,
        ease .. ", " .. math.floor(min * 100 + 0.5) / 100 .. " to " ..
        math.floor(max * 100 + 0.5) / 100,
        min,
        max,
        { 300, 150 }
    )

    imgui.End()
end

--- Shows the calculator window.
function ShowCalculator()
    imgui.Begin("mulch calculator", imgui_window_flags.AlwaysAutoResize)

    local precise = get("precise", false) ---@type boolean
    local calculators = get("calculators", 1) ---@type number

    _, precise = imgui.Checkbox("precise", precise)

    Tooltip(
        "When enabled, displays higher precision,\n" ..
        "including floating point errors."
    )

    imgui.SameLine(0, 10)
    imgui.PushItemWidth(1)
    _, calculators = imgui.InputInt("calculators", calculators, 1, 1, textFlags)
    imgui.PopItemWidth()

    Tooltip("The number of calculators.\nEach text field is independent.")
    calculators = clamp(calculators, 1, 16)

    state.SetValue("calculators", calculators)
    state.SetValue("precise", precise)
    imgui.Separator()
    local calc = calculator()

    for i = 1, calculators do
        ShowOneCalculator(i, precise, calc)
    end

    imgui.End()
end

--- Shows one calculator.
--- @param i number
--- @param precise boolean
--- @param calc function
function ShowOneCalculator(i, precise, calc)
    local format = "%.17f"

    if not precise then
        format = "%f"
    end

    local key = "##calculate" .. tostring(i)
    local calculate = get(key, "") ---@type string

    imgui.PushItemWidth(200)
    _, calculate = imgui.InputText(key, calculate, 100)
    imgui.PopItemWidth()

    state.SetValue(key, calculate)
    local value, err = calc(calculate)

    if value then
        value = string.format(format, value):
          gsub("(%..-)0*$", "%1"):
          gsub("%.$", "")
    end

    if #calculate ~= 0 then
        imgui.SameLine(0, 10)
    end

    if #calculate ~= 0 and imgui.Button(value or ":c") then
        if #calculate == 0 then
            print("Please enter a calculation first.")
        elseif value then
            imgui.SetClipboardText(value)
            print("Copied '" .. value .. "' to clipboard.")
        else
            print(err)
        end
    end
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
    local name = "mulch positions (" .. tostring(#objects) .. " selected)"
    imgui.Begin(name)

    if #objects ~= lastSelected then
        imgui.SetWindowPos(name, lastPosition)
        imgui.SetWindowSize(name, lastSize)
    end

    local relative = get("relative", false) ---@type boolean
    local nsv = get("nsv", false) ---@type boolean
    _, relative = imgui.Checkbox("relative", relative)

    Tooltip(
        "Distance will be relative to the first selected note, " ..
        "making the first selected note always 0."
    )

    imgui.SameLine(0, 10)
    _, nsv = imgui.Checkbox("nsv", nsv)
    Tooltip("Distance is measured without considering SVs.")
    imgui.Separator()

    if #objects == 0 then
    elseif #objects == lastSelected and
        lastNsv == nsv and
        lastRelative == relative and
        not refresh then
        for i = 1, #objects, 1 do
            local obj = objects[i]
            local position = lastSelectables[i * 2]

            if imgui.Selectable(noteString(obj, position, false)) then
                imgui.SetClipboardText(position)
                print("Copied '" .. position .. "' to clipboard.")
            end

            if obj.EndTime ~= 0 then
                position = lastSelectables[i * 2 + 1]

                if imgui.Selectable(noteString(obj, position, true)) then
                    imgui.SetClipboardText(position)
                    print("Copied '" .. position .. "' to clipboard.")
                end
            end
        end
    else
        lastSelectables[#objects] = nil
        local markers = positionMarkers(relative, nsv)

        for i = 1, #objects, 1 do
            local obj = objects[i]
            local position = tostring(markers(obj.StartTime) / 100)
            lastSelectables[i * 2] = position

            if imgui.Selectable(noteString(obj, position, false)) then
                imgui.SetClipboardText(position)
                print("Copied '" .. position .. "' to clipboard.")
            end

            if obj.EndTime == 0 then
                lastSelectables[i * 2 + 1] = nil
            else
                position = tostring(markers(obj.EndTime) / 100)
                lastSelectables[i * 2 + 1] = position

                if imgui.Selectable(noteString(obj, position, true)) then
                    imgui.SetClipboardText(position)
                    print("Copied '" .. position .. "' to clipboard.")
                end
            end
        end
    end

    state.SetValue("relative", relative)
    state.SetValue("nsv", nsv)
    lastPosition = imgui.GetWindowPos(name)
    lastSize = imgui.GetWindowSize(name)
    lastSelected = #objects
    lastRelative = relative
    lastNsv = nsv
    imgui.End()
end

--- Creates a tooltip hoverable element.
--- @param text string
function Tooltip(text)
    imgui.SameLine(0, 5)
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
    local rounding = 25
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
    imgui.PushStyleVar(imgui_style_var.WindowMinSize, { 240, 0 })
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
    }
end

--- Returns a function that can compute string expressions.
function calculator()
    -- Huge thanks to Noble-Mushtak's implementation:
    -- https://gist.github.com/Noble-Mushtak/a2eb302003891c85b562
    function characterPresent(stringParam, character)
        --[[
            This function returns true if and only if character is in stringParam.
        ]]--
        --Loop through stringParam:
        for i=1, #stringParam do
            --If the current character is character, return true.
            if stringParam:sub(i, i) == character then return true end
        end
        --If we go through the whole string without returning true, we get to this point.
        --This means we've checked every character and haven't found character, so we return false.
        return false
    end

    function getNumber(stringParam)
        --[[
            This function parses a number from the beginning of stringParam and also returns the rest of the string.
            For example, if stringParam is "23s", this function returns 23, "s".
            If there is no number at the beginning of stringParam (e.g., stringParam is "Hi"), then the function returns nil, stringParam.
        ]]--
        --These are all of the characters we would expect in a number.
        local validCharacters = "0123456789.-"
        --This is true if and only if we have found a digit.
        local foundDigit = false
        --This is the index of the character in stringParam we are currently looking at.
        local i = 1
        --This is the character in stringParams we are currently looking at.
        local currentCharacter = stringParam:sub(i, i)
        --We want to examine stringParam while the current character is a valid character:
        while characterPresent(validCharacters, currentCharacter) do
            --In the first character, get rid of the - from validCharacters because we do not want a negative sign after the number has already begun. Negative signs must always be the first character in a number.
            if i == 1 then validCharacters = "0123456789." end
            --If currentCharacter is a decimal point, then make get rid of the . and - from validCharacters because we only want one decimal point and a negative sign can not come after a decimal point.
            if currentCharacter == "." then validCharacters = "0123456789" end
            --If currentCharacter is a digit, then make foundDigit true:
            if characterPresent("0123456789", currentCharacter) then foundDigit = true end
            --Finally, increment i to go to the next character.
            i = i+1
            --If i has gone past the length of stringParam, then there are no more characters and the loop should be exited.
            if i > #stringParam then break end
            --Otherwise, update currentCharacter.
            currentCharacter = stringParam:sub(i, i)
        end
        --If we have not found a digit, then we have not found a number, so go back to the beginning of the string to signify that stringParam does not have a number at the beginning.
        if not foundDigit then i = 1 end
        --Parse the number from the beginningof the string up till i.
        local number = tonumber(stringParam:sub(1, i-1))
        --Finally, return the number and the rest of the string.
        return number, stringParam:sub(i, #stringParam)
    end

    function parseExpression(expression, expectEndParentheses)
        --[[
            This function parses expression and returns the mathematical value of expression along with the rest of expression that was not parsed.
            If expectEndParentheses is not specified, it defaults to false.
            If expectEndParentheses is false, then the whole expression is parsed. If the expression is valid, what is returned is the value of the expression along with the empty string.
            If expectEndParentheses is true, then the expression is parsed up until the first end parentheses without a matching beginning parentheses. If the expression is valid, what is returned is the value of the expression along with the rest of expression after the end parentheses.
            In both cases, if the expression is invalid, the. what is returned is nil along with an error message.
            For example:
            parseExpression("2+3") -> 5, ""
            parseExpression("Hi") -> nil, "Invalid input where number or '(' was expected"
            parseExpression("2+3)+5", true) -> 5, "+5"
        ]]--
        --This is true if and only if we are expecting an expression next instead of an operator.
        local expectingExpression = true
        --This is true if and only if the last expression examined was surrounded by parentheses.
        local lastExpressionWasParenthetical = false
        --These are all the operators in our parser.
        local operators = "+-/*^"
        --This is a list of all of the parts in our expression.
        local parts = {}
        --This is true if and only if we have found an unmatched end parentheses.
        local foundEndParentheses = false
        --If expectEndParentheses is not specified, make it default to false.
        expectEndParentheses = expectEndParentheses or false
        --We want to parse the expression until we have broken it up into all of its parts and there is nothing left to parse:
        while expression ~= "" do
            --Check if there is a number at the beginning of expression.
            local nextNumber, expressionAfterNumber = getNumber(expression)
            --This is the next character:
            local nextCharacter = expression:sub(1, 1)
            --This is the next piece of the expression, used in error messages:
            local nextPiece = expression:sub(1, 5)
            --Add " [end]" if expression has 5 characters or less to signify that this piece is the end of the expression
            if #expression <= 5 then nextPiece = nextPiece.." [end]" end
            --If we expect an expression:
            if expectingExpression then
                --If there is a beginning parentheses next, parse the expression inside the parentheses:
                if nextCharacter == "(" then
                    --Parse the next expression by taking the beginning parentheses off and outting the rest of the expression into parseExpression. Also, make expectEndParentheses true so that the expression will only be parsed up to the next end parentheses that is not matched without this beginning parentheses.
                    local nestedExpressionValue, expressionAfterParentheses = parseExpression(expression:sub(2, #expression), true)
                    --If the value returned is nil, then parsing this expression must have caused an error, so return the error message.
                    if nestedExpressionValue == nil then return nestedExpressionValue, expressionAfterParentheses end
                    --Otherwise, insert the value into parts.
                    table.insert(parts, nestedExpressionValue)
                    --Also, update expression by going on to what's after the parentheses.
                    expression = expressionAfterParentheses
                    --Make lastExpressionWasParenthetical true.
                    lastExpressionWasParenthetical = true
                --Otherwise, if there is no parentheses, parse the next number:
                else
                    --If the next number is nil, then return an error message.
                    if nextNumber == nil then return nil, "Expected number or '(', but found '"..nextPiece.."'" end
                    --Otherwise, insert the number into parts.
                    table.insert(parts, nextNumber)
                    --Also, update expression by going on to what's after the number.
                    expression = expressionAfterNumber
                    --Make lastExpressionWasParenthetical false.
                    lastExpressionWasParenthetical = false
                end
            --The following cases deal with the case that we expect an operator instead of an expression.
            --If the next character is an operator:
            elseif characterPresent(operators, nextCharacter) then
                --Insert the operator into parts.
                table.insert(parts, nextCharacter)
                --Also, update expression by taking out the operator.
                expression = expression:sub(2, #expression)
            --If the next character is a beginning parentheses or the preceding character was an end parentheses and there is a valid number after it, insert a multiplication sign.
            elseif nextCharacter == "(" or (lastExpressionWasParenthetical and nextNumber ~= nil) then table.insert(parts, "*")
            --If the next character is an end parentheses:
            elseif nextCharacter == ")" then
                --If we expect an end parentheses:
                if expectEndParentheses then
                    --Take the parentheses out of the expression.
                    expression = expression:sub(2, #expression)
                    --Set foundEndParentheses to true and exit the while loop.
                    foundEndParentheses = true
                    break
                --Otherwise, if we were not expecting an end parentheses, then return an error message.
                else return nil, "')' present without matching '(' at '"..nextPiece.."'" end
            --If none of the above cases apply, then the expression must be invalid, so return an error message.
            else return nil, "Expected expression, but found '"..nextPiece.."'" end
            --If we are expecting an expression, switch to expecting an operator and vice versa.
            expectingExpression = not expectingExpression
        end
        --If, at the end, we are left expecting an expression or have not found an end parentheses despite being told we would, then the expression ended before it was supposed to, so return an error message.
        if expectEndParentheses and not foundEndParentheses then return nil, "Expression unexpectedly ended ('(' present without matching ')')" end
        if expectingExpression then return nil, "Expression unexpectedly ended" end
        --Otherwise, the expression has been parsed successfully, so now we must evaulate it.
        --Loop through parts backwards and evaluate the exponentiation operations:
        --Notice that we loop through exponentiation since exponentiation is right-associative (2^3^4=2^81, not 8^4) and that we do not use a for loop since the value of #parts is going to change.
        local i = #parts
        while i >= 1 do
            --If the current part is an exponentiation operator, evaluate the operation, put the result in the slot of the former number, and remove the operator along with the latter number.
            if parts[i] == "^" then
                parts[i-1] = parts[i-1]^parts[i+1]
                table.remove(parts, i+1)
                table.remove(parts, i)
            end
            --Decrement i.
            --Notice that we decrement i regardless of if we have just encountered an exponentiation operator. This is because since we are going backwards, the operator we are on after removing the exponentiation operator must have been ahead of the exponentiation operator in the expression and thus could not have been an exponentiation operator.
            --To understand this better, examine the expression "2^3*4^5". How would this while loop deal with that expression by making sure that all of the exponentiation operations are evaluated?
            i = i-1
        end
        --Loop through parts forwards and evaluate the multiplication and division operators.
        --Notice that we loop forward since division is left-associative (1/2/4=0.5/4, not 1/0.5).
        i = 1
        while i <= #parts do
            --If the current part is a multiplication operator, evaluate the operation, put the result in the slot of the former number, and remove the operator along with the latter number.
            if parts[i] == "*" then
                parts[i-1] = parts[i-1]*parts[i+1]
                table.remove(parts, i+1)
                table.remove(parts, i)
            --If the current part is an division operator, evaluate the operation, put the result in the slot of the former number, and remove the operator along with the latter number.
            elseif parts[i] == "/" then
                parts[i-1] = parts[i-1]/parts[i+1]
                table.remove(parts, i+1)
                table.remove(parts, i)
            --Increment if the current part is not an operator.
            --Notice that we make this incrementation conditional. This is because since we are going backwards, incrementing after we have just processed an operator could make us skip a multiplication or division operator by hopping over it.
            --To understand this better, examine the expression "1/2/3". How does making this incrementation conditional prevent us from skipping over a division operator?
            else i = i+1 end
        end
        --Loop through parts forwards and evaluate the addition and subtraction operators.
        --Notice that we loop forward since subtraction is left-associative (1-2-3=-1-3, not 1-(-1)).
        i = 1
        while i <= #parts do
            --If the current part is an exponentiation operator, evaluate the operation, put the result in the slot of the former number, and remove the operator along with the latter number.
            if parts[i] == "+" then
                parts[i-1] = parts[i-1]+parts[i+1]
                table.remove(parts, i+1)
                table.remove(parts, i)
            --If the current part is an exponentiation operator, evaluate the operation, put the result in the slot of the former number, and remove the operator along with the latter number.
            elseif parts[i] == "-" then
                parts[i-1] = parts[i-1]-parts[i+1]
                table.remove(parts, i+1)
                table.remove(parts, i)
            --Just like with multiplication and division, increment i if the current part is not an operator.
            else i = i+1 end
        end
        --Finally, return the answer (which is in the first element of parts) along with the rest of the expression to be parsed.
        return parts[1], expression
    end

    return function(x)
        x, _ = x:gsub("%s", "")
        return parseExpression(x)
    end
end
