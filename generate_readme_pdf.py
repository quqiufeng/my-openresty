#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate README.md as PDF with Chinese font support using WeasyPrint
"""

import os
import sys
import tempfile
from weasyprint import HTML, CSS

def markdown_to_html(markdown_file):
    """Convert markdown to HTML"""
    with open(markdown_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Simple markdown to HTML conversion
    html_parts = []

    # Title
    if content.startswith('# '):
        lines = content.split('\n')
        title = lines[0][2:].strip()
        html_parts.append(f'<h1>{title}</h1>')

    html_parts.append('<div class="content">')

    in_code_block = False
    in_list = False

    for line in content.split('\n'):
        line = line.strip()

        # Skip title line (already handled)
        if line.startswith('# ') and not html_parts:
            continue

        # Code blocks
        if line.startswith('```'):
            in_code_block = not in_code_block
            continue

        if in_code_block:
            html_parts.append(f'<pre>{line}</pre>')
            continue

        # Headers
        if line.startswith('## '):
            html_parts.append(f'<h2>{line[3:]}</h2>')
        elif line.startswith('### '):
            html_parts.append(f'<h3>{line[4:]}</h3>')
        elif line.startswith('#### '):
            html_parts.append(f'<h4>{line[5:]}</h4>')
        # List items
        elif line.startswith('- ') or line.startswith('* '):
            if not in_list:
                html_parts.append('<ul>')
                in_list = True
            html_parts.append(f'<li>{line[2:]}</li>')
        elif line.startswith('|'):
            continue  # Skip tables
        elif line.startswith('---'):
            if in_list:
                html_parts.append('</ul>')
                in_list = False
            html_parts.append('<hr>')
        # Empty lines
        elif line == '':
            if in_list:
                html_parts.append('</ul>')
                in_list = False
            html_parts.append('<br>')
        # Regular text
        else:
            if in_list:
                html_parts.append('</ul>')
                in_list = False

            # Clean inline formatting
            text = line.replace('**', '').replace('`', '').replace('`', '')
            if text:
                # Handle links [text](url)
                import re
                text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
                html_parts.append(f'<p>{text}</p>')

    if in_list:
        html_parts.append('</ul>')

    html_parts.append('</div>')

    html_content = f'''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MyResty Framework</title>
    <style>
        @font-face {{
            font-family: 'NotoSansCJK';
            src: url('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc') format('truetype');
        }}

        body {{
            font-family: 'NotoSansCJK', 'Noto Serif CJK SC', 'AR PL UMing TW MBE', sans-serif;
            font-size: 12pt;
            line-height: 1.6;
            margin: 2cm;
            color: #333;
        }}

        h1 {{
            font-size: 24pt;
            color: #1a1a1a;
            border-bottom: 2px solid #007bff;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }}

        h2 {{
            font-size: 18pt;
            color: #2c3e50;
            margin-top: 25px;
            margin-bottom: 15px;
        }}

        h3 {{
            font-size: 14pt;
            color: #34495e;
            margin-top: 20px;
            margin-bottom: 10px;
        }}

        h4 {{
            font-size: 12pt;
            color: #555;
            margin-top: 15px;
            margin-bottom: 8px;
        }}

        p {{
            margin: 10px 0;
            text-align: justify;
        }}

        ul {{
            margin: 10px 0;
            padding-left: 30px;
        }}

        li {{
            margin: 5px 0;
        }}

        pre {{
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
            font-family: 'Courier New', monospace;
            font-size: 10pt;
        }}

        code {{
            background-color: #f5f5f5;
            padding: 2px 5px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }}

        hr {{
            border: none;
            border-top: 1px solid #ddd;
            margin: 20px 0;
        }}

        .content {{
            max-width: 100%;
        }}

        @page {{
            size: A4;
            margin: 2cm;
        }}
    </style>
</head>
<body>
    {''.join(html_parts)}
</body>
</html>
'''

    return html_content

def create_pdf(input_file, output_file):
    """Create PDF from markdown"""

    # Convert markdown to HTML
    html_content = markdown_to_html(input_file)

    # Create temporary HTML file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False, encoding='utf-8') as f:
        f.write(html_content)
        html_file = f.name

    try:
        # Generate PDF using WeasyPrint
        html = HTML(html_file)
        html.write_pdf(output_file)
        print(f"PDF generated: {output_file}")
    except Exception as e:
        print(f"Error generating PDF: {e}")
        # Fallback: create HTML file instead
        fallback_file = output_file.replace('.pdf', '.html')
        with open(fallback_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        print(f"Generated HTML instead: {fallback_file}")
    finally:
        os.unlink(html_file)

if __name__ == '__main__':
    input_file = '/var/www/web/my-openresty/README.md'
    output_file = '/var/www/web/my-openresty/README.pdf'

    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found")
        sys.exit(1)

    create_pdf(input_file, output_file)
