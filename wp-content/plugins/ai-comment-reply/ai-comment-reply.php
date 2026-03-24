<?php
/*
Plugin Name: AI评论自动回复 - 修复版
Description: 使用WordPress定时任务自动回复评论
Version: 3.1
Author: AI Assistant
*/

// 注册自定义时间间隔
add_filter('cron_schedules', 'ai_add_cron_intervals');
function ai_add_cron_intervals($schedules) {
    $schedules['every_five_minutes'] = array(
        'interval' => 300,
        'display' => '每5分钟一次'
    );
    return $schedules;
}

// 定时检查未回复的评论
add_action('ai_comment_reply_cron', 'ai_check_unreplied_comments');

function ai_check_unreplied_comments() {
    error_log('AI评论回复定时任务执行: ' . date('Y-m-d H:i:s'));
    
    // 获取最近10分钟的评论
    $recent_comments = get_comments(array(
        'status' => 'approve',
        'date_query' => array(
            array('after' => '10 minutes ago'),
        ),
    ));

    $replied_count = 0;
    
    foreach ($recent_comments as $comment) {
        // 跳过AI自己的评论
        if ($comment->comment_author === get_option('blogname')) {
            continue;
        }

        // 检查是否有回复
        $has_reply = get_comments(array(
            'parent' => $comment->comment_ID,
            'count' => true,
            'status' => 'approve',
        ));

        if ($has_reply == 0) {
            // 添加回复
            $reply_content = _ai_generate_reply($comment->comment_content, $comment->comment_author);
            
            $reply_data = array(
                'comment_post_ID' => $comment->comment_post_ID,
                'comment_author' => get_option('blogname'),
                'comment_author_email' => get_option('admin_email'),
                'comment_content' => $reply_content,
                'comment_parent' => $comment->comment_ID,
                'comment_approved' => 1,
                'comment_date' => current_time('mysql'),
                'user_id' => 0,
            );

            $reply_id = wp_insert_comment($reply_data);
            if ($reply_id) {
                $replied_count++;
                error_log("AI回复已添加: 评论{$comment->comment_ID} -> 回复{$reply_id}");
            }
        }
    }
    
    if ($replied_count > 0) {
        error_log("本次执行回复了 {$replied_count} 条评论");
    }
}

// 生成回复内容
function _ai_generate_reply($comment_content, $comment_author) {
    $comment_lower = mb_strtolower($comment_content);

    // 赞美类
    if (strpos($comment_lower, '好') !== false || strpos($comment_lower, '棒') !== false || 
        strpos($comment_lower, '赞') !== false || strpos($comment_lower, '不错') !== false) {
        $replies = array(
            "嘿嘿，过奖啦",
            "哈哈，谢谢鼓励",
            "嗯嗯，继续努力",
            "喜欢就好～",
        );
        return $replies[array_rand($replies)];
    }

    // 提问类
    if (strpos($comment_content, '?') !== false || strpos($comment_lower, '怎么') !== false) {
        $replies = array(
            "这个问题问得好",
            "嗯，有想法！",
            "好问题",
        );
        return $replies[array_rand($replies)];
    }

    // 短评论
    if (mb_strlen($comment_content) < 5) {
        $replies = array("👍", "哈哈", "嗯嗯", "OK");
        return $replies[array_rand($replies)];
    }

    // 默认
    $replies = array("有道理", "嗯嗯", "好滴", "哈哈", "🤝", "来了");
    return $replies[array_rand($replies)];
}

// 激活定时任务
register_activation_hook(__FILE__, 'ai_activate_cron');
function ai_activate_cron() {
    if (!wp_next_scheduled('ai_comment_reply_cron')) {
        wp_schedule_event(time(), 'every_five_minutes', 'ai_comment_reply_cron');
        error_log('AI评论回复定时任务已激活');
    }
}

// 停用定时任务
register_deactivation_hook(__FILE__, 'ai_deactivate_cron');
function ai_deactivate_cron() {
    wp_clear_scheduled_hook('ai_comment_reply_cron');
    error_log('AI评论回复定时任务已停用');
}

// 立即激活定时任务
ai_activate_cron();

// 同时使用实时钩子（立即回复）
add_action('wp_insert_comment', 'ai_instant_reply', 99, 2);
function ai_instant_reply($comment_id, $comment_object) {
    // 只处理新批准的评论
    if ($comment_object->comment_approved !== 1) {
        return;
    }
    
    // 跳过AI自己的评论
    if ($comment_object->comment_author === get_option('blogname')) {
        return;
    }
    
    // 延迟1秒后添加回复（避免竞态条件）
    wp_schedule_single_event(time() + 5, 'ai_delayed_reply', array($comment_id));
}

add_action('ai_delayed_reply', 'ai_do_delayed_reply');
function ai_do_delayed_reply($comment_id) {
    $comment = get_comment($comment_id);
    if (!$comment) {
        return;
    }
    
    // 检查是否已有回复
    $has_reply = get_comments(array(
        'parent' => $comment_id,
        'count' => true,
    ));
    
    if ($has_reply > 0) {
        return;
    }
    
    $reply_content = _ai_generate_reply($comment->comment_content, $comment->comment_author);
    
    $reply_data = array(
        'comment_post_ID' => $comment->comment_post_ID,
        'comment_author' => get_option('blogname'),
        'comment_author_email' => get_option('admin_email'),
        'comment_content' => $reply_content,
        'comment_parent' => $comment_id,
        'comment_approved' => 1,
        'user_id' => 0,
    );

    $reply_id = wp_insert_comment($reply_data);
    error_log("AI即时回复: 评论{$comment_id} -> 回复{$reply_id}");
}
?>
