<?php
/**
 * Search Template - 搜索结果页面
 */

get_header();
?>

<style>
    /* 搜索框样式 */
    .search-container {
        max-width: 900px;
        margin: 20px auto 30px;
        padding: 0 20px;
    }

    .search-form-wrapper {
        background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
        padding: 25px 30px;
        border-radius: 15px;
        box-shadow: 0 4px 15px rgba(0,0,0,0.08);
        border: 2px solid #dee2e6;
    }

    .search-form-wrapper h3 {
        margin: 0 0 15px 0;
        font-size: 18px;
        color: #2c3e50;
        font-weight: 600;
    }

    .search-form {
        display: flex;
        gap: 12px;
        align-items: center;
    }

    .search-input-wrapper {
        flex: 1;
        position: relative;
    }

    .search-input {
        width: 100%;
        padding: 14px 20px 14px 45px;
        border: 2px solid #cbd5e0;
        border-radius: 25px;
        font-size: 16px;
        transition: all 0.3s ease;
        background: white;
        color: #2c3e50;
    }

    .search-input:focus {
        outline: none;
        border-color: #0073aa;
        box-shadow: 0 0 0 3px rgba(0,115,170,0.1);
    }

    .search-icon {
        position: absolute;
        left: 18px;
        top: 50%;
        transform: translateY(-50%);
        color: #7f8c8d;
        font-size: 18px;
    }

    .search-button {
        padding: 14px 32px;
        background: linear-gradient(135deg, #0073aa 0%, #005177 100%);
        color: white;
        border: none;
        border-radius: 25px;
        font-size: 16px;
        font-weight: 600;
        cursor: pointer;
        transition: all 0.3s ease;
        box-shadow: 0 4px 12px rgba(0,115,170,0.3);
        white-space: nowrap;
    }

    .search-button:hover {
        background: linear-gradient(135deg, #005177 0%, #0073aa 100%);
        transform: translateY(-2px);
        box-shadow: 0 6px 16px rgba(0,115,170,0.4);
    }

    @media (max-width: 768px) {
        .search-form {
            flex-direction: column;
        }

        .search-button {
            width: 100%;
        }

        .search-container {
            padding: 0 15px;
        }
    }

    /* 整体容器 */
    .site-content {
        max-width: 900px;
        margin: 0 auto;
        padding: 30px 20px;
    }

    /* 搜索结果标题 */
    .search-results-title {
        font-size: 28px;
        font-weight: 600;
        color: #2c3e50;
        margin-bottom: 10px;
        text-align: center;
    }

    .search-query {
        color: #0073aa;
    }

    .search-results-info {
        text-align: center;
        color: #7f8c8d;
        margin-bottom: 30px;
        font-size: 16px;
    }

    /* 文章列表 */
    .article-list {
        margin-bottom: 40px;
    }

    .post-item {
        background: white;
        border: 1px solid #e0e0e0;
        border-radius: 12px;
        padding: 25px;
        margin-bottom: 25px;
        transition: all 0.3s ease;
        box-shadow: 0 2px 8px rgba(0,0,0,0.05);
    }

    .post-item:hover {
        transform: translateY(-3px);
        box-shadow: 0 8px 20px rgba(0,0,0,0.12);
        border-color: #0073aa;
    }

    /* 文章标题 */
    .post-title {
        font-size: 24px;
        font-weight: 600;
        margin-bottom: 12px;
        line-height: 1.4;
    }

    .post-title a {
        color: #2c3e50;
        text-decoration: none;
        transition: color 0.3s ease;
    }

    .post-title a:hover {
        color: #0073aa;
    }

    /* 文章元信息 */
    .post-meta {
        color: #7f8c8d;
        font-size: 14px;
        margin-bottom: 15px;
        display: flex;
        align-items: center;
        gap: 15px;
    }

    .post-meta-item {
        display: flex;
        align-items: center;
        gap: 5px;
    }

    /* 文章摘要 */
    .post-excerpt {
        color: #555;
        line-height: 1.8;
        font-size: 16px;
        margin-bottom: 18px;
    }

    /* 阅读更多按钮 */
    .read-more-btn {
        display: inline-flex;
        align-items: center;
        padding: 12px 28px;
        background: linear-gradient(135deg, #0073aa 0%, #005177 100%);
        color: white;
        text-decoration: none;
        border-radius: 25px;
        font-weight: 500;
        font-size: 15px;
        transition: all 0.3s ease;
        box-shadow: 0 4px 15px rgba(0,115,170,0.3);
    }

    .read-more-btn:hover {
        background: linear-gradient(135deg, #005177 0%, #0073aa 100%);
        transform: translateY(-2px);
        box-shadow: 0 6px 20px rgba(0,115,170,0.4);
    }

    /* 美化分页导航 */
    .pagination-wrapper {
        display: flex;
        justify-content: center;
        align-items: center;
        margin-top: 50px;
        padding: 20px 0;
    }

    .pagination {
        display: flex;
        gap: 8px;
        align-items: center;
    }

    .pagination a,
    .pagination span {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 45px;
        height: 45px;
        padding: 0 18px;
        border: 2px solid #e0e0e0;
        border-radius: 10px;
        text-decoration: none;
        color: #555;
        font-weight: 500;
        font-size: 15px;
        transition: all 0.3s ease;
        background: white;
    }

    .pagination a:hover {
        background: #0073aa;
        color: white;
        border-color: #0073aa;
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(0,115,170,0.3);
    }

    .pagination .current {
        background: linear-gradient(135deg, #0073aa 0%, #005177 100%);
        color: white;
        border-color: #0073aa;
        font-weight: 600;
        box-shadow: 0 4px 12px rgba(0,115,170,0.3);
    }

    .pagination .dots {
        background: transparent;
        border: none;
        color: #999;
    }

    /* 没有结果时的提示 */
    .no-results {
        text-align: center;
        padding: 60px 20px;
        color: #7f8c8d;
    }

    .no-results h2 {
        font-size: 24px;
        color: #2c3e50;
        margin-bottom: 10px;
    }

    .no-results p {
        font-size: 16px;
        line-height: 1.8;
    }

    /* 响应式设计 */
    @media (max-width: 768px) {
        .site-content {
            padding: 20px 15px;
        }

        .post-item {
            padding: 20px;
        }

        .post-title {
            font-size: 20px;
        }

        .search-results-title {
            font-size: 22px;
        }

        .pagination a,
        .pagination span {
            min-width: 40px;
            height: 40px;
            padding: 0 15px;
            font-size: 14px;
        }
    }
</style>

<!-- 搜索框 -->
<div class="search-container">
    <div class="search-form-wrapper">
        <h3>🔍 搜索文章</h3>
        <form role="search" method="get" class="search-form" action="<?php echo home_url('/'); ?>">
            <div class="search-input-wrapper">
                <span class="search-icon">🔍</span>
                <input type="search" 
                       class="search-input" 
                       placeholder="输入关键词搜索文章..." 
                       value="<?php echo get_search_query(); ?>" 
                       name="s" />
            </div>
            <button type="submit" class="search-button">搜索</button>
        </form>
    </div>
</div>

<div class="site-content">
    <?php
    global $wp_query;
    $search_query = get_search_query();
    $results_count = $wp_query->found_posts;
    ?>

    <?php if ($search_query) : ?>
        <h1 class="search-results-title">
            搜索结果：<span class="search-query">「<?php echo esc_html($search_query); ?>」</span>
        </h1>
        <p class="search-results-info">
            找到 <?php echo $results_count; ?> 篇相关文章
        </p>
    <?php endif; ?>

    <?php
    if (have_posts()) :
        echo '<div class="article-list">';

        while (have_posts()) : the_post();
            ?>
            <article class="post-item">
                <h2 class="post-title">
                    <a href="<?php the_permalink(); ?>">
                        <?php the_title(); ?>
                    </a>
                </h2>

                <div class="post-meta">
                    <span class="post-meta-item">
                        📅 <?php echo get_the_date('Y年m月d日'); ?>
                    </span>
                    <?php if (get_comments_number() > 0) : ?>
                    <span class="post-meta-item">
                        💬 <?php comments_number('0 评论', '1 评论', '% 评论'); ?>
                    </span>
                    <?php endif; ?>
                </div>

                <div class="post-excerpt">
                    <?php echo wp_trim_words(get_the_excerpt(), 60, '...'); ?>
                </div>

                <a href="<?php the_permalink(); ?>" class="read-more-btn">
                    阅读更多 →
                </a>
            </article>
            <?php
        endwhile;

        echo '</div>';

        // 美化的分页导航
        $big = 999999999;
        $pagination = paginate_links(array(
            'base' => str_replace($big, '%#%', esc_url(get_pagenum_link($big))),
            'format' => '/page/%#%',
            'current' => max(1, get_query_var('paged')),
            'total' => $wp_query->max_num_pages,
            'prev_text' => '←',
            'next_text' => '→',
            'type' => 'plain',
            'before_page_number' => '',
            'after_page_number' => ''
        ));

        if ($pagination) :
            echo '<div class="pagination-wrapper">';
            echo '<div class="pagination">' . $pagination . '</div>';
            echo '</div>';
        endif;

    else :
        ?>
        <div class="no-results">
            <h2>🔍 没有找到相关文章</h2>
            <p>试试搜索其他关键词，或者<a href="<?php echo home_url('/'); ?>">返回首页</a>看看最新文章。</p>
        </div>
    <?php
    endif;
    ?>
</div>

<?php
get_footer();
?>
