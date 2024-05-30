local function SetupBackpackView()
  local backpackView
  local allBackpackViews = {
    single = CreateFrame("Frame", "Baganator_SingleViewBackpackViewFrame", UIParent, "BaganatorSingleViewBackpackViewTemplate"),
    category = CreateFrame("Frame", "Baganator_CategoryViewBackpackViewFrame", UIParent, "BaganatorCategoryViewBackpackViewTemplate"),
  }

  function Baganator.ViewManagement.GetBackpackFrame()
    return backpackView
  end

  backpackView = allBackpackViews[Baganator.Config.Get(Baganator.Config.Options.VIEW_TYPE)]

  local bagButtons = {}

  local UpdateButtons
  if Baganator.Constants.IsClassic then
    UpdateButtons = function()
      for _, b in ipairs(bagButtons) do
        b:SetChecked(backpackView:IsVisible())
      end
    end
  else
    UpdateButtons = function()
      for _, b in ipairs(bagButtons) do
        b.SlotHighlightTexture:SetShown(backpackView:IsVisible())
      end
    end
  end

  local function SetPositions()
    for _, backpackView in pairs(allBackpackViews) do
      backpackView:ClearAllPoints()
      backpackView:SetPoint(unpack(Baganator.Config.Get(Baganator.Config.Options.MAIN_VIEW_POSITION)))
    end
  end

  local function ResetPositions()
    Baganator.Config.ResetOne(Baganator.Config.Options.MAIN_VIEW_POSITION)
    SetPositions()
  end

  local success = pcall(SetPositions) -- work around broken values
  if not success then
    ResetPositions()
  end

  for _, backpackView in pairs(allBackpackViews) do
    table.insert(UISpecialFrames, backpackView:GetName())

    backpackView:HookScript("OnHide", function()
      UpdateButtons()
    end)
  end

  Baganator.CallbackRegistry:RegisterCallback("ResetFramePositions", function()
    ResetPositions()
  end)

  local lastToggleTime = 0
  local function ToggleBackpackView()
    if GetTime() == lastToggleTime then
      return
    end
    backpackView:SetShown(not backpackView:IsShown())
    if backpackView:IsVisible() then
      backpackView:UpdateForCharacter(Syndicator.API.GetCurrentCharacter(), true)
    end
    lastToggleTime = GetTime()
    UpdateButtons()
  end

  Baganator.CallbackRegistry:RegisterCallback("BagShow",  function(_, characterName)
    characterName = characterName or Syndicator.API.GetCurrentCharacter()
    backpackView:Show()
    backpackView:UpdateForCharacter(characterName, characterName == backpackView.liveCharacter)
    UpdateButtons()
  end)

  Baganator.CallbackRegistry:RegisterCallback("BagHide",  function(_)
    backpackView:Hide()
    UpdateButtons()
  end)

  Baganator.CallbackRegistry:RegisterCallback("SettingChanged", function(_, settingName)
    if settingName == Baganator.Config.Options.VIEW_TYPE then
      local isShown = backpackView:IsShown()
      backpackView:Hide()
      backpackView = allBackpackViews[Baganator.Config.Get(settingName)]
      if isShown then
        Baganator.CallbackRegistry:TriggerEvent("BagShow")
      end
      Baganator.CallbackRegistry:TriggerEvent("BackpackFrameChanged", backpackView)
    elseif settingName == Baganator.Config.Options.MAIN_VIEW_POSITION then
      SetPositions()
    end
  end)

  --Handled by OpenClose.lua
  --[[hooksecurefunc("OpenAllBags", function()
    backpackView:Show()
    backpackView:UpdateForCharacter(Syndicator.API.GetCurrentCharacter(), true)
  end)

  hooksecurefunc("CloseAllBags", function()
    backpackView:Hide()
  end)]]

  -- Backpack button
  table.insert(bagButtons, MainMenuBarBackpackButton)
  -- Bags 1-4, hookscript so that changing bags remains
  for i = 0, 3 do
    table.insert(bagButtons, _G["CharacterBag" .. i .. "Slot"])
  end
  -- Reagent bag
  if CharacterReagentBag0Slot then
    table.insert(bagButtons, CharacterReagentBag0Slot)
  end
  -- Keyring bag
  if KeyRingButton then
    table.insert(bagButtons, KeyRingButton)
  end
  for _, b in ipairs(bagButtons) do
    b:HookScript("OnClick", ToggleBackpackView)
  end

  hooksecurefunc("ToggleBackpack", function()
    local stack = debugstack()
    -- Check to ensure we're not opening when OpenClose.lua will handle the
    -- auto-open and auto-close
    if stack:match("OpenAllBags") or stack:match("CloseAllBags") then
      return
    end
    ToggleBackpackView()
  end)

  ToggleAllBags = ToggleBackpackView
