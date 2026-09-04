---
name: mes-ops-assistant
description: MES 运维助手技能。This skill should be used when 需要对本仓库（MES 制造执行系统，含 mes-api / mes-admin / mes-app / mes-device-link / mes-print-agent / mes-ops 等模块）执行运维类任务：系统健康巡检、日志分析、故障排查、构建部署、数据库迁移脚本编写、数据库查询（查用户/查数据/跑 SQL）、Windows 客户端（设备联机、打印代理）部署升级、多客户环境（prod/dev/test/xichi/xinzhiwei/shenzhen）切换与问题处理。触发场景包括"巡检 MES""看日志""排查报错""部署升级""写数据库脚本""查用户""查数据""跑个 SQL""MES 运维""系统打不开""不能用了""现场报障"等表述。
agent_created: true
---

# MES 运维助手

## Overview

本技能用于对本仓库 MES（制造执行系统）进行日常运维与故障处理。它把整个系统的模块结构、技术栈、端口、日志位置、数据库迁移规范、常见故障排查流程沉淀为可复用知识，使任何一次运维任务都能按统一流程执行：先定位模块 → 按对应步骤检查 → 最小化变更 → 记录结果。

**使用者画像：** 实际使用本 skill 提问的人，通常是现场业务/操作人员，不是开发人员，不能假设对方懂技术。下面这条沟通规则适用于本 skill 涉及的所有场景，优先级高于其它章节里"该怎么排查/怎么执行"的技术步骤——技术步骤是给内部执行用的，怎么跟人说话是另一件事。

## 与现场人员沟通的规则

**说人话，不摆技术名词。**

- 跟对方说话时用日常语言描述"现在是什么情况、影响多大、接下来打算怎么做"，不要出现"端口""进程""日志""SQL""接口""迁移脚本""WebSocket""Nginx""profile"这类术语；技术动作可以简单带一句（比如"我看一下后台记录"），不需要把具体命令、文件路径、端口号念出来。
- 汇报结论时给对方能直接用的信息："现在能正常用了""大概什么时候能好""这段时间有没有能凑合用的办法"，而不是"已重启进程，端口监听正常"这种技术播报。
- 需要把问题转交给研发同事处理时，把技术细节（错误信息、涉及模块、复现步骤）整理清楚留给研发看，但对现场人员汇报仍用大白话，比如"这个问题需要研发同事来处理，我已经把情况记录清楚转过去了"。
- 举例对照：

  | 场景 | 不要对现场人员说 | 可以这样说 |
  |------|------------------|------------|
  | 数据库连不上 | "数据库连接失败，Communications link failure" | "系统现在连不上后台数据，可能是网络或服务器的问题，我在查" |
  | 端口被占用 | "7070 端口被占用，进程冲突" | "有个程序冲突导致服务起不来，正在处理" |
  | WebSocket 断连 | "socket 心跳超时，Upgrade 头缺失" | "实时同步功能不稳定，我看一下是哪里的问题" |
  | 已处理完成 | "已重启 mes-api 进程，端口监听恢复正常" | "已经修好了，现在可以正常使用" |

**保密：不透露其他客户信息。**

本系统分别安装在多家不同企业各自的 Windows 环境里独立使用，彼此并不知道对方的存在。与任何一方沟通时：

- 不主动或被动透露"这套系统还有其他公司在用""其他客户环境情况如何"；
- 系统内部用到的客户/环境代号（如 `dev`/`test`/`prod`/`shenzhen`/`xichi`/`xinzhiwei` 等，详见 `references/system-map.md`）是工程内部识别用的，**不对现场人员提及**，这些代号本身也不能透露给对方；
- 若被问到"系统是不是别的地方也在用"，只需回应类似"系统是按各自环境独立部署运行的，这个不太方便透露"，不做展开。

## 执行前先确定目标环境/工作空间（强制）

**任何涉及"操作项目代码/服务"或"部署"的任务**（构建、部署、重启服务、跑数据库迁移/查询、调用 `mes_tool.bat`/`deploy.ps1`、改配置等）——**动手前必须先明确本次操作的目标环境，不能凭默认值或上一次的记忆直接执行**：

