-- The boss list shown while inside a dungeon or raid. Draws a view from Progress.TrackerView; the frame is
-- created on first use. Drag the header to move it, click the header to collapse it.
local _, ns = ...

local Tracker = {}
ns.Tracker = Tracker

local WIDTH = 220
local HEADER_HEIGHT = 20
local ROW_HEIGHT = 16
local PADDING = 6
local TICK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local DONE_COLOR = { 0.1, 1, 0.1 }
local ALIVE_COLOR = { 0.6, 0.6, 0.6 }

local frame
local rowPool, shownRows = {}, {}

local function SetDefaultPosition()
	frame:ClearAllPoints()
	frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -230)
end

local function ApplyPosition(pos)
	if pos then
		frame:ClearAllPoints()
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		SetDefaultPosition()
	end
end

local function CreateTracker()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetWidth(WIDTH)
	f:SetClampedToScreen(true)
	f:SetMovable(true)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.45)

	local header = CreateFrame("Button", nil, f)
	header:SetHeight(HEADER_HEIGHT)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	header:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local point, _, relPoint, x, y = f:GetPoint(1)
		if f.opts.onMoved then
			f.opts.onMoved({ point = point, relPoint = relPoint, x = x, y = y })
		end
	end)
	header:SetScript("OnClick", function()
		f.opts.collapsed = not f.opts.collapsed
		if f.opts.onToggle then
			f.opts.onToggle(f.opts.collapsed)
		end
		Tracker.Show(f.view, f.opts)
	end)

	header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header.title:SetPoint("LEFT", 8, 0)
	header.title:SetJustifyH("LEFT")
	header.title:SetWordWrap(false) -- long wing names truncate instead of spilling onto the rows
	header.count = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header.count:SetPoint("RIGHT", -8, 0)
	header.count:SetJustifyH("RIGHT")
	header.title:SetPoint("RIGHT", header.count, "LEFT", -6, 0)

	f.header = header
	f:Hide()
	return f
end

local function AcquireRow()
	local row = table.remove(rowPool)
	if not row then
		row = CreateFrame("Frame", nil, frame)
		row:SetHeight(ROW_HEIGHT)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(12, 12)
		row.icon:SetPoint("LEFT", 10, 0)
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.right:SetPoint("RIGHT", -8, 0)
		row.right:SetJustifyH("RIGHT")
		row.text:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
	end
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_HEIGHT - #shownRows * ROW_HEIGHT)
	row:SetPoint("RIGHT", frame, "RIGHT")
	row.right:SetText("")
	row:Show()
	shownRows[#shownRows + 1] = row
	return row
end

local function ReleaseRows()
	for i = #shownRows, 1, -1 do
		local row = shownRows[i]
		row:Hide()
		rowPool[#rowPool + 1] = row
		shownRows[i] = nil
	end
end

local function AddText(row, text, color, fontObject)
	row.text:SetFontObject(fontObject or "GameFontHighlightSmall")
	row.text:SetText(text)
	if color then
		row.text:SetTextColor(color[1], color[2], color[3])
	end
end

local function AddBoss(boss)
	local row = AcquireRow()
	if boss.killed then
		row.icon:SetTexture(TICK)
		AddText(row, boss.name, { 1, 1, 1 })
	else
		row.icon:SetTexture(nil)
		AddText(row, "· " .. boss.name, ALIVE_COLOR)
	end
end

local function AddWing(wing)
	local row = AcquireRow()
	row.icon:SetTexture(nil)
	local color = wing.completed and DONE_COLOR or { 1, 1, 1 }
	AddText(row, wing.name, color)
	row.right:SetText(wing.done .. "/" .. wing.total)
	row.right:SetTextColor(color[1], color[2], color[3])
end

local function AddHeading(text)
	local row = AcquireRow()
	row.icon:SetTexture(nil)
	AddText(row, text, nil, "GameFontNormalSmall")
end

-- view: from Progress.TrackerView. opts: { pos, collapsed, onMoved(pos), onToggle(collapsed) }.
function Tracker.Show(view, opts)
	if not frame then
		frame = CreateTracker()
		ApplyPosition(opts.pos)
	end
	frame.view, frame.opts = view, opts

	local header = frame.header
	header.title:SetText(view.title)
	header.count:SetText(view.total and (view.done .. "/" .. view.total) or "")
	local color = view.completed and DONE_COLOR or { 1, 0.82, 0 }
	header.title:SetTextColor(color[1], color[2], color[3])
	header.count:SetTextColor(color[1], color[2], color[3])

	ReleaseRows()
	if not opts.collapsed then
		for _, wing in ipairs(view.wings or {}) do
			AddWing(wing)
		end
		for _, boss in ipairs(view.bosses) do
			AddBoss(boss)
		end
		if #view.bonus > 0 then
			AddHeading("Bonus")
			for _, boss in ipairs(view.bonus) do
				AddBoss(boss)
			end
		end
	end
	local rowsHeight = #shownRows > 0 and (#shownRows * ROW_HEIGHT + PADDING) or 0
	frame:SetHeight(HEADER_HEIGHT + rowsHeight)
	frame:Show()
end

function Tracker.Hide()
	if frame then
		frame:Hide()
	end
end

function Tracker.ResetPosition()
	if frame then
		SetDefaultPosition()
	end
end
