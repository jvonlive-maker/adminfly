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
local SPEED_WARP = 1000 
local ACCEL_SPEED = 0.06 

local FOV_NORMAL = 70
local FOV_MAX = 100 
local ROTATION_RESPONSIVENESS = 15 

local BANK_ANGLE = 10 
local BANK_SPEED = 0.1 

-- ASSET IDS
local ANIM_IDLE_ID = "rbxassetid://93326430026112" 
local ANIM_FLY_ID = "rbxassetid://140568359164725"  
local BOOM_SOUND_ID = "rbxassetid://9120769331" 
local WIND_SOUND_ID = "rbxassetid://93035214379043" 

-- KEYS
local TOGGLE_KEY = Enum.KeyCode.H
local BOOST_KEY = Enum.KeyCode.LeftShift
local WARP_KEY = Enum.KeyCode.Space
local FREELOOK_KEY = Enum.KeyCode.RightAlt -- FREE LOOK TOGGLE
local UP_KEY = Enum.KeyCode.E
local DOWN_KEY = Enum.KeyCode.Q
----------------------------------------------------------

local isFlying = false
local isBoosting = false
local isFreeLooking = false
local currentSpeed = 0 
local currentBank = 0 
local boomSound, windSound
local loadedIdleAnim, loadedFlyAnim
local speedGui, speedLabel

local function setupUI()
	local existing = player.PlayerGui:FindFirstChild("FlyStats")
	if existing then existing:Destroy() end
	speedGui = Instance.new("ScreenGui")
	speedGui.Name = "FlyStats"
	speedGui.ResetOnSpawn = false
	speedGui.Enabled = false
	speedLabel = Instance.new("TextLabel")
	speedLabel.Size = UDim2.new(0, 200, 0, 50)
	speedLabel.Position = UDim2.new(0.5, -100, 0.85, 0)
	speedLabel.BackgroundTransparency = 1
	speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedLabel.TextStrokeTransparency = 0
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.TextSize = 24
	speedLabel.Text = "SPEED: 0"
	speedLabel.Parent = speedGui
	speedGui.Parent = player:WaitForChild("PlayerGui")
end

local function setupEffects()
	boomSound = Instance.new("Sound")
	boomSound.SoundId = BOOM_SOUND_ID
	boomSound.Volume = 0.6
	boomSound.Parent = rootPart
	windSound = Instance.new("Sound")
	windSound.SoundId = WIND_SOUND_ID
	windSound.Volume = 0
	windSound.Looped = true
	windSound.Parent = rootPart
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
setupUI()

local function toggleFlight()
	isFlying = not isFlying
	isFreeLooking = false -- Reset free look on exit
	speedGui.Enabled = isFlying
	if isFlying then
		currentSpeed = 0
		currentBank = 0
		windSound:Play()
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
		ao.RigidityEnabled = false 
		ao.MaxTorque = 10^10 
		ao.Responsiveness = ROTATION_RESPONSIVENESS 
		ao.Parent = rootPart
		humanoid.PlatformStand = true
		loadedIdleAnim:Play(0.3)
	else
		windSound:Stop()
		camera.FieldOfView = FOV_NORMAL
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
	if input.KeyCode == FREELOOK_KEY and isFlying then 
		isFreeLooking = not isFreeLooking
		-- Optional: change UI color to show Free Look is on
		speedLabel.TextColor3 = isFreeLooking and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(255, 255, 255)
	end
	if input.KeyCode == BOOST_KEY and isFlying then 
		isBoosting = true 
		boomSound.Pitch = 0.8
		boomSound:Play()
	end
	if input.KeyCode == WARP_KEY and isFlying and isBoosting then
		boomSound.Pitch = 1.4
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
	local targetBank = 0

	-- Movement logic
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += camCFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector -= camCFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then 
		moveVector -= camCFrame.RightVector 
		targetBank += 1 
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then 
		moveVector += camCFrame.RightVector 
		targetBank -= 1 
	end
	if UserInputService:IsKeyDown(UP_KEY) then moveVector += Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(DOWN_KEY) then moveVector -= Vector3.new(0, 1, 0) end

	local isMoving = moveVector.Magnitude > 0
	local targetSpeed = 0

	if isMoving then
		if isBoosting then
			targetSpeed = UserInputService:IsKeyDown(WARP_KEY) and SPEED_WARP or SPEED_BOOST
		else
			targetSpeed = SPEED_BASE
		end
		moveVector = moveVector.Unit
	end

	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * ACCEL_SPEED
	currentBank = currentBank + (targetBank - currentBank) * BANK_SPEED

	-- UI, FOV, Sound
	speedLabel.Text = isFreeLooking and "FREE LOOK: " .. math.floor(currentSpeed) or "SPEED: " .. math.floor(currentSpeed)
	camera.FieldOfView = FOV_NORMAL + ((FOV_MAX - FOV_NORMAL) * (currentSpeed / SPEED_WARP))
	windSound.Volume = (currentSpeed / SPEED_WARP) * 1.5
	windSound.PlaybackSpeed = 0.5 + (currentSpeed / SPEED_WARP) * 1.5

	lv.VectorVelocity = moveVector * currentSpeed

	-- FREE LOOK LOGIC
	-- Only update rotation if Free Look is OFF
	if not isFreeLooking then
		local baseRotation = CFrame.lookAt(rootPart.Position, rootPart.Position + camCFrame.LookVector)
		ao.CFrame = baseRotation * CFrame.Angles(0, 0, math.rad(currentBank * BANK_ANGLE))
	end

	-- Animation Management
	if isMoving and isBoosting then
		if not loadedFlyAnim.IsPlaying then
			loadedIdleAnim:Stop(0.5)
			loadedFlyAnim:Play(0.5)
		end
	else
		if loadedFlyAnim.IsPlaying then
			loadedFlyAnim:Stop(0.5)
			loadedIdleAnim:Play(0.5)
		end
	end

	-- Camera Shake
	if currentSpeed > (SPEED_BASE + 5) then
		local shakeIntensity = 0.05 + (0.4 * (currentSpeed / SPEED_WARP))
		camera.CFrame = camera.CFrame * CFrame.new(math.noise(tick()*35)*shakeIntensity, math.noise(0,tick()*35)*shakeIntensity, 0)
	end
end)
