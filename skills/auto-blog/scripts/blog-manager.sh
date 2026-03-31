#!/bin/bash
#
# 博客管理脚本
# 功能：查看、清理、重置博客
#

LOG_FILE="/var/log/blog-auto-generate.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# 显示使用帮助
show_help() {
    cat << EOF
博客管理脚本 - 使用说明

用法:
  $0 [命令] [选项]

命令:
  status              查看博客生成状态
  list [days]         列出最近的博客（默认7天）
  clean <date>        删除指定日期的所有博客
  clean-old [days]    删除N天前的旧博客（默认7天）
  reset-today         清除今天的博客，允许重新生成
  force-generate      强制生成博客（忽略日期检查）
  stats               显示统计信息

示例:
  $0 status                    # 查看状态
  $0 list                      # 列出最近7天的博客
  $0 list 30                   # 列出最近30天的博客
  $0 clean 2026-03-28          # 删除2026-03-28的所有博客
  $0 clean-old 30              # 删除30天前的博客
  $0 reset-today               # 清除今天的博客
  $0 force-generate            # 强制生成博客
  $0 stats                     # 显示统计信息

EOF
}

# 查看状态
show_status() {
    echo "=========================================="
    echo "博客生成状态"
    echo "=========================================="
    echo ""

    # 今天的日期
    today=$(date '+%Y-%m-%d')
    echo "📅 今天: $today"
    echo ""

    # 检查今天的博客数量
    today_count=$(docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -se "SELECT COUNT(*) FROM wp_posts WHERE post_type='post' AND DATE(post_date)='$today';" 2>/dev/null)

    echo "📊 今天的博客数量: $today_count"

    if [ "$today_count" -gt 0 ]; then
        echo ""
        echo "✅ 今天已生成博客："
        docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
            -e "SELECT ID, post_title, DATE(post_date) as date FROM wp_posts WHERE post_type='post' AND DATE(post_date)='$today' ORDER BY post_date DESC;" 2>/dev/null | column -t
    else
        echo "⏳ 今天还没有生成博客"
    fi

    echo ""
    echo "=========================================="
}

# 列出博客
list_blogs() {
    local days=${1:-7}

    echo "=========================================="
    echo "最近 $days 天的博客"
    echo "=========================================="
    echo ""

    docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -e "SELECT DATE(post_date) as date, COUNT(*) as count FROM wp_posts WHERE post_type='post' AND DATE(post_date) >= DATE_SUB(CURDATE(), INTERVAL $days DAY) GROUP BY DATE(post_date) ORDER BY date DESC;" 2>/dev/null | column -t

    echo ""
    echo "详细列表："
    docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -e "SELECT ID, post_title, DATE(post_date) as date, post_status FROM wp_posts WHERE post_type='post' AND DATE(post_date) >= DATE_SUB(CURDATE(), INTERVAL $days DAY) ORDER BY post_date DESC;" 2>/dev/null | column -t

    echo ""
    echo "=========================================="
}

