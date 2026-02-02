/*
 * Skin Envelope Mirror Tool
 * 
 * Description: Mirror skin envelope data from source bone to target bone
 *              within the same Skin modifier.
 * 
 * Usage: Select a mesh with Skin modifier, activate the Skin modifier,
 *        select a source bone, then run this script.
 */

-- Clean up existing dialog
try (destroyDialog SkinEnvelopMirrorDialog) catch()

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

/*
 * Mirror a Point3 value along the specified axis
 * @param pt - Point3 to mirror
 * @param axis - 1:X, 2:Y, 3:Z
 * @return Mirrored Point3
 */
fn mirrorPoint3 pt axis = (
    case axis of (
        1: point3 pt.x pt.y (-pt.z)    -- YZ plane (Left/Right) - flip Z
        2: point3 pt.x (-pt.y) pt.z    -- XZ plane (Front/Back) - flip Y
        3: point3 (-pt.x) pt.y pt.z    -- XY plane (Up/Down) - flip X
        default: pt
    )
)

/*
 * Replace left/right token in bone name (Name-based matching)
 * @param boneName - Original bone name
 * @param leftToken - Left side token (e.g., "_L")
 * @param rightToken - Right side token (e.g., "_R")
 * @param caseSensitive - Whether to match case
 * @return Mirrored bone name
 */
fn mirrorBoneName boneName leftToken rightToken caseSensitive:true = (
    local srcName = if caseSensitive then boneName else (toLower boneName)
    local srcLeft = if caseSensitive then leftToken else (toLower leftToken)
    local srcRight = if caseSensitive then rightToken else (toLower rightToken)
    
    local leftPos = findString srcName srcLeft
    local rightPos = findString srcName srcRight
    
    if leftPos != undefined then (
        -- Replace left token with right token
        local result = copy boneName
        result = replace result leftPos leftToken.count rightToken
        result
    )
    else if rightPos != undefined then (
        -- Replace right token with left token
        local result = copy boneName
        result = replace result rightPos rightToken.count leftToken
        result
    )
    else (
        -- No token found, return original (center bone)
        boneName
    )
)

/*
 * Find bone index by name in Skin modifier (Name-based matching)
 * @param skinMod - Skin modifier
 * @param boneName - Bone name to find
 * @param caseSensitive - Whether to match case
 * @return Bone index (1-based) or 0 if not found
 */
fn findBoneIndexByName skinMod boneName caseSensitive:true = (
    local numBones = skinOps.GetNumberBones skinMod
    for i = 1 to numBones do (
        local bName = skinOps.GetBoneName skinMod i 0
        local match = if caseSensitive then (bName == boneName) else (stricmp bName boneName == 0)
        if match do return i
    )
    0  -- Not found
)

/*
 * Get bone node's world position (Position-based matching)
 * Works with regular nodes and Biped objects
 * @param skinMod - Skin modifier
 * @param boneIndex - Bone index (1-based)
 * @return Point3 position or [0,0,0] if not found
 */
fn getBonePosition skinMod boneIndex = (
    local boneName = skinOps.GetBoneName skinMod boneIndex 0
    local boneNode = getNodeByName boneName
    if boneNode != undefined then (
        -- Use transform to support both regular nodes and Biped objects
        boneNode.transform.translationpart
    ) else [0,0,0]
)

/*
 * Find target bone by mirrored position (Position-based matching)
 * @param skinMod - Skin modifier
 * @param sourceIndex - Source bone index
 * @param axis - Mirror axis (1:X, 2:Y, 3:Z)
 * @param tolerance - Position tolerance
 * @return #(targetBoneIndex, closestDistance, sourcePos, mirroredPos) or #(0, 0, [0,0,0], [0,0,0]) if not found
 */
fn findBoneByPosition skinMod sourceIndex axis tolerance = (
    local sourcePos = getBonePosition skinMod sourceIndex
    local mirroredPos = mirrorPoint3 sourcePos axis
    
    local closestIndex = 0
    local closestDist = 1e9  -- Start with very large value to find the closest bone first
    local numBones = skinOps.GetNumberBones skinMod
    
    for i = 1 to numBones where i != sourceIndex do (
        local bonePos = getBonePosition skinMod i
        local dist = distance bonePos mirroredPos
        if dist < closestDist do (
            closestDist = dist
            closestIndex = i
        )
    )
    
    -- Return array with debug info: #(index, distance, sourcePos, mirroredPos)
    -- Only accept if within tolerance
    if closestDist <= tolerance then
        #(closestIndex, closestDist, sourcePos, mirroredPos)
    else
        #(0, closestDist, sourcePos, mirroredPos)  -- Return 0 but include debug info
)

-- ============================================================================
-- SKIN ENVELOPE FUNCTIONS
-- ============================================================================

/*
 * Get currently active Skin modifier from selection
 * @return Skin modifier or undefined
 */
fn getActiveSkinModifier = (
    if selection.count != 1 then return undefined
    
    local obj = selection[1]
    local currentMod = modPanel.getCurrentObject()
    
    if classof currentMod == Skin then (
        currentMod
    ) else (
        -- Try to find Skin modifier in stack
        for m in obj.modifiers where classof m == Skin do return m
        undefined
    )
)

