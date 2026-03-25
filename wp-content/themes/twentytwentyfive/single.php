<?php
/*
 * Single Post Template - AJAX评论提交 + 嵌套回复
 */

get_header();
?>

<style>
    .single-post-container {
        max-width: 800px;
        margin: 0 auto;
        padding: 40px 20px;
    }

    .article-title {
        font-size: 36px;
        font-weight: 700;
        color: #2c3e50;
        margin-bottom: 20px;
        line-height: 1.3;
    }

    .article-meta {
        color: #7f8c8d;
        font-size: 15px;
        margin-bottom: 30px;
    }

    .article-content {
        font-size: 18px;
        line-height: 1.8;
        color: #333;
    }

    .article-content h2 {
        font-size: 28px;
        margin-top: 40px;
        margin-bottom: 20px;
        color: #2c3e50;
        font-weight: 600;
    }

    /* 微信分享 */
    .wechat-share {
        margin: 40px 0;
        text-align: center;
    }

    .wechat-btn {
        display: inline-block;
        padding: 12px 30px;
        background: #07c160;
        color: white;
        text-decoration: none;
        border-radius: 25px;
        font-size: 16px;
        font-weight: 600;
        cursor: pointer;
        border: none;
        transition: all 0.3s ease;
    }

    .wechat-btn:hover {
        background: #06ae56;
        transform: translateY(-2px);
    }

    /* 二维码弹窗 */
    .qrcode-modal {
        display: none;
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0,0,0,0.8);
        z-index: 9999;
        align-items: center;
        justify-content: center;
    }

    .qrcode-modal.active {
        display: flex;
    }

    .qrcode-box {
        background: white;
        padding: 30px;
        border-radius: 15px;
        text-align: center;
        max-width: 350px;
    }

    .qrcode-box img {
        width: 250px;
        height: 250px;
        margin: 15px 0;
        border: 1px solid #e0e0e0;
    }

    .close-btn {
        padding: 10px 30px;
        background: #666;
        color: white;
        border: none;
        border-radius: 20px;
        cursor: pointer;
        font-size: 14px;
    }

    /* 评论区 */
    .comments-section {
        margin-top: 60px;
        padding-top: 40px;
        border-top: 2px solid #e0e0e0;
    }

    .comments-title {
        font-size: 28px;
        margin-bottom: 30px;
        color: #2c3e50;
    }

    /* 评论对话列表 */
    .comment-thread {
        list-style: none;
        padding: 0;
        margin: 0 0 40px 0;
    }

    .comment-thread-item {
        margin-bottom: 30px;
        padding: 0;
    }

    .main-comment {
        background: #f8f9fa;
        border-radius: 12px;
        padding: 20px;
        margin-bottom: 15px;
    }

    .comment-author {
        font-weight: 600;
        color: #2c3e50;
        margin-bottom: 8px;
        display: flex;
        align-items: center;
        gap: 10px;
    }

    .comment-author .badge {
        background: #0073aa;
        color: white;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 12px;
    }

    .comment-date {
        color: #7f8c8d;
        font-size: 14px;
    }

    .comment-text {
        color: #555;
        line-height: 1.6;
        margin-top: 10px;
    }

    .reply-btn {
        display: inline-block;
        margin-top: 10px;
        padding: 5px 12px;
        background: #0073aa;
        color: white;
        border: none;
        border-radius: 15px;
        font-size: 13px;
        cursor: pointer;
        transition: all 0.2s;
    }

    .reply-btn:hover {
        background: #005177;
        transform: translateY(-1px);
    }

    /* 回复列表 */
    .replies-list {
        list-style: none;
        padding: 0;
        margin: 0;
    }

    .reply-item {
        background: white;
        border-radius: 10px;
        padding: 15px;
        margin-top: 10px;
        margin-left: 30px;
        border-left: 3px solid #07c160;
        position: relative;
    }

    .reply-item::before {
        content: '';
        position: absolute;
        left: -30px;
        top: 15px;
        width: 0;
        height: 0;
        border-left: 2px solid #e0e0e0;
        border-top: 2px solid #e0e0e0;
        transform: rotate(-45deg);
    }

    .reply-author {
        font-weight: 600;
        color: #07c160;
        margin-bottom: 5px;
    }

    .reply-date {
        color: #999;
        font-size: 13px;
    }

    .reply-text {
        color: #666;
        line-height: 1.5;
        font-size: 15px;
    }

    /* 评论表单 */
    .comment-form-wrapper {
        background: #f8f9fa;
        border-radius: 12px;
        padding: 25px;
        margin-top: 30px;
    }

    .replying-to {
        background: #e3f2fd;
        padding: 10px 15px;
        border-radius: 8px;
        margin-bottom: 15px;
        display: none;
        align-items: center;
        gap: 10px;
    }

    .replying-to.active {
        display: flex;
    }

    .cancel-reply {
        padding: 5px 12px;
        background: #666;
        color: white;
        border: none;
        border-radius: 12px;
        font-size: 12px;
        cursor: pointer;
    }

    .form-group {
        margin-bottom: 15px;
    }

    .form-control {
        width: 100%;
        padding: 10px 15px;
        border: 1px solid #ddd;
        border-radius: 8px;
        font-size: 15px;
    }

    .submit-btn {
        padding: 12px 30px;
        background: #0073aa;
        color: white;
        border: none;
        border-radius: 25px;
        font-size: 16px;
        font-weight: 500;
        cursor: pointer;
    }

    .submit-btn:disabled {
        background: #ccc;
        cursor: not-allowed;
    }

    .comment-message {
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 15px;
        display: none;
    }

    .comment-message.success {
        background: #d4edda;
        color: #155724;
        display: block;
    }

    .comment-message.error {
        background: #f8d7da;
        color: #721c24;
        display: block;
    }

    .back-to-home {
        display: inline-block;
        padding: 12px 24px;
        background: #0073aa;
        color: white;
        text-decoration: none;
        border-radius: 25px;
        margin-top: 40px;
    }

    .back-to-home:hover {
        background: #005177;
    }
