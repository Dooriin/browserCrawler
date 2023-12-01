#!/bin/bash

# Select a random user agent from the USER_AGENTS environment variable
IFS=';' read -ra UA_ARRAY <<EOF
$USER_AGENTS
EOF
SELECTED_UA=${UA_ARRAY[$RANDOM % ${#UA_ARRAY[@]}]}

# Export the selected user agent so the crawler can use it
export SELECTED_UA

# Get UID/GID from volume dir
VOLUME_UID=$(stat -c '%u' /crawls)
VOLUME_GID=$(stat -c '%g' /crawls)

# Get the UID/GID we are running as
MY_UID=$(id -u)
MY_GID=$(id -g)

# Function to run the crawler and post processing
run_crawler_and_post_process() {
    # Run the crawler command
    crawl "$@"

    # After crawler finishes, run the post processing script
    node /app/post_crawl_processing.cjs
}

# If we aren't running as the owner of the /crawls/ dir then add a new user
# btrix with the same UID/GID of the /crawls dir and run as that user instead.
if [ "$MY_GID" != "$VOLUME_GID" ] || [ "$MY_UID" != "$VOLUME_UID" ]; then
    groupadd btrix
    groupmod -o --gid $VOLUME_GID btrix

    useradd -ms /bin/bash -g $VOLUME_GID btrix
    usermod -o -u $VOLUME_UID btrix > /dev/null

    su btrix -c 'run_crawler_and_post_process "$@"' -- argv0-ignore "$@"
else
    # Directly run the crawler and post processing
    run_crawler_and_post_process "$@"
fi
