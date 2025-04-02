#!/bin/bash
# Script will take list of users and their corresponding groups.
# Script will create user and groups as needed


#functions
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*()_+=-[]{}|;:<>,.?/~' </dev/urandom | head -c 16
}

#check if root user
if [[ $(id -u) != 0 ]]; then
    echo "this script must be run as root."
    exit 1
fi

#check if args are formatted correctly
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <input-file>"
    exit 1
fi

#assign vars
USER_FILE=$1
LOG_FILE="/var/log/user_management_script.log"

#parse text file 
while IFS=';' read -r username groups;
do
   #trim leading trailing whitespace
   username=$(echo "$username" | tr -d '[:space:]')
   groups=$(echo "$groups" | tr -d '[:space:]')
   
   log_message "Read line: username='$username', groups='$groups'"

   #check if strings are empty
   if [[ -z "$username" || -z "$groups" ]]; then
      log_message "Error username or group missing in line: $username"
      continue
   fi 
   
   #check if user already exists 
   if id "$username" &>/dev/null; then
       log_message "user $username already exists"
   else
       #create user
       useradd -m "$username"
       log_message "Created user: $username"
       
       #generate password
       password=$(generate_password)
       echo "$username:$password" | chpasswd

       #log password change and echo to stdout
       log_message "Set password for user: $username"
       echo "$username:$password" 
   fi    
   
   #add user to other groups
   IFS=',' read -ra group_array <<< "$groups"
   for group in "${group_array[@]}"; do

       #create group if it doesnt exists	   
       if ! getent group "$group" &>/dev/null; then
           groupadd "$group"
           log_message "Created group: $group"
	   
	   #create shared group directory
	   shared_group_dir_path="/home/shared_dir/$group"
	   mkdir $shared_group_dir_path
           
	   #change owner of directory to the group
	   chgrp $group $shared_group_dir_path

	   #set gid bit on directory
	   chmod g+s $shared_group_dir_path

	   #set sticky bit on directory
	   chmod +t $shared_group_dir_path
	   
	   log_message "Created Group and Group Folder for: $group"
       fi

       usermod -aG "$group" "$username"
       log_message "Added user $username to group: $group"      
   done	   
done < "$USER_FILE"
