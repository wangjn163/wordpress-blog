/**
 * DeepSeek Content Optimizer - Editor JavaScript
 */
(function ($) {
    'use strict';

    var DSCO = {
        currentMode: 'polish',
        originalContent: '',
        optimizedContent: '',
        isLoading: false,
        panelOpen: false,

        init: function () {
            this.injectToolbar();
            this.injectPanel();
            this.bindEvents();
        },

        /* ─── Inject Toolbar ─── */

        injectToolbar: function () {
            var modes = [
                { key: 'polish',    label: '✨ 润色优化' },
                { key: 'simplify',  label: '📖 简化易懂' },
                { key: 'expand',    label: '📝 扩写丰富' },
                { key: 'seo',       label: '🔍 SEO优化' },
                { key: 'headline',  label: '📋 生成摘要' },
            ];

            var $bar = $('<div class="dsco-toolbar">');
            $bar.append('<span class="dsco-label">🤖 AI优化</span>');

            var self = this;
            modes.forEach(function (m) {
                var $btn = $('<button class="dsco-mode-btn">')
                    .attr('data-mode', m.key)
                    .text(m.label);
                if (m.key === self.currentMode) $btn.addClass('active');
                $bar.append($btn);
            });

            $bar.append(
                $('<button class="dsco-optimize-btn">')
                    .attr('id', 'dsco-optimize')
                    .text('🚀 开始优化')
            );

            // Insert above editor
            var $editorWrap = $('#wp-content-editor-container, .block-editor-writing-flow');
            if ($editorWrap.length) {
                $bar.insertBefore($editorWrap.closest('.wp-editor-container, .editor-styles-wrapper').parent());
            } else {
                $('#post-body-content').prepend($bar);
            }

            // Fallback: also inject at top of #postdivrich if not placed
            if (!$bar.parent().length) {
                $('#postdivrich').before($bar);
            }
        },

        /* ─── Inject Result Panel ─── */

        injectPanel: function () {
            var html = '' +
                '<div class="dsco-result-overlay" id="dsco-overlay"></div>' +
                '<div class="dsco-result-panel" id="dsco-panel">' +
                '  <div class="dsco-panel-header">' +
                '    <h3>🤖 AI 优化结果</h3>' +
                '    <button class="dsco-close-btn" id="dsco-close">&times;</button>' +
                '  </div>' +
                '  <div class="dsco-panel-actions" id="dsco-actions" style="display:none">' +
                '    <button class="dsco-panel-action-btn primary" id="dsco-apply">✅ 替换为优化内容</button>' +
                '    <button class="dsco-panel-action-btn" id="dsco-original">↩️ 恢复原始内容</button>' +
                '    <button class="dsco-panel-action-btn" id="dsco-copy">📋 复制</button>' +
                '  </div>' +
                '  <div class="dsco-panel-content" id="dsco-panel-content">' +
                '    <div class="dsco-loading-text" id="dsco-loading" style="display:none">' +
                '      <div class="dsco-spinner-large"></div>' +
                '      <p>' + dscoData.i18n.optimizing + '</p>' +
                '    </div>' +
                '  </div>' +
                '  <div class="dsco-panel-footer" id="dsco-footer"></div>' +
                '</div>';

            $('body').append(html);
        },

        /* ─── Bind Events ─── */

        bindEvents: function () {
            var self = this;

            // Mode selection
            $(document).on('click', '.dsco-mode-btn', function () {
                if (self.isLoading) return;
                $('.dsco-mode-btn').removeClass('active');
                $(this).addClass('active');
                self.currentMode = $(this).data('mode');
            });

            // Optimize button
            $(document).on('click', '#dsco-optimize', function () {
                if (self.isLoading) return;
                self.optimize();
            });

            // Close panel
            $(document).on('click', '#dsco-close, #dsco-overlay', function () {
                self.closePanel();
            });

            // Apply optimized content
            $(document).on('click', '#dsco-apply', function () {
                self.applyContent(self.optimizedContent);
            });

            // Restore original
            $(document).on('click', '#dsco-original', function () {
                self.applyContent(self.originalContent);
            });

            // Copy
            $(document).on('click', '#dsco-copy', function () {
                self.copyToClipboard(self.optimizedContent);
            });
        },

        /* ─── Get Editor Content ─── */

        getContent: function () {
            // Gutenberg block editor
            if (wp.data && wp.data.select('core/editor')) {
                return wp.data.select('core/editor').getEditedPostAttribute('content') || '';
            }
            // Classic editor - visual mode
            if (typeof tinyMCE !== 'undefined' && tinyMCE.activeEditor) {
                return tinyMCE.activeEditor.getContent() || '';
            }
            // Classic editor - text mode
            return $('#content').val() || '';
        },

        /* ─── Set Editor Content ─── */

        setContent: function (content) {
            // Gutenberg
            if (wp.data && wp.data.dispatch('core/editor')) {
                wp.data.dispatch('core/editor').editPost({ content: content });
                return;
            }
            // Classic - visual mode
            if (typeof tinyMCE !== 'undefined' && tinyMCE.activeEditor) {
                tinyMCE.activeEditor.setContent(content);
            }
            // Classic - text mode
            $('#content').val(content);
        },

        /* ─── Get Title ─── */

        getTitle: function () {
            if (wp.data && wp.data.select('core/editor')) {
                return wp.data.select('core/editor').getEditedPostAttribute('title') || '';
            }
            return $('#title').val() || '';
        },

        /* ─── Optimize ─── */

        optimize: function () {
            var content = this.getContent();
            if (!content.trim()) {
                this.showMessage(dscoData.i18n.emptyContent, 'error');
                return;
            }

            this.originalContent = content;
            this.isLoading = true;
            this.openPanel();
            this.showLoading();

            // Disable buttons
            $('.dsco-mode-btn, .dsco-optimize-btn').prop('disabled', true);
            $('#dsco-optimize').html('<span class="dsco-spinner"></span> 优化中...');

            var self = this;
            $.ajax({
                url: dscoData.restUrl,
                method: 'POST',
                beforeSend: function (xhr) {
                    xhr.setRequestHeader('X-WP-Nonce', dscoData.restNonce);
                },
                contentType: 'application/json',
                data: JSON.stringify({
                    content: content,
                    title: self.getTitle(),
                    mode: self.currentMode,
                }),
                timeout: 120000,
                success: function (res) {
                    self.optimizedContent = res.optimized_content;
                    self.showResult(res.optimized_content, res.usage);
                },
                error: function (xhr) {
                    var msg = dscoData.i18n.error;
                    try {
                        var err = JSON.parse(xhr.responseText);
                        msg += (err.error || err.message || xhr.statusText);
                    } catch (e) {
                        msg += xhr.statusText;
                    }
                    self.showMessage(msg, 'error');
                },
                complete: function () {
                    self.isLoading = false;
                    $('.dsco-mode-btn, .dsco-optimize-btn').prop('disabled', false);
                    $('#dsco-optimize').text('🚀 开始优化');
                },
            });
        },

        /* ─── Apply Content ─── */

        applyContent: function (content) {
            this.setContent(content);
            this.closePanel();
            // Show quick notification
            this.showToast(dscoData.i18n.success);
        },

        /* ─── Copy ─── */

        copyToClipboard: function (text) {
            if (navigator.clipboard) {
                navigator.clipboard.writeText(text).then(function () {
                    $('#dsco-copy').text('✅ ' + dscoData.i18n.copied);
                    setTimeout(function () {
                        $('#dsco-copy').text('📋 ' + dscoData.i18n.copy);
                    }, 2000);
                });
            } else {
                // Fallback
                var ta = document.createElement('textarea');
                ta.value = text;
                document.body.appendChild(ta);
                ta.select();
                document.execCommand('copy');
                document.body.removeChild(ta);
                $('#dsco-copy').text('✅ ' + dscoData.i18n.copied);
                setTimeout(function () {
                    $('#dsco-copy').text('📋 ' + dscoData.i18n.copy);
                }, 2000);
            }
        },

        /* ─── Panel Controls ─── */

        openPanel: function () {
            $('#dsco-panel, #dsco-overlay').addClass('open');
            this.panelOpen = true;
        },

        closePanel: function () {
            $('#dsco-panel, #dsco-overlay').removeClass('open');
            this.panelOpen = false;
        },

        showLoading: function () {
            $('#dsco-panel-content').html(
                '<div class="dsco-loading-text">' +
                '  <div class="dsco-spinner-large"></div>' +
                '  <p>' + dscoData.i18n.optimizing + '</p>' +
                '</div>'
            );
            $('#dsco-actions').hide();
            $('#dsco-footer').text('');
        },

        showResult: function (content, usage) {
            var escaped = $('<div>').text(content).html();

            $('#dsco-panel-content').html(
                '<textarea class="dsco-content-area" readonly>' + escaped + '</textarea>'
            );
            $('#dsco-actions').show();

            if (usage) {
                $('#dsco-footer').text(
                    'Token 使用：输入 ' + (usage.prompt_tokens || 0) +
                    ' + 输出 ' + (usage.completion_tokens || 0) +
                    ' = 总计 ' + (usage.total_tokens || 0)
                );
            }
        },

        showMessage: function (msg, type) {
            var cls = type === 'error' ? 'dsco-error-text' : '';
            $('#dsco-panel-content').html('<div class="' + cls + '">' + msg + '</div>');
            if (!this.panelOpen) this.openPanel();
        },

        showToast: function (msg) {
            var $toast = $('<div>')
                .css({
                    position: 'fixed',
                    top: '50px',
                    right: '30px',
                    padding: '10px 20px',
                    background: '#2271b1',
                    color: '#fff',
                    borderRadius: '4px',
                    fontSize: '13px',
                    zIndex: '999999',
                    boxShadow: '0 2px 10px rgba(0,0,0,0.2)',
                    opacity: 0,
                    transition: 'opacity 0.3s',
                })
                .text(msg);

            $('body').append($toast);
            $toast.animate({ opacity: 1 }, 200);
            setTimeout(function () {
                $toast.animate({ opacity: 0 }, 300, function () { $toast.remove(); });
            }, 2000);
        },
    };

    // Init when DOM + editor ready
    $(document).ready(function () {
        // Wait a bit for Gutenberg to initialize
        if (wp && wp.data) {
            setTimeout(function () { DSCO.init(); }, 500);
        } else {
            DSCO.init();
        }
    });

})(jQuery);
