import subprocess

def run_command(command):
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    return result.stdout

response = run_command('curl https://example.com/health')
print(response)
subprocess.run(['gh', 'issue', 'create', '--title', 'Health Check', '--body', response])
