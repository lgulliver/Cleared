-- Boss kill toasts and the Dungeon Complete banner. Frames are created on first use.
local _, ns = ...

local UI = {}
ns.UI = UI

local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local LEVEL_UP_SOUND = 888 -- SOUNDKIT "LEVELUPSOUND"
local MAX_TOASTS = 3
local TOAST_HOLD = 3
local BANNER_HOLD = 5
local BANNER_AFTER_TOAST = 1.5 -- seconds to wait so the banner doesn't land on the last toast

-- Adds a fade in, hold, fade out animation that hides the frame and calls onDone when finished.
local function AddFade(frame, hold, onDone)
	local group = frame:CreateAnimationGroup()
	local fadeIn = group:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(0.25)
	fadeIn:SetOrder(1)
	local fadeOut = group:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetDuration(0.6)
	fadeOut:SetStartDelay(hold)
	fadeOut:SetOrder(2)
	group:SetScript("OnFinished", function()
		frame:Hide()
		if onDone then
			onDone(frame)
		end
	end)
	frame.fade = group
end

-- Toasts ---------------------------------------------------------------------

local toastPool, shownToasts = {}, {}
local lastToastAt = 0

local function LayoutToasts()
	for i, toast in ipairs(shownToasts) do
		toast:ClearAllPoints()
		toast:SetPoint("TOP", UIParent, "TOP", 0, -190 - (i - 1) * 32)
	end
end

local function ReleaseToast(toast)
	for i, shown in ipairs(shownToasts) do
		if shown == toast then
			table.remove(shownToasts, i)
			break
		end
	end
	toastPool[#toastPool + 1] = toast
	LayoutToasts()
end

local function CreateToast()
	local toast = CreateFrame("Frame", nil, UIParent)
	toast:SetSize(340, 28)
	toast:SetFrameStrata("HIGH")

	local bg = toast:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.65)

	local icon = toast:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", 8, 0)
	icon:SetTexture(SKULL)

	toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	toast.text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	toast.text:SetJustifyH("LEFT")

	toast.right = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	toast.right:SetPoint("RIGHT", -10, 0)
	toast.right:SetJustifyH("RIGHT")
	toast.text:SetPoint("RIGHT", toast.right, "LEFT", -8, 0)

	AddFade(toast, TOAST_HOLD, ReleaseToast)
	return toast
end

function UI.Toast(text, right)
	if #shownToasts >= MAX_TOASTS then
		local oldest = shownToasts[1]
		oldest.fade:Stop()
		oldest:Hide()
		ReleaseToast(oldest)
	end
	local toast = table.remove(toastPool) or CreateToast()
	toast.text:SetText(text)
	toast.right:SetText(right)
	toast:SetAlpha(0)
	shownToasts[#shownToasts + 1] = toast
	LayoutToasts()
	toast:Show()
	toast.fade:Play()
	lastToastAt = GetTime()
end

-- Banner ---------------------------------------------------------------------

local banner

local function CreateBanner()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(460, 112)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
	frame:SetFrameStrata("HIGH")

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.55)

	for _, edge in ipairs({ "TOP", "BOTTOM" }) do
		local line = frame:CreateTexture(nil, "ARTWORK")
		line:SetColorTexture(1, 0.82, 0, 0.9)
		line:SetHeight(2)
		line:SetPoint(edge .. "LEFT")
		line:SetPoint(edge .. "RIGHT")
	end

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	frame.title:SetPoint("TOP", 0, -16)
	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
	frame.detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.detail:SetPoint("TOP", frame.subtitle, "BOTTOM", 0, -8)

	AddFade(frame, BANNER_HOLD)
	frame:Hide()
	return frame
end

local function ShowBanner(title, subtitle, detail, playSound)
	banner = banner or CreateBanner()
	banner.fade:Stop()
	banner.title:SetText(title)
	banner.subtitle:SetText(subtitle)
	banner.detail:SetText(detail)
	banner:SetAlpha(0)
	banner:Show()
	banner.fade:Play()
	if playSound then
		PlaySound(LEVEL_UP_SOUND)
	end
end

function UI.Banner(title, subtitle, detail, playSound)
	local wait = BANNER_AFTER_TOAST - (GetTime() - lastToastAt)
	if wait > 0 then
		C_Timer.After(wait, function()
			ShowBanner(title, subtitle, detail, playSound)
		end)
	else
		ShowBanner(title, subtitle, detail, playSound)
	end
end
