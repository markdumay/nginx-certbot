#!/bin/sh

# Run certbot script and repeat every 12 hours
trap : TERM INT; certbot_issue.sh init || exit 1; (while true; do certbot_issue.sh run; sleep 12h; done) & wait