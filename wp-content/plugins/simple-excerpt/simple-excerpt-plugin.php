<?php
/*
Plugin Name: 简单首页摘要
Description: 让首页只显示文章标题和摘要
Version: 1.0
*/

// 修改首页文章显示为摘要
add_action('template_redirect', 'force_excerpt_on_home');

function force_excerpt_on_home() {
    if (is_home() || is_front_page()) {
        // 添加过滤器
        add_filter('the_content', 'show_only_excerpt', 999);
    }
}

function show_only_excerpt($content) {
    // 移除所有内容
    $content = '';

    // 获取摘要
    $excerpt = get_the_excerpt();

    // 限制长度
    if (strlen($excerpt) > 150) {
        $excerpt = substr($excerpt, 0, 150) . '...';
    }

    // 返回摘要
    $content .= '<div class="entry-summary" style="color:#666;line-height:1.6;margin:15px 0;">';
    $content .= '<p>' . esc_html($excerpt) . '</p>';
    $content .= '<a href="' . get_permalink() . '" style="display:inline-block;padding:8px 16px;background-color:#0073aa;color:white;text-decoration:none;border-radius:4px;margin-top:10px;">阅读更多 →</a>';
    $content .= '</div>';

    return $content;
}
?>
