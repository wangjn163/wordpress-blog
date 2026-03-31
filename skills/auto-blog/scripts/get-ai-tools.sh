#!/bin/bash
#
# AI工具推荐生成脚本
# 功能：根据搜索结果提取AI工具，避免重复推荐
#

TOOLS_DB="/root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json"
SEARCH_RESULT="/tmp/tavily_result.txt"
OUTPUT="/tmp/ai_tools_recommendation.txt"

# 已知AI工具列表（用于匹配）
KNOWN_AI_TOOLS=(
  "GitHub Copilot"
  "Cursor"
  "Windsurf"
  "Claude"
  "ChatGPT"
  "GPT-4"
  "Midjourney"
  "Stable Diffusion"
  "DALL-E"
  "Jasper"
  "Copy.ai"
  "Notion AI"
  "Otter.ai"
  "Perplexity"
  "Bing Chat"
  "Gemini"
  "Hugging Face"
  "LangChain"
  "Pinecone"
  "Vector Database"
  "AutoGPT"
  "AgentGPT"
  "BabyAGI"
  "Llama"
  "Mistral"
  "Cohere"
  "Anthropic"
  "OpenAI"
  "Runway"
  "Synthesia"
  "Descript"
  "Fireflies"
  "Grammarly"
  "Wordtune"
  "QuillBot"
)

# 从数据库读取已推荐工具
get_recommended_tools() {
  if [ -f "$TOOLS_DB" ]; then
    python3 -c "
import json
try:
    with open('$TOOLS_DB', 'r', encoding='utf-8') as f:
        data = json.load(f)
        for tool in data.get('recommended_tools', []):
            print(tool)
except:
    pass
"
  fi
}

# 检查工具是否已推荐
is_tool_recommended() {
  local tool="$1"
  local recommended=$(get_recommended_tools)
  if echo "$recommended" | grep -qi "^${tool}$"; then
    return 0  # 已推荐
  fi
  return 1  # 未推荐
}

# 从搜索结果中提取AI工具
extract_tools_from_search() {
  local found_tools=()

  # 读取搜索结果
  if [ ! -f "$SEARCH_RESULT" ]; then
    return 1
  fi

  # 搜索已知工具
  for tool in "${KNOWN_AI_TOOLS[@]}"; do
    # 转换为小写用于搜索
    local tool_lower=$(echo "$tool" | tr '[:upper:]' '[:lower:]')
    if grep -qi "$tool_lower" "$SEARCH_RESULT"; then
      # 检查是否已推荐
      if ! is_tool_recommended "$tool"; then
        found_tools+=("$tool")
      fi
    fi
  done

  # 输出找到的工具
  for tool in "${found_tools[@]}"; do
    echo "$tool"
  done
}

# 记录已推荐工具
record_recommended_tool() {
  local tool="$1"

  python3 << PYTHON_SCRIPT
import json
from datetime import datetime

tools_db = "$TOOLS_DB"
tool = "$tool"

# 读取现有数据
try:
    with open(tools_db, 'r', encoding='utf-8') as f:
        data = json.load(f)
except:
    data = {
        "last_updated": datetime.now().strftime('%Y-%m-%d'),
        "recommended_tools": []
    }

# 添加新工具（避免重复）
if tool not in data.get('recommended_tools', []):
    data['recommended_tools'].append(tool)
    data['last_updated'] = datetime.now().strftime('%Y-%m-%d')

    # 保存
    with open(tools_db, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"✓ 已记录工具: {tool}")
else:
    print(f"- 工具已存在: {tool}")
PYTHON_SCRIPT
}

# 生成推荐内容
generate_recommendation() {
  local tools=()
  local max_tools=3  # 每次最多推荐3个

  # 尝试从搜索结果提取
  while IFS= read -r tool; do
    tools+=("$tool")
    if [ ${#tools[@]} -ge $max_tools ]; then
      break
    fi
  done < <(extract_tools_from_search)

  # 如果没有找到新工具，使用备用工具池
  if [ ${#tools[@]} -eq 0 ]; then
    local backup_tools=(
      "Perplexity AI"
      "Notion AI"
      "Otter.ai"
      "Jasper"
      "Runway ML"
      "Hugging Face"
      "LangChain"
      "Fireflies.ai"
      "Synthesia"
      "Descript"
      "Grammarly"
      "Wordtune"
      "QuillBot"
      "Copy.ai"
      "Pinecone"
      "Vector Database"
      "Midjourney"
      "Stable Diffusion"
      "DALL-E"
      "Claude"
      "Gemini"
      "Bing Chat"
      "Cohere"
      "Mistral"
      "Llama"
      "AutoGPT"
      "AgentGPT"
      "BabyAGI"
    )

    for tool in "${backup_tools[@]}"; do
      if ! is_tool_recommended "$tool"; then
        tools+=("$tool")
        if [ ${#tools[@]} -ge $max_tools ]; then
          break
        fi
      fi
    done
  fi

  # 生成推荐文本
  if [ ${#tools[@]} -gt 0 ]; then
    {
      echo "## 推荐工具"
      for tool in "${tools[@]}"; do
        echo "$tool"
      done
    } > "$OUTPUT"

    # 记录到数据库
    for tool in "${tools[@]}"; do
      record_recommended_tool "$tool"
    done

    return 0
  else
    # 所有工具都推荐过了，生成通用提示
    {
      echo "## 通用推荐"
      echo "更多AI工具正在收集中，敬请期待..."
    } > "$OUTPUT"
    return 1
  fi
}

# 主函数
main() {
  generate_recommendation
}

main "$@"
