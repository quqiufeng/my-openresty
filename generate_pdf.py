#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MyResty Documentation Generator - Bilingual PDF
生成中英双语PDF文档
"""

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
import os

def register_chinese_font():
    import subprocess

    font_paths = [
        ('/usr/share/fonts/truetype/arphic/uming.ttc', 'UMing'),
        ('/usr/share/fonts/truetype/arphic/ukai.ttc', 'UKai'),
        ('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc', 'NotoSans'),
    ]

    for path, name in font_paths:
        if os.path.exists(path):
            try:
                # Try to extract TTF from TTC using pyftsubset or similar
                # For now, register with TTFont which handles TTC in newer versions
                font = TTFont(name, path)
                pdfmetrics.registerFont(font)
                print(f"Registered font: {name} from {path}")
                return name
            except Exception as e:
                print(f"Failed to register {path}: {e}")
                # Try to find individual TTF files in the TTC
                try:
                    result = subprocess.run(['fc-query', '--format=%{family}\n', path], capture_output=True, text=True)
                    print(f"Font families in {path}: {result.stdout}")
                except:
                    pass
                continue

    print("Using default Helvetica font")
    return 'Helvetica'

# 文档配置
DOC_TITLE = "MyResty API Framework"
DOC_TITLE_CN = "MyResty API 框架文档"

SECTIONS = [
    {
        "title": "1. Directory Structure",
        "title_cn": "1. 目录结构",
        "content": """
The project follows a standard CodeIgniter-style directory structure:

项目遵循标准的 CodeIgniter 风格目录结构：
""",
        "code": """my-resty/
├── app/
│   ├── config/
│   │   └── config.lua          # Main configuration
│   ├── core/
│   │   ├── Config.lua          # Config loader
│   │   ├── Controller.lua      # Base controller
│   │   ├── Model.lua           # Base model
│   │   ├── Request.lua         # Request handler
│   │   ├── Response.lua        # Response handler
│   │   ├── Router.lua          # Router
│   │   └── Loader.lua          # Auto loader
│   ├── controllers/
│   │   ├── welcome.lua         # Welcome controller
│   │   ├── user.lua            # User controller
│   │   └── test.lua            # Test controller
│   ├── models/
│   │   └── user_model.lua      # User model
│   ├── libraries/
│   │   └── redis.lua           # Redis library
│   ├── helpers/
│   │   ├── url_helper.lua      # URL helpers
│   │   └── string_helper.lua   # String helpers
│   ├── routes.lua              # Route definitions
│   └── views/                  # View templates
├── nginx/
│   └── conf/
│       └── nginx.conf          # Nginx config
├── logs/                       # Log files
├── bootstrap.lua               # Entry point
└── README.md"""
    },
    {
        "title": "2. Quick Start",
        "title_cn": "2. 快速开始",
        "content": """
Getting started with MyResty is simple:

开始使用 MyResty 非常简单：

1. Install OpenResty
   安装 OpenResty

2. Configure nginx.conf
   配置 nginx.conf

3. Edit app/config/config.lua
   编辑数据库和Redis配置

4. Start nginx
   启动 nginx
""",
        "code": None
    },
    {
        "title": "3. Create Controller",
        "title_cn": "3. 创建控制器",
        "content": """
Controllers handle HTTP requests. Create controllers to define your API endpoints:

控制器处理 HTTP 请求。创建控制器来定义 API 端点：
""",
        "code": """local Controller = require('app.core.Controller')

local _M = {}

function _M:index()
    self:json({message = 'Hello World'})
end

return _M"""
    },
    {
        "title": "4. Create Model",
        "title_cn": "4. 创建模型",
        "content": """
Models handle database operations. Create models to encapsulate data logic:

模型处理数据库操作。创建模型来封装数据逻辑：
""",
        "code": """local Model = require('app.core.Model')

local _M = {}

function _M.new()
    local model = Model:new()
    model:set_table('your_table')
    return model
end

return _M"""
    },
    {
        "title": "5. Define Routes",
        "title_cn": "5. 定义路由",
        "content": """
Define routes in app/routes.lua:

在 app/routes.lua 中定义路由：
""",
        "code": """route:get('/api/users', 'user:get_list')
route:post('/api/users', 'user:create')
route:get('/api/users/{id}', 'user:get_one')
route:put('/api/users/{id}', 'user:update')
route:delete('/api/users/{id}', 'user:delete')"""
    },
    {
        "title": "6. Controller Methods",
        "title_cn": "6. 控制器方法",
        "content": """
Example of handling POST request:

处理 POST 请求示例：
""",
        "code": """function _M:create()
    local Request = require('app.core.Request')
    local data = Request.post

    self:load('user_model')
    local id = self.user_model:insert(data)

    self:json({success = true, id = id})
end"""
    },
    {
        "title": "7. Available Methods",
        "title_cn": "7. 可用方法",
        "content": """
MyResty provides rich methods for rapid development:

MyResty 提供了丰富的开发方法：
""",
        "code": """### Controller Methods
- self:json(data)           - Send JSON response
- self:output(content)      - Send raw output
- self:redirect(uri)        - Redirect
- self:load(model_name)     - Load model
- self:library(lib_name)    - Load library
- self:helper(helper_name)  - Load helper

### Model Methods
- self:get_all(where, limit, offset)
- self:get_by_id(id)
- self:insert(data)
- self:update(data, where)
- self:delete(where)
- self:query(sql)

### Request Methods
- Request.get               - GET parameters
- Request.post              - POST parameters
- Request.segments          - URI segments
- Request:segment(n)        - Get nth segment
- Request:method()          - HTTP method
- Request:is_ajax()         - Check AJAX request"""
    },
    {
        "title": "8. Connection Pool & Cache",
        "title_cn": "8. 连接池与缓存",
        "content": """
