try (if DialogMinSizeInstance != undefined do (DialogMinSizeInstance.Cleanup(); DialogMinSizeInstance = undefined)) catch()
try (destroyDialog TimeSliderSelectorDialog) catch()
callbacks.removeScripts id:#TimeSliderSelector

global TimeSliderSelectorDialog
global DialogMinSizeInstance
global DialogMinSizerType

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

fn initDialogMinSize hwnd minW minH =
(
    try
    (
        if DialogMinSizeInstance != undefined do
        (
            try (DialogMinSizeInstance.Cleanup()) catch()
            DialogMinSizeInstance = undefined
        )

        if DialogMinSizerType == undefined do
        (
            local code = ""
            code += "using System;\n"
            code += "using System.Windows.Forms;\n"
            code += "using System.Runtime.InteropServices;\n"
            code += "public class DialogMinSizer : NativeWindow {\n"
            code += "    int minW, minH;\n"
            code += "    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }\n"
            code += "    [StructLayout(LayoutKind.Sequential)] public struct MINMAXINFO {\n"
            code += "        public POINT ptReserved; public POINT ptMaxSize; public POINT ptMaxPosition;\n"
            code += "        public POINT ptMinTrackSize; public POINT ptMaxTrackSize;\n"
            code += "    }\n"
            code += "    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }\n"
            code += "    [DllImport(\"user32.dll\")] static extern bool GetWindowRect(IntPtr h, out RECT r);\n"
            code += "    [DllImport(\"user32.dll\")] static extern bool GetClientRect(IntPtr h, out RECT r);\n"
            code += "    public void Setup(IntPtr hwnd, int cw, int ch) {\n"
            code += "        RECT wr, cr; GetWindowRect(hwnd, out wr); GetClientRect(hwnd, out cr);\n"
            code += "        minW = cw + (wr.Right-wr.Left) - (cr.Right-cr.Left);\n"
            code += "        minH = ch + (wr.Bottom-wr.Top) - (cr.Bottom-cr.Top);\n"
            code += "        AssignHandle(hwnd);\n"
            code += "    }\n"
            code += "    protected override void WndProc(ref Message m) {\n"
            code += "        base.WndProc(ref m);\n"
            code += "        if (m.Msg == 0x0024) {\n"
            code += "            MINMAXINFO i = (MINMAXINFO)Marshal.PtrToStructure(m.LParam, typeof(MINMAXINFO));\n"
            code += "            i.ptMinTrackSize.X = minW; i.ptMinTrackSize.Y = minH;\n"
            code += "            Marshal.StructureToPtr(i, m.LParam, true);\n"
            code += "        }\n"
            code += "    }\n"
            code += "    public void Cleanup() { ReleaseHandle(); }\n"
            code += "}\n"

            local provider = dotNetObject "Microsoft.CSharp.CSharpCodeProvider"
            local compilerParams = dotNetObject "System.CodeDom.Compiler.CompilerParameters"
            compilerParams.GenerateInMemory = true
            compilerParams.ReferencedAssemblies.Add "System.dll"
            compilerParams.ReferencedAssemblies.Add "System.Windows.Forms.dll"
            local results = provider.CompileAssemblyFromSource compilerParams #(code)
            if results.Errors.Count == 0 then
                DialogMinSizerType = results.CompiledAssembly.GetType "DialogMinSizer"
            else
                for i = 0 to results.Errors.Count - 1 do
                    format "DialogMinSizer compile error: %\n" (results.Errors.Item[i].ErrorText)
        )

        if DialogMinSizerType != undefined do
        (
            DialogMinSizeInstance = (dotNetClass "System.Activator").CreateInstance DialogMinSizerType
            DialogMinSizeInstance.Setup (dotNetObject "System.IntPtr" hwnd) minW minH
        )
    )
    catch (format "initDialogMinSize failed: %\n" (getCurrentException()))
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
    dotNetControl spnStart "System.Windows.Forms.NumericUpDown" pos:[65,25] width:55 height:20
    button btnEnd "End" pos:[130,27] height:17
    dotNetControl spnEnd "System.Windows.Forms.NumericUpDown" pos:[170,25] width:60 height:20
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

        local btnLabelW = 45
        local endLabelW = 40
        local halfGap = 6
        local availW = innerW - innerPad * 2
        local halfW = (availW - halfGap) / 2

        local spnStartW = halfW - btnLabelW
        if spnStartW < 30 do spnStartW = 30
        local spnEndW = halfW - endLabelW
        if spnEndW < 30 do spnEndW = 30

        btnStart.pos = [m + innerPad, 27]
        spnStart.pos = [m + innerPad + btnLabelW, 25]
        spnStart.Width = spnStartW

        local midX = m + innerPad + halfW + halfGap
        btnEnd.pos = [midX, 27]
        spnEnd.pos = [midX + endLabelW, 25]
        spnEnd.Width = spnEndW

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

    fn initNumericUpDown ctrl val =
    (
        local darkBg = (dotNetClass "System.Drawing.Color").FromArgb 68 68 68
        local lightFg = (dotNetClass "System.Drawing.Color").FromArgb 220 220 220
        ctrl.Minimum = -100000
        ctrl.Maximum = 100000
        ctrl.DecimalPlaces = 0
        ctrl.Value = val
        ctrl.BackColor = darkBg
        ctrl.ForeColor = lightFg
        ctrl.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
    )

    on TimeSliderSelectorDialog open do
    (
        lstRanges.IntegralHeight = false
        lstRanges.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 68 68 68
        lstRanges.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 220 220 220
        lstRanges.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle

        initNumericUpDown spnStart (animationRange.start.frame as integer)
        initNumericUpDown spnEnd (animationRange.end.frame as integer)
        loadRangesFromFileProps()
        refreshRangeList lstRanges
        doLayout 250 290
        layoutReady = true
        initDialogMinSize TimeSliderSelectorDialog.hwnd 400 490
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
            spnStart.Value = s
            spnEnd.Value = e
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
		spnStart.Value = (animationRange.start.frame as integer)
    )

	on btnEnd pressed do
    (
		spnEnd.Value = (animationRange.end.frame as integer)
    )
	
    on btnAdd pressed do
    (
        local startVal = spnStart.Value as integer
        local endVal = spnEnd.Value as integer
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
            local startVal = spnStart.Value as integer
            local endVal = spnEnd.Value as integer
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
            spnStart.Value = rangeData.startFrame
            spnEnd.Value = rangeData.endFrame
        )
    )

    on lstRanges MouseDoubleClick sender args do
    (
        local idx = lstRanges.SelectedIndex + 1
        if idx > 0 and idx <= TimeSliderRanges.count then
        (
            local rangeData = TimeSliderRanges[idx]
            spnStart.Value = rangeData.startFrame
            spnEnd.Value = rangeData.endFrame
            animationRange = interval rangeData.startFrame rangeData.endFrame
            sliderTime = rangeData.startFrame
        )
    )

    on TimeSliderSelectorDialog close do
    (
        if DialogMinSizeInstance != undefined do
        (
            try (DialogMinSizeInstance.Cleanup()) catch()
            DialogMinSizeInstance = undefined
        )
    )

    on TimeSliderSelectorDialog resized val do
    (
        if layoutReady do
        (
            local w = if val.x < 250 then 250 else val.x
            local h = if val.y < 290 then 290 else val.y
            doLayout w h
        )
    )
)


callbacks.addScript #filePostOpen "if TimeSliderSelectorDialog != undefined and TimeSliderSelectorDialog.open then (loadRangesFromFileProps(); refreshRangeList TimeSliderSelectorDialog.lstRanges)" id:#TimeSliderSelector
callbacks.addScript #systemPostNew "TimeSliderRanges = #(); if TimeSliderSelectorDialog != undefined and TimeSliderSelectorDialog.open then (refreshRangeList TimeSliderSelectorDialog.lstRanges)" id:#TimeSliderSelector

createDialog TimeSliderSelectorDialog width:250 height:290 style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing)
