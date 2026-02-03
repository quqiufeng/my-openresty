local _M = {}

local function format_size(bytes)
    if bytes < 1024 then
        return bytes .. ' B'
    elseif bytes < 1024 * 1024 then
        return string.format('%.2f KB', bytes / 1024)
    elseif bytes < 1024 * 1024 * 1024 then
        return string.format('%.2f MB', bytes / (1024 * 1024))
    else
        return string.format('%.2f GB', bytes / (1024 * 1024 * 1024))
    end
end

_M.format_size = format_size

-- 验证路径安全性，防止目录遍历攻击
local function safe_path(base_path, filename)
    if not filename or filename == '' then
        return nil, 'Empty filename'
    end

    -- 移除危险字符
    local sanitized = filename:gsub('[\\:]', '_')

    -- 移除 .. 防止目录遍历
    while sanitized:find('%.%.') do
        sanitized = sanitized:gsub('%.%.', '.')
    end

    -- 防止绝对路径
    if sanitized:find('^/') or sanitized:find('^\\') then
        return nil, 'Absolute path not allowed'
    end

    -- 防止 NULL 字节
    if sanitized:find('%z') then
        return nil, 'Invalid characters in path'
    end

    local full_path = base_path .. '/' .. sanitized

    -- 确保路径在允许的目录内
    local resolved = full_path:gsub('/+', '/'):gsub('/%.$', ''):gsub('/%./', '/')

    -- 检查是否在允许的目录内
    local base_resolved = base_path:gsub('/+', '/'):gsub('/%.$', ''):gsub('/%./', '/')
    if not resolved:find('^' .. base_resolved) then
        return nil, 'Path outside allowed directory'
    end

    return resolved, nil
end

_M.safe_path = safe_path

local function sanitize_filename(filename)
    if not filename or filename == '' then
        return 'file_' .. os.time()
    end

    local sanitized = filename:gsub('[^a-zA-Z0-9._-]', '_')
    sanitized = sanitized:gsub('_+', '_')

    -- 移除危险字符
    sanitized = sanitized:gsub('[\\/:]', '_')

    -- 移除 .. 防止目录遍历
    while sanitized:find('%.%.') do
        sanitized = sanitized:gsub('%.%.', '.')
    end

    if #sanitized > 255 then
        local ext = sanitized:match('%.(%w+)$') or ''
        local name = sanitized:match('(.+)%..+$') or sanitized
        if #name > 250 then
            name = name:sub(1, 250)
        end
        sanitized = name .. '.' .. ext
    end

    return sanitized
end

_M.sanitize_filename = sanitize_filename

local function get_extension(filename)
    if not filename then return nil end
    return filename:match('%.(%w+)$')
end

_M.get_extension = get_extension

local function mime_to_ext(mime)
    local mime_map = {
        ['image/jpeg'] = 'jpg',
        ['image/png'] = 'png',
        ['image/gif'] = 'gif',
        ['image/webp'] = 'webp',
        ['image/svg+xml'] = 'svg',
        ['application/pdf'] = 'pdf',
        ['application/msword'] = 'doc',
        ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'] = 'docx',
        ['application/vnd.ms-excel'] = 'xls',
        ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'] = 'xlsx',
        ['application/zip'] = 'zip',
        ['application/x-zip-compressed'] = 'zip',
        ['audio/mpeg'] = 'mp3',
        ['audio/wav'] = 'wav',
        ['video/mp4'] = 'mp4',
        ['video/x-msvideo'] = 'avi',
        ['text/plain'] = 'txt',
        ['text/csv'] = 'csv',
        ['text/html'] = 'html',
        ['application/json'] = 'json',
    }
    return mime_map[mime] or nil
end

_M.mime_to_ext = mime_to_ext

local function is_image(mime)
    local image_mimes = {
        ['image/jpeg'] = true,
        ['image/png'] = true,
        ['image/gif'] = true,
        ['image/webp'] = true,
        ['image/svg+xml'] = true,
        ['image/bmp'] = true,
    }
    return image_mimes[mime] == true
end

_M.is_image = is_image

local function is_document(mime)
    local doc_mimes = {
        ['application/pdf'] = true,
        ['application/msword'] = true,
        ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'] = true,
        ['application/vnd.ms-excel'] = true,
        ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'] = true,
        ['text/plain'] = true,
        ['text/csv'] = true,
    }
    return doc_mimes[mime] == true
end

_M.is_document = is_document

local function is_archive(mime)
    local archive_mimes = {
        ['application/zip'] = true,
        ['application/x-zip-compressed'] = true,
        ['application/x-rar-compressed'] = true,
        ['application/gzip'] = true,
    }
    return archive_mimes[mime] == true
end

_M.is_archive = is_archive

local function is_audio(mime)
    local audio_mimes = {
        ['audio/mpeg'] = true,
        ['audio/wav'] = true,
        ['audio/ogg'] = true,
        ['audio/mp3'] = true,
    }
    return audio_mimes[mime] == true
end

_M.is_audio = is_audio

local function is_video(mime)
    local video_mimes = {
        ['video/mp4'] = true,
        ['video/x-msvideo'] = true,
        ['video/webm'] = true,
        ['video/quicktime'] = true,
    }
    return video_mimes[mime] == true
end

_M.is_video = is_video

local image_mimes = {
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml'
}
_M.image_mimes = image_mimes

local document_mimes = {
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain', 'text/csv'
}
_M.document_mimes = document_mimes

local archive_mimes = {
    'application/zip', 'application/x-zip-compressed',
    'application/x-rar-compressed', 'application/gzip'
}
_M.archive_mimes = archive_mimes

local audio_mimes = {
    'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/mp3'
}
_M.audio_mimes = audio_mimes

local video_mimes = {
    'video/mp4', 'video/x-msvideo', 'video/webm', 'video/quicktime'
}
_M.video_mimes = video_mimes

return _M
