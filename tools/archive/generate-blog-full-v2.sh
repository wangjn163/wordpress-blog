#!/bin/bash
LOG_FILE="/var/log/blog-auto-generate-full.log"
export BAIDU_API_KEY="REDACTED_BAIDU_API_KEY"
export TAVILY_API_KEY="REDACTED_TAVILY_API_KEY"
cd /root/.openclaw/workspace || exit 1

TODAY=$(date '+%Y年%m月%d日')
DATE_SHORT=$(date '+%Y-%m-%d')
TIME_NOW=$(date '+%H:%M:%S')
TIMESTAMP=$(date '+%Y%m%d%H%M%S')
TITLE="AI 每日资讯 – $TODAY"
SLUG="ai-daily-$TIMESTAMP"

echo "========================================" | tee -a "$LOG_FILE"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "步骤1: 搜索AI新闻..." | tee -a "$LOG_FILE"

# 使用 Tavily 搜索（增加到10个结果）
echo "正在执行Tavily搜索..." | tee -a "$LOG_FILE"
TAVILY_RESULT=$(timeout 60 /root/.nvm/versions/node/v22.22.1/bin/node /root/.openclaw/workspace/skills/tavily-search/scripts/search.mjs "人工智能 AI 最新动态" --topic general -n 10 2>/dev/null)

