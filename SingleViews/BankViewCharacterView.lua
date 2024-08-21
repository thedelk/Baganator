local _, addonTable = ...
BaganatorSingleViewBankViewCharacterViewMixin = CreateFromMixins(BaganatorItemViewCommonBankViewCharacterViewMixin)

function BaganatorSingleViewBankViewCharacterViewMixin:OnLoad()
  BaganatorItemViewCommonBankViewCharacterViewMixin.OnLoad(self)

  self.unallocatedItemButtonPool = addonTable.ItemViewCommon.GetLiveItemButtonPool(self)
  self.CollapsingBagSectionsPool = addonTable.SingleViews.GetCollapsingBagSectionsPool(self)
  self.CollapsingBankBags = {}
  self.bagDetailsForComparison = {}

  addonTable.CallbackRegistry:RegisterCallback("ContentRefreshRequired",  function()
    for _, layout in ipairs(self.Layouts) do
      layout:RequestContentRefresh()
    end
    if self:IsVisible() and self.lastCharacter ~= nil then
      self:GetParent():UpdateView()
    end
  end)

  addonTable.CallbackRegistry:RegisterCallback("SpecialBagToggled", function(_, character)
    if self:IsVisible() and self.lastCharacter ~= nil then
      self:GetParent():UpdateView()
    end
  end)
end

function BaganatorSingleViewBankViewCharacterViewMixin:ApplySearch(text)
  if not self:IsVisible() then
    return
  end

  if self.BankLive:IsShown() then
    self.BankLive:ApplySearch(text)
    for _, layouts in ipairs(self.CollapsingBankBags) do
      layouts.live:ApplySearch(text)
    end
  elseif self.BankCached:IsShown() then
    self.BankCached:ApplySearch(text)
    for _, layouts in ipairs(self.CollapsingBankBags) do
      layouts.cached:ApplySearch(text)
    end
  end
end

function BaganatorSingleViewBankViewCharacterViewMixin:AllocateBankBags(character)
  -- Copied from SingleViews/BagView.lua
  local newDetails = addonTable.SingleViews.GetCollapsingBagDetails(character, "bank", Syndicator.Constants.AllBankIndexes, Syndicator.Constants.BankBagSlotsCount)
  if self.bagDetailsForComparison.bank == nil or not tCompare(self.bagDetailsForComparison.bank, newDetails, 15) then
    self.bagDetailsForComparison.bank = CopyTable(newDetails)
    self.CollapsingBankBags = addonTable.SingleViews.AllocateCollapsingSections(
      character, "bank", Syndicator.Constants.AllBankIndexes,
      newDetails, self.CollapsingBankBags,
      self.CollapsingBagSectionsPool, self.unallocatedItemButtonPool,
      function() self:UpdateForCharacter(self.lastCharacter, self.isLive) end)
    self.lastBankBagDetails = newDetails
  end
end

function BaganatorSingleViewBankViewCharacterViewMixin:GetSearchMatches()
  local matches = {}
  tAppendAll(matches, self.BankLive.SearchMonitor:GetMatches())
  for _, layouts in ipairs(self.CollapsingBankBags) do
    tAppendAll(matches, layouts.live.SearchMonitor:GetMatches())
  end
  return matches
end

function BaganatorSingleViewBankViewCharacterViewMixin:NotifyBagUpdate(updatedBags)
  self.BankLive:MarkBagsPending("bank", updatedBags)

  for _, bagGroup in ipairs(self.CollapsingBankBags) do
    bagGroup.live:MarkBagsPending("bank", updatedBags)
  end

  -- Update cached views with current items when bank closed or on login
  if self.isLive == nil or self.isLive == true then
    for _, bagGroup in ipairs(self.CollapsingBankBags) do
      bagGroup.cached:MarkBagsPending("bank", updatedBags)
    end
    self.BankCached:MarkBagsPending("bank", updatedBags)
  end
end

