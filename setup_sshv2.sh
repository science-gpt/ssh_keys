#!/bin/bash

# URL of the GitHub repository containing public keys
github_keys_url="https://raw.githubusercontent.com/science-gpt/ssh_keys/main"

# Replace with your user list

users=("spencer" "areel" "bing" "amaan" "carter")

# Function to download and set up SSH public key for a user
setup_ssh_public_key() {
    local user=$1
    local ssh_dir="/Users/$user/.ssh"
    local key_file="id_rsa_${user}.pub"
    
    echo "Setting up SSH public key for user: $user"

    # Create .ssh directory if it doesn't exist
    sudo -u $user mkdir -p "$ssh_dir"
    sudo chmod 700 "$ssh_dir"

    # Download public key from GitHub
    local key_url="${github_keys_url}/${key_file}"
    curl -s -o "$ssh_dir/$key_file" "$key_url"

    # Check if download was successful
    if [ $? -eq 0 ]; then
        echo "Public key downloaded successfully for user: $user"

        # Check if public key file exists
        if [ -f "$ssh_dir/$key_file" ]; then
            echo "Public key file exists for user $user."

            # Check if the downloaded key is valid (does not contain "404")
            if ! grep -q "404" "$ssh_dir/$key_file"; then
                # Add or replace public key in authorized_keys
                local authorized_keys="$ssh_dir/authorized_keys"
                sudo -u $user touch "$authorized_keys"
                
                # Remove existing key if it already exists
                sudo sed -i "" "/$key_file/d" "$authorized_keys"
                
                # Add the new key
                sudo cat "$ssh_dir/$key_file" | sudo tee -a "$authorized_keys" >/dev/null
                sudo chmod 644 "$authorized_keys"
                echo "Public key added or updated in $authorized_keys for user $user"
            else
                echo "Error: Invalid key file downloaded for user $user (contains '404'). Removing..."
                rm "$ssh_dir/$key_file"
            fi
        else
            echo "Error: Public key file does not exist for user $user."
            exit 1
        fi
    else
        echo "Error: Failed to download public key for user: $user"
        exit 1
    fi
}

# Function to modify sshd_config
modify_sshd_config() {
    # Backup original sshd_config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # Modify sshd_config settings
    sudo sed -i '' 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i '' 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i '' 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
}

# Function to restart SSH service
restart_ssh_service() {
    # Restart SSH service
    sudo launchctl stop com.openssh.sshd
    sudo launchctl start com.openssh.sshd
}

echo "SSH configuration updated successfully."
# Main script starts here
echo "Starting setup process..."



# Loop through each user
for user in "${users[@]}"; do
    echo "Processing user: $user"

    # Check if user already exists
    if id "$user" &>/dev/null; then
        echo "User $user already exists."
    else
        echo "Creating user: $user"
        sudo sysadminctl -addUser "$user" -fullName "$user" -password "sciencegpt123" -admin
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create user $user"
            continue
        fi
    fi

    # Set up SSH public key for the user
    setup_ssh_public_key "$user"

    # Pause for user to review output
    echo "Press Enter to continue to modify sshd_config."
    read

    # Pause for user to review output
    echo "Press Enter to continue to the next user."
    read
done

# Main script
echo "Modifying sshd_config..."
modify_sshd_config

echo "Restarting SSH service..."
restart_ssh_service
echo "Setup process completed."
