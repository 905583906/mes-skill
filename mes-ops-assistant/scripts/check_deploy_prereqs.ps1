<#
MES 部署前置检查脚本（只读，不安装、不修改任何文件/服务/环境变量）

适用场景：识别到"部署应用"意图时，在开始部署前检查目标 Windows 机器是否已具备
（对应 mes-api/deploy.ps1 里的组件，目录结构为 $BaseDir\{jdk8,mysql,nginx,app,dist}）：
  1. JDK 8      -- 是否已安装（对应 deploy.ps1 的 $jdkDir）
  2. MySQL 8    -- 是否已安装并配置好（对应 deploy.ps1 的 $mysqlDir）
  3. nginx      -- 已安装则检查 nginx.conf 语法（nginx -t）；未安装则检查部署包目录下是否已备好 nginx-*.zip

注意：不同客户现场的安装路径不同（不是固定 D:\mes），$BaseDir 默认取当前目录
（即执行该脚本时所在的部署/安装目录），按需用 -BaseDir 显式指定。

用法：
  powershell -File check_deploy_prereqs.ps1
  powershell -File check_deploy_prereqs.ps1 -BaseDir "E:\customerA\mes"

输出：纯文本报告，[OK]/[WARN]/[MISSING] 标记。任何一项 MISSING 时，
请先向用户确认是否需要安装/补齐，用户确认后再执行安装步骤，不要自动安装。
#>
param(
    [string]$BaseDir = (Get-Location).Path
)

Write-Output ("==== MES 部署前置检查 " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " ====")
Write-Output ("检查目录: " + $BaseDir)
Write-Output ""

# ---------- 1. JDK 8 ----------
Write-Output "--- 1. JDK 8（本机是否已安装） ---"
$jdk8Found = $false
$jdk8Detail = "未检测到"

$javaCmd = Get-Command java -ErrorAction SilentlyContinue
if ($javaCmd) {
    $verLine = ((& java -version) 2>&1 | Select-Object -First 1).ToString()
    if ($verLine -match '1\.8\.') {
        $jdk8Found = $true
        $jdk8Detail = "PATH 中 java: $verLine"
    } else {
        $jdk8Detail = "PATH 中 java 版本非 1.8: $verLine"
    }
}

if (-not $jdk8Found -and $env:JAVA_HOME) {
    $javaExe = Join-Path $env:JAVA_HOME "bin\java.exe"
    if (Test-Path $javaExe) {
        $verLine = ((& $javaExe -version) 2>&1 | Select-Object -First 1).ToString()
        if ($verLine -match '1\.8\.') {
            $jdk8Found = $true
            $jdk8Detail = "JAVA_HOME 指向 JDK 8: $env:JAVA_HOME"
        }
    }
}

if (-not $jdk8Found) {
    # 对应 deploy.ps1 布局：$BaseDir\jdk8
    $localJdk = Join-Path $BaseDir "jdk8\bin\java.exe"
    if (Test-Path $localJdk) {
        $verLine = ((& $localJdk -version) 2>&1 | Select-Object -First 1).ToString()
        if ($verLine -match '1\.8\.') {
            $jdk8Found = $true
            $jdk8Detail = "部署目录下发现 JDK 8: $localJdk"
        }
    }
}

if ($jdk8Found) {
    Write-Output "[OK] JDK 8 已安装 -- $jdk8Detail"
} else {
    Write-Output "[MISSING] 未检测到 JDK 8（$jdk8Detail）"
}
Write-Output ""

# ---------- 2. MySQL 8 ----------
Write-Output "--- 2. MySQL 8（本机是否已安装并配置好） ---"
$mysql8Found = $false
$mysql8Detail = "未检测到"

$mysqlCmd = Get-Command mysql -ErrorAction SilentlyContinue
if ($mysqlCmd) {
    $verLine = ((& mysql --version) 2>&1 | Select-Object -First 1).ToString()
    if ($verLine -match 'Distrib 8\.') {
        $mysql8Found = $true
        $mysql8Detail = "PATH 中 mysql 客户端: $verLine"
    } else {
        $mysql8Detail = "PATH 中 mysql 客户端版本非 8.x: $verLine"
    }
}

$mysqlService = Get-Service -Name "MySQL" -ErrorAction SilentlyContinue
if ($mysqlService) {
    # 对应 deploy.ps1 布局：$BaseDir\mysql
    $localMysqld = Join-Path $BaseDir "mysql\bin\mysqld.exe"
    if (Test-Path $localMysqld) {
        $verLine = ((& $localMysqld --version) 2>&1 | Select-Object -First 1).ToString()
        if ($verLine -match 'Ver 8\.') {
            $mysql8Found = $true
            $mysql8Detail = "MySQL 服务运行中（状态: $($mysqlService.Status)），mysqld 版本: $verLine"
        } else {
            $mysql8Detail = "MySQL 服务存在（状态: $($mysqlService.Status)），但 mysqld 版本非 8.x: $verLine"
        }
    } elseif (-not $mysqlCmd) {
        $mysql8Detail = "检测到 MySQL 服务（状态: $($mysqlService.Status)），但未能定位 mysqld.exe 核实版本，请人工确认是否为 8.x"
    }
}

