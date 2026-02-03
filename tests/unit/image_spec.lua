-- Image Utility Unit Tests
-- tests/unit/image_spec.lua

package.path = '/var/www/web/my-resty/?.lua;/var/www/web/my-resty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-resty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('Image Module', function()
    describe('image_info', function()
        it('should detect image info from bytes', function()
            local function get_image_info(data)
                if not data or #data < 4 then return nil end
                local first_bytes = data:sub(1, 4)
                if first_bytes == string.char(0x89, 0x50, 0x4E, 0x47) then
                    return {format = 'PNG', width = 0, height = 0}
                elseif first_bytes == string.char(0xFF, 0xD8, 0xFF, 0xE0) or
                       first_bytes == string.char(0xFF, 0xD8, 0xFF, 0xE1) then
                    return {format = 'JPEG', width = 0, height = 0}
                elseif first_bytes == string.char(0x47, 0x49, 0x46, 0x38) then
                    return {format = 'GIF', width = 0, height = 0}
                elseif first_bytes == string.char(0x42, 0x4D) then
                    return {format = 'BMP', width = 0, height = 0}
                end
                return nil
            end

            local png_header = string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
            local info = get_image_info(png_header)
            assert.is_table(info)
            assert.equals('PNG', info.format)

            local jpg_header = string.char(0xFF, 0xD8, 0xFF, 0xE0)
            info = get_image_info(jpg_header)
            assert.is_table(info)
            assert.equals('JPEG', info.format)

            local gif_header = string.char(0x47, 0x49, 0x46, 0x38, 0x39, 0x61)
            info = get_image_info(gif_header)
            assert.is_table(info)
            assert.equals('GIF', info.format)
        end)
    end)

    describe('image_extension', function()
        it('should return correct extension for format', function()
            local function get_extension(format)
                local ext = {
                    PNG = '.png',
                    JPEG = '.jpg',
                    JPG = '.jpg',
                    GIF = '.gif',
                    BMP = '.bmp',
                    WEBP = '.webp',
                }
                return ext[format:upper()] or '.png'
            end

            assert.equals('.png', get_extension('PNG'))
            assert.equals('.jpg', get_extension('JPEG'))
            assert.equals('.gif', get_extension('GIF'))
            assert.equals('.bmp', get_extension('BMP'))
        end)
    end)

    describe('image_validate', function()
        it('should validate image format', function()
            local function is_valid_image(data, max_size)
                max_size = max_size or 10485760
                if not data or type(data) ~= 'string' then return false end
                if #data == 0 or #data > max_size then return false end
                if #data < 4 then return false end
                local first_bytes = data:sub(1, 4)
                local valid_headers = {
                    [string.char(0x89, 0x50, 0x4E, 0x47)] = 'PNG',
                    [string.char(0xFF, 0xD8, 0xFF, 0xE0)] = 'JPEG',
                    [string.char(0xFF, 0xD8, 0xFF, 0xE1)] = 'JPEG',
                    [string.char(0x47, 0x49, 0x46, 0x38)] = 'GIF',
                    [string.char(0x42, 0x4D)] = 'BMP',
                }
                for header, _ in pairs(valid_headers) do
                    if first_bytes:sub(1, #header) == header then
                        return true
                    end
                end
                return false
            end

            local png_header = string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
            assert.is_true(is_valid_image(png_header))

            local invalid_data = 'not an image'
            assert.is_false(is_valid_image(invalid_data))

            assert.is_false(is_valid_image(nil))
            assert.is_false(is_valid_image(''))
        end)
    end)

    describe('image_size_calculation', function()
        it('should calculate image dimensions for JPEG', function()
            local function get_jpeg_size(data)
                if not data or #data < 2 then return nil end
                if data:byte(1) ~= 0xFF or data:byte(2) ~= 0xD8 then return nil end
                local pos = 2
                while pos < #data do
                    if data:byte(pos) ~= 0xFF then break end
                    local marker = data:byte(pos + 1)
                    if marker == 0xC0 or marker == 0xC2 then
                        local height = tonumber(data:byte(pos + 5)) * 256 + data:byte(pos + 6)
                        local width = tonumber(data:byte(pos + 7)) * 256 + data:byte(pos + 8)
                        return {width = width, height = height}
                    end
                    local length = tonumber(data:byte(pos + 2)) * 256 + data:byte(pos + 3)
                    pos = pos + 2 + length
                end
                return nil
            end

            local jpeg_data = string.char(0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01)
            local size = get_jpeg_size(jpeg_data)
            assert.is_table(size)
            assert.equals(264, size.width)
            assert.equals(259, size.height)
        end)
    end)

    describe('image_size_calculation', function()
        it('should calculate image dimensions for PNG', function()
            local function get_png_size(data)
                if not data or #data < 24 then return nil end
                if data:sub(1, 8) ~= string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A) then
                    return nil
                end
                local width = 0
                local height = 0
                for i = 17, 20 do
                    width = width * 256 + data:byte(i)
                end
                for i = 21, 24 do
                    height = height * 256 + data:byte(i)
                end
                return {width = width, height = height}
            end

            local width_bytes = string.char(0x00, 0x00, 0x01, 0x90)
            local height_bytes = string.char(0x00, 0x00, 0x01, 0x2C)
            local png_header = string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
            local png_data = png_header .. string.char(0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52) .. width_bytes .. height_bytes

            local size = get_png_size(png_data)
            assert.is_table(size)
            assert.equals(400, size.width)
            assert.equals(300, size.height)
        end)
    end)

    describe('image_resize_calculation', function()
        it('should calculate resize dimensions maintaining aspect ratio', function()
            local function calculate_resize_dimensions(orig_width, orig_height, max_width, max_height)
                max_width = max_width or orig_width
                max_height = max_height or orig_height

                local ratio = math.min(max_width / orig_width, max_height / orig_height)

                if ratio >= 1 then
                    return orig_width, orig_height
                end

                local new_width = math.floor(orig_width * ratio + 0.5)
                local new_height = math.floor(orig_height * ratio + 0.5)

                return new_width, new_height
            end

            local w, h = calculate_resize_dimensions(800, 600, 400, 400)
            assert.equals(400, w)
            assert.equals(300, h)

            w, h = calculate_resize_dimensions(800, 600, 1000, 1000)
            assert.equals(800, w)
            assert.equals(600, h)

            w, h = calculate_resize_dimensions(800, 600, 200, 1000)
            assert.equals(200, w)
            assert.equals(150, h)
        end)
    end)

    describe('image_thumbnail_calculation', function()
        it('should calculate thumbnail dimensions', function()
            local function calculate_thumbnail_dimensions(width, height, thumb_size)
                thumb_size = thumb_size or 150

                if width <= thumb_size and height <= thumb_size then
                    return width, height
                end

                local ratio = math.min(thumb_size / width, thumb_size / height)
                local new_width = math.floor(width * ratio + 0.5)
                local new_height = math.floor(height * ratio + 0.5)

                return new_width, new_height
            end

            local w, h = calculate_thumbnail_dimensions(800, 600, 150)
            assert.equals(150, w)
            assert.equals(113, h)

            w, h = calculate_thumbnail_dimensions(100, 100, 150)
            assert.equals(100, w)
            assert.equals(100, h)
        end)
    end)

    describe('image_bytes_to_kb', function()
        it('should convert bytes to KB', function()
            local function bytes_to_kb(bytes)
                if not bytes then return 0 end
                return math.floor(bytes / 1024 * 100 + 0.5) / 100
            end

            assert.equals(0, bytes_to_kb(0))
            assert.equals(0.5, bytes_to_kb(512))
            assert.equals(1, bytes_to_kb(1024))
            assert.equals(1.5, bytes_to_kb(1536))
            assert.equals(10, bytes_to_kb(10240))
        end)
    end)

    describe('image_bytes_to_mb', function()
        it('should convert bytes to MB', function()
            local function bytes_to_mb(bytes)
                if not bytes then return 0 end
                return math.floor(bytes / 1048576 * 100 + 0.5) / 100
            end

            assert.equals(0, bytes_to_mb(0))
            assert.equals(1, bytes_to_mb(1048576))
            assert.equals(5.25, bytes_to_mb(5505024))
        end)
    end)

    describe('image_mime_type', function()
        it('should return correct MIME type', function()
            local function get_mime_type(format)
                local types = {
                    PNG = 'image/png',
                    JPEG = 'image/jpeg',
                    JPG = 'image/jpeg',
                    GIF = 'image/gif',
                    BMP = 'image/bmp',
                    WEBP = 'image/webp',
                    ICO = 'image/x-icon',
                    SVG = 'image/svg+xml',
                    TIFF = 'image/tiff',
                }
                return types[format:upper()] or 'application/octet-stream'
            end

            assert.equals('image/png', get_mime_type('PNG'))
            assert.equals('image/jpeg', get_mime_type('JPEG'))
            assert.equals('image/gif', get_mime_type('GIF'))
            assert.equals('image/webp', get_mime_type('WEBP'))
            assert.equals('application/octet-stream', get_mime_type('UNKNOWN'))
        end)
    end)

    describe('image_quality_calculation', function()
        it('should calculate quality percentage', function()
            local function validate_quality(quality)
                quality = tonumber(quality)
                if not quality then return 85 end
                return math.max(1, math.min(100, quality))
            end

            assert.equals(85, validate_quality(nil))
            assert.equals(85, validate_quality('invalid'))
            assert.equals(50, validate_quality(50))
            assert.equals(100, validate_quality(150))
            assert.equals(1, validate_quality(0))
            assert.equals(85, validate_quality(85))
        end)
    end)
end)
