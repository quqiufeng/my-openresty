-- Copyright (c) 2026 MyResty Framework
-- Unified Crypto Library using OpenSSL FFI
-- Used by Session and Captcha modules

local _M = { _VERSION = '1.0.0' }

local ngx_log = ngx and ngx.log or function() end
local ngx_WARN = ngx and ngx.WARN or 5
local ngx_ERR = ngx and ngx.ERR or 4

local ffi = require("ffi")

ffi.cdef[[
    typedef struct evp_cipher_st EVP_CIPHER;
    typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;
    typedef struct evp_md_st EVP_MD;

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

    const EVP_MD *EVP_sha256(void);
    unsigned char *SHA256(const unsigned char *d, size_t n, unsigned char *md);
    unsigned char *HMAC(const EVP_MD *evp_md, const void *key, int key_len,
                        const unsigned char *d, size_t n, unsigned char *md,
                        unsigned int *md_len);
]]

local libcrypto = ffi.load("crypto")

local bit = require("bit")

-- ===== 完整性/密钥派生辅助（encrypt-then-MAC） =====
local function sha256(data)
    local md = ffi.new("unsigned char[32]")
    libcrypto.SHA256(data, #data, md)
    return ffi.string(md, 32)
end

local function derive_key(secret, suffix)
    return sha256(secret .. suffix)
end

local function hmac_sha256(key, data)
    local md = ffi.new("unsigned char[32]")
    local mdlen = ffi.new("unsigned int[1]")
    libcrypto.HMAC(libcrypto.EVP_sha256(), key, #key, data, #data, md, mdlen)
    return ffi.string(md, mdlen[0])
end

-- 常量时间比较，防时序侧信道
local function const_time_eq(a, b)
    if #a ~= #b then return false end
    local r = 0
    for i = 1, #a do
        r = bit.bor(r, bit.bxor(a:byte(i), b:byte(i)))
    end
    return r == 0
end

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
    if config and config.session and config.session.secret_key and #config.session.secret_key >= 32 then
        return config.session.secret_key
    end

    ngx_log(ngx_WARN, 'crypto: SESSION_SECRET 未设置或长度不足 32！使用不安全回退密钥（仅可用于测试）。')
    return 'INSECURE_DEFAULT_KEY_DO_NOT_USE_IN_PRODUCTION'
end

-- 是否有强密钥（>=32），供启动期强制校验
function _M.has_strong_secret()
    local env_key = os.getenv('SESSION_SECRET') or os.getenv('MYRESTY_SESSION_SECRET')
    if env_key and #env_key >= 32 then return true end
    local config = load_config()
    if config and config.session and config.session.secret_key and #config.session.secret_key >= 32 then
        return true
    end
    return false
end

function _M.get_secret_key()
    return get_secret_key()
end

local function aes_cbc_encrypt(key, iv, data)
    local key_c = ffi.new("unsigned char[32]")
    ffi.copy(key_c, key, 32)
    local iv_c = ffi.new("unsigned char[16]")
    ffi.copy(iv_c, iv, 16)
    local data_len = #data
    local data_c = ffi.new("unsigned char[?]", data_len > 0 and data_len or 1)
    if data_len > 0 then ffi.copy(data_c, data, data_len) end
    local out_len = ffi.new("int[1]")
    local out_buf = ffi.new("unsigned char[?]", data_len + 32)

    local ctx = libcrypto.EVP_CIPHER_CTX_new()
    if not ctx then return nil, "Failed to create context" end
    local cipher = libcrypto.EVP_aes_256_cbc()
    if libcrypto.EVP_EncryptInit_ex(ctx, cipher, nil, key_c, iv_c) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx); return nil, "Encrypt init failed"
    end
    if libcrypto.EVP_EncryptUpdate(ctx, out_buf, out_len, data_c, data_len) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx); return nil, "Encrypt update failed"
    end
    local mid = out_len[0]
    local final_len = ffi.new("int[1]")
    if libcrypto.EVP_EncryptFinal_ex(ctx, out_buf + mid, final_len) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx); return nil, "Encrypt final failed"
    end
    libcrypto.EVP_CIPHER_CTX_free(ctx)
    return ffi.string(out_buf, mid + final_len[0])
end

local function aes_cbc_decrypt(key, iv, data)
    local key_c = ffi.new("unsigned char[32]")
    ffi.copy(key_c, key, 32)
    local iv_c = ffi.new("unsigned char[16]")
    ffi.copy(iv_c, iv, 16)
    local data_len = #data
    if data_len == 0 then return "" end
    local data_c = ffi.new("unsigned char[?]", data_len)
    ffi.copy(data_c, data, data_len)
    local out_len = ffi.new("int[1]")
    local out_buf = ffi.new("unsigned char[?]", data_len + 32)

    local ctx = libcrypto.EVP_CIPHER_CTX_new()
    if not ctx then return nil, "Failed to create context" end
    local cipher = libcrypto.EVP_aes_256_cbc()
    if libcrypto.EVP_DecryptInit_ex(ctx, cipher, nil, key_c, iv_c) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx); return nil, "Decrypt init failed"
    end
    if libcrypto.EVP_DecryptUpdate(ctx, out_buf, out_len, data_c, data_len) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx); return nil, "Decrypt update failed"
    end
    local mid = out_len[0]
    local final_len = ffi.new("int[1]")
    if libcrypto.EVP_DecryptFinal_ex(ctx, out_buf + mid, final_len) ~= 1 then
        libcrypto.EVP_CIPHER_CTX_free(ctx); return nil, "Decrypt final failed (bad key/padding)"
    end
    libcrypto.EVP_CIPHER_CTX_free(ctx)
    return ffi.string(out_buf, mid + final_len[0])
end

-- AES-256-CBC + HMAC-SHA256（encrypt-then-MAC）
-- 输出: IV(16) || ciphertext || HMAC(32)
function _M.encrypt(data, key)
    key = key or get_secret_key()
    local enc_key = derive_key(key, ":enc")
    local mac_key = derive_key(key, ":mac")

    local iv = ffi.new("unsigned char[16]")
    if libcrypto.RAND_bytes(iv, 16) ~= 1 then
        return nil, "Failed to generate IV"
    end
    local iv_s = ffi.string(iv, 16)

    local ct, err = aes_cbc_encrypt(enc_key, iv_s, data)
    if not ct then return nil, err end

    local mac = hmac_sha256(mac_key, iv_s .. ct)
    return iv_s .. ct .. mac
end

function _M.decrypt(data, key)
    key = key or get_secret_key()
    if #data < 16 + 32 + 16 then
        return nil, "Data too short"
    end

    local iv = data:sub(1, 16)
    local mac = data:sub(-32)
    local ct = data:sub(17, #data - 32)

    local mac_key = derive_key(key, ":mac")
    if not const_time_eq(mac, hmac_sha256(mac_key, iv .. ct)) then
        return nil, "integrity check failed"
    end

    local enc_key = derive_key(key, ":enc")
    return aes_cbc_decrypt(enc_key, iv, ct)
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