</style>

<div class="single-post-container">
    <?php
    if (have_posts()) :
        while (have_posts()) : the_post();
            ?>
            <article>
                <h1 class="article-title">
                    <?php the_title(); ?>
                </h1>

                <div class="article-meta">
                    📅 <?php echo get_the_date('Y年m月d日'); ?>
                    💬 <?php comments_number('暂无评论', '1 条评论', '% 条评论'); ?>
                </div>

                <div class="article-content">
                    <?php the_content(); ?>
                </div>

                <!-- 微信分享 -->
                <div class="wechat-share">
                    <button class="wechat-btn" onclick="showQRCode()">
                        📱 分享到微信
                    </button>
                </div>

                <nav style="margin-top: 40px; padding: 20px 0; border-top: 1px solid #e0e0e0;">
                    <div style="display: flex; justify-content: space-between;">
                        <div><?php previous_post_link('%link', '← %title'); ?></div>
                        <div><?php next_post_link('%link', '%title →'); ?></div>
                    </div>
                </nav>
            </article>

            <!-- 评论区 -->
            <?php if (comments_open() || get_comments_number()) : ?>
            <div class="comments-section" id="comments">
                <h2 class="comments-title">💬 评论</h2>

                <?php
                // 按对话组织评论
                $all_comments = get_comments(array(
                    'post_id' => get_the_ID(),
                    'status' => 'approve',
                    'order' => 'ASC',
                ));

                // 按主评论分组
                $comments_by_parent = array();
                foreach ($all_comments as $comment) {
                    if ($comment->comment_parent == 0) {
                        $comments_by_parent[$comment->comment_ID] = array(
                            'main' => $comment,
                            'replies' => array()
                        );
                    } else {
                        if (isset($comments_by_parent[$comment->comment_parent])) {
                            $comments_by_parent[$comment->comment_parent]['replies'][] = $comment;
                        }
                    }
                }

                if (!empty($comments_by_parent)) :
                    echo '<ul class="comment-thread" id="comment-list">';
                    foreach ($comments_by_parent as $thread_id => $thread) :
                        ?>
                        <li class="comment-thread-item">
                            <!-- 主评论 -->
                            <div class="main-comment">
                                <div class="comment-author">
                                    <?php echo esc_html($thread['main']->comment_author); ?>
                                    <?php if ($thread['main']->comment_author === get_option('blogname')) : ?>
                                    <span class="badge">作者</span>
                                    <?php endif; ?>
                                </div>
                                <div class="comment-date">
                                    <?php echo get_comment_date('Y-m-d H:i', $thread['main']->comment_ID); ?>
                                </div>
                                <div class="comment-text">
                                    <?php echo wp_kses_post($thread['main']->comment_content); ?>
                                </div>
                                <button class="reply-btn" onclick="replyToComment(<?php echo $thread['main']->comment_ID; ?>, '<?php echo esc_js($thread['main']->comment_author); ?>')">
                                    💬 回复
                                </button>
                            </div>

                            <!-- 回复列表 -->
                            <?php if (!empty($thread['replies'])) : ?>
                                <ul class="replies-list">
                                    <?php foreach ($thread['replies'] as $reply) : ?>
                                        <li class="reply-item">
                                            <div class="reply-author">
                                                <?php echo esc_html($reply->comment_author); ?>
                                            </div>
                                            <div class="reply-date">
                                                <?php echo get_comment_date('Y-m-d H:i', $reply->comment_ID); ?>
                                            </div>
                                            <div class="reply-text">
                                                <?php echo wp_kses_post($reply->comment_content); ?>
                                            </div>
                                            <button class="reply-btn" onclick="replyToComment(<?php echo $thread['main']->comment_ID; ?>, '<?php echo esc_js($reply->comment_author); ?>')">
                                                💬 回复
                                            </button>
                                        </li>
                                    <?php endforeach; ?>
                                </ul>
                            <?php endif; ?>
                        </li>
                    <?php endforeach;
                    echo '</ul>';
                endif;
                ?>

                <!-- 评论表单 -->
                <div class="comment-form-wrapper" id="respond">
                    <h3>发表评论</h3>
                    
                    <div id="replying-to" class="replying-to">
                        <span>正在回复 <strong id="replying-author"></strong></span>
                        <button class="cancel-reply" onclick="cancelReply()">取消</button>
                    </div>
                    
                    <div id="comment-message" class="comment-message"></div>
                    
                    <form id="ajax-comment-form">
                        <div class="form-group">
                            <label for="author">昵称：</label>
                            <input type="text" id="author" name="author" class="form-control" required>
                        </div>

                        <div class="form-group">
                            <label for="email">邮箱：</label>
                            <input type="email" id="email" name="email" class="form-control" required>
                        </div>

                        <div class="form-group">
                            <label for="comment">评论内容：</label>
                            <textarea id="comment" name="comment" class="form-control" rows="5" required></textarea>
                        </div>

                        <input type="hidden" name="comment_post_ID" value="<?php the_ID(); ?>">
                        <input type="hidden" name="comment_parent" id="comment_parent" value="0">
                        <button type="submit" class="submit-btn" id="submit-comment">发表评论</button>
                    </form>
                </div>
            </div>
            <?php endif; ?>

            <div style="text-align: center;">
                <a href="<?php echo home_url(); ?>" class="back-to-home">← 返回首页</a>
            </div>

        <?php
        endwhile;
    else :
        ?>
        <p>未找到文章。</p>
    <?php
    endif;
    ?>
