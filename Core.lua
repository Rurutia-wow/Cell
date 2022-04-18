local addonName, Cell = ...
_G.Cell = Cell
Cell.defaults = {}
Cell.frames = {}
Cell.vars = {}
Cell.funcs = {}
Cell.iFuncs = {}
Cell.animations = {}

local F = Cell.funcs
local I = Cell.iFuncs
local P = Cell.pixelPerfectFuncs
local L = Cell.L

-- sharing version check
Cell.MIN_VERSION = 95
Cell.MIN_LAYOUTS_VERSION = 87
Cell.MIN_INDICATORS_VERSION = 95
Cell.MIN_DEBUFFS_VERSION = 78

--@debug@
local debugMode = true
--@end-debug@
function F:Debug(arg, ...)
	if debugMode then
		if type(arg) == "string" or type(arg) == "number" then
			print(arg, ...)
		elseif type(arg) == "function" then
			arg(...)
		elseif arg == nil then
			return true
		end
	end
end

function F:Print(msg)
	print("|cFFFF3030[Cell]|r " .. msg)
end

local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitGUID = UnitGUID
-- local IsInBattleGround = C_PvP.IsBattleground -- NOTE: can't get valid value immediately after PLAYER_ENTERING_WORLD

-------------------------------------------------
-- fonts -- used by old versions only
-------------------------------------------------
local font_name = CreateFont("CELL_FONT_NAME")
font_name:SetFont(GameFontNormal:GetFont(), 13)

local font_status = CreateFont("CELL_FONT_STATUS")
font_status:SetFont(GameFontNormal:GetFont(), 11)

-------------------------------------------------
-- layout
-------------------------------------------------
local delayedLayoutGroupType, delayedUpdateIndicators
local delayedFrame = CreateFrame("Frame")
delayedFrame:SetScript("OnEvent", function()
    delayedFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    F:UpdateLayout(delayedLayoutGroupType, delayedUpdateIndicators)
end)

function F:UpdateLayout(layoutGroupType, updateIndicators)
    if InCombatLockdown() then
        F:Debug("|cFF7CFC00F:UpdateLayout(\""..layoutGroupType.."\") DELAYED")
        delayedLayoutGroupType, delayedUpdateIndicators = layoutGroupType, updateIndicators
        delayedFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        F:Debug("|cFF7CFC00F:UpdateLayout(\""..layoutGroupType.."\")")
        -- Cell.vars.layoutGroupType = layoutGroupType
        local layout = CellDB["layoutAutoSwitch"][Cell.vars.playerSpecRole][layoutGroupType]
        Cell.vars.currentLayout = layout
        Cell.vars.currentLayoutTable = CellDB["layouts"][layout]
        Cell:Fire("UpdateLayout", Cell.vars.currentLayout)
        if updateIndicators then
            Cell:Fire("UpdateIndicators")
        end
    end
end

local bgMaxPlayers = {
    [2197] = 40, -- 科尔拉克的复仇
}

-- layout auto switch
local instanceType
local function PreUpdateLayout()
    if not Cell.vars.playerSpecRole then return end

    if instanceType == "pvp" then
        local name, _, _, _, _, _, _, id = GetInstanceInfo()
        if bgMaxPlayers[id] then
            if bgMaxPlayers[id] <= 15 then
                Cell.vars.inBattleground = 15
                F:UpdateLayout("battleground15", true)
            else
                Cell.vars.inBattleground = 40
                F:UpdateLayout("battleground40", true)
            end
        else
            Cell.vars.inBattleground = 15
            F:UpdateLayout("battleground15", true)
        end
    elseif instanceType == "arena" then
        Cell.vars.inBattleground = 5 -- treat as bg 5
        F:UpdateLayout("arena", true)
    else
        Cell.vars.inBattleground = false
        if Cell.vars.groupType == "solo" or Cell.vars.groupType == "party" then
            F:UpdateLayout("party", true)
        else -- raid
            if Cell.vars.inMythic then
                F:UpdateLayout("mythic", true)
            else
                F:UpdateLayout("raid", true)
            end
        end
    end
end
Cell:RegisterCallback("GroupTypeChanged", "Core_GroupTypeChanged", PreUpdateLayout)
Cell:RegisterCallback("RoleChanged", "Core_RoleChanged", PreUpdateLayout)

-------------------------------------------------
-- events
-------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

