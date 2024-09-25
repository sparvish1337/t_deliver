RegisterNetEvent('delivery:completeJob')
AddEventHandler('delivery:completeJob', function()
    local src = source
    local amount = 500

    exports.ox_inventory:AddItem(src, 'money', amount)

    TriggerClientEvent('qbx_core:Notify', src, "You've received $" .. amount .. " for completing the deliveries!", "success", 5000)
end)
