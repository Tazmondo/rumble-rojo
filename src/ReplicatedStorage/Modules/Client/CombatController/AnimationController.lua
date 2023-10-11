local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Future = require(ReplicatedStorage.Packages.Future)
local AnimationController = {}

local animationFolder = ReplicatedStorage.Assets.Animations

local attackAnim = animationFolder.Attack

function LoadAnimation(animator: Animator, animation: Animation)
	return Future.new(function()
		local track = animator:LoadAnimation(animation)
		local start = os.clock()
		while track.Length == 0 do
			if os.clock() - start > 10 then
				warn("Failed to load animation after 10 seconds: ", animation.Name)
				return nil :: AnimationTrack?
			end
			task.wait()
		end
		return track :: AnimationTrack?
	end)
end

function AnimationController.new(character: Model)
	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChild("Animator") :: Animator

	local loadedAnimations = {}

	loadedAnimations["Attack"] = LoadAnimation(animator, attackAnim)

	return loadedAnimations
end

function AnimationController.AttemptPlay(
	animations: LoadedAnimations,
	animationName: string,
	fadeTime: number?,
	weight: number?,
	speed: number?
)
	local animFuture = animations[animationName]
	if animFuture:IsComplete() then
		local track = animFuture:Unwrap()
		if track then
			track:Play(fadeTime, weight, speed)
		end
	end
end

type LoadedAnimations = { [string]: typeof(LoadAnimation(...)) }

return AnimationController
