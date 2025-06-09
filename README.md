# Mirror Work Commits to Personal Contribution Graph

This repo automates mirroring your private-work commits onto an empty-commit stream in a personal repository so they appear on your contribution graph.

>⚠️ Use at your own risk.  Forging contribution activity breaches GitHub's Acceptable-Use Policy and could violate employer policy.

⸻

How It Works
1.	A scheduled GitHub Action counts the commits you made from your work account in the last 24 h (across all repos you can read) using the Search Commits API.
2.	It generates the same number of --allow-empty commits in this repo.
3.	Those commits use the email you configured, so they register on your personal graph after GitHub's normal propagation delay.

⸻

## 1. Quick-Start

#### 1  Fork / clone this repo
```
# your GitHub account
$ git clone https://github.com/<you>/mirror-work-commit.git
```
####  2  Create required secrets

| Secret name | Where to create it | Purpose | Scope / permissions |
|------------|-------------------|---------|-------------------|
| WORK_PAT | Settings ▸ Secrets ▸ Actions (this repo) | Authenticates the job to read commits from your work account | Fine-grained PAT<br>• Resource owner: your work org/user<br>• Repos: select every repo you want counted, or All repositories if you prefer<br>• Repository permissions:<br>  – Metadata → Read (default)<br>  – Contents → Read |
| PERSONAL_PAT (optional) | Same place | Pushes the forged commits. If omitted, the job falls back to GITHUB_TOKEN, which already has write access to this repo | Fine-grained PAT<br>• Resource owner: you<br>• Repository access: Only this repository<br>• Repository permissions:<br>  – Metadata → Read<br>  – Contents → Read & Write |

Generating a fine-grained PAT
1.	GitHub avatar ▸ Settings ▸ Developer settings ▸ Personal access tokens ▸ Fine-grained tokens ▸ Generate new token.
2.	Follow the table above for the right resource owner & scopes.
3.	Copy the token once and paste it into the secret field.
4.	If your work org uses SAML/SSO, click Configure SSO ▸ Authorize after saving.

#### 3  Edit the workflow defaults

Open `.github/workflows/mirror.yml` and tweak:
```
env:
  WORK_LOGIN: "<your-work-username>"   # e.g. jane_doe          
  AUTHOR_NAME: "<your name>"            # shows in forged commits
  AUTHOR_EMAIL: "<email@personal.com>"  # must be listed on your GitHub profile
```
Cron schedule is 0 3 * * * (17:00 UTC+10 daily). Adjust if you want.

#### 4  Push & run once manually
```
$ git add .
$ git commit -m "bootstrap mirroring"
$ git push origin main
```
In Actions tab, pick mirror-work-commits ▸ Run workflow. This seeds the state and verifies the secrets.

⸻

File Layout
```
.
├── .github/
│   ├── workflows/
│   │   └── mirror.yml        # the Action definition
│   └── scripts/
│       └── mirror.sh         # the bash logic
└── README.md
```
You generally edit only mirror.yml (schedule / env vars) and mirror.sh (if you want extra logic).

⸻

### Limitations
- The current GitHub API's endpoint being used only allows searching up to 1000 commits. This means you can't mirror >1000 commits a day (which is not likely to happen unless you are not human)

### Security Notes  
- Tokens live in GitHub Secrets, redacted in logs.  
- Renew your token when it is about to expire to continure mirroring  
- Use least privilege. The script only needs read on work repos and write on this repo.


### License

MIT. Do whatever you like—at your own risk.