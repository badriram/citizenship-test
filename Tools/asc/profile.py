#!/usr/bin/env python3
"""Create a provisioning profile that carries the App ID's *current* capabilities.

A profile is a snapshot. Enabling a capability on an App ID does nothing to profiles that already
exist, and there is no API to edit one — so a capability change means a new profile, always.

Deliberately creates rather than replaces. Deleting the profile the release path names and then
failing to recreate it would leave no way to ship at all, and `/v1/profiles` is documented in
DESIGN.md as returning HTTP 500 intermittently. The old profile stays until the new one is proven.

    python3 Tools/asc/profile.py list
    python3 Tools/asc/profile.py create "CitizenReady AppStore" IOS_APP_STORE
    python3 Tools/asc/profile.py inspect <profile-id>
    python3 Tools/asc/profile.py install <profile-id>
"""
import base64, plistlib, re, subprocess, sys, tempfile, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asc

BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.badriram.citizenready")


def bundle_id_ref() -> str:
    result = asc.call("GET", f"/v1/bundleIds?filter[identifier]={BUNDLE_ID}")
    if not result.get("data"):
        sys.exit(f"no App ID registered for {BUNDLE_ID}")
    return result["data"][0]["id"]


def capabilities(ref: str) -> list[str]:
    result = asc.call("GET", f"/v1/bundleIds/{ref}/bundleIdCapabilities")
    return sorted(c["attributes"]["capabilityType"] for c in result.get("data", []))


def certificates(kind: str) -> list[str]:
    result = asc.call("GET", "/v1/certificates?limit=50")
    return [c["id"] for c in result.get("data", [])
            if c["attributes"]["certificateType"] == kind]


def devices() -> list[str]:
    result = asc.call("GET", "/v1/devices?filter[status]=ENABLED&limit=100")
    return [d["id"] for d in result.get("data", [])]


def decode(profile_content: str) -> dict:
    """Pulls the entitlements out of the signed profile, which is CMS around a plist."""
    with tempfile.NamedTemporaryFile(suffix=".mobileprovision", delete=False) as handle:
        handle.write(base64.b64decode(profile_content))
        path = handle.name
    try:
        xml = subprocess.run(["security", "cms", "-D", "-i", path],
                             capture_output=True, check=True).stdout
        return plistlib.loads(xml)
    finally:
        os.unlink(path)


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "list"

    if command == "list":
        ref = bundle_id_ref()
        print(f"App ID {BUNDLE_ID} = {ref}")
        print(f"capabilities: {', '.join(capabilities(ref)) or 'none'}")
        for profile in asc.call("GET", "/v1/profiles?limit=50").get("data", []):
            a = profile["attributes"]
            print(f"  {profile['id']}  {a['name']!r}  {a['profileType']}  "
                  f"{a['profileState']}  expires {a['expirationDate'][:10]}")

    elif command == "create":
        name, kind = sys.argv[2], sys.argv[3]
        ref = bundle_id_ref()
        print(f"App ID capabilities at creation: {', '.join(capabilities(ref)) or 'none'}")
        certificate_kind = "DEVELOPMENT" if "DEVELOPMENT" in kind else "DISTRIBUTION"
        certs = certificates(certificate_kind)
        if not certs:
            sys.exit(f"no {certificate_kind} certificate on the account")
        relationships = {
            "bundleId": {"data": {"type": "bundleIds", "id": ref}},
            "certificates": {"data": [{"type": "certificates", "id": c} for c in certs]},
        }
        # Development profiles are per-device; App Store ones are not, and sending devices for a
        # store profile is rejected rather than ignored.
        if certificate_kind == "DEVELOPMENT":
            relationships["devices"] = {"data": [{"type": "devices", "id": d} for d in devices()]}

        body = {"data": {"type": "profiles",
                         "attributes": {"name": name, "profileType": kind},
                         "relationships": relationships}}
        created = asc.call("POST", "/v1/profiles", body)
        profile = created["data"]
        print(f"created {profile['id']}  {profile['attributes']['name']!r}")
        entitlements = decode(profile["attributes"]["profileContent"]).get("Entitlements", {})
        aware = entitlements.get("com.apple.developer.wifi-aware")
        print(f"com.apple.developer.wifi-aware in profile: {aware if aware else 'ABSENT'}")
        if not aware:
            print("  -> the capability is not enabled on the App ID; this profile will strip it")

    elif command == "install":
        # Xcode reads this directory and nothing else. A profile that exists on the account but
        # not here cannot be named by PROVISIONING_PROFILE_SPECIFIER, and the error says only
        # that no profile matches — not that it was never downloaded.
        result = asc.call("GET", f"/v1/profiles/{sys.argv[2]}")
        content = result["data"]["attributes"]["profileContent"]
        decoded = decode(content)
        target = os.path.expanduser(
            "~/Library/Developer/Xcode/UserData/Provisioning Profiles/"
            f"{decoded['UUID']}.mobileprovision")
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as handle:
            handle.write(base64.b64decode(content))
        print(f"installed {decoded['Name']!r} as {decoded['UUID']}")

    elif command == "inspect":
        result = asc.call("GET", f"/v1/profiles/{sys.argv[2]}")
        decoded = decode(result["data"]["attributes"]["profileContent"])
        print(f"name: {decoded.get('Name')}  expires: {decoded.get('ExpirationDate')}")
        for key, value in sorted(decoded.get("Entitlements", {}).items()):
            print(f"  {key} = {value}")