function BaganatorSingleViewBankViewCharacterViewMixin:UpdateForCharacter(character, isLive)
  BaganatorItemViewCommonBankViewCharacterViewMixin.UpdateForCharacter(self, character, isLive)
  if self.lastCharacter ~= character then
    return
  end

  self:AllocateBankBags(character)

  self.BankLive:SetShown(self.isLive)
  self.BankCached:SetShown(not self.isLive)

  for _, layouts in ipairs(self.CollapsingBankBags) do
    layouts.live:SetShown(self.isLive)
    layouts.cached:SetShown(not self.isLive)
  end

  local activeBank, activeBankBagCollapsibles = nil, {}

  if self.BankLive:IsShown() then
    activeBank = self.BankLive
    for _, layouts in ipairs(self.CollapsingBankBags) do
      table.insert(activeBankBagCollapsibles, layouts.live)
    end
  else
    activeBank = self.BankCached
    for _, layouts in ipairs(self.CollapsingBankBags) do
      table.insert(activeBankBagCollapsibles, layouts.cached)
    end
  end

  local bankWidth = addonTable.Config.Get(addonTable.Config.Options.BANK_VIEW_WIDTH)

  local characterData = Syndicator.API.GetCharacter(character) 
  local bagData = characterData and characterData.bank

  activeBank:ShowBags(bagData, character, Syndicator.Constants.AllBankIndexes, self.lastBankBagDetails.mainIndexesToUse, bankWidth)

  for index, layout in ipairs(activeBankBagCollapsibles) do
    layout:ShowBags(bagData, character, Syndicator.Constants.AllBankIndexes, self.CollapsingBankBags[index].indexesToUse, bankWidth)
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

  -- Copied from SingleViews/BagView.lua
  bankHeight = bankHeight + addonTable.SingleViews.ArrangeCollapsibles(activeBankBagCollapsibles, activeBank, self.CollapsingBankBags)

  self:GetParent().AllButtons = {}
  tAppendAll(self:GetParent().AllButtons, self:GetParent().AllFixedButtons)
  tAppendAll(self:GetParent().AllButtons, self.TopButtons)

  local lastButton = nil
  for index, layout in ipairs(activeBankBagCollapsibles) do
    local button = self.CollapsingBankBags[index].button
    button:SetShown(layout:GetHeight() > 0)
    if button:IsShown() then
      button:ClearAllPoints()
      if lastButton then
        button:SetPoint("LEFT", lastButton, "RIGHT", 5, 0)
      else
        button:SetPoint("BOTTOM", self, "BOTTOM", 0, 6)
        button:SetPoint("LEFT", activeBank, -2, 0)
      end
      table.insert(self:GetParent().AllButtons, button)
      lastButton = button
    end
  end

  if self.BuyReagentBankButton:IsShown() then
    table.insert(self:GetParent().AllButtons, self.BuyReagentBankButton)
    self.BuyReagentBankButton:ClearAllPoints()
    if lastButton then
      self.BuyReagentBankButton:SetPoint("TOPLEFT", lastButton, "TOPRIGHT", 5, 0)
    else
      self.BuyReagentBankButton:SetPoint("LEFT", activeBank, -2, 0)
      self.BuyReagentBankButton:SetPoint("BOTTOM", 0, 6)
    end
  end
  if self.DepositIntoReagentsBankButton:IsShown() then
    table.insert(self:GetParent().AllButtons, self.DepositIntoReagentsBankButton)
    self.DepositIntoReagentsBankButton:ClearAllPoints()
    self.DepositIntoReagentsBankButton:SetPoint("TOPLEFT", lastButton, "TOPRIGHT", 5, 0)
  end

  activeBank:ClearAllPoints()
  activeBank:SetPoint("TOPLEFT", sideSpacing + addonTable.Constants.ButtonFrameOffset - 2, - 50 - topSpacing / 4)

  addonTable.CallbackRegistry:TriggerEvent("ViewComplete")

  self:SetSize(
    activeBank:GetWidth() + sideSpacing * 2 + addonTable.Constants.ButtonFrameOffset - 2,
    bankHeight + 75
  )

  self:GetParent():OnTabFinished()

  self.CurrencyWidget:UpdateCurrencyTextVisibility(lastButton and lastButton:GetRight() - self:GetLeft() + 10 or sideSpacing + addonTable.Constants.ButtonFrameOffset)
end
