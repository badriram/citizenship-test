#!/usr/bin/env python3
"""Minimal App Store Connect API client.

Exists because altool cannot report build processing state or manage testers, and because pulling
in PyJWT for one ES256 signature is a poor trade. Signing goes through `openssl`; the only
non-obvious part is that JOSE wants a raw r||s signature while openssl emits DER, so the DER
SEQUENCE is parsed by hand below.

The private key is read by openssl and never printed.
"""
import base64, json, os, subprocess, sys, time, urllib.request, urllib.error

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER_ID = os.environ["ASC_ISSUER_ID"]
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """DER SEQUENCE { INTEGER r, INTEGER s } -> r||s, each left-padded to 32 bytes."""
    assert der[0] == 0x30
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        assert der[i] == 0x02
        length = der[i + 1]
        value = der[i + 2 : i + 2 + length].lstrip(b"\x00")
        out += value.rjust(32, b"\x00")
        i += 2 + length
    return out


def token() -> str:
    header = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    payload = b64(json.dumps({
        "iss": ISSUER_ID,
        "iat": int(time.time()),
        "exp": int(time.time()) + 900,
        "aud": "appstoreconnect-v1",
    }).encode())
    signing_input = f"{header}.{payload}".encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
                         input=signing_input, capture_output=True, check=True).stdout
    return f"{header}.{payload}.{b64(der_to_raw(der))}"


def call(method: str, path: str, body=None):
    url = path if path.startswith("http") else f"https://api.appstoreconnect.apple.com{path}"
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("Authorization", f"Bearer {token()}")
    if data:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        print(f"HTTP {error.code}: {detail}", file=sys.stderr)
        raise


if __name__ == "__main__":
    command = sys.argv[1]
    if command == "builds":
        app = sys.argv[2]
        result = call("GET", f"/v1/builds?filter[app]={app}&limit=5&sort=-uploadedDate")
        for build in result.get("data", []):
            a = build["attributes"]
            print(f"build {a.get('version')}  state={a.get('processingState')}  "
                  f"expired={a.get('expired')}  uploaded={a.get('uploadedDate')}  id={build['id']}")
    elif command == "testers":
        group = sys.argv[2]
        result = call("GET", f"/v1/betaGroups/{group}/betaTesters?limit=50")
        for tester in result.get("data", []):
            a = tester["attributes"]
            print(f"{a.get('firstName','')} {a.get('lastName','')} <{a.get('email')}>  "
                  f"state={a.get('state')}  invite={a.get('inviteType')}")
        if not result.get("data"):
            print("no testers in this group")
    elif command == "has-build":
        # Exit 0 when this build number already exists on App Store Connect. The build number is the
        # commit count, so re-running a release without committing collides with the previous
        # upload and fails with ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE — an alarming message for
        # something that already worked.
        app, version = sys.argv[2], sys.argv[3]
        result = call("GET", f"/v1/builds?filter[app]={app}&filter[version]={version}&limit=1")
        sys.exit(0 if result.get("data") else 1)
    elif command == "raw":
        print(json.dumps(call("GET", sys.argv[2]), indent=2)[:4000])
