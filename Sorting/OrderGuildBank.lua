function Baganator.Sorting.ApplyGuildOrdering(tabData, tabIndex, isReverse)
  if InCombatLockdown() then -- Sorting breaks during combat due to Blizzard restrictions
    return Baganator.Constants.SortStatus.Complete
  end

  if Syndicator.API.IsGuildEventPending() then
    return Baganator.Constants.SortStatus.WaitingMove
  end

  local showTimers = Baganator.Config.Get(Baganator.Config.Options.DEBUG_TIMERS)
  local start = debugprofilestop()

  local oneList = {}
  for index, item in ipairs(tabData) do
    local newItem = CopyTable(item)
    item.from = {tabIndex = tabIndex, slotID = index}
    table.insert(oneList, item)
  end

  if Baganator.Config.Get(Baganator.Config.Options.SORT_START_AT_BOTTOM) then
    isReverse = not isReverse
  end

  Baganator.Sorting.AddSortKeys(oneList)

  local sortedItems, incomplete = Baganator.Sorting.OrderOneListOffline(oneList, Baganator.Config.Get("sort_method"))

  if showTimers then
    print("sort initial", debugprofilestop() - start)
    start = debugprofilestop()
  end

  local moved, locked = false, false
  for newSlotID, item in ipairs(sortedItems) do
    if item.from.slotID ~= newSlotID then
      print("not fine")
      local _, _, locked1, _, _ = GetGuildBankItemInfo(tabIndex, item.from.slotID)
      local _, _, locked2, _, _ = GetGuildBankItemInfo(tabIndex, newSlotID)
      if locked1 or locked2 then
        locked = true
      else
        PickupGuildBankItem(tabIndex, item.from.slotID)
        PickupGuildBankItem(tabIndex, newSlotID)
        moved = true
        break
      end
      ClearCursor()
    end
  end

  local pending
  if incomplete then
    pending = Baganator.Constants.SortStatus.WaitingItemData
  elseif moved then
    pending = Baganator.Constants.SortStatus.WaitingMove
  elseif locked then
    pending = Baganator.Constants.SortStatus.WaitingUnlock
  else
    pending = Baganator.Constants.SortStatus.Complete
  end

  if showTimers then
    print("sort items moved", debugprofilestop() - start)
  end

  return pending
end

