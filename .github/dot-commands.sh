.bitbot.audit gh run list --json database,headBranch,status --limit 50 > .bithub/loop-state.json
.bitbot.compliance opa eval --format pretty --data .bit/policy --input .bit/context.json "data.bithub.allow"
.bithub.sync git clone --depth=1 https://github.com/Doctor0Evil/Bit.Hub.git tmpbithub && rsync -av --ignore-existing tmpbithub/.bithubpolicy .bithubpolicy && rsync -av --ignore-existing tmpbithub/.bitschemas .bitschemas
.bithub.protect actions/upload-artifact@v4 --name bithub-loop-state --path .bithub/loop-state.json
.bithub.meta ./github/workflows/bit-hub-meta-corrector-v3.yml --autofix true --powerthreshold paranoid --targetref main
.bithub.deploy gh workflow run "Bit.Hub Secure CD Supremacy Progressive Delivery" -f environment=production -f powerthreshold=paranoid
.bithub.cache actions/upload-artifact@v4 --name compliance-report --path compliance-report.json
