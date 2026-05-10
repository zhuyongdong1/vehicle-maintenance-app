-- 车辆维修管理系统数据库 Schema

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS vehicle_maintenance DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE vehicle_maintenance;

-- 分类表（客户可自定义）
CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type VARCHAR(30) NOT NULL COMMENT '分类类型: maintenance_type/ledger_income/ledger_expense',
    name VARCHAR(50) NOT NULL COMMENT '分类名称',
    sort_order INT DEFAULT 0 COMMENT '排序',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 默认分类数据
INSERT IGNORE INTO categories (type, name, sort_order) VALUES
('maintenance_type', '保养', 1),
('maintenance_type', '机修', 2),
('maintenance_type', '电路', 3),
('maintenance_type', '钣金', 4),
('maintenance_type', '喷漆', 5),
('maintenance_type', '轮胎', 6),
('maintenance_type', '其他', 7),
('ledger_income', '维修收入', 1),
('ledger_income', '配件销售', 2),
('ledger_income', '其他收入', 3),
('ledger_expense', '配件采购', 1),
('ledger_expense', '工具设备', 2),
('ledger_expense', '房租', 3),
('ledger_expense', '水电', 4),
('ledger_expense', '工资', 5),
('ledger_expense', '其他支出', 6);

-- 库存配件表
CREATE TABLE IF NOT EXISTS inventory_items (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL COMMENT '配件名称',
    category VARCHAR(50) COMMENT '配件分类',
    sku VARCHAR(50) COMMENT '配件编码',
    unit VARCHAR(20) DEFAULT '件' COMMENT '单位',
    stock_quantity INT NOT NULL DEFAULT 0 COMMENT '当前库存',
    warning_quantity INT NOT NULL DEFAULT 5 COMMENT '预警库存',
    purchase_price DECIMAL(10,2) DEFAULT 0 COMMENT '进货价',
    sale_price DECIMAL(10,2) DEFAULT 0 COMMENT '销售价',
    supplier VARCHAR(100) COMMENT '供应商',
    location VARCHAR(100) COMMENT '库位',
    notes TEXT COMMENT '备注',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_inventory_sku (sku)
);

-- 车辆表
CREATE TABLE IF NOT EXISTS vehicles (
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
    deleted_at DATETIME NULL COMMENT '档案删除时间，软删除保留历史工单',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 维修记录表
CREATE TABLE IF NOT EXISTS records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_id INT NOT NULL COMMENT '车辆ID',
    category_id INT COMMENT '维修分类ID',
    status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '工单状态: pending/repairing/completed/settled',
    items TEXT COMMENT '维修项目',
    cost DECIMAL(10,2) COMMENT '售价合计',
    purchase_cost DECIMAL(10,2) COMMENT '进价合计',
    mileage INT COMMENT '里程数(km)',
    record_date DATE COMMENT '维修日期',
    workshop VARCHAR(100) COMMENT '维修厂',
    notes TEXT COMMENT '备注',
    parts TEXT COMMENT '配件清单',
    fee_items TEXT COMMENT '费用明细JSON',
    reminder_date DATE COMMENT '下次保养提醒日期',
    reminder_mileage INT COMMENT '下次保养提醒里程',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- 记账表
CREATE TABLE IF NOT EXISTS ledger (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type ENUM('income', 'expense') NOT NULL COMMENT '类型：收入/支出',
    category_id INT COMMENT '记账分类ID',
    amount DECIMAL(10,2) NOT NULL COMMENT '金额',
    record_date DATE NOT NULL COMMENT '日期',
    description TEXT COMMENT '说明',
    related_record_id INT COMMENT '关联维修记录ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- 库存出入库流水表
CREATE TABLE IF NOT EXISTS inventory_transactions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    item_id BIGINT NOT NULL COMMENT '配件ID',
    type ENUM('in', 'out', 'adjust') NOT NULL COMMENT '类型：入库/出库/调整',
    quantity INT NOT NULL COMMENT '变动数量',
    unit_price DECIMAL(10,2) DEFAULT 0 COMMENT '单价',
    related_record_id INT COMMENT '关联工单ID',
    operator VARCHAR(50) COMMENT '操作人',
    notes TEXT COMMENT '备注',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES inventory_items(id) ON DELETE CASCADE,
    FOREIGN KEY (related_record_id) REFERENCES records(id) ON DELETE SET NULL
);
