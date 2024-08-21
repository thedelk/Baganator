local _, addonTable = ...
BaganatorItemViewCommonBankViewMixin = {}

function BaganatorItemViewCommonBankViewMixin:OnLoad()
  ButtonFrameTemplate_HidePortrait(self)
  ButtonFrameTemplate_HideButtonBar(self)
  self.Inset:Hide()

  do
    self.ScrollBox = CreateFrame("Frame", nil, UIParent, "WowScrollBox")
    self.ScrollBox:SetClampedToScreen(true)
    self.ScrollBox:Hide()
    self.ScrollChild = CreateFrame("Frame", nil, self.ScrollBox)
    self.ScrollBar = CreateFrame("EventFrame", nil, UIParent, "MinimalScrollBar")
    self.ScrollBar:SetPoint("TOPLEFT", self.ScrollBox, "TOPRIGHT", 2, -2)
    self.ScrollBar:SetPoint("BOTTOMLEFT", self.ScrollBox, "BOTTOMRIGHT", 2, 2)
    self.ScrollChild:SetPoint("TOPLEFT")
    self.ScrollChild.scrollable = true
    self:SetParent(self.ScrollChild)
    ScrollUtil.InitScrollBoxWithScrollBar(self.ScrollBox, self.ScrollBar, CreateScrollBoxLinearView())
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.ScrollBox, self.ScrollBar)
  end
  self:Show()
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT")

  self:RegisterForDrag("LeftButton")
  self.ScrollBox:SetMovable(true)
  self.ScrollBox:SetUserPlaced(false)

  self.Anchor = addonTable.ItemViewCommon.GetAnchorSetter(self, addonTable.Config.Options.BANK_ONLY_VIEW_POSITION)

  self.tabPool = addonTable.ItemViewCommon.GetTabButtonPool(self)

  self.Tabs = {}

  self.Character = CreateFrame("Frame", nil, self, self.characterTemplate)
  self.Character:SetPoint("TOPLEFT")
  self:InitializeWarband(self.warbandTemplate)

  self.currentTab = self.Character

  Syndicator.CallbackRegistry:RegisterCallback("BagCacheUpdate",  function(_, character, updatedBags)
    self.hasCharacter = true
  end)

  addonTable.CallbackRegistry:RegisterCallback("SettingChanged",  function(_, settingName)
    if tIndexOf(addonTable.Config.VisualsFrameOnlySettings, settingName) ~= nil then
      if self:IsShown() then
        addonTable.Utilities.ApplyVisuals(self)
      end
    end
  end)

  self.confirmTransferAllDialogName = "addonTable.ConfirmTransferAll_" .. self:GetName()
  StaticPopupDialogs[self.confirmTransferAllDialogName] = {
    text = BAGANATOR_L_CONFIRM_TRANSFER_ALL_ITEMS_FROM_BANK,
    button1 = YES,
    button2 = NO,
    OnAccept = function()
      self.currentTab:RemoveSearchMatches(function() end)
    end,
    timeout = 0,
    hideOnEscape = 1,
  }
  self:UpdateTransferButton()

  addonTable.Skins.AddFrame("ButtonFrame", self, {"bank"})
end

function BaganatorItemViewCommonBankViewMixin:InitializeWarband(template)
  if Syndicator.Constants.WarbandBankActive then
    self.Warband = CreateFrame("Frame", nil, self, template)
    self.Warband:Hide()
    self.Warband:SetPoint("TOPLEFT")

    local characterTab = self.tabPool:Acquire()
    addonTable.Skins.AddFrame("TabButton", characterTab)
    characterTab:SetText(BAGANATOR_L_CHARACTER)
    characterTab:Show()
    characterTab:SetScript("OnClick", function()
      self.currentTab:Hide()
      self.currentTab = self.Character
      self.currentTab:Show()
      PanelTemplates_SetTab(self, 1)
      self:UpdateView()
    end)

    local warbandTab = self.tabPool:Acquire()
    warbandTab:SetText(BAGANATOR_L_WARBAND)
    warbandTab:Show()
    warbandTab:SetScript("OnClick", function()
      self.currentTab:Hide()
      self.currentTab = self.Warband
      self.currentTab:Show()
      PanelTemplates_SetTab(self, 2)
      self:UpdateView()
    end)
    addonTable.Skins.AddFrame("TabButton", warbandTab)

    self.Tabs[1]:SetPoint("BOTTOM", 0, -30)
    PanelTemplates_SetNumTabs(self, #self.Tabs)
  end
end

function BaganatorItemViewCommonBankViewMixin:UpdateTransferButton()
  if not self.currentTab.isLive then
    self.TransferButton:Hide()
    return
  end

  self.TransferButton:ClearAllPoints()
  if self.SortButton:IsShown() then
    self.TransferButton:SetPoint("RIGHT", self.SortButton, "LEFT")
  else
    self.TransferButton:SetPoint("RIGHT", self.CustomiseButton, "LEFT")
  end

  self.TransferButton:Show()
end

function BaganatorItemViewCommonBankViewMixin:OnDragStart()
  if not addonTable.Config.Get(addonTable.Config.Options.LOCK_FRAMES) then
    self.ScrollBox:StartMoving()
    self.ScrollBox:SetUserPlaced(false)
  end
end

function BaganatorItemViewCommonBankViewMixin:OnDragStop()
  self.ScrollBox:StopMovingOrSizing()
  self.ScrollBox:SetUserPlaced(false)
  local oldCorner = addonTable.Config.Get(addonTable.Config.Options.BANK_ONLY_VIEW_POSITION)[1]
  addonTable.Config.Set(addonTable.Config.Options.BANK_ONLY_VIEW_POSITION, {addonTable.Utilities.ConvertAnchorToCorner(oldCorner, self.ScrollBox)})
end

function BaganatorItemViewCommonBankViewMixin:OnEvent(eventName)
  if eventName == "BANKFRAME_OPENED" then
    self:Show()
    self.ScrollBox:Show()
    self.liveBankActive = true
    if self.hasCharacter then
      self.Character:ResetToLive()
      self:UpdateView()
    end
  elseif eventName == "BANKFRAME_CLOSED" then
    self.liveBankActive = false
    self:Hide()
    self.ScrollBox:Hide()
  end
end

function BaganatorItemViewCommonBankViewMixin:OnShow()
  if Syndicator.Constants.WarbandBankActive then
    if C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.AccountBanker) then
      self.currentTab = self.Warband
      self.Warband:Show()
      self.Character:Hide()
      for _, tab in ipairs(self.Tabs) do
        tab:Hide()
      end
    else
      for _, tab in ipairs(self.Tabs) do
        tab:Show()
      end
    end
  end
  if self.Tabs[1] then
    local function Select()
      if self.currentTab == self.Character then
        PanelTemplates_SelectTab(self.Tabs[1])
      elseif self.currentTab == self.Warband then
        PanelTemplates_SelectTab(self.Tabs[2])
      end
    end
    Select()
    C_Timer.After(0, Select) -- Necessary because if the tabs were only shown this frame they won't select properly
  end
