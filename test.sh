#!/bin/bash
readUser(){
 STR="Hello World!"
            echo $STR  
	echo "Type the username you would like to add, followed by [ENTER]:"
	read USERNAME
}
readUser
if [ -n "$USERNAME" ]; then
	echo $USERNAME
else
	echo "Please enter valid username"
	readUser
fi

