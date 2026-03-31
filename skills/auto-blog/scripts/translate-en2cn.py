#!/usr/bin/env python3
"""
英文翻译为中文的辅助脚本
使用 MyMemory 免费翻译API，支持分段翻译长文本
"""
import sys
import json
import urllib.request
import urllib.parse
import re
import time

def translate_text(text, source='en', target='zh-CN'):
    """翻译单个文本段"""
    if not text or not text.strip():
        return text
    
    # 检查中文占比，如果已经大部分是中文就跳过
    chinese_chars = sum(1 for c in text if '\u4e00' <= c <= '\u9fff')
    total = len(text.replace(' ', ''))
    if total > 0 and chinese_chars / total > 0.3:
        return text

    encoded = urllib.parse.quote(text)
    url = f"https://api.mymemory.translated.net/get?q={encoded}&langpair={source}|{target}"
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            translated = data.get('responseData', {}).get('translatedText', '')
            if translated and translated.upper() != text.upper():  # 确保确实翻译了
                return translated
    except Exception as e:
        print(f"⚠ 翻译失败: {e}", file=sys.stderr)
    
    return text  # 翻译失败返回原文

def smart_translate(text):
    """
    智能翻译：对长文本分段翻译，保持质量
    """
    if not text or len(text) < 10:
        return text
    
    # 检查中文占比
    chinese_chars = sum(1 for c in text if '\u4e00' <= c <= '\u9fff')
    total = len(text.replace(' ', ''))
    if total > 0 and chinese_chars / total > 0.3:
        return text  # 已经是中文为主，跳过

    # 短文本直接翻译
    if len(text) <= 500:
        return translate_text(text)
    
    # 长文本：按句子分段翻译
    sentences = re.split(r'(?<=[.!?])\s+', text)
    translated_parts = []
    current_chunk = ""
    
    for sentence in sentences:
        if len(current_chunk) + len(sentence) < 450:
            current_chunk += (" " if current_chunk else "") + sentence
        else:
            if current_chunk:
                translated = translate_text(current_chunk)
                translated_parts.append(translated)
                time.sleep(0.3)  # 避免频率限制
            current_chunk = sentence
    
    if current_chunk:
        translated = translate_text(current_chunk)
        translated_parts.append(translated)
    
    return ''.join(translated_parts)

def main():
    if len(sys.argv) < 2:
        print("Usage: translate-en2cn.py <text_or_file>")
        print("  If argument is a file path that exists, reads from file")
        print("  Otherwise treats argument as text to translate")
        sys.exit(1)
    
    input_arg = sys.argv[1]
    
    # 判断是文件还是文本
    import os
    if os.path.isfile(input_arg):
        with open(input_arg, 'r', encoding='utf-8') as f:
            text = f.read().strip()
    else:
        text = input_arg
    
    result = smart_translate(text)
    print(result)

if __name__ == '__main__':
    main()
