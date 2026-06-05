-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Appearance = TSM.MainUI.Settings:NewPackage("Appearance") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local LibDBIcon = LibStub("LibDBIcon-1.0")
local LibDeflate = LibStub("LibDeflate")
local LibSerialize = LibStub("LibSerialize")
local private = {
	frame = nil,
	settings = nil,
	currentThemeKey = nil,
}
local MAGIC_STR = "TSM_THEME_EXPORT"
local VERSION = 1
local SERIALIZE_OPTIONS = {
	stable = true,
}
local THEME_KEYS = {
	"PRIMARY_BG",
	"PRIMARY_BG_ALT",
	"FRAME_BG",
	"ACTIVE_BG",
	"ACTIVE_BG_ALT",
}
local THEME_KEYS_VALID = {
	PRIMARY_BG = true,
	PRIMARY_BG_ALT = true,
	FRAME_BG = true,
	ACTIVE_BG = true,
	ACTIVE_BG_ALT = true,
}
local THEME_KEY_LABELS = {
	L["Primary"],
	L["Primary Alt"],
	L["Frame"],
	L["Active"],
	L["Active Alt"],
}
local SETTING_TOOLTIPS = {
	showTotalMoney = L["If eanbled, the gold amount in the top-right of TSM windows will be your total gold, rather than the gold on the current character."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Appearance.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "appearanceOptions", "customColorSet")
		:AddKey("global", "coreOptions", "minimapIcon")
		:AddKey("global", "appearanceOptions", "taskListBackgroundLock")
		:AddKey("global", "appearanceOptions", "showTotalMoney")
	TSM.MainUI.Settings.RegisterSettingPage(L["Appearance"], "middle", private.GetSettingsFrame)
end



-- ============================================================================
-- Appearance Settings UI
-- ============================================================================

function private.GetSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "appearance")
	local frame = UIElements.New("ScrollFrame", "generalSettings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Appearance", "appearance", L["General Options"], L["Some general appearance options are below."])
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "minimapCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Hide minimap icon"])
					:SetSettingInfo(private.settings.minimapIcon, "hide")
					:SetScript("OnValueChanged", private.MinimapOnValueChanged)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "taskListLockCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Lock task list's background"])
					:SetSettingInfo(private.settings, "taskListBackgroundLock")
					:SetScript("OnValueChanged", private.TaskListLockOnValueChanged)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Checkbox", "showTotalMoneyCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Show total gold in header"])
					:SetSettingInfo(private.settings, "showTotalMoney")
					:SetTooltip(SETTING_TOOLTIPS.showTotalMoney)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
		)
		:AddChild(UIElements.New("Text", "label")
			:SetHeight(24)
			:SetMargin(12, 0, 4, 12)
			:SetFont("BODY_BODY1_BOLD")
			:SetText(L["Themes"])
		)
		:AddChild(UIElements.New("Frame", "theme")
			:SetLayout("FLOW")
			:AddChildrenWithFunction(private.CreateThemes)
		)
		:AddChild(UIElements.New("Frame", "content")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(12, 0, 24, 12)
			:AddChild(UIElements.New("Text", "customLabel")
				:SetWidth("AUTO")
				:SetFont("BODY_BODY1_BOLD")
				:SetText(L["Custom Theme"])
			)
			:AddChild(UIElements.New("Button", "exportBtn")
				:SetWidth(24)
				:SetMargin(12, 4, 0, 0)
				:SetBackgroundAndSize("iconPack.18x18/Export")
				:SetTooltip(L["Export theme"])
				:SetScript("OnClick", private.ExportThemeBtnOnClick)
			)
			:AddChild(UIElements.New("Button", "importBtn")
				:SetWidth(24)
				:SetMargin(8, 0, 0, 0)
				:SetBackground("iconPack.18x18/Import")
				:SetTooltip(L["Import Theme"])
				:SetScript("OnClick", private.ImportThemeBtnOnClick)
			)
		)
		:AddChild(UIElements.New("Frame", "custom")
			:SetLayout("FLOW")
			:AddChildrenWithFunction(private.CreateCustomColors)
		)
		:SetScript("OnHide", private.OnHide)
	private.frame = frame
	return frame