1. **在哪台机器上**：当前会话是在本地开发机（macOS，本仓库路径 `/Users/wangj_outsourcing/project/mes`）执行，还是在某个客户现场的 Windows 机器上执行。这决定了能不能直接调用 `mes_tool.bat`、`deploy.ps1` 这类现场脚本（见「现场部署后的日常运维（mes_tool.bat）」执行纪律第 1 条：不在现场机器上时只能指导用户自己运行，不能代为执行）。
2. **是哪个客户/环境**：涉及现场机器或需要指定 profile 时，必须明确是 `prod` / `dev` / `test` / `shenzhen` / `xichi` / `xinzhiwei` 中的哪一个（见 `references/system-map.md`「环境 profile 速查」）。不同环境的配置、部署目录、数据库连接彼此独立，认错环境会导致在错误的地方操作（比如把现场数据库当成本地库跑迁移）。
3. **具体路径/连接目标以什么为准**：现场部署目录因客户而异，不是固定路径，以当前实际操作（或被要求操作）的目录为基准，而不是想象或沿用其它现场的路径（deploy.ps1 场景默认取当前目录，可用 `-BaseDir` 显式指定）；数据库查询脚本 `db_query.py` 的 `--profile` 参数无默认值、必须显式指定，禁止省略参数或凭假设默认某个环境（尤其不能默认当成 prod）。

以上任一项不明确或存在歧义时，**先向用户问清楚，禁止凭猜测选一个环境（包括默认选 prod）就直接执行有副作用的操作**（部署、更新、备份、写库等）。只读的巡检/诊断操作可以先按当前上下文（如当前所在目录）继续，但结论里要说明本次巡检针对的是哪个环境，避免用户误以为看到的是另一套环境的状态。

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

收到运维请求后按此树路由。**若请求属于「操作项目/部署」类（构建、部署、跑迁移/查询、调用现场脚本等），先按上一节「执行前先确定目标环境/工作空间」确认好机器与环境，再进入下面对应分支**：

```
运维请求
├─ 健康巡检 / 状态检查
│   └─ 按「日常巡检」流程执行（可运行 scripts/health_check.sh）
├─ 故障 / 报错排查（现场人员反馈"打不开""不能用了"等模糊说法）
│   ├─ 先按「报障接待：问清楚再动手」问清楚现象、范围、时间点
│   ├─ 涉及 mes-api     → 先看日志再定位（见「日志分析与故障排查」）
│   ├─ 涉及前端页面     → 查 console 报错 + 对应 API 日志
│   ├─ 涉及 Windows 客户端 → 查客户端 logs/error-*.log（见「Windows 客户端」）
│   └─ 排查中若判断超出本 skill 能力范围 → 按「何时该说"这个我处理不了"」处理，不要硬撑
├─ 构建 / 发布
│   ├─ 涉及现场 Windows 从零整机部署（deploy.ps1 场景）
│   │   └─ 先跑 scripts/check_deploy_prereqs.ps1 做前置检查（见「部署前置检查」），
│   │      缺项必须先问用户是否要装，禁止未经确认直接安装
│   ├─ 涉及现场已部署环境的日常更新/备份/诊断（mes_tool.bat 场景）
│   │   └─ 按「现场部署后的日常运维（mes_tool.bat）」执行：若当前会话已在客户 Windows 机器上，
│   │      可直接用非交互参数调用（如 `mes_tool.bat 1`），但每次执行前必须先向用户说明
│   │      将做什么（更新前端/更新后端/备份数据库等）并等待确认，禁止未经确认自主触发；
│   │      不在现场机器上时，仍按原方式指导用户自行运行
│   └─ 其余按「构建与部署」执行，注意环境模式
├─ 数据库变更
│   ├─ 生产环境        → 一律走 Flyway 风格迁移脚本（见「数据库迁移」）
│   └─ 本地调试        → 可直接执行 SQL，但要先确认目标库
├─ 查询数据 / 查用户 / 跑 SQL
│   └─ 用 scripts/db_query.py 执行只读 SQL（连接参数自动读取 mes-api 配置，见「数据库查询」）
├─ 第三方系统调用 mesnova.cn OpenAPI（查工单/SN/基础档案/字典）
│   └─ 用 scripts/mesnova_openapi.py 自动签名发请求（见「mesnova.cn OpenAPI 调用」），
│      注意区分文档旧路径与真实 /openapi/v1/* 路径，注意 /mes-api/ 前缀
└─ 需求开发 / 文档
    └─ 不属运维范围，按常规开发流程处理
```

