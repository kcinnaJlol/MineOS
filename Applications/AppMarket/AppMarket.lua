
local libraries = {
	buffer = "doubleBuffering",
	MineOSCore = "MineOSCore",
	image = "image",
	GUI = "GUI",
	fs = "filesystem",
	component = "component",
	unicode = "unicode",
	files = "files",
	ecs = "ECSAPI",
}

for library in pairs(libraries) do if not _G[library] then _G[library] = require(libraries[library]) end end; libraries = nil

------------------------------------------------------------------------------------------------------------------

local obj = {}
local sizes = {}
local colors = {
	topBar = 0xDDDDDD,
	main = 0xFFFFFF,
	topBarElementText = 0x444444,
	topBarElement = 0xCCCCCC,
	statusBar = 0xDDDDDD,
	statusBarText = 0x888888,
	appName = 0x262626,
	version = 0x555555,
	description = 0x888888,
	downloadButton = 0xAAAAAA,
	downloadButtonText = 0xFFFFFF,
	downloading = 0x009240,
	downloadingText = 0xFFFFFF,
	downloaded = 0xCCCCCC,
	downloadedText = 0xFFFFFF,
}

local typeFilters = {
	"Application",
	"Library",
	"Wallpaper",
	"Script",
}

local appStorePath = "MineOS/System/AppStore/"
local pathToApplications = "MineOS/System/OS/Applications.txt"
local updateImage = image.load(MineOSCore.paths.icons .. "Update.pic")
-- local topBarElements = {{title = "Приложения", type = "Application"}, {title = "Библиотеки", type = "Library"}, {title = "Обои", type = "Wallpaper"}, {title = "Другое"}, {title = "Обновления"}}
local topBarElements = {"Приложения", "Библиотеки", "Обои", "Другое", "Обновления"}
local oldApplications, newApplications, changes = {}, {}, {}
local currentApps = {}

local currentTopBarElement = 1
local from, limit, fromY = 1, 8

------------------------------------------------------------------------------------------------------------------

local function correctDouble(number)
	return string.format("%.1f", number)
end

local function status(text)
	text = unicode.sub(text, 1, sizes.width - 2)
	local y = sizes.y + sizes.height - 1
	buffer.square(sizes.x, y, sizes.width, 1, colors.statusBar, colors.statusBarText, " ")
	buffer.text(sizes.x + 1, y, colors.statusBarText, text)
	buffer.draw()
end

local function calculateSizes()
	sizes.width, sizes.height = math.floor(buffer.screen.width * 0.6), math.floor(buffer.screen.height * 0.7)
	sizes.x, sizes.y = math.floor(buffer.screen.width / 2 - sizes.width / 2), math.floor(buffer.screen.height / 2 - sizes.height / 2)
	sizes.topBarHeight = 3
	sizes.yMain = sizes.y + sizes.topBarHeight
	sizes.mainHeight = sizes.height - sizes.topBarHeight
	sizes.downloadButtonWidth = 17
	sizes.descriptionTruncateSize = sizes.width - 6 - MineOSCore.iconWidth - sizes.downloadButtonWidth
end

local function drawTopBar()
	obj.topBarButtons = GUI.toolbar(sizes.x, sizes.y, sizes.width, sizes.topBarHeight, 2, currentTopBarElement, colors.topBar, colors.topBarElementText, colors.topBarElement, colors.topBarElementText, table.unpack(topBarElements))
	obj.windowActionButtons = GUI.windowActionButtons(sizes.x + 1, sizes.y)
end

local function getIcon(url)
	local success, response = ecs.internetRequest(url)
	local path = appStorePath .. "TempIcon.pic"
	if success then
		local file = io.open(path, "w")
		file:write(response)
		file:close()
	else
		GUI.error(tostring(response), {title = {color = 0xFFDB40, text = "Ошибка при загрузке иконки"}})
	end
	return image.load(path)
end

local function getDescription(url)
	local success, response = ecs.internetRequest(url)
	if success then
		return response
	else
		GUI.error(tostring(response), {title = {color = 0xFFDB40, text = "Ошибка при загрузке описания приложения"}})
	end
end

local function getApplication(i)
	currentApps[i] = {}
	currentApps[i].name = fs.name(newApplications[i].name)

	if newApplications[i].icon then
		currentApps[i].icon = getIcon(newApplications.GitHubUserURL .. newApplications[i].icon)
	else
		if newApplications[i].type == "Application" then
			currentApps[i].icon = failureIcon
		elseif newApplications[i].type == "Wallpaper" then
			currentApps[i].icon = MineOSCore.icons.image
		elseif newApplications[i].type == "Library" then
			currentApps[i].icon = MineOSCore.icons.lua
		else
			currentApps[i].icon = MineOSCore.icons.script
		end
	end

	if newApplications[i].about then
		currentApps[i].description = getDescription(newApplications.GitHubUserURL .. newApplications[i].about)
		currentApps[i].description = ecs.stringWrap({currentApps[i].description}, sizes.descriptionTruncateSize )
	else
		currentApps[i].description = {"Описание отсутствует"}
	end

	if newApplications[i].version then
		currentApps[i].version = "Версия: " .. correctDouble(newApplications[i].version)
	else
		currentApps[i].version = "Версия не указана"
	end