end

local function SetupBankView()
  local bankView
  local allBankViews = {
    single = CreateFrame("Frame", "Baganator_SingleViewBankViewFrame", UIParent, "BaganatorSingleViewBankViewTemplate"),
    category = CreateFrame("Frame", "Baganator_CategoryViewBankViewFrame", UIParent, "BaganatorCategoryViewBankViewTemplate"),
  }

  bankView = allBankViews[Baganator.Config.Get(Baganator.Config.Options.VIEW_TYPE)]

  FrameUtil.RegisterFrameForEvents(bankView, {
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
  })

  for _, bankView in pairs(allBankViews) do
    table.insert(UISpecialFrames, bankView:GetName())
  end

  local function SetPositions()
    for key, bankView in pairs(allBankViews) do
      bankView:ClearAllPoints()
      bankView:SetPoint(unpack(Baganator.Config.Get(Baganator.Config.Options.BANK_ONLY_VIEW_POSITION)))
    end
  end

  local function ResetPositions()
    Baganator.Config.ResetOne(Baganator.Config.Options.BANK_ONLY_VIEW_POSITION)
    SetPositions()
  end

  local success = pcall(SetPositions) -- work around broken values
  if not success then
    ResetPositions()
  end

  Baganator.CallbackRegistry:RegisterCallback("ResetFramePositions", function()
    ResetPositions()
  end)

  Baganator.CallbackRegistry:RegisterCallback("BankToggle", function(_, characterName)
    characterName = characterName or Syndicator.API.GetCurrentCharacter()
    bankView:SetShown(characterName ~= bankView.Character.lastCharacter or not bankView:IsShown())
    bankView:UpdateViewToCharacter(characterName)
  end)

  Baganator.CallbackRegistry:RegisterCallback("BankShow", function(_, entity, subView)
    if type(entity) == "string" or entity == nil then -- Character bank
      local characterName = entity or Syndicator.API.GetCurrentCharacter()
      bankView:Show()
      bankView:UpdateViewToCharacter(characterName)
    elseif type(entity) == "number" then -- Warband bank
      subView = subView or 1
      bankView:Show()
      bankView:UpdateViewToWarband(entity, subView)
    end
  end)

  Baganator.CallbackRegistry:RegisterCallback("BankHide", function(_, characterName)
    bankView:Hide()
  end)

  Baganator.CallbackRegistry:RegisterCallback("SettingChanged", function(_, settingName)
    if settingName == Baganator.Config.Options.VIEW_TYPE then
      bankView:Hide()
      FrameUtil.UnregisterFrameForEvents(bankView, {
        "BANKFRAME_OPENED",
        "BANKFRAME_CLOSED",
      })
      bankView = allBankViews[Baganator.Config.Get(settingName)]
      FrameUtil.RegisterFrameForEvents(bankView, {
        "BANKFRAME_OPENED",
        "BANKFRAME_CLOSED",
      })
    elseif settingName == Baganator.Config.Options.BANK_ONLY_VIEW_POSITION then
      SetPositions()
    end
  end)
end

