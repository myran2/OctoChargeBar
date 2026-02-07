local addonName = select(1, ...)
local addon = select(2, ...)

local LEM = LibStub('LibEditMode')
local Util = addon.Util
local Data = addon.Data

local ChargeBar = {}
addon.ChargeBar = ChargeBar

---@param settings ChargeBarSettings
function ChargeBar:Init(settings)
    local newInstance = Util:TableCopy(Data.defaultBarSettings)
    setmetatable(newInstance, {__index = self})

    if not C_SpellBook.IsSpellKnown(settings.spellId) then print(settings.spellId, 'not known!') return end
    local spellName = C_Spell.GetSpellName(settings.spellId)
    assert(spellName, string.format("No spell name found for %d.", settings.spellId))

    local frameName = string.format("%s: %s", addonName, spellName)
    newInstance.spellId = settings.spellId
    newInstance.showTicks = settings.showTicks
    newInstance.tickColor = settings.tickColor
    newInstance.tickWidth = settings.tickWidth
    newInstance.enabled = settings.enabled

    newInstance.frame = newInstance.frame or CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    newInstance.frame:SetSize(settings.barWidth, settings.barHeight)
    newInstance.frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = settings.borderWidth,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    newInstance.frame:SetBackdropColor(0,0,0,0)
    newInstance.frame:SetBackdropBorderColor(Util:UnpackRGBA(settings.borderColor))
    newInstance.frame:SetSize(settings.barWidth, settings.barHeight)
    newInstance.frame:SetPoint(settings.position.point, settings.position.x, settings.position.y)

    newInstance.innerContainer = newInstance.innerContainer or CreateFrame("Frame", "innerContainer", newInstance.frame)
    newInstance.innerContainer:SetSize(settings.barWidth - (settings.borderWidth * 2), settings.barHeight - (settings.borderWidth * 2))
    newInstance.innerContainer:SetPoint("CENTER", newInstance.frame, "CENTER", 0, 0)
    newInstance.innerContainer:SetClipsChildren(true)

    newInstance.chargeFrame = newInstance.chargeFrame or CreateFrame("StatusBar", "ChargesBar", newInstance.innerContainer)
    newInstance.chargeFrame:SetPoint("CENTER", newInstance.innerContainer, "CENTER", 0, 0)
    newInstance.chargeFrame:SetSize(newInstance.innerContainer:GetWidth(), newInstance.innerContainer:GetHeight())
    newInstance.chargeFrame:SetColorFill(Util:UnpackRGBA(settings.chargeColor))

    newInstance.refreshCharge = newInstance.refreshCharge or CreateFrame("StatusBar", "RefreshCharge", newInstance.innerContainer)
    newInstance.refreshCharge:SetPoint("LEFT",newInstance.chargeFrame:GetStatusBarTexture(), "RIGHT", 0, 0)
    newInstance.refreshCharge:SetColorFill(Util:UnpackRGBA(settings.rechargeColor))

    newInstance.refreshCharge.text = newInstance.refreshCharge.text or newInstance.refreshCharge:CreateFontString("RechargeTime", "OVERLAY")
    if settings.showRechargeText then
        newInstance.refreshCharge.text:SetPoint("CENTER")
        newInstance.refreshCharge.text:SetFont(settings.rechargeTextFont, settings.rechargeTextFontSize, "OUTLINE")
        newInstance.refreshCharge:SetScript("OnUpdate", function()
            if newInstance.refreshCharge:GetTimerDuration() then
                local rechargeDuration = newInstance.refreshCharge:GetTimerDuration():GetRemainingDuration()
                newInstance.refreshCharge.text:SetFormattedText("%.1f", rechargeDuration)
            else
                newInstance.refreshCharge.text:SetText("")
            end
        end)
    else
        newInstance.refreshCharge.text:SetToDefaults()
    end

    newInstance.ticksContainer = newInstance.ticksContainer or CreateFrame("Frame", "TicksContainer", newInstance.innerContainer)
    newInstance.ticksContainer:SetPoint("CENTER")
    newInstance.ticksContainer:SetSize(newInstance.innerContainer:GetWidth(), newInstance.innerContainer:GetHeight())
    newInstance.ticksContainer.ticks = newInstance.ticksContainer.ticks or {}

    newInstance:LEMSetup()
    newInstance:SetupCharges()

    if not newInstance.enabled then
        newInstance:Hide()
    end

    return newInstance
end

