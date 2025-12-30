local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local camera = Workspace.CurrentCamera

-- CONFIGURATION -----------------------------------------
local SPEED_BASE = 25  
local SPEED_BOOST = 100 
local SPEED_WARP = 1000 -- Speed when Shift + Space are held
local LERP_SPEED = 0.08 -- Lowered slightly for a "heavy" acceleration feel

local ANIM_IDLE_ID = "rbxassetid://93326430026112" 
local ANIM_FLY_ID = "rbxassetid://140568359164725"  
local BOOM_SOUND_ID = "rbxassetid://142245274" 

local TOGGLE_KEY = Enum.KeyCode.H
local BOOST_KEY = Enum.KeyCode.LeftShift
local WARP_KEY = Enum.KeyCode.Space
local UP_KEY = Enum.KeyCode.E
local DOWN_KEY = Enum.KeyCode.Q
----------------------------------------------------------

local isFlying = false
local isBoosting = false
local currentSpeed = 0 
local boomSound = nil
local loadedIdleAnim = nil
local loadedFlyAnim = nil

local function setupEffects()
	boomSound = Instance.new("Sound")
	boomSound.SoundId = BOOM_SOUND_ID
	boomSound.Volume = 0.6
	boomSound.Parent = rootPart
end

local function setupAnims()
	local animator = humanoid:FindFirstChild("Animator") or humanoid:WaitForChild("Animator")
	local idleAnimObj = Instance.new("Animation")
	idleAnimObj.AnimationId = ANIM_IDLE_ID
	local flyAnimObj = Instance.new("Animation")
	flyAnimObj.AnimationId = ANIM_FLY_ID

	loadedIdleAnim = animator:LoadAnimation(idleAnimObj)
	loadedFlyAnim = animator:LoadAnimation(flyAnimObj)
	loadedIdleAnim.Priority = Enum.AnimationPriority.Movement
	loadedFlyAnim.Priority = Enum.AnimationPriority.Action
end

setupAnims()
setupEffects()

local function toggleFlight()
	isFlying = not isFlying

	if isFlying then
		currentSpeed = 0
		local attachment = Instance.new("Attachment")
		attachment.Name = "FlyAttachment"
		attachment.Parent = rootPart

		local lv = Instance.new("LinearVelocity")
		lv.Name = "FlyVelocity"
		lv.Attachment0 = attachment
		lv.MaxForce = math.huge
		lv.VectorVelocity = Vector3.zero
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = rootPart

		local ao = Instance.new("AlignOrientation")
		ao.Name = "FlyGyro"
		ao.Attachment0 = attachment
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.RigidityEnabled = true
		ao.Parent = rootPart

		humanoid.PlatformStand = true
		loadedIdleAnim:Play()
	else
		if rootPart:FindFirstChild("FlyVelocity") then rootPart.FlyVelocity:Destroy() end
		if rootPart:FindFirstChild("FlyGyro") then rootPart.FlyGyro:Destroy() end
		if rootPart:FindFirstChild("FlyAttachment") then rootPart.FlyAttachment:Destroy() end
		humanoid.PlatformStand = false
		loadedIdleAnim:Stop()
		loadedFlyAnim:Stop()
	end
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == TOGGLE_KEY then toggleFlight() end
	
	if input.KeyCode == BOOST_KEY and isFlying then 
		isBoosting = true 
		boomSound.Pitch = 0.8 -- Deeper sound for shift
		boomSound:Play()
	end

    -- Play a second, higher pitch boom if they hit Warp
    if input.KeyCode == WARP_KEY and isFlying and isBoosting then
        boomSound.Pitch = 1.5
        boomSound:Play()
    end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == BOOST_KEY then isBoosting = false end
end)

RunService.RenderStepped:Connect(function(dt)
	if not isFlying then return end

	local lv = rootPart:FindFirstChild("FlyVelocity")
	local ao = rootPart:FindFirstChild("FlyGyro")
	if not lv or not ao then return end

	local moveVector = Vector3.zero
	local camCFrame = camera.CFrame

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += camCFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector -= camCFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector -= camCFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += camCFrame.RightVector end
	if UserInputService:IsKeyDown(UP_KEY) then moveVector += Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(DOWN_KEY) then moveVector -= Vector3.new(0, 1, 0) end

	local isMoving = moveVector.Magnitude > 0
	local targetSpeed = 0

	if isMoving then
		-- SPEED LOGIC:
        if isBoosting then
            if UserInputService:IsKeyDown(WARP_KEY) then
                targetSpeed = SPEED_WARP
            else
                targetSpeed = SPEED_BOOST
            end
        else
            targetSpeed = SPEED_BASE
        end
		moveVector = moveVector.Unit
	end

	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * LERP_SPEED
	lv.VectorVelocity = moveVector * currentSpeed
	ao.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + camCFrame.LookVector)

	-- Shake Effect and Animation
	if isBoosting and currentSpeed > (SPEED_BASE + 5) then
        -- Intense shake for Warp Speed
		local shakeMult = (currentSpeed > 500) and 0.5 or 0.1
		local shakeIntensity = shakeMult * (currentSpeed / SPEED_BOOST)
		
		local xShake = math.noise(tick() * 30, 0) * shakeIntensity
		local yShake = math.noise(0, tick() * 30) * shakeIntensity
		camera.CFrame = camera.CFrame * CFrame.new(xShake, yShake, 0)

		if not loadedFlyAnim.IsPlaying then loadedFlyAnim:Play(0.5) end
	else
		if loadedFlyAnim.IsPlaying then loadedFlyAnim:Stop(0.5) end
	end
end)
