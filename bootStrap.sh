#!/bin/bash

clear
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 
  exit 1
fi



# Ask user for their GitHub token without displaying it
echo "What is your GitHub token?"
read -s github_token

# Validate the token
echo "Validating GitHub token..."
validation_result=$(curl -s -H "Authorization: token $github_token" https://api.github.com/user/orgs)

if [[ "$validation_result" == *"TruMeter-Cloud"* ]]; then
    echo "Token is valid."
    # You can now use $github_token in your script
else
    echo "Token is invalid or does not have access to TruMeter-Cloud."
    exit 1
fi


username="trumeter"

## don't ask for password when using sudo reboot

# Check if the sudoers file already exists
if [ ! -f /etc/sudoers.d/nopsd ]; then
    # If it doesn't exist, create the sudoers file
    echo "$username ALL=(ALL) NOPASSWD: /sbin/reboot" > $HOME/nopsd

    # Now copy this file to /etc/sudoers.d/
    cp $HOME/nopsd /etc/sudoers.d/

    # Set the correct permissions for the sudoers file
    chmod 0440 /etc/sudoers.d/nopsd

    # Remove the temporary file
    rm $HOME/nopsd

    echo "password setup so no need for sudo..."
fi
echo


## Setup read only and read-write ##

# Define the sudoers file path
sudoers_file="/etc/sudoers.d/"$username"_mount"

# Check if the sudoers file already exists
if [ ! -f "$sudoers_file" ]; then
    # If it doesn't exist, create the sudoers file
    temp_sudoers=$(mktemp)

    # Add the current user to the sudoers file for the mount command
    echo "$username ALL=(ALL) NOPASSWD: /bin/mount" > "$temp_sudoers"
    

    # Set the permissions of the temporary file
    chmod 0440 "$temp_sudoers"

    # Move the temporary file to the sudoers.d directory
    mv "$temp_sudoers" "$sudoers_file"

    echo "Passwordless mount setup for user $username..."
fi
echo


## make apt-get to be used without password

# Define the sudoers file path
sudoers_file="/etc/sudoers.d/"$username"_apt-get"

# Check if the sudoers file already exists
if [ ! -f "$sudoers_file" ]; then
    # If it doesn't exist, create the sudoers file
    temp_sudoers=$(mktemp)

    # Add the current user to the sudoers file for the mount command
    echo "$username ALL=(ALL) NOPASSWD: /usr/bin/apt-get" > "$temp_sudoers"
    

    # Set the permissions of the temporary file
    chmod 0440 "$temp_sudoers"

    # Move the temporary file to the sudoers.d directory
    sudo mv "$temp_sudoers" "$sudoers_file"

    echo "Passwordless apt-get setup for user $username..."
fi
echo


# # Replace 'username' with your actual username
# username="trumeter"

# # This command checks if the file exists
# if [ ! -f "/etc/sudoers.d/$username" ]; then
#     echo "$username ALL=(ALL:ALL) NOPASSWD:/usr/bin/apt-get" | sudo EDITOR='tee -a' visudo -f /etc/sudoers.d/$username
# fi
# echo "Passwordless apt-get setup done"
# echo



## create and change to trumeter user ##

useradd -m trumeter

# Set a password for the user
echo "Enter password for new user 'trumeter': "
read -s password
echo "trumeter:$password" | chpasswd

# Switch to the new user
su - trumeter
echo


## GITHUB ##

# Generate a new SSH key
echo "Generating a new SSH key..."

# Ask for the email associated with the GitHub account
echo "Please enter the email associated with your GitHub account:"
read email

# Create the .ssh directory in the user's home directory if it doesn't exist
mkdir -p ~/.ssh

# Generate the SSH key
ssh-keygen -t rsa -b 4096 -C "$email" -f ~/.ssh/id_rsa

echo "SSH key generated successfully."

# Start the ssh-agent in the background
eval "$(ssh-agent -s)"

# Add the SSH key to the ssh-agent
ssh-add ~/.ssh/id_rsa

echo "SSH key added to ssh-agent."

# Get the public key
public_key=$(cat ~/.ssh/id_rsa.pub)


# Use the GitHub API to add the SSH key to the account
curl -H "Authorization: token $github_token" --data "{\"title\":\"`hostname`\",\"key\":\"$public_key\"}" https://api.github.com/orgs/TruMeter-Cloud/keys

# Create the directories if they don't exist
mkdir -p ~/github
cd ~/github

#Take the file setup.sh
curl -H "Authorization: token $github_token" -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/TruMeter-Cloud/Production_RPI/contents/setup.sh


## EXECUTE SETUP.SH ## 
echo "Executing setup.sh..."
# ./setup.sh