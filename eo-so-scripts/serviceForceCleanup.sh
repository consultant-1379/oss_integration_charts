#!/bin/bash

#******************************************************************************
#* COPYRIGHT Ericsson 2021
#*
#*
#*
#* The copyright to the computer program(s) herein is the property of
#*
#* Ericsson Inc. The programs may be used and/or copied only with written
#*
#* permission from Ericsson Inc. or in accordance with the terms and
#*
#* conditions stipulated in the agreement/contract under which the
#*
#* program(s) have been supplied.
#******************************************************************************

START_TIMESTAMP=$(date -Iseconds | sed 's/:/_/g')
unset OVERRIDDEN_KUBECTL

function isSourced() {
  THIS_FILE=$(basename "${BASH_SOURCE[0]}")
  if tr '\0' '\n' < /proc/$$/cmdline | grep -q "$THIS_FILE"; then
    return 1
  else
    return 0
  fi
}

function warningMessage() {
  echo
  CAUTION_MESSAGE=" USE WITH CAUTION! "
  TERMINAL_WIDTH=$(tput -T xterm cols)
  STAR_COUNT=$(((TERMINAL_WIDTH - ${#CAUTION_MESSAGE}) / 2))
  STAR_SEGMENT="$(head -c "$STAR_COUNT" < /dev/zero | tr "\0" "*")"
  STAR_LINE="$STAR_SEGMENT$CAUTION_MESSAGE$STAR_SEGMENT"

  FIRST_LINE="This script will forcibly delete exactly one non-active service"
  TEXT_PADDING_WIDTH=$((((TERMINAL_WIDTH - ${#FIRST_LINE}) / 2) - 1))
  TEXT_PADDING="$(head -c "$TEXT_PADDING_WIDTH" < /dev/zero | tr "\0" " ")"

  echo "$STAR_LINE"
  echo
  echo "${TEXT_PADDING} $FIRST_LINE"
  echo "${TEXT_PADDING} from Service Orchestration only! This may result in major problems,"
  echo "${TEXT_PADDING} system inconsistency, etc., for example, if the deleted service had"
  echo "${TEXT_PADDING} data associated with it in a connected NFVO or Domain Manager subsystem."
  echo
  echo "$STAR_LINE"
  echo
}

function getUsername() {
  if ps -o user= -p $$ &>/dev/null; then
    ps -o user= -p $$ | awk '{print $1}'
  else
    whoami
  fi
}

function usage() {
  warningMessage
  echo "Workaround Script to forcibly delete a failed or stuck Service from Service Orchestration and clean out its dependent resources."
  echo "The Service must not be in Active state or part of a hierarchy of Services (check in Service Orchestration GUI first)."
  echo
  echo "Output will be saved in a log file at ${BASH_SOURCE[0]}_$(getUsername)_<timestamp>.log (default), or a path specified with the --logFile parameter."
  echo
  echo "  USAGE:"
  echo "  ${BASH_SOURCE[0]} --serviceName <service name> --tenantName <tenant name> --namespace <Kubernetes namespace> [--logFile <path/to/log/file>] [--overrideKubectl '<substituteForKubectl>']"
  echo
  echo -e "\tPARAMETERS:"
  echo -e "\t\t--serviceName:     (required) Name of service to delete, as displayed in the EO-SO GUI"
  echo -e "\t\t--tenantName:      (required) Name of the EO-SO tenant from which to delete the service"
  echo -e "\t\t--namespace:       (required) Kubernetes namespace in which EO-SO is installed"
  echo -e "\t\t--logFile:         (optional) File to log script output"
  echo -e "\t\t-d --debug:        (optional) Enable DEBUG log level; also dump output from kubectl port-forwards and some curl commands into logs and console"
  echo -e "\t\t--overrideKubectl: (optional) Substitute command to override local Kubectl - for example, a docker run command for a Dockerized Kubectl image. WARNING: NOT SUPPORTED ON WINDOWS ENVIRONMENTS."
  echo -e "\t\t-h --help: Display this help message and exit"
  echo
}

function log() {
  LEVEL="\e[34mINFO\e[0m"

  case "$1" in
    DEBUG|debug)
    if [[ $DEBUG_OUTPUT ]]; then
      LEVEL="\e[36mDEBUG\e[0m"
      shift
    else
      return
    fi
    ;;
    WARN|warn)
    LEVEL="\e[33mWARN\e[0m"
    shift
    ;;
    ERROR|error)
    LEVEL="\e[31mERROR\e[0m"
    shift
    ;;
  esac

  LINE_PORTION=$(
    if [[ -n $LINE_NUMBER ]]; then
      echo " - {line: $LINE_NUMBER}"
    else
      echo " - {line: ${BASH_LINENO[0]}}"
    fi
  )

  if [[ -n $LOG_USERNAME ]]; then
    LOG_USERNAME_PORTION=" - (User: $LOG_USERNAME)"
  else
    unset LOG_USERNAME_PORTION
  fi

  LOGGED_STRING=" - $*"

  echo -e "$(date -Ins | sed 's/,\(...\).*\(\+.*\)/.\1\2/' | tr 'T' ' ') - [$LEVEL]$LINE_PORTION$LOG_USERNAME_PORTION$LOGGED_STRING"
  unset LOGGED_STRING
}

function logDebug() {
  LINE_NUMBER="${BASH_LINENO[0]}" log debug "$@"
}

function logError() {
  LINE_NUMBER="${BASH_LINENO[0]}" log error "$@"
}

function logWarn() {
  LINE_NUMBER="${BASH_LINENO[0]}" log warn "$@"
}

#********************************************
# Call with a string argument giving a reason
# for reverting to the default log file.
#********************************************
function revertToDefaultLogFile() {
  REASON_MESSAGE="$1"
  logWarn "$REASON_MESSAGE - reverting to default log file."
  LOG_FILE="${BASH_SOURCE[0]}"'_'"$(getUsername)"'_'"$START_TIMESTAMP"'.log'
  logWarn "Output will be saved to $LOG_FILE"
}

function separator() {
    if [[ $1 ]]; then
      case "$1" in
      WARN|warn)
      COLOUR="\e[33m"
      ;;
      ERROR|error)
      COLOUR="\e[31m"
      ;;
      esac
    else
      COLOUR="\e[37m"
    fi
    echo -e "\n$COLOUR$(head -c "$(tput -T xterm cols)" < /dev/zero | tr "\0" "-")\e[0m"
}

function errorSeparator() {
    separator error
}

function cleanUpForked() {
  TEE_LOG_FILE="${LOG_FILE//+/\\+}"
  if pgrep -f "" &>/dev/null; then
    pgrep -f "port-forward (statefulset/eric-sec-access-mgmt $KEYCLOAK_PORT:8080|deployment/(eric-eo-eai $EAI_PORT:8080|toscao $TOSCAO_PORT:7001|eric-eo-workflow $WORKFLOW_PORT:8080|eric-eo-ipaddress-manager $IPAM_PORT:8080))|tee $TEE_LOG_FILE" \
    | while read -r fork; do
      kill "$fork"
    done
  else
    wmic process where "name like '%kubectl%' or name like '%tee%'" get processid,commandline \
    | grep -E "port-forward (statefulset/eric-sec-access-mgmt $KEYCLOAK_PORT:8080|deployment/(eric-eo-eai $EAI_PORT:8080|toscao $TOSCAO_PORT:7001|eric-eo-workflow $WORKFLOW_PORT:8080|eric-eo-ipaddress-manager $IPAM_PORT:8080))|tee $TEE_LOG_FILE" \
    | awk '{print $12}' \
    | while read -r fork; do
        taskkill -F -PID "$fork" &>/dev/null
      done
  fi
}

function soLogout() {
  unset SO_PASSWORD
  [[ $eric_sec_access_mgmt && $CLIENT_ID && $CLIENT_SECRET_VALUE && $SO_USERNAME && $REFRESH_TOKEN && $KEYCLOAK_HOSTNAME ]] && {
    separator
    log "Logging $SO_USERNAME out of SO"
    LOGOUT_RESPONSE=$(\
                      curl -i -s --request POST "$eric_sec_access_mgmt"'/auth/realms/master/protocol/openid-connect/logout' \
                          --header 'Host: '"$KEYCLOAK_HOSTNAME" \
                          --header 'Content-Type: application/x-www-form-urlencoded' \
                          --data-urlencode 'client_id='"$CLIENT_ID" \
                          --data-urlencode 'client_secret='"$CLIENT_SECRET_VALUE" \
                          --data-urlencode 'refresh_token='"$REFRESH_TOKEN"
    ) || {
      logWarn "Error encountered contacting Keycloak microservice (eric-sec-access-mgmt) to log out."
      logWarn "$SO_USERNAME""'s session may need to be logged out manually in the Keycloak Administration Console."
    }

    if echo "$LOGOUT_RESPONSE" | grep -Eq 'HTTP/.* 204 No Content'; then
      log "Logged out"
    else
      logWarn "Issue logging out: $LOGOUT_RESPONSE"
      logWarn "$SO_USERNAME""'s session may need to be logged out manually in the Keycloak Administration Console."
    fi
    unset SO_USERNAME
  }
}

function kubectl() {
  LOCAL_KUBECTL="maybe"
  KUBE_COMMAND=$(which kubectl)
  [[ -n $OVERRIDDEN_KUBECTL && $OVERRIDDEN_KUBECTL != "kubectl" ]] && {
    unset LOCAL_KUBECTL
    KUBE_COMMAND="$OVERRIDDEN_KUBECTL"
    if [[ $OVERRIDDEN_KUBECTL = "docker run"* ]]; then
      KUBE_COMMAND="${KUBE_COMMAND//--env/--env KUBE_EDITOR --env}"
      KUBE_COMMAND="${KUBE_COMMAND// -e / -e KUBE_EDITOR -e }"
    fi
  }

  if [[ -n $LOCAL_KUBECTL ]]; then
    [[ -n $NAMESPACE ]] && "${KUBE_COMMAND}" -n "$NAMESPACE" "$@"
  else
    [[ -n $NAMESPACE ]] && ${KUBE_COMMAND} -n "$NAMESPACE" "$@"
  fi
}

function kubectlPortForward() {
  PORT_FORWARDING_COMMAND=$(
    if [[ -n $OVERRIDDEN_KUBECTL \
          && $OVERRIDDEN_KUBECTL = "docker run"* \
          && "$2" = *":"* ]]; then

      PORT_EXPOSURE="$(echo "$2" | awk -F ':' '{print $1}')"

      echo "${OVERRIDDEN_KUBECTL//docker run /docker run -p 0.0.0.0:$PORT_EXPOSURE:$PORT_EXPOSURE }"
    else
      echo kubectl
    fi
  )
  [[ -n $NAMESPACE ]] \
  && ${PORT_FORWARDING_COMMAND} --address 0.0.0.0 -n "$NAMESPACE" port-forward "$@"
}

function randomFreePort() {
  if ss -lat &>/dev/null; then
    USED_PORTS=$(\
                    ss -lat \
                  | awk '{print $4}' \
                  | sed 's/.*://' \
                  | grep -v Local
                )
  else
    USED_PORTS=$(\
                    netstat -ano \
                  | grep -E "LISTEN[[:space:]]|ESTABLISHED" \
                  | awk '{print $4}' \
                  | sed 's/.*://'
                )
  fi

  FREE_PRIVATE_PORT=$(shuf -i 49152-65535 -n 1) &&
  while echo "$USED_PORTS" | grep -q "$FREE_PRIVATE_PORT"; do
    FREE_PRIVATE_PORT=$(shuf -i 49152-65535 -n 1)
  done
  echo "$FREE_PRIVATE_PORT"
}

while [ -n "$1" ]; do
  XCASE=$( echo "$1" | tr "[:lower:]" "[:upper:]" )
  case $XCASE in
    --SERVICENAME)
      shift
      SERVICE_NAME="$1"
      ;;
    --TENANTNAME)
      shift
      TENANT_NAME="$1"
      ;;
    --NAMESPACE)
      shift
      NAMESPACE="$1"
      ;;
    --LOGFILE)
      shift
      LOG_FILE="$1"
      ;;
    --OVERRIDEKUBECTL)
      shift
      OVERRIDDEN_KUBECTL="$1"
      ;;
    -Y|--ANSWERYES)
      Y_OR_N='Y'
      ;;
    -D|--DEBUG)
      DEBUG_OUTPUT="active"
      function curl() {
        $(which curl) -vvv "$@"
      }
      ;;
    -H|--HELP)
      usage
      exit
      ;;
    *)
      usage
      exit
      ;;
  esac
  shift
