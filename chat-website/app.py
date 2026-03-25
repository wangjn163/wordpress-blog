#!/usr/bin/env python3
"""
实时对话网站后端服务（带工作计划功能）
使用 Flask + SQLAlchemy + PostgreSQL
"""
from flask import Flask, jsonify, request, send_from_directory, session, redirect, url_for
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, date, timedelta
import json
import os

app = Flask(__name__, static_folder='.')
app.config['SECRET_KEY'] = 'your-secret-key-change-this'
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:postgres@localhost/chatdb'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# 初始化数据库
db = SQLAlchemy(app)
CORS(app, supports_credentials=True)

# ==================== 数据库模型 ====================
class User(db.Model):
    """用户表"""
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def set_password(self, password):
        """设置密码（加密存储）"""
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        """验证密码"""
        return check_password_hash(self.password_hash, password)

class Conversation(db.Model):
    """对话表（按天存储）"""
    __tablename__ = 'conversations'
    
    id = db.Column(db.Integer, primary_key=True)
    role = db.Column(db.String(20), nullable=False)  # 'user' or 'assistant'
    message = db.Column(db.Text, nullable=False)
    conversation_date = db.Column(db.Date, nullable=False, index=True)  # 对话日期
    timestamp = db.Column(db.String(10), nullable=False)  # 时间戳 HH:MM
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        """转换为字典"""
        return {
            'id': self.id,
            'role': self.role,
            'message': self.message,
            'timestamp': self.timestamp,
            'date': self.conversation_date.strftime('%Y-%m-%d')
        }

class WorkPlan(db.Model):
    """工作计划表"""
    __tablename__ = 'work_plans'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    plan_date = db.Column(db.Date, nullable=False, index=True)  # 计划日期
    week_goals = db.Column(db.Text)  # 本周目标
    yesterday_work = db.Column(db.Text)  # 昨日工作
    today_plan = db.Column(db.Text)  # 今日计划
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    user = db.relationship('User', backref=db.backref('work_plans', lazy=True))
    
    def to_dict(self):
        """转换为字典"""
        return {
            'id': self.id,
            'plan_date': self.plan_date.strftime('%Y-%m-%d'),
            'week_goals': self.week_goals,
            'yesterday_work': self.yesterday_work,
            'today_plan': self.today_plan,
            'created_at': self.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'updated_at': self.updated_at.strftime('%Y-%m-%d %H:%M:%S')
        }

# ==================== 辅助函数 ====================
def get_conversations_by_date(target_date, page=1, per_page=50):
    """按日期获取对话（分页）"""
    query = Conversation.query.filter_by(conversation_date=target_date)
    query = query.order_by(Conversation.created_at.asc())
    pagination = query.paginate(page=page, per_page=per_page, error_out=False)
    
    return {
        'conversations': [conv.to_dict() for conv in pagination.items],
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page,
        'has_next': pagination.has_next,
        'has_prev': pagination.has_prev
    }

def get_all_dates():
    """获取所有有对话的日期列表"""
    dates = db.session.query(Conversation.conversation_date).distinct()\
        .order_by(Conversation.conversation_date.desc()).all()
    return [d[0].strftime('%Y-%m-%d') for d in dates]

def save_conversation_to_db(role, message):
    """保存对话到数据库"""
    today = date.today()
    now = datetime.now()
    timestamp_str = now.strftime("%H:%M")
    
    conv = Conversation(
        role=role,
        message=message,
        conversation_date=today,
        timestamp=timestamp_str
    )
    db.session.add(conv)
    db.session.commit()
    
    return conv.to_dict()

def get_or_create_work_plan(target_date, user_id):
    """获取或创建工作计划"""
    plan = WorkPlan.query.filter_by(plan_date=target_date, user_id=user_id).first()
    if not plan:
        plan = WorkPlan(
            user_id=user_id,
            plan_date=target_date,
            week_goals='',
            yesterday_work='',
            today_plan=''
        )
        db.session.add(plan)
        db.session.commit()
    return plan

# ==================== 路由 ====================
@app.route('/')
def index():
    """主页 - 重定向到登录页"""
    return redirect('/login')

@app.route('/login')
def login_page():
    """登录页面"""
    return send_from_directory('.', 'login.html')

@app.route('/chat')
def chat_page():
    """聊天页面（需要登录）"""
    return send_from_directory('.', 'index.html')

@app.route('/workplan')
def workplan_page():
    """工作计划页面（需要登录）"""
    return send_from_directory('.', 'index.html')

