# MES 故障排查手册（runbook）

排查纪律：先收集错误原文（时间戳 + 堆栈前几行）→ 判断模块归属 → 只读排查 → 需要变更时先备份并确认 → 修复后必须验证并记录结果。

## 1. 后端 mes-api

### 1.1 服务启动失败 / 端口被占用
- 现象：启动日志报 `Port already in use` 或 `BindException`。
- 排查：
  1. `lsof -i :7070`（macOS/Linux）或 `netstat -ano | findstr 7070`（Windows）确认占用进程；
  2. 若为残留旧进程，确认业务已停后结束该进程；
  3. 若需同机多实例，用 `--server.port=7071 --socket.server.port=7071` 覆盖。
- 处理：释放端口或覆盖端口后重启。

### 1.2 数据库连接失败
- 现象：日志报 `Communications link failure` / `Access denied` / `Connection refused`。
- 排查：
  1. 确认当前 profile（`application-{profile}.yml` 中 datasource url/username/password）；
  2. 从应用机器 `telnet <dbhost> <port>` 验证网络与端口；
  3. 确认 MySQL 服务存活、账号权限、白名单（bind-address / 防火墙）。
- 处理：修正配置或网络后重启；生产修改配置前先备份原文件。

### 1.3 OOM / 内存不足
- 现象：`java.lang.OutOfMemoryError`（Heap / Metaspace），进程被杀。
- 排查：看日志附近是否有大批量查询/循环写入；检查 JVM 启动参数（Xmx）。
- 处理：临时调大堆内存并观察；长期需定位内存泄漏（大列表、未释放的 WebSocket 会话等），必要时导出 heap dump 分析。

### 1.4 WebSocket / socket 断连
- 现象：客户端频繁掉线，日志报 `socket` 相关超时或异常。
- 排查：确认 `socket.server.port`（默认 50000）未被占用、负载均衡/防火墙是否配置长连接超时（如 60s 空闲断开）。
- 处理：配置心跳/重连；调整代理超时或保活参数。

### 1.5 ERP 同步失败
- 现象：`t_erp_sync_log` 出现 status=2 记录，或同步按钮报错。
- 排查：
  1. 查最近同步日志与 error_msg：`SELECT * FROM t_erp_sync_log ORDER BY sync_time DESC LIMIT 20;`
  2. 确认 `t_erp_config` 配置（erp_enabled=1）与 ERP 侧服务可用；
  3. Token 缓存问题：TokenManager 内存缓存过期自动重登，重启应用即重置，无需持久化处理。
- 处理：按错误码修复 ERP 配置或网络；单条工单解析失败会跳过并记日志，属预期行为。
- 参考设计：`docs/superpowers/specs/2026-07-09-erp-integration-design.md`。

### 1.6 接口超时 / 服务卡顿
- 现象：接口响应慢，日志出现慢查询或超时异常。
- 排查：检查数据库慢查询日志、锁等待；查看是否有大表全量扫描（配合 MyBatis 日志定位 SQL）。
- 处理：为高频查询加索引、优化 SQL；接口默认超时 30s（ERP 适配器），确认无超时阻塞。

## 2. 前端 mes-admin

- 现象：页面白屏 / 接口报错 / 按钮无权限。
- 排查：
  1. 浏览器 F12 Console/Network 看报错与接口返回；
  2. 接口 401/403 → 登录态或权限点缺失（如 `erp:workorder:sync`），检查角色权限配置（`t_sys_role_menu`）；
  3. 构建产物问题 → 确认部署的是对应环境模式（pro/test/xichi/xinzhiwei）的 dist。
- 处理：按权限点补授权或重新构建部署对应模式。

## 3. Windows 客户端

### 3.1 设备联机不工作（mes-device-link）
- 现象：车间文件不处理 / 不上传。
- 排查：
  1. 看程序目录 `logs/error-{yyyy-MM-dd}.log` 最新错误（解析失败、上传失败、移动失败都会记 Error 且文件留原位）；
  2. 确认 `config.json` 的 ApiBaseUrl / ApiToken 与服务器一致；
  3. 确认监听目录存在且监听 API 返回了对应目录；
  4. 上传失败时文件会留在原位 → 修复后需人工重放或确认机制。
- 处理：修正配置/网络，重启客户端；解析格式不匹配时对照 `ParsedLogRecord{Sn, Status, BadInfo, BadPhenomenon}` 检查 TXT 格式。

### 3.2 打印代理异常（mes-print-agent）
- 排查：确认进程是否在运行、与打印服务/API 连通性、本地打印驱动与默认打印机设置。
- 处理：修复打印机/驱动或重启代理。

### 3.3 客户端升级
- 步骤：确认旧进程退出（单实例）→ 备份旧目录 → 覆盖 exe 与依赖 → 启动 → 查看日志确认无新报错。
- 注意：`config.json` 属现场配置，升级脚本不得覆盖；如需改 API 地址需现场同步。

## 4. 通用排查命令速查

```bash
# 端口监听（macOS/Linux）
lsof -i :7070
lsof -i :50000

# 最近错误日志（mes-api 运行目录）
ls -t logs/ | head -5
tail -n 200 logs/<今日日志> | grep -iE "error|exception"

# Java 进程
ps aux | grep -i mes-api
```