done

isSourced && return

if [[ -z $LOG_FILE ]]; then
  # use default log file in same directory as script -
  # construct from location, username, and timestamp when it was run
  #*****************************************************************
  LOG_FILE="${BASH_SOURCE[0]}"'_'"$(getUsername)"'_'"$START_TIMESTAMP"'.log'
else
  if [[ -d $LOG_FILE ]] || echo "$LOG_FILE" | grep -E '/$'; then
    # user set log file to a directory
    # revert to default log file
    #*********************************
    revertToDefaultLogFile "$LOG_FILE is a directory"
  fi

  # user set log file to one in a directory that doesn't (yet) exist
  # try and create it - revert to default log file if we fail
  #*****************************************************************
  LOG_DIRECTORY=$(dirname "$LOG_FILE")
  if [[ ! -d "$LOG_DIRECTORY" ]]; then
    log "Directory $LOG_DIRECTORY does not exist - attempting to create it."

    if mkdir -p "$LOG_DIRECTORY"; then
      log "Success"
    else
      revertToDefaultLogFile "Failed to create directory $LOG_DIRECTORY"
    fi
  fi

  touch "$LOG_FILE" || revertToDefaultLogFile "Failed to create log file $LOG_FILE"
fi

# set up a named pipe
#********************
tmp_logfile=/tmp/$$.tmp
mknod $tmp_logfile p

