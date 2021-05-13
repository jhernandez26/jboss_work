#!/usr/bin/env bash

# Prints msg
print_style () {

    if [ "$1" == "INFO" ] ; then
        COLOR="96m";
    elif [ "$1" == "SUCCESS" ] ; then
        COLOR="92m";
    elif [ "$1" == "WARNING" ] ; then
        COLOR="93m";
    elif [ "$1" == "ERROR" ] ; then
        COLOR="91m";
    else #default color
        COLOR="0m";
    fi

    STARTCOLOR="\e[$COLOR";
    ENDCOLOR="\e[0m";

    printf "$STARTCOLOR%b$ENDCOLOR%b" "$1" "$2\n";
}


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
_war_origen=''
_war_destino=''
_jboss_comando=''
_arg_print="off"

# Global variables
_num_argu=3
_realizar_cambio="false"
_existe_instancia="false"
_restart="false"
_jboss_home="/home/jboss7"
_jboss_home_service="/home/jboss7/admscript/service"

print_help()
{
	printf '%s\n' "The general script's help msg"
	printf 'Usage: %s [-o <arg-war-first>] [-n <arg-war-second>] [-j <arg-jboss-instance>] [-h|--help] \n' "$0"
	printf '\t%s\n' "<arg-war-first>: original war"
	printf '\t%s\n' "<arg-war-second>: new war"
	printf '\t%s\n' "<arg-jboss-instance>: jboss instance"
	printf '\t%s\n' "-o: option to set the original war"
	printf '\t%s\n' "-n: option to set the new war"
	printf '\t%s\n' "-j: option to set the jboss instance"
	printf '\t%s\n' "-h, --help: Prints help"
}


parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-o)
                if [[ $_war_origen == '' ]];then
                    _war_origen="$2"
				    _last_positional="$1"
				    _positionals+=("$_last_positional")
				    _positionals_count=$((_positionals_count + 1))
                fi
				;;
			-n)
                if [[ $_war_destino == '' ]];then
				    _war_destino="$2"
				    _last_positional="$1"
				    _positionals+=("$_last_positional")
				    _positionals_count=$((_positionals_count + 1))
                fi
				;;
			-j)
                if [[ $_jboss_comando = '' ]];then
				    _jboss_comando="$2"
				    _last_positional="$1"
				    _positionals+=("$_last_positional")
				    _positionals_count=$((_positionals_count + 1))
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
				echo "nothing" > /dev/null
				;;
		esac
		shift
	done
}


handle_passed_args_count()
{
	test "${_positionals_count}" -ge 3 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 3, but got only ${_positionals_count}." 1
	test "${_positionals_count}" -le 3 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 3 , but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
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

# End arg bash script
# Logic bash

# Check if the files are correct
check_files(){
    if [[ $(basename $_war_origen) == $(basename $_war_destino ) ]];then
        if [[ $(ls -l $_war_origen | wc -l ) != '0' ]];then
            if [[ $(ls -l $_war_destino | wc -l ) != '0' ]];then
                if [[ $_war_origen != $_war_destino ]];then
                    _realizar_cambio="true"
                else
                print_style "ERROR" " $(date +%Y-%m-%d) The file $_war_destino is the same with $_war_origen."    
                fi
            else
                print_style "ERROR" " $(date +%Y-%m-%d)  $_war_destino no souch, maybe you should use the absolute path."    
            fi
        else
            print_style "ERROR" " $(date +%Y-%m-%d)  $_war_origen no souch, maybe you should use the absolute path." 
        fi
    else
        print_style "ERROR" " $(date +%Y-%m-%d) The files have to has the same name."
    fi
}

# Check if the jboss instance exists
exist_jboss_instance(){
    instance=$(echo $_jboss_comando | awk '{print tolower($0)}')
    if [[ $instance == 'sisli' ||  $instance == 'juridica'  ||  $instance == 'juicios'  ||  $instance == 'tramite' ]];then
        _existe_instancia="true"
    else
        print_style 'ERROR' " $(date +%Y-%m-%d) The instance  $_jboss_comando does not  exists in JBOSS."
    fi
}

# Check jboss state
check_jboss_instance(){
    if [[ $(sh $1 status| grep -c "PID" ) == '1' ]];then
        _restart="true"
    fi
}

# make the change
cambio(){
    check_files  
    exist_jboss_instance 
    if [[ $_realizar_cambio == "true"  &&  $_existe_instancia == "true" ]]; then
        print_style 'INFO' " $(date +%Y-%m-%d) Preparing the  files."
        print_style 'INFO' " $(date +%Y-%m-%d) set permision."
        chmod --reference=$1 $2
        chown --reference=$1 $2
        getfacl $1 | setfacl --set-file=- $2
        #print_style 'INFO' " $(date +%Y-%m-%d) Generando backup del archivo original."
        print_style 'INFO' " $(date +%Y-%m-%d) Chanhe the .war."
        mv -f $2 $1
        print_style 'INFO' " $(date +%Y-%m-%d) check the instance $3 in JBOSS."
        script_service="$_jboss_home_service/service_$(echo $3 | awk '{print tolower($0)}').sh"
        check_jboss_instance $script_service
        if [[ $_restart == 'true' ]];then
            print_style 'INFO' " $(date +%Y-%m-%d) Restarting the instance $3 in JBOSS."
            sh $script_service restart
        else
            print_style 'INFO' " $(date +%Y-%m-%d) The instance  $3 is not running in JBOSS, therefore I'm going to start."
            sh $script_service start
        fi
        print_style 'INFO' " $(date +%Y-%m-%d) Finish."

    fi
}

cambio