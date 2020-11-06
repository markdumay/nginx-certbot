#!/bin/sh

# Run certbot script and repeat every 12 hours
trap : TERM INT; (while true; do certbot_issue.sh; sleep 12h; done) & wait