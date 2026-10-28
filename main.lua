local Locations = require("locations")
local Stars = require("star sizes")

--#region Don't ask, only way for me to get all the files loaded
local game_window = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
local myGroupBox = ui.GroupBox.new(game_window)
myGroupBox.stylesheetID = id.StyleSheet.DEFAULT
myGroupBox:SetHeaderLayout(0,0,0,0,0)
myGroupBox:SetSize(256,200)
myGroupBox:SetPos(0,0,0.6,0.4)

local sprite = ui.Sprite.new(myGroupBox)
sprite:SetSize(256,200)
sprite.sprite = Plugin.resources.starpng
sprite.sprite = Plugin.resources.empty

for _, callout in ipairs(Locations) do
    if(callout.map == nil) then
        print("Missing map for callout: "..callout.name)
    else
        sprite.sprite = callout.map
    end
end
myGroupBox:DeleteAll()
myGroupBox:Destroy()
--#endregion

--#region Start of main application
local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
local MainWindow = prettyui.Window.new(parent, { title = "Shooting Star Tracker", x = 0, y = 350, width = 425, height = 450, rowBackgroundColours = { 0x24211EFF, 0x2E2825FF } })

local function OnTabChange(tabs, index, value, page)
end
local tabList = MainWindow:AddTabs({{text = "Star Info"}, {text = "Scope Info"}, {text = "Lookup"}}, { height = 375, onChange = OnTabChange })
local tab1 = tabList:GetPage(1)
local tab2 = tabList:GetPage(2)
local tab3 = tabList:GetPage(3)

--Tab 1
local tab1Text = tab1:AddText({
    text = "",
    height = 100,
    marginBottom = 5,
    y = 30,
})
--Tab 2
local tab2Text = tab2:AddText({
    text = "",
    height = 125,
    marginBottom = 5,
    y = 50,
})
--Tab 3
local tab3Text = tab3:AddText({
    text = "",
    height = 50,
    marginBottom = 5,
    y = 40,
})

--#endregion

--#region Functions

local function CheckDirection(coordFirst, coordSecond)
    if(coordFirst.x < coordSecond.x) then
        if(coordFirst.z < coordSecond.z) then
            return "southwest"
        elseif(coordFirst.z > coordSecond.z) then
            return "northwest"
        else
            return "west"
        end
    elseif(coordFirst.x > coordSecond.x) then
        if(coordFirst.z < coordSecond.z) then
            return "southeast"
        elseif(coordFirst.z > coordSecond.z) then
            return "northeast"
        else
            return "east"
        end
    else
        if(coordFirst.z < coordSecond.z) then
            return "south"
        elseif(coordFirst.z > coordSecond.z) then
            return "north"
        end
    end
    return "same position"
end
--#endregion

--#region Star Information
local shapeList = {}
local subscribed = false

