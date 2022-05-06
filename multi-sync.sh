#!/bin/bash

# Syncing Trellis & Bedrock-based WordPress environments with WP-CLI aliases
# Version 1.2.0
# Copyright (c) Ben Word

# Requires: `jq` and new-ish bash (> 4)
# MacOS users:
#   > `brew install jq bash`
#   > `source ~/.zshrc`

JSON_MAPPING="./sync.json"

function connection() {
  echo $(jq -r ".connection | .$1" $JSON_MAPPING)
}

function site() {
  echo $(jq -r ".sites | .[0] | .$1" $JSON_MAPPING)
}

function env() {
  echo $(jq -r ".sites | .[$1] | .$2 | .$3" $JSON_MAPPING)
}

function replace() {
  from=$1
  to=$2
  use_alias=$3
  id=0
  for _x in $(jq -c ".sites | .[]" $JSON_MAPPING); do
    if [ "$use_alias" = true ]; then
      echo "[@${to}] $(env $id $from) => $(env $id $to)";
      wp search-replace "@${2}" "$(env $id $from)" "$(env $id $to)" --all-tables-with-prefix --network;
    else
      echo "[local] $(env $id $from) => $(env $id $to)";
      wp search-replace "$(env $id $from)" "$(env $id $to)" --all-tables-with-prefix --network;
    fi

    ((id++));
  done
}

uploads=$(jq -r ".uploads" $JSON_MAPPING)

LOCAL=false
SKIP_DB=false
SKIP_ASSETS=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-db)
      SKIP_DB=true
      shift
      ;;
    --skip-assets)
      SKIP_ASSETS=true
      shift
      ;;
    --local)
      LOCAL=true
      shift
      ;;
    --*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [ $# != 2 ]
then
  echo "Usage: $0 [[--skip-db] [--skip-assets] [--local]] [ENV_FROM] [ENV_TO]"
exit;
fi

FROM=$1
TO=$2

bold=$(tput bold)
normal=$(tput sgr0)

case "$1-$2" in
  production-development) DIR="down ⬇️ "          FROMSITE=$(site production); FROMDIR=$(connection production); TOSITE=$(site development);  TODIR=$uploads; ;;
  staging-development)    DIR="down ⬇️ "          FROMSITE=$(site staging); FROMDIR=$(connection staging); TOSITE=$(site development);  TODIR=$uploads; ;;
  development-production) DIR="up ⬆️ "            FROMSITE=$(site development);  FROMDIR=$uploads;  TOSITE=$(site production); TODIR=$(connection production); ;;
  development-staging)    DIR="up ⬆️ "            FROMSITE=$(site development);  FROMDIR=$uploads;  TOSITE=$(site staging); TODIR=$(connection staging); ;;
  production-staging)     DIR="horizontally ↔️ ";  FROMSITE=$(site production); FROMDIR=$(connection production); TOSITE=$(site staging); TODIR=$(connection staging); ;;
  staging-production)     DIR="horizontally ↔️ ";  FROMSITE=$(site staging); FROMDIR=$(connection staging); TOSITE=$(site production); TODIR=$(connection production); ;;
  *) echo "usage: $0 [[--skip-db] [--skip-assets] [--local]] production development | staging development | development staging | development production | staging production | production staging" && exit 1 ;;
esac

if [ "$SKIP_DB" = false ]
then
  DB_MESSAGE=" - ${bold}reset the $TO database${normal} ($TOSITE)"
fi

if [ "$SKIP_ASSETS" = false ]
then
  ASSETS_MESSAGE=" - sync ${bold}$DIR${normal} from $FROM ($FROMSITE)?"
fi

if [ "$SKIP_DB" = true ] && [ "$SKIP_ASSETS" = true ]
then
  echo "Nothing to synchronize."
  exit;
fi

echo
echo "Would you really like to "
echo $DB_MESSAGE
echo $ASSETS_MESSAGE
read -r -p " [y/N] " response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  # Change to site directory
  cd ../ &&
  echo

  # Make sure both environments are available before we continue
  availfrom() {
    local AVAILFROM

    if [[ "$LOCAL" = true && $FROM == "development" ]]; then
      AVAILFROM=$(wp option get home 2>&1)
    else
      AVAILFROM=$(wp "@$FROM" option get home 2>&1)
    fi
    if [[ $AVAILFROM == *"Error"* ]]; then
      echo "❌  Unable to connect to $FROM"
      exit 1
    else
      echo "✅  Able to connect to $FROM"
    fi
  };
  availfrom

  availto() {
    local AVAILTO
    if [[ "$LOCAL" = true && $TO == "development" ]]; then
      AVAILTO=$(wp option get home 2>&1)
    else
      AVAILTO=$(wp "@$TO" option get home 2>&1)
    fi

    if [[ $AVAILTO == *"Error"* ]]; then
      echo "❌  Unable to connect to $TO $AVAILTO"
      exit 1
    else
      echo "✅  Able to connect to $TO"
    fi
  };
  availto

  if [ "$SKIP_DB" = false ]
  then
  echo "Syncing database..."
    # Export/import database, run search & replace
    if [[ "$LOCAL" = true && $TO == "development" ]]; then
      wp db export --default-character-set=utf8mb4 &&
      wp db reset --yes &&
      wp "@$FROM" db export --default-character-set=utf8mb4 - | wp db import - &&
      replace $FROM $TO
    elif [[ "$LOCAL" = true && $FROM == "development" ]]; then
      wp "@$TO" db export --default-character-set=utf8mb4 &&
      wp "@$TO" db reset --yes &&
      wp db export --default-character-set=utf8mb4 - | wp "@$TO" db import - &&
      replace $FROM $TO true
    else
      wp "@$TO" db export --default-character-set=utf8mb4 &&
      wp "@$TO" db reset --yes &&
      wp "@$FROM" db export --default-character-set=utf8mb4 - | wp "@$TO" db import - &&
      replace $FROM $TO true
    fi
  fi

  if [ "$SKIP_ASSETS" = false ]
  then
  echo "Syncing assets..."
    # Sync uploads directory
    $(chmod -R 755 "$uploads") &&
    if [[ $DIR == "horizontally"* ]]; then
      [[ $FROMDIR =~ ^(.*): ]] && FROMHOST=${BASH_REMATCH[1]}
      [[ $FROMDIR =~ ^(.*):(.*)$ ]] && FROMDIR=${BASH_REMATCH[2]}
      [[ $TODIR =~ ^(.*): ]] && TOHOST=${BASH_REMATCH[1]}
      [[ $TODIR =~ ^(.*):(.*)$ ]] && TODIR=${BASH_REMATCH[2]}

      ssh -o ForwardAgent=yes $FROMHOST "rsync -aze 'ssh -o StrictHostKeyChecking=no' --progress $FROMDIR $TOHOST:$TODIR"
    else
      rsync -az --progress "$FROMDIR" "$TODIR"
    fi
  fi

  # Slack notification when sync direction is up or horizontal
  # if [[ $DIR != "down"* ]]; then
  #   USER="$(git config user.name)"
  #   curl -X POST -H "Content-type: application/json" --data "{\"attachments\":[{\"fallback\": \"\",\"color\":\"#36a64f\",\"text\":\"🔄 Sync from ${FROMSITE} to ${TOSITE} by ${USER} complete \"}],\"channel\":\"#site\"}" https://hooks.slack.com/services/xx/xx/xx
  # fi
  echo -e "\n🔄  Sync from $FROM to $TO complete.\n\n    ${bold}$TOSITE${normal}\n"
fi
