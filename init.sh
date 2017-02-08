#! /bin/bash

trap "exit 1" TERM
export TOP_PID=$$

# Define true and false as 1 and 0.
declare -r TRUE=1
declare -r FALSE=0

# Supported types of arguments.
# TODO(hedayati): Add array type.
declare -r INT=1
declare -r STR=2
declare -r BOOL=3

# List of defined parameters, their description, type and default values. The
# parameters should start with double dash sign (i.e., --), single dashes are
# not supported. Also, currently there is not support for short parameter names
# (i.e., -o/--o instead of --output). The value for the parameter can come after
# a space or assignment sign (i.e., =). Integer values can be negative. Strings
# should not have space unless passed with quotes and adequate escaping. Boolean
# values can be used without values with --name meaning true and --noname
# meaning false. There should always be a space after the name of the parameter
# and value unless separated with an assignment sign (i.e., --name=1 is correct,
# but --name1 is not).
params=()
params_desc=()
params_type=()
params_default=()

# Issue a log message to stderr.
function log()
{
    (>&2 echo "LOG: " $@)
}

# Issue a warning message to stderr.
function warn()
{
    (>&2 echo "WARNING: " $@)
}

# Issue an error message to stderr.
function error()
{
    (>&2 echo "ERROR: " $@)
}

# Declare an integer parameter.
# $1: name of the parameter.
# $2: description of the parameter.
# $3: default value for the parameter.
# TODO(hedayati): ensure there is no duplicate.
function declare_int()
{
    name=$1
    desc=$2
    default=$3

    # Integers are initialized to zero.
    eval "$name=0"
    params+=("$name")
    params_desc+=("$desc")
    params_type+=("$INT")

    # If any default value is defined, update the initialization.
    if [[ "$default" ]]; then
        eval "$name=$default"
        params_default+=("$default")
    else
        params_default+=("0")
    fi
}

# Declare a string parameter.
# $1: name of the parameter.
# $2: description of the parameter.
# $3: default value for the parameter.
# TODO(hedayati): ensure there is no duplicate.
function declare_str()
{
    name=$1
    desc=$2
    default=$3

    # Strings are initialized to "".
    eval "$name=\"\""
    params+=("$name")
    params_desc+=("$desc")
    params_type+=("$STR")

    # If any default value is defined, update the initialization.
    if [[ "$default" ]]; then
        eval "$name=$default"
        params_default+=("$default")
    else
        params_default+=("")
    fi
}

# Declare a boolean parameter.
# $1: name of the parameter.
# $2: description of the parameter.
# $3: default value for the parameter.
# TODO(hedayati): ensure there is no duplicate.
function declare_bool()
{
    name=$1
    desc=$2
    default=$3

    # Booleans are initialized to false.
    eval "$name=$FALSE"
    params+=("$name")
    params_desc+=("$desc")
    params_type+=("$BOOL")

    # If any default value is defined, update the initialization.
    if [[ "$default" ]]; then
        if [[ "$TRUE" -eq "$default" ]]; then
            eval "$name=$TRUE"
            params_default+=("$TRUE")
        fi

        if [[ "$FALSE" -eq "$default" ]]; then
            eval "$name=$FALSE"
            params_default+=("$FALSE")
        fi
    else
        params_default+=("$FALSE")
    fi
}

