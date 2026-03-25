<?php
/*
Plugin Name: 首页仅显示摘要
Description: 在首页只显示文章标题和摘要，不显示完整内容
Version: 2.0
Author: AI Assistant
*/

// 在首页使用摘要而不是完整内容
add_filter('the_content', 'excerpt_on_home_page', 999);

function excerpt_on_home_page($content) {
    // 只在主页应用
    if ((is_home() || is_front_page()) && in_the_loop() && is_main_query()) {
        // 移除所有块内容
        $content = '';

        // 获取摘要
        $excerpt = get_the_excerpt();

        // 限制摘要长度为150个字符
        if (strlen($excerpt) > 150) {
            $excerpt = substr($excerpt, 0, 150) . '...';
        }

        // 添加"阅读更多"链接
        $read_more_link = get_permalink();
        $read_more = '<div style="margin-top:15px;"><a href="' . $read_more_link . '" style="display:inline-block;padding:8px 16px;background-color:#0073aa;color:white;text-decoration:none;border-radius:4px;">阅读更多 →</a></div>';

        // 返回格式化的摘要
        return '<div class="entry-summary"><p>' . esc_html($excerpt) . '</p>' . $read_more . '</div>';
    }

    return $content;
}

// 设置摘要长度
add_filter('excerpt_length', 'custom_excerpt_length', 999);

function custom_excerpt_length($length) {
    return 150;
}

// 修改摘要末尾
add_filter('excerpt_more', 'custom_excerpt_more');

function custom_excerpt_more($more) {
    return '';
}

// 隐藏块编辑器在首页的完整内容
add_action('wp_head', 'hide_full_content_on_home');

function hide_full_content_on_home() {
    if (is_home() || is_front_page()) {
        ?>
        <style>
            /* 隐藏块内容 */
            .wp-site-blocks .entry-content > *:not(.entry-summary) {
                display: none !important;
            }
            /* 确保摘要显示 */
            .entry-summary {
                display: block !important;
            }
        </style>
        <?php
    }
}
?>
