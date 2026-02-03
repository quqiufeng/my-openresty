local _M = {}

local ffi = require('ffi')

ffi.cdef[[
    typedef struct gdImageStruct {
        int sx;
        int sy;
        int colorsTotal;
        int alphaFlag;
        int transparent;
        int interlace;
        int trueColor;
        unsigned long **pixels;
        int *polyInts;
        int polyAllocated;
        int arcMode;
        void *tp;
    } gdImage;

    typedef gdImage *gdImagePtr;

    gdImagePtr gdImageCreate(int sx, int sy);
    gdImagePtr gdImageCreateTrueColor(int sx, int sy);
    void gdImageDestroy(gdImagePtr im);

    void gdImageFilledRectangle(gdImagePtr im, int x1, int y1, int x2, int y2, int color);

    int gdImageColorAllocate(gdImagePtr im, int r, int g, int b);
    int gdImageColorAllocateAlpha(gdImagePtr im, int r, int g, int b, int a);
    int gdImageColorTransparent(gdImagePtr im, int color);
    int gdImageGetPixel(gdImagePtr im, int x, int y);

    void gdImageSetPixel(gdImagePtr im, int x, int y, int color);
    void gdImageLine(gdImagePtr im, int x1, int y1, int x2, int y2, int color);

    void gdImageString(gdImagePtr im, int font, int x, int y, unsigned char *str, int color);
    void gdImageStringUp(gdImagePtr im, int font, int x, int y, unsigned char *str, int color);

    int gdImageFontWidth(int font);
    int gdImageFontHeight(int font);

    void gdImagePng(gdImagePtr im, FILE *out);
    void gdImagePngPtr(gdImagePtr im, void **png, int *size);
    void gdFree(void *m);

    void gdImageBlur(gdImagePtr im);
    void gdImagePixelate(gdImagePtr im, int blocksize, int mode);
    void gdImageRotate90(gdImagePtr im, int direction);

    unsigned char *gdImagePngPtr(gdImagePtr im, int *size);
]]

local libgd = nil
local gd_libs = {
    'gd.so', 'libgd.so.3', 'libgd.so.2', 'libgd.so', nil
}

for _, name in ipairs(gd_libs) do
    local ok = pcall(function()
        libgd = ffi.load(name or 'gd')
    end)
    if libgd then break end
end

local function check_libgd()
    return libgd ~= nil
end

_M.is_available = check_libgd

-- 安全随机数（使用 ngx.random）
local function secure_rand(max_val)
    local byte = ngx.random(1)
    if not byte then return math.random(0, max_val) end
    return tonumber(string.byte(byte)) % (max_val + 1)
end

local function random_color(im)
    return libgd.gdImageColorAllocate(im,
        secure_rand(120) + 30,
        secure_rand(120) + 30,
        secure_rand(120) + 30
    )
end

local function random_light_color(im)
    return libgd.gdImageColorAllocate(im,
        secure_rand(55) + 200,
        secure_rand(55) + 200,
        secure_rand(55) + 200
    )
end

local function draw_noise_lines(im, width, height, line_count)
    for i = 1, line_count do
        local x1 = secure_rand(width)
        local y1 = secure_rand(height)
        local x2 = secure_rand(width)
        local y2 = secure_rand(height)
        local color = random_color(im)
        libgd.gdImageLine(im, x1, y1, x2, y2, color)
    end
end

local function draw_noise_dots(im, width, height, dot_count)
    for i = 1, dot_count do
        local x = secure_rand(width)
        local y = secure_rand(height)
        local color = random_color(im)
        libgd.gdImageSetPixel(im, x, y, color)
    end
end

local function draw_text(im, text, font, x, y, color, rotation)
    local text_ptr = ffi.cast('unsigned char *', text)
    libgd.gdImageString(im, font, x, y, text_ptr, color)
end

local function create_captcha_image(code, width, height)
    if not check_libgd() then
        return nil, 'GD library not available'
    end

    local im = libgd.gdImageCreateTrueColor(width, height)
    if im == nil then
        return nil, 'Failed to create image'
    end

    local bg_color = libgd.gdImageColorAllocate(im, 255, 255, 255)
    libgd.gdImageFilledRectangle(im, 0, 0, width - 1, height - 1, bg_color)

    draw_noise_lines(im, width, height, 5)
    draw_noise_dots(im, width, height, 30)

    local fonts = {1, 2, 3, 4, 5}
    local font = fonts[secure_rand(4) + 1]
    local char_width = libgd.gdImageFontWidth(font)
    local char_height = libgd.gdImageFontHeight(font)

    local start_x = secure_rand(10) + 5
    local center_y = (height - char_height) / 2 + char_height / 2

    for i = 1, #code do
        local char = code:sub(i, i)
        local char_byte = ffi.new('unsigned char[1]')
        char_byte[0] = string.byte(char)

        local rotation = secure_rand(30) - 15
        local y = center_y + secure_rand(10) - 5
        local x = start_x + (i - 1) * (char_width + 3)

        local color = libgd.gdImageColorAllocate(im,
            secure_rand(100),
            secure_rand(100),
            secure_rand(100)
        )

        libgd.gdImageLine(im, 0, y, width, y, random_color(im))

        libgd.gdImageString(im, font, x, y, char_byte, color)
    end

    draw_noise_dots(im, width, height, 10)

    local png_size = ffi.new('int[1]')
    local png_ptr = libgd.gdImagePngPtr(im, png_size)

    local image_data = nil
    if png_ptr ~= nil then
        image_data = ffi.string(png_ptr, png_size[0])
        libgd.gdFree(png_ptr)
    end

    libgd.gdImageDestroy(im)

    return image_data
end

function _M.generate_image(code, width, height)
    width = tonumber(width) or 120
    height = tonumber(height) or 40
    return create_captcha_image(code, width, height)
end

function _M.get_captcha_image(code, width, height)
    return create_captcha_image(code, width or 120, height or 40)
end

function _M.get_captcha_png_base64(code, width, height)
    local image_data, err = create_captcha_image(code, width or 120, height or 40)
    if not image_data then
        return nil, err
    end

    local mime_base64 = require('mime')
    if mime_base64 then
        local encoded = mime_base64.b64(image_data)
        return 'data:image/png;base64,' .. encoded
    end

    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = {}

    local i = 1
    local len = #image_data
    while i <= len do
        local b1 = string.byte(image_data, i)
        local b2 = i + 1 <= len and string.byte(image_data, i + 1) or 0
        local b3 = i + 2 <= len and string.byte(image_data, i + 2) or 0

        local b1_char = chars:sub(math.floor(b1 / 4) + 1, math.floor(b1 / 4) + 1)
        local b2_char = chars:sub(((b1 % 16) * 16) + math.floor(b2 / 16) + 1, ((b1 % 16) * 16) + math.floor(b2 / 16) + 1)
        local b3_char = i + 1 <= len and chars:sub(((b2 % 16) * 4) + math.floor(b3 / 64) + 1, ((b2 % 16) * 4) + math.floor(b3 / 64) + 1) or '='
        local b4_char = i + 2 <= len and chars:sub(b3 % 64 + 1, b3 % 64 + 1) or '='

        table.insert(result, b1_char)
        table.insert(result, b2_char)
        if i + 1 <= len then table.insert(result, b3_char) end
        if i + 2 <= len then table.insert(result, b4_char) end

        i = i + 3
    end

    return 'data:image/png;base64,' .. table.concat(result)
end

return _M
