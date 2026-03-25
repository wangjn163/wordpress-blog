<?php
/**
 * Archive Template
 * 用于分类、标签、日期归档等页面
 */

get_header();
?>

<style>
    /* 自定义归档页面样式 */
    .custom-archive-wrapper {
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
    }

    .archive-title {
        font-size: 32px;
        margin-bottom: 30px;
        padding-bottom: 15px;
        border-bottom: 2px solid #0073aa;
    }

    .custom-post-item {
        border-bottom: 1px solid #eee;
        padding: 20px 0;
        margin-bottom: 20px;
    }

    .custom-post-title {
        font-size: 24px;
        margin-bottom: 10px;
    }

    .custom-post-title a {
        color: #333;
        text-decoration: none;
    }

    .custom-post-title a:hover {
        color: #0073aa;
    }

    .custom-post-excerpt {
        color: #666;
        line-height: 1.6;
        margin-bottom: 15px;
    }

    .custom-post-date {
        color: #999;
        font-size: 14px;
        margin-bottom: 10px;
    }

    .read-more-link {
        display: inline-block;
        padding: 10px 20px;
        background-color: #0073aa;
        color: white;
        text-decoration: none;
        border-radius: 4px;
    }

    .read-more-link:hover {
        background-color: #005177;
    }

    .pagination {
        margin: 30px 0;
        text-align: center;
    }

    .pagination a, .pagination span {
        display: inline-block;
        padding: 8px 12px;
        margin: 0 5px;
        border: 1px solid #ddd;
        text-decoration: none;
        color: #0073aa;
    }

    .pagination a:hover {
        background-color: #f0f0f0;
    }

    .pagination .current {
        background-color: #0073aa;
        color: white;
        border-color: #0073aa;
    }
</style>

<div class="custom-archive-wrapper">
    <?php
    the_archive_title('<h1 class="archive-title">', '</h1>');
    the_archive_description('<div class="archive-description">', '</div>');

    if (have_posts()) :
        while (have_posts()) : the_post();
            ?>
            <article class="custom-post-item">
                <h2 class="custom-post-title">
                    <a href="<?php the_permalink(); ?>"><?php the_title(); ?></a>
                </h2>

                <div class="custom-post-date">
                    发布于：<?php echo get_the_date('Y年m月d日'); ?>
                </div>

                <div class="custom-post-excerpt">
                    <?php
                    // 获取摘要，限制在150个字符
                    $excerpt = get_the_excerpt();
                    if (strlen($excerpt) > 150) {
                        $excerpt = substr($excerpt, 0, 150) . '...';
                    }
                    echo esc_html($excerpt);
                    ?>
                </div>

                <a href="<?php the_permalink(); ?>" class="read-more-link">阅读更多 →</a>
            </article>
            <?php
        endwhile;

        // 分页导航
        $big = 999999999;
        $pagination = paginate_links(array(
            'base' => str_replace($big, '%#%', esc_url(get_pagenum_link($big))),
            'format' => '/page/%#%',
            'current' => max(1, get_query_var('paged')),
            'total' => $wp_query->max_num_pages,
            'prev_text' => '← 上一页',
            'next_text' => '下一页 →',
            'type' => 'plain'
        ));

        if ($pagination) :
            ?>
            <div class="pagination">
                <?php echo $pagination; ?>
            </div>
        <?php
        endif;

    else :
        ?>
        <p>没有找到文章。</p>
    <?php
    endif;
    ?>
</div>

<?php
get_footer();
?>
