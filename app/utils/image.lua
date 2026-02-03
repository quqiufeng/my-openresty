local _M = {}

local ffi = require('ffi')
local C = ffi.C

ffi.cdef[[
    typedef struct {
        unsigned char r, g, b, a;
    } gdPixel;
]]

local function check_libgd_available()
    local ok, libgd = pcall(require, 'resty.libgd')
    return ok and libgd
end

function _M.is_available()
    return check_libgd_available()
end

function _M.get_info(filepath)
    if not filepath or not (function()
        local f = io.open(filepath, 'rb')
        if f then
            local header = f:read(8)
            f:close()
            return header
        end
        return nil
    end)() then
        return nil, 'File not found or not readable'
    end

    local f = io.open(filepath, 'rb')
    local header = f:read(24)
    f:close()

    local info = {
        width = nil,
        height = nil,
        format = nil,
        size = nil,
        mime = nil
    }

    local size = (function()
        local f = io.open(filepath, 'rb')
        local s = f:seek('end')
        f:close()
        return s
    end)()
    info.size = size

    if header:sub(1, 3) == '\137PNG' then
        info.format = 'PNG'
        info.mime = 'image/png'
        local png = io.popen('file -b --mime-type ' .. filepath)
        local mime = png:read('*a'):gsub('%s+$', '')
        png:close()
        info.mime = mime
    elseif header:sub(1, 3) == '\255\216\255' then
        info.format = 'JPEG'
        info.mime = 'image/jpeg'
    elseif header:sub(1, 4) == 'GIF87a' or header:sub(1, 4) == 'GIF89a' then
        info.format = 'GIF'
        info.mime = 'image/gif'
    elseif header:sub(1, 4) == 'RIFF' and header:sub(9, 12) == 'WEBP' then
        info.format = 'WebP'
        info.mime = 'image/webp'
    elseif header:sub(1, 4) == '\x89PNG' then
        info.format = 'PNG'
        info.mime = 'image/png'
    else
        local cmd = 'file -b --mime-type ' .. filepath:gsub("'", "'\\''")
        local pipe = io.popen(cmd)
        local output = pipe:read('*a') or ''
        pipe:close()
        output = output:gsub('%s+$', '')

        if output:find('image') then
            info.mime = output
            local ext = filepath:match('%.(%w+)$')
            info.format = ext and ext:upper() or 'Unknown'
        else
            return nil, 'Not an image file'
        end
    end

    if info.format == 'PNG' then
        local cmd = 'pnginfo ' .. filepath:gsub("'", "'\\''") .. ' 2>/dev/null'
        local pipe = io.popen(cmd)
        local output = pipe:read('*a') or ''
        pipe:close()
        local w, h = output:match('(%d+)x(%d+)')
        if w and h then
            info.width = tonumber(w)
            info.height = tonumber(h)
        end
    elseif info.format == 'JPEG' then
        local cmd = 'identify -format "%w %h" ' .. filepath:gsub("'", "'\\''") .. ' 2>/dev/null'
        local pipe = io.popen(cmd)
        local output = pipe:read('*a') or ''
        pipe:close()
        local w, h = output:match('(%d+)%s+(%d+)')
        if w and h then
            info.width = tonumber(w)
            info.height = tonumber(h)
        end
    elseif info.format == 'GIF' then
        local cmd = 'identify -format "%w %h" ' .. filepath:gsub("'", "'\\''") .. ' 2>/dev/null'
        local pipe = io.popen(cmd)
        local output = pipe:read('*a') or ''
        pipe:close()
        local w, h = output:match('(%d+)%s+(%d+)')
        if w and h then
            info.width = tonumber(w)
            info.height = tonumber(h)
        end
    elseif info.format == 'WebP' then
        local cmd = 'file ' .. filepath:gsub("'", "'\\''")
        local pipe = io.popen(cmd)
        local output = pipe:read('*a') or ''
        pipe:close()
        local w, h = output:match('(%d+)x(%d+)')
        if w and h then
            info.width = tonumber(w)
            info.height = tonumber(h)
        end
    end

    return info
end

function _M.get_dimensions(filepath)
    local info, err = _M.get_info(filepath)
    if not info then
        return nil, err
    end
    return info.width, info.height
end

function _M.resize(filepath, output_path, width, height, quality)
    if not filepath or not output_path then
        return nil, 'Invalid filepath or output_path'
    end

    if not _M.get_info(filepath) then
        return nil, 'Not a valid image file'
    end

    quality = quality or 85

    local cmd = string.format(
        'convert -resize %dx%d -quality %d %s %s 2>&1',
        tonumber(width) or 0,
        tonumber(height) or 0,
        tonumber(quality),
        filepath:gsub("'", "'\\''"),
        output_path:gsub("'", "'\\''")
    )

    local pipe = io.popen(cmd)
    local output = pipe:read('*a')
    local status = pipe:close()

    if status then
        return {
            original = filepath,
            output = output_path,
            width = width,
            height = height,
            resized = true
        }
    else
        return nil, output or 'Resize failed'
    end