-- Sets up bars based on max charges.
-- Can't be called while Secret restrictions are active!
function ChargeBar:SetupCharges()
    if not self.enabled then
        return
    end

    local spellName = C_Spell.GetSpellName(self.spellId)
    assert(spellName, string.format("No spell name found for %d.", self.spellId))

    local chargeInfo = C_Spell.GetSpellCharges(self.spellId)
    if not chargeInfo then return end

    local maxCharges = chargeInfo.maxCharges
    local currentCharges = chargeInfo.currentCharges
    local chargeWidth = self.innerContainer:GetWidth() / maxCharges
    self.chargeFrame:SetMinMaxValues(0, maxCharges)
    self.chargeFrame:SetValue(currentCharges)

    self.refreshCharge:SetSize(chargeWidth, self.innerContainer:GetHeight())
    if self.showTicks then
        -- reuse existing ticks when possible
        for i, tick in ipairs(self.ticksContainer.ticks) do
            -- can be reused
            if i <= maxCharges - 1 then
                tick:SetColorTexture(Util:UnpackRGBA(self.tickColor))
                tick:SetSize(self.tickWidth, self.ticksContainer:GetHeight())
                tick:SetPoint("CENTER", self.ticksContainer, "LEFT", chargeWidth * i, 0)
                tick:SetShown(true)
            -- hide all ticks we don't need
            else
                tick:SetToDefaults()
                tick:SetShown(false)
            end
        end

        local newTicksNeeded = (maxCharges - 1) - #self.ticksContainer.ticks
        for i = #self.ticksContainer.ticks + 1, newTicksNeeded do
            local tick = self.ticksContainer:CreateTexture(nil, "OVERLAY")
            tick:SetColorTexture(Util:UnpackRGBA(self.tickColor))
            tick:SetSize(self.tickWidth, self.ticksContainer:GetHeight())
            tick:SetPoint("CENTER", self.ticksContainer, "LEFT", chargeWidth * i, 0)
            table.insert(self.ticksContainer.ticks, tick)
        end
    end
end

function ChargeBar:Hide()
    self.frame:Hide()
end

function ChargeBar:Show()
    self.frame:Show()
end

