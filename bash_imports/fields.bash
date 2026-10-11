# SYNOPSIS: field_prepend varName fieldVal [sep]
#   SEP defaults to ':'
# Note: Forces fieldVal into the first position, if already present.
#       Duplicates are removed, too.
# EXAMPLE: field_prepend PATH /usr/local/bin
field_prepend() {
    local varName=$1 fieldVal=$2 IFS=${3:-':'} auxArr
    read -ra auxArr <<< "${!varName}"
    for i in "${!auxArr[@]}"; do
        [[ ${auxArr[i]} == "$fieldVal" ]] && unset auxArr[i]
    done
    auxArr=("$fieldVal" "${auxArr[@]}")
    printf -v "$varName" '%s' "${auxArr[*]}"
}

# SYNOPSIS: field_append varName fieldVal [sep]
#   SEP defaults to ':'
# Note: Forces fieldVal into the last position, if already present.
#       Duplicates are removed, too.
# EXAMPLE: field_append PATH /usr/local/bin
field_append() {
    local varName=$1 fieldVal=$2 IFS=${3:-':'} auxArr
    read -ra auxArr <<< "${!varName}"
    for i in "${!auxArr[@]}"; do
        [[ ${auxArr[i]} == "$fieldVal" ]] && unset auxArr[i]
    done
    auxArr+=("$fieldVal")
    printf -v "$varName" '%s' "${auxArr[*]}"
}

# SYNOPSIS: field_remove varName fieldVal [sep]
#   SEP defaults to ':'
# Note: Duplicates are removed, too.
# EXAMPLE: field_remove PATH /usr/local/bin
field_remove() {
    local varName=$1 fieldVal=$2 IFS=${3:-':'} auxArr
    read -ra auxArr <<< "${!varName}"
    for i in "${!auxArr[@]}"; do
        [[ ${auxArr[i]} == "$fieldVal" ]] && unset auxArr[i]
    done
    printf -v "$varName" '%s' "${auxArr[*]}"
}