end

function _M.resize_max(filepath, output_path, max_size, quality)
    if not filepath or not output_path then
        return nil, 'Invalid filepath or output_path'
    end

    local info, err = _M.get_info(filepath)
    if not info then
        return nil, err
    end

    if not info.width or not info.height then
        return nil, 'Cannot get image dimensions'
    end

    local ratio = info.width / info.height
    local new_width, new_height

    if info.width > info.height then
        if info.width > max_size then
            new_width = max_size
            new_height = math.floor(max_size / ratio)
        else
            new_width = info.width
            new_height = info.height
        end
    else
        if info.height > max_size then
            new_height = max_size
            new_width = math.floor(max_size * ratio)
        else
            new_width = info.width
            new_height = info.height
        end
    end

    return _M.resize(filepath, output_path, new_width, new_height, quality)
end

function _M.crop(filepath, output_path, x, y, width, height, quality)
    if not filepath or not output_path then
        return nil, 'Invalid filepath or output_path'
    end

    quality = quality or 85

    local cmd = string.format(
        'convert -crop %dx%d+%d+%d -quality %d %s %s 2>&1',
        tonumber(width) or 0,
        tonumber(height) or 0,
        tonumber(x) or 0,
        tonumber(y) or 0,
        tonumber(quality),
        filepath:gsub("'", "'\\''"),
        output_path:gsub("'", "'\\''")
    )

    local pipe = io.popen(cmd)
    local output = pipe:read('*a')
    local status = pipe:close()

    if status then
        return {
            original = filepath,
            output = output_path,
            x = x,
            y = y,
            width = width,
            height = height,
            cropped = true
        }
    else
        return nil, output or 'Crop failed'
    end
end

function _M.thumbnail(filepath, output_path, size, quality)
    if not filepath or not output_path then
        return nil, 'Invalid filepath or output_path'
    end

    quality = quality or 85

    local cmd = string.format(
        'convert -thumbnail %dx%d^ -gravity center -extent %dx%d -quality %d %s %s 2>&1',
        tonumber(size) or 100,
        tonumber(size) or 100,
        tonumber(size) or 100,
        tonumber(size) or 100,
        tonumber(quality),
        filepath:gsub("'", "'\\''"),
        output_path:gsub("'", "'\\''")
    )

    local pipe = io.popen(cmd)
    local output = pipe:read('*a')
    local status = pipe:close()

    if status then
        return {
            original = filepath,
            output = output_path,
            size = size,
            thumbnail = true
        }
    else
        return nil, output or 'Thumbnail generation failed'
    end
end

function _M.convert_format(filepath, output_path, format, quality)
    if not filepath or not output_path then
        return nil, 'Invalid filepath or output_path'
    end

    quality = quality or 85

    local cmd = string.format(
        'convert -quality %d %s %s 2>&1',
        tonumber(quality),
        filepath:gsub("'", "'\\''"),
        output_path:gsub("'", "'\\''")
    )

    local pipe = io.popen(cmd)
    local output = pipe:read('*a')
    local status = pipe:close()

    if status then
        return {
            original = filepath,
            output = output_path,
            format = format,
            converted = true
        }
    else
        return nil, output or 'Format conversion failed'
    end
end

function _M.rotate(filepath, output_path, degrees, quality)
    if not filepath or not output_path then
        return nil, 'Invalid filepath or output_path'
    end

    quality = quality or 85

    local cmd = string.format(
        'convert -rotate %d -quality %d %s %s 2>&1',
        tonumber(degrees) or 0,
        tonumber(quality),
        filepath:gsub("'", "'\\''"),
        output_path:gsub("'", "'\\''")
    )

    local pipe = io.popen(cmd)
    local output = pipe:read('*a')
    local status = pipe:close()

    if status then
        return {
            original = filepath,
            output = output_path,
            degrees = degrees,
            rotated = true
        }
    else
        return nil, output or 'Rotate failed'
    end
end

function _M.watermark(filepath, watermark_path, output_path, position, opacity)
    if not filepath or not watermark_path or not output_path then
        return nil, 'Invalid filepath'
    end

    position = position or 'southeast'
    opacity = opacity or 0.5

    local gravity = 'SE'
    if position == 'north' then gravity = 'N'
    elseif position == 'south' then gravity = 'S'
    elseif position == 'east' then gravity = 'E'
    elseif position == 'west' then gravity = 'W'
    elseif position == 'center' then gravity = 'C'
    elseif position == 'northeast' then gravity = 'NE'
    elseif position == 'northwest' then gravity = 'NW'
    elseif position == 'southeast' then gravity = 'SE'
    elseif position == 'southwest' then gravity = 'SW'
    end

    local cmd = string.format(
        'composite -gravity %s -opacity %.2f %s %s %s 2>&1',
        gravity,
        tonumber(opacity) or 0.5,
        watermark_path:gsub("'", "'\\''"),
        filepath:gsub("'", "'\\''"),
        output_path:gsub("'", "'\\''")
    )

    local pipe = io.popen(cmd)
    local output = pipe:read('*a')
    local status = pipe:close()

    if status then
        return {
            original = filepath,
            watermark = watermark_path,
            output = output_path,
            position = position,
            opacity = opacity,
            watermarked = true
        }
    else
        return nil, output or 'Watermark failed'
    end
