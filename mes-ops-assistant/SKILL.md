---
name: mes-ops-assistant
description: MES 运维助手技能。This skill should be used when 需要对本仓库（MES 制造执行系统，含 mes-api / mes-admin / mes-app / mes-device-link / mes-print-agent / mes-ops 等模块）执行运维类任务：系统健康巡检、日志分析、故障排查、构建部署、数据库迁移脚本编写、数据库查询（查用户/查数据/跑 SQL）、Windows 客户端（设备联机、打印代理）部署升级、多客户环境（prod/dev/test/xichi/xinzhiwei/shenzhen）切换与问题处理。触发场景包括"巡检 MES""看日志""排查报错""部署升级""写数据库脚本""查用户""查数据""跑个 SQL""MES 运维"等表述。
agent_created: true
---

# MES 运维助手

## Overview

本技能用于对本仓库 MES（制造执行系统）进行日常运维与故障处理。它把整个系统的模块结构、技术栈、端口、日志位置、数据库迁移规范、常见故障排查流程沉淀为可复用知识，使任何一次运维任务都能按统一流程执行：先定位模块 → 按对应步骤检查 → 最小化变更 → 记录结果。

## 系统架构速览

仓库根目录 `/Users/wangj_outsourcing/project/mes`，各模块职责与关键技术栈：

| 模块 | 说明 | 技术栈 |
|------|------|--------|
| `mes-api` | 后端服务（核心） | Spring Boot 2.7.18 + MyBatis-Plus + MySQL + WebSocket，默认端口 **7070**，socket 端口 **50000** |
| `mes-admin` | 管理后台前端 | Vue 3 + Element Plus + Vite + Pinia + TypeScript |
| `mes-app` | 移动端/车间 APP | Flutter（Dart），版本见 pubspec.yaml |
| `mes-device-link` | 设备联机助手（Windows 客户端） | .NET 4.7.2 WinForms，监听目录 TXT 解析上传 |
| `mes-print-agent` | 打印代理（Windows 客户端） | .NET 4.7.2 WinForms |
| `mes-ops` | 运维小工具（Windows 客户端，二维码等） | .NET 4.7.2 WinForms |
| `mes-official-site` | 官网静态站 | 静态 HTML/JS |
| `docs/superpowers/` | 设计文档与实施计划 | Markdown |

详细速查（端口、配置文件、日志路径、环境 profile、客户端行为）见 `references/system-map.md`。执行任何任务前，若不确定目标模块，先读该文件确认。

## 运维工作流决策树

收到运维请求后按此树路由：

```
运维请求
├─ 健康巡检 / 状态检查
│   └─ 按「日常巡检」流程执行（可运行 scripts/health_check.sh）
├─ 故障 / 报错排查
│   ├─ 涉及 mes-api     → 先看日志再定位（见「日志分析与故障排查」）
│   ├─ 涉及前端页面     → 查 console 报错 + 对应 API 日志
│   └─ 涉及 Windows 客户端 → 查客户端 logs/error-*.log（见「Windows 客户端」）
├─ 构建 / 发布
│   └─ 按「构建与部署」执行，注意环境模式
├─ 数据库变更
│   ├─ 生产环境        → 一律走 Flyway 风格迁移脚本（见「数据库迁移」）
│   └─ 本地调试        → 可直接执行 SQL，但要先确认目标库
├─ 查询数据 / 查用户 / 跑 SQL
│   └─ 用 scripts/db_query.py 执行只读 SQL（连接参数自动读取 mes-api 配置，见「数据库查询」）
└─ 需求开发 / 文档
    └─ 不属运维范围，按常规开发流程处理
```

## 日常巡检

每次巡检遵循「只读优先，先看后动」原则，不修改任何文件与数据。

1. **仓库状态**：确认工作区在目标分支、无未提交大改动（`git status` 简要查看）。
2. **服务存活**：检查 mes-api 端口 7070 与 socket 端口 50000 是否监听；若本机部署，可运行 `scripts/health_check.sh` 一次性输出端口、进程、磁盘、最近错误日志摘要。
3. **错误日志**：查看 `mes-api` 运行目录下 `logs/`（logback 输出，按天滚动）最近 24 小时内的 `ERROR` / `Exception` 记录，重点过滤 `BusinessException` 之外的异常（数据库连接、OOM、超时、非法参数）。
4. **数据库健康**：确认数据库连接正常、`t_erp_sync_log` 等关键同步/作业表最近状态是否有持续失败（status=2）。
5. **客户端健康**（若现场反馈）：设备联机/打印代理是否在运行、日志是否有持续报错。

巡检结果以简洁报告形式输出：正常项、异常项、建议动作。

## 日志分析与故障排查

- **mes-api 日志位置**：`mes-api` 运行目录 `logs/`，按天滚动；根级别默认 INFO，ERROR 单独可配。配置文件 `logback-spring.xml` 中 `LOG_HOME` 可覆盖。
- **常见错误对照表** 见 `references/runbook.md`，包含：数据库连接失败、端口被占用、OOM、WebSocket 断连、ERP 同步失败、上传/监听失败等场景的「现象 → 排查步骤 → 处理动作」。
- 排查纪律：
  - 先复现/收集错误原文（时间戳 + 堆栈前几行），再判断模块归属；
  - 生产排查默认只读，需要修改（配置/脚本/数据）前先向用户确认并备份；
  - 修改后必须验证（重启服务 / 重新调用接口 / 观察日志），并在结论中写明验证结果。

## 构建与部署

### mes-admin（前端）

```bash
cd mes-admin
pnpm install          # 首次或依赖变更后
pnpm build:pro        # 生产构建（其他模式见 package.json scripts）
```

