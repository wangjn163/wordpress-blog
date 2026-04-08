<?php
/*
Plugin Name: DeepSeek AI 内容优化
Description: 在 WordPress 编辑器中集成 DeepSeek AI，对博客内容进行智能优化，使其更易读、更专业。
Version: 1.0.0
Author: Wang Jian
Requires at least: 6.0
Tested up to: 6.7
*/

if (!defined('ABSPATH')) exit;

class DeepSeek_Content_Optimizer {

    const OPTION_KEY = 'dsco_settings';
    const API_URL    = 'https://api.deepseek.com/chat/completions';

    private $settings;

    public function __construct() {
        $this->settings = get_option(self::OPTION_KEY, []);
        add_action('admin_menu', [$this, 'add_settings_page']);
        add_action('admin_init', [$this, 'register_settings']);
        add_action('admin_enqueue_scripts', [$this, 'enqueue_editor_assets']);
        add_action('rest_api_init', [$this, 'register_rest_route']);
    }

    /* ────────── Settings Page ────────── */

    public function add_settings_page() {
        add_options_page(
            'DeepSeek AI 内容优化',
            'DeepSeek AI 优化',
            'manage_options',
            'deepseek-content-optimizer',
            [$this, 'render_settings_page']
        );
    }

    public function register_settings() {
        register_setting('dsco_group', self::OPTION_KEY, [
            'sanitize_callback' => [$this, 'sanitize_settings'],
        ]);

        add_settings_section('dsco_main', '基本设置', null, 'deepseek-content-optimizer');

        add_settings_field('api_key', 'DeepSeek API Key', function () {
            $val = $this->get('api_key', '');
            echo '<input type="password" name="' . self::OPTION_KEY . '[api_key]" value="' . esc_attr($val) . '" class="regular-text" autocomplete="off">';
            echo '<p class="description">从 <a href="https://platform.deepseek.com/api_keys" target="_blank">platform.deepseek.com</a> 获取</p>';
        }, 'deepseek-content-optimizer', 'dsco_main');

        add_settings_field('model', '模型', function () {
            $val = $this->get('model', 'deepseek-chat');
            echo '<select name="' . self::OPTION_KEY . '[model]">';
            $models = ['deepseek-chat', 'deepseek-reasoner'];
            foreach ($models as $m) {
                printf('<option value="%s" %s>%s</option>', $m, selected($val, $m, false), $m);
            }
            echo '</select>';
            echo '<p class="description">deepseek-chat（通用）/ deepseek-reasoner（深度推理）</p>';
        }, 'deepseek-content-optimizer', 'dsco_main');

        add_settings_field('system_prompt', '系统提示词', function () {
            $val = $this->get('system_prompt', '');
            echo '<textarea name="' . self::OPTION_KEY . '[system_prompt]" rows="5" class="large-text">' . esc_textarea($val) . '</textarea>';
            echo '<p class="description">自定义 AI 的角色和行为指令，留空使用默认提示词</p>';
        }, 'deepseek-content-optimizer', 'dsco_main');

        // ─── 优化模式预设 ───
        add_settings_section('dsco_presets', '优化模式预设', null, 'deepseek-content-optimizer');

        $presets = $this->default_presets();
        foreach ($presets as $key => $preset) {
            add_settings_field('preset_' . $key, $preset['label'], function () use ($key, $preset) {
                $val = $this->get('preset_' . $key, $preset['prompt']);
                echo '<textarea name="' . self::OPTION_KEY . "[preset_{$key}]\" rows=\"3\" class=\"large-text\">" . esc_textarea($val) . '</textarea>';
            }, 'deepseek-content-optimizer', 'dsco_presets');
        }
    }

    public function sanitize_settings($input) {
        $clean = [];
        $clean['api_key']      = sanitize_text_field($input['api_key'] ?? '');
        $clean['model']        = sanitize_text_field($input['model'] ?? 'deepseek-chat');
        $clean['system_prompt'] = sanitize_textarea_field($input['system_prompt'] ?? '');

        $presets = $this->default_presets();
        foreach (array_keys($presets) as $key) {
            $clean['preset_' . $key] = sanitize_textarea_field($input['preset_' . $key] ?? $presets[$key]['prompt']);
        }

        return $clean;
    }

    public function render_settings_page() {
        ?>
        <div class="wrap">
            <h1>🤖 DeepSeek AI 内容优化</h1>
            <form method="post" action="options.php">
                <?php settings_fields('dsco_group'); ?>
                <?php do_settings_sections('deepseek-content-optimizer'); ?>
                <?php submit_button(); ?>
            </form>
        </div>
        <?php
    }

    /* ────────── REST API ────────── */

    public function register_rest_route() {
        register_rest_route('dsco/v1', '/optimize', [
            'methods'             => 'POST',
            'callback'            => [$this, 'handle_optimize'],
            'permission_callback' => function () {
                return current_user_can('edit_posts');
            },
        ]);
    }

