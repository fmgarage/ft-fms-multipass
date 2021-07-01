#!/usr/bin/env bash

# remove
function remove_instance() {
    printf "stopping instance %s...\n" "$1"
    multipass stop "$1"
    printf "deleting instance %s...\n" "$1"
    multipass delete "$1"
    printf "purging...\n"
    multipass purge
}
