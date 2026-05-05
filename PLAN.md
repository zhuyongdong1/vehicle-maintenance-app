# 车辆维修管理APP - 项目计划 (Flutter)

> 域名：**ulbooks.cn** | 单用户 | 无登录

## 整体架构

```
┌──────────────────────────────┐
│  Flutter APP (Android/Web)   │
│  Riverpod + go_router         │
└──────────────┬───────────────┘
               │ HTTP REST API (ulbooks.cn)
┌──────────────▼───────────────┐
│  Dart Shelf 后端服务           │
│  + Baidu OCR API              │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│  MySQL (云服务器)              │
└──────────────────────────────┘
```

---

## 技术方案

| 项目 | 选型 | 理由 |
|------|------|------|
| 前端框架 | Flutter 3.35 / Dart 3.9 | 一次开发 Android + Web |
| 状态管理 | Riverpod | 类型安全、无全局单例 |
| 路由 | go_router | 官方推荐 |
| UI | Material 3 | 现代化移动端体验 |
| 后端框架 | Dart Shelf | 前后端统一 Dart |
| 数据库 | MySQL 8.0 | 云部署，稳定可靠 |
| OCR 识别 | 百度OCR API | 车牌识别 / VIN码识别 |
| HTTP 客户端 | dio | 功能强大的网络请求库 |
| 云部署 | Docker + Nginx | 容器化一键部署 |
| 域名 | ulbooks.cn | Nginx 反向代理 |

---

## 功能模块

### 1. 车辆信息管理
- 车牌号、车架号/VIN码
- 品牌、型号、年份、颜色
- 车主姓名、电话
- 车辆照片（上传到服务器）
- 年检日期、保险日期
- 增/删/改/查

### 2. 百度 OCR 扫描录入 ⭐ 核心
- 拍照扫车牌 → 百度车牌识别 API → 自动回填
- 拍照扫车架号 → 百度通用文字识别 → 自动回填VIN码
- 扫描预览 + 手动修正

### 3. 维修记录管理
- 新增维修（关联车辆）
- **维修类型由客户自定义**（内置默认分类，可增删改）
- 项目、费用、里程数、日期
- 维修厂、备注、配件清单
- 下次保养提醒
- 增/删/改/查

### 4. 记账管理
- 收入/支出双类型
- **收入/支出分类由客户自定义**（内置默认，可增删改）
- 维修记录可一键记收入（自动关联）
- 收支明细列表，按日期/类型/分类筛选
- 月度/季度收支汇总、净利润统计
- 增/删/改/查

### 5. 首页仪表盘
- 本月收支概览（收入/支出/净利润卡片）
- 本月维修台次
- 待保养提醒列表
- 最近维修记录 + 最近记账

### 6. 提醒功能
- 保养/年检/保险到期提醒

### 7. 分类管理 ⭐ 客户可自定义
- 维修类型管理 → 增/删/改/查
- 收入分类管理 → 增/删/改/查
- 支出分类管理 → 增/删/改/查

### 8. 搜索 & 筛选
- 车牌号/车架号搜索
- 维修类型/日期筛选
- 记账类型/分类/日期筛选

---

## 页面路由 (go_router)

```
/dashboard              首页仪表盘
/vehicles               车辆列表
/vehicles/add           添加车辆（含OCR扫描）
/vehicles/:id           车辆详情（含该车维修历史）
/vehicles/:id/edit      编辑车辆
/records                维修记录列表
/records/add?vehicleId= 新增维修记录
/records/:id            维修记录详情
/ledger                 记账列表
/ledger/add             新增记账
/ledger/:id             记账详情
/ledger/:id/edit        编辑记账
/settings               设置中心
/settings/categories    分类管理（维修类型/收支分类）
```

---

## MySQL 数据表