MyResty supports connection pooling for MySQL and Redis:

MyResty 支持 MySQL 和 Redis 连接池：
""",
        "code": """### MySQL Pool / MySQL连接池
local Mysql = require('app.libraries.mysql')
local user = Mysql.query('SELECT * FROM users')

### Redis Pool / Redis连接池
local Redis = require('app.libraries.redis')
Redis.set('key', 'value', 3600)

### Model Usage / 模型使用
local user = self.user_model:get_by_id(1)
local users = self.user_model:get_all(nil, 10, 0)"""
    }
]

def create_document():
    output_file = "/var/www/web/my-resty/MyResty_Documentation.pdf"
    doc = SimpleDocTemplate(
        output_file,
        pagesize=A4,
        rightMargin=18*mm,
        leftMargin=18*mm,
        topMargin=20*mm,
        bottomMargin=18*mm
    )

    styles = getSampleStyleSheet()

    # 注册字体
    font_name = register_chinese_font()

    # 自定义样式
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Title'],
        fontName=font_name,
        fontSize=28,
        spaceAfter=25,
        alignment=TA_CENTER,
        textColor=colors.HexColor('#1A5276')
    )

    subtitle_style = ParagraphStyle(
        'Subtitle',
        parent=styles['Normal'],
        fontName=font_name,
        fontSize=16,
        spaceAfter=30,
        alignment=TA_CENTER,
        textColor=colors.HexColor('#5D6D7E')
    )

    heading_style = ParagraphStyle(
        'Heading',
        parent=styles['Heading1'],
        fontName=font_name,
        fontSize=16,
        spaceBefore=20,
        spaceAfter=12,
        textColor=colors.HexColor('#2874A6'),
        borderPadding=8,
        backColor=colors.HexColor('#D4E6F1')
    )

    heading_cn_style = ParagraphStyle(
        'HeadingCN',
        parent=heading_style,
        fontName=font_name,
        fontSize=12,
        textColor=colors.HexColor('#7F8C8D'),
        backColor=None
    )

    body_style = ParagraphStyle(
        'Body',
        parent=styles['Normal'],
        fontName=font_name,
        fontSize=11,
        spaceBefore=6,
        spaceAfter=6,
        leading=16,
        alignment=TA_JUSTIFY
    )

    code_style = ParagraphStyle(
        'Code',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=9,
        spaceBefore=8,
        spaceAfter=8,
        leftIndent=16,
        rightIndent=16,
        leading=14,
        backColor=colors.HexColor('#2C3E50'),
        textColor=colors.HexColor('#F8F9F9')
    )

    story = []

    # 封面
    story.append(Spacer(1, 60))
    story.append(Paragraph("MyResty", title_style))
    story.append(Paragraph("API Framework Documentation", subtitle_style))
    story.append(Paragraph("API 框架文档", ParagraphStyle('SubtitleCN', parent=subtitle_style, fontSize=14, textColor=colors.HexColor('#85929E'))))
    story.append(Spacer(1, 50))

    version_style = ParagraphStyle('Version', parent=styles['Normal'], alignment=TA_CENTER, fontSize=12, textColor=colors.HexColor('#AEB6BF'))
    story.append(Paragraph("Version 1.0.0", version_style))
    story.append(Paragraph("© 2026 OpenResty API Framework", version_style))
    story.append(PageBreak())

    # 目录
    story.append(Paragraph("Table of Contents / 目录", heading_style))
    story.append(Spacer(1, 10))
    for i, section in enumerate(SECTIONS, 1):
        toc = f"{i}. {section['title']}  {section['title_cn']}"
        story.append(Paragraph(toc, body_style))
    story.append(PageBreak())

    # 内容章节
    for section in SECTIONS:
        story.append(Paragraph(section["title"], heading_style))
        story.append(Paragraph(section["title_cn"], heading_cn_style))
        story.append(Spacer(1, 5))
        story.append(Paragraph(section["content"], body_style))

        if section["code"]:
            story.append(Spacer(1, 8))
            code_para = section["code"].replace('\n', '<br/>')
            code_para = f'<font face="Courier">{code_para}</font>'
            story.append(Paragraph(code_para, code_style))

        story.append(Spacer(1, 12))

    # 附录 - 配置
    story.append(PageBreak())
    story.append(Paragraph("Appendix: Configuration", heading_style))
    story.append(Paragraph("附录：配置参考", heading_cn_style))
    story.append(Spacer(1, 10))

    config_code = """-- app/config/config.lua
config = {
    -- Database / 数据库配置
    mysql = {
        host = '127.0.0.1',
        port = 3306,
        user = 'root',
        password = '',
        database = 'your_db',
        charset = 'utf8mb4',
        pool_size = 100,
        idle_timeout = 10000
    },

    -- Redis Configuration
    redis = {
        host = '127.0.0.1',
        port = 6379,
        password = '',
        db = 0,
        pool_size = 100
    },

    -- Application Config
    base_url = '',
    charset = 'UTF-8',
    log_path = '/var/www/web/my-resty/logs'
}"""
    story.append(Paragraph(config_code.replace('\n', '<br/>'), code_style))

    # 结尾
    story.append(Spacer(1, 30))
    story.append(Paragraph("— End of Document —", ParagraphStyle('End', parent=styles['Normal'], alignment=TA_CENTER, fontSize=12, textColor=colors.HexColor('#95A5A6'))))

    doc.build(story)
    print(f"PDF generated: {output_file}")
    return output_file

if __name__ == "__main__":
    create_document()
