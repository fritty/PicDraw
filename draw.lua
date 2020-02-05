local args = {...}
local color = require("Color")
local image = require("Image")
local gpu = require("component").gpu

--------------------------------------------------------------------------------

local bufferWidth, bufferHeight = 160, 50
local drawLimitX1, drawLimitX2, drawLimitY1, drawLimitY2 = 1, 50, 1, 50
local currentFrameBackgrounds, currentFrameForegrounds, currentFrameSymbols, newFrameBackgrounds, newFrameForegrounds, newFrameSymbols

--------------------------------------------------------------------------------

local function drawImage(startX, startY, picture, blendForeground)
	local bufferIndex, pictureIndex, imageWidth, background, foreground, alpha, symbol = bufferWidth * (startY - 1) + startX, 3, picture[1]
	local bufferIndexStepOnReachOfImageWidth = bufferWidth - imageWidth

	for y = startY, startY + picture[2] - 1 do
		if y >= drawLimitY1 and y <= drawLimitY2 then
			for x = startX, startX + imageWidth - 1 do
				if x >= drawLimitX1 and x <= drawLimitX2 then
					alpha, symbol = picture[pictureIndex + 2], picture[pictureIndex + 3]
					
					-- If it's fully transparent pixel
					if alpha == 0 then
						newFrameBackgrounds[bufferIndex], newFrameForegrounds[bufferIndex] = picture[pictureIndex], picture[pictureIndex + 1]
					-- If it has some transparency
					elseif alpha > 0 and alpha < 1 then
						newFrameBackgrounds[bufferIndex] = color.blend(newFrameBackgrounds[bufferIndex], picture[pictureIndex], alpha)
						
						if blendForeground then
							newFrameForegrounds[bufferIndex] = color.blend(newFrameForegrounds[bufferIndex], picture[pictureIndex + 1], alpha)
						else
							newFrameForegrounds[bufferIndex] = picture[pictureIndex + 1]
						end
					-- If it's not transparent with whitespace
					elseif symbol ~= " " then
						newFrameForegrounds[bufferIndex] = picture[pictureIndex + 1]
					end

					newFrameSymbols[bufferIndex] = symbol
				end

				bufferIndex, pictureIndex = bufferIndex + 1, pictureIndex + 4
			end

			bufferIndex = bufferIndex + bufferIndexStepOnReachOfImageWidth
		else
			bufferIndex, pictureIndex = bufferIndex + bufferWidth, pictureIndex + imageWidth * 4
		end
	end
end

local function drawRectangle(x, y, width, height, background, foreground, symbol, transparency) 
	local index, indexStepOnReachOfSquareWidth = bufferWidth * (y - 1) + x, bufferWidth - width
	for j = y, y + height - 1 do
		if j >= drawLimitY1 and j <= drawLimitY2 then
			for i = x, x + width - 1 do
				if i >= drawLimitX1 and i <= drawLimitX2 then
					if transparency then
						newFrameBackgrounds[index], newFrameForegrounds[index] =
							color.blend(newFrameBackgrounds[index], background, transparency),
							color.blend(newFrameForegrounds[index], background, transparency)
					else
						newFrameBackgrounds[index], newFrameForegrounds[index], newFrameSymbols[index] = background, foreground, symbol
					end
				end

				index = index + 1
			end

			index = index + indexStepOnReachOfSquareWidth
		else
			index = index + bufferWidth
		end
	end
end

--------------------------------------------------------------------------------