```sql
-- 客户可自定义的分类表（维修类型、收入分类、支出分类）
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type VARCHAR(30) NOT NULL COMMENT '分类类型',
    name VARCHAR(50) NOT NULL COMMENT '分类名称',
    sort_order INT DEFAULT 0 COMMENT '排序',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
-- type 枚举值: 'maintenance_type' | 'ledger_income' | 'ledger_expense'
-- 默认数据:
--   maintenance_type: 保养, 机修, 电路, 钣金, 喷漆, 轮胎, 其他
--   ledger_income:    维修收入, 配件销售, 其他收入
--   ledger_expense:   配件采购, 工具设备, 房租, 水电, 工资, 其他支出

-- 车辆表
CREATE TABLE vehicles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    plate_number VARCHAR(20) NOT NULL COMMENT '车牌号',
    vin VARCHAR(50) COMMENT '车架号',
    brand VARCHAR(50) COMMENT '品牌',
    model VARCHAR(50) COMMENT '型号',
    year INT COMMENT '年份',
    color VARCHAR(20) COMMENT '颜色',
    owner_name VARCHAR(50) COMMENT '车主',
    owner_phone VARCHAR(20) COMMENT '电话',
    photo_url TEXT COMMENT '照片URL',
    inspection_date DATE COMMENT '年检到期日',
    insurance_date DATE COMMENT '保险到期日',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 维修记录表
CREATE TABLE records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_id INT NOT NULL COMMENT '车辆ID',
    category_id INT COMMENT '维修分类ID（关联categories表）',
    items TEXT COMMENT '维修项目',
    cost DECIMAL(10,2) COMMENT '费用',
    mileage INT COMMENT '里程数(km)',
    record_date DATE COMMENT '维修日期',
    workshop VARCHAR(100) COMMENT '维修厂',
    notes TEXT COMMENT '备注',
    parts TEXT COMMENT '配件清单',
    reminder_date DATE COMMENT '下次保养提醒日期',
    reminder_mileage INT COMMENT '下次保养提醒里程',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- 记账表
CREATE TABLE ledger (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type ENUM('income', 'expense') NOT NULL COMMENT '类型：收入/支出',
    category_id INT COMMENT '记账分类ID（关联categories表）',
    amount DECIMAL(10,2) NOT NULL COMMENT '金额',
    record_date DATE NOT NULL COMMENT '日期',
    description TEXT COMMENT '说明',
    related_record_id INT COMMENT '关联维修记录ID（可为空）',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);
```

---

## 后端 API 设计

| 方法 | 路径 | 说明 |
|------|------|------|
| **车辆** | | |
| GET | /api/vehicles | 车辆列表（支持搜索） |
| GET | /api/vehicles/:id | 车辆详情 |
| POST | /api/vehicles | 添加车辆 |
| PUT | /api/vehicles/:id | 更新车辆 |
| DELETE | /api/vehicles/:id | 删除车辆 |
| **维修记录** | | |
| GET | /api/records | 维修记录列表 |
| GET | /api/records/:id | 维修记录详情 |
| POST | /api/records | 新增维修记录 |
| PUT | /api/records/:id | 更新维修记录 |
| DELETE | /api/records/:id | 删除维修记录 |
| **记账** | | |
| GET | /api/ledger | 记账列表（支持筛选） |
| GET | /api/ledger/:id | 记账详情 |
| POST | /api/ledger | 新增记账 |
| PUT | /api/ledger/:id | 更新记账 |
| DELETE | /api/ledger/:id | 删除记账 |
| GET | /api/ledger/stats | 收支统计（按月/季/年） |
| **分类管理** ⭐ | | |
| GET | /api/categories?type=xxx | 获取分类列表 |
| POST | /api/categories | 新增分类 |
| PUT | /api/categories/:id | 更新分类名称/排序 |
| DELETE | /api/categories/:id | 删除分类 |
| **OCR** | | |
| POST | /api/ocr/plate | 拍照→百度识别车牌号 |
| POST | /api/ocr/vin | 拍照→百度识别VIN码 |
| **其他** | | |
| POST | /api/upload | 上传车辆照片 |
| GET | /api/dashboard | 首页统计数据 |

---

## 项目结构

