#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""MES 数据库查询脚本（默认只读，禁止破坏性语句）

自动从 mes-api 的 application-<profile>.yml 读取连接参数（默认 prod），
优先使用 mysql CLI 执行，本机没有 mysql 时回退 pymysql。

用法示例:
  db_query.py "SELECT * FROM t_sys_users WHERE delete_flag = 0"
  db_query.py --profile dev "SHOW TABLES"
  echo "SELECT COUNT(*) FROM t_sys_users" | db_query.py
  db_query.py --force "UPDATE ..."      # 危险，仅确认需要时使用

连接参数优先级: 环境变量 > yml 配置。
环境变量: DB_HOST / DB_PORT / DB_NAME / DB_USER / DB_PASS
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

READONLY_RE = re.compile(r"^\s*(select|show|desc|describe|explain|with)\b", re.IGNORECASE)
JDBC_URL_RE = re.compile(r"jdbc:mysql://([^:/]+)(?::(\d+))?/([^?]+)")
YML_URL_RE = re.compile(r"^\s*url:\s*(.+?)\s*$")
YML_USER_RE = re.compile(r"^\s*username:\s*['\"]?([^'\"]+)['\"]?\s*$")
YML_PASS_RE = re.compile(r"^\s*password:\s*['\"]?([^'\"]+)['\"]?\s*$")


def find_resources_dir(start: Path) -> Optional[Path]:
    """从脚本位置向上查找 mes-api/src/main/resources 目录"""
    p = start
    for _ in range(8):
        cand = p / "mes-api" / "src" / "main" / "resources"
        if cand.is_dir():
            return cand
        p = p.parent
    return None


def load_conn_from_yml(resources_dir: Path, profile: str) -> dict:
    path = resources_dir / f"application-{profile}.yml"
    if not path.is_file():
        sys.exit(f"[db_query] 找不到配置文件: {path}")
    url = user = password = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if url is None:
            m = YML_URL_RE.match(line)
            if m:
                url = m.group(1)
        if user is None:
            m = YML_USER_RE.match(line)
            if m:
                user = m.group(1)
        if password is None:
            m = YML_PASS_RE.match(line)
            if m:
                password = m.group(1)
    if not (url and user and password):
        sys.exit(f"[db_query] 无法从 {path} 解析出完整的 datasource 配置（url/username/password）")
    m = JDBC_URL_RE.match(url)
    if not m:
        sys.exit(f"[db_query] 无法解析 JDBC URL: {url}")
    return {
        "host": m.group(1),
        "port": int(m.group(2) or 3306),
        "db": m.group(3),
        "user": user,
        "password": password,
    }


def resolve_conn(profile: str, api_resources: Optional[Path]) -> dict:
    env_map = {
        "host": "DB_HOST", "port": "DB_PORT", "db": "DB_NAME",
        "user": "DB_USER", "password": "DB_PASS",
    }
    conn = {}
    for k, env_name in env_map.items():
        v = os.environ.get(env_name)
        if v:
            conn[k] = int(v) if k == "port" else v
    if "host" in conn or api_resources:
        yml_conn = load_conn_from_yml(api_resources, profile) if api_resources else {}
        for k, v in yml_conn.items():
            conn.setdefault(k, v)
    if not (conn.get("host") and conn.get("db") and conn.get("user") and conn.get("password")):
        sys.exit("[db_query] 连接参数不完整。可设置环境变量 DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASS，"
                 "或提供含 application-<profile>.yml 的仓库路径（--api-dir）")
    conn.setdefault("port", 3306)
    return conn


def check_readonly(sql: str, force: bool) -> None:
    if force:
        print("[db_query] 警告: --force 已放行非只读语句，请确认语句安全！", file=sys.stderr)
        return
    if not READONLY_RE.match(sql):
        sys.exit("[db_query] 拒绝执行: 默认仅允许只读语句（SELECT/SHOW/DESC/EXPLAIN/WITH）。"
                 "如确需执行写操作，请人工确认后加 --force。")


def run_via_cli(conn: dict, sql: str) -> int:
    if not shutil.which("mysql"):
        return 1
    env = os.environ.copy()
    env["MYSQL_PWD"] = conn["password"]
    cmd = [
        "mysql", "-h", conn["host"], "-P", str(conn["port"]),
        "-u", conn["user"], "--default-character-set=utf8mb4",
        "--batch", "--raw", conn["db"], "-e", sql,
    ]
    return subprocess.call(cmd, env=env)


def run_via_pymysql(conn: dict, sql: str) -> int:
    try:
        import pymysql
    except ImportError:
        print("[db_query] 本机没有 mysql 客户端且未安装 pymysql。\n"
              "  安装其一即可:\n"
              "    brew install mysql-client   (macOS)\n"
              "    pip install pymysql         (Python 环境)", file=sys.stderr)
        return 127
    try:
        cur = pymysql.connect(
            host=conn["host"], port=conn["port"], user=conn["user"],
            password=conn["password"], database=conn["db"], charset="utf8mb4",
        ).cursor()
        cur.execute(sql)
        cols = [d[0] for d in cur.description] if cur.description else []
        rows = cur.fetchall()
        if cols:
            print("\t".join(cols))
            for r in rows:
                print("\t".join("" if v is None else str(v) for v in r))
        print(f"\n[db_query] {len(rows)} row(s) returned")
        return 0
    except Exception as e:
        print(f"[db_query] 查询失败: {e}", file=sys.stderr)
        return 1


def main() -> None:
    parser = argparse.ArgumentParser(description="MES 数据库只读查询（连接参数自动读取 mes-api 配置）")
    parser.add_argument("sql", nargs="?", help="SQL 语句；缺省时从 stdin 读取，'-' 表示 stdin")
    parser.add_argument("--profile", default="prod", help="环境 profile，默认 prod（dev/prod/shenzhen）")
    parser.add_argument("--api-dir", help="mes-api 源码 resources 目录或仓库根；默认自动向上查找")
    parser.add_argument("--force", action="store_true", help="放行非只读语句（危险，谨慎使用）")
    args = parser.parse_args()

    if args.sql is None or args.sql == "-":
        sql = sys.stdin.read().strip()
    else:
        sql = args.sql.strip()
    if not sql:
        parser.print_help()
        sys.exit(1)

    check_readonly(sql, args.force)

    api_resources = None
    if args.api_dir:
        d = Path(args.api_dir)
        api_resources = d if d.name == "resources" else d / "mes-api" / "src" / "main" / "resources"
    else:
        api_resources = find_resources_dir(Path(__file__).resolve().parent)

    conn = resolve_conn(args.profile, api_resources)

    if run_via_cli(conn, sql) == 0:
        return
    sys.exit(run_via_pymysql(conn, sql))


if __name__ == "__main__":
    main()