/*
 * Structure to hold envelope data for a bone
 */
struct EnvelopeData (
    startPoint,     -- Point3
    endPoint,       -- Point3
    crossSections   -- Array of #(innerRadius, outerRadius, uPosition)
)

/*
 * Extract envelope data from a bone
 * @param skinMod - Skin modifier
 * @param boneIndex - Bone index (1-based)
 * @return EnvelopeData struct
 */
fn getEnvelopeData skinMod boneIndex = (
    -- Select the bone to access envelope data
    skinOps.SelectBone skinMod boneIndex
    
    local startPt = skinOps.GetStartPoint skinMod boneIndex
    local endPt = skinOps.GetEndPoint skinMod boneIndex
    
    local numCS = skinOps.GetNumberCrossSections skinMod boneIndex
    local csData = #()
    
    for cs = 1 to numCS do (
        local innerR = skinOps.GetInnerRadius skinMod boneIndex cs
        local outerR = skinOps.GetOuterRadius skinMod boneIndex cs
        local uPos = skinOps.GetCrossSectionU skinMod boneIndex cs
        append csData #(innerR, outerR, uPos)
    )
    
    EnvelopeData startPoint:startPt endPoint:endPt crossSections:csData
)

/*
 * Apply envelope data to a bone with mirror transformation
 * @param skinMod - Skin modifier
 * @param boneIndex - Target bone index
 * @param envData - EnvelopeData struct
 * @param axis - Mirror axis (1:X, 2:Y, 3:Z)
 */
fn applyEnvelopeData skinMod boneIndex envData axis = (
    -- Select the target bone
    skinOps.SelectBone skinMod boneIndex
    
    -- Apply mirrored start/end points
    local mirroredStart = mirrorPoint3 envData.startPoint axis
    local mirroredEnd = mirrorPoint3 envData.endPoint axis
    
    skinOps.SetStartPoint skinMod boneIndex mirroredStart
    skinOps.SetEndPoint skinMod boneIndex mirroredEnd
    
    -- Get target bone's cross section count
    local targetNumCS = skinOps.GetNumberCrossSections skinMod boneIndex
    local sourceNumCS = envData.crossSections.count
    
    -- Apply cross section data (match as many as possible)
    local numToApply = amin targetNumCS sourceNumCS
    
    for cs = 1 to numToApply do (
        local csData = envData.crossSections[cs]
        skinOps.SetInnerRadius skinMod boneIndex cs csData[1]
        skinOps.SetOuterRadius skinMod boneIndex cs csData[2]
        skinOps.SetCrossSectionU skinMod boneIndex cs csData[3]
    )
)

-- ============================================================================
-- MAIN EXECUTION FUNCTION
-- ============================================================================

/*
 * Execute the envelope mirror operation
 * @param isNameBased - true for Name-based, false for Position-based
 * @param leftToken - Left side token (Name-based)
 * @param rightToken - Right side token (Name-based)
 * @param caseSensitive - Case sensitive matching (Name-based)
 * @param axis - Mirror axis (1:X, 2:Y, 3:Z)
 * @param tolerance - Position tolerance (Position-based)
 * @return Result message string
 */
fn executeSkinEnvelopeMirror isNameBased leftToken rightToken caseSensitive axis tolerance = (
    local result = ""
    
    -- Validate Skin modifier
    local skinMod = getActiveSkinModifier()
    if skinMod == undefined do (
        return "Error: No active Skin modifier found.\nPlease select a mesh and activate its Skin modifier."
    )
    
    -- Switch to modify mode
    max modify mode
    
    -- Get selected bone
    local sourceBoneIndex = skinOps.GetSelectedBone skinMod
    if sourceBoneIndex == 0 do (
        return "Error: No bone selected.\nPlease select a bone in the Skin modifier."
    )
    
    local sourceBoneName = skinOps.GetBoneName skinMod sourceBoneIndex 0
    result += "Source bone: " + sourceBoneName + " (index: " + (sourceBoneIndex as string) + ")\n"
    
    -- Find target bone based on mode
    local targetBoneIndex = 0
    local targetBoneName = ""
    
    if isNameBased then (
        targetBoneName = mirrorBoneName sourceBoneName leftToken rightToken caseSensitive:caseSensitive
        targetBoneIndex = findBoneIndexByName skinMod targetBoneName caseSensitive:caseSensitive
        result += "Target bone (Name-based): " + targetBoneName + "\n"
    ) else (
        -- Position-based returns: #(index, distance, sourcePos, mirroredPos)
        local posResult = findBoneByPosition skinMod sourceBoneIndex axis tolerance
        targetBoneIndex = posResult[1]
        local closestDist = posResult[2]
        local sourcePos = posResult[3]
        local mirroredPos = posResult[4]
        
        -- Show debug info
        local planeNames = #("YZ (Left/Right)", "XZ (Front/Back)", "XY (Up/Down)")
        result += "Source position: " + (sourcePos as string) + "\n"
        result += "Mirrored position (" + planeNames[axis] + " plane): " + (mirroredPos as string) + "\n"
        result += "Closest bone distance: " + (closestDist as string) + "\n"
        
        if targetBoneIndex > 0 do (
            targetBoneName = skinOps.GetBoneName skinMod targetBoneIndex 0
        )
        result += "Target bone (Position-based): "
        result += if targetBoneIndex > 0 then (targetBoneName + "\n") else "Not found (distance > tolerance)\n"
    )
    
    -- Validate target bone
    if targetBoneIndex == 0 do (
        result += "\nError: Target bone not found."
        if isNameBased then (
            result += "\nCheck if bone '" + targetBoneName + "' exists in the Skin modifier."
        ) else (
            result += "\nTry: 1) Increase tolerance value, or 2) Change mirror axis (usually X for left/right symmetry)."
        )
        return result
    )
    
    if targetBoneIndex == sourceBoneIndex do (
        result += "\nSkipped: Source and target are the same bone (center bone)."
        return result
    )
    
    result += "Target bone index: " + (targetBoneIndex as string) + "\n"
    
    -- Get envelope data from source
    local envData = getEnvelopeData skinMod sourceBoneIndex
    
    result += "\nEnvelope data:\n"
    result += "  Start point: " + (envData.startPoint as string) + "\n"
    result += "  End point: " + (envData.endPoint as string) + "\n"
    result += "  Cross sections: " + (envData.crossSections.count as string) + "\n"
    
    -- Apply envelope data with undo support
    undo "Mirror Skin Envelope" on (
        applyEnvelopeData skinMod targetBoneIndex envData axis
    )
    result += "\nEnvelope data successfully mirrored to '" + targetBoneName + "'."
    
    result
)

