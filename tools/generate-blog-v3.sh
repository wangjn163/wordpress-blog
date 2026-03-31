#!/bin/bash
#
# 自动博客生成脚本 V3（简化翻译集成版）
# 功能：使用Tavily和百度双源搜索生成AI资讯博客并发布到WordPress
# 作者：CrazyClaw
# 日期：2026-03-30
# 改进：简化的翻译流程，更易维护
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

# 执行搜索
perform_search() {
    log "开始搜索AI资讯..."
    
    # Tavily搜索
    log "1. 执行Tavily搜索..."
    /root/.nvm/versions/node/v22.22.1/bin/node /root/.openclaw/workspace/skills/tavily-search/scripts/search.mjs \
        "China artificial intelligence AI latest news developments 2026" \
        --topic news -n 5 --days 3 > /tmp/tavily_result.txt 2>&1
    
    if [ $? -eq 0 ] && grep -q "## Answer" /tmp/tavily_result.txt; then
        log "✓ Tavily搜索成功"
    else
        log "⚠ Tavily搜索失败，使用默认内容"
    fi
    
    # 百度搜索（添加时间过滤，只搜索最近2天）
    log "2. 执行百度搜索..."
    python3 /root/.openclaw/workspace/skills/baidu-search/scripts/search.py \
        '{"query": "人工智能 AI 最新 大模型 新闻 动态", "count": 3, "freshness": "pw"}' > /tmp/baidu_result.json 2>&1
    
    if [ $? -eq 0 ] && [ -s /tmp/baidu_result.json ]; then
        log "✓ 百度搜索成功"
    else
        log "⚠ 百度搜索失败，使用默认内容"
    fi
    
    # 腾讯新闻热点（添加中文新闻源）
    log "3. 执行腾讯新闻搜索..."
    export TENCENT_NEWS_APIKEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3NzQ1OTQ5MzYsImp0aSI6ImY5NTVlYTFhLWE2OTgtNDNjNy1iNGYyLTc0MjZhMWY1YjNmNiIsInN1aWQiOiI4UUlmM254WjY0WWV1ai9jNFFzPSJ9.rOzOd2oop1_kD3HdoV_6KSCCc3c3my0x21WHSJEdems'
    /root/.openclaw/workspace/skills/tencent-news/tencent-news-cli hot --limit 3 > /tmp/tencent_news.txt 2>&1
    
    if [ $? -eq 0 ] && [ -s /tmp/tencent_news.txt ]; then
        log "✓ 腾讯新闻搜索成功"
    else
        log "⚠ 腾讯新闻搜索失败，使用默认内容"
    fi
}

# 生成AI工具推荐
generate_tools_recommendation() {
    log "生成AI工具推荐..."
    
    # 调用工具推荐脚本
    bash /root/.openclaw/workspace/skills/auto-blog/scripts/get-ai-tools.sh
    
    if [ $? -eq 0 ]; then
        # 读取推荐结果 - 提取工具名称（跳过标题行）
        if [ -f /tmp/ai_tools_recommendation.txt ]; then
            # 使用iconv确保UTF-8编码，然后提取工具名称
            tools=$(iconv -f UTF-8 -t UTF-8 /tmp/ai_tools_recommendation.txt 2>/dev/null | grep -v "^##" | grep -v "^$" | tr '\n' '、' | sed 's/、$//')
            if [ -n "$tools" ]; then
                echo "$tools" > /tmp/final_tools.txt
                log "✓ AI工具推荐已生成: $tools"
                return 0
            fi
        fi
    fi
    
    # 如果生成失败，使用默认内容
    echo "更多AI工具正在收集中，敬请期待..." > /tmp/final_tools.txt
    log "⚠ 使用默认工具推荐"
    return 1
}

