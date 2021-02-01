#!/bin/sh

# Run certbot script and repeat every 12 hours
trap : TERM INT; id; certbot_issue.sh init; (while true; do certbot_issue.sh run; sleep 12h; done) & wait