# tee named pipe into log file and out to console
#************************************************
tee <$tmp_logfile "$LOG_FILE" &

# redirect all output to tmp_logfile
#***********************************
exec &> $tmp_logfile

# set up trap on the exit signal to:
#   - log out of Keycloak if we need to
#   - kill forked logging and kubectl port-forward processes
#   - remove named-pipe intermediate log file
#   - make log file read-only
#***********************************************************
trap 'soLogout; separator; log "This output has been saved to $LOG_FILE"; cleanUpForked; rm -f $tmp_logfile; chmod 444 "$LOG_FILE"' EXIT

if [[ -z $SERVICE_NAME ]]; then
  errorSeparator
  logError "Required parameter missing! Please add the --serviceName parameter to specify the service you want to delete."
  errorSeparator
  usage
  exit 1
fi

if [[ -z $TENANT_NAME ]]; then
  errorSeparator
  logError "Required parameter missing! Please add the --tenantName parameter to specify the tenant in EO-SO from which you are deleting the service."
  errorSeparator
  usage
  exit 1
fi

if [[ -z $NAMESPACE ]]; then
  errorSeparator
  logError "Required parameter missing! Please add the --namespace parameter to allow Kubectl access to your EO-SO installation."
  errorSeparator
  usage
  exit 1
fi

warningMessage
separator


#***************************************************************************
# Connect to required SO pods via several asynchronous kubectl port-forwards
#***************************************************************************

PORT_FORWARD_HOST='localhost'
PORT_FORWARD_LOG=$(
  if [[ $DEBUG_OUTPUT ]]; then
    echo "$tmp_logfile"
  else
    echo '/dev/null'
  fi
)
[[ -n $OVERRIDDEN_KUBECTL && $OVERRIDDEN_KUBECTL = "docker run"* ]] \
    && PORT_FORWARD_HOST='host.docker.internal'

KEYCLOAK_PORT=$(randomFreePort)
eric_sec_access_mgmt="http://$PORT_FORWARD_HOST:$KEYCLOAK_PORT"
kubectlPortForward statefulset/eric-sec-access-mgmt "$KEYCLOAK_PORT":8080 \
          &>>"$PORT_FORWARD_LOG" \
          &
log "Connecting $eric_sec_access_mgmt to Keycloak microservice"

EAI_PORT=$(randomFreePort)
eric_eo_eai="http://$PORT_FORWARD_HOST:$EAI_PORT"
kubectlPortForward deployment/eric-eo-eai "$EAI_PORT":8080 \
          &>>"$PORT_FORWARD_LOG" \
          &
log "Connecting $eric_eo_eai to EAI microservice"

TOSCAO_PORT=$(randomFreePort)
toscao="http://$PORT_FORWARD_HOST:$TOSCAO_PORT"
kubectlPortForward deployment/toscao "$TOSCAO_PORT":7001 \
          &>>"$PORT_FORWARD_LOG" \
          &
log "Connecting $toscao to TOSCA-O microservice"

WORKFLOW_PORT=$(randomFreePort)
eric_eo_workflow="http://$PORT_FORWARD_HOST:$WORKFLOW_PORT"
kubectlPortForward deployment/eric-eo-workflow "$WORKFLOW_PORT":8080 \
          &>>"$PORT_FORWARD_LOG" \
          &
log "Connecting $eric_eo_workflow to Workflow microservice"

IPAM_PORT=$(randomFreePort)
eric_eo_ipaddress_manager="http://$PORT_FORWARD_HOST:$IPAM_PORT"
kubectlPortForward deployment/eric-eo-ipaddress-manager "$IPAM_PORT":8080 \
          &>>"$PORT_FORWARD_LOG" \
          &
log "Connecting $eric_eo_ipaddress_manager to IPAM microservice"


# Wait for the port-forwards to take - CONNECTION_WAIT_PERIOD and RETRIES may be
# increased in case of slow network connections
#*******************************************************************************
echo
[[ $CONNECTION_WAIT_PERIOD ]] || CONNECTION_WAIT_PERIOD=2
[[ $RETRIES ]] || RETRIES=10
log "Waiting for microservice connections - will try $RETRIES times..."
RETRIES_LEFT=$RETRIES
until curl -s -o "$PORT_FORWARD_LOG" "$eric_sec_access_mgmt"'/auth/realms/master' \
   && curl -s -o "$PORT_FORWARD_LOG" "$eric_eo_eai" \
   && curl -s -o "$PORT_FORWARD_LOG" "$toscao"'/toscao/api/v2.4/' \
   && curl -s -o "$PORT_FORWARD_LOG" "$eric_eo_workflow"'/engine-rest/process-instance' \
   && curl -s -o "$PORT_FORWARD_LOG" "$eric_eo_ipaddress_manager"; do

  [[ $RETRIES_LEFT = 0 ]] && {
    errorSeparator
    logError "Could not connect to required EO-SO microservices."
    logError "Please ensure ALL of the required Kubernetes objects have their full quota of pods ready ("
    logError "\tkubectl -n '$NAMESPACE' get statefulset/eric-sec-access-mgmt deployment/eric-eo-eai deployment/toscao deployment/eric-eo-workflow deployment/eric-eo-ipaddress-manager"
    logError ")"
    logError "Additionally, verify the Kubernetes namespace you entered, \"$NAMESPACE\""
    logError "Otherwise, please ensure you have kubectl access to the namespace and try again."
    logError
    logError "If you suspect your network connection is slow enough for kubectl port-forwards to take longer to connect, please increase the CONNECTION_WAIT_PERIOD and RETRIES variables ("
    logError "\t$ export CONNECTION_WAIT_PERIOD=<more than $CONNECTION_WAIT_PERIOD>"
    logError "\t$ export RETRIES=<more than $RETRIES>"
    logError "), and try again."
    errorSeparator
    exit 1
  }

  echo -en "Will try $RETRIES_LEFT more time$([[ $RETRIES_LEFT -gt 1 ]] && echo -n 's')\033[0K\r"
  RETRIES_LEFT=$((RETRIES_LEFT - 1))
  sleep $CONNECTION_WAIT_PERIOD