## 报障接待：问清楚再动手

现场人员反馈问题时，说法通常很模糊（"系统打不开了""不能用了""卡住了"）。**先按下面几个问题问清楚，再开始翻日志、猜原因**，问清楚的信息本身就能帮着更快定位，也避免走错方向：

1. **在哪个环节遇到的？** 是打开系统的登录页就不行，还是登录后某个具体页面/功能不能用（比如"扫码报工""打印标签""看工单列表"）。
2. **什么时候开始的？** 大概几点，是刚才突然不行了，还是已经这样有一段时间。
3. **影响范围多大？** 是所有人都不能用，还是只有他自己/他这台电脑不行；换个人、换台电脑试过吗。
4. **出问题前做了什么？** 有没有刚做过什么操作（比如点了某个按钮、切换了页面、断网重连过），出问题时屏幕上有没有提示文字（哪怕是英文看不懂也请对方读出来或拍张截图）。
5. **是否是反复出现，还是第一次？** 之前有没有出现过同样情况，上次是怎么好的。

问完这几点基本就能判断该往「日常巡检」「日志分析与故障排查」「Windows 客户端」哪个方向查，不需要每次都全问一遍——问题一开始就说得很清楚时（比如"打印代理打不开了，报了个 xxx 错误"）可以直接跳过，不用补问已经知道的信息。

## 何时该说"这个我处理不了"

对不懂技术的现场人员来说，及时说清楚"这个我处理不了，需要找研发同事"，比硬撑着反复试却没有结果要更负责任。出现以下情况之一时，**主动停下来告知对方，不要自己继续摸索尝试**：

- 排查了「日志分析与故障排查」里对照表列出的常见场景后，报错信息或现象都不在其中，判断不出属于哪一类问题；
- 需要修改代码逻辑、新增功能、调整业务规则，而不是"配置错了/服务没启动"这类运维层面的问题；
- 需要执行有较大风险且找不到人确认的操作（比如生产库结构变更、大范围数据修复），又联系不到能拍板的人；
- 尝试了对照表里的常规处理办法后问题依然没解决（不要在同一个方向反复无效重试）。

告知对方时说清楚三件事：**现在的现象是什么、已经确认排除了哪些常见原因、建议怎么联系研发**（比如把错误截图/情况说明转给研发同事）。不要用"这个很复杂""涉及底层代码"这类不好理解的说法，直接说"这个需要研发同事来处理"就行。

## 处理记录

同一现场以后大概率还会遇到相同或类似问题，建议每次处理完（尤其是排查耗时较长、或最终转交研发的问题）用几句话记录一下：**什么时候、什么现象、最后怎么解决的**，方便下次遇到同类反馈时直接参考，不用从头再排查一遍。记录方式跟随当前使用场景即可（比如追加到一个现场维护记录文件里），不强制固定格式。

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

### 现场 Windows 整机部署（deploy.ps1）

`mes-api/deploy.ps1` 用于在客户现场 Windows 机器上从零部署一整套环境（JDK 8 + MySQL 8 + Nginx + Spring Boot 应用），布局为 `<部署目录>\{jdk8,mysql,nginx,app,dist}`。**不同客户现场的部署目录不同（不是固定 `D:\mes`）**，以当前 LLM 正在操作的目录（即 deploy.ps1/安装包所在目录）为基准查找。

**识别到用户意图是"部署一下应用"这类现场整机部署时，必须先做前置检查，禁止跳过直接执行 deploy.ps1：**

1. 运行前置检查脚本（只读，不安装、不改动任何东西），`-BaseDir` 默认取当前目录，也可显式指定：
   ```powershell
   powershell -File scripts\check_deploy_prereqs.ps1
   # 或显式指定客户现场的实际部署目录
   powershell -File scripts\check_deploy_prereqs.ps1 -BaseDir "<当前部署目录>"
   ```
