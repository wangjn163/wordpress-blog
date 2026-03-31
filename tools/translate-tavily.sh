#!/bin/bash
#
# Tavily内容翻译脚本
# 使用translate技能将Tavily英文搜索结果翻译成中文
# 作者：CrazyClaw
# 日期：2026-03-30
#

INPUT_FILE="/tmp/tavily_result.txt"
OUTPUT_FILE="/tmp/tavily_translated.txt"

echo "=== Tavily内容翻译工具 ===" 
echo "正在读取Tavily搜索结果..."

# 提取Answer部分
if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ 错误：找不到Tavily搜索结果文件 $INPUT_FILE"
    echo "请先运行Tavily搜索"
    exit 1
fi

# 使用Python提取和翻译
python3 << 'PYTHON_SCRIPT'
import re
import sys

# 读取文件
with open('/tmp/tavily_result.txt', 'r', encoding='utf-8') as f:
    content = f.read()

if '## Answer' not in content:
    print("❌ 错误：Tavily结果中没有找到Answer部分")
    sys.exit(1)

# 提取Answer
answer_section = content.split('## Answer')[1].split('## Sources')[0]
answer_text = answer_section.strip()

# 检测语言
chinese_chars = sum(1 for c in answer_text if '\u4e00' <= c <= '\u9fff')
total_chars = len(answer_text)

if total_chars > 0 and chinese_chars / total_chars >= 0.1:
    print("✓ 检测到中文内容，无需翻译")
    print("\n=== 原始内容 ===")
    print(answer_text)
    sys.exit(0)

print("✓ 检测到英文内容，准备翻译")
print("\n=== 原始英文内容 ===")
print(answer_text[:800])
print("...\n")

# 分割成句子
sentences = re.split(r'[.!?。！？]', answer_text)
sentences = [s.strip() for s in sentences if s.strip() and len(s) > 15]

print(f"✓ 提取了 {len(sentences)} 个句子")

# 关键词评分
key_topics = {
    'China': '中国', 'Chinese': '中国', 'AI': 'AI',
    'artificial intelligence': '人工智能', 'industry': '产业',
    'industrial': '工业', 'manufacturing': '制造业', 'forum': '论坛',
    'Beijing': '北京', 'government': '政府', 'investment': '投资',
    'development': '发展', 'technology': '技术', 'research': '研究',
    'model': '模型', 'multimodal': '多模态', 'agent': '智能体',
    'robotics': '机器人', 'embodied': '具身', 'intelligence': '智能',
    'application': '应用', 'commercial': '商业', 'ecosystem': '生态系统',
    'infrastructure': '基础设施', 'breakthrough': '突破',
    'innovation': '创新', 'dominance': '主导地位', 'scientific': '科学',
    'spending': '支出', 'global': '全球', 'market': '市场',
}

# 提取关键句子
key_sentences = []
for sentence in sentences[:10]:
    sentence_lower = sentence.lower()
    score = sum(1 for kw in key_topics if kw.lower() in sentence_lower)
    if score >= 2:
        key_sentences.append(sentence)

print(f"✓ 筛选出 {len(key_sentences)} 个关键句子")

# 保存待翻译内容
with open('/tmp/tavily_to_translate.txt', 'w', encoding='utf-8') as f:
    f.write("\n".join(key_sentences))

print("\n=== 待翻译句子 ===")
for i, s in enumerate(key_sentences, 1):
    print(f"{i}. {s[:100]}...")

print("\n" + "="*60)
print("📝 翻译说明：")
print("请将以上句子翻译成中文，要求：")
print("1. 保持专业术语的准确性（AI、multimodal、agent等）")
print("2. 保留专有名词（公司名、地名）")
print("3. 翻译流畅自然，符合中文表达习惯")
print("4. 每行用 • 开头")
print("="*60)
PYTHON_SCRIPT

echo ""
echo "💡 提示：将上述内容发送给AI进行翻译"
