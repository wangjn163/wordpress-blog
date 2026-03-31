---
name: work-plan
description: 工作计划管理技能。用户告知当天工作计划后，自动在"工作计划"知识库中创建新的工作记录。支持创建、更新、查询工作计划。
homepage: https://ima.qq.com
metadata:
  openclaw:
    emoji: '📋'
    requires: { env: ['IMA_OPENAPI_CLIENTID', 'IMA_OPENAPI_APIKEY'] }
    primaryEnv: 'IMA_OPENAPI_CLIENTID'
  security:
    credentials_usage: |
      This skill requires user-provisioned IMA OpenAPI credentials (Client ID and API Key)
      to authenticate with the official IMA API at https://ima.qq.com.
      Credentials are ONLY sent to the official IMA API endpoint (ima.qq.com) as HTTP headers.
      No credentials are logged, stored in files, or transmitted to any other destination.
    allowed_domains:
      - ima.qq.com
---

# 工作计划管理 (Work Plan)

自动管理工作计划知识库，记录每日工作内容。

## Setup

1. 确保已在 IMA 创建"工作计划"知识库
2. 配置 IMA 凭证（参见 ima-skill）
3. 首次使用时搜索"工作计划"知识库并记录其 ID

## 凭证加载

```bash
# Load IMA credentials
IMA_CLIENT_ID="${IMA_OPENAPI_CLIENTID:-$(cat ~/.config/ima/client_id 2>/dev/null)}"
IMA_API_KEY="${IMA_OPENAPI_APIKEY:-$(cat ~/.config/ima/api_key 2>/dev/null)}"

if [ -z "$IMA_CLIENT_ID" ] || [ -z "$IMA_API_KEY" ]; then
  echo "缺少 IMA 凭证，请先配置"
  exit 1
fi
```

## API 辅助函数

```bash
ima_api() {
  local path="$1" body="$2"
  curl -s -X POST "https://ima.qq.com/$path" \
    -H "ima-openapi-clientid: $IMA_CLIENT_ID" \
    -H "ima-openapi-apikey: $IMA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$body"
}
```

## 工作流程

### 1. 获取知识库 ID

如果尚未缓存"工作计划"知识库 ID，先搜索获取：

```bash
search_kb() {
  ima_api "openapi/wiki/v1/search_knowledge_base" \
    "{\"query\": \"工作计划\", \"cursor\": \"\", \"limit\": 10}" \
    | jq -r '.data.info_list[] | select(.name == "工作计划") | .id'
}

KB_ID="${CACHED_WORK_PLAN_KB_ID:-$(search_kb)}"

if [ -z "$KB_ID" ]; then
  echo "未找到"工作计划"知识库，请先在 IMA 创建"
  exit 1
fi
```

### 2. 创建工作记录

根据用户提供的工作计划，创建笔记并添加到知识库：

```bash
create_work_record() {
  local date="$1"
  local content="$2"
  
  # 创建笔记
  local note_id=$(ima_api "openapi/note/v1/import_doc" \
    "{\"content_format\": 1, \"content\": \"$content\"}" \
    | jq -r '.data.doc_id')
  
  # 添加到知识库
  ima_api "openapi/wiki/v1/add_knowledge" \
    "{\"knowledge_base_id\": \"$KB_ID\", \"media_type\": 11, \"note_info\": {\"content_id\": \"$note_id\"}}" \
    | jq -r '.data.media_id'
}
```

## 用户意图识别

当用户说以下内容时，触发此技能：

- "今天的工作计划是：..."
- "帮我记录一下工作：..."
- "更新工作计划：..."
- "今日工作内容：..."

## 使用示例

用户说：
> "今天的工作计划是：1. 完成DRF 2台备份恢复流程测试 2. 研究DRF恢复效率问题"

Agent 应：
1. 识别日期（今天）
2. 提取工作内容
3. 创建笔记（包含本周目标、昨日工作、今日计划）
4. 添加到"工作计划"知识库

## 模板格式

```markdown
# 今日工作 (YYYY-MM-DD)

## 本周目标

### 一、DRF 评审会议待办
1. [状态] 任务描述
2. [状态] 任务描述

### 二、其他项目
• [状态] 任务描述

---

## 昨日工作 (YYYY-MM-DD)

### 一、项目名称
1. 任务描述
   • 详细说明

---

## 今日计划 (YYYY-MM-DD)

### 一、项目名称
1. 任务描述

---

进度总结：
- X/Y 目标已完成
- N 个进行中
- 今日重点：XXX
```

## 注意事项

1. 状态标签：[已完成]、[进行中]、[待开始]
2. 保持格式一致性
3. 每次创建新笔记，不覆盖旧内容
4. 自动计算日期（昨天、今天）
5. 如用户提供详细信息，填充完整模板；如仅提供要点，创建简化版本

## 缓存管理

首次获取知识库 ID 后，建议缓存到环境变量或文件：

```bash
# 缓存到文件
echo "$KB_ID" > /tmp/work_plan_kb_id.txt

# 后续使用
KB_ID="${CACHED_WORK_PLAN_KB_ID:-$(cat /tmp/work_plan_kb_id.txt 2>/dev/null)}"
```
