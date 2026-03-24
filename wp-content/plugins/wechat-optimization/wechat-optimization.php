<?php
/*
Plugin Name: 微信访问优化
Description: 优化微信浏览器访问体验，减少二次确认
Version: 1.0
*/

// 移除WordPress的 canonical 重定向（避免微信二次访问）
remove_action('template_redirect', 'redirect_canonical');

// 禁用WordPress的归档重定向
add_filter('redirect_canonical', '__return_false');

// 添加微信友好的HTTP头
add_action('wp_head', 'add_wechat_friendly_headers');

function add_wechat_friendly_headers() {
    // 禁止缓存
    echo '<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">' . "\n";
    echo '<meta http-equiv="Pragma" content="no-cache">' . "\n";
    echo '<meta name="referrer" content="always">' . "\n";
    
    // 微信分享优化
    global $post;
    if (is_single()) {
        $post_url = get_permalink();
        $post_title = get_the_title();
        $post_excerpt = wp_trim_words(get_the_excerpt(), 100);
        
        echo '<meta property="og:type" content="article">' . "\n";
        echo '<meta property="og:title" content="' . esc_attr($post_title) . '">' . "\n";
        echo '<meta property="og:description" content="' . esc_attr($post_excerpt) . '">' . "\n";
        echo '<meta property="og:url" content="' . esc_url($post_url) . '">' . "\n";
        echo '<meta property="og:site_name" content="' . esc_html(get_bloginfo('name')) . '">' . "\n";
        
        // 尝试使用主题截图作为分享图片
        $theme_screenshot = get_stylesheet_directory_uri() . '/screenshot.png';
        echo '<meta property="og:image" content="' . esc_url($theme_screenshot) . '">' . "\n";
    }
}

// 移除不必要的头部信息
remove_action('wp_head', 'wp_shortlink_wp_head', 10);
remove_action('wp_head', 'wp_generator');
remove_action('wp_head', 'rsd_link');
remove_action('wp_head', 'wlwmanifest_link');
remove_action('wp_head', 'rest_output_link_wp_head');

// 简化头部，减少微信浏览器加载负担
add_action('init', 'simplify_theme_header');

function simplify_theme_header() {
    remove_action('wp_head', 'print_emoji_detection_script');
    remove_action('wp_print_styles', 'print_emoji_styles');
}
?>