-- ============================================================================
-- ROLLOUT UI
-- ============================================================================

rollout SkinEnvelopMirrorDialog "Skin Envelope Mirror" width:300 (
    -- Mode selection
    groupBox grpMode "Target Bone Detection" pos:[10,10] width:280 height:50
    radioButtons rdoMode "" pos:[20,33] labels:#("Name-based", "Position-based") default:1 columns:2
    
    -- Name-based options
    groupBox grpNameBased "Name-based Options" pos:[10,65] width:280 height:90
    label lblLeft "Source Token:" pos:[20,85] 
    editText edtLeftToken "" pos:[90,83] width:80 text:"_L"
    label lblRight "Target Token:" pos:[20,110]
    editText edtRightToken "" pos:[90,108] width:80 text:"_R"
    checkBox chkCaseSensitive "Case Sensitive" pos:[20,135] checked:true
    
    -- Position-based options
    groupBox grpPositionBased "Position-based Options" pos:[10,65] width:280 height:50 visible:false
    label lblTolerance "Tolerance:" pos:[20,85] visible:false
    spinner spnTolerance "" pos:[90,85] width:80 range:[0.001, 10000, 1.0] type:#float visible:false
    
    -- Mirror plane (common)
    groupBox grpAxis "Mirror Plane" pos:[10,120] width:280 height:70
    radioButtons rdoAxis "" pos:[20,137] labels:#("YZ (Left/Right)", "XZ (Front/Back)", "XY (Up/Down)") default:2 columns:1
    
    -- Execute button
    button btnExecute "Mirror Envelope" pos:[10,195] width:280 height:35
    
    -- Result output
    groupBox grpResult "Result" pos:[10,235] width:280 height:140
    editText edtResult "" pos:[15,251] width:268 height:115 readOnly:true
    
    -- Update UI visibility based on mode
    fn updateModeUI = (
        local isNameBased = (rdoMode.state == 1)
        
        -- Name-based group
        grpNameBased.visible = isNameBased
        lblLeft.visible = isNameBased
        edtLeftToken.visible = isNameBased
        lblRight.visible = isNameBased
        edtRightToken.visible = isNameBased
        chkCaseSensitive.visible = isNameBased
        
        -- Position-based group
        grpPositionBased.visible = not isNameBased
        lblTolerance.visible = not isNameBased
        spnTolerance.visible = not isNameBased
        
        -- Mirror plane (only for Position-based)
        grpAxis.visible = not isNameBased
        rdoAxis.visible = not isNameBased
    )
    
    -- Event handlers
    on SkinEnvelopMirrorDialog open do (
        updateModeUI()
    )
    
    on rdoMode changed state do (
        updateModeUI()
    )
    
    on btnExecute pressed do (
        local isNameBased = (rdoMode.state == 1)
        local leftToken = edtLeftToken.text
        local rightToken = edtRightToken.text
        local caseSensitive = chkCaseSensitive.checked
        -- Name-based always uses XZ plane (axis 2), Position-based uses selected plane
        local axis = if isNameBased then 2 else rdoAxis.state
        local tolerance = spnTolerance.value
        
        local result = executeSkinEnvelopeMirror isNameBased leftToken rightToken caseSensitive axis tolerance
        edtResult.text = result
    )
)

-- Create dialog
createDialog SkinEnvelopMirrorDialog height:385