end

function private.CreateThemes(frame)
	for _, key, name, isActive in TSM.UI.Util.ColorSetIterator() do
		frame:AddChild(UIElements.New("Frame", key)
			:SetLayout("VERTICAL")
			:SetSize(198, 140)
			:SetPadding(0, 0, 12, 8)
			:SetMargin(0, 12, 0, 8)
			:SetRoundedBackgroundColor("FRAME_BG"..":"..key)
			:SetBorderColor("ACTIVE_BG_ALT"..":"..key)
			:SetContext(key)
			:AddChild(UIElements.New("Frame", "top")
				:SetLayout("HORIZONTAL")
				:SetHeight(36)
				:SetMargin(8, 8, 0, 12)
				:AddChild(UIElements.New("Frame", "left")
					:SetSize(36, 36)
					:SetMargin(0, 12, 0, 0)
					:SetRoundedBackgroundColor("ACTIVE_BG_ALT"..":"..key)
				)
				:AddChild(UIElements.New("Frame", "right")
					:SetLayout("VERTICAL")
					:AddChild(UIElements.New("Frame", "line1")
						:SetHeight(12)
						:SetMargin(0, 0, 0, 12)
						:SetRoundedBackgroundColor("ACTIVE_BG"..":"..key)
					)
					:AddChild(UIElements.New("Frame", "line2")
						:SetHeight(12)
						:SetRoundedBackgroundColor("PRIMARY_BG_ALT"..":"..key)
					)
				)
			)
			:AddChild(UIElements.New("Frame", "line3")
				:SetMargin(8, 8, 0, 12)
				:SetRoundedBackgroundColor("PRIMARY_BG"..":"..key)
			)
			:AddChild(UIElements.New("Texture", "divider")
				:SetHeight(1)
				:SetColor("ACTIVE_BG_ALT"..":"..key)
			)
			:AddChild(UIElements.New("Checkbox", "checkbox")
				:SetHeight(20)
				:SetMargin(8, 0, 8, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetTheme("RADIO")
				:SetText(name)
				:SetChecked(isActive)
				:SetScript("OnValueChanged", private.ThemeButtonOnClick)
			)
			:AddChildNoLayout(UIElements.New("Button", "btn")
				:AddAnchor("TOPLEFT")
				:AddAnchor("BOTTOMRIGHT")
				:SetScript("OnClick", private.ThemeButtonOnClick)
			)
		)
	end
end

function private.CreateCustomColors(frame)
	for i, key in ipairs(THEME_KEYS) do
		local colorThemeKey = TSM.UI.Util.GetCustomColorThemeKey(key)
		frame:AddChild(UIElements.New("Frame", key)
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("Text", "label")
				:SetHeight(20)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(THEME_KEY_LABELS[i])
			)
			:AddChild(UIElements.New("Frame", "frame")
				:SetLayout("HORIZONTAL")
				:SetSize(200, 50)
				:SetMargin(0, 12, 0, 8)
				:SetRoundedBackgroundColor("FULL_BLACK")
				:SetBorderColor("ACTIVE_BG_ALT")
				:AddChild(UIElements.New("Frame", "color")
					:SetWidth(50, 50)
					:SetMouseEnabled(true)
					:SetRoundedBackgroundColor(colorThemeKey)
					:SetBorderColor("ACTIVE_BG_ALT")
					-- draw a line along the right to hide the rounded corners at the bottom of the header frame
					:AddChildNoLayout(UIElements.New("Texture", "mask")
						:AddAnchor("TOPRIGHT", 0, -1)
						:AddAnchor("BOTTOMRIGHT", 0, 1)
						:SetWidth(8)
						:SetColor(colorThemeKey)
					)
					:SetContext(key)
					:SetScript("OnMouseUp", private.ColorOnMouseUp)
				)
				:AddChild(UIElements.New("Texture", "line")
					:SetWidth(1)
					:SetColor("ACTIVE_BG_ALT")
				)
				:AddChild(UIElements.New("EditableText", "text")
					:SetMargin(8, 0, 8, 8)
					:SetContext(i)
					:SetFont("BODY_BODY1_BOLD")
					:SetText(strupper(Theme.GetColor(colorThemeKey):GetHexNoAlpha()))
					:SetScript("OnValueChanged", private.HexValueChanged)
					:SetScript("OnEditingChanged", private.HexValueOnEditingChanged)
				)
				:AddChild(UIElements.New("Button", "edit")
					:SetMargin(8, 8, 0, 0)
					:SetBackgroundAndSize("iconPack.18x18/Edit")
					:SetScript("OnClick", private.HexValueOnClick)
				)
			)
		)
	end
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.OnHide(frame)
	if frame ~= private.frame then return end
	ColorPickerFrame:Hide()
	private.frame = nil
