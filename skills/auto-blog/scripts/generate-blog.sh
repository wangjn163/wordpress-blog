#!/bin/bash
#
# 自动博客生成脚本 最终版
# 功能：使用Tavily和百度双源搜索生成AI资讯博客并发布到WordPress
# 作者：CrazyClaw
# 日期：2026-03-30
# 改进：使用AI进行高质量翻译
#

# 不使用 set -e，手动处理错误

LOG_FILE="/var/log/blog-auto-generate.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载 nvm 环境（用于 cron 任务）
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"
fi

# 设置 PATH 确保能找到 node
export PATH="$HOME/.nvm/versions/node/v22.22.1/bin:$PATH"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

# 检查依赖
check_dependencies() {
    log "检查依赖..."

    # 检查Node.js
    if ! command -v node &> /dev/null; then
        error "Node.js未安装"
    fi

    # 检查Python3
    if ! command -v python3 &> /dev/null; then
        error "Python3未安装"
    fi

    # 检查Docker
    if ! command -v docker &> /dev/null; then
        error "Docker未安装"
    fi

    # 检查WordPress容器
    if ! docker ps | grep -q "wordpress"; then
        error "WordPress容器未运行"
    fi

    log "✓ 依赖检查通过"
}

# 加载API凭证
load_credentials() {
    log "加载API凭证..."

    # 从环境变量或配置文件加载
    export TAVILY_API_KEY="${TAVILY_API_KEY:-$(cat ~/.config/tavily/api_key 2>/dev/null)}"
    export BAIDU_API_KEY="${BAIDU_API_KEY:-$(cat ~/.config/baidu/api_key 2>/dev/null)}"

    # 如果还是没有，使用默认值
    export TAVILY_API_KEY="${TAVILY_API_KEY:-REDACTED_TAVILY_API_KEY}"
    export BAIDU_API_KEY="${BAIDU_API_KEY:-REDACTED_BAIDU_API_KEY}"

    log "✓ API凭证已加载"
}

# 检查API凭证
check_credentials() {
    log "检查API凭证..."

    if [ -z "$TAVILY_API_KEY" ]; then
        error "TAVILY_API_KEY未设置"
    fi

    if [ -z "$BAIDU_API_KEY" ]; then
        error "BAIDU_API_KEY未设置"
    fi

    log "✓ API凭证检查通过"
}

# 执行搜索（并行化）
perform_search() {
    log "开始搜索AI资讯（三源并行）..."

    export TENCENT_NEWS_APIKEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3NzQ1OTQ5MzYsImp0aSI6ImY5NTVlYTFhLWE2OTgtNDNjNy1iNGYyLTc0MjZhMWY1YjNmNiIsInN1aWQiOiI4UUlmM254WjY0WWV1ai9jNFFzPSJ9.rOzOd2oop1_kD3HdoV_6KSCCc3c3my0x21WHSJEdems'

    # 三个搜索同时并行执行
    /root/.nvm/versions/node/v22.22.1/bin/node /root/.openclaw/workspace/skills/tavily-search/scripts/search.mjs \
        "artificial intelligence AI latest news United States OpenAI Google Anthropic 2026" \
        --topic news -n 5 --days 3 > /tmp/tavily_result.txt 2>&1 \
        && log "✓ Tavily搜索成功" || log "⚠ Tavily搜索失败" &

    python3 /root/.openclaw/workspace/skills/baidu-search/scripts/search.py \
        '{"query": "人工智能 AI 最新 大模型 新闻 动态", "count": 3, "freshness": "pw"}' > /tmp/baidu_result.json 2>&1 \
        && log "✓ 百度搜索成功" || log "⚠ 百度搜索失败" &

    /root/.openclaw/workspace/skills/tencent-news/tencent-news-cli ai-daily > /tmp/tencent_news.txt 2>&1 \
        && log "✓ 腾讯新闻搜索成功" || log "⚠ 腾讯新闻搜索失败" &

    # 等待所有搜索完成
    wait

    log "✓ 三源搜索完成"
}