local function SetupGuildView()
  local guildView = CreateFrame("Frame", "Baganator_SingleViewGuildViewFrame", UIParent, "BaganatorSingleViewGuildViewTemplate")
  guildView:SetClampedToScreen(true)
  guildView:SetUserPlaced(false)

  table.insert(UISpecialFrames, guildView:GetName())

  local function SetPositions()
    guildView:HideInfoDialogs()
    guildView:ClearAllPoints()
    guildView:SetPoint(unpack(Baganator.Config.Get(Baganator.Config.Options.GUILD_VIEW_POSITION)))
  end

  local function ResetPositions()
    Baganator.Config.ResetOne(Baganator.Config.Options.GUILD_VIEW_POSITION)
    Baganator.Config.ResetOne(Baganator.Config.Options.GUILD_VIEW_DIALOG_POSITION)
    SetPositions()
  end

  local success = pcall(SetPositions) -- work around broken values
  if not success then
    ResetPositions()
  end

  Baganator.CallbackRegistry:RegisterCallback("ResetFramePositions", function()
    ResetPositions()
  end)

  Baganator.CallbackRegistry:RegisterCallback("GuildToggle", function(_, guildName)
    local guildName = guildName or Syndicator.API.GetCurrentGuild()
    guildView:SetShown(guildName ~= guildView.lastGuild or not guildView:IsShown())
    guildView:UpdateForGuild(guildName, Syndicator.API.GetCurrentGuild() == guildName and C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.GuildBanker))
  end)

  Baganator.CallbackRegistry:RegisterCallback("GuildShow",  function(_, guildName, tabIndex)
    guildName = guildName or Syndicator.API.GetCurrentGuild()
    guildView:Show()
    if tabIndex ~= nil then
      guildView:SetCurrentTab(tabIndex)
    end
    guildView:UpdateForGuild(
      guildName,
      guildName == Syndicator.API.GetCurrentGuild() and C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.GuildBanker)
    )
  end)

  Baganator.CallbackRegistry:RegisterCallback("GuildHide",  function(_, ...)
    guildView:Hide()
  end)
end

local hidden = CreateFrame("Frame")
hidden:Hide()

local function HideDefaultBackpack()
  --Retail: 1-6 are regular bags
  --Wrath: 1-5 are regular bags, 6 is keyring
  --Era: Doing 1-6 gets the right result even if it hides more frames than
  --needed
  for i = 1, 6 do
    _G["ContainerFrame" .. i]:SetParent(hidden)
  end

  if Baganator.Constants.IsRetail then
    ContainerFrameCombinedBags:SetParent(hidden)

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("VARIABLES_LOADED")
    frame:SetScript("OnEvent", function()
      -- Prevent glitchy tutorial popups that cannot be closed from showing
      -- These would ordinarily be attached to the Blizzard bag frames
      SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_HUD_REVAMP_BAG_CHANGES, true)
      SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_BAG_SLOTS_AUTHENTICATOR, true)
      SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_MOUNT_EQUIPMENT_SLOT_FRAME, true)
      SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_UPGRADEABLE_ITEM_IN_SLOT, true)
    end)
  end
end

local function HideDefaultBank()
  -- 7 to 13 are bank bags
  for i = 7, 13 do
    _G["ContainerFrame" .. i]:SetParent(hidden)
  end

  BankFrame:SetParent(hidden)
  BankFrame:SetScript("OnHide", nil)
  BankFrame:SetScript("OnShow", nil)
  BankFrame:SetScript("OnEvent", nil)
end

function Baganator.ViewManagement.Initialize()
  -- Use xpcall to so that if Blizzard reworks a component the rest of the
  -- other component initialisations won't fail

  xpcall(function()
    if Baganator.Config.Get(Baganator.Config.Options.ENABLE_BACKPACK_VIEW) then
      SetupBackpackView()
      HideDefaultBackpack()
    else
      function Baganator.ViewManagement.GetBackpackFrame()
        return nil
      end
    end
  end, CallErrorHandler)

  xpcall(function()
    if Baganator.Config.Get(Baganator.Config.Options.ENABLE_BANK_VIEW) then
      SetupBankView()
      HideDefaultBank()
    end
  end, CallErrorHandler)

  xpcall(function()
    if BackpackTokenFrame then
      local info = C_XMLUtil.GetTemplateInfo("BackpackTokenTemplate")
      local tokenWidth = info and info.width or 50
      BackpackTokenFrame:SetWidth(tokenWidth * 3) -- Support tracking up to 3 currencies
    end
  end, CallErrorHandler)

  xpcall(function()
    if not Baganator.Constants.IsEra and Baganator.Config.Get(Baganator.Config.Options.ENABLE_GUILD_VIEW) then
      SetupGuildView()
    end
  end, CallErrorHandler)
end
