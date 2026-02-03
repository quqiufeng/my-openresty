local BaseController = require('app.core.Controller')
local FileUtil = require('app.utils.file')
local ImageUtil = require('app.utils.image')
local FileHelper = require('app.helpers.file_helper')

local ImageController = {}

function ImageController:index()
    local response = {
        message = 'Image Upload API',
        endpoints = {
            ['POST /image/upload'] = 'Upload single image',
            ['POST /image/upload/multiple'] = 'Upload multiple images',
            ['POST /image/upload/avatar'] = 'Upload and create avatar',
            ['POST /image/upload/variants'] = 'Upload and generate all variants',
            ['GET /image/info/{path}'] = 'Get image info',
            ['GET /image/thumbnail/{path}'] = 'Generate thumbnail',
            ['GET /image/optimize/{path}'] = 'Optimize/compress image',
        }
    }
    return self:json(response)
end

function ImageController:get_image_path()
    local upload_config = self.config.upload or {}
    local base_path = upload_config.path or '/var/www/web/my-openresty/uploads'
    return base_path .. '/images'
end

function ImageController:get_avatar_path()
    local upload_config = self.config.upload or {}
    local base_path = upload_config.path or '/var/www/web/my-openresty/uploads'
    return base_path .. '/avatars'
end

function ImageController:upload()
    local file = self:request():get_uploaded_file('image')
    if not file then
        return self:json({success = false, error = 'No image uploaded'}, 400)
    end

    local info = ImageUtil.get_info(file.path)
    if not info then
        return self:json({success = false, error = 'Invalid image file'}, 400)
    end

    local save_path = self:get_image_path()
    FileUtil.mkdir(save_path, 493)

    local new_name = FileHelper.sanitize_filename(file.original_name)
    local target_path = save_path .. '/' .. new_name

    local ok, err = FileUtil.copy(file.path, target_path)
    if not ok then
        return self:json({success = false, error = 'Failed to save: ' .. err}, 500)
    end

    local image_info = ImageUtil.get_image_with_metadata(target_path)

    return self:json({
        success = true,
        message = 'Image uploaded successfully',
        image = image_info
    })
end

