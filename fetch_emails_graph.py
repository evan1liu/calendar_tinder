import requests
import webbrowser
import json
import sys
from msal import PublicClientApplication

# Using "Microsoft Graph PowerShell" Client ID
# This is very widely used and usually has permission to read mail via Graph API.
CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e" 
TENANT_ID = "common" 
SCOPES = ["User.Read", "Mail.Read"]

def authenticate_graph():
    app = PublicClientApplication(
        CLIENT_ID,
        authority=f"https://login.microsoftonline.com/{TENANT_ID}"
    )

    # 1. Check cache
    accounts = app.get_accounts()
    result = None
    if accounts:
        print("Found cached account, attempting silent login...")
        result = app.acquire_token_silent(SCOPES, account=accounts[0])

    # 2. Interactive login
    if not result:
        print("No cached token found. Starting interactive login...", flush=True)
        
        flow = app.initiate_device_flow(scopes=SCOPES)
        if "user_code" not in flow:
            raise ValueError("Fail to create device flow. Err: %s" % json.dumps(flow, indent=4))

        print("\n" + "="*60, flush=True)
        print(f"USER ACTION REQUIRED:", flush=True)
        print(flow["message"], flush=True)
        print("="*60 + "\n", flush=True)
        
        webbrowser.open(flow["verification_uri"])
        
        result = app.acquire_token_by_device_flow(flow)

    if "access_token" in result:
        return result["access_token"]
    else:
        print(f"Error: {result.get('error')}")
        print(f"Description: {result.get('error_description')}")
        return None

def fetch_emails_graph():
    token = authenticate_graph()
    
    if not token:
        print("Authentication failed. Exiting.")
        return

    print("\nSuccessfully authenticated! Fetching emails via Microsoft Graph...\n")
    
    # Graph API Endpoint
    endpoint = "https://graph.microsoft.com/v1.0/me/messages"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    # Get top 5, sorted by received time desc
    params = {
        "$top": 5,
        "$orderby": "receivedDateTime desc",
        "$select": "subject,from,receivedDateTime,bodyPreview"
    }

    try:
        response = requests.get(endpoint, headers=headers, params=params)
        response.raise_for_status()
        
        emails = response.json().get("value", [])
        
        for i, email in enumerate(emails, 1):
            print(f"--- Email {i} ---")
            print(f"From:    {email.get('from', {}).get('emailAddress', {}).get('address')}")
            print(f"Subject: {email.get('subject')}")
            print(f"Date:    {email.get('receivedDateTime')}")
            print(f"Preview: {email.get('bodyPreview')}")
            print("")
            
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    fetch_emails_graph()

