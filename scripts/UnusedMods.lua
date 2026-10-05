-- UnusedMods: when a savegame starts, lists installed mods that are not actually used in any
-- savegame (no owned vehicle, placeable, hand tool or item comes from them) and writes the
-- result to the log and to modSettings/UnusedMods/unusedMods.xml.
-- Maps and mods without store items (scripts, textures, etc.) are ignored. Mods that ship
-- scripts (e.g. Precision Farming) count as used when enabled in any savegame.

UnusedMods = {}
UnusedMods.modName = g_currentModName
UnusedMods.settingsDir = g_currentModSettingsDirectory

-- file name, root element, entry element
UnusedMods.SAVE_FILES = {
    { "vehicles.xml", "vehicles", "vehicle" },
    { "placeables.xml", "placeables", "placeable" },
    { "items.xml", "items", "item" },
    { "handTools.xml", "handTools", "handTool" },
}

function UnusedMods.getUsedMods()
    local used, enabled, saves = {}, {}, 0
    local base = getUserProfileAppPath()

    for i = 1, 20 do
        local dir = string.format("%ssavegame%d/", base, i)
        if fileExists(dir .. "careerSavegame.xml") then
            saves = saves + 1

            local career = loadXMLFile("unusedModsCareer", dir .. "careerSavegame.xml")
            if career ~= nil and career ~= 0 then
                local k = 0
                while hasXMLProperty(career, string.format("careerSavegame.mod(%d)", k)) do
                    local name = getXMLString(career, string.format("careerSavegame.mod(%d)#modName", k))
                    if name ~= nil then
                        enabled[name] = true
                    end
                    k = k + 1
                end
                delete(career)
            end
            for _, def in ipairs(UnusedMods.SAVE_FILES) do
                local path = dir .. def[1]
                if fileExists(path) then
                    local xml = loadXMLFile("unusedModsSave", path)
                    if xml ~= nil and xml ~= 0 then
                        local j = 0
                        while true do
                            local key = string.format("%s.%s(%d)", def[2], def[3], j)
                            if not hasXMLProperty(xml, key) then
                                break
                            end
                            local name = getXMLString(xml, key .. "#modName")
                            if name == nil then
                                local file = getXMLString(xml, key .. "#filename")
                                name = file ~= nil and file:match("^%$moddir%$([^/]+)/") or nil
                            end
                            if name ~= nil then
                                used[name] = true
                            end
                            j = j + 1
                        end
                        delete(xml)
                    end
                end
            end
        end
    end

    return used, enabled, saves
end

function UnusedMods.getModPath(modName)
    for _, ext in ipairs({ ".zip", ".gar" }) do
        local path = g_modsDirectory .. modName .. ext
        if fileExists(path) then
            return path
        end
    end
    return g_modsDirectory .. modName .. "/"
end

function UnusedMods.getModFileName(path)
    return path:gsub("[/\\]+$", ""):match("[^/\\]+$")
end

function UnusedMods.getFileSize(path)
    if io == nil or io.open == nil then
        return nil
    end

    local file = io.open(path, "rb")
    if file == nil then
        return nil
    end

    local size = file:seek("end")
    file:close()
    return size
end

function UnusedMods:addFileSizeEntry(path, isDirectory)
    if self.modSize == nil then
        return
    end

    if isDirectory then
        getFiles(path, "addFileSizeEntry", self)
    else
        local size = UnusedMods.getFileSize(path)
        if size == nil then
            self.modSize = nil
        else
            self.modSize = self.modSize + size
        end
    end
end

function UnusedMods.getModSize(path)
    if path:sub(-1) ~= "/" then
        return UnusedMods.getFileSize(path)
    end

    local accumulator = setmetatable({ modSize = 0 }, { __index = UnusedMods })
    getFiles(path, "addFileSizeEntry", accumulator)
    return accumulator.modSize
end

function UnusedMods.formatFileSize(size)
    local units = { "B", "KB", "MB", "GB", "TB" }
    local value, unit = size, 1
    while value >= 1024 and unit < #units do
        value = value / 1024
        unit = unit + 1
    end
    return string.format("%.1f %s", value, units[unit])
end

