try (destroydialog AddCameraKey) catch()

rollout AddCameraKey "Add Camera Key"
(
	button		btn_AddKey		"Add Camera Key"		offset:[0,0]		width:200 height:30	align:#center
	button		btn_DeleteKey	"Delete Camera Key"	offset:[0,0]		width:200 height:30	align:#center
	-- Fuction --------------------------------------------------------------------------------------------------------------------------------------
	
	fn AddCameraKey=
	(
		if classof $ == Freecamera or classof $ == Targetcamera then
		(
			if $.fov.controller == undefined do
			(
				$.fov.controller = bezier_float()
			)
			
			addNewKey $.fov.controller currenttime
		)
		else
		(
			messagebox "You should select camera!"
		)
	)
	
	fn DeleteCameraKey=
	(
		if classof $ == Freecamera or classof $ == Targetcamera then
		(
			if $.fov.controller == undefined do
			(
				$.fov.controller = bezier_float()
			)
			
			deleteKeys $.fov.controller #selection
		)
		else
		(
			messagebox "You should select camera!"
		)
	)

	--Implementation-------------------------------------------------------------------------------------------------------------------------------------------------------
	
	on btn_AddKey pressed do
	(
		AddCameraKey()
	)
	
	on btn_DeleteKey pressed do
	(
		DeleteCameraKey()
	)
)
createdialog AddCameraKey width: 220 height: 75