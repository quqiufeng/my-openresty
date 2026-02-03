-- File Utility Unit Tests
-- tests/unit/file_spec.lua

package.path = '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-openresty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('File Module', function()
    describe('file_exists', function()
        it('should check if file exists', function()
            local function file_exists(path)
                local f = io.open(path, 'r')
                if f then
                    f:close()
                    return true
                end
                return false
            end

            assert.is_true(file_exists('/var/www/web/my-openresty/bootstrap.lua'))
            assert.is_false(file_exists('/var/www/web/my-openresty/nonexistent_file.lua'))
        end)
    end)

    describe('file_read', function()
        it('should read file content', function()
            local function file_read(path)
                local f = io.open(path, 'r')
                if not f then return nil end
                local content = f:read('*a')
                f:close()
                return content
            end

            local content = file_read('/var/www/web/my-openresty/bootstrap.lua')
            assert.is_string(content)
            assert.matches('package.path', content)
        end)
    end)

    describe('file_write', function()
        it('should write content to file', function()
            local test_file = '/tmp/myresty_test_output.txt'
            local function file_write(path, content)
                local f = io.open(path, 'w')
                if not f then return false end
                f:write(content)
                f:close()
                return true
            end

            local ok = file_write(test_file, 'test content')
            assert.is_true(ok)

            local f = io.open(test_file, 'r')
            local content = f:read('*a')
            f:close()
            assert.equals('test content', content)

            os.remove(test_file)
        end)
    end)

    describe('file_delete', function()
        it('should delete file', function()
            local test_file = '/tmp/myresty_test_delete.txt'
            local f = io.open(test_file, 'w')
            f:write('delete me')
            f:close()

            local function file_delete(path)
                local ok, err = os.remove(path)
                return ok, err
            end

            local ok, err = file_delete(test_file)
            assert.is_true(ok)
            assert.is_false(file_exists(test_file))
        end)
    end)

    describe('file_size', function()
        it('should get file size', function()
            local test_file = '/tmp/myresty_test_size.txt'
            local f = io.open(test_file, 'w')
            f:write('hello world')
            f:close()

            local function file_size(path)
                local f = io.open(path, 'r')
                if not f then return nil end
                f:seek('end')
                local size = f:seek()
                f:close()
                return size
            end

            local size = file_size(test_file)
            assert.equals(11, size)

            os.remove(test_file)
        end)
    end)

    describe('file_extension', function()
        it('should extract file extension', function()
            local function file_extension(filename)
                if not filename or #filename == 0 then return '' end
                local ext = filename:match('%.(%w+)$')
                return ext or ''
            end

            assert.equals('lua', file_extension('test.lua'))
            assert.equals('json', file_extension('config.json'))
            assert.equals('', file_extension('noextension'))
        end)
    end)

    describe('file_mime_type', function()
        it('should return mime type for extension', function()
            local function file_mime_type(ext)
                local types = {
                    ['lua'] = 'application/x-lua',
                    ['json'] = 'application/json',
                    ['txt'] = 'text/plain',
                    ['html'] = 'text/html',
                    ['css'] = 'text/css',
                    ['js'] = 'application/javascript',
                    ['png'] = 'image/png',
                    ['jpg'] = 'image/jpeg',
                    ['gif'] = 'image/gif',
                    ['pdf'] = 'application/pdf',
                }
                return types[ext:lower()] or 'application/octet-stream'
            end

            assert.equals('application/json', file_mime_type('json'))
            assert.equals('text/plain', file_mime_type('txt'))
            assert.equals('image/png', file_mime_type('PNG'))
            assert.equals('application/octet-stream', file_mime_type('xyz'))
        end)
    end)

    describe('file_list', function()
        it('should list files in directory', function()
            local function file_list(dir_path)
                local files = {}
                local p = io.popen('ls -a "' .. dir_path .. '" 2>/dev/null')
                if p then
                    for line in p:lines() do
                        local name = line:match('^.*%s+(.+)$')
                        if name and name ~= '.' and name ~= '..' then
                            table.insert(files, name)
                        end
                    end
                    p:close()
                end
                return files
            end

            local files = file_list('/var/www/web/my-openresty')
            assert.is_table(files)
            assert.True(#files > 0)
        end)
    end)

    describe('file_copy', function()
        it('should copy file', function()
            local src = '/tmp/myresty_test_src.txt'
            local dst = '/tmp/myresty_test_dst.txt'

            local f = io.open(src, 'w')
            f:write('copy this content')
            f:close()

            local function file_copy(src_path, dst_path)
                local src_file = io.open(src_path, 'rb')
                if not src_file then return false end
                local dst_file = io.open(dst_path, 'wb')
                if not dst_file then
                    src_file:close()
                    return false
                end
                dst_file:write(src_file:read('*a'))
                src_file:close()
                dst_file:close()
                return true
            end

            local ok = file_copy(src, dst)
            assert.is_true(ok)

            local f = io.open(dst, 'r')
            local content = f:read('*a')
            f:close()
            assert.equals('copy this content', content)

            os.remove(src)
            os.remove(dst)
        end)
    end)

    describe('path_join', function()
        it('should join path components', function()
            local function path_join(...)
                local parts = {...}
                local result = ''
                for i, part in ipairs(parts) do
                    if i > 1 then
                        result = result .. '/'
                    end
                    result = result .. part:gsub('^/', ''):gsub('/+$', '')
                end
                return result
            end

            assert.equals('dir/subdir/file.lua', path_join('dir', 'subdir', 'file.lua'))
            assert.equals('/absolute/path', path_join('/absolute', 'path'))
            assert.equals('single', path_join('single'))
        end)
    end

    describe('path_basename', function()
        it('should get basename from path', function()
            local function path_basename(path)
                local name = path:match('([^/]+)/?$')
                return name or path
            end

            assert.equals('file.lua', path_basename('/path/to/file.lua'))
            assert.equals('file.lua', path_basename('file.lua'))
            assert.equals('dir', path_basename('/path/to/dir/'))
        end)
    end)

    describe('path_dirname', function()
        it('should get dirname from path', function()
            local function path_dirname(path)
                local dir = path:match('^(.+)/[^/]+/?$')
                return dir or '.'
            end

            assert.equals('/path/to', path_dirname('/path/to/file.lua'))
            assert.equals('.', path_dirname('file.lua'))
            assert.equals('/path', path_dirname('/path/to/dir/'))
        end)
    end)
end)