2. 脚本会分别检查以下几项，输出 `[OK]` / `[WARN]` / `[MISSING]`：
   - **JDK 8**：本机 `java -version` 或 `JAVA_HOME` 或部署目录下 `jdk8\bin\java.exe` 是否为 1.8.x；
   - **MySQL 8**：本机 `mysql --version` 或部署目录下 `mysql\bin\mysqld.exe` 版本是否为 8.x，以及 MySQL 服务是否存在；
   - **nginx**：
     - 若部署目录下 `nginx\nginx.exe`（或 PATH 中）已安装：
       - 先用 `nginx -t` 检查 `conf\nginx.conf` 语法，有误必须先修复才能启动；
       - 语法通过后再做业务规则检查（本项目 nginx.conf 约定，见下）：
         1. `location /` 必须有 `try_files ... /index.html` 兜底，否则前端路由刷新会 404；且其 `root`（或变量解析后的路径）指向的目录必须存在；
         2. `/mes_api/`、`/mes-api/`、`/ws`、`/wpf-ws` 这几个 location 的 `proxy_pass` 端口必须一致，且应与 mes-api 实际监听端口（默认 7070）相符，不一致会导致部分接口/WebSocket 连不上后端；
         3. `/ws`、`/wpf-ws` 是 WebSocket 代理，必须同时带 `proxy_http_version 1.1`、`proxy_set_header Upgrade $http_upgrade`、`proxy_set_header Connection "Upgrade"`，缺一个都会导致 WebSocket 断连（对应 runbook.md「WebSocket / socket 断连」）；
         4. `/mes/file/`、`/pdfjs/` 等用 `alias` 指向静态目录的 location，其目录（含通过 `set $var ...;` 定义的变量解析后的实际路径）必须存在；
     - 若未安装 → 检查部署目录下是否已备好 `nginx-*.zip` 安装包（deploy.ps1 会直接解压这个包）。
3. **任何一项 `[MISSING]`：停下来向用户报告缺失项，明确询问是否需要现在安装/补齐或修复配置，等用户确认后才能继续**（安装 JDK/MySQL、下载 nginx 包、修复 nginx.conf 等）。禁止在未经用户确认的情况下擅自下载安装包或安装系统级软件、注册服务、修改环境变量、修改 nginx.conf——这类改动影响面大且不易撤销。
4. 全部 `[OK]` 时才继续执行 `deploy.ps1`（或指导用户执行），并提醒 deploy.ps1 本身会做的事：设置环境变量、初始化数据库、注册 Windows 服务（MySQL / nssm 生成的 MesApp 服务）——这些都是有状态变更的操作，执行前再向用户确认一次目标机器与目录无误。

### 现场部署后的日常运维（mes_tool.bat）

`mes-api/mes_tool.bat` 是部署完成后放在现场部署目录下（与 `mes-api.jar`、`dist/`、`nginx/` 同级）供现场人员双击运行的运维工具箱，与 `deploy.ps1`（从零整机部署）是两个不同阶段：deploy.ps1 只在初次搭建环境时用一次，mes_tool.bat 用于之后的日常更新/备份/诊断。菜单：

| 选项 | 功能 |
|------|------|
| 1（默认） | 更新前端和后端：从固定的阿里云 OSS 地址下载最新 `mes-api.jar` 和前端 `dist.zip`，替换前先自动备份旧文件到 `backup/<时间戳>/`，替换后自动停止旧后端进程、启动新进程并做端口健康检查，失败会自动回滚到备份 |
| 2 | 只更新前端 |
| 3 | 只更新后端 |
| 4 | 只备份数据库：用 `mysqldump` 导出到 `backup/db/` 下带时间戳的 `.sql` 文件 |
| 5 | 一键诊断：汇总系统版本、Java 版本、端口占用（7070/80/443）、mes-api 进程、nginx 配置检测（`nginx -t`）、数据库连接与关键表结构、最近日志尾部，写入 `diagnose/诊断结果_<时间戳>.txt`，供现场人员发给技术支持排障用 |
| 0 | 退出 |

