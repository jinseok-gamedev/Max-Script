try (destroydialog AddCameraKey) catch()

rollout AddCameraKey "Add Camera Key"
(
	local copiedFov = undefined
	
	button		btn_AddKey		"Add Camera Key"		offset:[0,0]		width:200 height:30	align:#center
	button		btn_DeleteKey	"Delete Camera Key"	offset:[0,0]		width:200 height:30	align:#center
	button		btn_CopyFov		"Copy FOV"				width:97 height:30	across:2
	button		btn_PasteFov	"Paste FOV"				width:97 height:30
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
	
	fn CopyFov=
	(
		if classof $ == Freecamera or classof $ == Targetcamera then
		(
			copiedFov = $.fov
		)
		else
		(
			messagebox "You should select camera!"
		)
	)
	
	fn PasteFov=
	(
		if copiedFov == undefined then
		(
			messagebox "Copy FOV first!"
		)
		else
		(
			if classof $ == Freecamera or classof $ == Targetcamera then
			(
				$.fov = copiedFov
			)
			else
			(
				messagebox "You should select camera!"
			)
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
	
	on btn_CopyFov pressed do
	(
		CopyFov()
	)
	
	on btn_PasteFov pressed do
	(
		PasteFov()
	)
)
createdialog AddCameraKey width: 220 height: 110