local function ClearShapeList()
    if(#shapeList > 0) then
        shapeList[1]:Destroy()
        shapeList[1] = nil
    end
end
local function CreateBox(coordGrid)
    -- A basic tile shape
    local tileShape = ShapeData.new()
    -- 2x2 box
    tileShape.positions = 
    { 
    Vector3.new(-256, 1000, -256), Vector3.new(768, 1000, -256), Vector3.new(768, 1000, 768), Vector3.new(-256, 1000, 768),
    Vector3.new(-256, 0, -256), Vector3.new(768, 0, -256), Vector3.new(768, 0, 768), Vector3.new(-256, 0, 768),
    Vector3.new(-256, 1000, -256), Vector3.new(768, 1000, -256), Vector3.new(768, 1000, 768), Vector3.new(-256, 1000, 768),
    Vector3.new(-256, 0, -256), Vector3.new(768, 0, -256), Vector3.new(768, 0, 768), Vector3.new(-256, 0, 768),}
    tileShape.lines = 
    { 
    -- Edges for fill
    0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7,
    -- Thicker edges
    8, 9, 9, 10, 10, 11, 11, 8, 12, 13, 13, 14, 14, 15, 15, 12, 8, 12, 9, 13, 10, 14, 11, 15
    }
    
    -- Triangles to fill in shape
    tileShape.tris = { 0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7, 0, 4, 5, 0, 5, 1, 1, 5, 6, 1, 6, 2, 2, 6, 7, 2, 7, 3, 3, 7, 4, 3, 4, 0}
    
    tileShape.rgba = { 
    -- Color for fill
    0x00FF0027, 0x00FF0027, 0x00FF0027, 0x00FF0027, 
    0x00FF0027, 0x00FF0027, 0x00FF0027, 0x00FF0027,
    -- Color for edges
    0x00FF00AA, 0x00FF00AA, 0x00FF00AA, 0x00FF00AA, 
    0x00FF00AA, 0x00FF00AA, 0x00FF00AA, 0x00FF00AA,  }

    -- Choose a tile and convert to a position
    local instancePos = coordGrid:ToCoordFine(true).position

    -- Get the ground height at that position
    local groundHeight = World.GetGroundHeight(coordGrid.level, instancePos.x, instancePos.z)
    -- Create start and end heights for the bounce
    local startHeight = groundHeight

    -- Set the instance height
    instancePos.y = startHeight

    ClearShapeList()

    -- Create the named shape instance
    local instance = ShapeList.CreateInstance("myInstance")
    instance:SetShapeData(tileShape)
    instance.translation = instancePos
    instance.ignoreDepth = true

    -- Add to shape list so we can keep track and remove when no longer required
    shapeList[#shapeList + 1] = instance
end
local function LookUpId(configValue)
    for _, star in ipairs(Stars) do
        if star.configValue.id == configValue then
            return star
        end
    end
    return nil
end
local function SetText()
    tab1Text.content = ""

    --Read DND tracker for active star
    local infoActive = var.VarPlayer.DNDTRACKER_SHOOTING_STAR_ACTIVE
    if(infoActive.value == 1) then 
    tab1Text.content = tab1Text.content..("Is star active? Yes")
    else
    tab1Text.content = tab1Text.content..("Is star active? No")
    end

    local coordGrid = nil
    --Read local area and report nearby star
    local allLocs = LocList.ByName("*crashed star*")
    for _,locEntity in ipairs(allLocs) do
        local configEntity = LookUpId(locEntity.configID)
        if(configEntity ~= nil) then
            tab1Text.content = tab1Text.content.."<br>Current size: "..configEntity.name
            coordGrid = locEntity.coordGrid
        end
    end

    --Read local area and report nearby star sprite
    local allNpcs = NPCList.ByName("*star sprite*")
    for _,locEntity in ipairs(allNpcs) do
        local configEntity = LookUpId(locEntity.configID)
        if(configEntity ~= nil) then
            tab1Text.content = tab1Text.content.."<br>Current size: "..configEntity.name
            coordGrid = locEntity.coordGrid
        end
    end

    --No star found
    if(coordGrid == nil) then
        tab1Text.content = tab1Text.content.."<br>No star found nearby"
        return
    end
    tab1Text.content = tab1Text.content.."<br>You are "..CheckDirection(Player.GetEntity().coordGrid, coordGrid).." of the star"
    
    return coordGrid
end
local function StarInfoClick(button, active)
    if(not subscribed) then
        subscribed = true
        button:SetText("Stop searching for stars")
        Event.ServerLogic.Subscribe("StarLocatorEvent", function()
            local coordGrid = SetText()
            if(coordGrid == nil) then
                ClearShapeList()
                return
            else
                CreateBox(coordGrid)
            end
        end)
    else
        subscribed = false
        tab1Text.content = ""
        ClearShapeList()
        button:SetText("Start searching for stars")
        Event.ServerLogic.Unsubscribe("StarLocatorEvent")
    end
end

local starInfoButton = tab1:AddFancyButton("Start searching for stars", StarInfoClick, { variant = "positive" })


--#endregion

--#region Scope Information
local function ScopeInfoClick(button, active)
    tab2Text.content = ""
    local inter = ui.Interfaces:GetInterface(id.Interface.MESBOX_V2)
    if(inter == nil) then
        tab2Text.content = "No scope detected"
        return
    end

    --Reads DND tracker for next star time
    local info = var.VarPlayer.DNDTRACKER_SHOOTING_STAR_TIME
    tab2Text.content = tab2Text.content..("Time to next star: "..info.value.." minutes")

    local test = ui.Interfaces:GetComponent(id.Component.FRIENDS2__FRIENDS_TITLE)
    local stringTest = test.content
    local split = string.sub(stringTest, 27)

    --Read telescope (GENERIC WINDOW - BE AWARE IF USING WITH OTHER PLUGINS AND CONTENT)
    
    if(inter ~= nil) then
        local nameLabelID = id.Component.MESBOX_V2__MESBOX_TEXT
        if(ui.Interfaces:GetComponent(nameLabelID) ~= nil) then
            local starText = (ui.Interfaces:GetComponent(nameLabelID).content)
            if(string.find(starText, "You see a shooting star!")) then
                tab2Text.content = tab2Text.content.."<br>Star call: World "..split.."<br>"..(starText)
             end
        end
    end
end
tab2:AddFancyButton("Push for scope reading", ScopeInfoClick, { variant = "positive" })
local function ClearScopeInfoClick(button, active)
    tab2Text.content = ""
end
tab2:AddSimpleButton("Clear", ClearScopeInfoClick, {inline = true})
--#endregion

--#region Lookup Information
local sprite = tab3:AddSprite(Plugin.resources.empty, {width = 375, height = 215, y = 100})

local function FindLocationById(id)
    for _, callout in ipairs(Locations) do
        if(callout.id == id) then
            return callout
        end
    end
    return nil
end
local function FindLocationByFullName(fullName)
    for _, callout in ipairs(Locations) do
        if(callout.callout == fullName or callout.name == fullName) then
            return callout
        end
    end
    return nil
end
local function FindLocationByPartialName(partialName)
    for _, callout in ipairs(Locations) do
        if(string.find(string.lower(callout.callout), string.lower(partialName), 1, true)
        or string.find(string.lower(callout.name), string.lower(partialName), 1, true)) then
            return callout
        end
    end
    return nil
end
local function CalloutBoxChange(field, reason, text)
    local partial = false
    local callout = nil
    callout = FindLocationByFullName(text)
    if(callout == nil) then
        callout = FindLocationByPartialName(text)
        if(callout ~= nil) then
            partial = true
        end
    end
    if(text == "" or callout == nil) then
        tab3Text.content = ""
        sprite:SetSprite(Plugin.resources.empty)
        return
    end

    if(callout ~= nil) then
        if(callout.isRegion) then
            tab3Text.content = "Region: " .. callout.name
        else
            local calloutRegion = FindLocationById(callout.regionId)
            if(calloutRegion == nil) then
                print("Missing region for callout: "..callout.name)
            else
                tab3Text.content = callout.name .. " <br>(Region: " .. calloutRegion.name .. ")"
            end
        end

        if(callout.map == nil) then
            print("Missing map for callout: "..callout.name)
            sprite:SetSprite(Plugin.resources.empty)
        else
            sprite:SetSprite(callout.map)
        end
    end
end
local calloutLookup = tab3:AddTextField({ placeholder = "Look up callout", onChange = CalloutBoxChange, y = 10 })
--#endregion

MainWindow:RefreshRowBackgrounds()

function PluginShutdown()
    if(subscribed) then
        Event.ServerLogic.Unsubscribe("StarLocatorEvent")
    end
    MainWindow:Destroy()
end