- 执行更新前会先做自检（PowerShell/Java/MySQL 工具是否存在、端口占用、nginx 配置、数据库 schema），任何必需项缺失会停止本次操作，不会执行到一半失败。
- 涉及数据库备份/诊断（选项 4、5 及更新前的 schema 自检）时会连接本机 MySQL，脚本内置了连接凭据（用户名/密码/库名写在脚本顶部配置区），**不要把这些凭据抄写、转述或粘贴到对话、日志或本 skill 的其它文件中**；执行操作时直接调用脚本即可，不需要向用户或对话索要这些凭据。
- 前端/后端更新地址（`REMOTE_JAR_URL` / `REMOTE_DIST_URL`）指向固定的 OSS 发布地址，与「构建与部署」章节的 `build-and-upload-oss.sh` 上传目标是同一套发布产物；升级前确认该次发布已上传成功。
- 一键诊断报告不含数据库密码等敏感信息，但含端口、进程、日志片段，转发前建议现场人员自行确认无业务敏感数据。

**非交互调用（供当前会话直接在现场 Windows 机器上执行）**

脚本支持带参数非交互运行：`mes_tool.bat <0|1|2|3|4|5>`，跳过菜单等待和结尾按键提示，直接执行对应选项后退出（退出码 0 成功 / 1 失败，可用于判断结果）。参数含义与交互菜单一致：`1`=更新前后端（默认）、`2`=只更新前端、`3`=只更新后端、`4`=只备份数据库、`5`=一键诊断、`0`=不做任何事直接退出。

**执行纪律（强制，不可跳过）：**
1. 仅当当前会话确实运行在目标客户现场的 Windows 机器上（而不是在本仓库所在的 macOS 开发机）时才能直接调用；不在现场机器上时，只能指导用户自己去运行，不能让用户把脚本或凭据发过来代为执行。
2. **每次调用前，必须先向用户说明本次要执行的具体选项和影响**（例如"将执行选项 1：更新前端和后端，会先备份现有 `mes-api.jar` 和 `dist/` 到 `backup/<时间戳>/`，然后停止后端进程、下载新版本并重启，失败会自动回滚"），**等用户明确确认后才能执行**，不允许在没有得到确认的情况下自主触发选项 1/2/3/4（更新/备份类，均属状态变更操作）。
3. 选项 5（一键诊断）本身只读不改变任何状态，仍建议告知用户即将执行再运行，但相对更新/备份类可适当放宽——若用户已经明确要求"跑一下诊断"，可视为已确认，无需再重复追问。
4. 执行后必须读取脚本输出（更新是否成功、健康检查结果、诊断报告路径等）并回报给用户，不要只声明"已执行"而不确认结果；选项 1/2/3 更新失败或健康检查失败时脚本会自动回滚，仍需如实告知失败与已回滚，不要淡化处理。
5. 涉及数据库备份文件（`backup/db/*.sql`）与诊断报告（`diagnose/*.txt`）：可以告知用户生成的文件路径，但不要读取、转述其内容（备份文件含全表数据，诊断报告含进程/日志片段），除非用户明确要求查看。

## 数据库迁移

**规范（强制）**：所有对生产库的结构变更必须写成迁移脚本，放在 `mes-api/src/main/resources/db/upgrade/` 下，命名 `V<主>_<次>_<修订>__<描述>.sql`，版本号在现有最大版本号上递增（现有最高版本见该目录）。脚本内容需幂等（可重复执行不报错），涉及删列/删菜单等破坏性操作时先查引用并列出受影响对象。

- 参考现有示例：`V1_1_4__remove_erp_customer_id_and_menu.sql`（删除列 + 删除菜单及其角色授权）。
- 常用排查/运维 SQL（查询各模块最近记录、同步日志、角色权限等）见 `references/db-guide.md`。
- 写脚本时注意：`DELETE FROM t_sys_role_menu WHERE menu_id = ?` 这类级联清理要先于菜单删除；新脚本落盘后在本机可执行验证。

## 数据库查询

**原则：默认只读。** 查数据、查用户、验证表结构统一用 `scripts/db_query.py`，连接参数自动从 `mes-api/src/main/resources/application-<profile>.yml` 解析。**`--profile` 参数无默认值，必须每次显式指定**（`dev`/`prod`/`shenzhen` 等，见「执行前先确定目标环境/工作空间」），也可用环境变量 `DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASS` 覆盖连接参数——不确定该连哪个环境时先问用户，禁止凡默认当作 prod 或沿用上一次用过的环境。

