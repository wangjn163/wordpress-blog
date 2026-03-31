# AI工具推荐功能快速指南

## ✅ 已完成

AI工具推荐去重功能已成功集成到自动博客生成系统中！

### 核心功能

1. **智能推荐**：自动从搜索结果中识别AI工具
2. **去重机制**：记录已推荐工具，避免重复
3. **备用工具池**：当搜索结果无新工具时，从备用池选择
4. **自动记录**：每次推荐后自动保存到数据库

### 文件清单

```
/root/.openclaw/workspace/skills/auto-blog/
├── scripts/
│   ├── generate-blog.sh           # 主生成脚本（已集成）
│   ├── get-ai-tools.sh            # 工具推荐脚本（新增）
│   └── recommended_tools.json     # 工具数据库（新增）
├── AI_TOOLS_README.md             # 详细文档
└── QUICK_START.md                 # 本文件
```

## 🎯 使用方法

### 自动运行（推荐）
无需任何操作！系统会在每天早上9点自动运行，工具推荐功能会自动工作。

### 手动测试
```bash
# 测试工具推荐功能
bash /root/.openclaw/workspace/skills/auto-blog/scripts/get-ai-tools.sh

# 查看推荐结果
cat /tmp/ai_tools_recommendation.txt

# 查看已推荐工具
cat /root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json
```

### 完整生成测试
```bash
# 手动触发完整博客生成（包含工具推荐）
bash /root/.openclaw/workspace/skills/auto-blog/scripts/generate-blog.sh
```

## 📊 当前状态

### 已推荐工具（11个）
1. GitHub Copilot
2. Cursor
3. Windsurf
4. Perplexity AI
5. Notion AI
6. Otter.ai
7. Jasper
8. Runway ML
9. Hugging Face
10. LangChain
11. Fireflies.ai

### 备用工具池（30+工具）
系统维护超过30个AI工具的备用池，包括：
- 编程助手
- 聊天机器人
- 图像生成
- 写作工具
- 视频工具
- 开发平台
- 智能体框架

## 🔧 常用操作

### 重置推荐记录
```bash
# 备份现有记录
cp /root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json \
   /root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json.backup

# 重置为空（允许重新推荐所有工具）
echo '{"last_updated": "'$(date +%Y-%m-%d)'", "recommended_tools": []}' > \
   /root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json
```

### 添加新工具
编辑 `/root/.openclaw/workspace/skills/auto-blog/scripts/get-ai-tools.sh`，在 `KNOWN_AI_TOOLS` 或 `backup_tools` 数组中添加新工具名称。

### 调整推荐数量
编辑 `get-ai-tools.sh`：
```bash
local max_tools=3  # 改为你想要的数量
```

## 📝 示例输出

### 博客中的工具推荐部分
```html
<h3>🛠️ AI工具推荐（基于搜索结果）</h3>
<p>Perplexity AI、Notion AI、Otter.ai</p>
```

### 当所有工具都推荐过后
```html
<h3>🛠️ AI工具推荐（基于搜索结果）</h3>
<p>更多AI工具正在收集中，敬请期待...</p>
```

## 🎉 效果验证

最新的博客生成测试（ID: 98）已成功：
- ✅ 工具推荐功能正常工作
- ✅ 去重机制生效
- ✅ 正确显示"更多AI工具正在收集中..."（因为所有工具都已推荐过）

访问地址：http://42.193.14.72:8081/?p=98

## 💡 建议

1. **定期重置**：每季度重置一次推荐记录，允许重新推荐热门工具
2. **扩展工具池**：随着AI发展，定期添加新出现的工具
3. **分类标签**：未来可以添加工具分类，提供更精准的推荐

## 📚 相关文档

详细文档请查看：`AI_TOOLS_README.md`
