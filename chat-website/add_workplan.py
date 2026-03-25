#!/usr/bin/env python3
"""
添加工作计划到数据库
"""
import sys
from datetime import datetime, date

sys.path.insert(0, '/root/.openclaw/workspace/chat-website')

from app import app, db, WorkPlan, User

def add_work_plan(target_date, week_goals, yesterday_work, today_plan):
    """添加工作计划"""
    with app.app_context():
        # 获取用户
        user = User.query.filter_by(username='wangjian').first()
        if not user:
            print("❌ 用户不存在")
            return False

        # 查找或创建工作计划
        plan = WorkPlan.query.filter_by(
            plan_date=target_date,
            user_id=user.id
        ).first()

        if plan:
            # 更新现有计划
            plan.week_goals = week_goals
            plan.yesterday_work = yesterday_work
            plan.today_plan = today_plan
            plan.updated_at = datetime.utcnow()
            print(f"✅ 更新工作计划: {target_date}")
        else:
            # 创建新计划
            plan = WorkPlan(
                user_id=user.id,
                plan_date=target_date,
                week_goals=week_goals,
                yesterday_work=yesterday_work,
                today_plan=today_plan
            )
            db.session.add(plan)
            print(f"✅ 创建工作计划: {target_date}")

        db.session.commit()
        return True

if __name__ == '__main__':
    today = date.today()

    week_goals = """一、强一致性查询慢问题分析、性能调优方案
慢问题分析

二、CMI_IOT向量库升级部署

三、CTI_ZJ向量库升级部署高可用
方案编写
与现场讨论方案
验证minio,kafka多向量库共用集群

四、drf冷备恢复时的数据准确性
环境搭建
问题复现"""

    yesterday_work = """三、CTI_ZJ向量库升级部署高可用
部署向量库，镜像使用的harbor无法拉取，现场排查问题。

四、drf冷备恢复时的数据准确性
定位问题，没有全量同步，所以无法恢复数据"""

    today_plan = """三、CTI_ZJ向量库升级部署高可用
部署向量库

四、drf冷备恢复时的数据准确性
问题复现"""

    add_work_plan(today, week_goals, yesterday_work, today_plan)
    print(f"\n💡 访问网站工作计划页面查看: http://42.193.14.72/workplan")