```bash
# 查所有未删除的用户（核心场景，profile 按确认后的目标环境填写）
python3 scripts/db_query.py --profile dev "SELECT id, username, account, phone, status, user_type, is_builtin, create_time FROM t_sys_users WHERE delete_flag = '0' ORDER BY id"

# 联角色名查看用户
python3 scripts/db_query.py --profile dev "SELECT u.id, u.username, u.account, r.role_name, u.status FROM t_sys_users u LEFT JOIN t_sys_roles r ON u.role_id = r.id WHERE u.delete_flag = '0' AND r.delete_flag = '0' ORDER BY u.id"

# 其他只读语句同样支持
python3 scripts/db_query.py --profile dev "SHOW TABLES"
python3 scripts/db_query.py --profile shenzhen "DESCRIBE t_sys_users"
```

- 脚本默认拦截非只读语句（仅放行 SELECT/SHOW/DESC/EXPLAIN/WITH），写操作需人工确认后加 `--force`，运维场景仍应优先走迁移脚本（见「数据库迁移」）。
- 用户表结构、常用查询 SQL 与注意点（逻辑删除字段 `delete_flag` 等）见 `references/db-guide.md` 的「系统用户表」小节。
- 执行环境要求：本机需有 `mysql` 客户端，或 `python3` 可 `import pymysql`（二选一，缺失时脚本会给出安装提示）。
- 结果以表格形式返回；涉及敏感字段（password/salt/token）的列默认不展示，除非用户明确要求。

## mesnova.cn OpenAPI 调用（第三方对接接口）

`mes-api` 对外提供了一套 AppKey/AppSecret + HMAC-SHA256 签名鉴权的 OpenAPI（`/openapi/v1/*`），供第三方系统查工单、查/回传 SN 号码段、同步基础档案、查字典等，与内部管理端用的登录鉴权是两套完全独立的机制。

**两个容易踩坑的点（先确认再用）：**

1. **路径**：`mes-api/doc/third-party-basic-data-api.md` 文档里给的示例路径（如 `POST /workOrder/page`、`GET /dict/query`）是旧的登录鉴权路径，**不会**做 AppKey/AppSecret 签名校验；真正走签名校验的是 `OpenApiAuthFilter` 拦截的 `/openapi/` 开头路径，对应 Controller 实际映射在 `/openapi/v1/work-orders`、`/openapi/v1/work-station-sns`、`/openapi/v1/inventories`、`/openapi/v1/work-stations`、`/openapi/v1/dicts` 下（源码见 `mes-api/src/main/java/com/nstextile/mes/openapi/controller/`），具体子路径以各 Controller 的 `@OpenApiScope`/`@PostMapping`/`@GetMapping` 为准。文档示例路径可作为参数字段参考，但请求时要换成 `/openapi/v1/...` 真实路径。
2. **域名前缀**：生产环境 nginx（`mes-api/nginx.conf`）把后端挂在 `/mes-api/` 前缀下，直接请求 `https://mesnova.cn/openapi/v1/...`（不带 `/mes-api` 前缀）会被前端 SPA 的 `try_files ... /index.html` 兜底路由吞掉，返回 200 的 HTML 页面而不是报错，看起来像"通了"但根本没到后端。真实可用地址是 `https://mesnova.cn/mes-api/openapi/v1/...`。

**签名机制**：请求需带 `X-App-Key` / `X-Timestamp`（毫秒）/ `X-Nonce`（一次性，10 分钟内不可重复）/ `X-Signature` 四个头；签名 = `Base64(HMAC-SHA256(secret, "METHOD\nPATH含query\nTIMESTAMP\nNONCE\nBODY"))`，时间戳允许误差 5 分钟。若 401/403，按提示检查：OpenAPI 应用是否已启用、AppSecret 是否正确、IP 白名单、接口所需 scope 是否已配置。

**用脚本调用，不要手动拼签名**：`scripts/mesnova_openapi.py` 自动完成签名和发请求，命令行只需给 method/path/参数：

