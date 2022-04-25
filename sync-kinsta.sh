#!/bin/bash

# Syncing Trellis & Bedrock-based WordPress environments with WP-CLI aliases (Kinsta version)
# Version 1.2.0
# Copyright (c) Ben Word

DEVDIR="web/app/uploads/"
DEVSITE="https://example.test"
DEVPORT="22"

REMOTEDIR="example@1.2.3.4:/www/example_123/public/shared/uploads/"

PRODPORT="12345"
PRODSITE="https://example.com"

STAGPORT="54321"
STAGSITE="https://staging-example.kinsta.cloud"

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
  production-development) DIR="down ⬇️ "           FROMSITE=$PRODSITE; FROMDIR=$REMOTEDIR; FROMPORT=$PRODPORT; TOPORT=$DEVPORT; TOSITE=$DEVSITE;  TODIR=$DEVDIR; ;;
  staging-development)    DIR="down ⬇️ "           FROMSITE=$STAGSITE; FROMDIR=$REMOTEDIR; FROMPORT=$STAGPORT; TOPORT=$DEVPORT; TOSITE=$DEVSITE;  TODIR=$DEVDIR; ;;
  development-production) DIR="up ⬆️ "             FROMSITE=$DEVSITE;  FROMDIR=$DEVDIR;  FROMPORT=$DEVPORT; TOPORT=$PRODPORT; TOSITE=$PRODSITE; TODIR=$REMOTEDIR; ;;
  development-staging)    DIR="up ⬆️ "             FROMSITE=$DEVSITE;  FROMDIR=$DEVDIR;  FROMPORT=$DEVPORT; TOPORT=$STAGPORT; TOSITE=$STAGSITE; TODIR=$REMOTEDIR; ;;
  production-staging)     DIR="horizontally ↔️ ";  FROMSITE=$PRODSITE; FROMDIR=$REMOTEDIR; FROMPORT=$PRODPORT; TOPORT=$STAGPORT; TOSITE=$STAGSITE; TODIR=$REMOTEDIR; ;;
  staging-production)     DIR="horizontally ↔️ ";  FROMSITE=$STAGSITE; FROMDIR=$REMOTEDIR; FROMPORT=$STAGPORT; TOPORT=$PRODPORT; TOSITE=$PRODSITE; TODIR=$REMOTEDIR; ;;
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
      wp search-replace "$FROMSITE" "$TOSITE" --all-tables-with-prefix
    elif [[ "$LOCAL" = true && $FROM == "development" ]]; then
      wp "@$TO" db export --default-character-set=utf8mb4 &&
      wp "@$TO" db reset --yes &&
      wp db export --default-character-set=utf8mb4 - | wp "@$TO" db import - &&
      wp "@$TO" search-replace "$FROMSITE" "$TOSITE" --all-tables-with-prefix
    else
      wp "@$TO" db export --default-character-set=utf8mb4 &&
      wp "@$TO" db reset --yes &&
      wp "@$FROM" db export --default-character-set=utf8mb4 - | wp "@$TO" db import - &&
      wp "@$TO" search-replace "$FROMSITE" "$TOSITE" --all-tables-with-prefix
    fi
  fi

  if [ "$SKIP_ASSETS" = false ]
  then
  echo "Syncing assets..."
    # Sync uploads directory
    chmod -R 755 web/app/uploads/ &&
    if [[ $DIR == "horizontally"* ]]; then
      [[ $FROMDIR =~ ^(.*): ]] && FROMHOST=${BASH_REMATCH[1]}
      [[ $FROMDIR =~ ^(.*):(.*)$ ]] && FROMDIR=${BASH_REMATCH[2]}
      [[ $TODIR =~ ^(.*): ]] && TOHOST=${BASH_REMATCH[1]}
      [[ $TODIR =~ ^(.*):(.*)$ ]] && TODIR=${BASH_REMATCH[2]}

      ssh -p $FROMPORT -o ForwardAgent=yes $FROMHOST "rsync -aze 'ssh -o StrictHostKeyChecking=no -p $TOPORT' --progress $FROMDIR $TOHOST:$TODIR"
    elif [[ $DIR == "down"* ]]; then
      rsync -chavzP -e "ssh -p $FROMPORT" --progress "$FROMDIR" "$TODIR"
    else
      rsync -az -e "ssh -p $TOPORT" --progress "$FROMDIR" "$TODIR"
    fi
  fi

  # Slack notification when sync direction is up or horizontal
  # if [[ $DIR != "down"* ]]; then
  #   USER="$(git config user.name)"
  #   curl -X POST -H "Content-type: application/json" --data "{\"attachments\":[{\"fallback\": \"\",\"color\":\"#36a64f\",\"text\":\"🔄 Sync from ${FROMSITE} to ${TOSITE} by ${USER} complete \"}],\"channel\":\"#site\"}" https://hooks.slack.com/services/xx/xx/xx
  # fi
  echo -e "\n🔄  Sync from $FROM to $TO complete.\n\n    ${bold}$TOSITE${normal}\n"
fi
