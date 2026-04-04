#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ENV_FILE = REPO_ROOT / ".env.octopus"
OAUTH1_VERIFY_URL = "https://api.x.com/1.1/account/verify_credentials.json"
OAUTH1_POST_URL = "https://api.x.com/1.1/statuses/update.json"
OAUTH2_VERIFY_URL = "https://api.x.com/2/users/me"
OAUTH2_POST_URL = "https://api.x.com/2/tweets"


def load_env_file(path: Path) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()

        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]

        os.environ.setdefault(key, value)


def percent_encode(value: str) -> str:
    return urllib.parse.quote(value, safe="~-._")


def build_oauth1_header(
    *,
    method: str,
    url: str,
    consumer_key: str,
    consumer_secret: str,
    token: str,
    token_secret: str,
    request_params: dict[str, str],
) -> str:
    oauth_params = {
        "oauth_consumer_key": consumer_key,
        "oauth_nonce": secrets.token_hex(16),
        "oauth_signature_method": "HMAC-SHA1",
        "oauth_timestamp": str(int(time.time())),
        "oauth_token": token,
        "oauth_version": "1.0",
    }

    signature_params = {**request_params, **oauth_params}
    normalized_items = sorted(
        (percent_encode(key), percent_encode(value))
        for key, value in signature_params.items()
    )
    normalized = "&".join(f"{key}={value}" for key, value in normalized_items)

    parsed = urllib.parse.urlsplit(url)
    normalized_url = f"{parsed.scheme}://{parsed.netloc}{parsed.path}"
    base_string = "&".join(
        [
            method.upper(),
            percent_encode(normalized_url),
            percent_encode(normalized),
        ]
    )
    signing_key = "&".join(
        [
            percent_encode(consumer_secret),
            percent_encode(token_secret),
        ]
    )
    digest = hmac.new(
        signing_key.encode("utf-8"),
        base_string.encode("utf-8"),
        hashlib.sha1,
    ).digest()
    signature = base64.b64encode(digest).decode("utf-8")
    oauth_params["oauth_signature"] = signature

    header_pairs = ", ".join(
        f'{percent_encode(key)}="{percent_encode(value)}"'
        for key, value in sorted(oauth_params.items())
    )
    return f"OAuth {header_pairs}"