# 删除指定日期的博客
clean_date() {
    local target_date=$1

    if [ -z "$target_date" ]; then
        echo "❌ 请指定日期，格式: YYYY-MM-DD"
        exit 1
    fi

    # 验证日期格式
    if ! [[ "$target_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "❌ 日期格式错误，请使用: YYYY-MM-DD"
        exit 1
    fi

    echo "⚠️  准备删除 $target_date 的所有博客"
    echo ""

    # 显示将要删除的博客
    docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -e "SELECT ID, post_title FROM wp_posts WHERE post_type='post' AND DATE(post_date)='$target_date';" 2>/dev/null

    echo ""
    read -p "确认删除? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        count=$(docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
            -se "DELETE FROM wp_posts WHERE post_type='post' AND DATE(post_date)='$target_date'; SELECT ROW_COUNT();" 2>/dev/null)

        log "✓ 已删除 $target_date 的博客"
    else
        echo "取消删除"
    fi
}

# 删除N天前的旧博客
clean_old() {
    local days=${1:-7}

    echo "⚠️  准备删除 $days 天前的旧博客"
    echo ""

    # 显示将要删除的博客数量
    count=$(docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -se "SELECT COUNT(*) FROM wp_posts WHERE post_type='post' AND DATE(post_date) < DATE_SUB(CURDATE(), INTERVAL $days DAY);" 2>/dev/null)

    echo "将删除 $count 篇博客"
    echo ""
    read -p "确认删除? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
            -e "DELETE FROM wp_posts WHERE post_type='post' AND DATE(post_date) < DATE_SUB(CURDATE(), INTERVAL $days DAY);" 2>/dev/null

        log "✓ 已删除 $days 天前的旧博客"
    else
        echo "取消删除"
    fi
}

# 重置今天的博客
reset_today() {
    local today=$(date '+%Y-%m-%d')

    echo "⚠️  准备清除今天的博客，允许重新生成"
    echo ""

    # 显示今天的博客
    docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -e "SELECT ID, post_title FROM wp_posts WHERE post_type='post' AND DATE(post_date)='$today';" 2>/dev/null

    echo ""
    read -p "确认删除今天的所有博客? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
            -e "DELETE FROM wp_posts WHERE post_type='post' AND DATE(post_date)='$today';" 2>/dev/null

        log "✓ 已清除今天的博客，可以重新生成"
        echo ""
        echo "💡 现在可以运行: bash /root/.openclaw/workspace/skills/auto-blog/scripts/generate-blog.sh"
    else
        echo "取消删除"
    fi
}

# 强制生成博客
force_generate() {
    log "强制生成博客（忽略日期检查）..."

    # 临时创建一个强制生成的脚本
    cat > /tmp/force-generate.sh << 'FORCE_SCRIPT'
#!/bin/bash
# 强制生成博客（跳过日期检查）

LOG_FILE="/var/log/blog-auto-generate.log"
SCRIPT_DIR="/root/.openclaw/workspace/skills/auto-blog/scripts"

# 加载 nvm 环境
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"
fi
export PATH="$HOME/.nvm/versions/node/v22.22.1/bin:$PATH"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# 直接执行生成流程，跳过日期检查
log "=========================================="
log "强制生成博客模式"

# 加载主脚本但跳过main函数
source "$SCRIPT_DIR/generate-blog.sh"

# 手动执行生成步骤
check_dependencies
load_credentials
check_credentials
perform_search
generate_content
publish_blog
cleanup

log "=========================================="
log "✅ 强制生成完成"
FORCE_SCRIPT

    chmod +x /tmp/force-generate.sh
    bash /tmp/force-generate.sh
    rm -f /tmp/force-generate.sh
}

# 显示统计信息
show_stats() {
    echo "=========================================="
    echo "博客统计信息"
    echo "=========================================="
    echo ""

    # 总博客数
    total=$(docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -se "SELECT COUNT(*) FROM wp_posts WHERE post_type='post';" 2>/dev/null)
    echo "📊 总博客数: $total"
    echo ""

    # 按日期统计
    echo "📅 按日期统计（最近10天）："
    docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -e "SELECT DATE(post_date) as date, COUNT(*) as count FROM wp_posts WHERE post_type='post' AND DATE(post_date) >= DATE_SUB(CURDATE(), INTERVAL 10 DAY) GROUP BY DATE(post_date) ORDER BY date DESC;" 2>/dev/null | column -t

    echo ""

    # 最早和最新的博客
    echo "🔝 最早的博客:"
    docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -e "SELECT ID, post_title, post_date FROM wp_posts WHERE post_type='post' ORDER BY post_date ASC LIMIT 1;" 2>/dev/null

    echo ""
    echo "🔽 最新的博客:"
    docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress \
        -e "SELECT ID, post_title, post_date FROM wp_posts WHERE post_type='post' ORDER BY post_date DESC LIMIT 1;" 2>/dev/null

    echo ""
    echo "=========================================="
}

# 主函数
main() {
    case "${1:-}" in
        status)
            show_status
            ;;
        list)
            list_blogs "${2:-7}"
            ;;
        clean)
            clean_date "$2"
            ;;
        clean-old)
            clean_old "${2:-7}"
            ;;
        reset-today)
            reset_today
            ;;
        force-generate)
            force_generate
            ;;
        stats)
            show_stats
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            echo "❌ 未知命令: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