# Print parameters and their descriptions.
function print_help()
{
    printf "%-10s\t%-10s\t%s\n" "parameter" "default" "description"
    printf "%-10s\t%-10s\t%s\n" "----------" "----------" "----------"

    for (( i = 0; i < ${#params[@]}; i++ )); do
        printf "%-10s\t%-10s\t%s\n" "${params[$i]}" "${params_default[$i]}" "${params_desc[$i]}"
    done
}

# Given what immediately follows an integer parameter in argument line, prints
# the value. Valid inputs can start with assignment sign, or an integer.
# Example: 2, =2, =-2, = 2, =2 --next /dev/sdb1, = 2--arg2 are all valid. =+3,
# +3, --help, ==3 are not valid.
function get_int()
{
    # Remove arguments that follow.
    arg=`echo $@ | sed s/"--"/"\n"/ | head -1 | sed 's/^ *//; s/ *$//'`

    # Remove starting assignment sign if any.
    if [[ `echo $arg | grep "^="` ]]; then
        arg=`echo $arg | sed s/"^="/"\n"/ | tail -1 | sed 's/^ *//; s/ *$//'`
    fi

    # If the remainder starts with an integer, echo that back.
    if [[ $arg =~ ^-?[0-9]+ ]]; then
        echo $arg | sed -n 's/\(^-\?[0-9]\+\).*/\1/p'
        return 0
    else
        # Indicate that input is not in correct format.
        return 1
    fi
}

# Given what immediately follows a string parameter in argument line, prints
# the value.
function get_str()
{
    # Remove arguments that follow.
    arg=`echo "$@" | sed 's/^ *//; s/ *$//'`

    # Remove starting assignment sign if any.
    if [[ `echo $arg | grep "^="` ]]; then
        arg=`echo $arg | sed s/"^="/"\n"/ | tail -1 | sed 's/^ *//; s/ *$//'`
    fi

    if [[ `echo $arg | grep -o '^".*"'` ]]; then
        echo "$arg" | grep -o '^".*"' | sed 's/"//g'
        return 0
    fi

    if [[ `echo $arg | grep -o ^\'.*\'` ]]; then
        echo $arg | grep -o ^\'.*\' | sed s/\'//g
        return 0
    fi

    arg=`echo $arg | sed s/" "/"\n"/ | head -1 | sed 's/^ *//; s/ *$//'`
    echo $arg

    return 0
}

# Given what immediately follows a boolean parameter in argument line, prints
# the value.
function get_bool()
{
    # Remove arguments that follow.
    arg=`echo $@ | sed s/"--"/"\n"/ | head -1 | sed 's/^ *//; s/ *$//'`

    # Remove starting assignment sign if any.
    if [[ `echo $arg | grep "^="` ]]; then
        arg=`echo $arg | sed s/"^="/"\n"/ | tail -1 | sed 's/^ *//; s/ *$//'`
    fi

    if [[ $arg =~ ^[0-1] ]]; then
        echo $arg | sed -n 's/\(^[0-1]\).*/\1/p'
        return 0
    else
        return 1
    fi
}

# Initializes the parameters and parses the arguments.
# $1: all of the arguments passed to the script (use init "$@" in the code).
function init()
{
    # Declare a boolean parameter (--help) that will show the list of
    # parameters with their descriptions.
    declare_bool help "show help message." FALSE

    # Declare a boolean parameter (--show_params) that will show the list of
    # parameters with their values after parsing and before we return to the
    # caller. This can be used for debugging.
    declare_bool show_params "show parameter values after parsing." FALSE

    # Iterate through defined parameters and parse the arguments.
    for (( i = 0; i < ${#params[@]}; i++ )); do
        param=${params[$i]}

        # If the parameter is used in the command line argument proceed,
        # otherwise check for next parameter.
        if [[ `echo "$@" | grep "\<$param\>"` ]]; then

            # If the parameter is an integer, call get_int function.
            if [[ $INT -eq ${params_type[$i]} ]]; then
                if get_int `echo "$@" | sed s/"\<$param\>"/"\n"/g | tail -1 | sed 's/^ *//; s/ *$//'` > /dev/null ; then
                    eval "$param=$(get_int `echo "$@" | sed s/"\<$param\>"/"\n"/g | tail -1 | sed 's/^ *//; s/ *$//'`)"
                else
                    error "provided value for $param is not an integer."
                fi
                continue
            fi

            # If the parameter is a string, call get_str function.
            if [[ $STR -eq ${params_type[$i]} ]]; then
                eval "$param='$(get_str `echo "$@" | sed s/"\<$param\>"/"\n"/g | tail -1 | sed 's/^ *//; s/ *$//'`)'"
                continue
            fi

            # If the parameter is a boolean, call get_bool function.
            if [[ $BOOL -eq ${params_type[$i]} ]]; then
                if get_bool `echo "$@" | sed s/"\<$param\>"/"\n"/g | tail -1 | sed 's/^ *//; s/ *$//'` > /dev/null ; then
                    # --boolparam=0 means it is false and --boolparam=1 means it is true.
                    eval "$param=$(get_bool `echo "$@" | sed s/"\<$param\>"/"\n"/g | tail -1 | sed 's/^ *//; s/ *$//'`)"
                else
                    # --boolparam means it is true.
                    eval "$param=$TRUE"
                fi
                continue
            fi

            continue
        fi

        # If the parameter is a boolean --noboolparam means it is false.
        if [[ $BOOL -eq ${params_type[$i]} ]]; then
            if [[ `echo "$@" | grep "\no<$param\>"` ]]; then
                eval "$param=$(($TRUE - $(get_bool `echo "$@" | sed s/"\<$param\>"/"\n"/g | tail -1 | sed 's/^ *//; s/ *$//'`)))"
                continue
            fi
        fi
    done

    # Should we print help?
    if [[ $help -eq $TRUE ]]; then
        print_help
        kill -s TERM $TOP_PID
    fi

    # Print the list of all parameters and their corresponding values.
    if [[ $show_params -eq $TRUE ]]; then
        echo "-----------------"
        for param in ${params[@]}; do
            printf "%-10s\t=\t%-10s\n" "$param" "${!param}"
        done
        echo "-----------------"
    fi
}
