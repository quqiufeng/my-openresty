local ffi = require('ffi')

if not ffi.load then
    return {
        copy = function() return nil, 'FFI not available' end,
        move = function() return nil, 'FFI not available' end,
        delete = function() return nil, 'FFI not available' end,
        exists = function() return nil, 'FFI not available' end,
        size = function() return nil, 'FFI not available' end,
        mkdir = function() return nil, 'FFI not available' end,
    }
end

local C = ffi.C

ffi.cdef[[
    int stat(const char *path, void *st);
    int access(const char *path, int mode);
    int open(const char *path, int flags, ...);
    int close(int fd);
    ssize_t read(int fd, void *buf, size_t count);
    ssize_t write(int fd, const void *buf, size_t count);
    int unlink(const char *path);
    int rename(const char *oldpath, const char *newpath);
    int mkdir(const char *path, int mode);
    int chmod(const char *path, int mode);
    void *malloc(size_t size);
    void free(void *ptr);
    int copyfile(const char *from, const char *to, int flags);
    int fcntl(int fd, int cmd, ...);
]]

local libcs = {
    'c', 'libc.so.6', 'libc.so.2', nil
}
local lib = nil

for _, name in ipairs(libcs) do
    pcall(function()
        lib = ffi.load(name or 'c')
    end)
    if lib then break end
end

if not lib then
    return {
        copy = function() return nil, 'C library not found' end,
        move = function() return nil, 'C library not found' end,
        delete = function() return nil, 'C library not found' end,
        exists = function() return nil, 'C library not found' end,
        size = function() return nil, 'C library not found' end,
        mkdir = function() return nil, 'C library not found' end,
    }
end

local _M = {}

function _M.exists(filepath)
    if not filepath or #filepath == 0 then return false end
    local result = lib.access(filepath, 0)
    return result == 0
end

function _M.size(filepath)
    if not _M.exists(filepath) then return nil, 'File not found' end

    ffi.cdef[[
        struct stat {
            unsigned long st_size;
        };
    ]]

    local stat_buf = ffi.new('struct stat')
    local ret = lib.stat(filepath, stat_buf)
    if ret ~= 0 then return nil, 'stat failed' end

    return tonumber(stat_buf.st_size)
end

function _M.mkdir(path, mode)
    mode = mode or 493
    local ret = lib.mkdir(path, mode)
    if ret ~= 0 and lib.errno ~= 17 then
        return nil, 'mkdir failed'
    end
    return true
end

function _M.delete(filepath)
    if not filepath or #filepath == 0 then
        return nil, 'Invalid filepath'
    end
    local ret = lib.unlink(filepath)
    if ret ~= 0 then
        return nil, 'Failed to delete file'
    end
    return true
end

function _M.move(src, dst)
    if not src or not dst or #src == 0 or #dst == 0 then
        return nil, 'Invalid source or destination'
    end

    if not _M.exists(src) then
        return nil, 'Source file not found'
    end

    local parent_dir = dst:match('(.+)/[^/]+$')
    if parent_dir and not _M.exists(parent_dir) then
        _M.mkdir(parent_dir, 493)
    end

    local ret = lib.rename(src, dst)
    if ret ~= 0 then
        return nil, 'Failed to rename file'
    end
    return true
end

function _M.copy(src, dst, buffer_size)
    if not src or not dst or #src == 0 or #dst == 0 then
        return nil, 'Invalid source or destination'
    end

    if not _M.exists(src) then
        return nil, 'Source file not found'
    end

    buffer_size = buffer_size or 8192

    local src_fd = lib.open(src, 0)
    if src_fd < 0 then
        return nil, 'Failed to open source file'
    end

    ffi.cdef[[
        struct stat {
            unsigned long st_mode;
            unsigned long st_size;
        };
    ]]

    local stat_buf = ffi.new('struct stat')
    if lib.fstat(src_fd, stat_buf) ~= 0 then
        lib.close(src_fd)
        return nil, 'Failed to stat source file'
    end

    local file_size = tonumber(stat_buf.st_size)
    local flags = 0x41
    local dst_fd = lib.open(dst, flags, 0o644)

    if dst_fd < 0 then
        lib.close(src_fd)
        return nil, 'Failed to open destination file'
    end

    local buf = lib.malloc(buffer_size)
    if not buf then
        lib.close(src_fd)
        lib.close(dst_fd)
        return nil, 'Failed to allocate buffer'
    end

    local total_read = 0
    local ok = true

    while total_read < file_size do
        local to_read = math.min(buffer_size, file_size - total_read)
        local bytes_read = lib.read(src_fd, buf, to_read)

        if bytes_read <= 0 then
            ok = false
            break
        end

        local bytes_written = lib.write(dst_fd, buf, bytes_read)
        if bytes_written ~= bytes_read then
            ok = false
            break
        end

        total_read = total_read + bytes_read
    end

    lib.free(buf)
    lib.close(src_fd)
    lib.close(dst_fd)

    if not ok then
        lib.unlink(dst)
        return nil, 'Failed to copy file'
    end

    return true, total_read
end

function _M.copy_file(src, dst)
    return _M.copy(src, dst)
end

function _M.chmod(filepath, mode)
    if not _M.exists(filepath) then
        return nil, 'File not found'
    end
    local ret = lib.chmod(filepath, mode)
    if ret ~= 0 then
        return nil, 'Failed to chmod'
    end
    return true
end

function _M.read(filepath, max_size)
    if not _M.exists(filepath) then
        return nil, 'File not found'
    end

    local size = _M.size(filepath)
    if not size then return nil, 'Cannot get file size' end

    if max_size and size > max_size then
        size = max_size
    end

    local fd = lib.open(filepath, 0)
    if fd < 0 then
        return nil, 'Failed to open file'
    end

    local buf = ffi.new('char[?]', size + 1)
    local bytes_read = lib.read(fd, buf, size)

    lib.close(fd)

    if bytes_read ~= size then
        return nil, 'Failed to read file'
    end

    ffi.fill(buf + size, 1, 1)

    return ffi.string(buf)
end

function _M.write(filepath, content, mode)
    if not filepath or #filepath == 0 then
        return nil, 'Invalid filepath'
    end

    local parent_dir = filepath:match('(.+)/[^/]+$')
    if parent_dir and not _M.exists(parent_dir) then
        _M.mkdir(parent_dir, 493)
    end

    local flags = 0x41
    local file_mode = mode or 0o644
    local fd = lib.open(filepath, flags, file_mode)

    if fd < 0 then
        return nil, 'Failed to open file'
    end

    local content_len = #content
    local bytes_written = lib.write(fd, content, content_len)

    lib.close(fd)

    if bytes_written ~= content_len then
        return nil, 'Failed to write file'
    end

    return true
end

function _M.append(filepath, content, mode)
    if not filepath or #filepath == 0 then
        return nil, 'Invalid filepath'
    end

    local flags = 0x2001
    local file_mode = mode or 0o644
    local fd = lib.open(filepath, flags, file_mode)

    if fd < 0 then
        return nil, 'Failed to open file'
    end

    local content_len = #content
    local bytes_written = lib.write(fd, content, content_len)

    lib.close(fd)

    if bytes_written ~= content_len then
        return nil, 'Failed to append to file'
    end

    return true
end

return _M
