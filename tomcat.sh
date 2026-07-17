#!/bin/bash

# 1. Check if Tomcat is already installed and loop for user input
if [ -d "tomcat" ]; then
  echo "Warning: A 'tomcat' directory already exists. Tomcat may already be installed."
  
  while true; do
    read -p "Do you want to delete the existing installation and reinstall? (y/n): " choice
    case "$choice" in 
      y|Y ) 
        echo "Removing existing Tomcat installation..."
        # Added sudo here just in case a previous install was accidentally created by root
        sudo rm -rf tomcat apache-tomcat-11.0.22*
        break
        ;;
      n|N ) 
        echo "Exiting script to prevent overwriting."
        exit 0
        ;;
      * ) 
        echo "Invalid input. Please enter 'y' or 'n'."
        ;;
    esac
  done
else
  echo "Tomcat is not installed. Proceeding with setup..."
fi

echo "Updating packages and installing dependencies..."
# 2. System updates and installing wget, java, and net-tools (Requires sudo)
sudo yum update -y

# Note: If java-21-openjdk fails to install on Amazon Linux 2023, change it to: java-21-amazon-corretto
sudo yum install -y wget java-21-openjdk net-tools

echo "Downloading and extracting Tomcat 11..."
# 3. Download, extract, and rename the directory using the permanent archive URL
wget https://archive.apache.org/dist/tomcat/tomcat-11/v11.0.22/bin/apache-tomcat-11.0.22.tar.gz
tar -xf apache-tomcat-11.0.22.tar.gz
mv apache-tomcat-11.0.22 tomcat

echo "Configuring context.xml files to allow remote access..."
# 4. Automating the 'vi' steps using 'sed' to comment out the Valve tags
for app in manager host-manager examples docs; do
  CONTEXT_FILE="tomcat/webapps/$app/META-INF/context.xml"
  
  if [ -f "$CONTEXT_FILE" ]; then
    sed -i 's/<Valve className="org.apache.catalina.valves.RemoteCIDRValve"/<!-- <Valve className="org.apache.catalina.valves.RemoteCIDRValve"/g' "$CONTEXT_FILE"
    sed -i 's/allow="127.0.0.0\/8,::1\/128" \/>/allow="127.0.0.0\/8,::1\/128" \/> -->/g' "$CONTEXT_FILE"
  fi
done

echo "Configuring Tomcat users..."
# 5. Automating the 'vi tomcat-users.xml' step to insert roles and users
sed -i '/<\/tomcat-users>/i \
  <role rolename="manager-gui"/>\
  <role rolename="manager-script"/>\
  <role rolename="manager-jmx"/>\
  <role rolename="manager-status"/>\
  <user username="admin" password="123456" roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>' tomcat/conf/tomcat-users.xml

echo "Starting Tomcat..."
# 6. Navigate to bin and start the server
cd tomcat/bin || exit
sh startup.sh

echo "Checking network ports (netstat)..."
# 7. Check if Tomcat is actively listening (Requires sudo to see the process ID)
sudo netstat -tulnp | grep java

echo "Restarting Tomcat to ensure all configurations are applied..."
# 8. Shutdown and Start cycle
sh shutdown.sh
sleep 5 # Pauses the script to ensure the port is completely freed
sh startup.sh

echo "---"
echo "Tomcat 11 installation and configuration is complete!"