def request_json(
    *,
    method: str,
    url: str,
    headers: dict[str, str],
    body: bytes | None = None,
) -> dict:
    request = urllib.request.Request(url, data=body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(request) as response:
            payload = response.read().decode("utf-8")
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {payload}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error: {exc.reason}") from exc


class XClient:
    def auth_mode(self) -> str:
        raise NotImplementedError

    def verify_account(self) -> tuple[str, str]:
        raise NotImplementedError

    def publish_post(self, text: str) -> tuple[str, str | None]:
        raise NotImplementedError


class OAuth2UserTokenClient(XClient):
    def __init__(self, token: str) -> None:
        self.token = token

    def auth_mode(self) -> str:
        return "oauth2-user-token"

    def verify_account(self) -> tuple[str, str]:
        response = request_json(
            method="GET",
            url=OAUTH2_VERIFY_URL,
            headers={"Authorization": f"Bearer {self.token}"},
        )
        data = response.get("data") or {}
        username = data.get("username")
        user_id = data.get("id")
        if not username or not user_id:
            raise RuntimeError(f"Unexpected verify response: {json.dumps(response)}")
        return username, user_id

    def publish_post(self, text: str) -> tuple[str, str | None]:
        response = request_json(
            method="POST",
            url=OAUTH2_POST_URL,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
            body=json.dumps({"text": text}).encode("utf-8"),
        )
        data = response.get("data") or {}
        post_id = data.get("id")
        if not post_id:
            raise RuntimeError(f"Unexpected publish response: {json.dumps(response)}")
        return post_id, data.get("text")


class OAuth1Client(XClient):
    def __init__(
        self,
        *,
        consumer_key: str,
        consumer_secret: str,
        access_token: str,
        access_token_secret: str,
    ) -> None:
        self.consumer_key = consumer_key
        self.consumer_secret = consumer_secret
        self.access_token = access_token
        self.access_token_secret = access_token_secret

    def auth_mode(self) -> str:
        return "oauth1-user-context"

    def verify_account(self) -> tuple[str, str]:
        params = {"skip_status": "true", "include_entities": "false"}
        url = f"{OAUTH1_VERIFY_URL}?{urllib.parse.urlencode(params)}"
        auth_header = build_oauth1_header(
            method="GET",
            url=OAUTH1_VERIFY_URL,
            consumer_key=self.consumer_key,
            consumer_secret=self.consumer_secret,
            token=self.access_token,
            token_secret=self.access_token_secret,
            request_params=params,
        )
        response = request_json(
            method="GET",
            url=url,
            headers={"Authorization": auth_header},
        )
        username = response.get("screen_name")
        user_id = response.get("id_str") or str(response.get("id", ""))
        if not username or not user_id:
            raise RuntimeError(f"Unexpected verify response: {json.dumps(response)}")
        return username, user_id

    def publish_post(self, text: str) -> tuple[str, str | None]:
        params = {"status": text}
        body = urllib.parse.urlencode(params).encode("utf-8")
        auth_header = build_oauth1_header(
            method="POST",
            url=OAUTH1_POST_URL,
            consumer_key=self.consumer_key,
            consumer_secret=self.consumer_secret,
            token=self.access_token,
            token_secret=self.access_token_secret,
            request_params=params,
        )
        response = request_json(
            method="POST",
            url=OAUTH1_POST_URL,
            headers={
                "Authorization": auth_header,
                "Content-Type": "application/x-www-form-urlencoded",
            },
            body=body,
        )
        post_id = response.get("id_str") or str(response.get("id", ""))
        if not post_id:
            raise RuntimeError(f"Unexpected publish response: {json.dumps(response)}")
        return post_id, response.get("text")


def build_client() -> XClient:
    user_access_token = os.getenv("X_USER_ACCESS_TOKEN", "").strip()
    if user_access_token:
        return OAuth2UserTokenClient(user_access_token)

    oauth1_values = {
        "X_API_KEY": os.getenv("X_API_KEY", "").strip(),
        "X_API_SECRET": os.getenv("X_API_SECRET", "").strip(),
        "X_ACCESS_TOKEN": os.getenv("X_ACCESS_TOKEN", "").strip(),
        "X_ACCESS_TOKEN_SECRET": os.getenv("X_ACCESS_TOKEN_SECRET", "").strip(),
    }
    if all(oauth1_values.values()):
        return OAuth1Client(
            consumer_key=oauth1_values["X_API_KEY"],
            consumer_secret=oauth1_values["X_API_SECRET"],
            access_token=oauth1_values["X_ACCESS_TOKEN"],
            access_token_secret=oauth1_values["X_ACCESS_TOKEN_SECRET"],
        )

    missing = [
        name
        for name, value in oauth1_values.items()
        if not value
    ]
    raise RuntimeError(
        "Missing X credentials. Set X_USER_ACCESS_TOKEN or the full OAuth 1.0a set: "
        + ", ".join(missing)
    )


def read_text(args: argparse.Namespace) -> str:
    if args.verify_only:
        return ""
    if bool(args.text) == bool(args.text_file):
        raise RuntimeError("Provide exactly one of --text or --text-file.")
    if args.text_file:
        return Path(args.text_file).read_text(encoding="utf-8").strip()
    return args.text.strip()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Preview, verify, and publish a text post to X using .env.octopus credentials."
    )
    parser.add_argument("--text", help="Post text to publish or preview.")
    parser.add_argument("--text-file", help="Path to a file that contains the post text.")
    parser.add_argument(
        "--env-file",
        default=str(DEFAULT_ENV_FILE),
        help="Path to the .env.octopus file. Defaults to the repository root file.",
    )
    parser.add_argument(
        "--expected-username",
        help="Fail if the authenticated account username does not match this value.",
    )
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Verify the authenticated account without publishing.",
    )
    parser.add_argument(
        "--publish",
        action="store_true",
        help="Publish the post. Without this flag, the script only previews the payload.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    load_env_file(Path(args.env_file))

    expected_username = (
        args.expected_username
        or os.getenv("X_EXPECTED_USERNAME", "").strip()
        or None
    )
    client = build_client()

    if args.verify_only:
        username, user_id = client.verify_account()
        if expected_username and username.lower() != expected_username.lower():
            raise RuntimeError(
                f"Authenticated as @{username}, but expected @{expected_username}."
            )
        print(json.dumps(
            {
                "mode": "verify-only",
                "auth_mode": client.auth_mode(),
                "username": username,
                "user_id": user_id,
            },
            indent=2,
        ))
        return 0

    text = read_text(args)
    if not text:
        raise RuntimeError("Post text cannot be empty.")

    preview = {
        "mode": "publish" if args.publish else "preview",
        "auth_mode": client.auth_mode(),
        "expected_username": expected_username,
        "text": text,
        "length": len(text),
    }

    if not args.publish:
        print(json.dumps(preview, indent=2))
        return 0

    username, _user_id = client.verify_account()
    if expected_username and username.lower() != expected_username.lower():
        raise RuntimeError(
            f"Authenticated as @{username}, but expected @{expected_username}."
        )

    post_id, response_text = client.publish_post(text)
    result = {
        "mode": "publish",
        "auth_mode": client.auth_mode(),
        "username": username,
        "post_id": post_id,
        "url": f"https://x.com/{username}/status/{post_id}",
        "text": response_text or text,
    }
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1) from exc