local function update(force)	
	local index, indexStepOnEveryLine, changes = bufferWidth * (drawLimitY1 - 1) + drawLimitX1, (bufferWidth - drawLimitX2 + drawLimitX1 - 1), {}
	local x, equalChars, equalCharsIndex, charX, charIndex, currentForeground
	local currentFrameBackground, currentFrameForeground, currentFrameSymbol, changesCurrentFrameBackground, changesCurrentFrameBackgroundCurrentFrameForeground

	local changesCurrentFrameBackgroundCurrentFrameForegroundIndex

	for y = drawLimitY1, drawLimitY2 do
		x = drawLimitX1
		while x <= drawLimitX2 do			
			-- Determine if some pixel data was changed (or if <force> argument was passed)
			if
				currentFrameBackgrounds[index] ~= newFrameBackgrounds[index] or
				currentFrameForegrounds[index] ~= newFrameForegrounds[index] or
				currentFrameSymbols[index] ~= newFrameSymbols[index] or
				force
			then
				-- Make pixel at both frames equal
				currentFrameBackground, currentFrameForeground, currentFrameSymbol = newFrameBackgrounds[index], newFrameForegrounds[index], newFrameSymbols[index]
				currentFrameBackgrounds[index] = currentFrameBackground
				currentFrameForegrounds[index] = currentFrameForeground
				currentFrameSymbols[index] = currentFrameSymbol

				-- Look for pixels with equal chars from right of current pixel
				equalChars, equalCharsIndex, charX, charIndex = {currentFrameSymbol}, 2, x + 1, index + 1
				while charX <= drawLimitX2 do
					-- Pixels becomes equal only if they have same background and (whitespace char or same foreground)
					if	
						currentFrameBackground == newFrameBackgrounds[charIndex] and
						(
							newFrameSymbols[charIndex] == " " or
							currentFrameForeground == newFrameForegrounds[charIndex]
						)
					then
						-- Make pixel at both frames equal
					 	currentFrameBackgrounds[charIndex] = newFrameBackgrounds[charIndex]
					 	currentFrameForegrounds[charIndex] = newFrameForegrounds[charIndex]
					 	currentFrameSymbols[charIndex] = newFrameSymbols[charIndex]

					 	equalChars[equalCharsIndex], equalCharsIndex = currentFrameSymbols[charIndex], equalCharsIndex + 1
					else
						break
					end

					charX, charIndex = charX + 1, charIndex + 1
				end

				-- Group pixels that need to be drawn by background and foreground
				changes[currentFrameBackground] = changes[currentFrameBackground] or {}
				changesCurrentFrameBackground = changes[currentFrameBackground]
				changesCurrentFrameBackground[currentFrameForeground] = changesCurrentFrameBackground[currentFrameForeground] or {index = 1}
				changesCurrentFrameBackgroundCurrentFrameForeground = changesCurrentFrameBackground[currentFrameForeground]
				changesCurrentFrameBackgroundCurrentFrameForegroundIndex = changesCurrentFrameBackgroundCurrentFrameForeground.index
				
				changesCurrentFrameBackgroundCurrentFrameForeground[changesCurrentFrameBackgroundCurrentFrameForegroundIndex], changesCurrentFrameBackgroundCurrentFrameForegroundIndex = x, changesCurrentFrameBackgroundCurrentFrameForegroundIndex + 1
				changesCurrentFrameBackgroundCurrentFrameForeground[changesCurrentFrameBackgroundCurrentFrameForegroundIndex], changesCurrentFrameBackgroundCurrentFrameForegroundIndex = y, changesCurrentFrameBackgroundCurrentFrameForegroundIndex + 1
				changesCurrentFrameBackgroundCurrentFrameForeground[changesCurrentFrameBackgroundCurrentFrameForegroundIndex], changesCurrentFrameBackgroundCurrentFrameForegroundIndex = table.concat(equalChars), changesCurrentFrameBackgroundCurrentFrameForegroundIndex + 1
				
				x, index, changesCurrentFrameBackgroundCurrentFrameForeground.index = x + equalCharsIndex - 2, index + equalCharsIndex - 2, changesCurrentFrameBackgroundCurrentFrameForegroundIndex
			end

			x, index = x + 1, index + 1
		end

		index = index + indexStepOnEveryLine
	end
	
	-- Draw grouped pixels on screen
	for background, foregrounds in pairs(changes) do
		gpu.setBackground(background)

		for foreground, pixels in pairs(foregrounds) do
			if currentForeground ~= foreground then
				gpu.setForeground(foreground)
				currentForeground = foreground
			end

			for i = 1, #pixels, 3 do
				gpu.set(pixels[i], pixels[i + 1], pixels[i + 2])
			end
		end
	end

	changes = nil
end


local function flush(width, height)
	if not width or not height then
		width, height = gpu.getResolution()
	end

	currentFrameBackgrounds, currentFrameForegrounds, currentFrameSymbols, newFrameBackgrounds, newFrameForegrounds, newFrameSymbols = {}, {}, {}, {}, {}, {}
	bufferWidth = width
	bufferHeight = height
	resetDrawLimit()

	for y = 1, bufferHeight do
		for x = 1, bufferWidth do
			table.insert(currentFrameBackgrounds, 0x010101)
			table.insert(currentFrameForegrounds, 0xFEFEFE)
			table.insert(currentFrameSymbols, " ")

			table.insert(newFrameBackgrounds, 0x010101)
			table.insert(newFrameForegrounds, 0xFEFEFE)
			table.insert(newFrameSymbols, " ")
		end
	end
end

local function resetDrawLimit()
	drawLimitX1, drawLimitY1, drawLimitX2, drawLimitY2 = 1, 1, bufferWidth, bufferHeight
end

local function clear(color, transparency)
	drawRectangle(1, 1, bufferWidth, bufferHeight, color or 0x0, 0x000000, " ", transparency)
end

--------------------------------------------------------------------------------
function load(path)
	local file, reason = io.open(path, "r")
	if file then
		local readedSignature = file:read(#"OCIF")
		if readedSignature == "OCIF" then
			local encodingMethod = string.byte(file:read(1))
			if encodingMethod == 5  then
				local picture = {}
				picture[1] = string.byte(file:read(2))file:readBytes(2)
	                        picture[2] = file:readBytes(2)

	                        for i = 1, image.getWidth(picture) * image.getHeight(picture) do
		                  table.insert(picture, color.to24Bit(file:readBytes(1)))
		                  table.insert(picture, color.to24Bit(file:readBytes(1)))
		                  table.insert(picture, file:readBytes(1) / 255)
		                  table.insert(picture, file:readUnicodeChar())
	                end
				file:close()

				if result then
					return picture
				else
					return false, "Failed to load OCIF image: " .. tostring(reason)
				end
			else
				file:close()
				return false, "Failed to load OCIF image: encoding method \"" .. tostring(encodingMethod) .. "\" is not supported"
			end
		else
			file:close()
			return false, "Failed to load OCIF image: binary signature \"" .. tostring(readedSignature) .. "\" is not valid"
		end
	else
		return false, "Failed to open file \"" .. tostring(path) .. "\" for reading: " .. tostring(reason)
	end
end

--------------------------------------------------------------------------------

local pic = image.load(args[1])

flush(160, 50)
drawImage(1, 1, pic, 0)
update(0)
