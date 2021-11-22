#!/bin/bash
# DepTree
# Copyright (c) tdrkDev 2021

search_paths_32="lib vendor/lib"
search_paths_64="lib64 vendor/lib64"

workdir="$(pwd)"

SILENCE_WARNINGS=true

gen_libraries_paths() {
    for i in $search_paths_32; do
        [ ! -d "$workdir/$i" ] && continue
        [ ! -z "$_libs_paths32" ] && _libs_paths32="$_libs_paths32 $(find $i -type f -name "*.so")"
        [ -z "$_libs_paths32" ] && _libs_paths32="$(find $i -type f -name "*.so")"
    done

    for i in $search_paths_64; do
        [ ! -d "$workdir/$i" ] && continue
        [ ! -z "$_libs_paths64" ] && _libs_paths64="$_libs_paths64 $(find $i -type f -name "*.so")"
        [ -z "$_libs_paths64" ] && _libs_paths64="$(find $i -type f -name "*.so")"
    done

    # Convert everything to arrays
    libs_paths64=($_libs_paths64)
    libs_paths32=($_libs_paths32)
    for ((i=0;$i<${#libs_paths32[@]};i++)); do
        libs32+=("$(sed 's#.*/##g' <<< "${libs_paths32[$i]}")")
    done
    for ((i=0;$i<${#libs_paths64[@]};i++)); do
        libs64+=("$(sed 's#.*/##g' <<< "${libs_paths64[$i]}")")
    done
}

# Because of bash, we need to use
# temporary data storage
gen_json_structure() {
    [ -d $workdir/.temp_gentree ] && rm -rf $workdir/.temp_gentree
    mkdir -p $workdir/.temp_gentree/libraries_{32,64}

    for ((i=0;$i<${#libs32[@]};i++)); do
        target="${libs32[$i]}"

        mkdir $workdir/.temp_gentree/libraries_32/$target
        touch $workdir/.temp_gentree/libraries_32/$target/{dependencies,used_by}
        echo "${libs_paths32[$i]}" > $workdir/.temp_gentree/libraries_32/$target/path
    done

    for ((i=0;$i<${#libs64[@]};i++)); do
        target="${libs64[$i]}"

        mkdir $workdir/.temp_gentree/libraries_64/$target
        touch $workdir/.temp_gentree/libraries_64/$target/{dependencies,used_by}
        echo "${libs_paths64[$i]}" > $workdir/.temp_gentree/libraries_64/$target/path
    done
}

# append_data [64|32] [used_by|dependencies] destination value
append_data() {
    if [ ! -d $workdir/.temp_gentree/libraries_$1/$3 ]; then
        ([ -z "$SILENCE_WARNINGS" ] || [ "$SILENCE_WARNINGS" = "false" ]) && echo "W: Library $3 does not exist"
        return
    fi

    echo "$4" >> $workdir/.temp_gentree/libraries_$1/$3/$2
}

clear_this_line(){
    printf '\r'
    cols="$(tput cols)"
    for x in $(seq "$cols"); do
            printf ' '
    done
    printf '\r'
}

generate_data() {
    echo -e "\nGenerating 32-bit libraries tree...\n\n"

    i=0

    for ((i=0;$i<${#libs32[@]};i++)); do
        current_library="${libs32[$i]}"
        current_path="${libs_paths32[$i]}"

        clear_this_line
        echo "[$(expr $i + 1)/${#libs32[@]}] $current_path"

        deps="$(patchelf --print-needed $current_path)"
        for a in $deps; do
            append_data 32 used_by $a $current_library
            append_data 32 dependencies $current_library $a
        done

        unset deps current_library current_path
    done

    echo -e "\nGenerating 64-bit libraries tree...\n\n"

    for ((i=0;$i<${#libs64[@]};i++)); do
        current_library="${libs64[$i]}"
        current_path="${libs_paths64[$i]}"

        clear_this_line
        echo "[$(expr $i + 1)/${#libs64[@]}] $current_path"

        deps="$(patchelf --print-needed $current_path)"
        for a in $deps; do
            append_data 64 used_by $a $current_library
            append_data 64 dependencies $current_library $a
        done

        unset deps current_library current_path
    done

    clear_this_line
    echo "Done generating tree."
}

generate_json_from_data() {
    echo "Generating json..."

    json="{"

    # 32-bit libraries
    json+='"libraries_32": ['
    for ((i=0;$i<${#libs32[@]};i++)); do
        current_library="${libs32[$i]}"
        current_path="${libs_paths32[$i]}"
        workdir_path="$workdir/.temp_gentree/libraries_32/$current_library"

        json+="{"

        json+='"name": "'$current_library'", '
        json+='"path": "'$current_path'", '
        json+='"dependencies": ['
        deps_arr=($(cat $workdir_path/dependencies))
        for ((a=0;$a<${#deps_arr[@]};a++)); do
            if [ $(expr $a + 1) = ${#deps_arr[@]} ]; then
                json+='"'${deps_arr[$a]}'"'
            else
                json+='"'${deps_arr[$a]}'", '
            fi
        done

        json+='], '
        json+='"used_by": ['
        used_arr=($(cat $workdir_path/used_by))
        for ((a=0;$a<${#used_arr[@]};a++)); do
            if [ $(expr $a + 1) = ${#used_arr[@]} ]; then
                json+='"'${used_arr[$a]}'"'
            else
                json+='"'${used_arr[$a]}'", '
            fi
        done
        json+=']'

        if [ $(expr $i + 1) = ${#libs32[@]} ]; then
            json+="}"
        else
            json+="}, "
        fi
    done
    json+='], '

    # 64-bit libraries
    json+='"libraries_64": ['
    for ((i=0;$i<${#libs64[@]};i++)); do
        current_library="${libs64[$i]}"
        current_path="${libs_paths64[$i]}"
        workdir_path="$workdir/.temp_gentree/libraries_64/$current_library"

        json+="{"

        json+='"name": "'$current_library'", '
        json+='"path": "'$current_path'", '
        json+='"dependencies": ['
        deps_arr=($(cat $workdir_path/dependencies))
        for ((a=0;$a<${#deps_arr[@]};a++)); do
            if [ $(expr $a + 1) = ${#deps_arr[@]} ]; then
                json+='"'${deps_arr[$a]}'"'
            else
                json+='"'${deps_arr[$a]}'", '
            fi
        done

        json+='], '
        json+='"used_by": ['
        used_arr=($(cat $workdir_path/used_by))
        for ((a=0;$a<${#used_arr[@]};a++)); do
            if [ $(expr $a + 1) = ${#used_arr[@]} ]; then
                json+='"'${used_arr[$a]}'"'
            else
                json+='"'${used_arr[$a]}'", '
            fi
        done
        json+=']'

        if [ $(expr $i + 1) = ${#libs64[@]} ]; then
            json+="}"
        else
            json+="}, "
        fi
    done
    json+=']'

    json+="}"

    echo "$(jq . <<< "$json")" > $workdir/tree.json
}

echo "Initializing..."

gen_libraries_paths
gen_json_structure
generate_data
generate_json_from_data

echo "Done! Your json: $workdir/tree.json"