end

local function checkAppExists(name, type)
	if type == "Application" then
		name = name .. ".app"
	end
	return fs.exists(name)
end

local function drawApplication(x, y, i, doNotDrawButton)
	buffer.image(x, y, currentApps[i].icon)
	buffer.text(x + 10, y, colors.appName, currentApps[i].name)
	buffer.text(x + 10, y + 1, colors.version, currentApps[i].version)
	local appExists = checkAppExists(newApplications[i].name, newApplications[i].type)
	local text = appExists and "Обновить" or "Загрузить"
	
	if not doNotDrawButton then
		local xButton, yButton = sizes.x + sizes.width - sizes.downloadButtonWidth - 2, y + 1
		if currentApps[i].buttonObject then
			currentApps[i].buttonObject.x, currentApps[i].buttonObject.y = xButton, yButton
			currentApps[i].buttonObject:draw()
		else
			currentApps[i].buttonObject = GUI.button(xButton, yButton, sizes.downloadButtonWidth, 1, colors.downloadButton, colors.downloadButtonText, 0x555555, 0xFFFFFF, text)
		end
	end

	for j = 1, #currentApps[i].description do
		buffer.text(x + 10, y + j + 1, colors.description, currentApps[i].description[j])
	end
	y = y + (#currentApps[i].description > 2 and #currentApps[i].description - 2 or 0)
	y = y + 5

	return x, y
end

local function drawPageSwitchButtons(y)
	local text = "Приложения с " .. from .. " по " .. from + limit - 1
	local textLength = unicode.len(text)
	local buttonWidth = 5
	local width = buttonWidth * 2 + textLength + 2
	local x = math.floor(sizes.x + sizes.width / 2 - width / 2)
	obj.prevPageButton = GUI.button(x, y, buttonWidth, 1, colors.downloadButton, colors.downloadButtonText, 0x262626, 0xFFFFFF, "<")
	x = x + obj.prevPageButton.width + 1
	buffer.text(x, y, colors.version, text)
	x = x + textLength + 1
	obj.nextPageButton = GUI.button(x, y, buttonWidth, 1, colors.downloadButton, colors.downloadButtonText, 0x262626, 0xFFFFFF, ">")
end

local function clearMainZone()
	buffer.square(sizes.x, sizes.yMain, sizes.width, sizes.mainHeight, 0xFFFFFF)
end

local function drawMain(refreshData)
	clearMainZone()
	local x, y = sizes.x + 2, fromY

	buffer.setDrawLimit(sizes.x, sizes.yMain, sizes.width, sizes.mainHeight)

	local matchCount = 1
	for i = 1, #newApplications do
		if newApplications[i].type == typeFilters[currentTopBarElement] then
			if matchCount >= from and matchCount <= from + limit - 1 then
				if refreshData and not currentApps[i] then
					status("Загрузка информации о приложении \"" .. newApplications[i].name .. "\"")
					getApplication(i)
				end
				x, y = drawApplication(x, y, i)
			-- else 
			-- 	ecs.error(matchCount, from, from + limit - 1)
			-- 	break
			end
			matchCount = matchCount + 1
		end
	end

	if matchCount > limit then
		drawPageSwitchButtons(y)
	end

	buffer.resetDrawLimit()
end

local function getNewApplications()
	local pathToNewApplications = "MineOS/System/OS/AppStore/NewApplications.txt"
	ecs.getFileFromUrl(oldApplications.GitHubApplicationListURL, pathToNewApplications)
	newApplications = files.loadTableFromFile(pathToNewApplications)
end

local function getChanges()
	changes = {}
	for i = 1, #oldApplications do
		-- local fileExistsInNewApplications
		for j = 1, #newApplications do
			if oldApplications[i].name == newApplications[j].name then
				if oldApplications[i].version < newApplications[j].version then
					table.insert(changes, newApplications[j])
					changes[#changes].newApplicationsIndex = j
				end
			end
		end
	end
end

local function updates()
	clearMainZone()

	if #changes > 0 then
		buffer.setDrawLimit(sizes.x, sizes.yMain, sizes.width, sizes.mainHeight)
		local x, y = sizes.x + 2, fromY
		obj.updateAllButton = GUI.button(math.floor(sizes.x + sizes.width / 2 - sizes.downloadButtonWidth / 2), y, 20, 1, colors.downloadButton, colors.downloadButtonText, 0x555555, 0xFFFFFF, "Обновить все")
		y = y + 2

		for i = from, (from + limit) do
			if not changes[i] then break end
			if not currentApps[changes[i].newApplicationsIndex] then
				status("Загрузка информации о приложении \"" .. changes[i].name .. "\"")
				getApplication(changes[i].newApplicationsIndex)
			end
			x, y = drawApplication(x, y, changes[i].newApplicationsIndex, true)
		end

		if #changes > limit then
			drawPageSwitchButtons(y)
		end
		buffer.resetDrawLimit()
	else
		local text = "У вас самое новое ПО"
		buffer.text(math.floor(sizes.x + sizes.width / 2 - unicode.len(text) / 2), math.floor(sizes.yMain + sizes.mainHeight / 2 - 1), colors.description, text)
	end
end

local function flush()
	fromY = sizes.yMain + 1
	from = 1
	fs.makeDirectory(appStorePath)
	currentApps = {}
	changes = {}
end

local function loadOldApplications()
	oldApplications = files.loadTableFromFile(pathToApplications)
end

local function saveOldApplications()
	files.saveTableToFile(pathToApplications, oldApplications)
end

local function drawAll(refreshIcons, force)
	drawTopBar()
	if currentTopBarElement == 5 then
		updates()
	else
		drawMain(refreshIcons)
	end
	buffer.draw(force)
end

local function updateImageWindow()
	clearMainZone()
	local x, y = math.floor(sizes.x + sizes.width / 2 - updateImage.width / 2), math.floor(sizes.yMain + sizes.mainHeight / 2 - updateImage.height / 2 - 2)
	buffer.image(x, y, updateImage)
	return y + updateImage.height
end

local function updateImageWindowWithText(text)
	local y = updateImageWindow() + 2
	local x = math.floor(sizes.x + sizes.width / 2 - unicode.len(text) / 2)
	buffer.text(x, y, colors.description, text)
end

local function updateAll()
	local y = updateImageWindow()
	local barWidth = math.floor(sizes.width * 0.6)
	local xBar = math.floor(sizes.x + sizes.width / 2 - barWidth / 2)
	y = y + 2
	for i = 1, #changes do
		local text = "Обновление " .. fs.name(changes[i].name)
		local xText = math.floor(sizes.x + sizes.width / 2 - unicode.len(text) / 2)
		buffer.square(sizes.x, y + 1, sizes.width, 1, 0xFFFFFF)
		buffer.text(xText, y + 1, colors.description, text)
		GUI.progressBar(xBar, y, barWidth, 1, 0xAAAAAA, 0x55FF55, i, #changes, true)
		buffer.draw()
		ecs.getOSApplication(newApplications[changes[i].newApplicationsIndex], true)
	end
	oldApplications = newApplications
	saveOldApplications()
end

------------------------------------------------------------------------------------------------------------------

-- buffer.start()
-- buffer.clear(0xFF8888)

calculateSizes()
flush()
loadOldApplications()
drawTopBar()
GUI.windowShadow(sizes.x, sizes.y, sizes.width, sizes.height, 50)
updateImageWindowWithText("Загрузка списка приложений")
buffer.draw()
getNewApplications()
drawAll(true, false)

while true do
	local e = {event.pull()}
	if e[1] == "touch" then
		if currentTopBarElement < 5 then
			for appIndex, app in pairs(currentApps) do
				if app.buttonObject:isClicked(e[3], e[4]) then
					app.buttonObject:press(0.3)
					if app.buttonObject.text == "Обновить" or app.buttonObject.text == "Загрузить" then
						app.buttonObject.text = "Загрузка"
						app.buttonObject.disabled = true
						app.buttonObject.colors.disabled.button, app.buttonObject.colors.disabled.text = colors.downloading, colors.downloadingText
						app.buttonObject:draw()
						buffer.draw()
						ecs.getOSApplication(newApplications[appIndex], true)
						app.buttonObject.text = "Установлено"
						app.buttonObject.colors.disabled.button, app.buttonObject.colors.disabled.text = colors.downloaded, colors.downloadedText
						app.buttonObject:draw()
						buffer.draw()
					end
					break
				end	
			end
		else
			if obj.updateAllButton and obj.updateAllButton:isClicked(e[3], e[4]) then
				obj.updateAllButton:press()
				updateAll()
				flush()
				drawAll()
			end
		end

		if obj.nextPageButton then
			if obj.nextPageButton:isClicked(e[3], e[4]) then
				obj.nextPageButton:press()
				fromY = sizes.yMain + 1
				from = from + limit
				drawAll(true, false)
			elseif obj.prevPageButton:isClicked(e[3], e[4]) then
				if from > limit then
					fromY = sizes.yMain + 1
					from = from - limit
					drawAll(true, false)
				end
			end
		end

		if obj.windowActionButtons.close:isClicked(e[3], e[4]) then
			obj.windowActionButtons.close:press()
			return
		end

		for key, button in pairs(obj.topBarButtons) do
			if button:isClicked(e[3], e[4]) then
				currentTopBarElement = key
				flush()
				if key < 5 then
					drawAll(true, false)
				else
					status("Получаю изменения")
					getChanges()
					drawAll(false, false)
				end
				break
			end
		end
	elseif e[1] == "scroll" then
		-- if currentTopBarElement < 5 then
			if e[5] == 1 then
				if (fromY < sizes.yMain) then
					fromY = fromY + 2
					drawAll(false, false)
				end
			else
				fromY = fromY - 2
				drawAll(false, false)
			end
		-- else
		-- 	if e[5] == 1 then

		-- 	else
		-- 	end
		-- end
	end
end









