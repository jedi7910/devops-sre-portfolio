import requests
import json
import time

SERVICES = [
    "https://api.prod.company.com/health",
    "https://payments.prod.company.com/status",
    "https://auth.prod.company.com/ping"
]

SLACK_WEBHOOK = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

def send_slack_alert(webhook_url, message):
    payload = {"text": message}
    response = requests.post(
        webhook_url,
        data=json.dumps(payload),
        headers={"Content-Type": "application/json"}
    )
    if response.status_code != 200:
        raise Exception(f"Slack webhook error: {response.text}")

def check_service(url, retries=3, delay=1):
    for attempt in range(1, retries + 1):
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                return True
        except requests.exceptions.RequestException:
            pass  # Ignore and retry
        # If not last attempt, wait before retrying
        if attempt < retries:
            time.sleep(delay)
    # All retries failed
    return False

def main():
    print("Starting health checks...")
    for service in SERVICES:
        status = check_service(service)
        if status:
            print(f"✓ {service} is UP")
        else:
            print(f"✗ {service} is DOWN")
            send_slack_alert(SLACK_WEBHOOK, f"🚨 Service DOWN: {service}")
        time.sleep(1)

if __name__ == "__main__":
    main()