LootSpecHelperEventFrame = CreateFrame("frame", "LootSpecHelper Frame");
myPrefix = "LootSpecHelper121";
SLASH_LOOTSPECHELPER1 = "/lsh"
SLASH_LOOTSPECHELPER2 = "/lootspechelper"
MyAddOn_Comms = {};

tinsert(UISpecialFrames, LootSpecHelperEventFrame:GetName())

-- index is 2 if journal->raids->current have wb and 1 if there are no wbs,
lsh_raidIndex = 2;

loot = {};
lootNames = {};

raidDifficulties = {
    "Lfr",
    "Normal",
    "Heroic",
    "Mythic",
    "All"
};
encounterIDs = {};

difficulty = nil;
difficultyIndex = nil;
boss = nil;
bossIndex = nil;
selectedItem = nil;

dungeon = nil;
dungeonIndex = nil;
dungeonLevel = nil;
dungeonLevelIndex = nil;

addFrameGlobal = nil;
globalTab = nil;

globalSpecLootsFrame = nil;
mostRecentBoss = nil;
disabled = false;

lsh_journal_opened = false;

notLoadedItems = {};

encounterLoadedStatus = {}

keyLevels = {
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "11",
    "12",
    "13",
    "14",
    "15",
    "16",
    "17",
    "18",
    "19",
    "20+"
}

function SlashCmdList.LOOTSPECHELPER(msg, editbox)
    if strtrim(msg) == "enable" then
        disabled = false;
        mostRecentBoss = nil;
        print("LootSpecHelper enabled")
    else
        LootSpecHelperEventFrame:CreateLootSpecHelperWindow();
    end
end

function tprint (tbl, indent)
    if not indent then indent = 0 end
    local toprnt = string.rep(" ", indent) .. "{\r\n"
    indent = indent + 2
    for k, v in pairs(tbl) do
        toprnt = toprnt .. string.rep(" ", indent)
      if (type(k) == "number") then
        toprnt = toprnt .. "[" .. k .. "] = "
      elseif (type(k) == "string") then
        toprnt = toprnt  .. k ..  "= "
      end
      if (type(v) == "number") then
        toprnt = toprnt .. v .. ",\r\n"
      elseif (type(v) == "string") then
        toprnt = toprnt .. "\"" .. v .. "\",\r\n"
      elseif (type(v) == "table") then
        toprnt = toprnt .. tprint(v, indent + 2) .. ",\r\n"
      else
        toprnt = toprnt .. "\"" .. tostring(v) .. "\",\r\n"
      end
    end
    toprnt = toprnt .. string.rep(" ", indent-2) .. "}"
    return toprnt
end

function LootSpecHelperEventFrame:CustomGetInstanceInfo()
    local latestTierIndex = EJ_GetNumTiers()
    EJ_SelectTier(latestTierIndex)

    local raids = {}
    local dungeons = {}

    local index = lsh_raidIndex
    while true do
        local instanceID, name, _, _, _, _, _, isRaid = EJ_GetInstanceByIndex(index, true)
        if not instanceID then break end
        local bosses = {}
        EJ_SelectInstance(instanceID)
        local bossIndex = 1
        while true do
            local bossName, _, encounterID = EJ_GetEncounterInfoByIndex(bossIndex)
            if not bossName then break end
            encounterLoadedStatus[bossName] = false
            table.insert(bosses, {name = bossName, id = encounterID})
            bossIndex = bossIndex + 1
        end
        table.insert(raids, {instanceName = name, instanceID = instanceID, bosses = bosses})
        index = index + 1
    end


    index = 1
    while true do
        local instanceID, name = EJ_GetInstanceByIndex(index, false)
        if not instanceID then break end
        encounterLoadedStatus[name] = false
        table.insert(dungeons, {instanceName = name, instanceID = instanceID})
        index = index + 1
    end
    return raids, dungeons
end

function determineDungeonDropsForLootSpecs(current_lsh_instanceName)
    local latestTierIndex = EJ_GetNumTiers()

    local function lsh_On()
        EncounterJournal:RegisterEvent("EJ_LOOT_DATA_RECIEVED");
        EncounterJournal:RegisterEvent("EJ_DIFFICULTY_UPDATE");
        EncounterJournal:RegisterEvent("UNIT_PORTRAIT_UPDATE");
        EncounterJournal:RegisterEvent("PORTRAITS_UPDATED");
        EncounterJournal:RegisterEvent("SEARCH_DB_LOADED");
        EncounterJournal:RegisterEvent("UI_MODEL_SCENE_INFO_UPDATED");
    end
    local function lsh_Off()
        EncounterJournal:UnregisterEvent("EJ_LOOT_DATA_RECIEVED");
        EncounterJournal:UnregisterEvent("EJ_DIFFICULTY_UPDATE");
        EncounterJournal:UnregisterEvent("UNIT_PORTRAIT_UPDATE");
        EncounterJournal:UnregisterEvent("PORTRAITS_UPDATED");
        EncounterJournal:UnregisterEvent("SEARCH_DB_LOADED");
        EncounterJournal:UnregisterEvent("UI_MODEL_SCENE_INFO_UPDATED");
    end

    local targetedInstanceId = nil;
    index = 1
    if EncounterJournal ~= nil then
        lsh_Off()
    end
    EJ_SelectTier(latestTierIndex)
    while true do
        local lsh_instanceID, lsh_dungeon_instance_name = EJ_GetInstanceByIndex(index, false)
        if not instanceID then break end
        if lsh_dungeon_instance_name == current_lsh_instanceName then
            targetedInstanceId = lsh_instanceID;
            break;
        end
        index = index + 1
    end
    if targetedInstanceId ~= nil then
    
        local function targetingItem(passedItemId)
            for k, v in pairs(targetedItemsDungeon) do
                if v["itemId"] == passedItemId then
                    return v["name"]
                end
            end
            return nil;
        end

        EJ_SelectInstance(targetedInstanceId)
        local lsh_class_id = select(3,UnitClass('player'))
        local lsh_numSpecializations = GetNumSpecializationsForClassID(lsh_class_id)
        local specTables = {};
        -- get the targeted items for each spec
        for lsh_specFilter = 1, lsh_numSpecializations, 1 do
            local lsh_currentTable = {};
            lsh_spec_id, lsh_name = GetSpecializationInfo(lsh_specFilter)
            EJ_SetLootFilter(lsh_class_id, lsh_spec_id)

            index = 1
            while true do
                local itemId = C_EncounterJournal.GetLootInfoByIndex(index);
                if not itemId then break end
                if targetingItem(itemId["itemID"]) then
                    table.insert(lsh_currentTable, itemId["itemID"])
                end
                index = index + 1
            end
            table.insert(specTables, lsh_specFilter, lsh_currentTable)
        end

        local sharedLoot = {};
        -- determine whats shared
        for k,v in pairs(specTables[1]) do
            isSharedLoot = true;
            for lsh_specFilter = 2, lsh_numSpecializations, 1 do
                local lsh_currentTable = specTables[lsh_specFilter];
                local alsoHas = false;
                for _,value in pairs(lsh_currentTable) do
                    if value == v then
                        alsoHas = true;
                        break;
                    end
                end
                if alsoHas == false then
                    isSharedLoot = false;
                end
            end
            if isSharedLoot then
                table.insert( sharedLoot,v )
                for lsh_specFilter = 2, lsh_numSpecializations, 1 do
                    local removalCounter = 1
                    for _,value in pairs(specTables[lsh_specFilter]) do
                        if value == v then
                            break;
                        end
                        removalCounter = removalCounter + 1
                    end
                    table.remove( specTables[lsh_specFilter], removalCounter )
                end
            end
        end
        for k,v in pairs(sharedLoot) do
            local removalCounter = 1
            for _,value in pairs(specTables[1]) do
                if value == v then
                    break;
                end
                removalCounter = removalCounter + 1
            end
            table.remove( specTables[1], removalCounter )
        end
        C_Timer.After(0.1, function()
            displaySpecLoot(specTables, sharedLoot, "dungeon")
        end)
    end
    if EncounterJournal ~= nil then
        lsh_On()
    end
