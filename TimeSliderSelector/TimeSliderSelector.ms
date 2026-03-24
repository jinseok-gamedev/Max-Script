try (destroyDialog TimeSliderSelectorDialog) catch()
callbacks.removeScripts id:#TimeSliderSelector

global TimeSliderSelectorDialog

struct TimeRangeData (
    startFrame,
    endFrame
)

global TimeSliderRanges = #()

fn formatRangeLabel idx rangeData =
(
    (idx as string) + ". " + (rangeData.startFrame as string) + " ~ " + (rangeData.endFrame as string)
)

fn refreshRangeList listBox =
(
    listBox.items = for i = 1 to TimeSliderRanges.count collect (formatRangeLabel i TimeSliderRanges[i])
)

fn saveRangesToFileProps =
(
    local str = ""
    for i = 1 to TimeSliderRanges.count do
    (
        local r = TimeSliderRanges[i]
        str += (r.startFrame as string) + "," + (r.endFrame as string)
        if i < TimeSliderRanges.count then str += ";"
    )
    if (fileProperties.findProperty #custom "TimeSliderRanges") > 0 then
        fileProperties.deleteProperty #custom "TimeSliderRanges"
    fileProperties.addProperty #custom "TimeSliderRanges" str
)

fn loadRangesFromFileProps =
(
    TimeSliderRanges = #()
    local idx = fileProperties.findProperty #custom "TimeSliderRanges"
    if idx > 0 then
    (
        local str = fileProperties.getPropertyValue #custom idx
        if str != undefined and str != "" then
        (
            local pairs = filterString str ";"
            for p in pairs do
            (
                local vals = filterString p ","
                if vals.count == 2 then
                    append TimeSliderRanges (TimeRangeData startFrame:(vals[1] as integer) endFrame:(vals[2] as integer))
            )
        )
    )
)

fn collectKeysFromController ctrl minKey maxKey =
(
    if ctrl == undefined then return #(minKey, maxKey)
    try
    (
        if (numKeys ctrl) > 0 then
        (
            for k in ctrl.keys do
            (
                local t = k.time.frame as integer
                if minKey == undefined or t < minKey then minKey = t
                if maxKey == undefined or t > maxKey then maxKey = t
            )
        )
    )
    catch ()
    for i = 1 to ctrl.numSubs do
    (
        local sub = ctrl[i].controller
        if sub != undefined then
        (
            local result = collectKeysFromController sub minKey maxKey
            minKey = result[1]
            maxKey = result[2]
        )
    )
    #(minKey, maxKey)
)

fn getKeyRangeFromAllObjects =
(
    local minKey = undefined
    local maxKey = undefined
    for obj in objects do
    (
        if obj.controller != undefined then
        (
            local result = collectKeysFromController obj.controller minKey maxKey
            minKey = result[1]
            maxKey = result[2]
        )
    )
    if minKey != undefined and maxKey != undefined then
        #(minKey, maxKey)
    else
        undefined
)

rollout TimeSliderSelectorDialog "Time Slider Selector" width:250
(
    groupBox grpInput "Range Input" pos:[10,10] width:230 height:70
	button btnStart "Start" pos:[20,27] height:17
    spinner spnStart pos:[65,28] width:55 height:15 type:#integer range:[-100000,100000,0] scale:1
	button btnEnd "End" pos:[130,27] height:17
    spinner spnEnd pos:[170,28] width:60 height:15 type:#integer range:[-100000,100000,100] scale:1
    button btnAdd "Add" pos:[20,50] width:68 height:22
    button btnEdit "Edit" pos:[91,50] width:68 height:22
    button btnDelete "Delete" pos:[162,50] width:68 height:22

    listBox lstRanges "" pos:[10,85] width:230 height:10

    button btnMoveUp "Move Up" pos:[10,225] width:112 height:22
    button btnMoveDown "Move Down" pos:[128,225] width:112 height:22
    button btnFitToKeys "Fit to Keys" pos:[10,253] width:230 height:28

    on TimeSliderSelectorDialog open do
    (
        spnStart.value = animationRange.start
        spnEnd.value = animationRange.end
        loadRangesFromFileProps()
        refreshRangeList lstRanges
    )

    on btnMoveUp pressed do
    (
        local idx = lstRanges.selection
        if idx > 1 and idx <= TimeSliderRanges.count then
        (
            swap TimeSliderRanges[idx] TimeSliderRanges[idx - 1]
            refreshRangeList lstRanges
            lstRanges.selection = idx - 1
            saveRangesToFileProps()
        )
    )

    on btnMoveDown pressed do
    (
        local idx = lstRanges.selection
        if idx > 0 and idx < TimeSliderRanges.count then
        (
            swap TimeSliderRanges[idx] TimeSliderRanges[idx + 1]
            refreshRangeList lstRanges
            lstRanges.selection = idx + 1
            saveRangesToFileProps()
        )
    )

    on btnFitToKeys pressed do
    (
        local result = getKeyRangeFromAllObjects()
        if result != undefined then
        (
            local s = result[1]
            local e = result[2]
            if s == e then e = s + 1
            spnStart.value = s
            spnEnd.value = e
            animationRange = interval s e
            sliderTime = s
        )
        else
        (
            messageBox "No keyed object found in the scene."
        )
    )

	on btnStart pressed do
    (
		spnStart.value = animationRange.start
    )

	on btnEnd pressed do
    (
		spnEnd.value = animationRange.end
    )
	
    on btnAdd pressed do
    (
        local startVal = spnStart.value
        local endVal = spnEnd.value
        if startVal > endVal then
        (
            local temp = startVal
            startVal = endVal
            endVal = temp
        )

        append TimeSliderRanges (TimeRangeData startFrame:startVal endFrame:endVal)
        refreshRangeList lstRanges
        lstRanges.selection = TimeSliderRanges.count
        saveRangesToFileProps()
    )

    on btnDelete pressed do
    (
        local idx = lstRanges.selection
        if idx != undefined and idx > 0 and idx <= TimeSliderRanges.count then
        (
            deleteItem TimeSliderRanges idx
            refreshRangeList lstRanges
            saveRangesToFileProps()
        )
    )

    on btnEdit pressed do
    (
        local idx = lstRanges.selection
        if idx > 0 and idx <= TimeSliderRanges.count then
        (
            local startVal = spnStart.value
            local endVal = spnEnd.value
            if startVal > endVal then
            (
                local temp = startVal
                startVal = endVal
                endVal = temp
            )
            TimeSliderRanges[idx].startFrame = startVal
            TimeSliderRanges[idx].endFrame = endVal
            refreshRangeList lstRanges
            lstRanges.selection = idx
            saveRangesToFileProps()
            animationRange = interval startVal endVal
            sliderTime = startVal
        )
    )

    on lstRanges selected idx do
    (
        if idx != undefined and idx > 0 and idx <= TimeSliderRanges.count then
        (
            local rangeData = TimeSliderRanges[idx]
            spnStart.value = rangeData.startFrame
            spnEnd.value = rangeData.endFrame
            animationRange = interval rangeData.startFrame rangeData.endFrame
            sliderTime = rangeData.startFrame
        )
    )
)


callbacks.addScript #filePostOpen "if TimeSliderSelectorDialog != undefined and TimeSliderSelectorDialog.open then (loadRangesFromFileProps(); refreshRangeList TimeSliderSelectorDialog.lstRanges)" id:#TimeSliderSelector
callbacks.addScript #systemPostNew "TimeSliderRanges = #(); if TimeSliderSelectorDialog != undefined and TimeSliderSelectorDialog.open then (refreshRangeList TimeSliderSelectorDialog.lstRanges)" id:#TimeSliderSelector

createDialog TimeSliderSelectorDialog
