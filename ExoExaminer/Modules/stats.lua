local ex = Examiner;
local gtt = GameTooltip;

-- Module
local mod = ex:CreateModule("Stats");
mod:CreatePage(false);
mod:CreateButton("Статы","Статы снаряжения.","Щелкните правой кнопкой мыши для расширенного меню");
mod.details = ex:CreateDetailObject();

-- Variables
local ITEM_HEIGHT = 12;
local cfg, cache;
local displayList = {};
local resists = {};
local entries = {};

-- Stat Entry Order
local StatEntryOrder = {
	{ [0] = PLAYERSTAT_BASE_STATS, "STR", "AGI", "STA", "INT", "SPI", "ARMOR" },
	{ [0] = HEALTH.." и "..MANA, "HP", "MP", "HP5", "MP5" },
	{ [0] = PLAYERSTAT_SPELL_COMBAT.." "..STATS_LABEL:gsub(":",""), "HEAL", "SPELLDMG", "ARCANEDMG", "FIREDMG", "NATUREDMG", "FROSTDMG", "SHADOWDMG", "HOLYDMG", "SPELLCRIT", "SPELLHIT", "SPELLHASTE", "SPELLPENETRATION" },
	{ [0] = MELEE.." и "..RANGED, "AP", "RAP", "CRIT", "HIT", "HASTE", "ARMORPENETRATION", "EXPERTISE", "WPNDMG", "RANGEDDMG" },
	{ [0] = PLAYERSTAT_DEFENSES, "DEFENSE", "DODGE", "PARRY", "BLOCK", "BLOCKVALUE", "RESILIENCE" },
};

