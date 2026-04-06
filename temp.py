import urllib.request
import json

url = "https://script.google.com/macros/s/AKfycbzTt-kfOChCFgnhc2GT8imN2Mgt2k9n437JSE-OsUou8zH4Wi0rdji_zTXyDhl0HIQedQ/exec"
data = json.dumps({"email": "asifabdullapa@gmail.com", "otp": "12345"}).encode('utf-8')
headers = {'Content-Type': 'application/json'}
req = urllib.request.Request(url, data=data, headers=headers)
try:
    response = urllib.request.urlopen(req)
    print("Status:", response.status)
    print("Body:", response.read().decode('utf-8'))
except Exception as e:
    print("Error:", e)
