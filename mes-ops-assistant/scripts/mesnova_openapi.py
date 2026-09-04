#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""mesnova.cn OpenAPI 通用签名客户端

自动完成 AppKey/AppSecret 的 HMAC-SHA256 签名，调用 mesnova.cn 的
/openapi/v1/* 接口（第三方对接接口，与 mes-api/doc/third-party-basic-data-api.md
里列出的旧路径如 /workOrder/page 不是一套——旧路径走普通登录鉴权，不校验签名）。

注意：生产环境 nginx 把 mes-api 挂在 /mes-api/ 前缀下（见 mes-api/nginx.conf），
直接请求 https://mesnova.cn/openapi/v1/... （不带 /mes-api 前缀）会被前端 SPA
兜底路由吞掉，返回 200 的 HTML 页面而不是报错，看起来像"通了"但其实没到后端。
本脚本默认 Base URL 已包含 /mes-api 前缀，命令行传 path 时只需写 /openapi/v1/...。

凭据来源优先级：CLI 参数 > 环境变量。
  环境变量: MES_OPENAPI_APP_KEY / MES_OPENAPI_APP_SECRET / MES_OPENAPI_BASE_URL
  默认 Base URL: https://mesnova.cn/mes-api

用法:
  mesnova_openapi.py GET  /openapi/v1/dicts/query --query codeType=001
  mesnova_openapi.py POST /openapi/v1/work-orders/page --body '{"pageNum":1,"pageSize":100}'
  mesnova_openapi.py GET  /openapi/v1/work-station-sns/getInfoByWorkOrderNo --query workOrderNo=WO-20260610001

AppSecret 只用于本地签名计算，不会被打印、不会写入任何日志或文件。
"""
import argparse
import base64
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from typing import Optional, Tuple

DEFAULT_BASE_URL = "https://mesnova.cn/mes-api"


def build_query_string(pairs: list) -> str:
    """将 --query k=v 列表转换成 query string（保持传入顺序）"""
    items = []
    for pair in pairs:
        if "=" not in pair:
            sys.exit(f"[mesnova_openapi] --query 参数格式错误，需为 key=value，收到: {pair}")
        key, value = pair.split("=", 1)
        items.append((key, value))
    return urllib.parse.urlencode(items)


def sign(app_secret: str, method: str, signature_path: str, timestamp: str, nonce: str, body: str) -> str:
    """按 mes-api OpenApiSignatureVerifier 的规则计算签名：
    明文 = METHOD\nPATH(含query)\nTIMESTAMP\nNONCE\nBODY
    签名 = Base64(HMAC-SHA256(明文, AppSecret))
    """
    plain_text = "\n".join([method.upper(), signature_path, timestamp, nonce, body])
    digest = hmac.new(app_secret.encode("utf-8"), plain_text.encode("utf-8"), hashlib.sha256).digest()
    return base64.b64encode(digest).decode("utf-8")


def resolve_credentials(args) -> Tuple[str, str, str]:
    app_key = args.app_key or os.environ.get("MES_OPENAPI_APP_KEY")
    app_secret = args.app_secret or os.environ.get("MES_OPENAPI_APP_SECRET")
    base_url = args.base_url or os.environ.get("MES_OPENAPI_BASE_URL") or DEFAULT_BASE_URL

    missing = []
    if not app_key:
        missing.append("AppKey（--app-key 或环境变量 MES_OPENAPI_APP_KEY）")
    if not app_secret:
        missing.append("AppSecret（--app-secret 或环境变量 MES_OPENAPI_APP_SECRET）")
    if missing:
        sys.exit(
            "[mesnova_openapi] 缺少凭据: " + "、".join(missing) + "\n"
            "请先向 MES 管理员申请 OpenAPI 应用的 AppKey/AppSecret，然后设置环境变量，例如：\n"
            "  export MES_OPENAPI_APP_KEY=你的AppKey\n"
            "  export MES_OPENAPI_APP_SECRET=你的AppSecret\n"
            "也可用 --app-key / --app-secret 参数临时传入。"
        )
    return app_key, app_secret, base_url.rstrip("/")


def main():
    parser = argparse.ArgumentParser(
        description="mesnova.cn OpenAPI 通用签名客户端（自动完成 HMAC-SHA256 签名）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("method", help="HTTP 方法，如 GET / POST / DELETE")
    parser.add_argument("path", help="接口路径，如 /openapi/v1/dicts/query")
    parser.add_argument("--query", action="append", default=[], metavar="KEY=VALUE",
                         help="query 参数，可重复传入，如 --query codeType=001")
    parser.add_argument("--body", default=None, help="POST/DELETE 请求体，JSON 字符串")
    parser.add_argument("--app-key", default=None, help="覆盖环境变量 MES_OPENAPI_APP_KEY")
    parser.add_argument("--app-secret", default=None, help="覆盖环境变量 MES_OPENAPI_APP_SECRET")
    parser.add_argument("--base-url", default=None,
                         help=f"覆盖环境变量 MES_OPENAPI_BASE_URL（默认 {DEFAULT_BASE_URL}）")
    parser.add_argument("--timeout", type=float, default=30.0, help="请求超时秒数，默认 30")
    args = parser.parse_args()

    if not args.path.startswith("/"):
        sys.exit(f"[mesnova_openapi] path 必须以 / 开头，收到: {args.path}")
    if not args.path.startswith("/openapi/"):
        print(
            f"[mesnova_openapi] 警告: {args.path} 不是 /openapi/ 开头的路径，"
            "mes-api 只对 /openapi/ 开头的路径做 AppKey/AppSecret 签名校验，"
            "其它路径的签名头会被忽略。",
            file=sys.stderr,
        )

    app_key, app_secret, base_url = resolve_credentials(args)

    query_string = build_query_string(args.query)
    signature_path = args.path if not query_string else f"{args.path}?{query_string}"
    body = args.body or ""

    timestamp = str(int(time.time() * 1000))
    nonce = uuid.uuid4().hex
    signature = sign(app_secret, args.method, signature_path, timestamp, nonce, body)

    url = base_url + signature_path
    headers = {
        "X-App-Key": app_key,
        "X-Timestamp": timestamp,
        "X-Nonce": nonce,
        "X-Signature": signature,
    }
    data = None
    if body:
        headers["Content-Type"] = "application/json"
        data = body.encode("utf-8")

    request = urllib.request.Request(url, data=data, headers=headers, method=args.method.upper())

    try:
        with urllib.request.urlopen(request, timeout=args.timeout) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        print_response(raw)
        sys.exit(1)
    except urllib.error.URLError as e:
        sys.exit(f"[mesnova_openapi] 请求失败: {e}")

    ok = print_response(raw)
    if not ok:
        sys.exit(1)


def print_response(raw: str) -> bool:
    """打印响应；返回 code == 200 与否（非标准 JSON 则原样输出，视为失败）"""
    try:
        payload = json.loads(raw)
    except ValueError:
        print(raw)
        return False
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    if isinstance(payload, dict) and "code" in payload:
        return payload.get("code") == 200
    return True


if __name__ == "__main__":
    main()