if [ $? -eq 0 ] && echo "$TAVILY_RESULT" | grep -q "## Answer"; then
    echo "Tavily搜索成功" | tee -a "$LOG_FILE"
    
    # 提取 Answer 部分
    TAVILY_ANSWER=$(echo "$TAVILY_RESULT" | sed -n '/## Answer/,/## Sources/p' | tail -n +2 | head -n -1 | tr '\n' ' | sed 's/  */ /g' | head -c 800)
    
    # 保存完整结果用于调试
    echo "$TAVILY_RESULT" > /tmp/tavily_result_full.txt
    
    # 使用简单的方法提取 Sources
    Tavily_Sources_HTML=$(python3 << 'PYTHON_SCRIPT'
import re

with open('/tmp/tavily_result_full.txt', 'r', encoding='utf-8') as f:
    content = f.read()

# 找到 Sources 部分
sources_section = re.split(r'## Sources', content)[1] if '## Sources' in content else ''
lines = sources_section.split('\n')

html = ''
current_item = {}
item_count = 0

for line in lines:
    line = line.strip()
    if not line:
        continue
    
    # 匹配标题行: - **标题** (relevance: XX%)
    if line.startswith('- **') and '**' in line and 'relevance:' in line:
        if current_item and 'title' in current_item and item_count < 5:
            # 输出上一个项目
            title = current_item.get('title', '').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", "''")
            snippet = current_item.get('snippet', '')[:500].replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", "''")
            snippet = snippet.replace('#', '').replace('*', '')  # 移除markdown符号
            html += f'<li><strong>{title}</strong><br>{snippet}<br><small>来源：Tavily搜索</small></li>\n'
            item_count += 1
        
        # 提取新标题
        title_match = re.search(r'\*\*(.+?)\*\*', line)
        if title_match:
            current_item = {'title': title_match.group(1)}
    
    # 匹配URL行
    elif line.startswith('http'):
        current_item['url'] = line
    
    # 匹配内容行（以 # 开头）
    elif line.startswith('#'):
        current_item['snippet'] = line.lstrip('#').strip()

# 处理最后一个项目
if current_item and 'title' in current_item and item_count < 5:
    title = current_item.get('title', '').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", "''")
    snippet = current_item.get('snippet', '')[:500].replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", "''")
    snippet = snippet.replace('#', '').replace('*', '')
    html += f'<li><strong>{title}</strong><br>{snippet}<br><small>来源：Tavily搜索</small></li>\n'

print(html)
PYTHON_SCRIPT
)
else
    echo "Tavily搜索失败" | tee -a "$LOG_FILE"
    TAVILY_ANSWER="AI技术持续快速发展，各大科技公司不断推出新的产品和服务。"
    Tavily_Sources_HTML="<li><strong>备用内容</strong><br>AI技术正在快速发展中。<br><small>来源：Tavily备用</small></li>"
fi

# 使用百度搜索
echo "正在执行百度搜索..." | tee -a "$LOG_FILE"
python3 skills/baidu-search/scripts/search.py '{"query":"人工智能 AI news","count":5}' 2>/dev/null > /tmp/baidu_result.json

if [ -s /tmp/baidu_result.json ] && grep -q '"title"' /tmp/baidu_result.json; then
    echo "百度搜索成功" | tee -a "$LOG_FILE"
    
    # 解析百度搜索结果
    Baidu_Content=$(python3 << 'PYTHON_SCRIPT'
import json
try:
    with open('/tmp/baidu_result.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    html = ''
    for item in data[:5]:
        title = item.get('title', '').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", "''")
        date_str = item.get('date', '')[:10]
        content_text = item.get('content', '')[:600].replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", "''")
        website = item.get('website', '未知来源')
        html += f'<li><strong>{title}</strong><br>{content_text}<br><small>来源：{website} | {date_str}</small></li>\n'
    
    print(html)
except Exception as e:
    print(f'<li><strong>搜索错误</strong><br>{str(e)}<br><small>来源：系统</small></li>')
PYTHON_SCRIPT
)
else
    echo "百度搜索失败" | tee -a "$LOG_FILE"
    Baidu_Content="<li><strong>备用内容</strong><br>AI技术正在快速发展中。<br><small>来源：备用</small></li>"
fi

echo "步骤2: 生成文章..." | tee -a "$LOG_FILE"

# 转义单引号
TAVILY_ANSWER_ESCAPED=$(echo "$TAVILY_ANSWER" | sed "s/'/''/g")
Tavily_Sources_HTML_ESCAPED=$(echo "$Tavily_Sources_HTML" | sed "s/'/''/g")
Baidu_Content_ESCAPED=$(echo "$Baidu_Content" | sed "s/'/''/g")

# 生成完整的文章内容
ARTICLE_CONTENT="<article>
  <h2>从多模态革命到智能体时代</h2>
  <p>今天是${TODAY}，欢迎来到今天的 AI 每日资讯！</p>

  <h3>📰 行业动态概览 (Tavily AI总结)</h3>
  <p>${TAVILY_ANSWER_ESCAPED}</p>

  <h3>🔍 Tavily 搜索结果 (Top 5)</h3>
  <ul>
    ${Tavily_Sources_HTML_ESCAPED}
  </ul>

  <h3>🌐 百度搜索结果 (Top 5)</h3>
  <ul>
    ${Baidu_Content_ESCAPED}
  </ul>

  <h3>🛠️ 新工具推荐</h3>
  <ul>
    <li><strong>Claude Code</strong><br>Anthropic 推出的 AI 编程工具，支持多种编程语言和框架。</li>
    <li><strong>Cursor</strong><br>AI原生的代码编辑器，提供智能补全和代码解释功能。</li>
    <li><strong>GitHub Copilot</strong><br>GitHub 推出的 AI 编程助手，集成在IDE中提供实时建议。</li>
  </ul>

  <h3>🤖 模型更新</h3>
  <ul>
    <li><strong>开源模型</strong><br>Llama 3、Mistral、Qwen 等开源大模型性能持续提升。</li>
    <li><strong>模型能力</strong><br>各大公司持续突破模型能力限制。</li>
  </ul>

  <p style=\"color: #666; font-size:0.9em; margin-top:30px;\">
    📅 ${DATE_SHORT} ${TIME_NOW} | 🤖 由CrazyClaw自动生成 | 🔍 百度+Tavily搜索(10条) | 📍 重庆
  </p>
</article>"

# 使用 wp-publish-v2.sh 发布
echo "步骤3: 发布到WordPress..." | tee -a "$LOG_FILE"
/root/.openclaw/workspace/tools/wp-publish-v2.sh "$TITLE" "$ARTICLE_CONTENT"

echo "========================================" | tee -a "$LOG_FILE"