-- local cellLoaded, omnicdLoaded
function eventFrame:ADDON_LOADED(arg1)
    if arg1 == addonName then
        -- cellLoaded = true
        eventFrame:UnregisterEvent("ADDON_LOADED")
        
        if type(CellDB) ~= "table" then CellDB = {} end

        if type(CellDB["indicatorPreviewAlpha"]) ~= "number" then CellDB["indicatorPreviewAlpha"] = 0.5 end

        if type(CellDB["customTextures"]) ~= "table" then CellDB["customTextures"] = {} end

        -- general --------------------------------------------------------------------------------
        if type(CellDB["general"]) ~= "table" then
            CellDB["general"] = {
                ["enableTooltips"] = false,
                ["hideTooltipsInCombat"] = true,
                -- ["enableAurasTooltips"] = false,
                ["tooltipsPosition"] = {"BOTTOMLEFT", "Default", "TOPLEFT", 0, 15},
                ["showSolo"] = true,
                ["showParty"] = true,
                ["showPartyPets"] = true,
                ["hideBlizzard"] = true,
                ["locked"] = false,
                ["fadeOut"] = false,
                ["menuPosition"] = "top_bottom",
                ["sortPartyByRole"] = false,
            }
        end

        -- tools ----------------------------------------------------------------------------------
        if type(CellDB["tools"]) ~= "table" then
            CellDB["tools"] = {
                ["showBattleRes"] = true,
                ["buffTracker"] = {false, {}},
                ["deathReport"] = {false, 10},
                ["readyAndPull"] = {false, {"default", 7}, {}},
                ["marks"] = {false, "both_h", {}},
            }
        end

        -- glows ----------------------------------------------------------------------------------
        if type(CellDB["glows"]) ~= "table" then
            local POWER_INFUSION = GetSpellInfo(10060)
            local INNERVATE = GetSpellInfo(29166)

            CellDB["glows"] = {
                ["spellRequest"] = {
                    ["enabled"] = false,
                    ["checkIfExists"] = true,
                    ["knownSpellsOnly"] = true,
                    ["freeCooldownOnly"] = true,
                    ["replyCooldown"] = true,
                    ["responseType"] = "me",
                    ["timeout"] = 10,
                    -- ["replyAfterCast"] = nil,
                    ["spells"] = {
                        { 
                            ["spellId"] = 10060,
                            ["buffId"] = 10060,
                            ["keywords"] = POWER_INFUSION,
                            ["glowOptions"] = {
                                "pixel", -- [1] glow type
                                {
                                    {1,1,0,1}, -- [1] color
                                    0, -- [2] x
                                    0, -- [3] y
                                    9, -- [4] N
                                    0.25, -- [5] frequency
                                    8, -- [6] length
                                    2 -- [7] thickness
                                } -- [2] glowOptions
                            },
                            ["isBuiltIn"] = true
                        },
                        { 
                            ["spellId"] = 29166,
                            ["buffId"] = 29166,
                            ["keywords"] = INNERVATE,
                            ["glowOptions"] = {
                                "pixel", -- [1] glow type
                                {
                                    {0,1,1,1}, -- [1] color
                                    0, -- [2] x
                                    0, -- [3] y
                                    9, -- [4] N
                                    0.25, -- [5] frequency
                                    8, -- [6] length
                                    2 -- [7] thickness
                                } -- [2] glowOptions
                            },
                            ["isBuiltIn"] = true
                        },
                    }, -- [8] spells
                },
                ["dispelRequest"] = {
                    ["enabled"] = false,
                    ["dispellableByMe"] = true,
                    ["responseType"] = "all",
                    ["timeout"] = 30,
                    ["debuffs"] = {},
                    ["glowOptions"] = {
                        "shine", -- [1] glow type
                        {
                            {1,0,0.4,1}, -- [1] color
                            0, -- [2] x
                            0, -- [3] y
                            9, -- [4] N
                            0.5, -- [5] frequency
                            2, -- [6] scale
                        } -- [2] glowOptions
                    }
                },
            }
        end

        -- appearance -----------------------------------------------------------------------------
        if type(CellDB["appearance"]) ~= "table" then
            -- get recommended scale
            local pScale = P:GetPixelPerfectScale()
            local scale
            if pScale >= 0.7 then
                scale = 1
            elseif pScale >= 0.5 then
                scale = 1.4
            else
                scale = 2
            end

            CellDB["appearance"] = F:Copy(Cell.defaults.appearance)
            -- update recommended scale
            CellDB["appearance"]["scale"] = scale
        end
        P:SetRelativeScale(CellDB["appearance"]["scale"])

        -- click-casting --------------------------------------------------------------------------
        if type(CellDB["clickCastings"]) ~= "table" then CellDB["clickCastings"] = {} end
        Cell.vars.playerClass, Cell.vars.playerClassID = select(2, UnitClass("player"))

        if type(CellDB["clickCastings"][Cell.vars.playerClass]) ~= "table" then
            CellDB["clickCastings"][Cell.vars.playerClass] = {
                ["useCommon"] = true,
                ["alwaysTargeting"] = {
                    ["common"] = "disabled",
                },
                ["common"] = {
                    {"type1", "target"},
                    {"type2", "togglemenu"},
                },
            }
            -- https://wow.gamepedia.com/SpecializationID
            for sepcIndex = 1, GetNumSpecializationsForClassID(Cell.vars.playerClassID) do
                local specID = GetSpecializationInfoForClassID(Cell.vars.playerClassID, sepcIndex)
                CellDB["clickCastings"][Cell.vars.playerClass]["alwaysTargeting"][specID] = "disabled"
                CellDB["clickCastings"][Cell.vars.playerClass][specID] = {
                    {"type1", "target"},
                    {"type2", "togglemenu"},
                } 
            end
        end
        Cell.vars.clickCastingTable = CellDB["clickCastings"][Cell.vars.playerClass]

        -- layouts --------------------------------------------------------------------------------
        if type(CellDB["layouts"]) ~= "table" then
            CellDB["layouts"] = {
                ["default"] = F:Copy(Cell.defaults.layout)
            }
        end

        -- init enabled layout
        if type(CellDB["layoutAutoSwitch"]) ~= "table" then
            CellDB["layoutAutoSwitch"] = {
                ["TANK"] = {
                    ["party"] = "default",
                    ["raid"] = "default",
                    ["mythic"] = "default",
                    ["arena"] = "default",
                    ["battleground15"] = "default",
                    ["battleground40"] = "default",
                },
                ["HEALER"] = {
                    ["party"] = "default",
                    ["raid"] = "default",
                    ["mythic"] = "default",
                    ["arena"] = "default",
                    ["battleground15"] = "default",
                    ["battleground40"] = "default",
                },
                ["DAMAGER"] = {
                    ["party"] = "default",
                    ["raid"] = "default",
                    ["mythic"] = "default",
                    ["arena"] = "default",
                    ["battleground15"] = "default",
                    ["battleground40"] = "default",
                },
            }
        end

        -- validate layout
        for role, t in pairs(CellDB["layoutAutoSwitch"]) do
            for groupType, layout in pairs(t) do
                if not CellDB["layouts"][layout] then
                    CellDB["layoutAutoSwitch"][role][groupType] = "default"
                end
            end
        end

        -- debuffBlacklist ------------------------------------------------------------------------
        if type(CellDB["debuffBlacklist"]) ~= "table" then
            CellDB["debuffBlacklist"] = I:GetDefaultDebuffBlacklist()
        end
        Cell.vars.debuffBlacklist = F:ConvertTable(CellDB["debuffBlacklist"])
        
        -- raid debuffs ---------------------------------------------------------------------------
        if type(CellDB["raidDebuffs"]) ~= "table" then CellDB["raidDebuffs"] = {} end
        -- CellDB["raidDebuffs"] = {
        --     [instanceId] = {
        --         ["general"] = {
        --             [spellId] = {order, glowType, glowColor},
        --         },
        --         [bossId] = {
        --             [spellId] = {order, glowType, glowColor},
        --         },
        --     }
        -- }
        
        -- misc ---------------------------------------------------------------------------------
        Cell.version = GetAddOnMetadata(addonName, "version")
        Cell.versionNum = tonumber(string.match(Cell.version, "%d+")) 
        if not CellDB["revise"] then CellDB["firstRun"] = true end
        F:Revise()
        F:CheckWhatsNew()
        Cell.loaded = true
    end

    -- omnicd ---------------------------------------------------------------------------------
    -- if arg1 == "OmniCD" then
    --     omnicdLoaded = true

    --     local E = OmniCD[1]
    --     tinsert(E.unitFrameData, 1, {
    --         [1] = "Cell",
    --         [2] = "CellPartyFrameMember",
    --         [3] = "unitid",
    --         [4] = 1,
    --     })

    --     local function UnitFrames()
    --         if not E.customUF.optionTable.Cell then
    --             E.customUF.optionTable.Cell = "Cell"
    --             E.customUF.optionTable.enabled.Cell = {
    --                 ["delay"] = 1,
    --                 ["frame"] = "CellPartyFrameMember",
    --                 ["unit"] = "unitid",
    --             }
    --         end
    --     end
    --     hooksecurefunc(E, "UnitFrames", UnitFrames)
    -- end

    -- if cellLoaded and omnicdLoaded then
    --     eventFrame:UnregisterEvent("ADDON_LOADED")
    -- end