```
vehicle-maintenance-app/
├── frontend/                    # Flutter 前端
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   │   ├── api/
│   │   │   │   ├── api_client.dart        # dio 封装
│   │   │   │   ├── vehicle_api.dart
│   │   │   │   ├── record_api.dart
│   │   │   │   ├── ledger_api.dart
│   │   │   │   ├── category_api.dart      # 分类接口
│   │   │   │   └── ocr_api.dart
│   │   │   ├── config.dart                # API地址（ulbooks.cn）
│   │   │   ├── router.dart                # go_router
│   │   │   └── theme.dart                 # Material 3 主题
│   │   ├── features/
│   │   │   ├── dashboard/
│   │   │   ├── vehicles/
│   │   │   ├── records/
│   │   │   ├── ledger/                    # 记账管理
│   │   │   ├── ocr/                       # OCR 扫描页面
│   │   │   └── settings/                  # 设置中心 + 分类管理
│   │   ├── models/
│   │   │   ├── vehicle.dart
│   │   │   ├── record.dart
│   │   │   ├── ledger.dart
│   │   │   ├── category.dart
│   │   │   └── dashboard_stats.dart
│   │   └── widgets/                       # 通用组件
│   └── pubspec.yaml
│
├── backend/                     # Dart Shelf 后端
│   ├── bin/
│   │   └── server.dart
│   ├── lib/
│   │   ├── router.dart
│   │   ├── middleware.dart          # CORS等中间件
│   │   ├── config.dart              # 数据库、百度OCR key、域名
│   │   ├── database/
│   │   │   ├── connection.dart      # MySQL 连接
│   │   │   └── schema.sql           # 建表 + 默认分类数据
│   │   ├── handlers/
│   │   │   ├── vehicle_handler.dart
│   │   │   ├── record_handler.dart
│   │   │   ├── ledger_handler.dart
│   │   │   ├── category_handler.dart
│   │   │   ├── ocr_handler.dart
│   │   │   └── upload_handler.dart
│   │   └── services/
│   │       ├── baidu_ocr.dart
│   │       └── file_service.dart
│   └── pubspec.yaml
│
├── docker-compose.yml
├── Dockerfile
├── nginx.conf                    # Nginx 反向代理配置（ulbooks.cn）
└── README.md
```

---

## 开发步骤

| 步骤 | 内容 |
|------|------|
| 1 | Flutter 创建前端项目，搭建目录结构 |
| 2 | Material 3 主题 + go_router 路由 + 域名配置 |
| 3 | Dart Shelf 后端项目 + MySQL 连接 + 建表（含默认分类种子数据） |
| 4 | 分类管理 CRUD API + 前端设置页面 |
| 5 | 车辆 CRUD API + Flutter 页面 |
| 6 | 百度 OCR 集成 |
| 7 | 维修记录 CRUD API + Flutter 页面（动态加载维修分类） |
| 8 | 记账 CRUD API + Flutter 页面（动态加载收支分类） |
| 9 | 首页仪表盘 + 提醒功能 |
| 10 | 搜索筛选功能 |
| 11 | Docker 打包 + Nginx 配置 + 部署文档 |

---

## 客户可自定义清单

| 数据 | 管理入口 | 默认值 |
|------|----------|--------|
| 维修类型 | 设置→维修分类 | 保养/机修/电路/钣金/喷漆/轮胎/其他 |
| 记账收入分类 | 设置→收入分类 | 维修收入/配件销售/其他收入 |
| 记账支出分类 | 设置→支出分类 | 配件采购/工具设备/房租/水电/工资/其他 |
| 车辆信息 | 车辆管理 | — |
| 维修记录 | 维修记录 | — |
| 记账条目 | 记账管理 | — |

> 所有数据均支持 **增/删/改/查**，客户可自由管理。

---

## 部署说明

- 域名：`ulbooks.cn`
- 前端 Web 版部署到 `ulbooks.cn`
- 后端 API 通过 `/api/*` 路径反向代理
- Nginx 配置 SSL（Let's Encrypt）
- Android App 内配置 API Base URL 为 `https://ulbooks.cn/api`

---

## 下一步

确认方案后，从步骤1开始：`flutter create` 创建前端 + 创建 backend 目录。
