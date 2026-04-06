import urllib.request
import urllib.error
import json

url = "https://script.google.com/macros/s/AKfycbzHDtb5V-CW7rEM0VujWbf2_TLmj89NBcAu8Fbnq1syUhRk7XZIRP9a8AD2EiJVm_5B/exec"
data = json.dumps({"email": "asifabdullapa@gmail.com", "otp": "99999"}).encode('utf-8')
headers = {'Content-Type': 'application/json'}
req = urllib.request.Request(url, data=data, headers=headers)
try:
    response = urllib.request.urlopen(req)
    print("Status:", response.status)
    body = response.read().decode('utf-8')
    with open("temp_google_response_new.html", "w", encoding="utf-8") as f:
        f.write(body)
    print("Saved body to temp_google_response_new.html")
except urllib.error.HTTPError as e:
    print("HTTPError:", e.code)
    body = e.read().decode('utf-8')
    with open("temp_google_response_new.html", "w", encoding="utf-8") as f:
        f.write(body)
    print("Saved error body to temp_google_response_new.html")
except Exception as e:
    print("Error:", e)
