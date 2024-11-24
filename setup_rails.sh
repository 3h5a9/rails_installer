#!/bin/bash

# Function to print a dynamic styled banner
print_banner() {
  echo -e "\033[1;34m#############################################################\033[0m"
  echo -e "\033[1;34m#                                                           #\033[0m"
  echo -e "\033[1;34m#        Ruby on Rails Setup ($1)                           #\033[0m"
  echo -e "\033[1;34m#                                                           #\033[0m"
  echo -e "\033[1;34m#############################################################\033[0m"
}

# Function for success message with pause
success_message() {
  echo -e "\033[1;32m$1 🎉\033[0m"
  echo -e "\n"
  sleep 3
}

# Function to restart the process if a command fails
restart_process() {
  echo -e "\033[1;31mError occurred! Restarting the entire process...\033[0m"
  sleep 2
  exec "$0"  # Restart the script from the beginning
}

# Enable error detection: if any command fails, exit the script
set -e

# Step 1: Update system packages
print_banner "Updating System Packages"
echo -e "\033[1;33mUpdating system packages...\033[0m"
sudo apt-get update -y || restart_process
success_message "System packages updated successfully!"

# Step 2: Install necessary dependencies for Ruby
print_banner "Installing Ruby Dependencies"
echo -e "\033[1;33mInstalling dependencies for Ruby...\033[0m"
sudo apt install -y build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev || restart_process
success_message "Dependencies installed successfully!"

# Step 3: Install Mise (Ruby version manager)
print_banner "Installing Mise (Ruby Version Manager)"
echo -e "\033[1;33mInstalling Mise...\033[0m"
curl https://mise.run | sh || restart_process
echo 'eval "$(~/.local/bin/mise activate)"' >> ~/.bashrc
source ~/.bashrc || restart_process
success_message "Mise installed successfully!"

# Step 4: Choose Ruby version
print_banner "Choosing Ruby Version"
echo -e "\033[1;33mWhich version of Ruby would you like to install?\033[0m"
echo -e "\033[1;33mEnter the version (e.g., 3.1.2) or press Enter to install the latest stable version.\033[0m"
read ruby_version

if [ -z "$ruby_version" ]; then
  ruby_version="latest"  # Default to the latest stable version
  echo -e "\033[1;33mNo Ruby version specified. Installing the latest stable version of Ruby...\033[0m"
fi

mise use --global ruby@$ruby_version || restart_process
success_message "Ruby $ruby_version installed successfully!"

# Step 5: Update Rubygems to the latest version
print_banner "Updating Rubygems"
echo -e "\033[1;33mUpdating Rubygems...\033[0m"
gem update --system || restart_process
success_message "Rubygems updated successfully!"

# Step 6: Optionally install Node.js (for handling assets)
print_banner "Installing Node.js"
echo -e "\033[1;33mDo you want to install Node.js for asset management? (y/n)\033[0m"
read install_node
if [ "$install_node" == "y" ]; then
  mise use --global node@22.11.0 || restart_process
  node -v || restart_process
  success_message "Node.js installed successfully!"
else
  echo -e "\033[1;33mSkipping Node.js installation.\033[0m"
fi

# Step 7: Configure Git
print_banner "Configuring Git"
echo -e "\033[1;33mConfiguring Git...\033[0m"
git config --global color.ui true || restart_process
echo -e "\033[1;33mEnter your GitHub username (or full name) to configure Git:\033[0m"
read git_name
echo -e "\033[1;33mEnter your GitHub email address:\033[0m"
read git_email
git config --global user.name "$git_name" || restart_process
git config --global user.email "$git_email" || restart_process
success_message "Git configured successfully!"

# Step 8: Generate SSH key for GitHub
print_banner "Generating SSH Key for GitHub"
echo -e "\033[1;33mGenerating SSH key for GitHub...\033[0m"
echo -e "\033[1;33mWhen prompted for a file to save the key, just press Enter to use the default location (/home/$USER/.ssh/id_ed25519)\033[0m"
echo -e "\033[1;33mIf you're unsure, simply press Enter.\033[0m"
ssh-keygen -t ed25519 -C "$git_email" || restart_process

# Show the generated SSH key and how to add it to GitHub
echo -e "\n\033[1;33m### Important: Copy the following SSH key to your GitHub account ###\033[0m"
echo -e "\n\033[1;32m$(cat ~/.ssh/id_ed25519.pub)\033[0m"
echo -e "\n\033[1;33m### Steps to add the SSH key to GitHub ###\033[0m"
echo -e "\033[1;33m1. Go to your GitHub account: https://github.com/settings/keys\033[0m"
echo -e "\033[1;33m2. Click 'New SSH Key'.\033[0m"
echo -e "\033[1;33m3. Paste the above SSH key into the 'Key' field.\033[0m"
echo -e "\033[1;33m4. Click 'Add SSH Key' to save.\033[0m"
echo -e "\n\033[1;33mAfter adding, test the connection by running:\033[0m"
echo -e "\033[1;33m    ssh -T git@github.com\033[0m"
echo -e "\033[1;33mYou should see a success message like:\033[0m"
echo -e "\033[1;32m'You've successfully authenticated, but GitHub does not provide shell access.'\033[0m"
sleep 3

