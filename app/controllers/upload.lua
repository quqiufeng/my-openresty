local BaseController = require("app.core.Controller")
local UploadController = {}

function UploadController:index()
    local response = {
        message = "File Upload Demo",
        endpoints = {
            ["POST /upload"] = "Upload a single file",
            ["POST /upload/multiple"] = "Upload multiple files",
            ["POST /upload/validate"] = "Upload with validation",
            ["GET /upload/form"] = "Show upload form (HTML)",
        }
    }
    return self:json(response)
end

function UploadController:upload()
    local file = self:request():get_uploaded_file("file")

    if not file then
        return self:json({
            success = false,
            error = "No file uploaded or file too large"
        }, 400)
    end

    local save_result = self:request():save_file("file", "uploads/", "uploaded_" .. os.time())

    if save_result then
        return self:json({
            success = true,
            message = "File uploaded successfully",
            file = file
        })
    else
        return self:json({
            success = false,
            error = "Failed to save file"
        }, 500)
    end
end

function UploadController:uploadMultiple()
    local files = self:request():multiple_files()

    if not files or #files == 0 then
        return self:json({
            success = false,
            error = "No files uploaded"
        }, 400)
    end

    local uploaded = {}
    for _, file in ipairs(files) do
        local result = self:request():save_file(file.name, "uploads/", "multi_" .. os.time() .. "_" .. file.name)
        table.insert(uploaded, {
            name = file.name,
            size = file.size,
            saved = result
        })
    end

    return self:json({
        success = true,
        message = string.format("Processed %d files", #files),
        files = uploaded
    })
end

function UploadController:uploadValidate()
    local upload_config = self.config.upload or {}
    local rules = {
        max_size = upload_config.max_size or 10,
        allowed_types = upload_config.allowed_mimes or {"image/jpeg", "image/png", "image/gif", "application/pdf"}
    }

    local valid, error = self:request():validate_upload("file", rules)

    if not valid then
        return self:json({
            success = false,
            error = error
        }, 400)
    end

    local save_result = self:request():save_file("file", nil, "validated_" .. os.time())

    return self:json({
        success = true,
        message = "File validated and uploaded successfully"
    })
end

function UploadController:showForm()
    local html = [[
<!DOCTYPE html>
<html>
<head>
    <title>File Upload Demo</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
        .form-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        input[type="file"] { padding: 10px; border: 1px solid #ddd; border-radius: 4px; width: 100%; }
        button { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background: #0056b3; }
        .info { background: #f8f9fa; padding: 15px; border-radius: 4px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>File Upload Demo</h1>
    <div class="info">
        <strong>MyResty File Upload API</strong><br>
        Allowed types: JPEG, PNG, GIF, PDF<br>
        Max size: 5MB
    </div>

    <form action="/upload" method="POST" enctype="multipart/form-data">
        <div class="form-group">
            <label for="file">Select File:</label>
            <input type="file" name="file" id="file" accept=".jpg,.jpeg,.png,.gif,.pdf">
        </div>
        <button type="submit">Upload File</button>
    </form>
</body>
</html>
    ]]
    return self:html(html)
end

return UploadController