    public function handle_optimize($request) {
        $api_key = $this->get('api_key', '');
        if (empty($api_key)) {
            return new WP_REST_Response(['error' => '请先在设置中配置 DeepSeek API Key'], 400);
        }

        $params  = $request->get_json_params();
        $content = sanitize_textarea_field($params['content'] ?? '');
        $title   = sanitize_text_field($params['title'] ?? '');
        $mode    = sanitize_text_field($params['mode'] ?? 'polish');

        if (empty(trim($content))) {
            return new WP_REST_Response(['error' => '内容不能为空'], 400);
        }

        // 组装提示词
        $system_prompt = $this->get('system_prompt', '');
        if (empty($system_prompt)) {
            $system_prompt = "你是一位专业的内容编辑和写作助手。你的任务是优化用户提供的博客内容，使其更加易读、专业、有吸引力。";
            $system_prompt .= "\n\n优化原则：\n";
            $system_prompt .= "1. 保持原文核心意思不变\n";
            $system_prompt .= "2. 改善句子结构和逻辑流畅性\n";
            $system_prompt .= "3. 修正语法和标点错误\n";
            $system_prompt .= "4. 增强表达力但不堆砌词藻\n";
            $system_prompt .= "5. 适当增加段落过渡使文章更连贯\n";
            $system_prompt .= "6. 保持 Markdown 格式（如果有）\n\n";
            $system_prompt .= "重要：只输出优化后的内容，不要添加任何解释或说明。";
        }

        // 获取模式预设
        $mode_prompt = $this->get('preset_' . $mode, '');
        if (empty($mode_prompt)) {
            $presets = $this->default_presets();
            $mode_prompt = $presets[$mode]['prompt'] ?? $presets['polish']['prompt'];
        }

        $user_message = "";
        if (!empty($title)) {
            $user_message .= "文章标题：{$title}\n\n";
        }
        $user_message .= "优化模式：{$mode_prompt}\n\n";
        $user_message .= "以下是需要优化的内容：\n\n{$content}";

        $body = [
            'model'       => $this->get('model', 'deepseek-chat'),
            'messages'    => [
                ['role' => 'system', 'content' => $system_prompt],
                ['role' => 'user',   'content' => $user_message],
            ],
            'temperature' => 0.7,
            'max_tokens'  => 4096,
        ];

        $response = wp_remote_post(self::API_URL, [
            'timeout' => 60,
            'headers' => [
                'Content-Type'  => 'application/json',
                'Authorization' => 'Bearer ' . $api_key,
            ],
            'body'    => wp_json_encode($body),
        ]);

        if (is_wp_error($response)) {
            return new WP_REST_Response(['error' => '请求失败: ' . $response->get_error_message()], 500);
        }

        $code = wp_remote_retrieve_response_code($response);
        $data = json_decode(wp_remote_retrieve_body($response), true);

        if ($code !== 200 || isset($data['error'])) {
            $msg = $data['error']['message'] ?? "HTTP {$code}";
            return new WP_REST_Response(['error' => 'DeepSeek API 错误: ' . $msg], 500);
        }

        $optimized = $data['choices'][0]['message']['content'] ?? '';
        $usage     = $data['usage'] ?? [];

        return new WP_REST_Response([
            'optimized_content' => $optimized,
            'usage'             => $usage,
        ]);
    }

    /* ────────── Editor Assets ────────── */

    public function enqueue_editor_assets($hook) {
        global $post_type;
        if (!in_array($hook, ['post.php', 'post-new.php'], true)) return;

        wp_enqueue_style(
            'dsco-editor',
            plugins_url('assets/css/editor.css', __FILE__),
            [],
            '1.0.0'
        );

        wp_enqueue_script(
            'dsco-editor',
            plugins_url('assets/js/editor.js', __FILE__),
            ['jquery', 'wp-editor'],
            '1.0.0',
            true
        );

        wp_localize_script('dsco-editor', 'dscoData', [
            'restUrl' => esc_url_raw(rest_url('dsco/v1/optimize')),
            'restNonce' => wp_create_nonce('wp_rest'),
            'i18n' => [
                'optimizing'  => '⏳ AI 正在优化中...',
                'success'     => '✅ 优化完成！',
                'error'       => '❌ 优化失败：',
                'emptyContent' => '请先输入内容',
                'apply'       => '替换为优化内容',
                'original'    => '恢复原始内容',
                'diff'        => '对比查看',
                'close'       => '关闭',
                'copy'        => '复制',
                'copied'      => '已复制',
            ],
        ]);
    }

    /* ────────── Helpers ────────── */

    private function get($key, $default = '') {
        return $this->settings[$key] ?? $default;
    }

    private function default_presets() {
        return [
            'polish' => [
                'label'  => '润色优化',
                'prompt' => '润色优化：改善文字表达、修正语法错误、使文章更流畅易读，保持原文风格和核心内容不变。',
            ],
            'simplify' => [
                'label'  => '简化易懂',
                'prompt' => '简化易懂：将复杂的技术概念和长句拆解为简洁明了的表达，让普通读者也能轻松理解，适当使用类比。',
            ],
            'expand' => [
                'label'  => '扩写丰富',
                'prompt' => '扩写丰富：在保持原有信息的基础上，增加必要的细节、例子和解释，使文章更加充实、有价值。',
            ],
            'seo' => [
                'label'  => 'SEO 优化',
                'prompt' => 'SEO优化：优化文章结构和关键词布局，确保标题清晰、段落分明，适当加入关键词但不过度堆砌，提高搜索引擎友好度。',
            ],
            'headline' => [
                'label'  => '生成摘要',
                'prompt' => '生成摘要：阅读全文后生成一段 100-200 字的文章摘要，概括核心内容和亮点，适合作为文章导语。',
            ],
        ];
    }
}

new DeepSeek_Content_Optimizer();