# Step 9: Choose Rails version
print_banner "Choosing Rails Version"
echo -e "\033[1;33mWhich version of Ruby on Rails would you like to install?\033[0m"
echo -e "\033[1;33mEnter the version (e.g., 7.0.4) or press Enter to install the latest stable version.\033[0m"
read rails_version

if [ -z "$rails_version" ]; then
  rails_version="latest"  # Default to the latest stable version
  echo -e "\033[1;33mNo Rails version specified. Installing the latest stable version of Rails...\033[0m"
fi

# Install Rails
print_banner "Installing Rails"
echo -e "\033[1;33mInstalling Rails version $rails_version...\033[0m"
gem install rails -v "$rails_version" || restart_process
rails -v || restart_process
success_message "Rails $rails_version installed successfully!"

# Step 10: Set up the database
print_banner "Setting Up Database"
echo -e "\033[1;33mWhich database would you like to use?\033[0m"
echo -e "\033[1;33m1 = SQLite\n2 = MySQL\n3 = PostgreSQL\033[0m"
read db_choice

# PostgreSQL user management logic
handle_postgres_user() {
  echo -e "\033[1;33mDo you want to use an existing PostgreSQL user or create a new one? (y = Use existing, n = Create new)\033[0m"
  read use_existing_user
  if [ "$use_existing_user" == "y" ]; then
    echo -e "\033[1;33mEnter the existing PostgreSQL username:\033[0m"
    read postgres_user
    # Check if the user exists
    user_check=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$postgres_user';")
    if [ "$user_check" != "1" ]; then
      echo -e "\033[1;31mError: PostgreSQL user '$postgres_user' does not exist! Please try again.\033[0m"
      handle_postgres_user
    else
      echo -e "\033[1;33mUsing existing PostgreSQL user '$postgres_user'.\033[0m"
    fi
  else
    # Create a new PostgreSQL user
    while true; do
      echo -e "\033[1;33mWhat would you like your new PostgreSQL username to be?\033[0m"
      read postgres_user

      if [ -z "$postgres_user" ]; then
        echo -e "\033[1;31mError: You must specify a username.\033[0m"
        continue
      fi

      # Check if the user already exists
      user_check=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$postgres_user';")
      if [ "$user_check" == "1" ]; then
        echo -e "\033[1;31mError: User '$postgres_user' already exists! Please choose a different name.\033[0m"
      else
        break
      fi
    done
    echo -e "\033[1;33mCreating PostgreSQL user '$postgres_user'...\033[0m"
    sudo -u postgres psql -c "CREATE USER $postgres_user WITH PASSWORD 'yourpassword';" || restart_process
    sudo -u postgres psql -c "ALTER USER $postgres_user WITH PASSWORD 'yourpassword';" || restart_process
    success_message "PostgreSQL user '$postgres_user' created successfully!"
  fi
}

# Handle the choice for PostgreSQL database
if [ "$db_choice" == "3" ]; then
  echo -e "\033[1;33mInstalling PostgreSQL...\033[0m"
  sudo apt install -y postgresql libpq-dev || restart_process
  success_message "PostgreSQL installed successfully!"
  handle_postgres_user
fi

# Final Step: Create Rails app
print_banner "Creating Rails Application"
echo -e "\033[1;33mEnter the name of your Rails application:\033[0m"
read app_name
if [ "$db_choice" == "1" ]; then
  rails new "$app_name" || restart_process
elif [ "$db_choice" == "2" ]; then
  rails new "$app_name" -d mysql || restart_process
elif [ "$db_choice" == "3" ]; then
  rails new "$app_name" -d postgresql || restart_process
fi
success_message "Rails application '$app_name' created successfully!"

# Moving into app directory
cd "$app_name" || restart_process

# Final commands to create the database
echo -e "\033[1;33mSetting up the database...\033[0m"
rails db:create || restart_process
success_message "Database created successfully!"

# Final Step: Shut down the process with instructions
echo -e "\n\033[1;32mYour Rails app is ready! 🎉\033[0m"
echo -e "\033[1;33mTo run the app, navigate to your project directory and run one of the following commands:\033[0m"
echo -e "\033[1;32m    rails server\033[0m"
echo -e "\033[1;33m    or\033[0m"
echo -e "\033[1;32m    ./bin/dev\033[0m"
echo -e "\033[1;33mThis will start the server at http://localhost:3000.\033[0m"
echo -e "\033[1;33mHappy coding! 🎉\033[0m"