-- Az: this is a temp slash command to add iLvlTotal value to old cached entries
--ex.slashHelp[#ex.slashHelp + 1] = " |2fixcacheitemlevels|r = Temp slash cmd to give old cache entries an avg itemlevel";
ex.slashFuncs.fixcacheitemlevels = function(cmd)
	local numItems = (#ExScanner.Slots - 3); -- Ignore Tabard + Shirt + Ranged, hence minus 3
	for entryName, entry in next, cache do
		local iLvlTotal = 0;
		for slotName, link in next, entry.Items do
			if (slotName ~= "TabardSlot") and (slotName ~= "ShirtSlot") and (slotName ~= "RangedSlot") then
				local _, _, _, itemLevel = GetItemInfo(link);
				if (itemLevel) then
					if (slotName == "MainHandSlot") and (not entry.Items.SecondaryHandSlot) then
						itemLevel = (itemLevel * 2);
					end
					iLvlTotal = (iLvlTotal + itemLevel);
				end
			end
		end
		entry.iLvlAvg = nil
		entry.iLvlAverage = (iLvlTotal / numItems);
	end
end

--------------------------------------------------------------------------------------------------------
--                                           Module Scripts                                           --
--------------------------------------------------------------------------------------------------------

-- OnInitialize
function mod:OnInitialize()
	cfg = Examiner_Config;
	cache = Examiner_Cache;
	-- Defaults
	cfg.statsViewType = (cfg.statsViewType or 1);
	-- Add cache sort method
	local cacheMod = ex:GetModuleFromToken("Cache");
	if (cacheMod) and (cacheMod.cacheSortMethods) then
		cacheMod.cacheSortMethods[#cacheMod.cacheSortMethods + 1] = "iLvlAverage";
	end
end

-- OnConfigChanged
function mod:OnConfigChanged(var,value)
	if (var == "combineAdditiveStats" or var == "percentRatings") then
		self:BuildShownList();
	end
end

-- OnButtonClick
function mod:OnButtonClick(button)
	-- left
	if (button == "LeftButton") then
		if (IsShiftKeyDown()) and (ex.itemsLoaded) then
			ex:CacheStatsForCompare();
		elseif (IsControlKeyDown()) then
			cfg.statsViewType = (cfg.statsViewType == 1 and 2 or 1);
			self:BuildShownList();
		end
	-- right
	elseif (IsShiftKeyDown()) then
		ex:CacheStatsForCompare(1);
	end
end

-- OnInspect
function mod:OnInspect(unit)
	if (ex.itemsLoaded) then
		self.details:Clear();	-- Az: due to the gem workaround, clear details here
		self:InitDetails();
		self:BuildShownList();
		self.button:Enable();
	else
		self.page:Hide();
		self.button:Disable();
	end
end

-- OnCacheLoaded
function mod:OnCacheLoaded(entry,unit)
	self.details:Clear();	-- Az: due to the gem workaround, clear details here
	self:InitDetails();
	self:BuildShownList();
	self.button:Enable();
end

-- OnClearInspect
function mod:OnClearInspect()
	self.details:Clear();
end

-- OnCompare
function mod:OnCompare(isCompare,compareEntry)
	self:BuildShownList();
end

-- OnDetailsUpdate
function mod:OnDetailsUpdate()
	if (cfg.statsViewType == 2) then
		self:BuildShownList();
	end
end

--------------------------------------------------------------------------------------------------------
--                                                Menu                                                --
--------------------------------------------------------------------------------------------------------

-- Menu Init Items
function mod.MenuInit(parent,list)
	-- stats
	local tbl = list[#list + 1]; tbl.text = "Настройки отображения"; tbl.header = 1;
	--tbl = list[#list + 1]; tbl.text = "Добавить в кеш"; tbl.value = 1; tbl.checked = (cache[ex:GetEntryName()] ~= nil);
	-- view
	tbl = list[#list + 1]; tbl.header = 1;
	tbl = list[#list + 1]; tbl.text = "Вид"; tbl.header = 1;
	tbl = list[#list + 1]; tbl.text = "Статы снаряжения"; tbl.value = 4; tbl.checked = (cfg.statsViewType == 1);
	tbl = list[#list + 1]; tbl.text = "Детали"; tbl.value = 5; tbl.checked = (cfg.statsViewType == 2);
	-- compare
	tbl = list[#list + 1]; tbl.header = 1;
	tbl = list[#list + 1]; tbl.text = "Сравнить"; tbl.header = 1;
	tbl = list[#list + 1]; tbl.text = "Отметить для сравнения"; tbl.value = 2; tbl.checked = (ex.isComparing and ex.compareStats.entry == ex:GetEntryName());
	if (ex.isComparing) then
		tbl = list[#list + 1]; tbl.text = "Очистить сравнение"; tbl.value = 3;
	end
end

-- Menu Select Item
function mod.MenuSelect(parent,entry)
	-- Cache
	if (entry.value == 1) then
		ex:CachePlayer(1);
	-- Mark for Compare & Clear Compare
	elseif (entry.value == 2 or entry.value == 3) then
		ex:CacheStatsForCompare(entry.value == 3);
	-- View Type
	else
		cfg.statsViewType = (entry.value - 3);
		mod:BuildShownList();
	end
end

--------------------------------------------------------------------------------------------------------
--                                               Details                                              --
--------------------------------------------------------------------------------------------------------

-- Obtain Gem and Item Level Details
-- http://www.wowwiki.com/Item_level#Epic_Item_Level_Chart
-- http://elitistjerks.com/f15/t44718-item_level_mechanics/
local function GetGemAndItemInfo()
	local iLvlTotal, iSlotValues, iLvlMin, iLvlMax = 0, 0;
	local gemCount, gemRed, gemYellow, gemBlue = 0, 0, 0, 0;
	for slotName, link in next, ex.info.Items do
		-- Count Gem Colors
		for i = 1, 3 do
			local _, gemLink = GetItemGem(link,i);
			if (gemLink) then
				gemCount = (gemCount + 1);
				local _, _, _, _, _, _, itemSubType = GetItemInfo(gemLink);
				if (EMPTY_SOCKET_NO_COLOR:match(itemSubType)) then
					gemRed = (gemRed + 1);
					gemYellow = (gemYellow + 1);
					gemBlue = (gemBlue + 1);
				else
					ExScannerTip:ClearLines();
					ExScannerTip:SetHyperlink(gemLink);
					-- 09.08.09: This code now scans all lines, to fix the issue with patch 3.2 adding more lines to item tooltip.
					for n = 3, ExScannerTip:NumLines() do
						local line = _G["ExScannerTipTextLeft"..n]:GetText():lower();
						if (line:match("^\".+\"$")) then
							if (line:match(RED_GEM:lower())) then
								gemRed = (gemRed + 1);
							end
							if (line:match(YELLOW_GEM:lower())) then
								gemYellow = (gemYellow + 1);
							end
							if (line:match(BLUE_GEM:lower())) then
								gemBlue = (gemBlue + 1);
							end
						end
					end
				end
			end
		end
		-- Calculate Item Level Numbers
		if (slotName ~= "TabardSlot") and (slotName ~= "ShirtSlot") and (slotName ~= "RangedSlot") then
			local _, _, itemRarity, itemLevel = GetItemInfo(link);
			if (itemLevel) then
				iLvlMin = min(iLvlMin or itemLevel,itemLevel);
				iLvlMax = max(iLvlMax or itemLevel,itemLevel);
				local itemSlotValue = ExScanner:CalculateItemSlotValue(link);
				if (slotName == "MainHandSlot") and (not ex.info.Items.SecondaryHandSlot) then
					itemLevel = (itemLevel * 2);
					itemSlotValue = (itemSlotValue * 2);
				end
				iLvlTotal = (iLvlTotal + itemLevel);
				iSlotValues = (iSlotValues + itemSlotValue);
			end
		end
	end
	-- Return
	return iLvlTotal, iLvlMin, iLvlMax, iSlotValues, gemCount, gemRed, gemYellow, gemBlue;
end

-- Initialise Details
function mod:InitDetails()
	local details = self.details;
	-- Unit Details
	if (ex.unit) then
		details:Add("Информация о персонаже");
		details:Add("Токен",ex.unit);
		details:Add(HEALTH,UnitHealthMax(ex.unit));
		if (UnitPowerType(ex.unit) == 0) then
			details:Add(MANA,UnitPowerMax(ex.unit));
		end
	end
	-- Item Level
	local iLvlTotal, iLvlMin, iLvlMax, iSlotValues, gemCount, gemRed, gemYellow, gemBlue = GetGemAndItemInfo();
	local numItems = (#ExScanner.Slots - 3); -- Ignore Tabard + Shirt + Ranged, hence minus 3
	details:Add("Уровень предметов");
	details:Add("Комб.значения предметов",floor(iSlotValues));
	details:Add("Средн.значение предметов",format("%.2f",iSlotValues / numItems));
	details:Add("Комб.уровень предметов",iLvlTotal);
	details:Add("Средний уровень предметов",format("%.2f",iLvlTotal / numItems));
	if (iLvlMin and iLvlMax) then
		details:Add("Мин/Макс ур.предметов",iLvlMin.." / "..iLvlMax);
	end
	ex.info.iLvlAverage = (iLvlTotal / numItems);
	-- Gems
	details:Add("Камни в вещах");
	details:Add("Количество камней",gemCount);
	--details:Add("Сочетания камней по цвету",format("|cffff6060%d|r/|cffffff00%d|r/|cff008ef8%d",gemRed,gemYellow,gemBlue));
	-- Cache
	if (ex.isCacheEntry) then
		details:Add("Кэшированная запись");
		details:Add("Зона",ex.info.zone);
		details:Add("Дата",date("%a, %b %d, %Y",ex.info.time));
		details:Add("Время",date("%H:%M:%S",ex.info.time));
		details:Add("Как давно",ex:FormatTime(time() - ex.info.time));
	end
end

--------------------------------------------------------------------------------------------------------
--                                         Update Stat Lists                                          --
--------------------------------------------------------------------------------------------------------

-- Show Resistances
local function UpdateResistances()
	for i = 1, 5 do
		local statToken = (ExScanner.MagicSchools[i].."RESIST");
		if (ex.unitStats[statToken]) or (ex.isComparing and ex.compareStats[statToken]) then
			resists[i].value:SetText(ex:GetStatValue(statToken,ex.unitStats,ex.isComparing and ex.compareStats));
		else
			resists[i].value:SetText("");
		end
	end
end

-- ScrollBar: Update Stat List
local function UpdateShownItems()
	FauxScrollFrame_Update(ExaminerStatScroll,displayList.count,#entries,ITEM_HEIGHT);
	local index = ExaminerStatScroll.offset;
	for i = 1, #entries do
		index = (index + 1);
		local entry = entries[i];
		if (index <= displayList.count) then
			if (displayList[index].value) then
				entry.left:SetTextColor(1,1,1);
				entry.left:SetFormattedText("  %s",displayList[index].name);
				entry.right:SetText(displayList[index].value);
			elseif (displayList[index].name) then
				entry.left:SetTextColor(0.5,0.75,1.0);
				entry.left:SetFormattedText("%s:",displayList[index].name);
				entry.right:SetText("");
			else
				entry.left:SetText("");
				entry.right:SetText("");
			end

			if (displayList[index].tip) then
				entry.tip.tip = displayList[index].tip;
				entry.tip:SetWidth(max(entry.right:GetWidth(),20));
				entry.tip:Show();
			else
				entry.tip:Hide();
			end

			entry:Show();
		else
			entry:Hide();
		end
	end
	entries[1]:SetWidth(displayList.count > #entries and 200 or 216);
end

-- Adds a List Entry
local function AddListEntry(name,value,tip)
	displayList.count = (displayList.count + 1);
	local tbl = displayList[displayList.count] or {};
   	displayList[displayList.count] = tbl;
	tbl.name = name;
	tbl.value = value;
	tbl.tip = tip;
end

-- Build Stat List
local function BuildStatList()
	displayList.count = 0;
	local needHeader;
	-- Build display table
	for _, statCat in ipairs(StatEntryOrder) do
		needHeader = 1;
		for _, statToken in ipairs(statCat) do
			if (ex.unitStats[statToken]) or (ex.isComparing and ex.compareStats[statToken]) then
				if (needHeader) then
					AddListEntry(statCat[0]);
					needHeader = nil;
				end
				local value, tip = ex:GetStatValue(statToken,ex.unitStats,ex.isComparing and ex.compareStats);
				AddListEntry(ExScanner.StatNames[statToken],value,tip);
			end
		end
	end
	-- Add Sets
	if (next(ex.info.Sets)) then
		AddListEntry();
		AddListEntry("Сеты экиперовки");
	end
	for setName, setEntry in next, ex.info.Sets do
		AddListEntry(setName,setEntry.count.."/"..setEntry.max);
	end
	-- Add Padding + Update Resistances + Shown Items
	AddListEntry();
	UpdateResistances();
	UpdateShownItems();
end

-- Build Detail List
local function BuildInfoList()
	displayList.count = 0;
	--- Show Details from Modules
	for index, mod in ipairs(ex.modules) do
		if (mod.details) and (#mod.details.entries > 0) then
			for index, entry in ipairs(mod.details.entries) do
				AddListEntry(entry.label,entry.value,entry.tip);
			end
		end
	end
	-- Add Padding + Update Resistances + Shown Items
	AddListEntry();
	UpdateResistances();
	UpdateShownItems();
end

-- Build the Shown List
function mod:BuildShownList()
	if (cfg.statsViewType == 1) then
		BuildStatList();
	else
		BuildInfoList();
	end
end

--------------------------------------------------------------------------------------------------------
--                                           Widget Creation                                          --
--------------------------------------------------------------------------------------------------------

-- Resistance Boxes
for i = 1, 5 do
	local t = CreateFrame("Frame",nil,mod.page);
	t:SetWidth(32);
	t:SetHeight(29);

	t.texture = t:CreateTexture(nil,"BACKGROUND");
	t.texture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ResistanceIcons");
	t.texture:SetTexCoord(0,1,(i - 1) * 0.11328125,i * 0.11328125);
	t.texture:SetAllPoints();

	t.value = t:CreateFontString(nil,"ARTWORK","GameFontNormal");
	t.value:SetFont(GameFontNormal:GetFont(),12,"OUTLINE");
	t.value:SetPoint("BOTTOM",1,3);
	t.value:SetTextColor(1,1,0);

	if (i == 1) then
 		t:SetPoint("TOPLEFT",36,-9);
	else
 		t:SetPoint("LEFT",resists[i - 1],"RIGHT");
	end

	resists[i] = t;
end

-- Stat Entries
local StatEntry_OnEnter = function(self,motion) gtt:SetOwner(self,"ANCHOR_RIGHT"); gtt:SetText(self.tip); end
for i = 1, 20 do
	local t = CreateFrame("Frame",nil,mod.page);
	t:SetWidth(200);
	t:SetHeight(ITEM_HEIGHT);
	t.id = i;

	if (i == 1) then
		t:SetPoint("TOPLEFT",8,-40);
	else
		t:SetPoint("TOPLEFT",entries[i - 1],"BOTTOMLEFT");
		t:SetPoint("TOPRIGHT",entries[i - 1],"BOTTOMRIGHT");
	end

	t.left = t:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
	t.left:SetPoint("LEFT");

	t.right = t:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
	t.right:SetPoint("RIGHT");
	t.right:SetTextColor(1,1,0);

	t.tip = CreateFrame("Frame",nil,t);
	t.tip:SetPoint("TOPRIGHT");
	t.tip:SetPoint("BOTTOMRIGHT");
	t.tip:SetScript("OnEnter",StatEntry_OnEnter);
	t.tip:SetScript("OnLeave",ex.HideGTT);
	t.tip:EnableMouse(1);

	entries[i] = t;
end

-- Scroll
local scroll = CreateFrame("ScrollFrame","ExaminerStatScroll",mod.page,"FauxScrollFrameTemplate");
scroll:SetPoint("TOPLEFT",entries[1]);
scroll:SetPoint("BOTTOMRIGHT",entries[#entries],-3,-1);
scroll:SetScript("OnVerticalScroll",function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,ITEM_HEIGHT,UpdateShownItems) end);