-- Copyright (c) 2026 MyResty Framework
-- Unified Crypto Library using OpenSSL FFI
-- Used by Session and Captcha modules

local _M = {}

local ffi = require("ffi")

ffi.cdef[[
    typedef struct evp_cipher_st EVP_CIPHER;
    typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;

    const EVP_CIPHER *EVP_aes_256_cbc(void);
    EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);
    void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *ctx);

    int EVP_EncryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *type,
                           void *impl, const unsigned char *key,
                           const unsigned char *iv);

    int EVP_EncryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out,
                          int *outl, const unsigned char *in, int inl);

    int EVP_EncryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl);

    int EVP_DecryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *type,
                           void *impl, const unsigned char *key,
                           const unsigned char *iv);

    int EVP_DecryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out,
                          int *outl, const unsigned char *in, int inl);

    int EVP_DecryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *outb, int *outl);

    int RAND_bytes(unsigned char *buf, int num);
]]

local libcrypto = ffi.load("crypto")

local function load_config()
    local ok, Config = pcall(require, 'app.core.Config')
    if ok and Config then
        Config.load()
        return Config.get()
    end
    return nil
end

local function get_secret_key()
    local env_key = os.getenv('SESSION_SECRET') or os.getenv('MYRESTY_SESSION_SECRET')
    if env_key and #env_key >= 32 then
        return env_key
    end

    local config = load_config()
    if config and config.session and config.session.secret_key then
        return config.session.secret_key
    end

    return 'd07495d9623312cae328d13ca573e788'
end

function _M.get_secret_key()
    return get_secret_key()
end

function _M.encrypt(data, key)
    local key = key or get_secret_key()
    local iv_len = 16
    local key_c = ffi.new("unsigned char[32]")
    local iv_c = ffi.new("unsigned char[16]")
    for i = 1, 32 do
        if i <= #key then
            key_c[i-1] = key:byte(i)
        else
            key_c[i-1] = 0
        end
    end

    if libcrypto.RAND_bytes(iv_c, iv_len) ~= 1 then
        if ngx then ngx.log(ngx.ERR, "RAND_bytes failed") end
        return nil, "Failed to generate IV"
    end

    local data_len = #data
    local data_c = ffi.new("unsigned char[?]", data_len)
    for i = 1, data_len do
        data_c[i-1] = data:byte(i)
    end

    local out_len = ffi.new("int[1]")
    local out_buf = ffi.new("unsigned char[?]", data_len + 32)

    local ctx = libcrypto.EVP_CIPHER_CTX_new()
    if not ctx then
        if ngx then ngx.log(ngx.ERR, "EVP_CIPHER_CTX_new failed") end
        return nil, "Failed to create context"
    end

    local cipher = libcrypto.EVP_aes_256_cbc()
    if cipher == nil then
        libcrypto.EVP_CIPHER_CTX_free(ctx)
        if ngx then ngx.log(ngx.ERR, "EVP_aes_256_cbc returned nil") end
        return nil, "Failed to get cipher"
    end

    if libcrypto.EVP_EncryptInit_ex(ctx, cipher, nil, key_c, iv_c) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx)
        if ngx then ngx.log(ngx.ERR, "EVP_EncryptInit_ex failed") end
        return nil, "Encrypt init failed"
    end

    if libcrypto.EVP_EncryptUpdate(ctx, out_buf, out_len, data_c, data_len) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx)
        if ngx then ngx.log(ngx.ERR, "EVP_EncryptUpdate failed") end
        return nil, "Encrypt update failed"
    end

    local mid_len = out_len[0]
    local final_len = ffi.new("int[1]")

    if libcrypto.EVP_EncryptFinal_ex(ctx, out_buf + mid_len, final_len) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx)
        if ngx then ngx.log(ngx.ERR, "EVP_EncryptFinal_ex failed") end
        return nil, "Encrypt final failed"
    end

    libcrypto.EVP_CIPHER_CTX_free(ctx)

    local total_len = mid_len + final_len[0]
    local result = ffi.string(iv_c, iv_len) .. ffi.string(out_buf, total_len)
    return result
end

