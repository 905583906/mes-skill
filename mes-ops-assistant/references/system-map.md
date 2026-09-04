# MES 系统速查表（system-map）

本文件是执行任何 MES 运维任务前的第一参考：确认模块、端口、配置、日志位置。

## 仓库结构

```
/Users/wangj_outsourcing/project/mes/
├── mes-api/              # 后端服务（核心，Spring Boot）
├── mes-admin/            # 管理后台前端（Vue 3 + Element Plus + Vite）
├── mes-app/              # 移动端 APP（Flutter）
├── mes-device-link/      # 设备联机助手（.NET WinForms）
├── mes-print-agent/      # 打印代理（.NET WinForms）
├── mes-ops/              # 运维工具（.NET WinForms，二维码等）
├── mes-official-site/    # 官网静态站
├── docs/superpowers/     # 设计文档（specs/）与实施计划（plans/）
├── git-pull-all.sh       # 一键拉取全部子仓库
├── update.bat            # Windows 更新脚本
└── qa.html               # 车间侧页面/测试页
```

## 后端 mes-api

| 项 | 值 |
|----|----|
| 框架 | Spring Boot 2.7.18，Java，Maven（pom.xml） |
| ORM | MyBatis-Plus（含 join、generator），部分 JPA |
| 数据库 | MySQL（MyBatis-Plus 实体 + `resources/mapper/*.xml`） |
| HTTP 端口 | 7070（`server.port`） |
| Socket 端口 | 50000（WebSocket，`socket.server.port`，可通过启动参数覆盖） |
| Profile | `spring.profiles.active` 默认 `prod`；支持 `dev` / `prod` / `shenzhen`（`application-{profile}.yml`） |
| 启动示例 | `java -jar -Dspring.profiles.active=prod mes-api.jar --socket.server.port=7071` |
| 日志 | `logback-spring.xml` 控制，`logging.path` 默认 `./logs`，按天滚动 |
| 文档 | springdoc-openapi，Swagger UI 可访问 `/v3/api-docs` |
| 数据库迁移 | `src/main/resources/db/upgrade/V*__*.sql`（Flyway 风格命名，按版本序执行） |

## 前端 mes-admin

| 项 | 值 |
|----|----|
| 框架 | Vue 3 + TypeScript + Vite 5 + Element Plus + Pinia |
| 包管理 | pnpm（package.json scripts 均以 `pnpm` 前缀调用） |
| 开发 | `pnpm dev`（`vite --mode base`） |
| 构建 | `pnpm build:pro` 等（mode: dev/test/pro/xichi/xinzhiwei） |
| 发布 | `npm run release` = build + `upload_dist.sh` 上传 |
| 关键目录 | `src/views/`（页面，如 `authorization/sys.vue` 系统设置、`authorization/erpConfig.vue` ERP 配置）、`src/api/`（接口封装，如 `erp/index.ts`） |

## 移动端 mes-app

| 项 | 值 |
|----|----|
| 框架 | Flutter（Dart），版本号在 `pubspec.yaml`（如 2.6.3+263） |
| 依赖 | dio（网络）、get、tdesign_flutter（本地 third_party）、qr_code_scanner（git 源） |
| 构建 | `flutter build apk` / `flutter build ios` 等 |
| 注意 | 依赖 `flutter_app_update` 做应用内更新 |

## Windows 客户端

### mes-device-link（设备联机助手）
- 技术：.NET 4.7.2 WinForms，单实例互斥，托盘常驻。
- 行为：读取 `config.json`（ApiBaseUrl / ApiToken / ListRefreshInterval）→ 开启监听时调用监听 API 拿设备目录列表 → 每个目录一个 FileSystemWatcher → 新 TXT 解析 → 上传 API → 成功移动到 `{监听路径}/{工单编号}/`，失败留原位并记日志。
- 日志：程序目录 `logs/error-{yyyy-MM-dd}.log`（Error 级别，按天滚动）。
- 解析模型：`ParsedLogRecord{Sn, Status, BadInfo, BadPhenomenon}`；列表模型 `DeviceRecord{DeviceCode, ProductionLine, WorkOrderNo, WatchPath}`。
- 设计文档：`docs/superpowers/specs/2026-05-18-mes-device-link-design.md`。

### mes-print-agent（打印代理）
- 技术：.NET 4.7.2 WinForms，版本见 `mes-print-agent.csproj`（如 1.0.12）。
- 职责：接收并执行打印任务。

### mes-ops（运维工具）
- 技术：.NET 4.7.2 WinForms，引用 QRCoder 1.4.3（二维码生成）与 System.Management（硬件信息）。
- 职责：现场运维辅助工具。

## 部署默认约定

以下为通用默认约定（不针对某台具体机器，供无更具体信息时参考；已知某现场有更具体的配置时以现场实际配置为准，如 deploy.ps1 用 nginx-1.28.0、application-*.yml 里 logging.path 默认 `./logs` 相对路径）：

| 项 | 默认值 |
|----|--------|
| 日志目录 | `/logs` |
| nginx 版本 | nginx-1.26.2 |

## 常用端口汇总

| 端口 | 用途 |
|------|------|
| 7070 | mes-api HTTP |
| 50000 | mes-api WebSocket/socket |
| 7071 | 示例：多实例/负载时覆盖 socket 端口 |

## 环境 profile 速查

| Profile | 用途 |
|---------|------|
| dev | 本地开发（application-dev.yml，端口 7070） |
| prod | 生产（application-prod.yml，默认） |
| shenzhen | 深圳客户环境（application-shenzhen.yml） |
| xichi / xinzhiwei | 前端构建模式（多客户定制，见 mes-admin scripts） |