end

function _M.compress(filepath, output_path, quality)
    if not filepath or not output_path then
        return nil, 'Invalid filepath'
    end

    quality = tonumber(quality) or 75

    local info, err = _M.get_info(filepath)
    if not info then
        return nil, err
    end

    local cmd = string.format(
        'convert -quality %d %s %s 2>&1',
        quality,
        filepath:gsub("'", "'\\''"),
        output_path:gsub("'", "'\\''")
    )

    local pipe = io.popen(cmd)
    local output = pipe:read('*a')
    local status = pipe:close()

    if status then
        local orig_size = (function()
            local f = io.open(filepath, 'rb')
            local s = f:seek('end')
            f:close()
            return s
        end)()

        local new_size = (function()
            local f = io.open(output_path, 'rb')
            local s = f:seek('end')
            f:close()
            return s
        end)()

        return {
            original = filepath,
            output = output_path,
            original_size = orig_size,
            new_size = new_size,
            compression_ratio = string.format('%.1f%%', (1 - new_size / orig_size) * 100),
            compressed = true
        }
    else
        return nil, output or 'Compression failed'
    end
end

function _M.is_image(filepath)
    local info, err = _M.get_info(filepath)
    return info ~= nil, err
end

function _M.get_format(filepath)
    local info, err = _M.get_info(filepath)
    if info then
        return info.format
    end
    return nil, err
end

function _M.get_mime_type(filepath)
    local info, err = _M.get_info(filepath)
    if info then
        return info.mime
    end
    return nil, err
end

function _M.get_size_formatted(filepath)
    local info = _M.get_info(filepath)
    if info and info.size then
        local size = info.size
        if size < 1024 then
            return size .. ' B'
        elseif size < 1024 * 1024 then
            return string.format('%.2f KB', size / 1024)
        elseif size < 1024 * 1024 * 1024 then
            return string.format('%.2f MB', size / (1024 * 1024))
        else
            return string.format('%.2f GB', size / (1024 * 1024 * 1024))
        end
    end
    return nil
end

function _M.get_image_with_metadata(filepath)
    local info = _M.get_info(filepath)
    if not info then
        return nil
    end

    local meta = {
        path = filepath,
        format = info.format,
        mime = info.mime,
        width = info.width,
        height = info.height,
        size = info.size,
        size_formatted = _M.get_size_formatted(filepath),
        aspect_ratio = nil,
        megapixels = nil
    }

    if info.width and info.height then
        meta.aspect_ratio = string.format('%.2f', info.width / info.height)
        meta.megapixels = string.format('%.2f', (info.width * info.height) / 1000000)
    end

    return meta
end

function _M.generate_image_variants(filepath, base_path, options)
    options = options or {}
    local basename = (function()
        local name = filepath:match('([^/]+)$') or 'image'
        return name:gsub('%.[^.]+$', '')
    end)()

    local variants = {}
    local info = _M.get_info(filepath)
    if not info then
        return nil, 'Invalid image file'
    end

    if options.thumbnail then
        local thumb_path = base_path .. '/' .. basename .. '_thumb.jpg'
        local result, err = _M.thumbnail(filepath, thumb_path, options.thumbnail, options.quality or 80)
        if result then
            variants.thumbnail = thumb_path
        end
    end

    if options.medium then
        local medium_path = base_path .. '/' .. basename .. '_medium.jpg'
        local result, err = _M.resize_max(filepath, medium_path, options.medium, options.quality or 85)
        if result then
            variants.medium = medium_path
        end
    end

    if options.large then
        local large_path = base_path .. '/' .. basename .. '_large.jpg'
        local result, err = _M.resize_max(filepath, large_path, options.large, options.quality or 90)
        if result then
            variants.large = large_path
        end
    end

    if options.webp then
        local webp_path = base_path .. '/' .. basename .. '.webp'
        local result, err = _M.compress(filepath, webp_path, options.webp_quality or 80)
        if result then
            variants.webp = webp_path
        end
    end

    if options.avatar then
        local avatar_path = base_path .. '/' .. basename .. '_avatar.jpg'
        local result, err = _M.thumbnail(filepath, avatar_path, options.avatar, options.quality or 85)
        if result then
            variants.avatar = avatar_path
        end
    end

    variants.original = filepath

    return variants
end

return _M