end


function LootSpecHelperEventFrame:onLoad()
	AceGUI = LibStub("AceGUI-3.0");
	LootSpecHelperEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	LootSpecHelperEventFrame:SetScript("OnEvent", LootSpecHelperEventFrame.OnEvent);
	LootSpecHelperEventFrame:RegisterEvent("ENCOUNTER_END")
	LootSpecHelperEventFrame:SetScript("OnEvent", LootSpecHelperEventFrame.OnEvent);
	LootSpecHelperEventFrame:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
	LootSpecHelperEventFrame:SetScript("OnEvent", LootSpecHelperEventFrame.OnEvent);
end

function LootSpecHelperEventFrame:LoadSavedVariables()
	if targetedItemsRaid == nil then
        targetedItemsRaid = {};
    end
	if targetedItemsDungeon == nil then
        targetedItemsDungeon = {};
    end
end

function checkLoadedItem(loadedItemId)
    local function buildLink(id, name)
        local specIndex = GetSpecialization();
        local specId = GetSpecializationInfo(specIndex)

        local levelsBonusId = nil;
        local level = dungeonLevel;

        if level == "2" then
            levelsBonusId = 1624
        elseif level == "3" or level == "4" then
            levelsBonusId = 1627
        elseif level == "5" or level == "6" then
            levelsBonusId = 1630
        elseif level == "7" or level == "8" then
            levelsBonusId = 1633
        elseif level == "9" or level == "10" then
            levelsBonusId = 1637
        elseif level == "11" or level == "12" then
            levelsBonusId = 1640
        elseif level == "13" or level == "14" then
            levelsBonusId = 1643
        elseif level == "15" or level == "16" then
            levelsBonusId = 1646
        elseif level == "17" or level == "18" then
            levelsBonusId = 1650
        elseif level == "19" or level == "20+" then
            levelsBonusId = 1653
        else
            print("level was different. " )
            print(dungeonLevel)
        end

        local itemId = id .. ":"
        local enchantID = ":"
        local gemID1 = ":"
        local gemID2 = ":"
        local gemID3 = ":"
        local gemID4 = ":"
        local suffixID = ":"
        local uniqueID = ":"
        local linkLevel = "50:"
        local specializationID = specId .. ":"
        local modifiersMask = ":"
        local itemContext = "22:"
        local numBonusIDs;
        if levelsBonusId ~= nil then
            numBonusIDs = "1:" .. levelsBonusId
        end
        local numModifiers = ":"
        local relic1NumBonusIDs= ":"
        local relic2NumBonusIDs = ":"
        local relic3NumBonusIDs = ":"
        local crafterGUID = ":"
        local extraEnchantID = ":"
        local itemLink2 = "|cffa335ee|Hitem:"..itemId..enchantID..gemID1..gemID2..gemID3..gemID4..suffixID..uniqueID..linkLevel..specializationID..modifiersMask..itemContext..numBonusIDs..numModifiers..relic1NumBonusIDs..relic2NumBonusIDs..relic3NumBonusIDs..crafterGUID..extraEnchantID
        itemLink2 = itemLink2.."|h[" .. name .. "]|h|r"
        return itemLink2
    end
    local lsh_removeCounter = 1;
    for _,v in pairs(notLoadedItems) do
        if v == loadedItemId then
            itemName = GetItemInfo(loadedItemId) 
            local newLink = buildLink( loadedItemId, itemName)
            local indexCounter = 1
            local newRow = nil;
            for _,value in pairs(loot) do
                if value["itemID"] == loadedItemId then
                    newRow = value;
                    break
                end
                indexCounter = indexCounter + 1;
            end
            newRow["link"] = newLink
            newRow["name"] = itemName
            loot[indexCounter] = newRow
        end
        lsh_removeCounter = lsh_removeCounter + 1;
    end
end

function LootSpecHelperEventFrame:OnEvent(event, text, ... )
	if(event == "PLAYER_ENTERING_WORLD") then
        disabled = false;
        mostRecentBoss = nil;
        lsh_journal_opened = false;
        LootSpecHelperEventFrame:onLoad();
        inInstance, instanceType = IsInInstance()
        if (inInstance) and (instanceType == "party") then
            local inTargetedInstance = false;
            lsh_instanceName, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
            for _,v in pairs(targetedItemsDungeon) do
                if v["dungeon"] == lsh_instanceName then
                    inTargetedInstance = true;
                    break;
                end
            end
            if inTargetedInstance == true then
                determineDungeonDropsForLootSpecs(lsh_instanceName);
            else
            end
        end
    elseif(event == "ADDON_LOADED" ) then
        if(text == "LootSpecHelper") then
            LootSpecHelperEventFrame:LoadSavedVariables();
        end
        if(text == "Blizzard_EncounterJournal") then
            lsh_journal_opened = true;
        end
    elseif(event == "PLAYER_TARGET_CHANGED") then
        checkTarget()
    elseif(event == "ENCOUNTER_END") then
        encounterName, encounterID, difficultyID, groupSize, success = ...;
        print("the encounter that just ended has the name  of " .. encounterName)
        if encounterName == mostRecentBoss then
            mostRecentBoss = nil;
        end
    elseif(event == "EJ_LOOT_DATA_RECIEVED") then
        checkLoadedItem(text)
    end -- if its the event we want
end --function

LootSpecHelperEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
LootSpecHelperEventFrame:RegisterEvent("ADDON_LOADED")
LootSpecHelperEventFrame:SetScript("OnEvent", LootSpecHelperEventFrame.OnEvent);

