#!/bin/bash

# Only runs if 'Jupyter' is found in Portal configuration - Otherwise we let /.launch run as normal
# This method of startup is useful because:
# 1) It's user-configurable
# 2) it uses our venv's python binary by default
# 3) We get unauthenticated access without TLS via SSH forwarding 
# 4) it gives us a shell in Args runtype

[[ ${AUTOSCALER,,} = 'true' ]] && echo "Refusing to start ${PROC_NAME} (AUTOSCALER=true)" | tee -a "/var/log/portal/${PROC_NAME}.log" && exit
[[ $OPEN_BUTTON_PORT != "1111" ]] && echo "Refusing to start ${PROC_NAME} (OPEN_BUTTON_PORT!=1111)" | tee -a "/var/log/portal/${PROC_NAME}.log" && exit
[[ -z $VAST_TCP_PORT_8080 ]] && echo "Refusing to start ${PROC_NAME} (VAST_TCP_PORT_8080 not set)" | tee -a "/var/log/portal/${PROC_NAME}.log" && exit
[[ -f /.launch ]] && grep -qi jupyter /.launch &&  echo "Refusing to start ${PROC_NAME} (/.launch managing)" | tee -a "/var/log/portal/${PROC_NAME}.log" && exit

# User can configure startup by removing the reference in /etc.portal.yaml - So wait for that file and check it
while [ ! -f "$(realpath -q /etc/portal.yaml 2>/dev/null)" ]; do
    echo "Waiting for /etc/portal.yaml before starting ${PROC_NAME}..." | tee -a "/var/log/portal/${PROC_NAME}.log"
    sleep 1
done

# rudimentary check for jupyter in the portal config
search_pattern=$(echo "$PROC_NAME" | sed 's/[ _-]/[ _-]/g')
if ! grep -qiE "^[^#].*${search_pattern}" /etc/portal.yaml; then
    echo "Skipping startup for ${PROC_NAME} (not in /etc/portal.yaml)" | tee -a "/var/log/portal/${PROC_NAME}.log"
    exit 0
fi

type="${JUPYTER_TYPE:-notebook}"

# Ensure the default Python used by Jupyter is our venv
# Token not specified because auth is handled through Caddy
. ${DATA_DIR}venv/main/bin/activate
jupyter "${type,,}" \
        --allow-root \
        --ip=127.0.0.1 \
        --port=18080 \
        --no-browser \
        --IdentityProvider.token='' \
        --ServerApp.password='' \
        --ServerApp.trust_xheaders=True \
        --ServerApp.disable_check_xsrf=False \
        --ServerApp.allow_remote_access=True \
        --ServerApp.allow_origin='*' \
        --ServerApp.allow_credentials=True \
        --ServerApp.root_dir=/ \
        --ServerApp.preferred_dir="$DATA_DIR" \
        --ServerApp.terminado_settings="{'shell_command': ['/bin/bash']}" \
        --ContentsManager.allow_hidden=True \
        --KernelSpecManager.ensure_native_kernel=False 2>&1 | tee -a "/var/log/portal/${PROC_NAME}.log"