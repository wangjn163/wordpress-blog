#!/bin/bash

# IMA OpenAPI 辅助函数
# 使用前请确保已设置环境变量：
# export IMA_OPENAPI_CLIENTID="your_client_id"
# export IMA_OPENAPI_APIKEY="your_api_key"

IMA_BASE_URL="https://ima.qq.com/openapi/note/v1"

# 检查凭证是否配置
check_credentials() {
    if [ -z "$IMA_OPENAPI_CLIENTID" ] || [ -z "$IMA_OPENAPI_APIKEY" ]; then
        echo "错误：缺少 IMA 凭证"
        echo "请配置环境变量："
        echo "  export IMA_OPENAPI_CLIENTID=\"your_client_id\""
        echo "  export IMA_OPENAPI_APIKEY=\"your_api_key\""
        echo ""
        echo "获取凭证：https://ima.qq.com/agent-interface"
        return 1
    fi
    return 0
}

# IMA API 调用通用函数
# 参数: endpoint, json_body
ima_api() {
    local endpoint="$1"
    local body="$2"

    check_credentials || return 1

    curl -s -X POST "${IMA_BASE_URL}/${endpoint}" \
        -H "ima-openapi-clientid: ${IMA_OPENAPI_CLIENTID}" \
        -H "ima-openapi-apikey: ${IMA_OPENAPI_APIKEY}" \
        -H "Content-Type: application/json" \
        -d "$body"
}

# 搜索笔记
# 参数: search_type(0=标题,1=正文), keyword, start, end
ima_search_notes() {
    local search_type="${1:-0}"
    local keyword="$2"
    local start="${3:-0}"
    local end="${4:-20}"

    local query_key="title"
    if [ "$search_type" = "1" ]; then
        query_key="content"
    fi

    local body="{\"search_type\": ${search_type}, \"query_info\": {\"${query_key}\": \"${keyword}\"}, \"start\": ${start}, \"end\": ${end}}"
    ima_api "search_note_book" "$body"
}

# 获取笔记内容
# 参数: doc_id
ima_get_note() {
    local doc_id="$1"
    local body="{\"doc_id\": \"${doc_id}\", \"target_content_format\": 0}"
    ima_api "get_doc_content" "$body"
}

# 列出笔记本
# 参数: cursor, limit
ima_list_folders() {
    local cursor="${1:-0}"
    local limit="${2:-20}"
    local body="{\"cursor\": \"${cursor}\", \"limit\": ${limit}}"
    ima_api "list_note_folder_by_cursor" "$body"
}

# 列出笔记本中的笔记
# 参数: folder_id, cursor, limit
ima_list_notes() {
    local folder_id="${1:-}"
    local cursor="${2:-}"
    local limit="${3:-20}"

    if [ -n "$folder_id" ]; then
        local body="{\"folder_id\": \"${folder_id}\", \"cursor\": \"${cursor}\", \"limit\": ${limit}}"
    else
        local body="{\"cursor\": \"${cursor}\", \"limit\": ${limit}}"
    fi

    ima_api "list_note_by_folder_id" "$body"
}

# 新建笔记
# 参数: content, folder_id(可选)
ima_create_note() {
    local content="$1"
    local folder_id="${2:-}"

    if [ -n "$folder_id" ]; then
        local body="{\"content_format\": 1, \"content\": \"${content}\", \"folder_id\": \"${folder_id}\"}"
    else
        local body="{\"content_format\": 1, \"content\": \"${content}\"}"
    fi

    ima_api "import_doc" "$body"
}

# 追加内容到笔记
# 参数: doc_id, content
ima_append_note() {
    local doc_id="$1"
    local content="$2"
    local body="{\"doc_id\": \"${doc_id}\", \"content_format\": 1, \"content\": \"${content}\"}"
    ima_api "append_doc" "$body"
}

# 如果直接执行此脚本，显示帮助信息
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        search)
            ima_search_notes "${2:-0}" "$3" "${4:-0}" "${5:-20}"
            ;;
        get)
            ima_get_note "$2"
            ;;
        folders)
            ima_list_folders "${2:-0}" "${3:-20}"
            ;;
        notes)
            ima_list_notes "$2" "${3:-}" "${4:-20}"
            ;;
        create)
            ima_create_note "$2" "$3"
            ;;
        append)
            ima_append_note "$2" "$3"
            ;;
        *)
            echo "IMA Note API 辅助工具"
            echo ""
            echo "使用方法："
            echo "  source ima.sh           # 加载函数"
            echo "  ima_search_notes 0 \"关键词\" 0 20    # 搜索笔记"
            echo "  ima_get_note \"doc_id\"             # 获取笔记内容"
            echo "  ima_list_folders \"0\" 20            # 列出笔记本"
            echo "  ima_list_notes \"folder_id\" \"\" 20   # 列出笔记"
            echo "  ima_create_note \"内容\" \"folder_id\"  # 新建笔记"
            echo "  ima_append_note \"doc_id\" \"内容\"     # 追加内容"
            echo ""
            check_credentials || exit 1
            ;;
    esac
fi
