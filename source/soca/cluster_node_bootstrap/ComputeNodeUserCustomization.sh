#!/bin/bash -xe

# User customization code below
source /etc/environment
source /root/config.cfg

if [[ ! -f /root/ComputeNodeUserCustomization.sh.run ]]; then

	USER_HOME=$(eval echo ~$SOCA_DCV_OWNER)

	# Change owner of stable diffusion webui directory
	chown -R $SOCA_DCV_OWNER /shared
	chown -R $SOCA_DCV_OWNER /tmp/gradio

	# change nginx reverse proxy configuration

	SERVER_IP=$(hostname -I)
	SERVER_HOSTNAME=$(hostname)
	SERVER_HOSTNAME_ALT=$(echo $SERVER_HOSTNAME | cut -d. -f1)

	# Configure nginx to use reverse proxy
	echo "Configuring nginx reverse proxy for accesing stable diffusion WebUI ..."
	sed -i "s/ip-0-0-0-0/$SERVER_HOSTNAME_ALT/" /etc/nginx/default.d/stable-diffusion.conf
	systemctl enable nginx
	systemctl start nginx

	FOLDER_NAME=".ifnude"
	SOURCE_PATH="/home/ec2-user/$FOLDER_NAME"

	# Check if the folder exists
	if [ ! -d "$USER_HOME/$FOLDER_NAME" ]; then
	    echo "Copying .ifnude to user's home directory"
	    cp -r "$SOURCE_PATH" "$USER_HOME/$FOLDER_NAME"
	    chown -R $SOCA_DCV_OWNER "$USER_HOME/$FOLDER_NAME"
	fi

	# Change stable diffusion WebUI configuraiton
	echo "Configuring output paths of stable diffusion"
        sed -i "s/"outputs/"\/data\/home\/$SOCA_DCV_OWNER\/stable-diffusion\/$SOCA_JOB_ID\/outputs/" /shared/stable-diffusion-webui/config.json
        sed -i "s/"log/"\/data\/home\/$SOCA_DCV_OWNER\/stable-diffusion\/$SOCA_JOB_ID\/log/" /shared/stable-diffusion-webui/config.json

	# use crontab to start webui

	# Define the new rule
	# NEW_RULE="@reboot cd /shared/stable-diffusion-webui/ && nohup /bin/bash webui.sh --xformers --listen --skip-install --subpath /sd-$SERVER_HOSTNAME_ALT --gradio-auth $SOCA_DCV_OWNER:$SOCA_SD_PASSWORD &"
	COMMAND="cd /shared/stable-diffusion-webui/ && /bin/bash webui.sh --xformers --listen --skip-install --subpath /sd-$SERVER_HOSTNAME_ALT --gradio-auth $SOCA_DCV_OWNER:$SOCA_SD_PASSWORD >> webui.log 2>&1 &"
	NEW_RULE="@reboot $COMMAND"

	# Append the new rule to the existing crontab entries and set the combined list as the new crontab for the user
	(crontab -u $SOCA_DCV_OWNER -l; echo "$NEW_RULE") | crontab -u $SOCA_DCV_OWNER -

	echo "$COMMAND"
	su - $SOCA_DCV_OWNER -c "$COMMAND"

	touch /root/ComputeNodeUserCustomization.sh.run

else
	echo "Customization has been executed before"
fi

# URL of the local web server
URL="http://127.0.0.1:7860/"

# Calculate end time (current time + 10 minutes in seconds)
END_TIME=$(( $(date +%s) + 600 ))

while [ $(date +%s) -lt $END_TIME ]; do
    # Use curl to check the server status
    if curl -s "$URL" > /dev/null; then
        echo "Web server is up!"
	exit 0
    else
        echo "Web server is down!"
    fi

    # Wait for 30 seconds before the next check
    sleep 30
done

echo "Script finished after 10 minutes."

