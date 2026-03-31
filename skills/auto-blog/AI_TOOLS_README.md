# AI工具推荐去重功能

## 功能说明

自动博客生成系统现在具备智能AI工具推荐功能，可以：
- 自动从搜索结果中识别AI工具
- 避免重复推荐相同的工具
- 记录已推荐工具到数据库
- 当所有工具都推荐过后，使用备用工具池

## 工作流程

### 1. 工具识别
系统维护一个已知AI工具列表（`KNOWN_AI_TOOLS`），包含：
- 编程工具：GitHub Copilot, Cursor, Windsurf
- 聊天机器人：ChatGPT, Claude, Gemini, Bing Chat
- 图像生成：Midjourney, Stable Diffusion, DALL-E
- 写作助手：Jasper, Copy.ai, Grammarly, Wordtune
- 视频工具：Runway, Synthesia, Descript
- 开发平台：Hugging Face, LangChain, Pinecone
- 智能体：AutoGPT, AgentGPT, BabyAGI
- 等等...

### 2. 去重检查
- 从 `recommended_tools.json` 读取已推荐工具列表
- 检查候选工具是否在已推荐列表中
- 只推荐未推荐过的工具

### 3. 备用工具池
如果搜索结果中没有找到新工具，系统会从备用工具池中选择：
- Perplexity AI
- Notion AI
- Otter.ai
- Jasper
- Runway ML
- Hugging Face
- LangChain
- Fireflies.ai
- 等等...

### 4. 记录保存
每次推荐后，工具会自动记录到 `recommended_tools.json`

## 文件结构

```
/root/.openclaw/workspace/skills/auto-blog/scripts/
├── generate-blog.sh              # 主生成脚本（已集成工具推荐）
├── get-ai-tools.sh               # 工具推荐生成脚本
└── recommended_tools.json        # 已推荐工具数据库
```

## 手动管理

### 查看已推荐工具
```bash
cat /root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json
```

### 重置推荐记录
```bash
# 备份现有记录
cp /root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json \
   /root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json.backup

# 重置为空
echo '{"last_updated": "'$(date +%Y-%m-%d)'", "recommended_tools": []}' > \
   /root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json
```

### 手动测试工具推荐
```bash
bash /root/.openclaw/workspace/skills/auto-blog/scripts/get-ai-tools.sh
cat /tmp/ai_tools_recommendation.txt
```

### 添加新的已知工具
编辑 `get-ai-tools.sh` 中的 `KNOWN_AI_TOOLS` 数组：
```bash
KNOWN_AI_TOOLS=(
  "GitHub Copilot"
  "Cursor"
  # ... 添加新工具
  "新工具名称"
)
```

## 配置参数

在 `get-ai-tools.sh` 中可以调整：

```bash
local max_tools=3  # 每次推荐的最大工具数量
```

## 集成方式

主生成脚本 `generate-blog.sh` 会自动调用工具推荐功能：

```bash
# 生成内容前先获取工具推荐
generate_tools_recommendation

# 在Python脚本中读取推荐结果
tools_recommendation = "更多AI工具正在收集中，敬请期待..."
try:
    with open('/tmp/final_tools.txt', 'r', encoding='utf-8') as f:
        tools_recommendation = f.read().strip()
except:
    pass

# 在博客HTML中使用
<p>{tools_recommendation}</p>
```

## 示例输出

### 第一次推荐
```
🛠️ AI工具推荐（基于搜索结果）
Perplexity AI、Notion AI、Otter.ai
```

### 第二次推荐（不同工具）
```
🛠️ AI工具推荐（基于搜索结果）
Jasper、Runway ML、Hugging Face
```

### 所有工具都推荐过后
```
🛠️ AI工具推荐（基于搜索结果）
更多AI工具正在收集中，敬请期待...
```

## 注意事项

1. **数据库位置**：`recommended_tools.json` 存储在脚本目录中
2. **自动备份**：建议定期备份此文件
3. **手动干预**：如需重新推荐某个工具，可从JSON中手动删除
4. **扩展性**：可以通过编辑 `KNOWN_AI_TOOLS` 添加新工具
5. **推荐数量**：默认每次推荐3个，可根据需要调整

## 未来改进

- [ ] 添加工具分类标签（编程、写作、图像等）
- [ ] 记录推荐日期，避免短期内重复
- [ ] 支持工具描述和特点
- [ ] 从多个来源获取工具信息
- [ ] 工具评分和推荐优先级
