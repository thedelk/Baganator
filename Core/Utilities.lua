local _, addonTable = ...
function addonTable.Utilities.Message(text)
  print(LINK_FONT_COLOR:WrapTextInColorCode("Baganator") .. ": " .. text)
end

do
  local callbacksPending = {}
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:SetScript("OnEvent", function(self, eventName, addonName)
    if callbacksPending[addonName] then
      for _, cb in ipairs(callbacksPending[addonName]) do
        xpcall(cb, CallErrorHandler)
      end
      callbacksPending[addonName] = nil
    end
  end)

  local AddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

  -- Necessary because cannot nest EventUtil.ContinueOnAddOnLoaded
  function addonTable.Utilities.OnAddonLoaded(addonName, callback)
    if select(2, AddOnLoaded(addonName)) then
      xpcall(callback, CallErrorHandler)
    else
      callbacksPending[addonName] = callbacksPending[addonName] or {}
      table.insert(callbacksPending[addonName], callback)
    end
  end
end

function addonTable.Utilities.GetCharacterFullName()
  local characterName, realm = UnitFullName("player")
  return characterName .. "-" .. realm
end

local queue = {}
local reporter = CreateFrame("Frame")
reporter:SetScript("OnUpdate", function()
  if #queue > 0 then
    for _, entry in ipairs(queue) do
      print(entry[1], entry[2])
    end
    queue = {}
  end
end)
function addonTable.Utilities.DebugOutput(label, value)
  table.insert(queue, {label, value})
end

local pendingItems = {}
local itemFrame = CreateFrame("Frame")
itemFrame.elapsed = 0
itemFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
itemFrame:SetScript("OnEvent", function(_, _, itemID)
  if pendingItems[itemID] ~= nil then
    for _, callback in ipairs(pendingItems[itemID]) do
      callback()
    end
    pendingItems[itemID] = nil
  end
end)
itemFrame.OnUpdate = function(self, elapsed)
  itemFrame.elapsed = itemFrame.elapsed + elapsed
  if itemFrame.elapsed > 0.4 then
    for itemID in pairs(pendingItems) do
      C_Item.RequestLoadItemDataByID(itemID)
    end
    itemFrame.elapsed = 0
  end

  if next(pendingItems) == nil then
    self:SetScript("OnUpdate", nil)
  end
end

function addonTable.Utilities.LoadItemData(itemID, callback)
  pendingItems[itemID] = pendingItems[itemID] or {}
  table.insert(pendingItems[itemID], callback)
  C_Item.RequestLoadItemDataByID(itemID)
  itemFrame:SetScript("OnUpdate", itemFrame.OnUpdate)
end
