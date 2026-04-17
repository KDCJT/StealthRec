import urllib.request, json, sys

sys.stdout.reconfigure(encoding='utf-8')

url = 'https://api.github.com/repos/KDCJT/StealthRec/actions/runs/24515701667/jobs'
req = urllib.request.Request(url, headers={'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'Mozilla/5.0'})
data = json.loads(urllib.request.urlopen(req).read())
job = data['jobs'][0]
print('Job Conclusion:', job['conclusion'])
for step in job['steps']:
    name = step['name'].encode('ascii', errors='replace').decode('ascii')
    conclusion = step['conclusion']
    num = step['number']
    print('  #' + str(num) + ' ' + name + ' => ' + str(conclusion))

# Now download job log
log_url = 'https://api.github.com/repos/KDCJT/StealthRec/actions/jobs/71658915827/logs'
try:
    log_req = urllib.request.Request(log_url, headers={'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'Mozilla/5.0'})
    log_data = urllib.request.urlopen(log_req).read().decode('utf-8', errors='replace')
    # Find key lines
    lines = log_data.split('\n')
    for i, line in enumerate(lines):
        if any(kw in line for kw in ['Building GhostRec', 'error:', 'Binary size', 'CFBundleShortVersionString', 'IPA size', 'du -sh', 'binary']):
            print('LOG:' + line.strip())
except Exception as e:
    print('Log download failed:', e)