done
log "Connections established"


#******************************
# Authenticate with SO Keycloak
#******************************

REQUIRED_ROLE="SOProviderAdmin"

separator

echo
echo "Please log in to an SO user account with the $REQUIRED_ROLE role"
echo
echo "Enter SO username:"
read -r SO_USERNAME;
echo "Enter SO password:"
read -rs SO_PASSWORD;
echo
log "Authenticating with Keycloak"

OAUTH_CREDENTIALS=$(\
  kubectl describe deployment/eric-eo-api-gateway\
) || {
  errorSeparator
  logError "Error encountered contacting API Gateway (eric-eo-api-gateway) to begin login."
  logError "Please resolve any issues encountered by the preceding kubectl describe command, and rerun this script."
  logError "If this error occurs again, ensure the eric-eo-api-gateway microservice is healthy and can be contacted by kubectl describe, and rerun this script."
  logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
  errorSeparator
  exit 1
}
KEYCLOAK_HOSTNAME=$(
    kubectl get ingress eric-sec-access-mgmt-ingress --no-headers | awk '{print $3}'
) || {
  errorSeparator
  logError "Error encountered obtaining Keycloak hostname (ingress/eric-sec-access-mgmt-ingress) to begin login."
  logError "Please resolve any issues encountered by the preceding kubectl get command, and rerun this script."
  logError "If this error occurs again, ensure the eric-sec-access-mgmt-ingress object is present on the Kubernetes cluster, and rerun this script."
  logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
  errorSeparator
  exit 1
}

OAUTH_CREDENTIALS=$(echo "$OAUTH_CREDENTIALS" | grep -E 'CLIENT_(ID|SECRET)')
CLIENT_ID=$(\
              echo "$OAUTH_CREDENTIALS" \
            | grep 'CLIENT_ID' \
            | awk '{print $2}'\
          )
CLIENT_SECRET_NAME=$(\
                        echo "$OAUTH_CREDENTIALS" \
                      | grep 'CLIENT_SECRET' \
                      | grep -Eo "in secret '.*'" \
                      | awk -F "'" '{print $2}'\
                    )
CLIENT_SECRET_VALUE=$(\
                        KUBE_EDITOR="cat" kubectl edit secret "$CLIENT_SECRET_NAME" 2>/dev/null \
                      | grep ' clientSecret' \
                      | awk '{print $2}' \
                      | base64 -d\
                    )

AUTH_RESPONSE=$(\
                  curl -i -s --request POST "$eric_sec_access_mgmt"'/auth/realms/master/protocol/openid-connect/token' \
                  --header 'Host: '"$KEYCLOAK_HOSTNAME" \
                  --header 'Content-Type: application/x-www-form-urlencoded' \
                  --data-urlencode 'grant_type=password' \
                  --data-urlencode 'client_id='"$CLIENT_ID" \
                  --data-urlencode 'client_secret='"$CLIENT_SECRET_VALUE" \
                  --data-urlencode 'username='"$SO_USERNAME" \
                  --data-urlencode 'password='"$SO_PASSWORD"\
) || {
  errorSeparator
  logError "Error encountered contacting Keycloak microservice (eric-sec-access-mgmt) to log in."
  logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
  logError "If this error occurs again, ensure the eric-sec-access-mgmt microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
  logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
  errorSeparator
  exit 1
}
unset SO_PASSWORD

AUTH_STATUS=$(echo "$AUTH_RESPONSE" | grep "HTTP/")
[[ $AUTH_STATUS = *"401 Unauthorized"* ]] && {
  unset SO_USERNAME
  errorSeparator
  logError "Login failed - 401 Unauthorized"
  errorSeparator
  logError "Authentication failed - username or password incorrect"
  errorSeparator
  exit 1
}
[[ $AUTH_STATUS = *"200 OK"* ]] || {
  unset SO_USERNAME
  errorSeparator
  logError "Authentication failed due to unexpected response from Keycloak: $AUTH_RESPONSE"
  logError "Please check the username and password, verify that the eric-sec-access-mgmt microservice is healthy and can be contacted by kubectl port-forward, and try again."
  errorSeparator
  exit 1
}

LOG_USERNAME="$SO_USERNAME"
log "Logged in as $SO_USERNAME"
REFRESH_TOKEN=$(\
                  echo "$AUTH_RESPONSE" \
                | tr ',' '\n' \
                | grep '"refresh_token"' \
                | awk -F '"' '{print $4}'\
              )

# Login succeeded and included a list of user's roles in response - parse that out
# and check for the required role to be allowed to force-delete
#*********************************************************************************
log "Verifying user roles"

ROLES_TOKEN=$(\
                echo "$AUTH_RESPONSE" \
              | tr ',' '\n' \
              | grep '"access_token"' \
              | awk -F '.' '{print $2}' \
              | tr '\n' '\0' \
              | base64 -d 2>/dev/null\
            )
echo "$ROLES_TOKEN" \
| tr '{]' '\n' \
| grep '"roles"' \
| grep -q "$REQUIRED_ROLE" || {

  errorSeparator
  logError "Authentication failed - user does not have the required role to perform this operation"
  errorSeparator
  exit 1
}


