--- @class HitObjectInfo
--- @field StartTime number
--- @field Lane 1|2|3|4|5|6|7|8
--- @field EndTime number
--- @field HitSound any
--- @field EditorLayer integer

--- @class ScrollVelocityInfo
--- @field StartTime number
--- @field Multiplier number

local afters = { "none", "abs", "acos", "asin", "atan", "ceil", "cos", "deg", "exp", "floor", "log", "modf", "rad", "random", "sin", "sqrt", "tan" }

-- The main function
function draw()
    imgui.Begin("mul")
    local from = get("from", 0)
    local to = get("to", 1)
    local count = get("count", 16)
    local after = get("after", 0)

    _, from = imgui.InputFloat("from", from)
    Tooltip("The SV value to multiply by at the start of a group.")
    _, to = imgui.InputFloat("to", to)
    Tooltip("The SV value to multiply by at the end of a group.")
    _, after = imgui.Combo("after", after, afters, #afters)
    Tooltip("The function to apply after the tween calculation.")
    _, count = imgui.InputInt("count", count)
    Tooltip("This parameter only applies to 'per sv'.\nNumber of points between SVs.")
    count = clamp(count, 1, 10000)

    if imgui.Button("swap") or utils.IsKeyPressed(keys.U) then
        from, to = to, from
    end

    Tooltip("Alternatively, press U to perform this action.")
    imgui.SameLine(0, 4)
    ActionButton("per section", "I", perSection, { from, to, after })
    ActionButton("per note", "O", perNote, { from, to, after })
    imgui.SameLine(0, 4)
    ActionButton("per sv", "P", perSV, { from, to, after, count })
    state.SetValue("from", from)
    state.SetValue("to", to)
    state.SetValue("count", count)
    state.SetValue("after", after)
    imgui.End()
end

--- Applies the linear tween per selected region
--- @param from number
--- @param to number
function perSection(from, to, after)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])
    local svsToAdd = {}

    if not svs[1] then
        print("Please select the region you wish to modify before pressing this button.")
        return
    end

    for _, sv in pairs(svs) do
        local f = (sv.StartTime - svs[1].StartTime) / (svs[#svs].StartTime - svs[1].StartTime)
        table.insert(svsToAdd, utils.CreateScrollVelocity(sv.StartTime, afterfn(after)(sv.Multiplier * tween(f, from, to))))
    end

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
end

--- Applies the linear tween per note
--- @param from number
--- @param to number
function perNote(from, to, after)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])

    if not svs[1] then
        print("Please select the region you wish to modify before pressing this button.")
        return
    end

    local svsToAdd = {}

    for _, sv in pairs(svs) do
        local b, e = findAdjacentNotes(sv, offsets)
        local f = (sv.StartTime - b) / (e - b)
        table.insert(svsToAdd, utils.CreateScrollVelocity(sv.StartTime, afterfn(after)(sv.Multiplier * tween(f, from, to))))
    end

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
end

---Applies the linear tween per note
---@param from number
---@param to number
function perSV(from, to, after, count)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])
    local svsToAdd = {}

    if not svs[2] then
        print("Your selected region must contain at least 2 SV points for this action to work.")
        return
    end

    for i, sv in ipairs(svs) do
        local n = svs[i + 1]

        if not n then
            break
        end

        for j = 0, count, 1 do
            local f = j / tonumber(count - 1)
            table.insert(svsToAdd, utils.CreateScrollVelocity(tween(f, sv.StartTime, n.StartTime), afterfn(after)(sv.Multiplier * tween(f, from, to))))
        end
    end

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
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

--- Returns the list of unique offsets (in increasing order) of selected notes [Table]
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
    local svsBetweenOffsets = {}

    if startOffset == nil or endOffset == nil then
        return svsBetweenOffsets
    end

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
--- @param after number
--- @return function
function afterfn(after)
    local name = afters[after + 1]

    if name == "random" then
        return random
    end

    return math[name] or id
end

-- Calculates the linear tween between a range.
-- @param f number
-- @param from number
-- @param to number
-- @param after string
-- @return number
function tween(f, from, to)
    -- Lossless path: This prevents slight floating point inaccuracies.
    if from == to then
        return from
    end

    return from * (1 - f) + to * f
end

-- Clamps the value between a minimum and maximum value.
-- @param value number
-- @param min number
-- @param max number
-- @return number
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

--- Generates a random number starting or ending the number, depending on its sign.
--- @param x number
--- @return number
function random(x)
    return math.random() * x
end

--- Returns the argument.
--- @param identifier any
--- @return any
function id(x)
    return x
end

--- Creates a button that runs a function using `from` and `to`.
--- @param label string
--- @param key string
--- @param fn function
--- @param tbl table
function ActionButton(label, key, fn, tbl)
    if imgui.Button(label) or utils.IsKeyPressed(keys[key]) then
        fn(table.unpack(tbl))
    end

    Tooltip("Alternatively, press " .. key .. " to perform this action.")
end

--- Creates a tooltip hoverable element.
--- @param text string
function Tooltip(text)
    imgui.SameLine(0, 4)
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
