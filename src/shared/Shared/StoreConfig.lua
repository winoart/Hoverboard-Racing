--!strict
-- StoreConfig.lua
-- Contains the catalog of Hoverboards for the store.

local StoreConfig = {}

export type StoreItem = {
	id: string,
	name: string,
	imageId: string,
	goldPrice: number,
	robuxPrice: number,
}

StoreConfig.Items = {
	{
		id = "DefaultHoverboard",
		name = "Basic Board",
		imageId = "rbxassetid://10078028148", -- Example placeholder
		goldPrice = 0,
		robuxPrice = 0,
	},
	{
		id = "CloudHoverboard",
		name = "Nimbus Cloud",
		imageId = "rbxassetid://10078028148",
		goldPrice = 500,
		robuxPrice = 50,
	},
	{
		id = "MagicBroom",
		name = "Magic Broom",
		imageId = "rbxassetid://10078028148",
		goldPrice = 1200,
		robuxPrice = 120,
	},
}

return StoreConfig
