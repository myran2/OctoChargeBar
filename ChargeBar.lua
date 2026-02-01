local addonName = select(1, ...)
local addon = select(2, ...)

local LEM = LibStub('LibEditMode')
local Util = addon.Util
local Data = addon.Data

local ChargeBar = {}
addon.ChargeBar = ChargeBar

---@param settings ChargeBarSettings
function ChargeBar:Init(settings)
    if not C_SpellBook.IsSpellKnown(settings.spellId) then print(settings.spellId, 'not known!') return end
    local spellName = C_Spell.GetSpellName(settings.spellId)
    assert(spellName, string.format("No spell name found for %d.", settings.spellId))

    local frameName = string.format("%s: %s", addonName, spellName)
    self.spellId = settings.spellId
    self.showTicks = settings.showTicks
    self.tickColor = settings.tickColor
    self.tickWidth = settings.tickWidth
    self.enabled = settings.enabled
    self.reinitRequired = false

    if not self.enabled then
        return
    end

    self.frame = self.frame or CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    self.frame:SetSize(settings.barWidth, settings.barHeight)
    self.frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = settings.borderWidth,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    self.frame:SetBackdropColor(0,0,0,0)
    self.frame:SetBackdropBorderColor(Util:UnpackRGBA(settings.borderColor))
    self.frame:SetSize(settings.barWidth, settings.barHeight)
    self.frame:SetPoint(settings.position.point, settings.position.x, settings.position.y)

    self.innerContainer = self.innerContainer or CreateFrame("Frame", "innerContainer", self.frame)
    self.innerContainer:SetSize(settings.barWidth - (settings.borderWidth * 2), settings.barHeight - (settings.borderWidth * 2))
    self.innerContainer:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    self.innerContainer:SetClipsChildren(true)

    self.chargeFrame = self.chargeFrame or CreateFrame("StatusBar", "ChargesBar", self.innerContainer)
    self.chargeFrame:SetPoint("CENTER", self.innerContainer, "CENTER", 0, 0)
    self.chargeFrame:SetSize(self.innerContainer:GetWidth(), self.innerContainer:GetHeight())
    self.chargeFrame:SetColorFill(Util:UnpackRGBA(settings.chargeColor))

    self.refreshCharge = self.refreshCharge or CreateFrame("StatusBar", "RefreshCharge", self.innerContainer)
    self.refreshCharge:SetPoint("LEFT",self.chargeFrame:GetStatusBarTexture(), "RIGHT", 0, 0)
    self.refreshCharge:SetColorFill(Util:UnpackRGBA(settings.rechargeColor))

    self.refreshCharge.text = self.refreshCharge.text or self.refreshCharge:CreateFontString("RechargeTime", "OVERLAY")
    if settings.showRechargeText then
        self.refreshCharge.text:SetPoint("CENTER")
        self.refreshCharge.text:SetFont(settings.rechargeTextFont, settings.rechargeTextFontSize, "OUTLINE")
        self.refreshCharge:SetScript("OnUpdate", function()
            if self.refreshCharge:GetTimerDuration() then
                local rechargeDuration = self.refreshCharge:GetTimerDuration():GetRemainingDuration()
                self.refreshCharge.text:SetFormattedText("%.1f", rechargeDuration)
            else
                self.refreshCharge.text:SetText("")
            end
        end)
    else
        self.refreshCharge.text:SetToDefaults()
    end

    self.ticksContainer = self.ticksContainer or CreateFrame("Frame", "TicksContainer", self.innerContainer)
    self.ticksContainer:SetPoint("CENTER")
    self.ticksContainer:SetSize(self.innerContainer:GetWidth(), self.innerContainer:GetHeight())
    self.ticksContainer.ticks = self.ticksContainer.ticks or {}

    self:LEMSetup()

    return self
end

-- Sets up bars based on max charges.
-- Can't be called while Secret restrictions are active!
function ChargeBar:Setup()
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

function ChargeBar:Disable()
    self.frame:SetToDefaults()
    self.frame:SetShown(false)
    self.enabled = false
end