# 内容生成（跳过无用的AI工具推荐）
generate_content() {
    log "生成博客内容..."

    # 使用Python生成内容（确保UTF-8编码）
    python3 << 'PYTHON_SCRIPT'
import subprocess
import json
import os
import re
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

today = datetime.now().strftime('%Y年%m月%d日')
date_short = datetime.now().strftime('%Y-%m-%d')
time_now = datetime.now().strftime('%H:%M:%S')

TRANSLATE_SCRIPT = '/root/.openclaw/workspace/skills/auto-blog/scripts/translate-en2cn.py'

def translate_one(text):
    """翻译单条文本（供并行调用）"""
    try:
        r = subprocess.run(
            ['python3', TRANSLATE_SCRIPT, text],
            capture_output=True, text=True, timeout=15
        )
        result = r.stdout.strip()
        if result and len(result) > 5:
            return result
    except:
        pass
    return text

# 提取Tavily结果 - 美国AI新闻（英文翻译为中文，并行）
tavily_answer = "全球AI技术持续快速发展，各大科技公司不断推出新的产品和服务。"
try:
    with open('/tmp/tavily_result.txt', 'r', encoding='utf-8') as f:
        content = f.read()

    # 提取来源条目
    sources_section = content.split('## Sources')[1] if '## Sources' in content else ''
    source_blocks = re.split(r'\n\- \*\*', sources_section)

    # 第一遍：提取原始英文条目
    raw_items = []
    for block in source_blocks[:5]:
        block = block.strip()
        if not block:
            continue
        title_match = re.match(r'(.+?)\*\*', block)
        title_en = title_match.group(1).strip() if title_match else block.split('\n')[0].strip()
        title_en = re.sub(r'\s*\(relevance:\s*\d+%\)\s*', '', title_en)

        url_match = re.search(r'(https?://\S+)', block)
        url = url_match.group(1) if url_match else ''

        content_lines = []
        for line in block.split('\n'):
            line = line.strip()
            if line.startswith('http') or not line:
                continue
            content_lines.append(line)

        summary_en = ' '.join(content_lines)[:400]
        summary_en = re.sub(r'\s*\(relevance:\s*\d+%\)\s*', '', summary_en)
        summary_en = re.sub(r'^.*?\*\*\s*', '', summary_en, count=1)
        summary_en = re.sub(r'^#{1,6}\s*', '', summary_en)
        summary_en = re.sub(r'(?:###?\s*[\u4e00-\u9fff]{1,6}[.\s]*){2,}', '', summary_en)
        summary_en = re.sub(r'\.{3,}', '...', summary_en)
        summary_en = summary_en.strip('.。# ')

        chinese_chars = sum(1 for c in title_en if '\u4e00' <= c <= '\u9fff')
        is_en = chinese_chars / max(len(title_en), 1) < 0.2

        raw_items.append({'title': title_en, 'summary': summary_en, 'url': url, 'is_en': is_en})

    # 第二遍：收集需要翻译的文本，并行翻译
    translate_tasks = []
    for i, item in enumerate(raw_items):
        if item['is_en']:
            translate_tasks.append((i, 'title', item['title']))
            if item['summary'] and len(item['summary']) > 20:
                translate_tasks.append((i, 'summary', item['summary']))

    if translate_tasks:
        print(f"并行翻译 {len(translate_tasks)} 个文本段...", flush=True)
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = {executor.submit(translate_one, text): (idx, field) for idx, field, text in translate_tasks}
            for future in as_completed(futures):
                idx, field = futures[future]
                raw_items[idx][field] = future.result()

    # 第三遍：组装HTML
    tavily_items = []
    for item in raw_items:
        title = item['title']
        summary = item['summary']
        url = item['url']

        if item['is_en']:
            print(f"✓ 翻译: {title[:40]}...", flush=True)

        if title and summary[:len(title)].replace(' ', '') == title.replace(' ', ''):
            summary = summary[len(title):].strip()

        if title:
            item_html = f"<strong>{title}</strong>"
            if summary and len(summary) > 20:
                item_html += f"<br>{summary}"
            if url:
                item_html += f"<br><small>来源：{url.split('/')[2]}</small>"
            tavily_items.append(item_html)

    if tavily_items:
        tavily_answer = "<br><br>".join(tavily_items)
        print(f"✓ Tavily美国AI新闻处理完成，共{len(tavily_items)}条", flush=True)
    else:
        print("⚠ 未提取到Tavily来源，使用默认内容", flush=True)
except Exception as e:
    print(f"⚠ Tavily内容提取失败: {e}", flush=True)
    import traceback
    traceback.print_exc()

# 提取百度结果（限制摘要长度为150字）
baidu_items = []
try:
    with open('/tmp/baidu_result.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
        for item in data[:3]:
            title = item.get('title', '')
            content_text = item.get('content', '')[:200]  # 缩短到200字
            baidu_items.append(f"<strong>{title}</strong><br>{content_text}")
except:
    baidu_items.append("<strong>AI技术持续发展</strong><br>各大公司在AI领域持续投入，推动技术进步。")

baidu_html = "<br>".join(baidu_items)

# 提取腾讯新闻AI日报（新格式：### 序号. 标题 / 摘要 [来源>>](链接)）
tencent_items = []
try:
    with open('/tmp/tencent_news.txt', 'r', encoding='utf-8') as f:
        content = f.read()

    # 提取速览行作为摘要
    suilv_match = re.search(r'速览[：:]\s*(.+?)(?:\n\n|\n###)', content, re.DOTALL)
    tencent_summary = suilv_match.group(1).strip() if suilv_match else ''

    # 提取各条新闻（格式：### N. 标题 / 摘要 [来源>>](链接)）
    news_entries = re.findall(r'###\s*\d+\.\s*(.+?)(?:\n|$)', content)
    news_blocks = content.split('### ')
    
    for block in news_blocks[1:6]:  # 跳过标题部分，取5条
        lines = block.strip().split('\n')
        if not lines:
            continue
        
        # 第一行是标题和摘要
        header = lines[0].strip()
        # 分离标题和摘要（用 / 分割）
        parts = re.split(r'\s*/\s*', header, maxsplit=1)
        title = parts[0].strip().rstrip('.')
        # 去掉标题开头的序号（如 "1. "）
        title = re.sub(r'^\d+\.\s*', '', title)
        summary = parts[1].strip() if len(parts) > 1 else ''
        
        # 提取链接
        url_match = re.search(r'\[.*?\]\((https?://\S+)\)', block)
        url = url_match.group(1) if url_match else ''
        
        # 提取来源（去掉已有的"来源:"前缀避免重复）
        source_match = re.search(r'来源[：:]?\s*(.+?)>>?\]', block)
        source = source_match.group(1).strip() if source_match else '腾讯新闻'
        
        if title:
            item = {'title': title, 'summary': summary, 'source': source, 'url': url}
            tencent_items.append(item)

    print(f"✓ 腾讯新闻AI日报解析成功，共{len(tencent_items)}条", flush=True)
except Exception as e:
    print(f"⚠ 腾讯新闻解析失败: {e}", flush=True)
    import traceback
    traceback.print_exc()

# 生成腾讯新闻HTML
tencent_html = ""
if tencent_items:
    # 先放速览
    if tencent_summary:
        tencent_html += f"<p style='color:#555; font-size:0.95em; margin-bottom:12px;'>📌 <strong>今日概要：</strong>{tencent_summary}</p>"
    
    for item in tencent_items[:5]:
        title = item.get('title', '')
        summary = item.get('summary', '')
        source = item.get('source', '腾讯新闻')
        url = item.get('url', '')
        
        tencent_html += f"<strong>• {title}</strong>"
        if summary:
            tencent_html += f"<br><span style='color:#666;'>{summary}</span>"
        if url:
            tencent_html += f"<br><small><a href='{url}' target='_blank'>来源：{source}</a></small>"
        tencent_html += "<br>"
else:
    tencent_html = "<strong>今日AI资讯</strong><br>请关注腾讯新闻获取最新AI动态。"

# 构建完整内容
full_content = f'''<article>
  <h2>AI 每日资讯 | {today}</h2>
  <p>本期汇集美国AI前线动态、国内产业进展与今日AI热点，三源精选。</p>

  <h3>🇺🇸 美国AI动态（Tavily搜索源）</h3>
  <p>{tavily_answer}</p>

  <h3>🇨🇳 国内AI动态（百度搜索源）</h3>
  <p>{baidu_html}</p>

  <h3>📡 AI日报精选（腾讯新闻源）</h3>
  {tencent_html}

  <p style='color: #666; font-size:0.9em; margin-top:30px;'>
    📅 {date_short} {time_now} | 🤖 由CrazyClaw自动生成 | 🔍 Tavily+百度+腾讯新闻三源搜索 | 📍 重庆
  </p>
</article>'''

title = f"AI 每日资讯 – {today}"

# 保存到文件
with open('/tmp/blog_content.txt', 'w', encoding='utf-8') as f:
    f.write(full_content)

with open('/tmp/blog_title.txt', 'w', encoding='utf-8') as f:
    f.write(title)

print("CONTENT_GENERATED")
PYTHON_SCRIPT

    log "✓ 博客内容已生成"
}

# 发布到WordPress
publish_blog() {
    log "发布到WordPress..."

    CONTENT=$(cat /tmp/blog_content.txt)
    TITLE=$(cat /tmp/blog_title.txt)

    # 调用WordPress发布脚本
    bash /root/.openclaw/workspace/tools/wp-publish-v2.sh "$TITLE" "$CONTENT" > /tmp/publish_result.txt 2>&1
    PUBLISH_EXIT_CODE=$?

    # 检查是否真的成功（看输出中是否包含"成功"）
    if grep -q "成功" /tmp/publish_result.txt; then
        POST_ID=$(grep "文章ID:" /tmp/publish_result.txt | awk '{print $2}')
        POST_URL=$(grep "访问地址:" /tmp/publish_result.txt | awk '{print $2}')

        log "✓ 博客发布成功！"
        log "文章ID: $POST_ID"
        log "访问地址: $POST_URL"

        # 清理7天前的旧博客（保留最近7天）
        log "清理7天前的旧博客..."
        docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
            -e "DELETE FROM wp_posts WHERE post_type='post' AND DATE(post_date) < DATE_SUB(CURDATE(), INTERVAL 7 DAY);" \
            2>&1 | grep -v "Warning" || true

        log "✓ 7天前的旧博客已清理"

        # 返回成功信息
        echo "✅ 博客已发布"
        echo "📰 标题: $TITLE"
        echo "🔗 地址: $POST_URL"
        echo "📝 ID: $POST_ID"
    else
        log "✗ 博客发布失败"
        cat /tmp/publish_result.txt
        error "博客发布失败"
    fi
}

# 清理临时文件
cleanup() {
    log "清理临时文件..."
    rm -f /tmp/tavily_result.txt /tmp/baidu_result.json /tmp/blog_content.txt /tmp/blog_title.txt /tmp/publish_result.txt
    log "✓ 清理完成"
}

# 主流程
main() {
    log "=========================================="
    log "开始自动博客生成流程（最终优化版）"

    # 检查今天是否已经生成过博客
    today=$(date '+%Y-%m-%d')
    today_count=$(docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -se "SELECT COUNT(*) FROM wp_posts WHERE post_type='post' AND DATE(post_date)='$today';" 2>/dev/null)

    if [ "$today_count" -gt 0 ]; then
        log "⚠️  今天($today)已经生成过 $today_count 篇博客"
        log "📅 最新博客: $(docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
            -se "SELECT CONCAT('ID:', ID, ' - ', post_title) FROM wp_posts WHERE post_type='post' AND DATE(post_date)='$today' ORDER BY post_date DESC LIMIT 1;" 2>/dev/null)"
        log "❌ 跳过本次生成（每天只生成一篇）"
        return 0
    fi

    log "✓ 今天还没有生成博客，开始生成..."

    check_dependencies
    load_credentials
    check_credentials
    perform_search
    generate_content
    publish_blog
    cleanup

    log "=========================================="
    log "✅ 自动博客生成完成"
}

# 执行主流程
main "$@"