-- Returns "map", "noStoreItems", "unreadable" or "buyable", plus whether the mod ships scripts.
function UnusedMods.classify(modName)
    local path = g_modsDirectory .. modName .. "/modDesc.xml"
    if not fileExists(path) then
        return "unreadable", false
    end

    local xml = loadXMLFile("unusedModsDesc", path)
    if xml == nil or xml == 0 then
        return "unreadable", false
    end

    local result = "buyable"
    if hasXMLProperty(xml, "modDesc.maps.map(0)") then
        result = "map"
    elseif not hasXMLProperty(xml, "modDesc.storeItems.storeItem(0)") then
        result = "noStoreItems"
    end
    local hasScripts = hasXMLProperty(xml, "modDesc.extraSourceFiles.sourceFile(0)")
    delete(xml)

    return result, hasScripts
end

function UnusedMods.run()
    local ok, err = pcall(UnusedMods.generate)
    if not ok then
        Logging.error("[UnusedMods] failed: %s", tostring(err))
    end
end

function UnusedMods.generate()
    local used, enabled, saves = UnusedMods.getUsedMods()
    local unused, checked = {}, 0
    local skipped = { map = 0, noStoreItems = 0, unreadable = 0 }
    local scriptsInUse = 0

    for _, mod in ipairs(g_modManager:getMods()) do
        if not mod.isDLC and mod.modName ~= UnusedMods.modName then
            local kind, hasScripts = UnusedMods.classify(mod.modName)
            if kind == "buyable" then
                checked = checked + 1
                local inUse = used[mod.modName]
                if not inUse and hasScripts and enabled[mod.modName] then
                    inUse = true
                    scriptsInUse = scriptsInUse + 1
                end
                if not inUse then
                    local path = UnusedMods.getModPath(mod.modName)
                    local size = UnusedMods.getModSize(path)
                    table.insert(unused, {
                        name = mod.modName,
                        title = mod.title or "",
                        path = UnusedMods.getModFileName(path),
                        size = size
                    })
                end
            else
                skipped[kind] = skipped[kind] + 1
            end
        end
    end
    table.sort(unused, function(a, b) return a.name:lower() < b.name:lower() end)

    Logging.info("[UnusedMods] %d of %d buyable mods are unused across %d savegames (ignored: %d maps, %d without store items, %d unreadable; %d script mods counted as used because they are enabled; mods folder: %s)",
        #unused, checked, saves, skipped.map, skipped.noStoreItems, skipped.unreadable, scriptsInUse, g_modsDirectory)
    for _, m in ipairs(unused) do
        if m.size == nil then
            Logging.warning("[UnusedMods] could not determine the size of %s", m.name)
        end
        Logging.info("[UnusedMods]   %s (%s) - %s [%s]", m.name, m.title, m.path,
            m.size ~= nil and UnusedMods.formatFileSize(m.size) or "size unknown")
    end

    local dir = UnusedMods.settingsDir or (getUserProfileAppPath() .. "modSettings/" .. UnusedMods.modName .. "/")
    createFolder(getUserProfileAppPath() .. "modSettings/")
    createFolder(dir)
    local file = dir .. "unusedMods.xml"
    local xml = createXMLFile("unusedModsOut", file, "unusedMods")
    setXMLString(xml, "unusedMods#modsPath", g_modsDirectory)
    setXMLInt(xml, "unusedMods#savegames", saves)
    setXMLInt(xml, "unusedMods#checked", checked)
    setXMLInt(xml, "unusedMods#unused", #unused)
    setXMLInt(xml, "unusedMods#ignoredMaps", skipped.map)
    setXMLInt(xml, "unusedMods#ignoredNoStoreItems", skipped.noStoreItems)
    setXMLInt(xml, "unusedMods#ignoredUnreadable", skipped.unreadable)
    setXMLInt(xml, "unusedMods#scriptModsInUse", scriptsInUse)
    for i, m in ipairs(unused) do
        local key = string.format("unusedMods.mod(%d)", i - 1)
        setXMLString(xml, key .. "#name", m.name)
        setXMLString(xml, key .. "#title", m.title)
        setXMLString(xml, key .. "#path", m.path)
        if m.size ~= nil then
            setXMLString(xml, key .. "#sizeBytes", tostring(m.size))
        end
    end
    saveXMLFile(xml)
    delete(xml)
    Logging.info("[UnusedMods] wrote %s", file)
end

FSBaseMission.onStartMission = Utils.appendedFunction(FSBaseMission.onStartMission, UnusedMods.run)
