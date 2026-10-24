"""Only loopback demo Firebase emulators; no service account or live project."""
import json
import urllib.request

PROJECT = 'demo-andi-xix'
def post(url, data):
    request = urllib.request.Request(url, json.dumps(data).encode(),
        headers={'Content-Type':'application/json', 'Authorization':'Bearer owner'})
    return json.load(urllib.request.urlopen(request, timeout=30))
def value(v):
    if isinstance(v, bool): return {'booleanValue':v}
    if isinstance(v, list): return {'arrayValue':{'values':[value(x) for x in v]}}
    return {'stringValue':v}
writes=[]
for role in ['admin', 'editor', 'outsider']:
    result=post('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-andi-xix-key',
        {'email':f'{role}@andi.test','password':'synthetic-only-123','returnSecureToken':True})
    uid=result['localId']
    data={'active':True,'role':'admin' if role=='admin' else 'member','name':f'XIX {role}',
          'email':f'{role}@andi.test','function':'worker','functionIds':['worker'],
          'effectivePermissions':['viewDashboard','viewProgram','editProgram','viewCentralizer','editCentralizer','viewOwnDecont']}
    writes.append({'update':{'name':f'projects/{PROJECT}/databases/(default)/documents/users/{uid}',
        'fields':{k:value(v) for k,v in data.items()}}})
    if role=='editor': editor=uid
writes.append({'update':{'name':f'projects/{PROJECT}/databases/(default)/documents/teams/craiova',
    'fields':{'name':value('Craiova XIX'),'active':value(True),'members':value([editor])}}})
post(f'http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents:commit', {'writes':writes})
print('Seeded three synthetic Auth users and Firestore profiles in demo-andi-xix only.')