end

-- Cell.vars.guids = {} -- NOTE: moved to UnitButton.lua OnShow/OnHide
Cell.vars.role = {["TANK"]=0, ["HEALER"]=0, ["DAMAGER"]=0}
function eventFrame:GROUP_ROSTER_UPDATE()
    -- wipe(Cell.vars.guids)
    if IsInRaid() then
        if Cell.vars.groupType ~= "raid" then
            Cell.vars.groupType = "raid"
            F:Debug("|cffffbb77GroupTypeChanged:|r raid")
            Cell:Fire("GroupTypeChanged", "raid")
        end
        -- reset raid setup
        Cell.vars.role["TANK"] = 0
        Cell.vars.role["HEALER"] = 0
        Cell.vars.role["DAMAGER"] = 0
        -- update guid & raid setup
        for i = 1, GetNumGroupMembers() do
            -- update guid
            -- local playerGUID = UnitGUID("raid"..i)
            -- if playerGUID then
            --     Cell.vars.guids[playerGUID] = "raid"..i
            -- end
            -- update raid setup
            local role = select(12, GetRaidRosterInfo(i))
            if role and Cell.vars.role[role] then
                Cell.vars.role[role] = Cell.vars.role[role] + 1
            end
        end
        -- update Cell.unitButtons.raid.units
        for i = GetNumGroupMembers()+1, 40 do
            Cell.unitButtons.raid.units["raid"..i] = nil
            _G["CellRaidFrameMember"..i] = nil
        end
        F:UpdateRaidSetup()
        -- update Cell.unitButtons.party.units
        Cell.unitButtons.party.units["player"] = nil
        Cell.unitButtons.party.units["pet"] = nil
        for i = 1, 4 do
            Cell.unitButtons.party.units["party"..i] = nil
            Cell.unitButtons.party.units["partypet"..i] = nil
        end

    elseif IsInGroup() then
        if Cell.vars.groupType ~= "party" then
            Cell.vars.groupType = "party"
            F:Debug("|cffffbb77GroupTypeChanged:|r party")
            Cell:Fire("GroupTypeChanged", "party")
        end
        -- update guid
        -- Cell.vars.guids[UnitGUID("player")] = "player"
        -- if UnitGUID("pet") then
        --     Cell.vars.guids[UnitGUID("pet")] = "pet"
        -- end
        -- for i = 1, 4 do
        --     local playerGUID = UnitGUID("party"..i)
        --     if playerGUID then
        --         Cell.vars.guids[playerGUID] = "party"..i
        --     else
        --         break
        --     end

        --     local petGUID = UnitGUID("partypet"..i)
        --     if petGUID then
        --         Cell.vars.guids[petGUID] = "partypet"..i
        --     end
        -- end
        -- update Cell.unitButtons.raid.units
        for i = 1, 40 do
            Cell.unitButtons.raid.units["raid"..i] = nil
            _G["CellRaidFrameMember"..i] = nil
        end
        -- update Cell.unitButtons.party.units
        for i = GetNumGroupMembers(), 4 do
            Cell.unitButtons.party.units["party"..i] = nil
            Cell.unitButtons.party.units["partypet"..i] = nil
        end

    else
        if Cell.vars.groupType ~= "solo" then
            Cell.vars.groupType = "solo"
            F:Debug("|cffffbb77GroupTypeChanged:|r solo")
            Cell:Fire("GroupTypeChanged", "solo")
        end
        -- update guid
        -- Cell.vars.guids[UnitGUID("player")] = "player"
        -- if UnitGUID("pet") then
        --     Cell.vars.guids[UnitGUID("pet")] = "pet"
        -- end
        -- update Cell.unitButtons.raid.units
        for i = 1, 40 do
            Cell.unitButtons.raid.units["raid"..i] = nil
            _G["CellRaidFrameMember"..i] = nil
        end
        -- update Cell.unitButtons.party.units
        Cell.unitButtons.party.units["player"] = nil
        Cell.unitButtons.party.units["pet"] = nil
        for i = 1, 4 do
            Cell.unitButtons.party.units["party"..i] = nil
            Cell.unitButtons.party.units["partypet"..i] = nil
        end
    end

    if Cell.vars.hasPermission ~= F:HasPermission() or Cell.vars.hasPartyMarkPermission ~= F:HasPermission(true) then
        Cell.vars.hasPermission = F:HasPermission()
        Cell.vars.hasPartyMarkPermission = F:HasPermission(true)
        Cell:Fire("PermissionChanged")
        F:Debug("|cffbb00bbPermissionChanged")
    end