@app.route('/static/<path:filename>')
def static_files(filename):
    """静态文件服务"""
    return send_from_directory('static', filename)

@app.route('/api/login', methods=['POST'])
def login():
    """登录API"""
    data = request.json
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({"error": "用户名和密码不能为空"}), 400
    
    user = User.query.filter_by(username=username).first()
    
    if user and user.check_password(password):
        session['logged_in'] = True
        session['username'] = username
        session['user_id'] = user.id
        return jsonify({"success": True, "message": "登录成功"})
    else:
        return jsonify({"error": "用户名或密码错误"}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    """登出API"""
    session.clear()
    return jsonify({"success": True, "message": "已登出"})

@app.route('/api/check-auth', methods=['GET'])
def check_auth():
    """检查登录状态"""
    if session.get('logged_in'):
        return jsonify({
            "logged_in": True, 
            "username": session.get('username'),
            "user_id": session.get('user_id')
        })
    return jsonify({"logged_in": False}), 401

@app.route('/api/conversations', methods=['GET'])
def get_conversations():
    """获取对话（支持按日期查询和分页）"""
    if not session.get('logged_in'):
        return jsonify({"error": "请先登录"}), 401
    
    target_date_str = request.args.get('date', date.today().strftime('%Y-%m-%d'))
    page = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 50))
    
    try:
        target_date = datetime.strptime(target_date_str, '%Y-%m-%d').date()
    except ValueError:
        return jsonify({"error": "日期格式错误，请使用 YYYY-MM-DD"}), 400
    
    result = get_conversations_by_date(target_date, page, per_page)
    result['available_dates'] = get_all_dates()
    result['current_date'] = target_date_str
    
    return jsonify(result)

@app.route('/api/conversations', methods=['POST'])
def add_conversation():
    """添加新对话（需要登录）"""
    if not session.get('logged_in'):
        return jsonify({"error": "请先登录"}), 401
    
    content = request.json
    role = content.get('role')
    message = content.get('message')
    
    if not role or not message:
        return jsonify({"error": "Missing role or message"}), 400
    
    new_msg = save_conversation_to_db(role, message)
    return jsonify(new_msg)

@app.route('/api/sync-conversations', methods=['POST'])
def sync_conversations():
    """触发对话同步（需要登录）- 支持日期归档"""
    if not session.get('logged_in'):
        return jsonify({"error": "请先登录"}), 401

    try:
        # 方案：直接从导出脚本读取对话列表并同步
        import subprocess
        import os
        import logging

        logging.basicConfig(level=logging.INFO)
        logger = logging.getLogger(__name__)
        import logging

        logging.basicConfig(level=logging.INFO)
        logger = logging.getLogger(__name__)

        # 1. 点击刷新时，自动从会话历史中提取最新对话
        export_script = os.path.join(os.path.dirname(__file__), 'auto_extract_from_session.py')

        logger.info(f"开始从会话历史提取对话，脚本路径: {export_script}")
        export_result = subprocess.run(
            ['python3', export_script],
            capture_output=True,
            text=True,
            timeout=60  # 增加超时时间，因为文件可能很大
        )

        if export_result.returncode != 0:
            logger.error(f"从会话提取失败: {export_result.stderr}")
            return jsonify({
                "success": False,
                "error": "提取会话失败: " + export_result.stderr
            }), 500

        logger.info(f"提取结果: {export_result.stdout}")

        # 2. 读取生成的JSON文件
        json_file = os.path.join(os.path.dirname(__file__), 'data/conversations.json')

        if not os.path.exists(json_file):
            logger.error(f"JSON文件不存在: {json_file}")
            return jsonify({
                "success": False,
                "error": "对话文件不存在，请先进行对话"
            }), 500

        import json
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        conversations = data.get('conversations', [])
        logger.info(f"读取到 {len(conversations)} 条对话")

        # 3. 获取请求参数（指定目标日期）
        try:
            req_data = request.get_json(force=False, silent=True) or {}
        except:
            req_data = {}
        target_date_str = req_data.get('target_date') if req_data else None

        from datetime import date, timedelta

        if target_date_str:
            target_date = datetime.strptime(target_date_str, '%Y-%m-%d').date()
        else:
            # 自动判断：根据导出文件中的日期字段来确定目标日期
            target_date = date.today()

            # 优先使用导出文件中的日期字段
            if 'date' in data:
                try:
                    target_date = datetime.strptime(data['date'], '%Y-%m-%d').date()
                    logger.info(f"使用导出文件中的日期: {target_date}")
                except ValueError:
                    pass
            # 备选方案：从第一条对话的时间戳来确定日期
            elif conversations and 'date' in conversations[0]:
                try:
                    first_conv_date = datetime.strptime(conversations[0]['date'], '%Y-%m-%d').date()
                    target_date = first_conv_date
                    logger.info(f"根据第一条对话确定日期: {target_date}")
                except (ValueError, KeyError):
                    pass

            logger.info(f"最终确定的目标日期: {target_date}")

        logger.info(f"目标日期: {target_date}")

        # 4. 同步到数据库
        synced_count = 0
        for conv in conversations:
            try:
                # 检查是否已存在
                existing = Conversation.query.filter_by(
                    conversation_date=target_date,
                    timestamp=conv['timestamp'],
                    role=conv['role']
                ).first()

                if not existing:
                    new_conv = Conversation(
                        role=conv['role'],
                        message=conv['message'],
                        conversation_date=target_date,
                        timestamp=conv['timestamp']
                    )
                    db.session.add(new_conv)
                    synced_count += 1
            except Exception as e:
                logger.error(f"同步单条对话失败: {e}")
                continue

        if synced_count > 0:
            db.session.commit()
            logger.info(f"成功同步 {synced_count} 条对话")

        return jsonify({
            "success": True,
            "message": f"同步完成！新增 {synced_count} 条对话到 {target_date}",
            "new_count": synced_count,
            "total_conversations": len(conversations),
            "target_date": target_date.strftime('%Y-%m-%d')
        })

    except Exception as e:
        db.session.rollback()
        import traceback
        error_details = traceback.format_exc()
        print(f"同步失败详细错误:\n{error_details}")
        return jsonify({
            "success": False,
            "error": str(e),
            "details": error_details
        }), 500

