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

fn refreshRangeList lb =
(
    local sel = lb.SelectedIndex
    lb.BeginUpdate()
    lb.Items.Clear()
    for i = 1 to TimeSliderRanges.count do
        lb.Items.Add (formatRangeLabel i TimeSliderRanges[i])
    lb.EndUpdate()
    if sel >= 0 and sel < lb.Items.count do lb.SelectedIndex = sel
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

    dotNetControl lstRanges "System.Windows.Forms.ListBox" pos:[10,85] width:230 height:134

    button btnMoveUp "Move Up" pos:[10,225] width:112 height:22
    button btnMoveDown "Move Down" pos:[128,225] width:112 height:22
    button btnFitToKeys "Fit to Keys" pos:[10,253] width:230 height:28

    fn doLayout w h =
    (
        local m = 10
        local innerW = w - m * 2
        local innerPad = 10

        grpInput.pos = [m, m]
        grpInput.width = innerW

        local halfInner = (innerW - innerPad * 2) / 2
        btnStart.pos = [m + innerPad, 27]
        spnStart.pos = [m + innerPad + 45, 28]

        local midX = m + innerPad + halfInner
        btnEnd.pos = [midX, 27]
        spnEnd.pos = [midX + 40, 28]

        local btnW = (innerW - innerPad * 2) / 3
        btnAdd.pos = [m + innerPad, 50]
        btnAdd.width = btnW - 2
        btnEdit.pos = [m + innerPad + btnW, 50]
        btnEdit.width = btnW - 2
        btnDelete.pos = [m + innerPad + btnW * 2, 50]
        btnDelete.width = btnW - 2

        local fitH = 28
        local moveH = 22
        local gap = 6
        btnFitToKeys.pos = [m, h - fitH - m]
        btnFitToKeys.width = innerW

        local moveY = h - fitH - gap - moveH - m
        btnMoveUp.pos = [m, moveY]
        btnMoveUp.width = (innerW - gap) / 2
        btnMoveDown.pos = [m + (innerW - gap) / 2 + gap, moveY]
        btnMoveDown.width = (innerW - gap) / 2

        lstRanges.pos = [m, 85]
        lstRanges.width = innerW
        local listPixelH = moveY - 85 - gap
        if listPixelH < 30 do listPixelH = 30
        lstRanges.height = listPixelH
    )

    local layoutReady = false

    on TimeSliderSelectorDialog open do
    (
        lstRanges.IntegralHeight = false
        lstRanges.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 68 68 68
        lstRanges.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 220 220 220
        lstRanges.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle

        spnStart.value = animationRange.start
        spnEnd.value = animationRange.end
        loadRangesFromFileProps()
        refreshRangeList lstRanges
        layoutReady = true
    )

    on btnMoveUp pressed do
    (
        local idx = lstRanges.SelectedIndex + 1
        if idx > 1 and idx <= TimeSliderRanges.count then
        (
            swap TimeSliderRanges[idx] TimeSliderRanges[idx - 1]
            refreshRangeList lstRanges
            lstRanges.SelectedIndex = idx - 2
            saveRangesToFileProps()
        )
    )

    on btnMoveDown pressed do
    (
        local idx = lstRanges.SelectedIndex + 1
        if idx > 0 and idx < TimeSliderRanges.count then
        (
            swap TimeSliderRanges[idx] TimeSliderRanges[idx + 1]
            refreshRangeList lstRanges
            lstRanges.SelectedIndex = idx
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
        lstRanges.SelectedIndex = TimeSliderRanges.count - 1
        saveRangesToFileProps()
    )

    on btnDelete pressed do
    (
        local idx = lstRanges.SelectedIndex + 1
        if idx > 0 and idx <= TimeSliderRanges.count then
        (
            deleteItem TimeSliderRanges idx
            refreshRangeList lstRanges
            saveRangesToFileProps()
        )
    )

    on btnEdit pressed do
    (
        local idx = lstRanges.SelectedIndex + 1
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
            lstRanges.SelectedIndex = idx - 1
            saveRangesToFileProps()
        )
    )

    on lstRanges SelectedIndexChanged sender args do
    (
        local idx = lstRanges.SelectedIndex + 1
        if idx > 0 and idx <= TimeSliderRanges.count then
        (
            local rangeData = TimeSliderRanges[idx]
            spnStart.value = rangeData.startFrame
            spnEnd.value = rangeData.endFrame
        )
    )

    on lstRanges MouseDoubleClick sender args do
    (
        local idx = lstRanges.SelectedIndex + 1
        if idx > 0 and idx <= TimeSliderRanges.count then
        (
            local rangeData = TimeSliderRanges[idx]
            spnStart.value = rangeData.startFrame
            spnEnd.value = rangeData.endFrame
            animationRange = interval rangeData.startFrame rangeData.endFrame
            sliderTime = rangeData.startFrame
        )
    )

    on TimeSliderSelectorDialog resized val do
    (
        if layoutReady do doLayout val.x val.y
    )
)


callbacks.addScript #filePostOpen "if TimeSliderSelectorDialog != undefined and TimeSliderSelectorDialog.open then (loadRangesFromFileProps(); refreshRangeList TimeSliderSelectorDialog.lstRanges)" id:#TimeSliderSelector
callbacks.addScript #systemPostNew "TimeSliderRanges = #(); if TimeSliderSelectorDialog != undefined and TimeSliderSelectorDialog.open then (refreshRangeList TimeSliderSelectorDialog.lstRanges)" id:#TimeSliderSelector

createDialog TimeSliderSelectorDialog width:250 height:290 style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing)