end

function private.MinimapOnValueChanged(_, value)
	if value then
		LibDBIcon:Hide("TradeSkillMaster")
	else
		LibDBIcon:Show("TradeSkillMaster")
	end
end

function private.TaskListLockOnValueChanged()
	if TSM.UI.TaskListUI.IsVisible() then
		TSM.UI.TaskListUI.UpdateFrame()
	end
end

function private.ThemeButtonOnClick(buttonToggle)
	local card = buttonToggle:GetParentElement()
	local checkbox = card:GetElement("checkbox")
	if buttonToggle ~= checkbox then
		-- Клик по оверлей-кнопке карточки темы (btn): сам radio-чекбокс клик не получает.
		-- Реактивную «точку» перерисовывает только НЕтихий Checkbox:SetChecked (через _HandleClick),
		-- а тихий путь/:Draw()/rebuild — нет. Поэтому просто эмулируем клик по чекбоксу —
		-- дальше отрабатывает рабочий checkbox-путь (этот же обработчик, но уже от самого чекбокса).
		if not checkbox:IsChecked() then
			checkbox:SetChecked(true)
		end
		return
	end
	local frame = card:GetParentElement()
	local selectedKey = card:GetContext()
	TSM.UI.Util.SetActiveColorSet(selectedKey)
	-- ОБНОВЛЯЕМ «точки» ПЕРВЫМ ДЕЛОМ — до любых guard'ов и hex-лупа.
	-- frame это контейнер тем (card:GetParentElement()), private.frame для этого не нужен.
	for _, key, _, isActive in TSM.UI.Util.ColorSetIterator() do
		frame:GetElement(key..".checkbox")
			:SetChecked(isActive, true)
			:Draw()
	end
	local customKey = TSM.UI.Util.GetCustomColorSetKey()
	if selectedKey ~= customKey and frame:HasChildById(customKey) then
		-- remove the custom theme
		frame:RemoveChild(frame:GetElement(customKey))
	end
	if not private.frame then return end
	for _, key in ipairs(THEME_KEYS) do
		private.frame:GetElement("custom."..key..".frame.text")
			:SetText(strupper(Theme.GetColor(key..":"..selectedKey):GetHexNoAlpha()))
			:Draw()
	end
end

function private.ExportThemeBtnOnClick(button)
	ColorPickerFrame:Hide()
	button:GetBaseElement():ShowDialogFrame(UIElements.New("Frame", "frame")
		:SetLayout("VERTICAL")
		:SetSize(540, 250)
		:SetPadding(12)
		:AddAnchor("CENTER")
		:SetRoundedBackgroundColor("FRAME_BG")
		:SetMouseEnabled(true)
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(20, -4, -4, 12)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY2_BOLD")
				:SetJustifyH("CENTER")
				:SetText(L["Export Custom Theme"])
			)
			:AddChild(UIElements.New("Button", "closeBtn")
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetScript("OnClick", private.ImportExportCloseBtnOnClick)
			)
		)
		:AddChild(UIElements.New("Text", "desc")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 12)
			:SetFont("BODY_BODY3")
			:SetText(L["You can use the export string below to share this custom theme with others."])
		)
		:AddChild(UIElements.New("Text", "heading")
			:SetMargin(0, 0, 0, 8)
			:SetHeight(20)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Export String"])
		)
		:AddChild(UIElements.New("MultiLineInput", "input")
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetValue(private.GenerateThemeExport())
			:SetScript("OnValueChanged", private.ExportThemeOnEnterPressed)
		)
	)
