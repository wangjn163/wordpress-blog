#!/usr/bin/env python3
"""
改进的Tavily翻译测试脚本
"""

import re
import json

# 测试翻译
def translate_tavily_content():
    # 读取Tavily结果
    with open('/tmp/tavily_result.txt', 'r', encoding='utf-8') as f:
        content = f.read()

    if '## Answer' not in content:
        print("❌ 没有找到Answer部分")
        return

    answer_section = content.split('## Answer')[1].split('## Sources')[0]
    answer_text = answer_section.strip()

    # 检测语言
    chinese_chars = sum(1 for c in answer_text if '\u4e00' <= c <= '\u9fff')
    total_chars = len(answer_text)

    if total_chars > 0 and chinese_chars / total_chars >= 0.1:
        print("✓ 中文内容，无需翻译")
        print(answer_text)
        return

    print("=== 英文内容，开始翻译 ===\n")

    # 分割句子
    sentences = re.split(r'[.!?。！？]', answer_text)
    sentences = [s.strip() for s in sentences if s.strip() and len(s) > 15]

    # 完整的翻译词典
    translations = {
        # 专有名词
        'China': '中国', 'Chinese': '中国', 'China\'s': '中国',
        'Beijing': '北京', 'Hikvision': '海康威视',
        'Insilico Medicine': 'Insilico Medicine',  # 保留公司名
        'Eli Lilly': '礼来公司', 'Hannover Messe': '汉诺威工业展',

        # 技术术语
        'AI': 'AI', 'artificial intelligence': '人工智能',
        'multimodal': '多模态', 'agent': '智能体', 'agents': '智能体',
        'embodied intelligence': '具身智能', 'robotics': '机器人技术',
        'AIoT': 'AIoT', 'AI-powered': 'AI驱动的',

        # 行业词汇
        'industry': '产业', 'industrial': '工业', 'manufacturing': '制造业',
        'automation': '自动化', 'commercial': '商业', 'application': '应用',
        'applications': '应用', 'sector': '领域', 'sectors': '领域',
        'transportation': '交通', 'infrastructure': '基础设施',
        'ecosystem': '生态系统', 'solutions': '解决方案',

        # 动作词
        'is experiencing': '正经历', 'experiencing': '经历',
        'advancing': '发展', 'advancements': '进步',
        'fostering': '培育', 'highlighted': '强调',
        'emphasizing': '强调', 'enable': '实现',
        'shift from': '从...转向', 'gaining momentum': '势头强劲',
        'driven by': '由...推动', 'driven': '推动',
        'positioning': '使...成为', 'unveil': '发布',
        'showcasing': '展示', 'underscores': '强调',
        'leveraging': '利用', 'continues': '持续',
        'is set to': '即将', 'will': '将', 'which': '这',

        # 形容词/副词
        'significant': '重大', 'rapid': '快速', 'rapidly': '快速',
        'large-scale': '大规模', 'new': '新', 'substantial': '大幅',
        'global': '全球', 'scientific': '科学',

        # 名词
        'model': '模型', 'models': '模型', 'forum': '论坛',
        'Forum': '论坛', 'investment': '投资', 'development': '发展',
        'technology': '技术', 'technological': '技术的',
        'research': '研究', 'breakthrough': '突破',
        'breakthroughs': '突破', 'innovation': '创新',
        'dominance': '主导地位', 'spending': '支出',
        'market': '市场', 'deal': '交易', 'impact': '影响',
        'drug discovery': '药物研发', 'drugs': '药物',
        'leader': '领导者', 'increases': '增加',
        'contributions': '贡献', 'publications': '出版物',

        # 介词和连接词
        'with': '，', 'and': '和', 'of': '的',
        'in': '在', 'for': '用于', 'to': '向',
        'from': '从', 'by': '被', 'as': '作为',
        'the': '', 'a': '', 'an': '',  # 删除冠词

        # 常用词
        'focus': '重点', 'business models': '商业模式',
        'additionally': '此外', 'furthermore': '此外',
        'meanwhile': '同时', 'moreover': '而且',
        'costs': '成本', 'hardware': '硬件',
    }

    # 提取和翻译关键句子
    key_points = []

    for i, sentence in enumerate(sentences[:10]):
        sentence_lower = sentence.lower()

        # 计算关键词得分
        score = sum(1 for kw in translations.keys() if kw.lower() in sentence_lower)

        if score >= 5:  # 提高阈值
            # 翻译
            translated = sentence

            # 按长度排序替换（优先替换短语）
            for en_keyword, cn_keyword in sorted(translations.items(), key=lambda x: len(x[0]), reverse=True):
                pattern = r'\b' + re.escape(en_keyword) + r'\b'
                translated = re.sub(pattern, cn_keyword, translated, flags=re.IGNORECASE)

            # 清理多余空格和标点
            translated = re.sub(r'\s+', '', translated)  # 删除所有空格
            translated = re.sub(r',+', '，', translated)  # 统一逗号
            translated = translated.strip('，,')  # 删除首尾逗号

            if len(translated) > 20:  # 确保翻译结果有意义
                key_points.append(f"• {translated}")
                print(f"✓ 句子 {i+1}: 得分={score}")
                print(f"  {translated}")

    print(f"\n{'='*70}")
    print(f"✓ 翻译了 {len(key_points)} 个句子")
    print(f"{'='*70}\n")

    print("=== 最终结果 ===")
    for point in key_points[:5]:
        print(point)

    return '\n'.join(key_points[:5])

if __name__ == '__main__':
    translate_tavily_content()