end

-- NOTE: used to update pet in Cell.vars.guids
-- function eventFrame:UNIT_PET()
--     if not IsInRaid() then
--         eventFrame:GROUP_ROSTER_UPDATE()
--     end
-- end

local inInstance
function eventFrame:PLAYER_ENTERING_WORLD()
    -- eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    F:Debug("PLAYER_ENTERING_WORLD")
    Cell.vars.inMythic = false

    local isIn, iType = IsInInstance()
    instanceType = iType
    if isIn then
        F:Debug("|cffff1111Entered Instance:|r", iType)
        PreUpdateLayout()
        inInstance = true

        -- NOTE: delayed check mythic raid
        if Cell.vars.groupType == "raid" and iType == "raid" then
            C_Timer.After(0.5, function()
                local difficultyID, difficultyName = select(3, GetInstanceInfo()) --! can't get difficultyID, difficultyName immediately after entering an instance
                Cell.vars.inMythic = difficultyID == 16
                if Cell.vars.inMythic then
                    PreUpdateLayout()
                end
            end)
        end

    elseif inInstance then -- left insntance
        F:Debug("|cffff1111Left Instance|r")
        PreUpdateLayout()
        inInstance = false
    end

    if CellDB["firstRun"] then
        F:FirstRun()
    end
end