end

function private.ExportThemeOnEnterPressed(input)
	input:SetValue(private.GenerateThemeExport())
		:Draw()
end

function private.GenerateThemeExport()
	local serialized = LibSerialize:SerializeEx(SERIALIZE_OPTIONS, MAGIC_STR, VERSION, private.settings.customColorSet)
	local compressed = LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(serialized))
	return compressed
end

function private.ImportThemeBtnOnClick(button)
	ColorPickerFrame:Hide()
	button:GetBaseElement():ShowDialogFrame(UIElements.New("Frame", "frame")
		:SetLayout("VERTICAL")
		:SetSize(540, 250)
		:SetPadding(12)
		:AddAnchor("CENTER")
		:SetRoundedBackgroundColor("FRAME_BG")
		:SetMouseEnabled(true)
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(20, -4, -4, 12)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY2_BOLD")
				:SetJustifyH("CENTER")
				:SetText(L["Import Theme"])
			)
			:AddChild(UIElements.New("Button", "closeBtn")
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetScript("OnClick", private.ImportExportCloseBtnOnClick)
			)
		)
		:AddChild(UIElements.New("Text", "desc")
			:SetHeight(40)
			:SetMargin(0, 0, 0, 12)
			:SetFont("BODY_BODY3")
			:SetText(L["You can import custom themes by pasting an import string into the box below."])
		)
		:AddChild(UIElements.New("Text", "text")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 8)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Import String"])
		)
		:AddChild(UIElements.New("MultiLineInput", "input")
			:SetMargin(0, 0, 0, 12)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetFocused(true)
			:SetPasteMode()
			:SetScript("OnValueChanged", private.ImportInputOnValueChanged)
		)
	)
end

function private.ImportInputOnValueChanged(input)
	local baseFrame = input:GetBaseElement()
	local themeSet = private.DecodeThemeImport(strtrim(input:GetValue()))
	if not themeSet then
		baseFrame:HideDialog()
		ChatMessage.PrintUser(L["The pasted value was not valid. Ensure you are pasting the entire import string."])
		return
	end
	for key, hexColor in pairs(themeSet) do
		local r, g, b = private.HexToRGB(hexColor)
		TSM.UI.Util.SetCustomColor(key, r, g, b)
		private.frame:GetElement("custom."..key..".frame.text")
			:SetText(strupper(format("#%02x%02x%02x", r, g, b)))
			:Draw()
	end
	baseFrame:HideDialog()
	local themeContainer = private.frame:GetElement("theme")
	themeContainer:ReleaseAllChildren()
	themeContainer:AddChildrenWithFunction(private.CreateThemes)
	themeContainer:Draw()
end

function private.DecodeThemeImport(str)
	str = LibDeflate:DecodeForPrint(str)
	if not str then
		Log.Info("Not a valid theme import string")
		return nil
	end
	local numExtraBytes = nil
	str, numExtraBytes = LibDeflate:DecompressDeflate(str)
	if not str then
		Log.Err("Failed to decompress theme import string")
		return nil
	elseif numExtraBytes > 0 then
		Log.Err("Import string had extra bytes")
		return nil
	end

	-- deserialize and validate the data
	local success, magicStr, version, themeSet = LibSerialize:Deserialize(str)
	if not success then
		Log.Err("Failed to deserialize new import string")
		return nil
	elseif magicStr ~= MAGIC_STR then
		Log.Err("Invalid magic string: "..tostring(magicStr))
		return nil
	elseif version ~= VERSION then
		Log.Err("Invalid version: "..tostring(version))
		return nil
	elseif type(themeSet) ~= "table" then
		Log.Err("Invalid theme: "..tostring(themeSet))
		return nil
	else
		local colors = 0
		for key, hexColor in pairs(themeSet) do
			colors = colors + 1
			if not THEME_KEYS_VALID[key] or not strmatch(strlower(hexColor), "^#([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$") then
				return nil
			end
		end
		if colors ~= #THEME_KEYS then
			return nil
		end
		return themeSet
	end
