-- Gets a value from the current state
-- Parameters
--    identifier   : The key [String]
--    defaultValue : The fallback [Any]
function get(identifier, defaultValue)
    return state.GetValue(identifier) or defaultValue
end

-- Sorting function for numbers that returns whether a < b [Boolean]
-- Parameters
--    a : first number [Int/Float]
--    b : second number [Int/Float]
function sortAscending(a, b) return a < b end

-- Sorting function for SVs 'a' and 'b' that returns whether a.StartTime < b.StartTime [Boolean]
-- Parameters
--    a : first SV
--    b : second SV
function sortAscendingStartTime(a, b) return a.StartTime < b.StartTime end

-- Combs through a list and locates unique values
-- Returns a list of only unique values (no duplicates) [Table]
-- Parameters
--    list : list of values [Table]
function removeDuplicateValues(list)
    local hash = {}
    local newList = {}
    for _, value in ipairs(list) do
        if (not hash[value]) then
            newList[#newList + 1] = value
            hash[value] = true
        end
    end
    return newList
end

-- Finds unique offsets of all notes currently selected in the editor
-- Returns a list of unique offsets (in increasing order) of selected notes [Table]
function uniqueSelectedNoteOffsets()
    local offsets = {}
    for i, hitObject in pairs(state.SelectedHitObjects) do
        offsets[i] = hitObject.StartTime
    end
    offsets = removeDuplicateValues(offsets)
    offsets = table.sort(offsets, sortAscending)
    return offsets
end

-- Returns an chronologically ordered list of SVs between two offsets/times [Table]
-- Parameters
--    startOffset : start time in milliseconds [Int/Float]
--    endOffset   : end time in milliseconds [Int/Float]
function getSVsBetweenOffsets(startOffset, endOffset)
    local svsBetweenOffsets = {}
    for _, sv in pairs(map.ScrollVelocities) do
        local svIsInRange = sv.StartTime >= startOffset and sv.StartTime < endOffset
        if svIsInRange then table.insert(svsBetweenOffsets, sv) end
    end
    return table.sort(svsBetweenOffsets, sortAscendingStartTime)
end

-- Finds the adjacent notes of a set of notes
-- Returns a tuple of a previous [Float] and next [Float] note 
-- Parameters
--     sv    : the list of SVs
--     notes : the list of notes
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

-- Applies the linear tween per selected region
-- Parameters
--     from : the starting value multiplier [Float]
--     to   : the ending value multiplier [Float]
function perSection(from, to)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])
    local svsToAdd = {}

    for key, sv in pairs(svs) do
        local f = (sv.StartTime - svs[1].StartTime) / (svs[#svs].StartTime - svs[1].StartTime)
        local fm = from * (1 - f) + to * f
	    table.insert(svsToAdd, utils.CreateScrollVelocity(sv.StartTime, sv.Multiplier * fm))
    end

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
end

-- Applies the linear tween per note
-- Parameters
--     from : the starting value multiplier [Float]
--     to   : the ending value multiplier [Float]
function perNote(from, to)
    local offsets = uniqueSelectedNoteOffsets()
    local svs = getSVsBetweenOffsets(offsets[1], offsets[#offsets])
    local svsToAdd = {}

    for key, sv in pairs(svs) do
        local b, e = findAdjacentNotes(sv, offsets)
        local f = (sv.StartTime - b) / (e - b)
        local fm = from * (1 - f) + to * f
    	table.insert(svsToAdd, utils.CreateScrollVelocity(sv.StartTime, sv.Multiplier * fm))
    end

    actions.PerformBatch({
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svs),
        utils.CreateEditorAction(action_type.AddScrollVelocityBatch, svsToAdd)
    })
end

-- The main function
function draw()
    imgui.Begin("mul")

    local from = get("from", 0)
    _, from = imgui.InputFloat("from", from)
    state.SetValue("from", from)

    local to = get("to", 0)
    _, to = imgui.InputFloat("to", to)
    state.SetValue("to", to)

    if imgui.Button("per section") or utils.IsKeyPressed(keys.Y) then
        perSection(from, to)
    end

    if imgui.Button("per note") or utils.IsKeyPressed(keys.U) then
        perNote(from, to)
    end

    imgui.End()
end