function ChargeBar:LEMSetup()
    LEM:RegisterCallback('enter', function()
        self:onEnterEditMode()
    end)
    LEM:RegisterCallback('exit', function()
        self:onExitEditMode()
    end)
    LEM:RegisterCallback('layout', function(layoutName)
        self:onEditModeLayout(layoutName)
    end)

    -- TODO: Figure out what the default position values should be.
    LEM:AddFrame(self.frame, function(frame, layoutName, point, x, y)
        self:onPositionChanged(layoutName, point, x, y)
    end, {point = 'CENTER', x = 0, y = 0})

    LEM:AddFrameSettings(self.frame, {
        {
            name = 'Enabled',
            kind = LEM.SettingType.Checkbox,
            default = Data.defaultBarSettings.enabled,
            get = function(layoutName)
                return Data.db.profile.bars[1].enabled
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].enabled = value
                self.reinitRequired = self.enabled ~= value
                self.enabled = value
            end,
        },
        {
            name = 'Bar Width',
            kind = LEM.SettingType.Slider,
            default = Data.defaultBarSettings.barWidth,
            disabled = function()
                return not self.enabled
            end,
            get = function(layoutName)
                return Data.db.profile.bars[1].barWidth
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].barWidth = value
                self.reinitRequired = self.reinitRequired or self.frame:GetWidth() ~= value
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
            disabled = function()
                return not self.enabled
            end,
            get = function(layoutName)
                return Data.db.profile.bars[1].barHeight
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].barHeight = value
                self.reinitRequired = self.reinitRequired or self.frame:GetHeight() ~= value
                self.frame:SetHeight(value)
            end,
            minValue = 8,
            maxValue = 100,
            valueStep = 1,
        },
        {
            name = 'Bar Color',
            description = 'Color of active charges.',
            kind = LEM.SettingType.ColorPicker,
            default = CreateColor(Util:UnpackRGBA(Data.defaultBarSettings.chargeColor)),
            disabled = function()
                return not self.enabled
            end,
            hasOpacity = true,
            get = function(layoutName)
                return CreateColor(Util:UnpackRGBA(Data.db.profile.bars[1].chargeColor))
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].chargeColor = {
                    r = value.r,
                    g = value.g,
                    b = value.b,
                    a = value.a
                }
                self.chargeFrame:SetColorFill(value:GetRGBA())
            end,
        },
        {
            name = 'Border Width',
            kind = LEM.SettingType.Slider,
            default = Data.defaultBarSettings.borderWidth,
            disabled = function()
                return not self.enabled
            end,
            get = function(layoutName)
                return Data.db.profile.bars[1].borderWidth
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].borderWidth = value
                self.reinitRequired = self.frame:GetBackdrop().edgeSize ~= value
            end,
            minValue = 0,
            maxValue = 5,
        },
        {
            name = 'Border Color',
            kind = LEM.SettingType.ColorPicker,
            default = CreateColor(Util:UnpackRGBA(Data.defaultBarSettings.borderColor)),
            disabled = function()
                return not self.enabled
            end,
            hasOpacity = true,
            get = function(layoutName)
                return CreateColor(Util:UnpackRGBA(Data.db.profile.bars[1].borderColor))
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].borderColor = {
                    r = value.r,
                    g = value.g,
                    b = value.b,
                    a = value.a
                }
                self.frame:SetBackdropBorderColor(value:GetRGBA())
            end,
        },
        {
            name = 'Recharge Bar Color',
            kind = LEM.SettingType.ColorPicker,
            default = CreateColor(Util:UnpackRGBA(Data.defaultBarSettings.rechargeColor)),
            disabled = function()
                return not self.enabled
            end,
            hasOpacity = true,
            get = function(layoutName)
                return CreateColor(Util:UnpackRGBA(Data.db.profile.bars[1].rechargeColor))
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].rechargeColor = {
                    r = value.r,
                    g = value.g,
                    b = value.b,
                    a = value.a
                }
                self.refreshCharge:SetColorFill(value:GetRGBA())
            end,
        },
        {
            name = 'Show Recharge Cooldown Text',
            kind = LEM.SettingType.Checkbox,
            default = Data.defaultBarSettings.showRechargeText,
            disabled = function()
                return not self.enabled
            end,
            get = function(layoutName)
                return Data.db.profile.bars[1].showRechargeText
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].showRechargeText = value
                self.reinitRequired = true
            end,
        },
        {
            name = 'Recharge Cooldown Text Size',
            kind = LEM.SettingType.Slider,
            default = Data.defaultBarSettings.rechargeTextFontSize,
            disabled = function()
                return not self.enabled
            end,
            hidden = function()
                return Data.db.profile.bars[1].rechargeTextFontSize < 1
            end,
            get = function(layoutName)
                return Data.db.profile.bars[1].rechargeTextFontSize
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].rechargeTextFontSize = value
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
            disabled = function()
                return not self.enabled
            end,
            get = function(layoutName)
                return Data.db.profile.bars[1].tickWidth
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].tickWidth = value
                if not self.reinitRequired then
                    self.reinitRequired = self.tickWidth ~= value
                end
                self.tickWidth = value
            end,
            minValue = 0,
            maxValue = 5,
        },
        {
            name = 'Tick Color',
            kind = LEM.SettingType.ColorPicker,
            default = CreateColor(Util:UnpackRGBA(Data.defaultBarSettings.tickColor)),
            disabled = function()
                return not self.enabled
            end,
            hasOpacity = true,
            get = function(layoutName)
                return CreateColor(Util:UnpackRGBA(Data.db.profile.bars[1].tickColor))
            end,
            set = function(layoutName, value)
                Data.db.profile.bars[1].tickColor = {
                    r = value.r,
                    g = value.g,
                    b = value.b,
                    a = value.a
                }
                self.tickColor = Data.db.profile.bars[1].tickColor
                self.reinitRequired = true
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
    Data.db.profile.bars[1].position = {
        point = point,
        x = floor(x),
        y = floor(y)
    }
end

function ChargeBar:onEnterEditMode()
end

function ChargeBar:onExitEditMode()
    if self.reinitRequired then
        self:Init(Data.db.profile.bars[1])
        self:Setup()
        self.reinitRequired = false
    end
end

--- Called every time the Edit Mode layout changes (including on login)
function ChargeBar:onEditModeLayout(layoutName)
end
