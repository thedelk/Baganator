local _, addonTable = ...
BaganatorSingleViewBankViewWarbandViewMixin = CreateFromMixins(BaganatorItemViewCommonBankViewWarbandViewMixin)

function BaganatorSingleViewBankViewWarbandViewMixin:GetSearchMatches()
  if self.Container.BankTabLive:IsShown() then
    return self.Container.BankTabLive.SearchMonitor:GetMatches()
  else
    return self.Container.BankUnifiedLive.SearchMonitor:GetMatches()
  end
end

function BaganatorSingleViewBankViewWarbandViewMixin:NotifyBagUpdate(updatedBags)
  self.Container.BankTabLive:MarkTabsPending(updatedBags)
  self.Container.BankUnifiedLive:MarkBagsPending("bags", updatedBags)
end

function BaganatorSingleViewBankViewWarbandViewMixin:ShowTab(tabIndex, isLive)
  BaganatorItemViewCommonBankViewWarbandViewMixin.ShowTab(self, tabIndex, isLive)

  if self.BankMissingHint:IsShown() then
    return
  end

  self.Container.BankTabLive:SetShown(self.isLive and self.currentTab > 0)
  self.Container.BankTabCached:SetShown(not self.isLive and self.currentTab > 0)

  self.Container.BankUnifiedLive:SetShown(self.isLive and self.currentTab == 0)
  self.Container.BankUnifiedCached:SetShown(not self.isLive and self.currentTab == 0)

  local bankWidth = addonTable.Config.Get(addonTable.Config.Options.WARBAND_BANK_VIEW_WIDTH)

  local activeBank

  if self.currentTab > 0 then
    if self.Container.BankTabLive:IsShown() then
      activeBank = self.Container.BankTabLive
    else
      activeBank = self.Container.BankTabCached
    end

    activeBank:ShowTab(self.currentTab, Syndicator.Constants.AllWarbandIndexes, bankWidth)
  else
    if self.Container.BankUnifiedLive:IsShown() then
      activeBank = self.Container.BankUnifiedLive
    else
      activeBank = self.Container.BankUnifiedCached
    end

    local warbandData = Syndicator.API.GetWarband(1)
    local bagData = {}
    for _, tab in ipairs(warbandData.bank) do
      table.insert(bagData, tab.slots)
    end

    activeBank:ShowBags(bagData, 1, Syndicator.Constants.AllWarbandIndexes, nil, bankWidth * 2)
  end

  local searchText = self:GetParent().SearchWidget.SearchBox:GetText()
  self:ApplySearch(searchText)

  -- Copied from SingleViews/BagView.lua
  local sideSpacing, topSpacing = 13, 14
  if addonTable.Config.Get(addonTable.Config.Options.REDUCE_SPACING) then
    sideSpacing = 8
    topSpacing = 7
  end

  local bankHeight = activeBank:GetHeight() + topSpacing / 2

  bankHeight = bankHeight + 20

  activeBank:ClearAllPoints()
  activeBank:SetPoint("TOPLEFT", sideSpacing + addonTable.Constants.ButtonFrameOffset - 2, - 50 - topSpacing / 4)

  if self.isLive then
    bankHeight = bankHeight + 25
  end

  addonTable.CallbackRegistry:TriggerEvent("ViewComplete")

  self.Container:SetSize(activeBank:GetWidth(), bankHeight)

  self:SetSize(
    math.max(self.Container:GetWidth() + sideSpacing * 2 + addonTable.Constants.ButtonFrameOffset - 2, self:GetButtonsWidth(sideSpacing)),
    self.Container:GetHeight() + 55
  )

  self:GetParent():OnTabFinished()
end

function BaganatorSingleViewBankViewWarbandViewMixin:ApplySearch(text)
  for _, layout in ipairs(self.Container.Layouts) do
    if layout:IsShown() then
      layout:ApplySearch(text)
    end
  end
end