#********************************************************************************************
# Retrieve service data from EAI - will be used again further down as well as in EAI deletion
#********************************************************************************************
declare -a EAI_HEADERS=(\
                        --header 'Authorization: Basic c3lzYWRtOg==' \
                        --header 'GS-Database-Host-Name: localhost' \
                        --header 'GS-Database-Name: install' \
                        --header 'Content-Type: application/json'\
                      )

separator
log "Retrieving service data..."
SERVICE_DATA=$(\
  curl -i --request GET "${EAI_HEADERS[@]}" "$eric_eo_eai"'/oss-core-ws/rest/eso/service?fs.resources&fs.resources.context&fs.resources.context.inputs&fs.resources.subsystemref&fs.actions&fs.serviceGrouping&fs.serviceGroupedBy&name='"$SERVICE_NAME"'&tenantName='"$TENANT_NAME"\
) || {
  errorSeparator
  logError "Error encountered contacting EAI microservice (eric-eo-eai) to get service details."
  logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
  logError "If this error occurs again, ensure the eric-eo-eai microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
  logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
  errorSeparator
  exit 1
}
STATUS=$(echo "$SERVICE_DATA" | grep "HTTP/")

# Pre-deletion checks on retrieved data:
# check request status was 200 OK...
#***************************************
if [[ $STATUS = *"200 OK"* ]]; then

  # ...retrieved service list isn't empty...
  #*****************************************
  if [[ "$SERVICE_DATA" = *"[ ]" ]]; then
    errorSeparator
    logError "Service with name \"$SERVICE_NAME\" not found in tenant \"$TENANT_NAME\"."
    logError "Please check the values for the --serviceName and --tenantName parameters, and rerun this script."
    errorSeparator
    exit 1
  fi
  # ...and service isn't in Active state...
  #****************************************
  if echo "$SERVICE_DATA" | grep -E '^  "state" ?: ?"Active"'; then
    errorSeparator
    logError "Service $SERVICE_NAME is in Active state - try deleting it through the EO SO GUI before using this script."
    errorSeparator
    exit 1
  fi
  # ...and service isn't part of a hierarchy.
  #******************************************
  if echo "$SERVICE_DATA" \
    | grep -E '"(serviceGroupedBy|serviceGrouping)" ?: ?\['; then
    errorSeparator
    logError "Service $SERVICE_NAME is part of a hierarchy of services. Cleanup of such services is not supported due to increased potential of data loss. Please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  fi


  HREFS=$(echo "$SERVICE_DATA" | grep "href")
  SERVICE_HREF=$(\
                    echo "$HREFS" \
                  | grep "/service/" \
                  | awk -F "\"" '{print $4}'\
                )
else
  errorSeparator
  logError "Failed to get service from EAI: $SERVICE_DATA"
  errorSeparator
  exit 1
fi


#********************************
# Confirm details before deletion
#********************************

separator
echo -e "\e[1;31m"
echo -e "You are about to delete the following service and all its data from EO SO only:"
echo -e "\tService Name:\t\t$SERVICE_NAME"
echo -e "\tEO SO Tenant:\t\t$TENANT_NAME"
echo -e "\tKubernetes Namespace:\t$NAMESPACE"
echo -e '\e[0m'"Are these details correct?"
echo -en '\e[32m[Y]\e[0mes  \e[31m[N]\e[0mo (default is "N"): '

if [[ "$Y_OR_N" == "Y" ]]; then echo "y"; else read -r Y_OR_N; fi
if [[ "$(echo "$Y_OR_N" | tr "[:lower:]" "[:upper:]")" != "Y" ]]; then
  exit 1
fi


#************************************
# Clear service instance from TOSCA-O
#************************************

separator
log "Getting TOSCA-O service instance ID" &&
SERVICE_INSTANCE_ID=$(\
                        echo "$SERVICE_DATA" \
                      | grep '"orchServInstanceId"' \
                      | awk -F '"' '{print $4}'\
                    )

log
if [[ -n $SERVICE_INSTANCE_ID ]]; then
  log "TOSCA-O service instance id found: $SERVICE_INSTANCE_ID"

  TOSCAO_SERVICE_DATA=$(\
    curl -i --request GET "$toscao"'/toscao/api/v2.4/service-instances/'"$SERVICE_INSTANCE_ID"\
  ) || {
    errorSeparator
    logError "Error encountered contacting TOSCA-O microservice (toscao) to get service instance details."
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
  logError "If this error occurs again, ensure the toscao microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
  logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }

  STATUS=$(echo "$TOSCAO_SERVICE_DATA" | grep "HTTP/")

  if [[ $STATUS = *"404 NOT FOUND"* ]]; then
    logWarn
    logWarn "Unable to find TOSCA-O service instance with ID $SERVICE_INSTANCE_ID - it may have been deleted from TOSCA-O already."

  elif [[ $STATUS != *"200 OK"* ]]; then
    errorSeparator
    logError "Error encountered retrieving TOSCA-O service instance details."
    logError "Please check the TOSCA-O microservice for errors - if none are found or once they are resolved, try running this script again."
    errorSeparator
    exit 1

  else
    log
    if echo "$TOSCAO_SERVICE_DATA" | grep -Eq '"name" ?: ?"'"$SERVICE_NAME"'"' \
    && echo "$TOSCAO_SERVICE_DATA" | grep -Eq '"id" ?: ?"'"$SERVICE_INSTANCE_ID"'"'; then
      log "Found service instance in TOSCA-O - deleting"
      DELETE_RESULT=$(\
        curl -i -s --request DELETE "$toscao"'/toscao/api/v2.4/service-instances/'"$SERVICE_INSTANCE_ID"\
      ) || {
        errorSeparator
        logError "Error encountered contacting TOSCA-O microservice (toscao) to delete service instance."
        logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
  logError "If this error occurs again, ensure the toscao microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
  logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
        errorSeparator
        exit 1
      }

      if [[ $(echo "$DELETE_RESULT" | grep "HTTP/") = *"409 CONFLICT"* ]]; then
        logError "Conflict deleting: $DELETE_RESULT"
      else
        log "Deleted"
      fi
    else
      errorSeparator
      logError "Failed to get service instance from TOSCA-O - instead got:"
      logError "$TOSCAO_SERVICE_DATA"
      logError "Please check the TOSCA-O microservice for errors - if none are found or once they are resolved, try running this script again."
      errorSeparator
      exit 1
    fi
  fi
else
  logWarn
  logWarn "Unable to find TOSCA-O service instance for service $SERVICE_NAME - it may have been deleted from TOSCA-O already"
fi


