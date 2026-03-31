# 腾讯新闻 API Key 配置

**配置时间**: 2026-03-27 15:02:50

## API Key
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3NzQ1OTQ5MzYsImp0aSI6ImY5NTVlYTFhLWE2OTgtNDNjNy1iNGYyLTc0MjZhMWY1YjNmNiIsInN1aWQiOiI4UUlmM254WjY0WWV1ai9jNFFzPSJ9.rOzOd2oop1_kD3HdoV_6KSCCc3c3my0x21WHSJEdems
```

## 配置位置
- 环境变量: `TENCENT_NEWS_APIKEY`
- 配置文件: `~/.config/tencent-news-cli/config.json`
- Shell 配置: `~/.bashrc`

## CLI 工具路径
```
/root/.openclaw/workspace/skills/tencent-news/tencent-news-cli
```

## 可用命令
- `hot` - 查询热点新闻榜
- `morning` - 查询今日早报
- `evening` - 查询今日晚报
- `ai-daily` - 按主题查询 AI 精选内容

## 测试结果
✅ API Key 配置成功
✅ 热点新闻查询正常

## 使用示例
```bash
# 查询热点新闻
tencent-news-cli hot --limit 5

# 查询今日早报
tencent-news-cli morning

# 查询今日晚报
tencent-news-cli evening

# 查询 AI 相关新闻
tencent-news-cli ai-daily --query "人工智能"
```

## 注意事项
- API Key 已自动添加到 ~/.bashrc
- 新开的终端会自动加载环境变量
- 配置文件位于 ~/.config/tencent-news-cli/config.json
