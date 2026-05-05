import paramiko, sys, io, os, hashlib
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

host = os.environ['DEPLOY_HOST']
user = os.environ.get('DEPLOY_USER', 'ubuntu')
pw = os.environ['DEPLOY_PASSWORD']

# Upload main.dart.js to /tmp first, then sudo cp
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(host, username=user, password=pw, timeout=10, look_for_keys=False, allow_agent=False)

def run(cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=30)
    return stdout.read().decode(errors='replace').strip()

local_js = r'C:\Users\Z\Desktop\project\vehicle-maintenance-app\frontend\build\web\main.dart.js'

# Upload to /tmp (writable by ubuntu)
sftp = ssh.open_sftp()
sftp.put(local_js, '/tmp/main.dart.js')
sftp.close()
print('Uploaded to /tmp')

# sudo cp to web directory
out = run("sudo cp /tmp/main.dart.js /var/www/vehicle-maintenance/current/main.dart.js && rm /tmp/main.dart.js && echo 'OK'")
print(f'Copy: {out}')

# Set permissions
run("sudo chmod 644 /var/www/vehicle-maintenance/current/main.dart.js")
run("sudo rm -f /var/www/vehicle-maintenance/current/flutter_service_worker.js /var/www/vehicle-maintenance/current/.last_build_id")

# Verify
out = run("ls -lh /var/www/vehicle-maintenance/current/main.dart.js && md5sum /var/www/vehicle-maintenance/current/main.dart.js")
print(f'\nServer: {out}')

with open(local_js, 'rb') as f:
    local_md5 = hashlib.md5(f.read()).hexdigest()
print(f'Local MD5: {local_md5}')

# Check for correct URLs in JS
out = run("grep -c 'ulbooks.cn' /var/www/vehicle-maintenance/current/main.dart.js || echo 0")
print(f'ulbooks.cn refs: {out}')
out = run("grep -c 'localhost:8080' /var/www/vehicle-maintenance/current/main.dart.js || echo 0")
print(f'localhost:8080 refs: {out}')

# Test
stdin, stdout, stderr = ssh.exec_command("curl -s -o /dev/null -w '%{http_code}' https://ulbooks.cn/", timeout=10)
print(f'\nFrontend: HTTP {stdout.read().decode().strip()}')

ssh.close()
print('\nNow Ctrl+Shift+R refresh https://ulbooks.cn')
