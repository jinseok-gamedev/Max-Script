try (destroyDialog TimeSliderSelectorDialog) catch()

global TimeSliderSelectorDialog

struct TimeRangeData (
    startFrame,
    endFrame
)

global TimeSliderRanges = #()

fn formatRangeLabel rangeData =
(
    (rangeData.startFrame as string) + " - " + (rangeData.endFrame as string)
)

fn refreshRangeList listBox =
(
    listBox.items = for r in TimeSliderRanges collect (formatRangeLabel r)
)

rollout TimeSliderSelectorDialog "Time Slider Selector" width:250
(
    groupBox grpInput "Range Input" pos:[10,10] width:230 height:40
    spinner spnStart "Start " pos:[35,27] width:80 height:15 type:#integer range:[-100000,100000,0] scale:1
    spinner spnEnd "End " pos:[150,27] width:80 height:15 type:#integer range:[-100000,100000,100] scale:1

    listBox lstRanges "" pos:[10,55] width:230 height:10

    button btnAdd "Add" pos:[10,195] width:110 height:28
    button btnDelete "Delete" pos:[130,195] width:110 height:28

    on TimeSliderSelectorDialog open do
    (
        spnStart.value = animationRange.start
        spnEnd.value = animationRange.end
        refreshRangeList lstRanges
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
    )

    on btnDelete pressed do
    (
        local idx = lstRanges.selection
        if idx != undefined and idx > 0 and idx <= TimeSliderRanges.count then
        (
            deleteItem TimeSliderRanges idx
            refreshRangeList lstRanges
        )
    )

    on lstRanges selected idx do
    (
        if idx != undefined and idx > 0 and idx <= TimeSliderRanges.count then
        (
            local rangeData = TimeSliderRanges[idx]
            animationRange = interval rangeData.startFrame rangeData.endFrame
            sliderTime = rangeData.startFrame
        )
    )
)


createDialog TimeSliderSelectorDialog
