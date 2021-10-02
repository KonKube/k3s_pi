#!/bin/bash

MAIL_RECIPIENT=$1
KIND=$2

echo "$KIND `date +%Y.%m.%d' '%H:%M:%S`" | mail -s "$KIND `date +%Y.%m.%d' '%H:%M:%S`" $MAIL_RECIPIENT
