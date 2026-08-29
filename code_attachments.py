#!/usr/bin/env python3
"""
Extract code blocks from HTML, save as files, and inject attachment links.
This prepares HTML for WeasyPrint's native attachment feature.
"""
import sys
import re
import os
import tempfile
import json

def extract_code_blocks(html_content):
    """Extract code blocks from HTML."""
    code_blocks = []

    # Find all code blocks with syntax highlighting
    pattern = r'<div class="sourceCode" id="(\w+)"><pre class="sourceCode (\w+?)"><code class="sourceCode \w+?">(.*?)</code></pre></div>'
    matches = re.findall(pattern, html_content, re.DOTALL)

    for block_id, lang, content in matches:
        # Decode HTML entities
        content = content.replace('&lt;', '<')
        content = content.replace('&gt;', '>')
        content = content.replace('&amp;', '&')
        content = content.replace('&quot;', '"')
        content = content.replace('&#39;', "'")

        # Remove syntax highlighting spans
        content = re.sub(r'<span[^>]*>', '', content)
        content = re.sub(r'</span>', '', content)
        content = re.sub(r'<a[^>]*>', '', content)
        content = re.sub(r'</a>', '', content)

        code_blocks.append({
            'id': block_id,
            'lang': lang,
            'content': content.strip()
        })

    return code_blocks

def get_file_extension(language):
    """Map language to file extension."""
    extensions = {
        'json': '.json',
        'javascript': '.js',
        'js': '.js',
        'python': '.py',
        'bash': '.sh',
        'sh': '.sh',
        'yaml': '.yaml',
        'yml': '.yaml',
        'xml': '.xml',
        'sql': '.sql',
        'java': '.java',
        'cpp': '.cpp',
        'c': '.c',
        'cs': '.cs',
        'go': '.go',
        'rust': '.rs',
        'ruby': '.rb',
        'php': '.php',
        'html': '.html',
        'css': '.css',
    }
    return extensions.get(language.lower(), '.txt')

def get_language_label(language):
    """Map language code to a display label for the attachment badge."""
    labels = {
        'json': 'JSON',
        'javascript': 'JS',
        'js': 'JS',
        'typescript': 'TS',
        'ts': 'TS',
        'python': 'PYTHON',
        'bash': 'BASH',
        'sh': 'BASH',
        'yaml': 'YAML',
        'yml': 'YAML',
        'xml': 'XML',
        'sql': 'SQL',
        'java': 'JAVA',
        'cpp': 'C++',
        'c': 'C',
        'cs': 'C#',
        'go': 'GO',
        'rust': 'RUST',
        'ruby': 'RUBY',
        'php': 'PHP',
        'html': 'HTML',
        'css': 'CSS',
    }
    return labels.get(language.lower(), 'CODE')

def save_code_blocks(code_blocks, output_dir):
    """Save code blocks as files and return mapping."""
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    file_mapping = []

    for i, block in enumerate(code_blocks, 1):
        ext = get_file_extension(block['lang'])
        filename = f"code_{i:03d}{ext}"
        filepath = os.path.join(output_dir, filename)

        # Save the code block
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(block['content'])

        file_mapping.append({
            'id': block['id'],
            'filename': filename,
            'filepath': filepath,
            'lang': block['lang']
        })

        # Don't print individual file saves - too verbose

    return file_mapping

def inject_attachment_links(html_content, file_mapping, code_dir):
    """Add attachment links to HTML."""
    # Use rel="attachment" which DOES work in Firefox (needs double-click)
    # Yes, it creates comments in Adobe, but at least it's functional

    for item in file_mapping:
        block_pattern = rf'<div class="sourceCode" id="{item["id"]}">'

        # Use absolute file:// path for attachments
        abs_path = os.path.abspath(item['filepath'])
        file_url = f"file://{abs_path}"

        # Language badge + download link
        lang_label = get_language_label(item['lang'])
        badge_html = f'''<div style="margin: 0 0 -8px 0; padding: 0; line-height: 1;">
<a rel="attachment" href="{file_url}" download="{item['filename']}" style="display: inline-block; padding: 3px 8px; background-color: #2998F5; border-top-left-radius: 3px; border-top-right-radius: 3px; color: #fff; font-size: 0.65em; font-family: monospace; text-decoration: none; font-weight: 700; letter-spacing: 0.5px;">
{lang_label}
</a>
<span style="color: #aaa; font-size: 0.55em; margin-left: 4px;">&lt;&lt; double-click to open the attachment</span>
</div>'''

        # Wrap badge + code block together to prevent page-break separation
        full_block_pattern = re.compile(
            rf'(<div class="sourceCode" id="{item["id"]}">.*?</code></pre></div>)',
            re.DOTALL
        )
        html_content = full_block_pattern.sub(
            lambda m: f'<div style="page-break-inside: avoid;">{badge_html}{m.group(1)}</div>',
            html_content,
            count=1
        )

    return html_content

def main():
    # Read HTML from stdin
    html_content = sys.stdin.read()

    # Get output directory for code files (default to temp)
    code_dir = os.environ.get('CODE_OUTPUT_DIR', 'code_attachments')

    # Extract code blocks
    code_blocks = extract_code_blocks(html_content)

    if not code_blocks:
        # No code blocks, output unchanged HTML
        print(html_content)
        return 0

    print(f"Found {len(code_blocks)} code blocks", file=sys.stderr)

    # Save code blocks as files
    file_mapping = save_code_blocks(code_blocks, code_dir)

    # Inject attachment links into HTML
    html_with_attachments = inject_attachment_links(html_content, file_mapping, code_dir)

    # Output the modified HTML
    print(html_with_attachments)

    print(f"✅ Prepared {len(file_mapping)} code attachments in {code_dir}/", file=sys.stderr)
    return 0

if __name__ == "__main__":
    sys.exit(main())