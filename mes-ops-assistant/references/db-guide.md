# MES 数据库迁移规范与常用运维 SQL

## 1. 迁移脚本规范（强制）

- 位置：`mes-api/src/main/resources/db/upgrade/`
- 命名：`V<主>_<次>_<修订>__<英文描述>.sql`，如 `V1_1_4__remove_erp_customer_id_and_menu.sql`
- 版本：在现有目录最大版本号上 +1（先 `ls` 确认，防止撞号）
- 要求：
  - 可重复执行（幂等）：建表用 `CREATE TABLE IF NOT EXISTS`，加列前检查列存在等；
  - 破坏性操作（DROP 列/表、DELETE 行）必须在脚本内注释说明目的，并先清理依赖引用；
  - 涉及菜单删除时，先删角色授权再删菜单：

```sql
-- 删除菜单关联的角色授权
DELETE FROM t_sys_role_menu WHERE menu_id = <menuId>;
-- 再删除菜单本身
DELETE FROM t_sys_menu WHERE id = <menuId>;
```

- 提交前在本机可执行验证（非生产库），确认无语法错误。

## 2. 常用运维 SQL

### 2.1 ERP 同步日志

```sql
-- 最近同步记录
SELECT id, erp_config_id, biz_type, sync_time, status, sync_count, skip_count, error_msg, operator
FROM t_erp_sync_log
ORDER BY sync_time DESC
LIMIT 20;

-- 某业务类型最近一次成功同步时间（增量起点）
SELECT sync_time FROM t_erp_sync_log
WHERE erp_config_id = ? AND biz_type = 'workorder' AND status = 1
ORDER BY sync_time DESC LIMIT 1;
```

### 2.2 ERP 配置

```sql
-- 查看当前生效的 ERP 配置（erp_enabled=1 且未删除）
SELECT id, erp_type, erp_enabled, config_json, remark
FROM t_erp_config
WHERE erp_enabled = 1 AND delete_flag = '0';
```

### 2.3 权限 / 菜单

```sql
-- 查角色拥有的菜单
SELECT * FROM t_sys_role_menu WHERE role_id = ?;
-- 查菜单
SELECT * FROM t_sys_menu WHERE id = ? OR parent_id = ?;
```

### 2.4 系统用户（t_sys_users）

表名 `t_sys_users`（实体 `SysUser`，见 `mes-api/src/main/java/com/nstextile/mes/entity/SysUser.java`），角色表为 `t_sys_roles`。

| 字段 | 说明 |
|------|------|
| id | 主键 |
| username / account | 用户名 / 账号 |
| role_id | 角色 ID，关联 t_sys_roles.id |
| password / salt | 加密密码 / 加盐（敏感，默认不展示） |
| email / phone | 邮箱 / 手机号 |
| status | 用户状态 0=禁用 1=启用 |
| user_type | 用户平台 1=WEB 2=APP 3=仓库大屏（关联 code=016） |
| is_builtin | 是否系统内置 0=否 1=是 |
| delete_flag | 逻辑删除 0=未删 1=已删（**查询必须过滤**） |
| create_time / update_time | 创建 / 更新时间 |

```sql
-- 查询所有未删除用户（核心场景）
SELECT id, username, account, phone, status, user_type, is_builtin, create_time
FROM t_sys_users
WHERE delete_flag = '0'
ORDER BY id;

-- 联角色名查询用户
SELECT u.id, u.username, u.account, r.role_name, u.status, u.user_type
FROM t_sys_users u
LEFT JOIN t_sys_roles r ON u.role_id = r.id
WHERE u.delete_flag = '0' AND r.delete_flag = '0'
ORDER BY u.id;

-- 按状态 / 平台筛选
SELECT id, username, account, status FROM t_sys_users
WHERE delete_flag = '0' AND status = 1 AND user_type = '1';

-- 精确查找（登录名/手机号）
SELECT id, username, account, phone, status FROM t_sys_users
WHERE delete_flag = '0' AND (account = ? OR phone = ?);

-- 排查角色下用户数
SELECT role_id, COUNT(*) AS cnt FROM t_sys_users
WHERE delete_flag = '0' GROUP BY role_id ORDER BY cnt DESC;
```

注意：`password` / `salt` 为敏感字段，日常查询不 SELECT；如需验证登录问题，只在确认授权后查看。

### 2.5 工单

```sql
-- 按工单号查询（upsert 唯一键）
SELECT * FROM t_work_order_info WHERE work_order_no = ?;
```

## 3. 安全提醒

- 任何 `UPDATE` / `DELETE` 必须带 WHERE 并先用 SELECT 确认影响行数；
- 生产库操作前备份相关表或确认存在最近备份；
- 不确定表结构时先 `DESCRIBE <table>;` / `SHOW CREATE TABLE <table>;`。
