#!/usr/bin/env bash

die()
{
        local _ret="${2:-1}"
        test "${_PRINT_HELP:-no}" = yes && print_help >&2
        echo "$1" >&2
        exit "${_ret}"
}


begins_with_short_option()
{
        local first_option all_short_options='oh'
        first_option="${1:0:1}"
        test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()

# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_option=
_arg_print="off"
_jboss="/home/jboss7/jboss-eap-7.2"
_jbos_home="$_jboss/SISLI/"
salida="false"

print_help()
{
        printf '%s\n' "The general script's help msg"
        printf 'Usage: %s [start|status|stop|restart]\n' "$0"
        printf '\t%s\n' "-h, --help: Prints help"
}

# prints colored text
print_style () {

    if [ "$3" == "info" ] ; then
        COLOR="96m";
    elif [ "$3" == "success" ] ; then
        COLOR="92m";
    elif [ "$3" == "warning" ] ; then
        COLOR="93m";
    elif [ "$3" == "danger" ] ; then
        COLOR="91m";
    else #default color
        COLOR="0m";
    fi

    STARTCOLOR="\e[$COLOR";
    ENDCOLOR="\e[0m";

    printf "%b$STARTCOLOR%b$ENDCOLOR\n" "$1" "$2";
}

# Check if the instance is running
check(){
    if [[ $(ps -fea  | grep "$_jbos_home" | grep -vE "grep|change" | wc -l ) != '0' ]];then
        echo "true"
    else
        echo "false"
    fi
}

# Get JBOSS PID
get_pid(){
    ps -fea | grep "$_jbos_home" | grep -vE "grep|standalone.sh" | awk '{print $2}'
}

# Return the status for the instance
status(){
    status=$(check)
    if [[ $status == 'true' ]];then
        PID=$(get_pid)
        print_style "La instancia de JBOSS esta corriendo con el PID:" "$PID" "info"
    else
        printf '%s\n' "No se encuentra la instancia corriendo."
    fi
}

# Start the instance
start(){
    status=$(check)
    salida="false"
    if [[ $status == 'true' ]];then
        PID=$(get_pid)
        print_style "Se genero un " "error" "danger"
        print_style "La instancia de JBOSS esta corriendo con el PID:" "$PID" "info"
    else
        nohup $_jboss/bin/standalone.sh  -Djboss.server.base.dir=$_jbos_home > /dev/null 2>&1  &
        salida="true"
    fi
}

# Stop the instance
stop(){
    status=$(check)
    salida="false"
    if [[ $status == 'true' ]];then
        cd $_jbos_home
        rm -rf tmp/
        sleep 1
        ps -fea | grep "$_jbos_home" | grep -v grep  | awk '{system("kill -9 "$2)}'
        salida="true"
    else
        print_style "Se genero un " "error" "danger"
        printf '%s\n' "No se encuentra corriendo la instancia de JBOSS."
    fi
}

# Restart the instance
restart(){
    salida="false"
    stop
    if [[ salida == "true" ]];then
        start
    fi
}

parse_commandline()
{
        _positionals_count=0
        while test $# -gt 0
        do
                _key="$1"
                case "$_key" in
                        status)
                                status
                exit 0
                                ;;
                        start)
                                start
                if [[ $salida != "false" ]];then
                    exit 0
                else
                    exit -1
                fi
                ;;
                        stop)
                                stop
                if [[ $salida != "false" ]];then
                    exit 0
                else
                    exit -1
                fi
                ;;
                        restart)
                                restart
                if [[ $salida != "false" ]];then
                    exit 0
                else
                    exit -1
                fi
                ;;
                        -h|--help)
                                print_help
                                exit 0
                                ;;
                        -h*)
                                print_help
                                exit 0
                                ;;
                        *)
                                _last_positional="$1"
                                _positionals+=("$_last_positional")
                                _positionals_count=$((_positionals_count + 1))
                                ;;
                esac
                shift
        done
}


handle_passed_args_count()
{
        local _required_args_string="'action'"
        test "${_positionals_count}" -ge 1 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${_positionals_count}." 1
        test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}


assign_positional_args()
{
        local _positional_name _shift_for=$1
        _positional_names="_arg_positional_arg "

        shift "$_shift_for"
        for _positional_name in ${_positional_names}
        do
                test $# -gt 0 || break
                eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
                shift
        done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"