# 生成博客内容（简化版，使用智能关键词替换）
generate_content() {
    log "生成博客内容..."
    
    # 使用Python生成内容（确保UTF-8编码）
    python3 << 'PYTHON_SCRIPT'
import subprocess
import json
import os
import re
from datetime import datetime

# 先生成工具推荐
print("生成AI工具推荐...", flush=True)
result = subprocess.run(['bash', '/root/.openclaw/workspace/skills/auto-blog/scripts/get-ai-tools.sh'], 
                       capture_output=True, text=True)
    
tools_recommendation = "更多AI工具正在收集中，敬请期待..."
try:
    with open('/tmp/ai_tools_recommendation.txt', 'r', encoding='utf-8') as f:
        content = f.read()
        # 提取工具名称
        tools = '\n'.join([line for line in content.split('\n') if not line.startswith('##') and line.strip()])
        if tools:
            tools_recommendation = tools.replace('\n', '、')
            print(f"✓ AI工具推荐已生成: {tools_recommendation}", flush=True)
        else:
            print("⚠ 未找到新工具，使用默认推荐", flush=True)
except Exception as e:
    print(f"⚠ 工具推荐读取失败: {e}", flush=True)
    
today = datetime.now().strftime('%Y年%m月%d日')
date_short = datetime.now().strftime('%Y-%m-%d')
time_now = datetime.now().strftime('%H:%M:%S')

# 提取Tavily结果（改进的智能翻译）
tavily_answer = "全球AI技术持续快速发展，各大科技公司不断推出新的产品和服务。"
try:
    with open('/tmp/tavily_result.txt', 'r', encoding='utf-8') as f:
        content = f.read()
        if '## Answer' in content:
            answer_section = content.split('## Answer')[1].split('## Sources')[0]
            answer_text = answer_section.strip()
            
            # 检测是否为英文
            chinese_chars = sum(1 for c in answer_text if '\u4e00' <= c <= '\u9fff')
            total_chars = len(answer_text)
            
            if total_chars > 0 and chinese_chars / total_chars < 0.1:
                # 英文内容，智能提取和翻译
                print("检测到英文内容，开始智能翻译...", flush=True)
                
                # 分割成句子
                sentences = re.split(r'[.!?。！？]', answer_text)
                sentences = [s.strip() for s in sentences if s.strip() and len(s) > 15]
                
                # 改进的关键词映射（更准确的翻译）
                translations = {
                    'China': '中国',
                    'Chinese': '中国',
                    'China\'s': '中国',
                    'AI': 'AI',
                    'artificial intelligence': '人工智能',
                    'industry': '产业',
                    'industrial': '工业',
                    'manufacturing': '制造业',
                    'forum': '论坛',
                    'Forum': '论坛',
                    'Beijing': '北京',
                    'government': '政府',
                    'investment': '投资',
                    'development': '发展',
                    'technology': '技术',
                    'technological': '技术',
                    'research': '研究',
                    'model': '模型',
                    'models': '模型',
                    'multimodal': '多模态',
                    'agent': '智能体',
                    'agents': '智能体',
                    'robotics': '机器人',
                    'embodied': '具身',
                    'intelligence': '智能',
                    'application': '应用',
                    'applications': '应用',
                    'commercial': '商业',
                    'ecosystem': '生态系统',
                    'infrastructure': '基础设施',
                    'breakthrough': '突破',
                    'breakthroughs': '突破',
                    'innovation': '创新',
                    'dominance': '主导地位',
                    'scientific': '科学',
                    'spending': '支出',
                    'global': '全球',
                    'market': '市场',
                    'rapidly': '快速',
                    'advancing': '发展',
                    'fostering': '培育',
                    'emphasizing': '强调',
                    'enable': '实现',
                    'sectors': '领域',
                    'transportation': '交通',
                    'momentum': '势头',
                    'driven': '推动',
                    'declining': '下降',
                    'positioning': '使...成为',
                    'leader': '领导者',
                    'automation': '自动化',
                    'significant': '重大',
                    'strides': '进展',
                    'evidenced': '证明',
                    'deal': '交易',
                    'bring': '推向',
                    'large-scale': '大规模',
                    'business models': '商业模式',
                    'shift from': '从...转向',
                    'gaining momentum': '势头强劲',
                }
                
                # 提取关键信息点并翻译
                key_points = []
                
                for i, sentence in enumerate(sentences[:12]):
                    sentence_lower = sentence.lower()
                    
                    # 检测是否包含重要关键词
                    score = 0
                    for en_keyword in translations.keys():
                        if en_keyword.lower() in sentence_lower:
                            score += 1
                    
                    # 只保留包含至少3个关键词的句子（提高质量）
                    if score >= 3:
                        # 智能翻译
                        translated = sentence
                        # 按长度排序，先替换长的短语
                        for en_keyword, cn_keyword in sorted(translations.items(), key=lambda x: len(x[0]), reverse=True):
                            pattern = r'\b' + re.escape(en_keyword) + r'\b'
                            translated = re.sub(pattern, cn_keyword, translated, flags=re.IGNORECASE)
                        
                        key_points.append(f"• {translated}")
                        print(f"✓ 翻译句子 {i+1}: 评分={score}", flush=True)
                
                print(f"✓ 翻译了 {len(key_points)} 个关键句", flush=True)
                
                # 如果翻译的句子太少，降低阈值
                if len(key_points) < 3:
                    print("⚠ 翻译结果较少，重新提取...", flush=True)
                    key_points = []
                    for sentence in sentences[:8]:
                        translated = sentence
                        for en_keyword, cn_keyword in sorted(translations.items(), key=lambda x: len(x[0]), reverse=True):
                            pattern = r'\b' + re.escape(en_keyword) + r'\b'
                            translated = re.sub(pattern, cn_keyword, translated, flags=re.IGNORECASE)
                        key_points.append(f"• {translated}")
                
                # 限制数量并格式化
                if key_points:
                    tavily_answer = "\n".join(key_points[:5])  # 最多5个要点
                else:
                    tavily_answer = f"{answer_text[:500]}..."
                    print("⚠ 使用原始内容摘要", flush=True)
            else:
                tavily_answer = answer_text
                print("✓ 使用中文原始内容", flush=True)
except Exception as e:
    print(f"⚠ Tavily内容提取失败: {e}", flush=True)
    import traceback
    traceback.print_exc()

# 提取百度结果
baidu_items = []
try:
    with open('/tmp/baidu_result.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
        for item in data[:2]:
            title = item.get('title', '')
            content_text = item.get('content', '')[:500]
            baidu_items.append(f"<strong>{title}</strong><br>{content_text}")
except:
    baidu_items.append("<strong>AI技术持续发展</strong><br>各大公司在AI领域持续投入，推动技术进步。")

baidu_html = "<br>".join(baidu_items)

# 提取腾讯新闻结果（热点新闻）
tencent_items = []
try:
    with open('/tmp/tencent_news.txt', 'r', encoding='utf-8') as f:
        content = f.read()
        # 解析腾讯新闻格式（数字序号格式）
        lines = content.split('\n')
        current_item = {}
        for line in lines:
            line = line.strip()
            # 匹配 "1. 标题：" 或 "标题：" 格式
            if line and line[0].isdigit() and '标题：' in line:
                if current_item:  # 保存上一个
                    tencent_items.append(current_item)
                title = line.split('标题：')[1].strip()
                current_item = {'title': title}
            elif '标题：' in line and not line[0].isdigit():
                if current_item:  # 保存上一个
                    tencent_items.append(current_item)
                title = line.split('标题：')[1].strip()
                current_item = {'title': title}
            elif '摘要:' in line and current_item:
                summary = line.split('摘要:')[1].strip()
                current_item['summary'] = summary
            elif '摘要:' in line and '摘要' not in current_item:
                summary = line.split('摘要:')[1].strip()
                current_item['summary'] = summary
            elif '来源:' in line and current_item:
                source = line.split('来源:')[1].strip()
                current_item['source'] = source
        if current_item:
            tencent_items.append(current_item)
        
        # 只取前3条
        tencent_items = tencent_items[:3]
except:
    tencent_items = []

# 生成腾讯新闻HTML
tencent_html = ""
if tencent_items:
    for item in tencent_items:
        title = item.get('title', '')
        summary = item.get('summary', '')[:300]
        source = item.get('source', '腾讯新闻')
        tencent_html += f"<strong>{title}</strong><br>{summary}<br><small>来源：{source}</small><br><br>"
else:
    tencent_html = "<strong>今日热点</strong><br>关注腾讯新闻获取最新资讯。"

# 构建完整内容
full_content = f'''<article>
  <h2>从多模态革命到智能体时代</h2>
  <p>今天是{today},欢迎来到今天的 AI 每日资讯！本期汇集了Tavily、百度和腾讯新闻三源的AI最新动态。</p>

  <h3>🔥 最新AI动态（Tavily搜索源）</h3>
  <p>{tavily_answer}</p>

  <h3>🇨🇳 国内AI动态（百度搜索源）</h3>
  <p>{baidu_html}</p>

  <h3>📰 今日热点（腾讯新闻源）</h3>
  <p>{tencent_html}</p>

  <h3>🛠️ AI工具推荐（基于搜索结果）</h3>
  <p>{tools_recommendation}</p>

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
    rm -f /tmp/ai_tools_recommendation.txt /tmp/final_tools.txt
    log "✓ 清理完成"
}

# 主流程
main() {
    log "=========================================="
    log "开始自动博客生成流程 V3（改进翻译）"
    
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