if ($mysql8Found) {
    Write-Output "[OK] MySQL 8 已安装并配置 -- $mysql8Detail"
} elseif ($mysqlService) {
    Write-Output "[WARN] $mysql8Detail"
} else {
    Write-Output "[MISSING] 未检测到 MySQL 8（$mysql8Detail）"
}
Write-Output ""

# ---------- 3. nginx ----------
Write-Output "--- 3. nginx ---"

# mes-api 默认监听端口（见 references/system-map.md），仅作对比参考，现场可能被覆盖
$expectedBackendPort = 7070

# 对应 deploy.ps1 布局：$BaseDir\nginx\nginx.exe
$localNginxExe = Join-Path $BaseDir "nginx\nginx.exe"
$nginxExe = $null
if (Test-Path $localNginxExe) {
    $nginxExe = $localNginxExe
} else {
    $nginxCmd = Get-Command nginx -ErrorAction SilentlyContinue
    if ($nginxCmd) { $nginxExe = $nginxCmd.Source }
}

if ($nginxExe) {
    Write-Output "[OK] 找到已安装的 nginx: $nginxExe"

    # 已安装 -> 启动前先检查 nginx.conf 语法（只读，不启动、不重载服务）
    $nginxHome = Split-Path $nginxExe -Parent
    $confPath = Join-Path $nginxHome "conf\nginx.conf"
    if (Test-Path $confPath) {
        $testOutput = (& $nginxExe -t -c $confPath) 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "[OK] nginx.conf 语法检查通过（$confPath）"
        } else {
            Write-Output "[MISSING] nginx.conf 语法检查失败（$confPath），启动前必须先修复："
            $testOutput | ForEach-Object { Write-Output "    $_" }
        }

        # ---------- 3b. nginx.conf 业务规则检查（本项目约定，只读） ----------
        Write-Output ""
        Write-Output "--- 3b. nginx.conf 业务规则检查 ---"
        $confText = Get-Content -Path $confPath -Raw -Encoding UTF8

        # 解析 "set `$var value;" 定义的变量（root/alias 常用变量路径，如 `$mes_dist / `$mes_upload / `$mes_pdfjs）
        $varMap = @{}
        [regex]::Matches($confText, 'set\s+\$(\w+)\s+([^;]+);') | ForEach-Object {
            $name = $_.Groups[1].Value
            $val = $_.Groups[2].Value.Trim().Trim('"').Trim("'")
            $varMap[$name] = $val
        }

        function Resolve-ConfValue {
            param([string]$Raw)
            $v = $Raw.Trim().Trim(';').Trim()
            if ($v.StartsWith('$')) {
                $key = $v.Substring(1)
                if ($varMap.ContainsKey($key)) { return $varMap[$key] }
                return $null
            }
            return $v.Trim('"').Trim("'")
        }

        # 提取所有 location 块（假定块内不含嵌套 {}，本项目配置符合此约定）
        $locations = @{}
        [regex]::Matches($confText, 'location\s+([^\{]+?)\s*\{([^\}]*)\}') | ForEach-Object {
            $locations[$_.Groups[1].Value.Trim()] = $_.Groups[2].Value
        }

        # 规则 1：location / 必须有 try_files ... /index.html 兜底（否则前端路由刷新 404，见 runbook.md）
        if ($locations.ContainsKey('/')) {
            $rootBody = $locations['/']
            $tryFilesMatch = [regex]::Match($rootBody, 'try_files\s+([^;]+);')
            if ($tryFilesMatch.Success -and $tryFilesMatch.Groups[1].Value -match '/index\.html\s*$') {
                Write-Output "[OK] location / 已配置 try_files 兜底到 /index.html（前端路由刷新不会 404）"
            } else {
                Write-Output "[MISSING] location / 缺少 try_files ... /index.html 兜底，前端路由刷新会 404"
            }

            $rootMatch = [regex]::Match($rootBody, 'root\s+([^;]+);')
            if ($rootMatch.Success) {
                $rootPath = Resolve-ConfValue -Raw $rootMatch.Groups[1].Value
                if ($rootPath) {
                    if (Test-Path -Path $rootPath -PathType Container) {
                        Write-Output "[OK] location / 静态资源目录存在: $rootPath"
                    } else {
                        Write-Output "[MISSING] location / 静态资源目录不存在: $rootPath"
                    }
                } else {
                    Write-Output "[WARN] location / 的 root 使用了未在本文件中定义的变量: $($rootMatch.Groups[1].Value.Trim())，请人工确认实际路径"
                }
            }
        } else {
            Write-Output "[WARN] 未找到 location / 配置块"
        }

        # 规则 2：后端代理端口一致性（/mes_api/、/mes-api/、/ws、/wpf-ws 应指向同一个 mes-api 端口）
        $backendPorts = @{}
        foreach ($p in @('/mes_api/', '/mes-api/', '/ws', '/wpf-ws')) {
            if ($locations.ContainsKey($p)) {
                $m = [regex]::Match($locations[$p], 'proxy_pass\s+http://[^:/]+:(\d+)')
                if ($m.Success) { $backendPorts[$p] = $m.Groups[1].Value }
            }
        }
        if ($backendPorts.Count -gt 0) {
            $distinctPorts = $backendPorts.Values | Select-Object -Unique
            if ($distinctPorts.Count -eq 1) {
                Write-Output "[OK] 后端代理端口一致: $($distinctPorts[0])（涉及 $($backendPorts.Keys -join ', ')）"
                if ($distinctPorts[0] -ne [string]$expectedBackendPort) {
                    Write-Output "[WARN] 代理端口为 $($distinctPorts[0])，与 mes-api 默认端口 $expectedBackendPort 不同，请确认 mes-api 是否也用此端口启动"
                }
            } else {
                Write-Output "[MISSING] 后端代理端口不一致，可能导致部分接口/WebSocket 连不上后端："
                foreach ($k in $backendPorts.Keys) {
                    Write-Output "    $k -> $($backendPorts[$k])"
                }
            }
        } else {
            Write-Output "[WARN] 未找到 /mes_api/、/mes-api/、/ws、/wpf-ws 的 proxy_pass 配置，请人工确认反向代理是否配置"
        }

        # 规则 3：WebSocket location（/ws、/wpf-ws）必须带升级头，否则 WebSocket 断连（见 runbook.md 1.4）
        foreach ($p in @('/ws', '/wpf-ws')) {
            if ($locations.ContainsKey($p)) {
                $wsBody = $locations[$p]
                $hasHttp11 = $wsBody -match 'proxy_http_version\s+1\.1'
                $hasUpgrade = $wsBody -match 'proxy_set_header\s+Upgrade\s+\$http_upgrade'
                $hasConnection = $wsBody -match 'proxy_set_header\s+Connection\s+["\x27]?Upgrade["\x27]?'
                if ($hasHttp11 -and $hasUpgrade -and $hasConnection) {
                    Write-Output "[OK] location $p 已正确配置 WebSocket 升级头（proxy_http_version 1.1 + Upgrade + Connection）"
                } else {
                    $missingHeaders = @()
                    if (-not $hasHttp11) { $missingHeaders += 'proxy_http_version 1.1' }
                    if (-not $hasUpgrade) { $missingHeaders += 'proxy_set_header Upgrade $http_upgrade' }
                    if (-not $hasConnection) { $missingHeaders += 'proxy_set_header Connection "Upgrade"' }
                    Write-Output "[MISSING] location $p 缺少 WebSocket 升级头: $($missingHeaders -join ' / ')，会导致 WebSocket 无法建立或频繁断连"
                }
            }
        }

        # 规则 4：alias 静态目录（/mes/file/、/pdfjs/ 等）路径存在性
        foreach ($p in $locations.Keys) {
            if ($p -like '*mes/file*' -or $p -like '*pdfjs*') {
                $aliasMatch = [regex]::Match($locations[$p], 'alias\s+([^;]+);')
                if ($aliasMatch.Success) {
                    $aliasPath = Resolve-ConfValue -Raw $aliasMatch.Groups[1].Value
                    if ($aliasPath) {
                        if (Test-Path -Path $aliasPath -PathType Container) {
                            Write-Output "[OK] location $p 的 alias 目录存在: $aliasPath"
                        } else {
                            Write-Output "[MISSING] location $p 的 alias 目录不存在: $aliasPath"
                        }
                    } else {
                        Write-Output "[WARN] location $p 的 alias 使用了未在本文件中定义的变量: $($aliasMatch.Groups[1].Value.Trim())，请人工确认实际路径"
                    }
                }
            }
        }
    } else {
        Write-Output "[WARN] 未找到 nginx.conf（预期路径: $confPath），无法做语法检查"
    }
} else {
    Write-Output "[INFO] 本机未检测到已安装的 nginx，检查部署包目录下是否已备好安装包"
    $nginxZip = Get-ChildItem -Path $BaseDir -Filter "nginx-*.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nginxZip) {
        Write-Output "[OK] 找到 nginx 安装包: $($nginxZip.Name)"
    } else {
        Write-Output "[MISSING] 部署目录（$BaseDir）下未找到 nginx-*.zip 安装包"
    }
}
Write-Output ""

Write-Output "==== 检查完成（本脚本只读，未安装/未修改任何内容）===="