</div>

<!-- 微信分享二维码弹窗 -->
<div id="qrcodeModal" class="qrcode-modal">
    <div class="qrcode-box">
        <h3 style="margin-top:0;">📱 微信扫一扫</h3>
        <img src="https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=<?php echo urlencode(get_permalink()); ?>" alt="分享二维码" class="qrcode-img">
        <p style="color: #666; font-size: 14px; margin: 15px 0;">使用微信扫描二维码分享</p>
        <button class="close-btn" onclick="closeQRCode()">关闭</button>
    </div>
</div>

<script>
    var ajaxurl = <?php echo json_encode(admin_url('admin-ajax.php')); ?>;
</script>

<script>
// 微信分享弹窗
function showQRCode() {
    document.getElementById('qrcodeModal').classList.add('active');
}

function closeQRCode() {
    document.getElementById('qrcodeModal').classList.remove('active');
}

document.getElementById('qrcodeModal').addEventListener('click', function(e) {
    if (e.target === this) {
        closeQRCode();
    }
});

// 回复评论功能
function replyToComment(commentId, authorName) {
    document.getElementById('comment_parent').value = commentId;
    document.getElementById('replying-author').textContent = authorName;
    document.getElementById('replying-to').classList.add('active');
    document.getElementById('respond').scrollIntoView({ behavior: 'smooth' });
    document.getElementById('comment').focus();
}

function cancelReply() {
    document.getElementById('comment_parent').value = '0';
    document.getElementById('replying-to').classList.remove('active');
}

// AJAX评论提交
document.getElementById('ajax-comment-form').addEventListener('submit', function(e) {
    e.preventDefault();
    
    var form = this;
    var submitBtn = document.getElementById('submit-comment');
    var messageBox = document.getElementById('comment-message');
    
    submitBtn.disabled = true;
    submitBtn.textContent = '提交中...';
    
    var formData = new FormData(form);
    formData.append('action', 'ajax_comment_submit');
    
    fetch(ajaxurl, {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            messageBox.textContent = '✅ 评论发表成功！页面将自动刷新...';
            messageBox.className = 'comment-message success';
            
            setTimeout(function() {
                location.reload();
            }, 1500);
        } else {
            messageBox.textContent = '❌ ' + (data.data || '提交失败');
            messageBox.className = 'comment-message error';
            submitBtn.disabled = false;
            submitBtn.textContent = '发表评论';
        }
    })
    .catch(error => {
        messageBox.textContent = '❌ 网络错误，请重试';
        messageBox.className = 'comment-message error';
        submitBtn.disabled = false;
        submitBtn.textContent = '发表评论';
    });
});
</script>

<!-- 微信分享元信息 -->
<meta property="og:type" content="article">
<meta property="og:title" content="<?php the_title(); ?>">
<meta property="og:description" content="<?php echo wp_trim_words(get_the_excerpt(), 100); ?>">
<meta property="og:url" content="<?php the_permalink(); ?>">
<meta property="og:site_name" content="<?php bloginfo('name'); ?>">

<?php
get_footer();
?>
