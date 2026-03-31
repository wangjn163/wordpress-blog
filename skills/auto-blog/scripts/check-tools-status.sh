#!/bin/bash
#
# AI工具推荐状态检查脚本
#

TOOLS_DB="/root/.openclaw/workspace/skills/auto-blog/scripts/recommended_tools.json"

echo "=========================================="
echo "AI工具推荐状态检查"
echo "=========================================="
echo ""

# 检查数据库文件
if [ ! -f "$TOOLS_DB" ]; then
    echo "❌ 工具数据库不存在"
    exit 1
fi

# 显示最后更新时间
last_updated=$(jq -r '.last_updated' "$TOOLS_DB")
echo "📅 最后更新: $last_updated"
echo ""

# 统计已推荐工具数量
count=$(jq '.recommended_tools | length' "$TOOLS_DB")
echo "📊 已推荐工具数量: $count"
echo ""

# 显示已推荐工具列表
echo "✅ 已推荐工具列表:"
jq -r '.recommended_tools[]' "$TOOLS_DB" | nl -w2 -s'. '
echo ""

# 检查是否需要重置
if [ $count -ge 30 ]; then
    echo "⚠️  已推荐工具数量较多，建议考虑重置"
    echo "   重置命令: echo '{\"last_updated\": \"'$(date +%Y-%m-%d)'\", \"recommended_tools\": []}' > $TOOLS_DB"
else
    remaining=$((30 - count))
    echo "💡 备用工具池剩余: $remaining 个"
fi

echo ""
echo "=========================================="
echo "检查完成"
echo "=========================================="
