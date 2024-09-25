local ped -- NPC ped entity.
local jobVehicle
local isJobActive = false
local isPaymentCollected = false -- Flag to track if payment has been collected
local deliveryPoints = {
    {x = 714.2079, y = -1321.4843, z = 25.9835, delivered = false, blip = nil},
    {x = 706.4297, y = -1302.4673, z = 25.8249, delivered = false, blip = nil},
    {x = 714.0267, y = -1282.6217, z = 26.0420, delivered = false, blip = nil}
}

local deliveriesCompleted = 0
local totalDeliveries = #deliveryPoints

-- NPC setup and job dialog
Citizen.CreateThread(function()
    local npcModel = GetHashKey("a_f_y_business_02")
    RequestModel(npcModel)
    while not HasModelLoaded(npcModel) do
        Wait(100)
    end

    local npcCoords = vector3(758.6345, -1291.2979, 25.3007)
    ped = CreatePed(4, npcModel, npcCoords.x, npcCoords.y, npcCoords.z, 87.0, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)

    local decorationVehicleModel = GetHashKey("nspeedo")
    RequestModel(decorationVehicleModel)
    while not HasModelLoaded(decorationVehicleModel) do
        Wait(100)
    end

    local decorationVehicle = CreateVehicle(decorationVehicleModel, 750.7502, -1285.2753, 25.3007, -90.1, false, false)
    SetVehicleLivery(decorationVehicle, 3)
    SetVehicleDoorsLocked(decorationVehicle, 2)
    SetVehicleDoorOpen(decorationVehicle, 5, false, false)
    FreezeEntityPosition(decorationVehicle, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            label = "Talk to NPC",
            icon = "fas fa-truck",
            canInteract = function()
                return not isJobActive
            end,
            onSelect = function()
                exports.mt_lib:showDialogue({
                    ped = ped,
                    label = 'Job NPC',
                    speech = 'Do you want to start a delivery job?',
                    options = {
                        {
                            id = 'accept_job',
                            label = 'Yes, I\'m ready!',
                            icon = 'fa-check',
                            close = true,
                            action = function()
                                startJob()
                            end
                        },
                        {
                            id = 'decline_job',
                            label = 'No, maybe later.',
                            icon = 'fa-times',
                            close = true
                        }
                    }
                })
            end
        }
    })
end)

-- Start the job
function startJob()
    isJobActive = true
    isPaymentCollected = false

    local vehicleModel = GetHashKey("nspeedo")
    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Wait(100)
    end

    local vehicleCoords = vector3(750.8725, -1294.7476, 25.3007)
    jobVehicle = CreateVehicle(vehicleModel, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, 87.0, true, false)
    SetPedIntoVehicle(PlayerPedId(), jobVehicle, -1)

    SetVehicleLivery(jobVehicle, 3)

    SetVehicleDoorsLockedForAllPlayers(jobVehicle, false)
    SetVehicleEngineOn(jobVehicle, true, true, false)

    for i, point in ipairs(deliveryPoints) do
        point.blip = AddBlipForCoord(point.x, point.y, point.z)
        SetBlipSprite(point.blip, 1)
        SetBlipColour(point.blip, 2)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Delivery Point")
        EndTextCommandSetBlipName(point.blip)
    end

    updateMissionStatus()

    CreateThread(function()
        while deliveriesCompleted < totalDeliveries do
            for i, point in ipairs(deliveryPoints) do
                if not point.delivered then
                    local playerCoords = GetEntityCoords(PlayerPedId())
                    if #(playerCoords - vector3(point.x, point.y, point.z)) < 10.0 then
                        DrawMarker(1, point.x, point.y, point.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                        if #(playerCoords - vector3(point.x, point.y, point.z)) < 2.0 then
                            DrawText3D(point.x, point.y, point.z, "[E] Deliver")
                            if IsControlJustReleased(0, 38) then
                                if exports.ox_lib:progressCircle({
                                    duration = 5000,
                                    label = 'Delivering...',
                                    position = 'bottom',
                                    useWhileDead = false,
                                    canCancel = false,
                                    canMove = false,
                                    disable = { move = true, combat = true }
                                }) then
                                    point.delivered = true
                                    deliveriesCompleted = deliveriesCompleted + 1
                                    RemoveBlip(point.blip)
                                    exports.qbx_core:Notify("Delivery completed!", "success", 3000)
                                    updateMissionStatus()

                                    if deliveriesCompleted == totalDeliveries then
                                        endJob()
                                    end
                                else
                                    exports.qbx_core:Notify("Delivery cancelled!", "error", 3000)
                                end
                            end
                        end
                    end
                end
            end
            Wait(0)
        end
    end)
end

function updateMissionStatus()
    exports.mt_lib:showMissionStatus("Delivery Job", "Deliveries completed: " .. deliveriesCompleted .. "/" .. totalDeliveries)
end

function endJob()
    exports.qbx_core:Notify("All deliveries complete, return to the NPC to collect payment!", "success", 5000)

    exports.mt_lib:hideMissionStatus()

    Citizen.CreateThread(function()
        exports.ox_target:addLocalEntity(ped, {
            {
                label = "Talk to NPC",
                icon = "fas fa-handshake",
                canInteract = function()
                    return deliveriesCompleted == totalDeliveries and not isPaymentCollected
                end,
                onSelect = function()
                    exports.mt_lib:showDialogue({
                        ped = ped,
                        label = 'Job NPC',
                        speech = 'You\'ve completed the deliveries. Here\'s your payment!',
                        options = {
                            {
                                id = 'collect_payment',
                                label = 'Collect Payment',
                                icon = 'money-bill-wave',
                                close = true,
                                action = function()
                                    TriggerServerEvent('delivery:completeJob')
                                    if DoesEntityExist(jobVehicle) then
                                        DeleteVehicle(jobVehicle)
                                    end
                                    isJobActive = false
                                    isPaymentCollected = true
                                end
                            },
                            {
                                id = 'close',
                                label = 'I don\'t need anything else',
                                icon = 'ban',
                                close = true
                            }
                        }
                    })
                end
            }
        })
    end)
end

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
end