- 可用构建模式：`build:dev` / `build:test` / `build:pro` / `build:xichi` / `build:xinzhiwei`（多客户环境定制）。
- 发布脚本：`npm run release` = 构建 + `upload_dist.sh` 上传，**执行前确认目标环境与上传配置**。

### mes-api（后端）

```bash
cd mes-api
mvn clean package -DskipTests
java -jar -Dspring.profiles.active=prod target/mes-api.jar   # 环境 profile 见 system-map
```

- profile 由 `application.properties` 中 `spring.profiles.active` 指定，支持 `dev` / `prod` / `shenzhen` 等（对应 `application-{profile}.yml`）。
- 覆盖端口示例：`--server.port=7071`、`--socket.server.port=7071`。
- 发布前确认：数据库迁移脚本是否已按版本顺序就位（见下节）、配置文件中数据源地址/密钥是否正确、日志目录可写。

## 数据库迁移

**规范（强制）**：所有对生产库的结构变更必须写成迁移脚本，放在 `mes-api/src/main/resources/db/upgrade/` 下，命名 `V<主>_<次>_<修订>__<描述>.sql`，版本号在现有最大版本号上递增（现有最高版本见该目录）。脚本内容需幂等（可重复执行不报错），涉及删列/删菜单等破坏性操作时先查引用并列出受影响对象。

- 参考现有示例：`V1_1_4__remove_erp_customer_id_and_menu.sql`（删除列 + 删除菜单及其角色授权）。
- 常用排查/运维 SQL（查询各模块最近记录、同步日志、角色权限等）见 `references/db-guide.md`。
- 写脚本时注意：`DELETE FROM t_sys_role_menu WHERE menu_id = ?` 这类级联清理要先于菜单删除；新脚本落盘后在本机可执行验证。

## 数据库查询

**原则：默认只读。** 查数据、查用户、验证表结构统一用 `scripts/db_query.py`，连接参数自动从 `mes-api/src/main/resources/application-<profile>.yml` 解析（默认 prod，可用 `--profile dev|prod|shenzhen` 切换，也可用环境变量 `DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASS` 覆盖）。

```bash
# 查所有未删除的用户（核心场景）
python3 scripts/db_query.py "SELECT id, username, account, phone, status, user_type, is_builtin, create_time FROM t_sys_users WHERE delete_flag = '0' ORDER BY id"

# 联角色名查看用户
python3 scripts/db_query.py "SELECT u.id, u.username, u.account, r.role_name, u.status FROM t_sys_users u LEFT JOIN t_sys_roles r ON u.role_id = r.id WHERE u.delete_flag = '0' AND r.delete_flag = '0' ORDER BY u.id"

# 其他只读语句同样支持
python3 scripts/db_query.py "SHOW TABLES"
python3 scripts/db_query.py --profile dev "DESCRIBE t_sys_users"
```

- 脚本默认拦截非只读语句（仅放行 SELECT/SHOW/DESC/EXPLAIN/WITH），写操作需人工确认后加 `--force`，运维场景仍应优先走迁移脚本（见「数据库迁移」）。
- 用户表结构、常用查询 SQL 与注意点（逻辑删除字段 `delete_flag` 等）见 `references/db-guide.md` 的「系统用户表」小节。
- 执行环境要求：本机需有 `mysql` 客户端，或 `python3` 可 `import pymysql`（二选一，缺失时脚本会给出安装提示）。
- 结果以表格形式返回；涉及敏感字段（password/salt/token）的列默认不展示，除非用户明确要求。

## Windows 客户端（mes-device-link / mes-print-agent / mes-ops）

三个均为 .NET 4.7.2 WinForms 客户端，部署到车间 Windows 机器（支持 Win7+）：

- **mes-device-link（设备联机）**：监听配置目录下 TXT 文件 → 解析 → 上传 API → 成功后移动到 `{监听路径}/{工单编号}/`。配置 `config.json`（ApiBaseUrl、ApiToken、ListRefreshInterval）。日志：程序目录 `logs/error-{yyyy-MM-dd}.log`，按天滚动。设计细节见 `docs/superpowers/specs/2026-05-18-mes-device-link-design.md`。
- **mes-print-agent（打印代理）**：WinForms，版本号见 csproj，处理打印任务。
- **mes-ops（运维工具）**：WinForms，QRCoder 二维码等工具。
- 升级客户端注意：先确认旧进程已退出（单实例互斥），覆盖 exe/依赖文件，再启动验证；改动 API 地址/Token 需同步现场 `config.json`。

## 安全红线

- 对个人目录（Desktop/Downloads/Documents 等）的扫描/整理/删除操作一律只读报告，不执行任何变更，且需用户明确确认。
- 生产环境禁止未经确认执行 `DELETE` / `DROP` / `TRUNCATE` / `UPDATE`（不带 WHERE）等破坏性语句。
- 不改动他人正在使用的配置文件与数据；排查优先只读。
- `.workbuddy` 目录存放项目数据与记忆，禁止删除。

## Resources

- `scripts/health_check.sh` — 只读巡检脚本：检查端口监听、进程、磁盘、最近错误日志摘要，直接 `bash scripts/health_check.sh` 运行。
- `scripts/db_query.py` — 数据库只读查询脚本：自动读取 mes-api 配置连接 MySQL，执行 SELECT/SHOW 等查询（见「数据库查询」）。
- `references/system-map.md` — 模块、端口、配置文件、环境 profile、日志路径、客户端行为速查表。
- `references/runbook.md` — 常见故障对照表（现象 → 排查 → 处理）。
- `references/db-guide.md` — 数据库迁移规范细则与常用运维 SQL。
