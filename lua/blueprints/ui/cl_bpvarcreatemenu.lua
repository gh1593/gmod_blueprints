if SERVER then AddCSLuaFile() return end

module("bpuivarcreatemenu", package.seeall, bpcommon.rescope(bpschema))

function VarList( element, window, list, name )

	local module = element.module
	local vlist = vgui.Create( "BPListView", window )
	vlist:SetList( list )
	vlist:SetText( name )
	vlist:SetNoConfirm()
	vlist.HandleAddItem = function(pnl)
		local id, item = list:Add( MakePin( PD_None, nil, PN_Bool, PNF_None, nil ), name )
		pnl:Rename(id)
	end
	vlist.OpenMenu = function(pnl, id, item)
		window.menu = bpuivarcreatemenu.OpenPinSelectionMenu(module, function(pnl, pinType)
			element:PreModify()
			item:SetType( pinType )
			element:PostModify()
		end, item:GetType())
	end
	vlist.ItemBackgroundColor = function( list, id, item, selected )
		local vcolor = item:GetColor()
		if selected then
			return vcolor
		else
			return Color(vcolor.r*.5, vcolor.g*.5, vcolor.b*.5)
		end
	end

	return vlist

end

local function PinTypeDisplayName( pinType )

	if pinType:IsType(PN_Ref) or pinType:IsType(PN_Enum) or pinType:IsType(PN_Struct) then
		return pinType:GetSubType()
	else
		return pinType:GetTypeName()
	end

end

local tableIcon = Material("icon16/text_list_bullets.png")
function PaintPinType( btn, w, h, pinType )

	local col = pinType:GetColor()
	local text_col = color_white

	if btn.Hovered then col = Color(255,255,255) end
	if btn:IsDown() then col = Color(50,170,200) end
	col = Color(col.r - 20, col.g - 20, col.b - 20)

	local bgColor = Color(col.r + 20, col.g + 20, col.b + 20)
	draw.RoundedBox( 2, 1, 1, w-2, h-2, col )
	draw.SimpleTextOutlined( PinTypeDisplayName(pinType), "DermaDefaultBold", 4, h/2, text_col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, color_black )

	if pinType:HasFlag( PNF_Table ) then
		surface.SetDrawColor(color_white)
		surface.DrawRect(w-h-2,h/2 - 8,16,16)
		surface.SetMaterial(tableIcon)
		surface.DrawTexturedRect(w-h-2,h/2 - 8,16,16)
	end

end

local categoryOrder = {
	["Basic"] = 1,
	["Custom"] = 2,
	["Classes"] = 3,
	["Structs"] = 4,
	["Enums"] = 5,
}

local function SearchRanker( entry, query, queryLength, panel )

	local str = panel:GetDisplayName(entry):lower()
	local rank = str:len() - queryLength
	if str == query then rank = 0
	elseif str:find(query) == 1 then
		rank = rank + 100
		rank = rank + categoryOrder[ panel:GetCategory( entry ) ] * 400
	else rank = rank + 4000
	end
	return rank

end

local function CreateEntryWidget( pnl, entry )

	local p = vgui.Create("DButton")
	p.pinType = entry
	p:SetText( "" )
	p.DoClick = function(btn) pnl:Select(btn.pinType) end

	p:SetFont("DermaDefaultBold")
	p:SetTextColor(color_white)
	p.Paint = function(btn, w, h) PaintPinType(btn, w, h, btn.pinType) end
	p.SetPinType = function(btn, type) btn.pinType = type end

	return p

end

function OpenPinSelectionMenu( module, onSelected, current )

	local collection = bpcollection.New()
	module:GetPinTypes( collection )

	current = current or PinType(PN_Bool)

	local currentWidget = nil
	local function convert( asTable )

		local tablePins = bpcommon.Transform( function() return collection:Items() end, {}, function(t)
			return asTable and t:AsTable() or t:AsSingle()
		end)

		collection:Clear()
		collection:Add( tablePins )

		current = asTable and current:AsTable() or current:AsSingle()
		currentWidget:SetPinType( current )

	end

	local menu = bpuipickmenu.Create(nil, nil, 300)
	local top = vgui.Create("DPanel")
	top:SetBackgroundColor(Color(40,40,40))
	top:SetTall(30)

	currentWidget = CreateEntryWidget( menu, current )
	currentWidget:SetWide(120)
	currentWidget:SetParent(top)
	currentWidget:DockMargin(2,2,2,2)
	currentWidget:Dock( FILL )

	local tcheck = vgui.Create("DCheckBoxLabel", top)
	tcheck:Dock( RIGHT )
	tcheck:SetText("As Table")
	tcheck:SetChecked( current:HasFlag(PNF_Table) )
	tcheck:DockMargin(4,4,4,4)
	tcheck.OnChange = function( check, val )
		convert( val )
		menu:CreatePages()
	end

	if tcheck:GetChecked() then convert( true ) end

	menu:SetCustomTop(top)
	menu:SetCollection( collection )
	menu.OnEntrySelected = onSelected
	menu.GetDisplayName = function(pnl, e) return PinTypeDisplayName(e) end
	menu:SetSearchRanker( SearchRanker )
	menu:SetSorter( function(a,b)
		local aname = menu:GetDisplayName(a)
		local bname = menu:GetDisplayName(b)
		local acat = categoryOrder[menu:GetCategory(a)] or 0
		local bcat = categoryOrder[menu:GetCategory(b)] or 0
		if acat == bcat then
			return aname:lower() < bname:lower()
		end
		return acat < bcat
	end 
	)
	menu.GetCategory = function(pnl, e)
		if e:HasFlag(PNF_Custom) then return "Custom", "icon16/wrench.png" end
		if e:IsType(PN_Ref) then return "Classes", "icon16/bricks.png" end
		if e:IsType(PN_Enum) then return "Enums", "icon16/book_open.png" end
		if e:IsType(PN_Struct) then return "Structs", "icon16/table.png" end
		return "Basic", "icon16/brick.png"
	end
	menu.GetEntryPanel = function(pnl, e)
		local p = vgui.Create("DButton")
		p:SetText( "" )
		p.DoClick = function() pnl:Select(e) end

		p:SetFont("DermaDefaultBold")
		p:SetTextColor(color_white)
		p.Paint = function(btn, w, h) PaintPinType(btn, w, h, e) end

		return p
	end
	menu:Setup()
	return menu

end