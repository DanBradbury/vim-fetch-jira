inoremap <F6> <C-R>=FindUnresolved()<CR>
inoremap <F7> <C-R>=InsertCommitMessage()<CR>
inoremap <F8> <C-R>=GenerateTeamReport()<CR>

function! GenerateTeamReport()
autocmd CompleteDone * pclose | execute("%s/\r/\r&/ge") | execute("%s/\r//ge") | execute "%s/\n//ge" | execute "normal" "gg\<Esc>"
python << EOF
import vim
import json
import requests
import base64
import re

def generate_report():
  url = vim.eval("g:jiracomplete_url")
  user = vim.eval("g:jiracomplete_username")
  pw = vim.eval("g:jiracomplete_auth")
  team_name = vim.eval("g:jira_team_name")
  sprint_num = vim.eval("g:jira_current_sprint")

  sprint = "sprint"+sprint_num
  auth = base64.b64encode(user+':'+pw)
  query = "jql=labels=%s and labels in (%s)" % (team_name, sprint)
  api_url = "%s/rest/api/2/search?%s" % (url, query)
  headers = {}
  if auth:
    headers['authorization'] = 'Basic ' + auth
  response = requests.get(api_url, headers=headers)
  if response.status_code == requests.codes.ok:
    jvalue = json.loads(response.content)
    issues = jvalue["issues"]
    text = ""
    match = []
    for issue in issues:
      time_estimate = str(issue['fields']['aggregatetimeoriginalestimate'])
      time_spent = str(issue['fields']['aggregatetimespent'])
      if time_estimate != 'None':
          time_estimate = str(float(time_estimate)/28800.0)
      if time_spent != 'None':
          time_spent = str(float(time_spent)/28800.0)
      link = "JIRA link: https://ringrevenue.atlassian.net/browse/"+issue['key']+"\r\r\r"
      summary = issue['key']
      summary = summary.replace("\"", "")
      time_details = issue['key']+": "+issue['fields']['summary']+"\r\rORIGINAL ESTIMATE: "+time_estimate+"\rTIME SPENT: "+time_spent
      if issue['fields']['assignee']:
        time_details += "\rASSIGNED TO: "+ str(issue['fields']['assignee']['displayName'])
      description = time_details
      text += "==================================================================================================\r"+description+"\r\r"
    text += "=================================================================================================="
    vim.command(":normal i"+text)
  else:
    vim.command("return \"Error: " + response.reason + "\"")
EOF
py generate_report()
return ''
endfunction

function! InsertCommitMessage()
let contents=get(readfile('.git/HEAD'),0, '')
python << EOF
import vim
import json
import requests
import base64
import re

def filter_branch():
  branch = vim.eval("contents")
  branch = branch.replace("refs/heads/", "").replace("ref: ", "")
  splits = branch.split("/")
  #vim.command("echo '"+splits[0]+"'")

  url = vim.eval("g:jiracomplete_url")
  user = vim.eval("g:jiracomplete_username")
  pw = vim.eval("g:jiracomplete_auth")
  auth = base64.b64encode(user+':'+pw)

  query = "jql=assignee=%s+and+resolution=unresolved" % user
  api_url = "%s/rest/api/2/search?%s" % (url, query)
  headers = {}
  if auth:
      headers['authorization'] = 'Basic ' + auth
  response = requests.get(api_url, headers=headers)
  if response.status_code == requests.codes.ok:
      jvalue = json.loads(response.content)
      issues = jvalue['issues']
      match = []
      for issue in issues:
          if issue['fields']['description']:
              summary = issue['key']+" "+issue['fields']['summary']+" : "
              summary = summary.replace("\"", "")
              match.append('{"word": "%s", "abbr":"%s"}' %
              (splits[0]+" "+summary, issue['key']))
      command = 'call complete(col("."), [' + ",".join(match) + '])'
      vim.command(command)
  else:
      vim.command("return \"Error: " + response.reason + "\"")
EOF
py filter_branch()
return ''
endfunction

" Search your Assigned & Unresolved Issues and get relevant information
function! FindUnresolved()
autocmd CompleteDone * pclose | execute("%s/\r/\r&/ge") | execute("%s/\r//ge") | execute "%s/\n//ge" | execute "normal" "gg\<Esc>"

python << EOF
import vim
import json
import requests
import base64
import re

def get_unresolved():
    url = vim.eval("g:jiracomplete_url")
    user = vim.eval("g:jiracomplete_username")
    pw = vim.eval("g:jiracomplete_auth")
    auth = base64.b64encode(user+':'+pw)

    query = "jql=assignee=%s+and+resolution=unresolved" % user
    api_url = "%s/rest/api/2/search?%s" % (url, query)
    headers = {}
    if auth:
        headers['authorization'] = 'Basic ' + auth
    response = requests.get(api_url, headers=headers)
    if response.status_code == requests.codes.ok:
        jvalue = json.loads(response.content)
        issues = jvalue['issues']
        match = []
        match.append("{'word':'NONE', 'info':'PLACEHOLDER'}")
        for issue in issues:
            if issue['fields']['description']:
                time_estimate = str(issue['fields']['aggregatetimeoriginalestimate'])
                time_spent = str(issue['fields']['timespent'])
                if time_estimate != 'None':
                    time_estimate = str(float(time_estimate)/28800.0)
                if time_spent != 'None':
                    time_spent = str(float(time_spent)/28800.0)
                link = "JIRA link: https://ringrevenue.atlassian.net/browse/"+issue['key']+"\r\r\r"
                summary = issue['key']+": "+issue['fields']['summary']+"\rORIGINAL ESTIMATE: "+time_estimate+"\rTIME SPENT: "+time_spent+"\r"
                summary = summary.replace("\"", "")
                des = issue['fields']['description'].encode('ascii', 'replace')
                description = link+summary+des.replace("\"", "").replace("\'","")
                match.append('{"word": "%s", "abbr":"%s", "info":"%s"}' %
                (description, issue['key'], summary))
        command = 'call complete(col("."), [' + ",".join(match) + '])'
        vim.command(command)
    else:
        vim.command("return \"Error: " + response.reason + "\"")
EOF
py get_unresolved()
return ''
endfunction