local prevSpec
function eventFrame:PLAYER_LOGIN()
    F:Debug("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- eventFrame:RegisterEvent("UNIT_PET")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

    Cell.vars.playerName = F:UnitName("player")
    
    --! init bgMaxPlayers
    for i = 1, GetNumBattlegroundTypes() do
        local bgName, _, _, _, _, _, bgId, maxPlayers = GetBattlegroundInfo(i)
        bgMaxPlayers[bgId] = maxPlayers
    end

    if not prevSpec then prevSpec = GetSpecialization() end
    Cell.vars.playerGUID = UnitGUID("player")
    -- update spec vars
    Cell.vars.playerSpecID, Cell.vars.playerSpecName, _, Cell.vars.playerSpecIcon, Cell.vars.playerSpecRole = GetSpecializationInfo(prevSpec)
    --! init Cell.vars.currentLayout and Cell.vars.currentLayoutTable 
    eventFrame:GROUP_ROSTER_UPDATE()
    -- update visibility
    Cell:Fire("UpdateVisibility")
    -- update sortMethod
    Cell:Fire("UpdateSortMethod")
    -- update click-castings
    Cell:Fire("UpdateClickCastings")
    -- update indicators
    -- Cell:Fire("UpdateIndicators") -- NOTE: already update in GROUP_ROSTER_UPDATE -> GroupTypeChanged -> F:UpdateLayout
    -- update texture and font
    Cell:Fire("UpdateAppearance")
    Cell:UpdateOptionsFont(CellDB["appearance"]["optionsFontSizeOffset"], CellDB["appearance"]["useGameFont"])
    -- update tools
    Cell:Fire("UpdateTools")
    -- update glows
    Cell:Fire("UpdateGlows")
    -- update raid debuff list
    Cell:Fire("UpdateRaidDebuffs")
    -- hide blizzard
    if CellDB["general"]["hideBlizzard"] then F:HideBlizzard() end
    -- lock & menu
    Cell:Fire("UpdateMenu")
    -- update pixel perfect
    Cell:Fire("UpdatePixelPerfect")
end

local forceRecheck
local checkSpecFrame = CreateFrame("Frame")
checkSpecFrame:SetScript("OnEvent", function()
    eventFrame:ACTIVE_TALENT_GROUP_CHANGED()
end)
-- PLAYER_SPECIALIZATION_CHANGED fires when level up, ACTIVE_TALENT_GROUP_CHANGED usually fire twice.
-- NOTE: ACTIVE_TALENT_GROUP_CHANGED fires before PLAYER_LOGIN, but can't GetSpecializationInfo before PLAYER_LOGIN
function eventFrame:ACTIVE_TALENT_GROUP_CHANGED()
    F:Debug("ACTIVE_TALENT_GROUP_CHANGED")
    -- not in combat & spec CHANGED
    if not InCombatLockdown() and (prevSpec and prevSpec ~= GetSpecialization() or forceRecheck) then
        prevSpec = GetSpecialization()
        -- update spec vars
        Cell.vars.playerSpecID, Cell.vars.playerSpecName, _, Cell.vars.playerSpecIcon, Cell.vars.playerSpecRole = GetSpecializationInfo(prevSpec)
        if not Cell.vars.playerSpecID then -- NOTE: when join in battleground, spec auto switched, during loading, can't get info from GetSpecializationInfo, until PLAYER_ENTERING_WORLD
            forceRecheck = true
            checkSpecFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            F:Debug("|cffffbb77RoleChanged:|r FAILED")
        else
            forceRecheck = false
            checkSpecFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
            if not CellDB["clickCastings"][Cell.vars.playerClass]["useCommon"] then
                Cell:Fire("UpdateClickCastings")
            end
            F:Debug("|cffffbb77RoleChanged:|r", Cell.vars.playerSpecRole)
            Cell:Fire("RoleChanged", Cell.vars.playerSpecRole)
        end
    end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

-------------------------------------------------
-- slash command
-------------------------------------------------
SLASH_CELL1 = "/cell"
function SlashCmdList.CELL(msg, editbox)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    if command == "options" or command == "opt" then
        F:ShowOptionsFrame()

    elseif command == "reset" then
        if rest == "position" then
            Cell.frames.anchorFrame:ClearAllPoints()
            Cell.frames.anchorFrame:SetPoint("TOPLEFT", UIParent, "CENTER")
            Cell.vars.currentLayoutTable["position"] = {}
            Cell.frames.readyAndPullFrame:ClearAllPoints()
            Cell.frames.readyAndPullFrame:SetPoint("TOPRIGHT", UIParent, "CENTER")
            CellDB["tools"]["readyAndPull"][3] = {}
            Cell.frames.raidMarksFrame:ClearAllPoints()
            Cell.frames.raidMarksFrame:SetPoint("BOTTOMRIGHT", UIParent, "CENTER")
            CellDB["tools"]["marks"][3] = {}

        elseif rest == "all" then
            Cell.frames.anchorFrame:ClearAllPoints()
            Cell.frames.anchorFrame:SetPoint("TOPLEFT", UIParent, "CENTER")
            Cell.frames.readyAndPullFrame:ClearAllPoints()
            Cell.frames.readyAndPullFrame:SetPoint("TOPRIGHT", UIParent, "CENTER")
            Cell.frames.raidMarksFrame:ClearAllPoints()
            Cell.frames.raidMarksFrame:SetPoint("BOTTOMRIGHT", UIParent, "CENTER")
            CellDB = nil
            ReloadUI()

        elseif rest == "layouts" then
            CellDB["layouts"] = nil
            ReloadUI()

        elseif rest == "raiddebuffs" then
            CellDB["raidDebuffs"] = nil
            ReloadUI()
            
        elseif rest == "clickcastings" then
            CellDB["clickCastings"] = nil
            ReloadUI()
        end

    elseif command == "report" then
        rest = tonumber(rest:format("%d"))
        if rest and rest>=0 and rest<=40 then
            if rest == 0 then
                F:Print(L["Cell will report all deaths during a raid encounter."])
            else
                F:Print(string.format(L["Cell will report first %d deaths during a raid encounter."], rest))
            end
            CellDB["tools"]["deathReport"][2] = rest
            Cell:Fire("UpdateTools", "deathReport")
        else
            F:Print(L["A 0-40 integer is required."])
        end

    else
        F:Print(L["Available slash commands"]..":\n"..
            "|cFFFFB5C5/cell options|r, |cFFFFB5C5/cell opt|r: "..L["show Cell options frame"]..".\n"..
            "|cFFFF7777"..L["These \"reset\" commands below affect all your characters in this account"]..".|r\n"..
            "|cFFFFB5C5/cell reset position|r: "..L["reset Cell position"]..".\n"..
            "|cFFFFB5C5/cell reset layouts|r: "..L["reset all Layouts and Indicators"]..".\n"..
            "|cFFFFB5C5/cell reset clickcastings|r: "..L["reset all Click-Castings"]..".\n"..
            "|cFFFFB5C5/cell reset raiddebuffs|r: "..L["reset all Raid Debuffs"]..".\n"..
            "|cFFFFB5C5/cell reset all|r: "..L["reset all Cell settings"].."."
        )
    end
end