end

function private.ImportExportCloseBtnOnClick(button)
	button:GetBaseElement():HideDialog()
end

function private.HexValueOnClick(button)
	local text = button:GetElement("__parent.text")
	text:SetEditing(true)
	text:_GetBaseFrame():HighlightText(1, -1)
end

function private.HexValueChanged(text, newValue)
	newValue = strlower(newValue)
	if strmatch(strtrim(newValue), "^#([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$") then
		text:SetText(strupper(newValue))
		local r, g, b = private.HexToRGB(newValue)
		TSM.UI.Util.SetCustomColor(THEME_KEYS[text:GetContext()], r, g, b)
		local themeContainer = private.frame:GetElement("theme")
		themeContainer:ReleaseAllChildren()
		themeContainer:AddChildrenWithFunction(private.CreateThemes)
		themeContainer:Draw()
	end
	text:Draw()
end

function private.HexValueOnEditingChanged(text, editing)
	if editing then
		text:GetElement("__parent.edit"):Hide()
	else
		text:GetElement("__parent.edit"):Show()
	end
end

function private.HexToRGB(hexColor)
	local r, g, b = strmatch(hexColor, "^#([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$")
	return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

function private.ColorOnMouseUp(frame)
	private.currentThemeKey = frame:GetContext()
	local r, g, b = Theme.GetColor(TSM.UI.Util.GetCustomColorThemeKey(private.currentThemeKey)):GetFractionalRGBA()
	if ClientInfo.IsRetail() then
		ColorPickerFrame.Content.ColorPicker:SetColorRGB(r, g, b)
		ColorPickerFrame.Content.ColorSwatchOriginal:SetColorTexture(r, g, b)
	else
		ColorPickerFrame:SetColorRGB(r, g, b)
	end
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.previousValues = ColorPickerFrame.previousValues or {}
	wipe(ColorPickerFrame.previousValues)
	ColorPickerFrame.previousValues.r = r
	ColorPickerFrame.previousValues.g = g
	ColorPickerFrame.previousValues.b = b
	if ClientInfo.IsRetail() or ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		ColorPickerFrame.swatchFunc = private.ColorPickerCallback
	else
		ColorPickerFrame.func = private.ColorPickerCallback
	end
	ColorPickerFrame.cancelFunc = private.ColorPickerCancelCallback
	ColorPickerFrame:ClearAllPoints()
	local baseFrame = frame:GetBaseElement():_GetBaseFrame()
	local x, y = baseFrame:GetLeft() + (baseFrame:GetWidth() / 2), baseFrame:GetTop() - (baseFrame:GetHeight() / 2) - UIParent:GetHeight()
	ColorPickerFrame:SetPoint("CENTER", UIParent, "TOPLEFT", x, y)
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
	if ClientInfo.IsPandaClassic() then
		ColorPickerFrame.swatchFunc = ColorPickerFrame.func
	end
end

function private.ColorPickerCallback()
	private.SetCurrentThemeColor(ColorPickerFrame:GetColorRGB())
end

function private.ColorPickerCancelCallback(prev)
	private.SetCurrentThemeColor(prev.r, prev.g, prev.b)
end

function private.SetCurrentThemeColor(r, g, b)
	if not private.frame then return end
	r = Math.Round(r * 255)
	g = Math.Round(g * 255)
	b = Math.Round(b * 255)
	TSM.UI.Util.SetCustomColor(private.currentThemeKey, r, g, b)
	private.frame:GetElement("custom."..private.currentThemeKey..".frame.text")
		:SetText(strupper(format("#%02x%02x%02x", r, g, b)))
		:Draw()
	local themeContainer = private.frame:GetElement("theme")
	themeContainer:ReleaseAllChildren()
	themeContainer:AddChildrenWithFunction(private.CreateThemes)
	themeContainer:Draw()
end
