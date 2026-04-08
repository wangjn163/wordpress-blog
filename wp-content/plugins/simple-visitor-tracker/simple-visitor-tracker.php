<?php
/*
Plugin Name: Simple Visitor Tracker
Description: 简单的访客统计（去重）
Version: 1.1
*/

// 防止直接访问
if (!defined('ABSPATH')) {
    exit;
}

// 记录访问
add_action('init', 'svt_track_visitor');
function svt_track_visitor() {
    if (is_admin()) return;

    global $wpdb;
    $table_name = $wpdb->prefix . 'visitor_stats';

    $ip = svt_get_ip();
    $today = current_time('Y-m-d');

    // 插入记录（使用IGNORE避免重复）
    $wpdb->query($wpdb->prepare(
        "INSERT IGNORE INTO `$table_name` (`visit_date`, `ip_address`, `user_agent`) VALUES (%s, %s, %s)",
        $today, $ip, $_SERVER['HTTP_USER_AGENT'] ?? ''
    ));
}

// 获取IP
function svt_get_ip() {
    $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';

    if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        $ip = $_SERVER['HTTP_CLIENT_IP'];
    } elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ips = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        $ip = trim($ips[0]);
    }

    return sanitize_text_field($ip);
}

// 获取今日访客
function svt_get_today_count() {
    global $wpdb;
    $table_name = $wpdb->prefix . 'visitor_stats';
    $today = current_time('Y-m-d');

    $count = $wpdb->get_var($wpdb->prepare(
        "SELECT COUNT(DISTINCT ip_address) FROM `$table_name` WHERE `visit_date` = %s",
        $today
    ));

    return $count ? $count : 0;
}

// 在页面底部显示
add_action('wp_footer', 'svt_display_stats');
function svt_display_stats() {
    if (is_admin()) return;

    $count = svt_get_today_count();
    $date = current_time('Y年m月d日');

    echo '<div style="background:#f5f5f5;padding:15px;margin:20px 0;text-align:center;border-radius:5px;">';
    echo '<p style="margin:0;color:#666;font-size:14px;">';
    echo '📊 <strong>' . $date . '</strong> 独立访客：';
    echo '<span style="color:#0073aa;font-size:24px;font-weight:bold;">' . $count . '</span> 人';
    echo '</p></div>';
}

// 添加管理页面
add_action('admin_menu', 'svt_add_menu');
function svt_add_menu() {
    add_options_page('访客统计', '访客统计', 'manage_options', 'simple-visitor-tracker', 'svt_admin_page');
}

function svt_admin_page() {
    global $wpdb;
    $table_name = $wpdb->prefix . 'visitor_stats';

    // 今日统计
    $today = current_time('Y-m-d');
    $today_count = svt_get_today_count();

    // 总访客
    $total_count = $wpdb->get_var("SELECT COUNT(DISTINCT ip_address) FROM `$table_name`");

    // 最近7天
    $week_stats = $wpdb->get_results($wpdb->prepare(
        "SELECT `visit_date`, COUNT(DISTINCT ip_address) as visitors FROM `$table_name`
        WHERE `visit_date` >= DATE_SUB(%s, INTERVAL 7 DAY)
        GROUP BY `visit_date` ORDER BY `visit_date` DESC",
        $today
    ));

    ?>
    <div class="wrap">
        <h1>📊 访客统计</h1>

        <div style="display:flex;gap:20px;margin:20px 0;">
            <div style="flex:1;background:#fff;padding:20px;border:1px solid #ddd;border-radius:5px;">
                <h2 style="margin-top:0;">今日访客</h2>
                <p style="font-size:48px;color:#0073aa;margin:0;"><?php echo $today_count; ?></p>
                <p>独立访客</p>
            </div>

            <div style="flex:1;background:#fff;padding:20px;border:1px solid #ddd;border-radius:5px;">
                <h2 style="margin-top:0;">总访客数</h2>
                <p style="font-size:48px;color:#0073aa;margin:0;"><?php echo $total_count; ?></p>
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
                <?php if ($week_stats) : ?>
                    <?php foreach ($week_stats as $stat) : ?>
                        <tr>
                            <td><?php echo $stat->visit_date; ?></td>
                            <td><strong><?php echo $stat->visitors; ?></strong> 人</td>
                        </tr>
                    <?php endforeach; ?>
                <?php else : ?>
                    <tr><td colspan="2">暂无数据</td></tr>
                <?php endif; ?>
            </tbody>
        </table>

        <p style="margin-top:20px;">
            <em>说明：统计基于IP地址去重，同一IP在同一天只计为一次访问。</em>
        </p>
    </div>
    <?php
}
