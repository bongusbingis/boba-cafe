local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

---> dependencies
local React = require(Packages.React)

---> private
local c = React.createElement

---> public
export type Props = {
	Model: Instance,
	Size: UDim2?,
	LayoutOrder: number?,
	ZIndex: number?,
	ModelRotation: number?,  -- Y-axis rotation of the model in degrees; default 0
	-- optional camera overrides
	ElevationAngle: number?, -- degrees above horizontal; default 30
	FieldOfView: number?,    -- default 45
	Ambient: Color3?,
	LightColor: Color3?,
	LightDirection: Vector3?,
}

--[[
	Renders any PVInstance (Model, MeshPart, Part, etc.) inside a ViewportFrame.
	The camera is automatically positioned in front of the subject and angled
	downward by ElevationAngle degrees, framing the full bounding box.
]]
return function(props: Props)
	local viewportRef = React.useRef(nil)

	React.useEffect(function()
		local viewport: ViewportFrame = viewportRef.current
		if not viewport then
			return
		end

		-- Clone and move pivot to origin for consistent framing, applying Y rotation
		local worldModel = Instance.new("WorldModel")
		local modelClone = props.Model:Clone()
		local rotY = math.rad(props.ModelRotation or 0)
		;(modelClone :: PVInstance):PivotTo(CFrame.Angles(0, rotY, 0))
		modelClone.Parent = worldModel
		worldModel.Parent = viewport

		-- Resolve bounding box: Model has GetBoundingBox(); BaseParts use CFrame/Size directly
		local center: Vector3
		local size: Vector3
		if modelClone:IsA("Model") then
			local cf
			cf, size = (modelClone :: Model):GetBoundingBox()
			center = cf.Position
		else
			local part = modelClone :: BasePart
			center = part.CFrame.Position -- at origin after PivotTo
			size = part.Size
		end

		local maxDim = math.max(size.X, size.Y, size.Z)

		-- Position camera: in front (+Z) and elevated by ElevationAngle
		local elevRad = math.rad(props.ElevationAngle or 30)
		local dist = maxDim * 2.5
		local cameraPos = center + Vector3.new(
			0,
			dist * math.sin(elevRad),
			-dist * math.cos(elevRad)
		)

		local camera = Instance.new("Camera")
		camera.FieldOfView = props.FieldOfView or 45
		camera.CFrame = CFrame.lookAt(cameraPos, center)
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		return function()
			worldModel:Destroy()
			camera:Destroy()
		end
	end, { props.Model, props.ModelRotation })

	return c("ViewportFrame", {
		ref = viewportRef,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Ambient = props.Ambient or Color3.fromRGB(178, 178, 178),
		LightColor = props.LightColor or Color3.fromRGB(255, 255, 255),
		LightDirection = props.LightDirection or Vector3.new(-1, -2, -1),
		Size = props.Size or UDim2.fromScale(1, 1),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
	})
end