end

function BaganatorItemViewCommonBankViewMixin:OnHide(eventName)
  if C_Bank then
    C_Bank.CloseBankFrame()
  else
    CloseBankFrame()
  end

  self.ScrollBox:Hide()
  self.ScrollBar:Hide()
  addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", "")
end

function BaganatorItemViewCommonBankViewMixin:UpdateViewToCharacter(characterName)
  self.Character.lastCharacter = characterName
  if not self.Character:IsShown() then
    self.Tabs[1]:Click()
  else
    self:UpdateView()
  end
end

function BaganatorItemViewCommonBankViewMixin:UpdateViewToWarband(warbandIndex, tabIndex)
  self.Warband:SetCurrentTab(tabIndex)
  if not self.Warband:IsShown() then
    self.Tabs[2]:Click()
  else
    self:UpdateView()
  end
end

function BaganatorItemViewCommonBankViewMixin:UpdateView()
  self.start = debugprofilestop()

  self.padding = { top = 0, bottom = 0, left = 0, right = 0}

  self.padding.bottom = self.Tabs[1] and self.Tabs[1]:IsShown() and self.Tabs[1]:GetHeight() or 0

  if Syndicator.Constants.WarbandBankActive and not C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.AccountBanker) then
    self.Tabs[1]:Show()
  end

  addonTable.Utilities.ApplyVisuals(self)

  -- Copied from ItemViewCommons/BagView.lua
  local sideSpacing = 13
  if addonTable.Config.Get(addonTable.Config.Options.REDUCE_SPACING) then
    sideSpacing = 8
  end

  if self.Tabs[1] then
    self.Tabs[1]:SetPoint("LEFT", sideSpacing + addonTable.Constants.ButtonFrameOffset, 0)
  end

  self.SearchWidget:SetSpacing(sideSpacing)

  self.currentTab:UpdateView()
end


function BaganatorItemViewCommonBankViewMixin:OnTabFinished()
  self.SortButton:SetShown(self.currentTab.isLive and addonTable.Utilities.ShouldShowSortButton())
  self:UpdateTransferButton()

  self.ButtonVisibility:Update()

  self:SetSize(self.currentTab:GetSize())
  self.ScrollChild:SetSize(self.currentTab:GetSize())
  self.ScrollBox:SetSize(self:GetWidth(), math.min(self:GetHeight() + self.padding.top + self.padding.bottom + 10, UIParent:GetHeight()))
  self.ScrollBox:GetView():SetPadding((self.padding.top or 0) + 3, self.padding.bottom + 3, self.padding.left, self.padding.right or 0)
  self.ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)

  if addonTable.Config.Get(addonTable.Config.Options.DEBUG_TIMERS) then
    print("bank", debugprofilestop() - self.start)
  end
end

function BaganatorItemViewCommonBankViewMixin:Transfer()
  if self.SearchWidget.SearchBox:GetText() == "" then
    StaticPopup_Show(self.confirmTransferAllDialogName)
  else
    self.currentTab:RemoveSearchMatches()
  end
end

function BaganatorItemViewCommonBankViewMixin:GetExternalSortMethodName()
  return addonTable.Utilities.GetExternalSortMethodName()
end
