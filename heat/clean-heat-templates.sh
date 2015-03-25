#!/bin/bash

heat stack-list | awk '{ print $4 }' | xargs heat stack-delete