#***************************************
# Clean process instance out of Workflow
#***************************************

separator
log "May have to clean process instances out of Workflow"
log
log "Getting process instances from Workflow"
PROCESS_INSTANCES=$(curl -s --request GET "$eric_eo_workflow"'/engine-rest/process-instance') || {
  errorSeparator
  logError "Error encountered contacting Workflow microservice (eric-eo-workflow) to get process instances."
  logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
  logError "If this error occurs again, ensure the eric-eo-workflow microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
  logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
  errorSeparator
  exit 1
}
PROCESS_INSTANCE_IDS=$(echo "$PROCESS_INSTANCES" | sed -e 's/,/\n/g' | grep -E "id|businessKey" | grep -B 1 '"'"$SERVICE_NAME"'_' | grep "id" | sed 's/.*:"\(.*\)"/\1/g')

if [[ -n $PROCESS_INSTANCE_IDS ]]; then
  while read -r instance_id; do
    log
    log "Checking process instance $instance_id"
    INSTANCE_DATA=$(curl -s --request GET "$eric_eo_workflow"'/engine-rest/process-instance/'"$instance_id") || {
      errorSeparator
      logError "Error encountered contacting Workflow microservice (eric-eo-workflow) to get process instance $instance_id."
      logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
      logError "If this error occurs again, ensure the eric-eo-workflow microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
      logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
      errorSeparator
      exit 1
    }

    if echo "$INSTANCE_DATA" | grep "$SERVICE_NAME"; then
      log
      log "Process instance valid - deleting"
      curl --request DELETE "$eric_eo_workflow"'/engine-rest/process-instance/'"$instance_id" || {
        errorSeparator
        logError "Error encountered contacting Workflow microservice (eric-eo-workflow) to delete process instance $instance_id."
        logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
        logError "If this error occurs again, ensure the eric-eo-workflow microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
        logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
        errorSeparator
        exit 1
      }
    fi
  done <<< "$PROCESS_INSTANCE_IDS"
else
  log "No process instances to delete"
fi


#**************************************************
# Delete tenant resources from Tenant Management DB
#**************************************************

separator
TENANT_DB_DESCRIPTION=$(kubectl describe pod eric-eo-tenantmgmt-database-pg-0) || {
  errorSeparator
  logError "Error encountered contacting Tenant Management database microservice (eric-eo-tenantmgmt-database-pg) to get database credentials."
  logError "Please try running this script again."
  logError "If this error occurs again, ensure the eric-eo-tenantmgmt-database-pg microservice is healthy and can be contacted by kubectl describe, and rerun this script."
  logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
  errorSeparator
  exit 1
}

TENANT_DB_DETAILS=$(\
                      echo "$TENANT_DB_DESCRIPTION" \
                    | grep -E '(PATRONI_SUPERUSER_USERNAME|POSTGRES_DB):'\
                  )
TENANT_USERNAME=$(\
                    echo "$TENANT_DB_DETAILS" \
                  | grep 'PATRONI_SUPERUSER_USERNAME' \
                  | awk '{print $2}'\
                )
TENANT_DB_NAME=$(\
                    echo "$TENANT_DB_DETAILS" \
                  | grep 'POSTGRES_DB' \
                  | awk '{print $2}'\
                )

log "Deleting tenant resources for service $SERVICE_NAME from Tenant Management"
TENANT_CLEAN_RESULT=$(kubectl exec eric-eo-tenantmgmt-database-pg-0 -c eric-eo-tenantmgmt-database-pg -- \
  psql \
    --user "$TENANT_USERNAME" \
    --dbname "$TENANT_DB_NAME" \
    -c "DELETE FROM tenant_resources \
        WHERE id IN (\
          SELECT r.id \
            FROM tenants t \
              INNER JOIN tenant_resources r \
              ON r.tenant_id = t.id \
            WHERE r.name = '$SERVICE_NAME' \
              AND t.name = '$TENANT_NAME'\
        );"\
) || {
  errorSeparator
  logError "Error encountered contacting Tenant Management database microservice (eric-eo-tenantmgmt-database-pg) to delete tenant resources."
  logError "Please try running this script again."
  logError "If this error occurs again, ensure the eric-eo-tenantmgmt-database-pg microservice is healthy and can be contacted by kubectl exec, and rerun this script."
  logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
  errorSeparator
  exit 1
}

if echo "$TENANT_CLEAN_RESULT" | grep 'DELETE 0'; then
  logWarn "Found 0 tenant resources to delete - they may have been deleted already."
elif echo "$TENANT_CLEAN_RESULT" | grep -E 'DELETE [[:digit:]]+'; then
  log "Tenant resources successfully deleted"
else
  errorSeparator
  logError "$TENANT_CLEAN_RESULT"
  logError "Failed to delete tenant resources."
  logError "Please try running this script again."
  logError "If this command still fails, the tenant $TENANT_NAME may be left in an undeletable state - please contact PDU OSS Support for manual cleanup."
  errorSeparator
  exit 1
fi


#*************************************************
# Delete subsystem users from Subsystem Management
#*************************************************

separator
log "Deleting subsystem users from Subsystem Management"
SUBSYSTEM_USER_ID_STRING=$(\
                        echo "$SERVICE_DATA" \
                      | grep "subsystemUserId" \
                      | awk '{print $3}' \
                      | sed "s/\"/'/g" \
                      | tr -d "\r\n"
                    ) &&
[[ $SUBSYSTEM_USER_ID_STRING = *"," ]] && SUBSYSTEM_USER_ID_STRING="${SUBSYSTEM_USER_ID_STRING::-1}"

