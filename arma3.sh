#!/bin/bash
source config.conf
SERVER_MODS_PATH="$SERVER_PATH/workshop"
STEAM_PATH=$(realpath ~/Steam)
STEAM_PATH_EXEC="$STEAM_PATH/steamcmd.sh"

process() {
        case $1 in
        "install")
            install
            ;;
                "start")
                        start
                        ;;
                "stop")
                        stop
                        ;;
                "restart")
                        restart
                        ;;
                "status")
                        status
                        ;;
                "logSave")
                        logSave
                        ;;
                "help")
                        help
                        ;;
                "updateMods")
                        updateMods
                        ;;
                "updateServer")
                        updateServer
                        ;;
                *)
                        echo "Usage: $TOOLS_PATH/arma3.sh <start|stop|restart|status|logSave|help|getKey|tolower>"
                        ;;
        esac
}

update() {
        $STEAM_PATH_EXEC +login $STEAM_USER $STEAM_PASS +force_install_dir $SERVER_PATH +app_update 233780 validate
}

install() {
    if [ ! "$EUID" -ne 0 ]
    then
        echo "You only run this script as non-root-user!"
    else
        echo "* starting installation"
        sudo apt-get update
        echo "* updating packages"
        sudo apt-get install tmux lib32stdc++6 lib32gcc1 python3 wget
        echo "* updating steamcmd"
        if [ ! -d ~/Steam ]
        then
            if [ ! -f ~/Steam/steamcmd.sh ]
            then
                mkdir ~/Steam
                cd ~/Steam
                wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
                tar -xzf steamcmd_linux.tar.gz
                rm steamcmd_linux.tar.gz
            fi
        fi

        echo "* installing server"
        update
        start
    fi
}

start() {
    if ! status; then
        cd $SERVER_PATH
        echo "* starting"

        local cMods=""
        for mod in ${STEAM_CLIENT_WORKSHOP_MODS[@]}
        do
                cMods="${cMods}steamapps/workshop/content/107410/$mod;"
        done
        for mod in ${SERVER_CLIENT_MODS[@]}
        do
                cMods="${cMods}$mod;"
        done
        local wMods=$(getWorkshopCollectionMods)
        for mod in ${wMods[@]}
        do
                cMods="${cMods}steamapps/workshop/content/107410/$mod;"
        done
        local sMods=""
	for mod in ${STEAM_SERVER_WORKSHOP_MODS[@]}
	do
		sMods="${cMods}steamapps/workshop/content/107410/$mod;"
	done
        for mod in ${SERVER_SERVER_MODS[@]}
        do
                sMods="${sMods}$mod;"
        done

        if [ ! -z $cMods ]
        then
                cMods="-mod=\"$cMods\""
        fi

        if [ ! -z $sMods ]
        then
                sMods="-serverMod=\"$sMods\""
        fi

        SERVER_PARAMETERS+=($cMods)
        SERVER_PARAMETERS+=($sMods)

        if [ -f $SERVER_LOG ]
        then
                rm $SERVER_LOG
        fi

        local fCmd="./$SERVER_EXEC_NAME ${SERVER_PARAMETERS[@]} 2>&1 | tee $SERVER_LOG"
        tmux new -d -s $SERVER_NAME "$fCmd"
        while ! status; do sleep 0.2; done

        echo "* started"
    else
        echo "! server is already online"
    fi
}

stop() {
        cd $SERVER_PATH
        echo "* stopping";
        if status
        then
                killSession
                while status; do sleep 0.2; done
                logSave
                echo "* stopped"
        else
        echo "! server is already offline"
    fi
}

#function for shutting down current tmux instance
killSession() {
        tmux kill-session -t $SERVER_NAME
}

#restarts the server
restart() {
        echo -e "* restarting";
        stop
        start
        echo -e "* restarted";
}

#status true is on; status false is off
status() {
        if ! $(tmux list-sessions | grep -q $SERVER_NAME)
        then
                return 1
        fi
        return 0
}

update() {
    $STEAM_PATH_EXEC +login $STEAM_USER $STEAM_PASS +force_install_dir $SERVER_PATH +app_update 233780 validate +quit
}

updateServer() {
    stop
    update
    start
}

logSave() {
        if [ ! -f $SERVER_LOG ]
        then
                cd $SERVER_PATH
                local f=$SERVER_PATH/`date +%Y-%m-%d_%H:%M:%S`_dump
                zip -q $f dump.rpt
                mv $f $LOG_PATH
                cd $TOOLS_PATH
        fi
}

getWorkshopCollectionMods() {
        echo $(python3 $TOOLS_PATH/getCollectionMods.py $STEAM_API_KEY $STEAM_COLLECTION_ID)
}

downloadWorkshopMods() {
        local mods=()
	mods+=("${STEAM_SERVER_WORKSHOP_MODS[@]}")
        mods+=("${STEAM_CLIENT_WORKSHOP_MODS[@]}")
        mods+=($(getWorkshopCollectionMods))
        local cmds=()
        for mod in ${mods[@]}
        do
                cmds+=("+workshop_download_item 107410 $mod validate")
        done
        #remove the information file about the current mods to update post edited lower-case files too
        if [ -f $SERVER_PATH/steamapps/workshop/appworkshop_107410.acf ]
        then
                rm $SERVER_PATH/steamapps/workshop/appworkshop_107410.acf
        fi
        $STEAM_PATH_EXEC +login $STEAM_USER $STEAM_PASS +force_install_dir $SERVER_PATH ${cmds[@]} +quit
        toLower
}

updateMods() {
        stop
        #download all workshop-related mods
        downloadWorkshopMods
        #update all keys
        local mods=$(getWorkshopCollectionMods)
        fCmd=()
        for eK in ${SERVER_KEYS_EXCEPT[@]}
        do
                fCmd+=("-not -name '$eK'")
        done
        #remove existing keys except a3.bikey and keys listed in SERVER_KEYS_EXCEPT
        find $SERVER_PATH/keys -type f -not -name 'a3.bikey' ${fCmd[@]} -delete
        #copy the keys to $SERVER_PATH/keys
        for mod in ${mods[@]}
        do
                local cP="$SERVER_PATH/steamapps/workshop/content/107410/$mod"
                for f in $(find $cP -type f -name '*.bikey')
                do
                        cp -u $f $SERVER_PATH/keys
                done
        done
    start
}

toLower() {
        find $SERVER_PATH/steamapps/workshop/content/107410/ -depth -exec rename 's/(.*)\/([^\/]*)/$1\/\L$2/' {} \;
}

help() {
        echo "####################################################"
        echo -e "# \e[1;33mHelp menu of Arma 3 Restart Script by Vincent H.\e[0m #"
        echo "# ------------------------------------------------ #"
        echo -e "# \e[1;32mstart\e[0m | \e[1;33mStarts the server\e[0m #"
        echo -e "# \e[1;32mstop\e[0m | \e[1;33mStops the server\e[0m #"
        echo -e "# \e[1;32mrestart\e[0m | \e[1;33mRestarts the server\e[0m #"
        echo -e "# \e[1;32mstatus\e[0m | \e[1;33mReturns the current process-PID\e[0m #"
        echo -e "# \e[1;32mhelp\e[0m | \e[1;33mYou are currently watching the help!\e[0m #"
        echo "####################################################"
}

process $1 $2 cd $MAIN_PATH
