/*
	Create Reference Bone Script
	- Creates reference bones for selected objects using Link Constraint
	- Based on LDI_Tool Create Ref Bone functionality
	- Modified to use Link Constraint instead of Position/Orientation/Scale constraints
*/

try (destroyDialog CreateRefBoneRollout) catch()

rollout CreateRefBoneRollout "Create Ref Bone"
(
	-- Local Variables
	Local NAMEPREFIX = "Ref_"
	Local uiColorWireColor = yellow
	Local uiSpnBoneWidth = 100
	Local IDKEYWORD = "RefBone"
	Local IDKEYWORDHANDLE = "RefBoneHandle"
	
	-- UI Declaration
	group "Options"
	(
		colorpicker cp_WireColor "Bone Color:" color:yellow align:#left across:2
		spinner spn_BoneWidth "Bone Width %:" range:[10, 300, 100] type:#integer fieldwidth:40 align:#right
	)
	
	button btn_CreateRefBone "Create Ref Bone" width:240 height:30 align:#center
	button btn_DeleteRefBone "Delete Selected Ref Bones" width:240 height:30 align:#center
	
	-- Functions
	
	-- Get aligned bounding box for calculating bone dimensions
	fn fnGetAlignBB obj =
	(
		tMatrix = obj.transform
		tMatrix.scale = [1, 1, 1]
		tMatrix.rotation = obj.transform.rotation
		tMatrix.position = obj.transform.position
		
		bb = nodeLocalBoundingBox obj
		
		bb[1] = ((transMatrix bb[1]) * (inverse tMatrix)).pos
		bb[2] = ((transMatrix bb[2]) * (inverse tMatrix)).pos
		
		if ((classof obj.baseobject) == Point) do
		(
			bb[1].x -= obj.baseobject.size * 0.5
			bb[1].y -= obj.baseobject.size * 0.5
			bb[2].x += obj.baseobject.size * 0.5
			bb[2].y += obj.baseobject.size * 0.5
		)
		return bb
	)
	
	-- Get width of object for bone size calculation
	fn fnGetWidthX obj =
	(
		bb = fnGetAlignBB obj
		return (((abs (bb[2].y - bb[1].y)) + (abs (bb[2].z - bb[1].z))) / 2.0)
	)
	
	-- Check if object is a valid working bone
	fn fnCheckWorkingBone obj =
	(
		tFlag = false
		
		if ((obj.BoneEnable == true) or (classof obj.baseobject == Biped_Object) or (classof obj.baseobject == Point) or (classof obj.baseobject == Dummy)) do
		(
			tFlag = true
		)
		
		local propVal = getUserProp obj IDKEYWORD
		if (propVal == "true" or propVal == true) do
		(
			tFlag = false
		)
		
		return tFlag
	)
	
	-- Find the look-at position for bone orientation
	fn fnFindLookAtPos obj =
	(
		tMatrix = obj.transform
		tMatrix.scale = [1, 1, 1]
		tMatrix.rotation = obj.transform.rotation
		tMatrix.position = obj.transform.position
		
		tLength = 1.0
		
		if obj.children.count == 0 then
		(
			tLength = case (classof obj.baseobject) of
			(
				BoneGeometry: obj.baseobject.length * obj.transform.scale.x
				Biped_Object: (biped.getTransform obj #scale).x
				default: (fnGetAlignBB obj)[2].x
			)
		)
		else
		(
			local targetNode
			local beforeDist = -1.0

			for o in obj.children do
			(
				vDist = distance obj.transform.pos o.transform.pos
				if vDist > 0.00001 do
				(
					xPos = ((transMatrix [vDist, 0, 0]) * tMatrix).pos
					endDist = distance xPos o.transform.pos
					
					if beforeDist == -1.0 OR endDist <= beforeDist do
					(
						targetNode = o
						beforeDist = endDist
						tLength = (cos ((90 - acos ((endDist * 0.5) / vDist)) * 2)) * vDist
					)
				)
			)
		)
		
		return ((transMatrix [tLength, 0, 0]) * tMatrix).pos
	)
	
	-- Create bone geometry
	fn fnCreateBone pStart pEnd vUp vSize =
	(
		tBone = BoneSys.createBone pStart pEnd vUp
		tBone.width = vSize
		tBone.height = vSize
		tBone.taper = 90.0

		tBone.sidefins = false
		tBone.sidefinssize = vSize * 0.5
		tBone.frontfin = false
		tBone.frontfinsize = vSize * 0.5
		tBone.backfin = false
		tBone.backfinsize = vSize * 0.5
		tBone.backfinstarttaper = 10.0
		tBone.backfinendtaper = 10.0
		tBone.genmap = false
		tBone.boneAutoAlign = false
		tBone.boneScaleType = #none
		
		return tBone
	)
	
	-- Set reference bone attributes (name, color, user properties)
	fn fnSetRefBoneAttr targetObj newObj wireColor =
	(
		newObj.WireColor = wireColor
		setUserProp newObj IDKEYWORD "true"
		setUserProp newObj IDKEYWORDHANDLE targetObj.inode.handle
		newObj.name = NAMEPREFIX + targetObj.name
	)
	
	-- Set Link Constraint controller (replaces Position/Orientation/Scale constraints)
	fn fnSetLinkConstraint targetObj newObj =
	(
		-- Use Link Constraint for transform
		newObj.transform.controller = Link_Constraint ()
		newObj.transform.controller.addTarget targetObj 0
	)
	
	-- Check if RefBone already exists for the object
	fn fnCheckIfExist obj =
	(
		if obj == undefined do 
		(
			return undefined
		)
		
		rNode = undefined
		
		for o in objects do 
		(
			if (obj.inode.handle == getUserProp o IDKEYWORDHANDLE) do 
			(
				rNode = o
			)
		)
		
		return rNode
	)
	
	-- Auto-parent the new RefBone to parent's RefBone
	fn fnAutoParent targetObj newObj =
	(
		if targetObj.parent == undefined do 
		(
			return ()
		)
		
		tObj = fnCheckIfExist targetObj.parent
		
		if tObj != undefined do
		(
			newObj.parent = tObj
		)
	)
	
	-- Event Handlers
	
	on cp_WireColor changed val do
	(
		uiColorWireColor = val
	)
	
	on spn_BoneWidth changed val do
	(
		uiSpnBoneWidth = val
	)
	
	on btn_CreateRefBone pressed do
	(
		Local tTarget = #()
		Local tNew = #()
		Local targetBipedScale
		Local bipedFigureModeFlag = false
		Local YESNOCANCELSTRING = "This object already has a Ref Bone.\nDo you want to recreate it?\n\nYes: Delete existing and create new\nCancel: Stop all operations"
		
		if (selection as array).count == 0 do
		(
			messagebox "Please select objects"
			return ()
		)
		
		-- Check for Biped objects and handle figure mode
		for Obj in selection do
		(
			if classof Obj == Biped_Object do
			(
				max motion mode
				
				selectedObject = biped.getNode Obj 13 link:1
				BipCtrl = selectedObject.controller
				
				if (BipCtrl.figuremode == false) do
				(
					BipCtrl.figuremode = true
					bipedFigureModeFlag = false
				)
				
				BipCtrl.trianglePelvis = off
				BipCtrl.triangleNeck = on
				
				if (bipedFigureModeFlag == false) do
				(
					BipCtrl.figuremode = false
				)
				
				deselect selectedObject
				exit
			)
		)
		
		-- Process each selected object
		for Obj in selection as array do
		(
			if (fnCheckWorkingBone Obj) == true do
			(
				local tReply = #yes
				local foundRefBone = fnCheckIfExist Obj
				
				if foundRefBone != undefined do
				(
					tReply = (yesNoCancelBox ("Current Object = " + Obj.name + "\n\n" + YESNOCANCELSTRING) title:"Warning" beep:false)
				)
				
				if tReply == #cancel do
				(
					exit
				)
				
				if tReply == #yes do
				(
					if foundRefBone != undefined do
					(
						delete foundRefBone
					)
					
					-- Get scale based on object type
					if ((classof Obj.baseobject) == Biped_Object) then
					(
						targetBipedScale = biped.getTransform Obj #scale
					)
					else
					(
						targetBipedScale = Obj.transform.scale
					)
					
					-- Create the reference bone
					tBone = fnCreateBone Obj.transform.pos (fnFindLookAtPos Obj) Obj.dir ((fnGetWidthX Obj) * (uiSpnBoneWidth * 0.01))
					
					-- Set bone attributes
					fnSetRefBoneAttr Obj tBone uiColorWireColor
					
					-- Set Link Constraint (instead of Position/Orientation/Scale constraints)
					fnSetLinkConstraint Obj tBone
					
					-- Set source object to box mode for visibility
					if ((classof Obj.baseobject) != Point AND (classof Obj.baseobject) != Dummy) do
					(
						Obj.boxMode = on
					)
					
					append tTarget Obj
					append tNew tBone
				)
			)
		)
		
		-- Auto-parent reference bones
		if tTarget.count != 0 do
		(
			for i = 1 to tTarget.count do
			(
				fnAutoParent tTarget[i] tNew[i]
			)
		)
		
		clearSelection()
		
		if tNew.count > 0 do
		(
			select tNew
			messagebox ("Created " + (tNew.count as string) + " Ref Bone(s)")
		)
	)
	
	on btn_DeleteRefBone pressed do
	(
		local deleteCount = 0
		local toDelete = #()
		
		for obj in selection do
		(
			local propVal = getUserProp obj IDKEYWORD
			if (propVal == "true" or propVal == true) do
			(
				append toDelete obj
			)
		)
		
		if toDelete.count > 0 then
		(
			local confirm = queryBox ("Delete " + (toDelete.count as string) + " Ref Bone(s)?") title:"Confirm Delete"
			if confirm do
			(
				delete toDelete
				messagebox ("Deleted " + (toDelete.count as string) + " Ref Bone(s)")
			)
		)
		else
		(
			messagebox "No Ref Bones selected"
		)
	)
)

-- Create dialog window (no rollout folding)
createDialog CreateRefBoneRollout 250 130