@app.route('/api/dates', methods=['GET'])
def get_dates():
    """获取所有有对话的日期"""
    if not session.get('logged_in'):
        return jsonify({"error": "请先登录"}), 401
    
    dates = get_all_dates()
    return jsonify({"dates": dates})

@app.route('/api/workplan', methods=['GET'])
def get_workplan():
    """获取工作计划"""
    if not session.get('logged_in'):
        return jsonify({"error": "请先登录"}), 401
    
    target_date_str = request.args.get('date', date.today().strftime('%Y-%m-%d'))
    user_id = session.get('user_id')
    
    try:
        target_date = datetime.strptime(target_date_str, '%Y-%m-%d').date()
    except ValueError:
        return jsonify({"error": "日期格式错误"}), 400
    
    plan = get_or_create_work_plan(target_date, user_id)
    return jsonify(plan.to_dict())

@app.route('/api/workplan', methods=['POST'])
def save_workplan():
    """保存工作计划"""
    if not session.get('logged_in'):
        return jsonify({"error": "请先登录"}), 401
    
    data = request.json
    target_date_str = data.get('date')
    user_id = session.get('user_id')
    
    try:
        target_date = datetime.strptime(target_date_str, '%Y-%m-%d').date()
    except ValueError:
        return jsonify({"error": "日期格式错误"}), 400
    
    plan = get_or_create_work_plan(target_date, user_id)
    plan.week_goals = data.get('week_goals', '')
    plan.yesterday_work = data.get('yesterday_work', '')
    plan.today_plan = data.get('today_plan', '')
    plan.updated_at = datetime.utcnow()
    
    db.session.commit()
    
    return jsonify({"success": True, "message": "保存成功", "data": plan.to_dict()})

@app.route('/api/health', methods=['GET'])
def health():
    """健康检查"""
    return jsonify({"status": "ok", "timestamp": datetime.now().isoformat()})

# ==================== 初始化数据库 ====================
def init_db():
    """初始化数据库和默认用户"""
    with app.app_context():
        db.create_all()
        
        existing_user = User.query.filter_by(username='wangjian').first()
        if not existing_user:
            user = User(username='wangjian')
            user.set_password('wangjianc')
            db.session.add(user)
            db.session.commit()
            print("✅ 创建默认用户: wangjian / wangjianc")
        else:
            print("ℹ️  用户 wangjian 已存在")

if __name__ == '__main__':
    init_db()
    
    print("🚀 启动对话服务...")
    print("📡 服务地址: http://0.0.0.0:80")
    print("🔐 登录页面: http://0.0.0.0:80/login")
    print("💬 聊天页面: http://0.0.0.0:80/chat")
    print("📋 工作计划: http://0.0.0.0:80/workplan")
    print("📦 默认账号: wangjian / wangjianc")
    app.run(host='0.0.0.0', port=80, debug=True)