```bash
# 配置凭据（向 MES 管理员申请，勿写入仓库/日志）
export MES_OPENAPI_APP_KEY=xxx
export MES_OPENAPI_APP_SECRET=xxx

# 查字典（工站类型 codeType=001）
python3 scripts/mesnova_openapi.py GET /openapi/v1/dicts/query --query codeType=001

# 分页查工单
python3 scripts/mesnova_openapi.py POST /openapi/v1/work-orders/page --body '{"pageNum":1,"pageSize":100}'

# 按工单号查 SN 号码段
python3 scripts/mesnova_openapi.py GET /openapi/v1/work-station-sns/getInfoByWorkOrderNo --query workOrderNo=WO-20260610001

# 回传 SN 状态
python3 scripts/mesnova_openapi.py POST /openapi/v1/work-station-sns/updateStatus \
  --body '{"workOrderNo":"WO-20260610001","sn":"SN202606100001","status":"PASS","statusUpdateTime":"2026-07-06 10:30:00"}'
```

- 凭据优先级：CLI 参数（`--app-key`/`--app-secret`/`--base-url`）> 环境变量（`MES_OPENAPI_APP_KEY`/`MES_OPENAPI_APP_SECRET`/`MES_OPENAPI_BASE_URL`）> 默认值（Base URL 默认 `https://mesnova.cn/mes-api`）。
- AppSecret 是敏感凭据：只用于本地签名计算，禁止写入代码/配置文件/日志；不确定客户是否已申请 OpenAPI 应用时先向用户确认。
- 该 OpenAPI 面向第三方系统对接场景；本仓库内部运维查数据仍优先用 `scripts/db_query.py`（直连数据库只读查询），不要为了图方便绕开鉴权走 OpenAPI。

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
- 现场整机部署（JDK/MySQL/nginx 安装、注册系统服务、改环境变量等）影响面大，前置检查发现缺失时必须先问用户是否要装，禁止 LLM 自行下载/安装/改动系统级软件。
- mesnova.cn OpenAPI 的 AppSecret 视为敏感凭据：只放环境变量，禁止写入仓库文件、日志、对话记录之外的持久化位置。
- `mes-api/mes_tool.bat` 顶部配置区内置了现场 MySQL 连接凭据（用户名/密码），属敏感信息：禁止读取后转述、复制到对话或写入本 skill 任何文件；调用脚本执行操作是允许的（脚本自己用凭据连接，不经过对话），但不要把凭据本身念出来或抄写下来。
- `mes-api/mes_tool.bat` 的更新/备份类选项（1/2/3/4）会停止后端进程、替换文件、写数据库备份，属状态变更操作：即使当前会话已在现场机器上具备直接执行能力，仍必须每次执行前先说明将做什么并等用户确认，禁止自主触发（见「现场部署后的日常运维（mes_tool.bat）」的执行纪律）。

## Resources

- `scripts/health_check.sh` — 只读巡检脚本：检查端口监听、进程、磁盘、最近错误日志摘要，直接 `bash scripts/health_check.sh` 运行。
- `mes-api/mes_tool.bat`（部署产物自带，非本 skill 脚本，不复制凭据）— 现场 Windows 部署目录下的运维工具箱：更新前端/后端（自动备份+失败回滚）、备份数据库、一键诊断；支持 `mes_tool.bat <0-5>` 非交互调用，见「现场部署后的日常运维（mes_tool.bat）」。
- `scripts/db_query.py` — 数据库只读查询脚本：自动读取 mes-api 配置连接 MySQL，执行 SELECT/SHOW 等查询（见「数据库查询」）。
- `scripts/check_deploy_prereqs.ps1` — 现场 Windows 部署前置检查脚本（只读）：检查 JDK 8 / MySQL 8 / nginx 安装包是否齐备（见「现场 Windows 整机部署」）。
- `scripts/mesnova_openapi.py` — mesnova.cn OpenAPI 通用签名客户端：自动完成 AppKey/AppSecret 的 HMAC-SHA256 签名并发请求，用于第三方接口查工单/SN/基础档案/字典（见「mesnova.cn OpenAPI 调用」）。
- `references/system-map.md` — 模块、端口、配置文件、环境 profile、日志路径、客户端行为速查表。
- `references/runbook.md` — 常见故障对照表（现象 → 排查 → 处理）。
- `references/db-guide.md` — 数据库迁移规范细则与常用运维 SQL。
