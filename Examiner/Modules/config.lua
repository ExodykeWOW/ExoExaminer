local ex = Examiner;

-- Module
local mod = ex:CreateModule("Config");
mod:CreatePage(false,"Настройки");
mod:CreateButton("Конфиг","Конфигурации","Настройки аддона");

-- Create Version String
local modName = ex:GetName();
local vers = mod.page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
vers:SetText(modName.." |cffffff80"..GetAddOnMetadata(modName,"Version"));
vers:SetPoint("BOTTOM",0,14);

-- Variables
local cfg;
local checkBtns = {};

--------------------------------------------------------------------------------------------------------
--                                           Config Scripts                                           --
--------------------------------------------------------------------------------------------------------

-- CheckBoxes: OnClick
local function ConfigCheckBox_OnClick(self,button)
	local var = ex.options[self.id].var;
	cfg[var] = (self:GetChecked() ~= nil);
	-- Special "makeMovable" handling -- Must not invoke the OnHide event!
	if (var == "makeMovable") then
		local onHide = ex:GetScript("OnHide");
		ex:SetScript("OnHide",nil);
		ex:SetMovable(cfg.makeMovable);
		if (cfg.makeMovable) then
			HideUIPanel(ex);
			ex:Show();
		else
			ex:Hide();
			ShowUIPanel(ex);
		end
		ex:SetScript("OnHide",onHide);
	end
	-- Post Change to Modules
	for index, mod in ipairs(ex.modules) do
		if (mod.OnConfigChanged) then
			mod:OnConfigChanged(var,cfg[var]);
		end
	end
end

-- CheckBoxes: OnEnter
local function ConfigCheckBox_OnEnter(self)
	local option = ex.options[self.id];
	GameTooltip:SetOwner(self,"ANCHOR_RIGHT");
	GameTooltip:AddLine(option.label,1,1,1);
	GameTooltip:AddLine(option.tip,nil,nil,nil,1);
	GameTooltip:Show();
end

--------------------------------------------------------------------------------------------------------
--                                           Module Scripts                                           --
--------------------------------------------------------------------------------------------------------

-- Menu Init
local function MenuInit(parent,list)
	list[1].text = "|cff00c0ffКэширование ядра";
	list[1].value = "Core";
	list[1].checked = cfg.caching.Core;
	list[1].tip = "Отключите это, чтобы полностью отключить кеширование в аддоне";
	for index, mod in ipairs(ex.modules) do
		if (mod.canCache) then
			local tbl = list[#list + 1];
			tbl.text = mod.token;
			tbl.value = mod.token;
			tbl.checked = cfg.caching[mod.token];
			tbl.tip = "Включите, чтобы включить кеширование для этого модуля";
		end
	end
end

-- Menu Select
local function MenuSelect(parent,entry)
	cfg.caching[entry.value] = not cfg.caching[entry.value];
end

-- OnInitialize
function mod:OnInitialize()
	cfg = Examiner_Config;
	-- DropDown
	local dropDown = AzDropDown.CreateDropDown(self.page,190,false,MenuInit,MenuSelect);
	dropDown:SetPoint("TOP",0,-40);
	dropDown.label:SetText("Активация кэша модулей");
	-- Check Boxes
	for index, option in ipairs(ex.options) do
		local chk = CreateFrame("CheckButton",nil,mod.page);
		chk:SetWidth(24);
		chk:SetHeight(24);
		chk:SetScript("OnClick",ConfigCheckBox_OnClick);
		chk:SetScript("OnEnter",ConfigCheckBox_OnEnter);
		chk:SetScript("OnLeave",ex.HideGTT);

		chk:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");
		chk:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down");
	 	chk:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight");
		chk:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled");
		chk:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");

		chk:SetChecked(cfg[option.var]);

		chk.text = chk:CreateFontString("ARTWORK",nil,"GameFontNormalSmall");
		chk.text:SetPoint("LEFT",chk,"RIGHT",0,1);
		chk.text:SetText(option.label);
		chk:SetHitRectInsets(0,chk.text:GetWidth() * -1,0,0);

		chk.id = index;

		if (index == 1) then
			chk:SetPoint("TOPLEFT",20,-70);
		else
			chk:SetPoint("TOP",checkBtns[index - 1],"BOTTOM");
		end

		checkBtns[index] = chk;
	end
end