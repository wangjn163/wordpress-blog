<?php
/*
Plugin Name: Visitor Tracker
Description: 统计每日独立访客数量（基于IP去重）
Version: 1.0
*/

// 创建统计数据表
function vt_create_table() {
    global $wpdb;
    $table_name = $wpdb->prefix . 'visitor_stats';
    $charset_collate = $wpdb->get_charset_collate();

    $sql = "CREATE TABLE IF NOT EXISTS $table_name (
        id INT AUTO_INCREMENT PRIMARY KEY,
        visit_date DATE NOT NULL,
        ip_address VARCHAR(45) NOT NULL,
        user_agent VARCHAR(255),
        visit_time DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_visit (visit_date, ip_address)
    ) $charset_collate;";

    require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
    dbDelta($sql);
}
register_activation_hook(__FILE__, 'vt_create_table');

// 记录访客
function vt_track_visitor() {
    if (is_admin()) return; // 不统计后台访问

    global $wpdb;
    $table_name = $wpdb->prefix . 'visitor_stats';

    $ip = vt_get_visitor_ip();
    $user_agent = $_SERVER['HTTP_USER_AGENT'] ?? '';
    $today = current_time('Y-m-d');

    // 使用 INSERT IGNORE 避免重复记录
    $wpdb->query($wpdb->prepare(
        "INSERT IGNORE INTO $table_name (visit_date, ip_address, user_agent) VALUES (%s, %s, %s)",
        $today, $ip, $user_agent
    ));
}
add_action('wp_head', 'vt_track_visitor');

// 获取访客IP
function vt_get_visitor_ip() {
    $ip = '';

    if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        $ip = $_SERVER['HTTP_CLIENT_IP'];
    } elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
    } else {
        $ip = $_SERVER['REMOTE_ADDR'];
    }

    // 处理多个IP的情况（代理）
    $ips = explode(',', $ip);
    $ip = trim($ips[0]);

    return sanitize_text_field($ip);
}

// 获取今日访客数
function vt_get_today_visitors() {
    global $wpdb;
    $table_name = $wpdb->prefix . 'visitor_stats';
    $today = current_time('Y-m-d');

    $count = $wpdb->get_var($wpdb->prepare(
        "SELECT COUNT(DISTINCT ip_address) FROM $table_name WHERE visit_date = %s",
        $today
    ));

    return $count ? $count : 0;
}

// 在页面底部显示统计信息
function vt_display_stats() {
    if (is_admin()) return;

    $today_count = vt_get_today_visitors();
    $today_date = current_time('Y年m月d日');

    echo '<div style="background: #f5f5f5; padding: 15px; margin: 20px 0; border-radius: 5px; text-align: center; font-size: 14px; color: #666;">';
    echo '<strong>📊 访问统计</strong><br>';
    echo $today_date . ' 独立访客：<strong style="color: #0073aa; font-size: 18px;">' . $today_count . '</strong> 人';
    echo '</div>';
}
add_action('wp_footer', 'vt_display_stats');

// 添加管理员菜单
function vt_add_admin_menu() {
    add_options_page(
        '访客统计',
        '访客统计',
        'manage_options',
        'visitor-tracker',
        'vt_admin_page'
    );
}
add_action('admin_menu', 'vt_add_admin_menu');

// 管理员页面
function vt_admin_page() {
    global $wpdb;
    $table_name = $wpdb->prefix . 'visitor_stats';

    // 获取最近7天的数据
    $results = $wpdb->get_results(
        "SELECT visit_date, COUNT(DISTINCT ip_address) as visitors
        FROM $table_name
        WHERE visit_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        GROUP BY visit_date
        ORDER BY visit_date DESC"
    );

    // 获取总访客数
    $total_visitors = $wpdb->get_var("SELECT COUNT(DISTINCT ip_address) FROM $table_name");

    // 获取今日访客数
    $today = current_time('Y-m-d');
    $today_visitors = $wpdb->get_var($wpdb->prepare(
        "SELECT COUNT(DISTINCT ip_address) FROM $table_name WHERE visit_date = %s",
        $today
    ));

    ?>
    <div class="wrap">
        <h1>📊 访客统计</h1>

        <div style="display: flex; gap: 20px; margin: 20px 0;">
            <div style="background: #fff; padding: 20px; border: 1px solid #ddd; border-radius: 5px; flex: 1;">
                <h2 style="margin-top: 0;">今日访客</h2>
                <p style="font-size: 48px; color: #0073aa; margin: 0;"><?php echo $today_visitors; ?></p>
                <p>独立访客</p>
            </div>

            <div style="background: #fff; padding: 20px; border: 1px solid #ddd; border-radius: 5px; flex: 1;">
                <h2 style="margin-top: 0;">总访客数</h2>
                <p style="font-size: 48px; color: #0073aa; margin: 0;"><?php echo $total_visitors; ?></p>
                <p>独立访客（累计）</p>
            </div>
        </div>

        <h2>最近7天统计</h2>
        <table class="wp-list-table widefat fixed striped">
            <thead>
                <tr>
                    <th>日期</th>
                    <th>独立访客数</th>
                </tr>
            </thead>
            <tbody>
                <?php if ($results) : ?>
                    <?php foreach ($results as $row) : ?>
                        <tr>
                            <td><?php echo $row->visit_date; ?></td>
                            <td><strong><?php echo $row->visitors; ?></strong> 人</td>
                        </tr>
                    <?php endforeach; ?>
                <?php else : ?>
                    <tr>
                        <td colspan="2">暂无数据</td>
                    </tr>
                <?php endif; ?>
            </tbody>
        </table>

        <h2 style="margin-top: 30px;">快捷操作</h2>
        <p>
            <button type="button" class="button" onclick="vtRefreshStats()">刷新统计</button>
            <button type="button" class="button" onclick="vtExportData()">导出数据</button>
        </p>

        <script>
        function vtRefreshStats() {
            location.reload();
        }
        function vtExportData() {
            alert('导出功能开发中...');
        }
        </script>
    </div>
    <?php
}