function ImageController:uploadMultiple()
    local files = self:request():multiple_files()
    if not files or next(files) == nil then
        return self:json({success = false, error = 'No images uploaded'}, 400)
    end

    local save_path = self:get_image_path()
    FileUtil.mkdir(save_path, 493)

    local uploaded = {}
    for name, file_info in pairs(files) do
        local info = ImageUtil.get_info(file_info.path)
        if info then
            local new_name = FileHelper.sanitize_filename(file_info.original_name)
            local target_path = save_path .. '/' .. new_name
            local ok = FileUtil.copy(file_info.path, target_path)

            table.insert(uploaded, {
                name = file_info.original_name,
                saved = ok,
                info = ImageUtil.get_image_with_metadata(target_path)
            })
        end
    end

    return self:json({
        success = true,
        message = string.format('Processed %d images', #uploaded),
        images = uploaded
    })
end

function ImageController:uploadAvatar()
    local file = self:request():get_uploaded_file('avatar')
    if not file then
        return self:json({success = false, error = 'No image uploaded'}, 400)
    end

    local info = ImageUtil.get_info(file.path)
    if not info then
        return self:json({success = false, error = 'Invalid image file'}, 400)
    end

    local save_path = self:get_avatar_path()
    FileUtil.mkdir(save_path, 493)

    local image_config = self.config.image or {}
    local avatar_size = image_config.avatar_size or 200
    local quality = image_config.quality or 90

    local timestamp = os.time()
    local original_path = save_path .. '/original_' .. timestamp .. '.jpg'
    local avatar_path = save_path .. '/avatar_' .. timestamp .. '.jpg'

    FileUtil.copy(file.path, original_path)
    local result, err = ImageUtil.thumbnail(file.path, avatar_path, avatar_size, quality)

    if not result then
        return self:json({success = false, error = 'Failed to create avatar: ' .. err}, 500)
    end

    return self:json({
        success = true,
        message = 'Avatar uploaded and processed',
        original = original_path,
        avatar = avatar_path,
        info = ImageUtil.get_image_with_metadata(avatar_path)
    })
end

function ImageController:uploadVariants()
    local file = self:request():get_uploaded_file('image')
    if not file then
        return self:json({success = false, error = 'No image uploaded'}, 400)
    end

    local info = ImageUtil.get_info(file.path)
    if not info then
        return self:json({success = false, error = 'Invalid image file'}, 400)
    end

    local save_path = self:get_image_path()
    FileUtil.mkdir(save_path, 493)

    local image_config = self.config.image or {}
    local timestamp = os.time()
    local basename = 'image_' .. timestamp
    local original_path = save_path .. '/' .. basename .. '.jpg'

    FileUtil.copy(file.path, original_path)

    local options = {
        thumbnail = image_config.thumbnail_size or 150,
        medium = image_config.medium_size or 800,
        large = image_config.large_size or 1920,
        webp = image_config.webp_quality or 80,
        avatar = image_config.avatar_size or 200,
        quality = image_config.quality or 85
    }

    local variants = ImageUtil.generate_image_variants(file.path, save_path, options)

    if not variants then
        return self:json({success = false, error = 'Failed to generate variants'}, 500)
    end

    return self:json({
        success = true,
        message = 'Image uploaded with all variants generated',
        original = original_path,
        variants = variants,
        metadata = ImageUtil.get_image_with_metadata(original_path)
    })
end

function ImageController:info()
    local uri = self:request():uri()
    local path = uri:gsub('/image/info/', ''):gsub('^/', '')

    if not path or path == '' then
        return self:json({error = 'Image path required'}, 400)
    end

    local upload_config = self.config.upload or {}
    local app_path = self.config.app_path or '/var/www/web/my-openresty'
    local full_path = app_path .. '/' .. path

    if not FileUtil.exists(full_path) then
        return self:json({error = 'Image not found'}, 404)
    end

    local info = ImageUtil.get_image_with_metadata(full_path)
    if info then
        return self:json({
            success = true,
            image = info
        })
    else
        return self:json({error = 'Not a valid image'}, 400)
    end
end

function ImageController:thumbnail()
    local uri = self:request():uri()
    local path = uri:gsub('/image/thumbnail/', ''):gsub('^/', '')
    local size = tonumber(self:request():get('size')) or (self.config.image or {}).thumbnail_size or 150

    if not path or path == '' then
        return self:json({error = 'Image path required'}, 400)
    end

    local app_path = self.config.app_path or '/var/www/web/my-openresty'
    local full_path = app_path .. '/' .. path

    if not FileUtil.exists(full_path) then
        return self:json({error = 'Image not found'}, 404)
    end

    local upload_config = self.config.upload or {}
    local base_path = upload_config.path or '/var/www/web/my-openresty/uploads'
    local thumb_dir = base_path .. '/thumbnails'
    FileUtil.mkdir(thumb_dir, 493)

    local basename = path:match('([^/]+)%.%w+$') or 'image'
    local thumb_path = thumb_dir .. '/' .. basename .. '_' .. size .. '.jpg'

    local image_config = self.config.image or {}
    local quality = image_config.quality or 85

    local result, err = ImageUtil.thumbnail(full_path, thumb_path, size, quality)
    if not result then
        return self:json({error = 'Failed to generate thumbnail: ' .. err}, 500)
    end

    return self:json({
        success = true,
        original = path,
        thumbnail = thumb_path:gsub(app_path .. '/', ''),
        size = size
    })
end

function ImageController:optimize()
    local uri = self:request():uri()
    local path = uri:gsub('/image/optimize/', ''):gsub('^/', '')
    local quality = tonumber(self:request():get('quality')) or 75

    if not path or path == '' then
        return self:json({error = 'Image path required'}, 400)
    end

    local app_path = self.config.app_path or '/var/www/web/my-openresty'
    local full_path = app_path .. '/' .. path

    if not FileUtil.exists(full_path) then
        return self:json({error = 'Image not found'}, 404)
    end

    local upload_config = self.config.upload or {}
    local base_path = upload_config.path or '/var/www/web/my-openresty/uploads'
    local opt_dir = base_path .. '/optimized'
    FileUtil.mkdir(opt_dir, 493)

    local basename = path:match('([^/]+)%.%w+$') or 'image'
    local optimized_path = opt_dir .. '/' .. basename .. '_opt.jpg'

    local result, err = ImageUtil.compress(full_path, optimized_path, quality)
    if not result then
        return self:json({error = 'Failed to optimize: ' .. err}, 500)
    end

    return self:json({
        success = true,
        original = path,
        optimized = optimized_path:gsub(app_path .. '/', ''),
        original_size = result.original_size,
        new_size = result.new_size,
        compression_ratio = result.compression_ratio
    })
end

return ImageController
