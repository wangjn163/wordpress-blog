#!/usr/bin/env python3
"""
清理错误的对话数据
"""
import sys
from datetime import date, datetime, timedelta
from app import app, db, Conversation

def clean_date(target_date_str):
    """清理指定日期的所有对话"""
    with app.app_context():
        target_date = datetime.strptime(target_date_str, '%Y-%m-%d').date()

        # 查询该日期的所有对话
        conversations = Conversation.query.filter_by(conversation_date=target_date).all()

        if not conversations:
            print(f"ℹ️  日期 {target_date} 没有对话数据")
            return

        print(f"⚠️  将删除 {target_date} 的 {len(conversations)} 条对话")
        print("前3条预览:")
        for conv in conversations[:3]:
            print(f"  [{conv.timestamp}] {conv.role}: {conv.message[:50]}...")

        confirm = input("\n确认删除? (yes/no): ")
        if confirm.lower() == 'yes':
            for conv in conversations:
                db.session.delete(conv)
            db.session.commit()
            print(f"✅ 已删除 {len(conversations)} 条对话")
        else:
            print("❌ 取消删除")

def show_all_dates():
    """显示所有有对话的日期"""
    with app.app_context():
        from sqlalchemy import func
        dates = db.session.query(
            Conversation.conversation_date,
            func.count(Conversation.id)
        ).group_by(
            Conversation.conversation_date
        ).order_by(
            Conversation.conversation_date.desc()
        ).all()

        print("\n📅 所有有对话的日期:")
        for d, count in dates:
            print(f"  {d}: {count} 条")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        show_all_dates()
        clean_date(sys.argv[1])
    else:
        print("用法: python3 clean_wrong_data.py YYYY-MM-DD")
        show_all_dates()