function LootSpecHelperEventFrame:CreateLootSpecHelperWindow()
    local raids, dungeons = self:CustomGetInstanceInfo()

    local function setLoot(key, type, dungeonName)
        local function buildLink(id, name)
            local specIndex = GetSpecialization();
            local specId = GetSpecializationInfo(specIndex)

            local levelsBonusId = nil;
            local level = dungeonLevel;

            if level == "2" then
                levelsBonusId = 1624
            elseif level == "3" or level == "4" then
                levelsBonusId = 1627
            elseif level == "5" or level == "6" then
                levelsBonusId = 1630
            elseif level == "7" or level == "8" then
                levelsBonusId = 1633
            elseif level == "9" or level == "10" then
                levelsBonusId = 1637
            elseif level == "11" or level == "12" then
                levelsBonusId = 1640
            elseif level == "13" or level == "14" then
                levelsBonusId = 1643
            elseif level == "15" or level == "16" then
                levelsBonusId = 1646
            elseif level == "17" or level == "18" then
                levelsBonusId = 1650
            elseif level == "19" or level == "20+" then
                levelsBonusId = 1653
            else
                print("level was different. " )
                print(dungeonLevel)
            end

            local itemId = id .. ":"
            local enchantID = ":"
            local gemID1 = ":"
            local gemID2 = ":"
            local gemID3 = ":"
            local gemID4 = ":"
            local suffixID = ":"
            local uniqueID = ":"
            local linkLevel = "50:"
            local specializationID = specId .. ":"
            local modifiersMask = ":"
            local itemContext = "22:"
            local numBonusIDs;
            if levelsBonusId ~= nil then
                numBonusIDs = "1:" .. levelsBonusId
            end
            local numModifiers = ":"
            local relic1NumBonusIDs= ":"
            local relic2NumBonusIDs = ":"
            local relic3NumBonusIDs = ":"
            local crafterGUID = ":"
            local extraEnchantID = ":"
            local itemLink2 = "|cffa335ee|Hitem:"..itemId..enchantID..gemID1..gemID2..gemID3..gemID4..suffixID..uniqueID..linkLevel..specializationID..modifiersMask..itemContext..numBonusIDs..numModifiers..relic1NumBonusIDs..relic2NumBonusIDs..relic3NumBonusIDs..crafterGUID..extraEnchantID
            itemLink2 = itemLink2.."|h[" .. name .. "]|h|r"
            return itemLink2
        end

        loot = {};
        lootNames = {};
        local class_id = select(3,UnitClass('player'))
        EJ_SetLootFilter(class_id)

        local function lsh_On()
            EncounterJournal:RegisterEvent("EJ_LOOT_DATA_RECIEVED");
            EncounterJournal:RegisterEvent("EJ_DIFFICULTY_UPDATE");
            EncounterJournal:RegisterEvent("UNIT_PORTRAIT_UPDATE");
            EncounterJournal:RegisterEvent("PORTRAITS_UPDATED");
            EncounterJournal:RegisterEvent("SEARCH_DB_LOADED");
            EncounterJournal:RegisterEvent("UI_MODEL_SCENE_INFO_UPDATED");
        end
        local function lsh_Off()
            EncounterJournal:UnregisterEvent("EJ_LOOT_DATA_RECIEVED");
            EncounterJournal:UnregisterEvent("EJ_DIFFICULTY_UPDATE");
            EncounterJournal:UnregisterEvent("UNIT_PORTRAIT_UPDATE");
            EncounterJournal:UnregisterEvent("PORTRAITS_UPDATED");
            EncounterJournal:UnregisterEvent("SEARCH_DB_LOADED");
            EncounterJournal:UnregisterEvent("UI_MODEL_SCENE_INFO_UPDATED");
        end

        if lsh_journal_opened == true then
            lsh_Off()
        end

        if type == "raid" then

            local addingDifficulty = 0;
            if difficulty == "Lfr" then
                addingDifficulty = 17;
            elseif difficulty == "Normal" then
                addingDifficulty = 14;
            elseif difficulty == "Heroic" then
                addingDifficulty = 15;
            elseif difficulty == "Mythic" then
                addingDifficulty = 16;
            elseif difficulty == "All" then
                addingDifficulty = 16;
            end

            EJ_SelectTier(EJ_GetNumTiers())
            EJ_SelectInstance(EJ_GetInstanceByIndex(2, true))
            EJ_SelectEncounter(encounterIDs[key])
            EJ_SetDifficulty(addingDifficulty)
            index = 1
            while true do
                local itemId = C_EncounterJournal.GetLootInfoByIndex(index);
                if not itemId then break end
                local name = itemId["name"]
                local itemID = itemId["itemID"]
                local slot = itemId["slot"]
                local encounterID = itemId["encounterID"]
                local icon = itemId["icon"]
                local itemLink = itemId["link"]
                local encounterName = EJ_GetEncounterInfo(encounterID)
                table.insert(loot, {itemID = itemID,  encounterId = encounterID, name = name, icon = icon, slot = slot, bossName = encounterName, link = itemLink});
                table.insert(lootNames, name);
                index = index + 1
            end
        elseif type == "dungeon" then
            EJ_SelectInstance(encounterIDs[key])
            EJ_SetDifficulty(8)
            for i = 1, EJ_GetNumLoot(), 1 do
                local itemId = C_EncounterJournal.GetLootInfoByIndex(i)
                if not itemId then break end
                local name = itemId["name"]
                local itemID = itemId["itemID"]
                local slot = itemId["slot"]
                local encounterID = itemId["encounterID"]
                local icon = itemId["icon"]
                if name ~= nil then
                    local itemLink = buildLink(itemID, name)
                    table.insert(loot, {itemID = itemID,  encounterId = encounterID, name = name, icon = icon, slot = slot, dungeon = dungeonName, link = itemLink});
                    table.insert(lootNames, name);
                else
                    local itemLink = "|cffa335ee|Hitem:".. itemID .. "]|h|r"
                    table.insert(loot, {itemID = itemID,  encounterId = encounterID, name = name, icon = icon, slot = slot, dungeon = dungeonName, link = itemLink});
                    table.insert(lootNames, name);
                    table.insert( notLoadedItems, itemID )
                end
                --local itemLink = buildLink(itemID, name)
            end
        end
        if lsh_journal_opened == true then
            lsh_On()
        end
    end

    local function NewItemPopupRaid(lsh_currentPoint, lsh_returnedX, lsh_returnedY)
        local function addToTargeted()
            local function checkContains(checkDifficulty)
                for _,checkingV in pairs(targetedItemsRaid) do
                    if (selectedItem["itemID"] == checkingV["itemId"]) and (checkDifficulty == checkingV["difficulty"]) then
                        return true
                    end
                end
                return false
            end

            if difficulty == "All" then
                if checkContains("Lfr") == false then
                    local class_id = select(3,UnitClass('player'))
                    local properLink = selectedItem["link"]
                    EJ_SetLootFilter(class_id)
                    EJ_SelectEncounter(selectedItem["encounterId"])
                    EJ_SetDifficulty(17)
                    index = 1
                    while true do
                        local lootItem = C_EncounterJournal.GetLootInfoByIndex(index);
                        if lootItem["itemID"] == selectedItem["itemID"] then
                            properLink = lootItem["link"]
                            break
                        end
                        index = index + 1
                    end
                    table.insert(targetedItemsRaid, {itemId = selectedItem["itemID"], name = selectedItem["name"], icon = selectedItem["icon"], difficulty = "Lfr", boss = selectedItem["bossName"], encounterId = selectedItem["encounterId"], link = properLink})
                end

                if checkContains("Normal") == false then
                    local class_id = select(3,UnitClass('player'))
                    local properLink = selectedItem["link"]
                    EJ_SetLootFilter(class_id)
                    EJ_SelectEncounter(selectedItem["encounterId"])
                    EJ_SetDifficulty(14)
                    index = 1
                    while true do
                        local lootItem = C_EncounterJournal.GetLootInfoByIndex(index);
                        if lootItem["itemID"] == selectedItem["itemID"] then
                            properLink = lootItem["link"]
                            break
                        end
                        index = index + 1
                    end
                    table.insert(targetedItemsRaid, {itemId = selectedItem["itemID"], name = selectedItem["name"], icon = selectedItem["icon"], difficulty = "Normal", boss = selectedItem["bossName"], encounterId = selectedItem["encounterId"], link = properLink})
                end

                if checkContains("Heroic") == false then
                    local class_id = select(3,UnitClass('player'))
                    local properLink = selectedItem["link"]
                    EJ_SetLootFilter(class_id)
                    EJ_SelectEncounter(selectedItem["encounterId"])
                    EJ_SetDifficulty(15)
                    index = 1
                    while true do
                        local lootItem = C_EncounterJournal.GetLootInfoByIndex(index);
                        if lootItem["itemID"] == selectedItem["itemID"] then
                            properLink = lootItem["link"]
                            break
                        end
                        index = index + 1
                    end
                    table.insert(targetedItemsRaid, {itemId = selectedItem["itemID"], name = selectedItem["name"], icon = selectedItem["icon"], difficulty = "Heroic", boss = selectedItem["bossName"], encounterId = selectedItem["encounterId"], link = properLink})
                end

                if checkContains("Mythic") == false then
                    local class_id = select(3,UnitClass('player'))
                    local properLink = selectedItem["link"]
                    EJ_SetLootFilter(class_id)
                    EJ_SelectEncounter(selectedItem["encounterId"])
                    EJ_SetDifficulty(16)
                    index = 1
                    while true do
                        local lootItem = C_EncounterJournal.GetLootInfoByIndex(index);
                        if lootItem["itemID"] == selectedItem["itemID"] then
                            properLink = lootItem["link"]
                            break
                        end
                        index = index + 1
                    end
                    table.insert(targetedItemsRaid, {itemId = selectedItem["itemID"], name = selectedItem["name"], icon = selectedItem["icon"], difficulty = "Mythic", boss = selectedItem["bossName"], encounterId = selectedItem["encounterId"], link = properLink})
                end

                return
            end

            if checkContains(difficulty) == false then
                table.insert(targetedItemsRaid, {itemId = selectedItem["itemID"], name = selectedItem["name"], icon = selectedItem["icon"], difficulty = difficulty, boss = selectedItem["bossName"], encounterId = selectedItem["encounterId"], link = selectedItem["link"]})
            end
        end

        encounterIDs = {};
        raidSaved = false;

        addFrameGlobal = AceGUI:Create("Frame")
        if lsh_currentPoint ~= nil then
            addFrameGlobal:SetPoint(lsh_currentPoint, lsh_returnedX, lsh_returnedY)
        end
        addFrameGlobal:SetWidth(250)
	    addFrameGlobal:SetTitle("Add Raid Item")

        local difficultyDropdown = AceGUI:Create("Dropdown")
        difficultyDropdown:SetList(raidDifficulties)
        difficultyDropdown:SetText("Difficulty")
        difficultyDropdown:SetCallback("OnValueChanged", function(widget, event, key)
            difficulty = raidDifficulties[key];
            difficultyIndex = key;
        end)
        if difficultyIndex ~= nil then
            difficultyDropdown:SetValue(difficultyIndex)
        end
        addFrameGlobal:AddChild(difficultyDropdown);

        local bossesOnly = {};
        --get info for each boss
        for k,v in pairs(raids) do
            if (type(v) == "table") then
                for key, value in pairs(v) do
                    if (type(value) == "table") then
                        for newkey, newvalue in pairs(value) do
                            if (type(newvalue) == "table") then
                                table.insert(bossesOnly, newvalue["name"])
                                table.insert(encounterIDs, newvalue["id"])
                            end
                        end
                    end
                end
            end
        end

        local bossDropdown = AceGUI:Create("Dropdown");
        bossDropdown:SetList(bossesOnly);
        bossDropdown:SetText("Boss");
        if bossIndex ~= nil then
            bossDropdown:SetValue(bossIndex)
        end
        bossDropdown:SetCallback("OnValueChanged", function(widget, event, key)
            boss = bossesOnly[key];
            bossIndex = key;
            setLoot(key, "raid");
            if encounterLoadedStatus[boss] == false then
                encounterLoadedStatus[boss] = true
                C_Timer.After(0.1, function()
                    setLoot(key, "raid");
                end)
            end
            C_Timer.After(0.2, function()
                local lsh_currentPoint, lsh_returnedTableThing, lsh_currentPointRepeat, lsh_returnedX, lsh_returnedY = addFrameGlobal:GetPoint()
                addFrameGlobal:ReleaseChildren();
                addFrameGlobal:Release();
                NewItemPopupRaid(lsh_currentPoint, lsh_returnedX, lsh_returnedY)
            end)
        end)

        addFrameGlobal:AddChild(bossDropdown);

        local lootDropdown = AceGUI:Create("Dropdown")
        lootDropdown:SetList(lootNames)
        lootDropdown:SetText("Loot Item")
        lootDropdown:SetCallback("OnValueChanged", function(lootWidget, lootEvent, lootKey)
            selectedItem = loot[lootKey]
        end)
        addFrameGlobal:AddChild(lootDropdown);

        local saveButton = AceGUI:Create("Button");
        saveButton:SetText("Save");
        saveButton:SetCallback("OnClick", function(widget)
            if (difficulty ~= nil) and (boss ~= nil) and (selectedItem ~= nil) then
                addToTargeted();
                AceGUI:Release(addFrameGlobal)
                addFrameGlobal = nil;
                difficulty = nil;
                difficultyIndex = nil;
                boss = nil;
                bossIndex = nil;
                selectedItem = nil;
                raidSaved = true;
                loot = {};
                lootNames = {};
                globalTab:SelectTab("tab1")
            else
                --TODO: space this out more vertically, and center it horizontally
                local errorFrame = AceGUI:Create("Window")
                errorFrame:SetWidth(200)
                errorFrame:SetHeight(200)
                errorFrame:SetTitle("Error")
                errorFrame:SetLayout("Flow")

                local errorMessage = AceGUI:Create("InteractiveLabel");
                errorMessage:SetText("You must include a difficulty, boss and loot item");
                errorMessage:SetFullWidth(true)
                errorFrame:AddChild(errorMessage);

                local okButton = AceGUI:Create("Button");
                okButton:SetText("OK");
                okButton:SetWidth(175)
                okButton:SetCallback("OnClick", function()
                    local lsh_currentPoint, lsh_returnedTableThing, lsh_currentPointRepeat, lsh_returnedX, lsh_returnedY = addFrameGlobal:GetPoint()
                    addFrameGlobal:ReleaseChildren();
                    addFrameGlobal:Release();
                    NewItemPopupRaid(lsh_currentPoint, lsh_returnedX, lsh_returnedY)
                end);
                errorFrame:AddChild(okButton);
                addFrameGlobal:AddChild(errorFrame)
            end
        end)
        saveButton:SetWidth(200);
        addFrameGlobal:AddChild(saveButton);
        addFrameGlobal:SetCallback("OnClose", function(widget)
            widget:ReleaseChildren();
            AceGUI:Release(widget);
            if raidSaved == true then
                difficulty = nil;
                difficultyIndex = nil;
                boss = nil;
                bossIndex = nil;
            end
            selectedItem = nil;
            addFrameGlobal = nil;
        end)
    end -- new item popup raid

    local function NewItemPopupDungeon(lsh_currentPoint, lsh_returnedX, lsh_returnedY)
        local function addToTargeted()
            for k,v in pairs(targetedItemsDungeon) do
                if (selectedItem["itemID"] == v["itemId"]) then
                    return
                end
            end

            table.insert(targetedItemsDungeon, {itemId = selectedItem["itemID"], name = selectedItem["name"], icon = selectedItem["icon"], dungeon = selectedItem["dungeon"], link = selectedItem["link"]})
        end

        encounterIDs = {};
        dungeonSaved = false;

        addFrameGlobal = AceGUI:Create("Frame")
        if lsh_currentPoint ~= nil then
            addFrameGlobal:SetPoint(lsh_currentPoint, lsh_returnedX, lsh_returnedY)
        end
        addFrameGlobal:SetWidth(250)
	    addFrameGlobal:SetTitle("Add Dungeon Item")

        local dungeonsOnly = {};
        --get raid bosses info
        for k,v in pairs(dungeons) do
            if (type(v) == "table") then
                table.insert(dungeonsOnly, v["instanceName"])
                table.insert(encounterIDs, v["instanceID"])
            end
        end

        local keyLevelDropdown = AceGUI:Create("Dropdown");
        keyLevelDropdown:SetList(keyLevels);
        keyLevelDropdown:SetText("Key Level");
        if dungeonLevelIndex ~= nil then
            keyLevelDropdown:SetValue(dungeonLevelIndex)
        end
        keyLevelDropdown:SetCallback("OnValueChanged", function(widget, event, key)
            dungeonLevel = keyLevels[key];
            dungeonLevelIndex = key;
            if dungeonIndex ~= nil then
                setLoot(dungeonIndex, "dungeon", dungeon);
                C_Timer.After(0.4, function()
                    local lsh_currentPoint, lsh_returnedTableThing, lsh_currentPointRepeat, lsh_returnedX, lsh_returnedY = addFrameGlobal:GetPoint()
                    addFrameGlobal:ReleaseChildren();
                    addFrameGlobal:Release();
                    NewItemPopupDungeon(lsh_currentPoint, lsh_returnedX, lsh_returnedY);
                end)
            end
        end)
        addFrameGlobal:AddChild(keyLevelDropdown);

        local dungeonDropdown = AceGUI:Create("Dropdown");
        dungeonDropdown:SetList(dungeonsOnly);
        dungeonDropdown:SetText("Dungeon");
        if dungeonIndex ~= nil then
            dungeonDropdown:SetValue(dungeonIndex)
        end
        dungeonDropdown:SetCallback("OnValueChanged", function(widget, event, key)
            dungeon = dungeonsOnly[key];
            dungeonIndex = key;
            setLoot(key, "dungeon", dungeon);
            if encounterLoadedStatus[dungeon] == false then
                encounterLoadedStatus[dungeon] = true
                C_Timer.After(0.1, function()
                    setLoot(key, "dungeon", dungeon);
                end)
            end
            C_Timer.After(0.2, function()
                local lsh_currentPoint, lsh_returnedTableThing, lsh_currentPointRepeat, lsh_returnedX, lsh_returnedY = addFrameGlobal:GetPoint()
                addFrameGlobal:ReleaseChildren();
                addFrameGlobal:Release();
                NewItemPopupDungeon(lsh_currentPoint, lsh_returnedX, lsh_returnedY);
            end)
        end)
        addFrameGlobal:AddChild(dungeonDropdown);

        local lootDropdown = AceGUI:Create("Dropdown")
        lootDropdown:SetList(lootNames)
        lootDropdown:SetText("Loot Item")
        lootDropdown:SetCallback("OnValueChanged", function(lootWidget, lootEvent, lootKey)
            selectedItem = loot[lootKey]
        end)
        addFrameGlobal:AddChild(lootDropdown);

        local saveButton = AceGUI:Create("Button");
        saveButton:SetText("Save");
        saveButton:SetCallback("OnClick", function(widget)
            if (dungeon ~= nil) and (selectedItem ~= nil) then
                addToTargeted();
                AceGUI:Release(addFrameGlobal)
                addFrameGlobal = nil;
                dungeon = nil;
                dungeonIndex = nil;
                dungeonLevel = nil;
                dungeonLevelIndex = nil;
                selectedItem = nil;
                dungeonSaved = true;
                globalTab:SelectTab("tab2")
            else
                --TODO: space this out more vertically, and center it horizontally
                local errorFrame = AceGUI:Create("Window")
                errorFrame:SetWidth(200)
                errorFrame:SetHeight(200)
                errorFrame:SetTitle("Error")

                local errorMessage = AceGUI:Create("InteractiveLabel");
                errorMessage:SetText("You must include a dungeon and loot item");
                errorFrame:AddChild(errorMessage);

                local okButton = AceGUI:Create("Button");
                okButton:SetText("OK");
                okButton:SetWidth(175)
                okButton:SetCallback("OnClick", function()
                    local lsh_currentPoint, lsh_returnedTableThing, lsh_currentPointRepeat, lsh_returnedX, lsh_returnedY = addFrameGlobal:GetPoint()
                    addFrameGlobal:ReleaseChildren();
                    addFrameGlobal:Release();
                    NewItemPopupDungeon(lsh_currentPoint, lsh_returnedX, lsh_returnedY)
                end);
                errorFrame:AddChild(okButton);
                addFrameGlobal:AddChild(errorFrame)
            end
        end)
        saveButton:SetWidth(200);
        addFrameGlobal:AddChild(saveButton);
        addFrameGlobal:SetCallback("OnClose", function(widget)
            widget:ReleaseChildren();
            AceGUI:Release(widget);
            if dungeonSaved == true then
                dungeon = nil;
                dungeonIndex = nil;
                dungeonLevel = nil;
                dungeonLevelIndex = nil;
            end
            selectedItem = nil;
            addFrameGlobal = nil;
        end)
    end -- new item popup dungeon

	local function DrawRaid(container)
        local function removeTargetedItem(itemId, difficulty)
            for k,v in pairs(targetedItemsRaid) do
                if (v["itemId"] == itemId) and (v["difficulty"] == difficulty) then
                    table.remove( targetedItemsRaid, k)
                end
            end
        end

        raidTabContainer = AceGUI:Create("SimpleGroup");
        raidTabContainer:SetFullWidth(true);
        raidTabContainer:SetFullHeight(true);
        raidTabContainer:SetLayout("Fill");
        container:AddChild(raidTabContainer);

        raidScroll = AceGUI:Create("ScrollFrame");
        raidScroll:SetLayout("Flow");
        raidTabContainer:AddChild(raidScroll);

        targetedItemContainer = AceGUI:Create("SimpleGroup");
        targetedItemContainer:SetLayout("List");
        targetedItemContainer:SetFullWidth(true);
        raidScroll:AddChild(targetedItemContainer);

        for k,v in pairs(targetedItemsRaid) do
            --TODO: center the icon horizontally or at least align with the text and push delete button to the right side

            cardContainer = AceGUI:Create("SimpleGroup");
            cardContainer:SetLayout("Flow");
            cardContainer:SetFullWidth(true);
            targetedItemContainer:AddChild(cardContainer);

            --TODO: need to center this horizontally

            local targetItem = AceGUI:Create("InteractiveLabel");
            targetItem:SetText(v["name"] .. " - " .. v["difficulty"]);
            targetItem:SetImage(GetItemIcon(v["itemId"]));
            targetItem:SetImageSize(50,50);
            targetItem:SetCallback("OnEnter", function(widget)
                GameTooltip:SetOwner(LootSpecHelperEventFrame, "ANCHOR_CURSOR")
                if ( (IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems")) ) then
                    GameTooltip_ShowCompareItem(GameTooltip)
                end
                GameTooltip:SetHyperlink(v["link"])
            end)
            targetItem:SetCallback("OnLeave", function(widget) GameTooltip:FadeOut() end)
            cardContainer:AddChild(targetItem);

            local deleteButton = AceGUI:Create("Button")
            deleteButton:SetHeight(20)
            deleteButton:SetWidth(100)
            deleteButton:SetText("DELETE")
            deleteButton:SetCallback("OnClick", function()
                removeTargetedItem(v["itemId"],v["difficulty"])
                globalTab:SelectTab("tab1")
            end)
            cardContainer:AddChild(deleteButton);
        end

        --TODO: anchor the button to the bottom of the container and center horizontally.
        local button = AceGUI:Create("Button");
        button:SetText("Add item");
        button:SetCallback("OnClick", function() NewItemPopupRaid(nil) end)
        button:SetWidth(325);
        raidScroll:AddChild(button);
    end -- draw raid

	local function DrawDungeon(container)
        local function removeTargetedItem(itemId)
            for k,v in pairs(targetedItemsDungeon) do
                if (v["itemId"] == itemId) then
                    table.remove(targetedItemsDungeon, k)
                end
            end
        end

        dungeonTabContainer = AceGUI:Create("SimpleGroup");
        dungeonTabContainer:SetFullWidth(true);
        dungeonTabContainer:SetFullHeight(true);
        dungeonTabContainer:SetLayout("Fill");
        container:AddChild(dungeonTabContainer);

        dungeonScroll = AceGUI:Create("ScrollFrame");
        dungeonScroll:SetLayout("Flow");
        dungeonTabContainer:AddChild(dungeonScroll);

        targetedItemContainer = AceGUI:Create("SimpleGroup");
        targetedItemContainer:SetLayout("List");
        targetedItemContainer:SetFullWidth(true);
        dungeonScroll:AddChild(targetedItemContainer);

        for k,v in pairs(targetedItemsDungeon) do
            --TODO: center the icon horizontally or at least align with the text and push delete button to the right side

            cardContainer = AceGUI:Create("SimpleGroup");
            cardContainer:SetLayout("Flow");
            cardContainer:SetFullWidth(true);
            targetedItemContainer:AddChild(cardContainer);

            --TODO: need to center this horizontally

            local targetItem = AceGUI:Create("InteractiveLabel");
            targetItem:SetText(v["name"] .. " - " .. v["dungeon"]);
            targetItem:SetImage(GetItemIcon(v["itemId"]));
            targetItem:SetImageSize(50,50);
            targetItem:SetCallback("OnEnter", function(widget) 
                GameTooltip:SetOwner(LootSpecHelperEventFrame, "ANCHOR_CURSOR")
                if ( (IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems")) ) then
                    GameTooltip_ShowCompareItem(GameTooltip)
                end
                GameTooltip:SetHyperlink(v["link"])
            end)
            targetItem:SetCallback("OnLeave", function(widget) GameTooltip:FadeOut() end)
            cardContainer:AddChild(targetItem);

            local deleteButton = AceGUI:Create("Button")
            deleteButton:SetHeight(20)
            deleteButton:SetWidth(100)
            deleteButton:SetText("DELETE")
            deleteButton:SetCallback("OnClick", function()
                removeTargetedItem(v["itemId"])
                globalTab:SelectTab("tab2")
            end)
            cardContainer:AddChild(deleteButton);
        end

        --TODO: anchor the button to the bottom of the container and center horizontally.
        local button = AceGUI:Create("Button");
        button:SetText("Add item");
        button:SetCallback("OnClick", function() NewItemPopupDungeon(nil) end)
        button:SetWidth(325);
        dungeonScroll:AddChild(button);
    end -- draw dungeon

    -- Callback function for OnGroupSelected
	local function SelectGroup(container, event, group)
        container:ReleaseChildren();
        if group == "tab1" then
           DrawRaid(container)
        elseif group == "tab2" then
           DrawDungeon(container)
        end
     end


    -- Create the frame container
	local frame = AceGUI:Create("Frame", "LootSpecHelper Main Frame")

    -- Add the frame as a global variable under the name `MyGlobalFrameName`
    _G["LootSpecHelperGlobalFrameName"] = frame.frame
    -- Register the global variable `MyGlobalFrameName` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "LootSpecHelperGlobalFrameName")

    frame:SetWidth(425)
	frame:SetTitle("LootSpecHelper")
	frame:SetStatusText("Created by Van on Stormrage.")
	frame:SetCallback("OnClose", function(widget)
		AceGUI:Release(widget)
        if addFrameGlobal ~= nil then
            addFrameGlobal:ReleaseChildren()
            addFrameGlobal:Release()
            addFrameGlobal = nil;
        end

        difficulty = nil;
        difficultyIndex = nil;
        boss = nil;
        bossIndex = nil;
        selectedItem = nil;

        dungeon = nil;
        dungeonIndex = nil;
        dungeonLevel = nil;
        dungeonLevelIndex = nil;
	end)
	-- Fill Layout - the TabGroup widget will fill the whole frame
	frame:SetLayout("Fill")

	-- Create the TabGroup
	globalTab =  AceGUI:Create("TabGroup");
	globalTab:SetTitle("Instance Type");
	globalTab:SetLayout("Flow");

    globalTab:SetTabs( { {text="Raid", value="tab1"}, {text="M+", value="tab2"} } )

	-- Register callback
	globalTab:SetCallback("OnGroupSelected", SelectGroup)
	-- Set initial Tab (this will fire the OnGroupSelected callback)
	globalTab:SelectTab("tab1")

	-- add to the frame container
	frame:AddChild(globalTab)
end--CreateLootSpecHelperWindow

function displaySpecLoot(specTables, sharedTable, passedInstanceType)
    local specLootsFrame = AceGUI:Create("Frame", "LootSpecHelperDisplayTargets")

    -- Add the frame as a global variable under the name `MyGlobalFrameName`
    _G["LootSpecHelperTargetDisplayGlobalFrameName"] = specLootsFrame.frame
    -- Register the global variable `MyGlobalFrameName` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "LootSpecHelperTargetDisplayGlobalFrameName")

    globalSpecLootsFrame = specLootsFrame;
    specLootsFrame:SetWidth(500)
	specLootsFrame:SetTitle("LootSpecHelper")
	specLootsFrame:SetStatusText("Created by Van on Stormrage.")
	specLootsFrame:SetCallback("OnClose", function(widget)
        widget:ReleaseChildren()
		AceGUI:Release(widget)
        if globalSpecLootsFrame ~= nil then
            globalSpecLootsFrame = nil;
        end
	end)
    specLootsFrame:SetLayout("Flow")

    local testContainer = AceGUI:Create("SimpleGroup")
    testContainer:SetLayout("Fill")
    testContainer:SetFullHeight(true)
    testContainer:SetFullWidth(true)
    specLootsFrame:AddChild(testContainer);


    local scrollContainer = AceGUI:Create("ScrollFrame");
    scrollContainer:SetLayout("List");
    scrollContainer:SetFullHeight(true)
    testContainer:AddChild(scrollContainer);

    if passedInstanceType == "raid" then
        local disableButton = AceGUI:Create("Button")
        disableButton:SetText("Disable for instance");
        disableButton:SetCallback("OnClick", function(widget)
            disabled = true;
            specLootsFrame:Release()
        end)
        disableButton:SetWidth(200);
        scrollContainer:AddChild(disableButton);
    end
    local function buildLink(id, name, lshPassedDifficulty)
        local levelsBonusId = nil;

        if lshPassedDifficulty == "Lfr" then
            levelsBonusId = 1459
        elseif lshPassedDifficulty == "normal" then
            levelsBonusId = nil
        elseif lshPassedDifficulty == "heroic" then
            levelsBonusId = 1485
        else
            levelsBonusId = 1498
        end
        
        local specIndex = GetSpecialization();
        local specId = GetSpecializationInfo(specIndex)

        local itemId = id .. ":"
        local enchantID = ":"
        local gemID1 = ":"
        local gemID2 = ":"
        local gemID3 = ":"
        local gemID4 = ":"
        local suffixID = ":"
        local uniqueID = ":"
        local linkLevel = "50:"
        local specializationID = specId .. ":"
        local modifiersMask = ":"
        local itemContext = "22:"
        local numBonusIDs;
        if levelsBonusId ~= nil then
            numBonusIDs = "1:" .. levelsBonusId
        else
            numBonusIDs = ":"
        end
        local numModifiers = ":"
        local relic1NumBonusIDs= ":"
        local relic2NumBonusIDs = ":"
        local relic3NumBonusIDs = ":"
        local crafterGUID = ":"
        local extraEnchantID = ":"
        local itemLink2 = "|cffa335ee|Hitem:"..itemId..enchantID..gemID1..gemID2..gemID3..gemID4..suffixID..uniqueID..linkLevel..specializationID..modifiersMask..itemContext..numBonusIDs..numModifiers..relic1NumBonusIDs..relic2NumBonusIDs..relic3NumBonusIDs..crafterGUID..extraEnchantID
        itemLink2 = itemLink2.."|h[" .. name .. "]|h|r"
        return itemLink2
    end

    local lsh_spec_counter = 1;
    for _,v in pairs(specTables) do
        local lsh_lootItemCounter = 0;
        for _,_ in pairs(v) do
            lsh_lootItemCounter = lsh_lootItemCounter + 1;
        end
        local lsh_spec_id, lsh_spec_name = GetSpecializationInfo(lsh_spec_counter)
        lsh_spec_counter = lsh_spec_counter + 1;
        if lsh_lootItemCounter ~= 0 then
            local individualSpecContainer = AceGUI:Create("InlineGroup");
            individualSpecContainer:SetFullWidth(true);
            individualSpecContainer:SetFullHeight(true);
            individualSpecContainer:SetLayout("Flow");
            individualSpecContainer:SetTitle(lsh_spec_name);
            scrollContainer:AddChild(individualSpecContainer);

            for key, value in pairs(v) do
                if passedInstanceType == "raid" then
                    for targetKey, targetValue in pairs(targetedItemsRaid) do
                        lsh_thisDifficult = GetDifficultyInfo(GetRaidDifficultyID())
                        if lsh_thisDifficult == "Looking For Raid" then
                            lsh_thisDifficult = "Lfr"
                        end
                        if (targetValue["itemId"] == value) and (targetValue["difficulty"] == lsh_thisDifficult) then
                            local targetItem = AceGUI:Create("InteractiveLabel");
                            targetItem:SetText(targetValue["name"] .. " - " .. lsh_thisDifficult);
                            targetItem:SetImage(GetItemIcon(targetValue["itemId"]));
                            targetItem:SetImageSize(50,50);
                            targetItem:SetCallback("OnEnter", function(widget) 
                                GameTooltip:SetOwner(LootSpecHelperEventFrame, "ANCHOR_CURSOR")
                                if ( (IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems")) ) then
                                    GameTooltip_ShowCompareItem(GameTooltip)
                                end
                                local linkForToolTip = buildLink(targetValue["itemId"],targetValue["name"], lsh_thisDifficult)
                                GameTooltip:SetHyperlink(linkForToolTip)
                            end)
                            targetItem:SetCallback("OnLeave", function(widget) GameTooltip:FadeOut() end)
                            individualSpecContainer:AddChild(targetItem);
                            break
                        else
                        end
                    end
                elseif passedInstanceType == "dungeon" then
                    for targetKey, targetValue in pairs(targetedItemsDungeon) do
                        if targetValue["itemId"] == value then
                            local targetItem = AceGUI:Create("InteractiveLabel");
                            targetItem:SetText(targetValue["name"]);
                            targetItem:SetImage(GetItemIcon(targetValue["itemId"]));
                            targetItem:SetImageSize(50,50);
                            targetItem:SetCallback("OnEnter", function(widget)
                                GameTooltip:SetOwner(LootSpecHelperEventFrame, "ANCHOR_CURSOR")
                                if ( (IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems")) ) then
                                    GameTooltip_ShowCompareItem(GameTooltip)
                                end
                                GameTooltip:SetHyperlink("item:" .. targetValue["itemId"])
                                end)
                            targetItem:SetCallback("OnLeave", function(widget) GameTooltip:FadeOut() end)
                            individualSpecContainer:AddChild(targetItem);
                            break
                        end
                    end
                end
            end

            local swapSpecButton = AceGUI:Create("Button");
            swapSpecButton:SetText("Set Loot Spec to " .. lsh_spec_name);
            swapSpecButton:SetCallback("OnClick", function(widget)
                SetLootSpecialization(lsh_spec_id)
                specLootsFrame:Release()
            end)
            swapSpecButton:SetFullWidth(true);
            scrollContainer:AddChild(swapSpecButton);
        end
    end

    local lsh_lootItemCounter = 0;
    for _,_ in pairs(sharedTable) do
        lsh_lootItemCounter = lsh_lootItemCounter + 1;
    end
    if lsh_lootItemCounter ~= 0 then
        local sharedSpecContainer = AceGUI:Create("InlineGroup");
        sharedSpecContainer:SetFullWidth(true);
        sharedSpecContainer:SetFullHeight(true);
        sharedSpecContainer:SetLayout("Flow");
        sharedSpecContainer:SetTitle("Shared Spec Loot");
        scrollContainer:AddChild(sharedSpecContainer);

        for key, value in pairs(sharedTable) do
            if passedInstanceType == "raid" then
                for targetKey, targetValue in pairs(targetedItemsRaid) do
                    if targetValue["itemId"] == value then
                        local targetItem = AceGUI:Create("InteractiveLabel");
                        lsh_thisDifficult = GetDifficultyInfo(GetRaidDifficultyID())
                        if lsh_thisDifficult == "Looking For Raid" then
                            lsh_thisDifficult = "Lfr"
                        end
                        targetItem:SetText(targetValue["name"] .. " - " .. lsh_thisDifficult);
                        targetItem:SetImage(GetItemIcon(targetValue["itemId"]));
                        targetItem:SetImageSize(50,50);
                        targetItem:SetCallback("OnEnter", function(widget)
                            GameTooltip:SetOwner(LootSpecHelperEventFrame, "ANCHOR_CURSOR")
                            if ( (IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems")) ) then
                                GameTooltip_ShowCompareItem(GameTooltip)
                            end
                            local lsh_this_raidDiff = GetDifficultyInfo(GetRaidDifficultyID())
                            if lsh_this_raidDiff == "Looking For Raid" then
                                lsh_this_raidDiff = "Lfr"
                            end
                            local linkForToolTip = buildLink(targetValue["itemId"],targetValue["name"], lsh_this_raidDiff)
                            GameTooltip:SetHyperlink(linkForToolTip)
                            end)
                        targetItem:SetCallback("OnLeave", function(widget) GameTooltip:FadeOut() end)
                        sharedSpecContainer:AddChild(targetItem);
                        break
                    end
                end
            elseif passedInstanceType == "dungeon" then
                for targetKey, targetValue in pairs(targetedItemsDungeon) do
                    if (targetValue["itemId"] == value) then
                        local targetItem = AceGUI:Create("InteractiveLabel");
                        targetItem:SetText(targetValue["name"]);
                        targetItem:SetImage(GetItemIcon(targetValue["itemId"]));
                        targetItem:SetImageSize(50,50);
                        targetItem:SetCallback("OnEnter", function(widget) 
                            GameTooltip:SetOwner(LootSpecHelperEventFrame, "ANCHOR_CURSOR")
                            if ( (IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems")) ) then
                                GameTooltip_ShowCompareItem(GameTooltip)
                            end
                            GameTooltip:SetHyperlink("item:" .. targetValue["itemId"])
                        end)
                        targetItem:SetCallback("OnLeave", function(widget) GameTooltip:FadeOut() end)
                        sharedSpecContainer:AddChild(targetItem);
                        break
                    end
                end
            end
        end

        local swapSpecButton = AceGUI:Create("Button");
        local lsh_current_spec = GetSpecialization()
        local lsh_spec_id, lsh_spec_name = GetSpecializationInfo(lsh_current_spec)
        swapSpecButton:SetText("Set Loot Spec to current spec: " .. lsh_spec_name);
        swapSpecButton:SetCallback("OnClick", function(widget)
            SetLootSpecialization(lsh_spec_id)
            specLootsFrame:Release()
        end)
        swapSpecButton:SetFullWidth(true);
        scrollContainer:AddChild(swapSpecButton);
    end
end

function determineDropsForLootSpecs(passedEncounterId)
    local function targetingItem(passedItemId)
        for k, v in pairs(targetedItemsRaid) do
            local currentDiff = GetDifficultyInfo(GetRaidDifficultyID())
            if currentDiff == "Looking For Raid" then
                currentDiff = "Lfr"
            end
            if (v["itemId"] == passedItemId) and (v["difficulty"] == currentDiff) then
                return v["name"]
            end
        end
        return nil;
    end
    
    local function lsh_On()
        EncounterJournal:RegisterEvent("EJ_LOOT_DATA_RECIEVED");
        EncounterJournal:RegisterEvent("EJ_DIFFICULTY_UPDATE");
        EncounterJournal:RegisterEvent("UNIT_PORTRAIT_UPDATE");
        EncounterJournal:RegisterEvent("PORTRAITS_UPDATED");
        EncounterJournal:RegisterEvent("SEARCH_DB_LOADED");
        EncounterJournal:RegisterEvent("UI_MODEL_SCENE_INFO_UPDATED");
    end
    local function lsh_Off()
        EncounterJournal:UnregisterEvent("EJ_LOOT_DATA_RECIEVED");
        EncounterJournal:UnregisterEvent("EJ_DIFFICULTY_UPDATE");
        EncounterJournal:UnregisterEvent("UNIT_PORTRAIT_UPDATE");
        EncounterJournal:UnregisterEvent("PORTRAITS_UPDATED");
        EncounterJournal:UnregisterEvent("SEARCH_DB_LOADED");
        EncounterJournal:UnregisterEvent("UI_MODEL_SCENE_INFO_UPDATED");
    end

    local index = 1
    local lsh_this_instanceId = nil
    while true do
        tempInstanceId = EJ_GetInstanceByIndex(index, true)
        if not tempInstanceId then
            break
        end
        lsh_this_instanceId = tempInstanceId;
        index = index + 1
    end
    local lsh_class_id = select(3,UnitClass('player'))
    local lsh_numSpecializations = GetNumSpecializationsForClassID(lsh_class_id)
    local specTables = {};
    local latestTierIndex = EJ_GetNumTiers()
    if EncounterJournal ~= nil then
        lsh_Off()
    end
    EJ_SelectTier(latestTierIndex)
    EJ_SelectInstance(lsh_this_instanceId)
    for lsh_specFilter = 1, lsh_numSpecializations, 1 do
        local lsh_currentTable = {};
        lsh_spec_id, lsh_name = GetSpecializationInfo(lsh_specFilter)
        EJ_SetLootFilter(lsh_class_id, lsh_spec_id)
        EJ_SelectEncounter(passedEncounterId)
        EJ_SetDifficulty(GetRaidDifficultyID())
        index = 1
        while true do
            local itemId = C_EncounterJournal.GetLootInfoByIndex(index);
            if not itemId then break end
            if targetingItem(itemId["itemID"]) then
                table.insert(lsh_currentTable, itemId["itemID"])
            end
            index = index + 1
        end
        table.insert(specTables, lsh_specFilter, lsh_currentTable)
    end

    local sharedLoot = {};
    for k,v in pairs(specTables[1]) do
        isSharedLoot = true;
        for lsh_specFilter = 2, lsh_numSpecializations, 1 do
            local lsh_currentTable = specTables[lsh_specFilter];
            local alsoHas = false;
            for _,value in pairs(lsh_currentTable) do
                if value == v then
                    alsoHas = true;
                end
            end
            if alsoHas == false then
                isSharedLoot = false;
            end
        end
        if isSharedLoot then
            table.insert( sharedLoot,v )
            for lsh_specFilter = 2, lsh_numSpecializations, 1 do
                local removalCounter = 1
                for _,value in pairs(specTables[lsh_specFilter]) do
                    if value == v then
                        break;
                    end
                    removalCounter = removalCounter + 1
                end
                table.remove( specTables[lsh_specFilter], removalCounter )
            end
        end
    end
    for k,v in pairs(sharedLoot) do
        local removalCounter = 1
        for _,value in pairs(specTables[1]) do
            if value == v then
                break;
            end
            removalCounter = removalCounter + 1
        end
        table.remove( specTables[1], removalCounter )
    end
    C_Timer.After(0.2, function()
        if EncounterJournal ~= nil then
            lsh_On()
        end
        C_Timer.After(0.2, function()
            displaySpecLoot(specTables, sharedLoot, "raid")
        end)
    end)
end --determine drops function


function checkTarget()
    if disabled == true then
        return
    end

    local targetsName = UnitName("target")
    
    if mostRecentBoss ~= nil then
        -- chamber bosses
        if targetsName == "Essence of Shadow" then
            targetsName = "Shadowflame Amalgamation"
        elseif targetsName == "Eternal Blaze" then
            targetsName = "Shadowflame Amalgamation"
            --experiments bosses
        elseif targetsName == "Rionthus" then
            targetsName = "Thadrion"
        elseif targetsName == "Neldris" then
            targetsName = "Thadrion"
        end

        if mostRecentBoss == targetsName then
            return
        end
    end
    if globalSpecLootsFrame ~= nil then
        globalSpecLootsFrame:Release()
    end
    currentRaidifficulty = GetDifficultyInfo(GetRaidDifficultyID())
    if currentRaidifficulty == "Looking For Raid" then
        currentRaidifficulty = "Lfr"
    end

    local needFromBoss = false;
    local targetEncounterId = nil;
    if targetsName ~= nil then
        print("target is " .. targetsName)
    end
    for k,v in pairs(targetedItemsRaid) do
        local compareName = v["boss"]

        if (compareName == "The Vigilant Steward, Zskarn") then
            compareName = "Zskarn";
        elseif (compareName == "Assault of the Zaqali") then
            compareName = "Warlord Kagni";
        elseif (compareName == "Kazzara, the Hellforged") then
            compareName = "Kazzara, the Hellforged";
        elseif (compareName == "The Amalgamation Chamber") then
            compareName = "Shadowflame Amalgamation";
        elseif (compareName == "The Forgotten Experiments") then
            compareName = "Thadrion";
        elseif (compareName == "Rashok, the Elder") then
            compareName = "Rashok";
        elseif (compareName == "Echo of Neltharion") then
            compareName = "Neltharion";
        end
        if (v["difficulty"] == currentRaidifficulty) then
            if (compareName == targetsName) then
                needFromBoss = true;
                targetEncounterId = v["encounterId"];
                break;
            else
            end
        else
        end
    end
    if needFromBoss then
        mostRecentBoss = targetsName;
        determineDropsForLootSpecs(targetEncounterId)
    else
        print("dont need")
    end
end

--resolved tooltip errors in raid popup that showed wrong ilvl in tooltip
--resolved text in raid popup that showed no difficulty for a targeted item if it was shared spec
--resolved issue with lfr that caused loot to not show up properly
--resolved bug with some items not showing in shared loot but in all loot specs
--added button to bottom of shared loot section so that entire frame was scrollable and not cutoff if the loot extended past the bottom due to a weird Ace3 bug
--