if [[ -n "$SUBSYSTEM_USER_ID_STRING" ]]; then

  SUBSYSTEM_DB_DESCRIPTION=$(kubectl describe pod eric-eo-subsystem-management-database-pg-0) || {
    errorSeparator
    logError "Error encountered contacting Subsystem Management database microservice (eric-eo-subsystem-management-database-pg) to get database credentials."
    logError "Please try running this script again."
    logError "If this error occurs again, ensure the eric-eo-subsystem-management-database-pg microservice is healthy and can be contacted by kubectl describe, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }

  SUBSYSTEM_DB_DETAILS=$(\
                            echo "$SUBSYSTEM_DB_DESCRIPTION" \
                          | grep -E '(PATRONI_SUPERUSER_USERNAME|POSTGRES_DB):'\
                        )
  SUBSYSTEM_USERNAME=$(\
                          echo "$SUBSYSTEM_DB_DETAILS" \
                        | grep 'PATRONI_SUPERUSER_USERNAME' \
                        | awk '{print $2}'\
                      )
  SUBSYSTEM_DB_NAME=$(\
                        echo "$SUBSYSTEM_DB_DETAILS" \
                      | grep 'POSTGRES_DB' \
                      | awk '{print $2}'\
                    )

  log
  log "Deleting subsystem users with the following IDs: $SUBSYSTEM_USER_ID_STRING"
  SUBSYSTEM_CLEAN_RESULT=$(kubectl exec eric-eo-subsystem-management-database-pg-0 -c eric-eo-subsystem-management-database-pg -- \
    psql \
      --user "$SUBSYSTEM_USERNAME" \
      --dbname "$SUBSYSTEM_DB_NAME" \
      -c "DELETE FROM subsystem_user WHERE subsystem_user_id IN ($SUBSYSTEM_USER_ID_STRING);"\
  ) || {
    errorSeparator
    logError "Error encountered contacting Subsystem Management database microservice (eric-eo-subsystem-management-database-pg) to delete subsystem users."
    logError "Please try running this script again."
    logError "If this error occurs again, ensure the eric-eo-subsystem-management-database-pg microservice is healthy and can be contacted by kubectl exec, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }

  if echo "$SUBSYSTEM_CLEAN_RESULT" | grep 'DELETE 0'; then
    logWarn "0 subsystem users deleted - they may have been deleted already."
  elif echo "$SUBSYSTEM_CLEAN_RESULT" | grep -E 'DELETE [[:digit:]]+'; then
    log "Subsystem users successfully deleted"
  else
    errorSeparator
    logError "$SUBSYSTEM_CLEAN_RESULT"
    logError "Failed to delete subsystem users."
    logError "Please try running this script again."
    logError "If this command still fails, some subsystems may be left in an undeletable state - please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1

  fi
else
  log
  log "No subsystem users found to delete"
fi


#**********************************************************************
# Deallocate IP addresses and subnets from IP Address Management (IPAM)
#**********************************************************************

# Parse subnet IDs and network addresses out of service data
#***********************************************************
SUBNET_IDS_AND_ADDRESSES=$(\
                              echo "$SERVICE_DATA" \
                            | grep -E -A 1 '"subnet(Id|Address)"' \
                            | grep '"value"' \
                            | grep -v '"null"' \
                            | awk -F "\"" '{print $4}' \
                            | while read -r line; do
                                if echo "$line" | grep -Eq '([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}'; then
                                  echo " $line"
                                else
                                  echo -n -e "$line\c"
                                fi
                              done \
                            | tr '\n' ' ' \
                            | sed 's/ \([[:digit:]]*\) /\n\1 /g' \
                            | sed 's/^ \(\([[:digit:]]\{1,3\}\.\)\{3\}[[:digit:]]\{1,3\}\) \([[:digit:]]\+\)$/\3 \1/g'
)

ADDRESSES=$(\
              echo "$SERVICE_DATA" \
            | grep -A 1 '"ipAddress"' \
            | grep "value" \
            | awk -F "\"" '{print $4}'\
          )
[[ -n $ADDRESSES ]] && separator && log "Deallocating IP addresses in IPAM" &&
while read -r address; do

  # Get address data, including the subnet it's part of, from EAI
  #**************************************************************
  log
  log "Obtaining ID for $address"
  ADDRESS_DATA=$(\
    curl -s -i --request GET "${EAI_HEADERS[@]}" "$eric_eo_eai"'/oss-core-ws/rest/ipm/ipaddress?fs.ipRange&name='"$address"\
  ) || {
    errorSeparator
    logError "Error encountered contacting EAI microservice (eric-eo-eai) to get IP address \"$address\"."
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-eai microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }

  STATUS=$(echo "$ADDRESS_DATA" | grep "HTTP/")
  [[ $STATUS != *"200 OK"* ]] && {
    errorSeparator
    logError "Failed to get IP address from EAI: $ADDRESS_DATA"
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-eai microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }
  [[ "$ADDRESS_DATA" = *"[ ]" ]] \
  && logWarn "IP address \"$address\" not found in EAI. Has it already been deallocated?" \
  && continue

  # Parse address JSON:
  #********************
  ADDRESS_ID=$(
    # Get key/values IDs of IP address and its IP range - have to do it by key/values to distinguish between them
    echo "$ADDRESS_DATA" \
    | grep -E -A 1 'ipm/ip.*Key' \
    | awk '{print $3}' \
    | tr ',' ' ' \
    | grep -E -v "^$" | while read -r line; do
      # pair up ".*Key" elements with their values
      echo "$line" | grep -E -q '"$' \
      && echo -n -e "$line\c" \
      || echo " $line"
    done | while read -r key; do
      # put them all on one line
      echo "$key" | grep -q "address" \
      && echo -n -e "$key\c" \
      || echo " $key"
    done | while read -r addressRangePair; do
      # Range ID is now the 4th element in the line
      RANGE_KEY=$(echo "$addressRangePair" | awk '{print $4}')

      # To ensure that the IP address is the one used by our service,
      # check that the range ID is present in the list of subnet data
      # extracted earlier from the service
      echo "$SUBNET_IDS_AND_ADDRESSES" | grep -q "$RANGE_KEY" \
      && echo "$addressRangePair" | awk '{print $2}'
    done
  )

  # Deallocate IPs by ID
  #*********************
  log
  log "Deallocating IP address with ID $ADDRESS_ID through IPAM"
  ADDRESS_DELETION_DATA=$(\
    curl -s -i --request DELETE "$eric_eo_ipaddress_manager"'/ipam/v2/ip-addresses/'"$ADDRESS_ID"\
  ) || {
    errorSeparator
    logError "Error encountered contacting IPAM microservice (eric-eo-ipaddress-manager) to deallocate IP address $ADDRESS_ID."
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-ipaddress-manager microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }

  if [[ $(echo "$ADDRESS_DELETION_DATA" | grep "HTTP/") = *"204"* ]]; then
    log "Deallocated"
  else
    errorSeparator
    logError "Deallocation of IP address $address with ID $ADDRESS_ID failed:"
    logError "$ADDRESS_DELETION_DATA" | sed -e 's/, ?/\n/g' | grep "userMessage" | sed 's/[{}]//g'
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-ipaddress-manager microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this request still fails, some IPAM subnet pools may be left in an undeletable state - please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  fi
done <<< "$ADDRESSES"

[[ -n $SUBNET_IDS_AND_ADDRESSES ]] && separator && log "Deallocating subnets in IPAM" &&
while read -r subnet; do
  # Using numeric ID and network address of each subnet...
  #*******************************************************
  subnetId=$(echo "$subnet" | awk '{print $1}')

  # ...get the subnet's data direct from EAI...
  #********************************************
  log
  log "Getting subnet with ID $subnetId"
  SUBNET_DATA=$(curl -s -i --request GET "${EAI_HEADERS[@]}" "$eric_eo_eai"'/oss-core-ws/rest/ipm/iprange/'"$subnetId"'?fs.ipAddresses') || {
    errorSeparator
    logError "Error encountered contacting EAI microservice (eric-eo-eai) to get subnet $subnetId."
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-eai microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }

  STATUS=$(echo "$SUBNET_DATA" | grep "HTTP/")
  [[ $STATUS = *"404"* ]] && {
    logWarn "Subnet with ID \"$subnetId\" not found in EAI. Has it already been deallocated?"
    logWarn "(this might happen automatically if this subnet was defined in the Service Template without the poolName attribute."
    logWarn " Such a subnet would have been created automatically as part of the service, and deleted automatically when its last IP address was deallocated.)"
    continue
  }
  [[ $STATUS != *"200 OK"* ]] && {
    errorSeparator
    logError "Failed to get subnet from EAI: $SUBNET_DATA"
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-eai microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this request still fails, some IPAM subnet pools may be left in an undeletable state - please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }

  # ...check that the subnet has exactly 2 addresses allocated: network address and broadcast address
  # (that is, no other allocations or services-using-it that we have to deal with)...
  #**************************************************************************************************
  [[ $(echo "$SUBNET_DATA" | grep -E -c '"type" *: *"ipm/ipaddress"') == 2 ]] || {
    logWarn "Subnet with ID $subnetId still has IP addresses allocated - will not deallocate it"
    continue
  }
  log
  log "Deallocating subnet with ID $subnetId"

  # ...and deallocate by ID.
  #*************************
  SUBNET_DELETION_DATA=$(\
    curl -s -i --request DELETE "$eric_eo_ipaddress_manager"'/ipam/v2/subnets/'"$subnetId"\
  ) || {
    errorSeparator
    logError "Error encountered contacting IPAM microservice (eric-eo-ipaddress-manager) to deallocate subnet $subnetId."
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-ipaddress-manager microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }

  if [[ $(echo "$SUBNET_DELETION_DATA" | grep "HTTP/") = *"204"* ]]; then
    log "Deallocated"
  else
    errorSeparator
    logError "Deallocation of subnet with ID $subnetId failed:"
    logError "$SUBNET_DELETION_DATA" | sed -e 's/, ?/\n/g' | grep "userMessage" | sed 's/[{}]//g'
    logError "If this error occurs again, ensure the eric-eo-ipaddress-manager microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this request still fails, some IPAM subnet pools may be left in an undeletable state - please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  fi
done <<< "$SUBNET_IDS_AND_ADDRESSES"


#************************
# Delete service from EAI
#************************

# Delete actions, networkfunctions, etc.
#***************************************
separator
log "Deleting service data from EAI"
while read -r serviceResource; do
  log
  log "Deleting $serviceResource"
  DELETE_RESULT=$(\
    curl -s -i --request DELETE "${EAI_HEADERS[@]}" "$eric_eo_eai"'/oss-core-ws/rest/'"$serviceResource"\
  ) || {
    errorSeparator
    logError "Error encountered contacting EAI microservice (eric-eo-eai) to delete service resource object \"$serviceResource\"."
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-eai microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
  }
  [[ $(echo "$DELETE_RESULT" | grep "HTTP/")  = *"204 No Content"* ]] || {
    errorSeparator
    logError "Failed to delete service resource object \"$serviceResource\":"
    logError "$DELETE_RESULT"
    logError "If this error occurs again, ensure the eric-eo-eai microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
    logError "If this request still fails, please contact PDU OSS Support for manual cleanup."
    exit 1
  }

  log "Deleted"
done < <(\
            echo "$HREFS" \
          | awk -F "\"" '{print $4}' \
          | grep -Ev "/service/|/keypair/|/context/|/concreteresource/|/subsystemreference/"\
        )

# Delete top-level service object
#********************************
separator
log "Deleting service: $SERVICE_HREF"
SERVICE_DELETE_RESULT=$(\
  curl -i --request DELETE "${EAI_HEADERS[@]}" "$eric_eo_eai"'/oss-core-ws/rest/'"$SERVICE_HREF"\
) || {
  errorSeparator
  logError "Error encountered contacting EAI microservice (eric-eo-eai) to delete top-level service object \"$SERVICE_HREF\"."
  logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-eai microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this error continues despite this, please contact PDU OSS Support for manual cleanup."
  errorSeparator
  exit 1
}
[[ $(echo "$SERVICE_DELETE_RESULT" | grep "HTTP/")  = *"204 No Content"* ]] || {
    errorSeparator
    logError "Failed to delete top-level service object \"$SERVICE_HREF\":"
    logError "$SERVICE_DELETE_RESULT"
    logError "Please resolve any issues encountered by the preceding curl command, and rerun this script."
    logError "If this error occurs again, ensure the eric-eo-eai microservice is healthy and can be contacted by kubectl port-forward, and rerun this script."
    logError "If this request still fails, please contact PDU OSS Support for manual cleanup."
    errorSeparator
    exit 1
}

log "Deleted"


#*******************************
# Deletion and cleanup complete!
#*******************************
separator
SUCCESS_MESSAGE=" SUCCESS "
TERMINAL_WIDTH=$(tput -T xterm cols)
STAR_COUNT=$(((TERMINAL_WIDTH - ${#SUCCESS_MESSAGE}) / 2))
STAR_SEGMENT="$(head -c "$STAR_COUNT" < /dev/zero | tr "\0" "*")"
STAR_LINE="\e[32m$STAR_SEGMENT$SUCCESS_MESSAGE$STAR_SEGMENT\e[0m"
echo -e "$STAR_LINE"
log "Done cleaning up service $SERVICE_NAME"
echo -e "$STAR_LINE"