function ChargeBar:LEMSetup()
    -- TODO: Figure out what the default position values should be.
    LEM:AddFrame(self.frame, function(frame, layoutName, point, x, y)
        print(frame:GetName(), layoutName, point, x, y)
        self:onPositionChanged(layoutName, point, x, y)
    end, {point = 'CENTER', x = 0, y = 0})

    LEM:AddFrameSettings(self.frame, {
        {
            name = 'Enabled',
            kind = LEM.SettingType.Checkbox,
            default = Data.defaultBarSettings.enabled,
            get = function(layoutName)
                return Data:GetBarSetting(layoutName, self.spellId, 'enabled')
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'enabled', value)
                self.enabled = value
            end,
        },
        {
            name = 'Bar Width',
            kind = LEM.SettingType.Slider,
            default = Data.defaultBarSettings.barWidth,
            disabled = function(layoutName)
                return not self.enabled
            end,
            get = function(layoutName)
                return Data:GetBarSetting(layoutName, self.spellId, 'barWidth')
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'barWidth', value)
                self.frame:SetWidth(value)
            end,
            minValue = 50,
            maxValue = 500,
            valueStep = 1,
        },
        {
            name = 'Bar Height',
            kind = LEM.SettingType.Slider,
            default = Data.defaultBarSettings.barHeight,
            disabled = function(layoutName)
                return not self.enabled
            end,
            get = function(layoutName)
                return Data:GetBarSetting(layoutName, self.spellId, 'barHeight')
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'barHeight', value)
                self.frame:SetHeight(value)
            end,
            minValue = 8,
            maxValue = 100,
            valueStep = 1,
        },
        {
            name = 'Charge Color',
            description = 'Color of active charges.',
            kind = LEM.SettingType.ColorPicker,
            default = CreateColor(Util:UnpackRGBA(Data.defaultBarSettings.chargeColor)),
            disabled = function(layoutName)
                return not self.enabled
            end,
            hasOpacity = true,
            get = function(layoutName)
                return CreateColor(Util:UnpackRGBA(Data:GetBarSetting(layoutName, self.spellId, 'chargeColor')))
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'chargeColor', {
                    r = value.r,
                    g = value.g,
                    b = value.b,
                    a = value.a
                })
                self.chargeFrame:SetColorFill(value:GetRGBA())
            end,
        },
        {
            name = 'Border Width',
            kind = LEM.SettingType.Slider,
            default = Data.defaultBarSettings.borderWidth,
            disabled = function(layoutName)
                return not self.enabled
            end,
            get = function(layoutName)
                return Data:GetBarSetting(layoutName, self.spellId, 'borderWidth')
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'borderWidth', value)
            end,
            minValue = 0,
            maxValue = 5,
        },
        {
            name = 'Border Color',
            kind = LEM.SettingType.ColorPicker,
            default = CreateColor(Util:UnpackRGBA(Data.defaultBarSettings.borderColor)),
            disabled = function(layoutName)
                return not self.enabled
            end,
            hasOpacity = true,
            get = function(layoutName)
                return CreateColor(Util:UnpackRGBA(Data:GetBarSetting(layoutName, self.spellId, 'borderColor')))
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'borderColor', {
                    r = value.r,
                    g = value.g,
                    b = value.b,
                    a = value.a
                })
                self.frame:SetBackdropBorderColor(value:GetRGBA())
            end,
        },
        {
            name = 'Recharge Bar Color',
            kind = LEM.SettingType.ColorPicker,
            default = CreateColor(Util:UnpackRGBA(Data.defaultBarSettings.rechargeColor)),
            disabled = function(layoutName)
                return not self.enabled
            end,
            hasOpacity = true,
            get = function(layoutName)
                return CreateColor(Util:UnpackRGBA(Data:GetBarSetting(layoutName, self.spellId, 'rechargeColor')))
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'rechargeColor', {
                    r = value.r,
                    g = value.g,
                    b = value.b,
                    a = value.a
                })
                self.refreshCharge:SetColorFill(value:GetRGBA())
            end,
        },
        {
            name = 'Show Recharge Cooldown Text',
            kind = LEM.SettingType.Checkbox,
            default = Data.defaultBarSettings.showRechargeText,
            disabled = function(layoutName)
                return not self.enabled
            end,
            get = function(layoutName)
                return Data:GetBarSetting(layoutName, self.spellId, 'showRechargeText')
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'showRechargeText', value)
                self.refreshCharge.text:SetShown(false)
            end,
        },
        {
            name = 'Recharge Cooldown Text Size',
            kind = LEM.SettingType.Slider,
            default = Data.defaultBarSettings.rechargeTextFontSize,
            disabled = function(layoutName)
                return not self.enabled
            end,
            hidden = function(layoutName)
                return Data:GetBarSetting(layoutName, self.spellId, 'rechargeTextFontSize') < 1
            end,
            get = function(layoutName)
                return Data:GetBarSetting(layoutName, self.spellId, 'rechargeTextFontSize')
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'rechargeTextFontSize', value)
                self.refreshCharge.text:SetFontHeight(value)
            end,
            -- TODO: make these related to the bar size somehow
            minValue = 6,
            maxValue = 20,
            valueStep = 1,
        },
        {
            name = 'Tick Width',
            kind = LEM.SettingType.Slider,
            default = Data.defaultBarSettings.tickWidth,
            disabled = function(layoutName)
                return not self.enabled
            end,
            get = function(layoutName)
                Data:GetBarSetting(layoutName, self.spellId, 'tickWidth')
            end,
            set = function(layoutName, value)
                Data:SetBarSetting(layoutName, self.spellId, 'tickWidth', value)
                self.tickWidth = value
            end,
            minValue = 0,
            maxValue = 5,
        },
        {
            name = 'Tick Color',
            kind = LEM.SettingType.ColorPicker,
            default = CreateColor(Util:UnpackRGBA(Data.defaultBarSettings.tickColor)),
            disabled = function(layoutName)
                return not self.enabled
            end,
            hasOpacity = true,
            get = function(layoutName)
                return CreateColor(Util:UnpackRGBA(Data:GetBarSetting(layoutName, self.spellId, 'tickColor')))
            end,
            set = function(layoutName, value)
                local color = {
                    r = value.r,
                    g = value.g,
                    b = value.b,
                    a = value.a
                }
                Data:SetBarSetting(layoutName, self.spellId, 'tickColor', color)
                self.tickColor = color
            end,
        },
    })
end

function ChargeBar:HandleSpellUpdateCharges()
    self.chargeFrame:SetValue(C_Spell.GetSpellCharges(self.spellId).currentCharges)
    self.refreshCharge:SetTimerDuration(
        C_Spell.GetSpellChargeDuration(self.spellId),
        Enum.StatusBarInterpolation.Immediate,
        Enum.StatusBarTimerDirection.ElapsedTime
    )
end

function ChargeBar:onPositionChanged(layoutName, point, x, y)
    print('onPositionChanged', self.spellId)
    Data:SetBarSetting(layoutName, self.spellId, 'position', {
        point = point,
        x = floor(x),
        y = floor(y)
    })
end
