import os
import paramiko, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

host = os.environ['DEPLOY_HOST']
user = os.environ.get('DEPLOY_USER', 'ubuntu')
pw = os.environ['DEPLOY_PASSWORD']

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(host, username=user, password=pw, timeout=10, look_for_keys=False, allow_agent=False)

def run(cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=120)
    return stdout.read().decode('utf-8', errors='replace').strip(), stderr.read().decode('utf-8', errors='replace').strip()

print(">>> Step 4: Install Dart SDK")
out, err = run("""
if [ -f /usr/local/bin/dart ]; then
    dart --version && echo 'SKIP'
elif [ -d /usr/lib/dart ]; then
    export PATH=$PATH:/usr/lib/dart/dart-sdk/bin
    /usr/lib/dart/dart-sdk/bin/dart --version && echo 'SKIP'
else
    echo 'Downloading Dart SDK...'
    wget -q --show-progress https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip -O /tmp/dart.zip
    echo 'Unzipping...'
    sudo unzip -oq /tmp/dart.zip -d /usr/lib/dart
    sudo ln -sf /usr/lib/dart/dart-sdk/bin/dart /usr/local/bin/dart
    sudo ln -sf /usr/lib/dart/dart-sdk/bin/dartaotruntime /usr/local/bin/dartaotruntime
    rm -f /tmp/dart.zip
    echo 'Done!'
    export PATH=$PATH:/usr/lib/dart/dart-sdk/bin
    dart --version
fi
""")
print(out)
if err: print('ERR:', err[:500])

ssh.close()
