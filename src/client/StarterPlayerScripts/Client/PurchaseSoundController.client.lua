--!strict
-- PurchaseSoundController.client.lua
-- 로복스(GamePass & DeveloperProduct) 결제 성공 및 실패 사운드 제어기

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer

local SUCCESS_SOUND_ID = "rbxassetid://94970683619502"
local FAIL_SOUND_ID = "rbxassetid://139351338224439"

local successSound = Instance.new("Sound")
successSound.Name = "RobuxPurchaseSuccessSound"
successSound.SoundId = SUCCESS_SOUND_ID
successSound.Volume = 1.0
successSound.Parent = SoundService

local failSound = Instance.new("Sound")
failSound.Name = "RobuxPurchaseFailSound"
failSound.SoundId = FAIL_SOUND_ID
failSound.Volume = 1.0
failSound.Parent = SoundService

ContentProvider:PreloadAsync({ successSound, failSound })

local function playSuccessSound()
	successSound.TimePosition = 0
	successSound:Play()
end

local function playFailSound()
	failSound.TimePosition = 0
	failSound:Play()
end

-- 1. 게임패스 구매 결과 리스너
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
	if player == LocalPlayer then
		if wasPurchased then
			playSuccessSound()
		else
			playFailSound()
		end
	end
end)

-- 2. 개발자 상품(Developer Product) 구매 결과 리스너
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, isPurchased: boolean)
	if userId == LocalPlayer.UserId then
		if isPurchased then
			playSuccessSound()
		else
			playFailSound()
		end
	end
end)

-- 3. 일반 에셋(Asset) 구매 결과 리스너
MarketplaceService.PromptPurchaseFinished:Connect(function(player: Player, assetId: number, isPurchased: boolean)
	if player == LocalPlayer then
		if isPurchased then
			playSuccessSound()
		else
			playFailSound()
		end
	end
end)

-- 외부(테스트/시뮬레이션 등)에서 직접 호출할 수 있도록 글로벌 및 바인드 노출
_G.PlayPurchaseSuccessSound = playSuccessSound
_G.PlayPurchaseFailSound = playFailSound

