import os
import requests
from requests.auth import HTTPBasicAuth
import functions_framework


def poll():

    pat = os.getenv("PAT", "")
    org = os.getenv("ORGANIZATION", "")
    project = os.getenv("PROJECT", "")
    pool_id = os.getenv("POOL_ID", "")

    basic = HTTPBasicAuth("ci", pat)
    req = requests.get('https://dev.azure.com/%s/%s/_apis/distributedtask/queues?api-version=7.1-preview.1' % (org, project), auth=basic)

    if req.status_code == 200:
        print(req.text)

    req = requests.get('https://dev.azure.com/%s/%s/_apis/distributedtask/queues/%d?api-version=7.1-preview.1' % (org, project, pool_id), auth=basic)
    if req.status_code == 200:
        print(req.text)

    req = requests.get('https://dev.azure.com/%s/_apis/distributedtask/pools/%d/jobrequests?api-version=6.0' % (org, pool_id), auth=basic)
    if req.status_code == 200:
        print(req.text)


@functions_framework.http
def poll_agent_jobs(request):
    """HTTP Cloud Function.
    Args:
        request (flask.Request): The request object.
        <https://flask.palletsprojects.com/en/1.1.x/api/#incoming-request-data>
    Returns:
        The response text, or any set of values that can be turned into a
        Response object using `make_response`
        <https://flask.palletsprojects.com/en/1.1.x/api/#flask.make_response>.
    """
    request_json = request.get_json(silent=True)
    request_args = request.args
    print(request)

    if request_json and 'name' in request_json:
        name = request_json['name']
    elif request_args and 'name' in request_args:
        name = request_args['name']
    else:
        name = 'World'
    
    return 'Hello {}!'.format(name)