function _M.decrypt(data, key)
    local key = key or get_secret_key()
    if #data < 32 then
        return nil, "Data too short"
    end

    local key_c = ffi.new("unsigned char[32]")
    for i = 1, 32 do
        if i <= #key then
            key_c[i-1] = key:byte(i)
        else
            key_c[i-1] = 0
        end
    end

    local iv_len = 16
    local iv_c = ffi.new("unsigned char[16]")
    for i = 1, 16 do
        iv_c[i-1] = data:byte(i)
    end

    local ciphertext_len = #data - 16
    local ciphertext_c = ffi.new("unsigned char[?]", ciphertext_len)
    for i = 1, ciphertext_len do
        ciphertext_c[i-1] = data:byte(16 + i)
    end

    local out_len = ffi.new("int[1]")
    local out_buf = ffi.new("unsigned char[?]", ciphertext_len)

    local ctx = libcrypto.EVP_CIPHER_CTX_new()
    if not ctx then
        return nil, "Failed to create context"
    end

    local cipher = libcrypto.EVP_aes_256_cbc()
    if libcrypto.EVP_DecryptInit_ex(ctx, cipher, nil, key_c, iv_c) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx)
        return nil, "Decrypt init failed"
    end

    if libcrypto.EVP_DecryptUpdate(ctx, out_buf, out_len, ciphertext_c, ciphertext_len) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx)
        return nil, "Decrypt update failed"
    end

    local final_len = ffi.new("int[1]")
    if libcrypto.EVP_DecryptFinal_ex(ctx, out_buf + out_len[0], final_len) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx)
        return nil, "Decrypt final failed"
    end

    libcrypto.EVP_CIPHER_CTX_free(ctx)

    local total_len = out_len[0] + final_len[0]
    return ffi.string(out_buf, total_len)
end

function _M.base64_encode(data)
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = {}

    local i = 1
    while i <= #data do
        local byte1 = string.byte(data, i)
        local byte2 = i + 1 <= #data and string.byte(data, i + 1) or 0
        local byte3 = i + 2 <= #data and string.byte(data, i + 2) or 0

        local triplet = byte1 * 65536 + byte2 * 256 + byte3

        table.insert(result, b64chars:sub(math.floor(triplet / 262144) % 64 + 1, math.floor(triplet / 262144) % 64 + 1))
        table.insert(result, b64chars:sub(math.floor(triplet / 4096) % 64 + 1, math.floor(triplet / 4096) % 64 + 1))

        if i + 1 <= #data then
            table.insert(result, b64chars:sub(math.floor(triplet / 64) % 64 + 1, math.floor(triplet / 64) % 64 + 1))
        else
            table.insert(result, '=')
        end

        if i + 2 <= #data then
            table.insert(result, b64chars:sub(triplet % 64 + 1, triplet % 64 + 1))
        else
            table.insert(result, '=')
        end

        i = i + 3
    end

    return table.concat(result)
end

function _M.base64_decode(data)
    if not data or data == '' then
        return ''
    end

    data = data:gsub('%s+', '')

    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local reverse_map = {}
    for i = 1, #b64chars do
        reverse_map[b64chars:sub(i, i)] = i - 1
    end

    local result = {}
    local i = 1

    while i <= #data do
        local padding = 0
        local c1, c2, c3, c4

        local p1 = data:sub(i, i)
        local p2 = data:sub(i + 1, i + 1)
        local p3 = data:sub(i + 2, i + 2)
        local p4 = data:sub(i + 3, i + 3)

        if p3 == '=' then padding = 2 elseif p4 == '=' then padding = 1 end

        c1 = reverse_map[p1] or 0
        c2 = reverse_map[p2] or 0
        c3 = reverse_map[p3] or 0
        c4 = reverse_map[p4] or 0

        local triplet = c1 * 262144 + c2 * 4096 + c3 * 64 + c4

        table.insert(result, string.char(math.floor(triplet / 65536)))
        if padding < 2 then
            table.insert(result, string.char(math.floor(triplet / 256) % 256))
        end
        if padding == 0 then
            table.insert(result, string.char(triplet % 256))
        end

        i = i + 4
    end

    return table.concat(result)
end

function _M.random_bytes(length)
    local buf = ffi.new("unsigned char[?]", length)
    if libcrypto.RAND_bytes(buf, length) ~= 1 then
        return nil
    end
    return ffi.string(buf, length)
end

-- Alias for secure_random
_M.secure_random = _M.random_bytes

function _M.encrypt_captcha(plaintext)
    local secret_key = get_secret_key()
    local encrypted = _M.encrypt(plaintext, secret_key)
    if not encrypted then
        return nil
    end
    return _M.base64_encode(encrypted)
end

function _M.decrypt_captcha(encrypted_data)
    local secret_key = get_secret_key()
    local decoded = _M.base64_decode(encrypted_data)
    if not decoded or #decoded == 0 then
        return nil
    end
    local decrypted = _M.decrypt(decoded, secret_key)
    return decrypted
end

function _M.encrypt_session(plaintext)
    local encrypted = _M.encrypt(plaintext)
    if not encrypted then
        return nil
    end
    return _M.base64_encode(encrypted)
end

function _M.decrypt_session(encrypted_data)
    local decoded = _M.base64_decode(encrypted_data)
    if not decoded or #decoded == 0 then
        return nil
    end
    return _M.decrypt(decoded)
end

return _M
