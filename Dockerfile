FROM ubuntu:latest

# Let's start with some basic stuff.
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get clean

#Add the Docker repository to APT sources:
RUN apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
RUN apt-get update
RUN apt-get install software-properties-common apt-transport-https ca-certificates curl git iptables ssh-askpass unzip zip wget net-tools telnet ftp vim sudo libxext-dev libxrender-dev libxtst-dev -y
RUN apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'

#Update & Upgrade
RUN apt-get update
RUN apt-get upgrade -y

# Make sure you are about to install from the Docker repo instead of the default Ubuntu 16.04 repo:
RUN apt-cache policy docker-engine
RUN apt-get install -y docker-engine

# Install Docker Compose
RUN curl -L https://github.com/docker/compose/releases/download/1.13.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

# Install Jenkins
ENV JENKINS_HOME=/var/lib/jenkins JENKINS_UC=https://updates.jenkins-ci.org HOME="/var/lib/jenkins"
RUN wget --progress=bar:force -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | apt-key add - \
	&& sh -c 'echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list' \
	&& apt-get update && apt-get install -y jenkins \
	&& apt-get clean \
	&& apt-get purge \
	&& rm -rf /var/lib/apt/lists/*

# Make the jenkins user a sudoer
# Replace the docker binary with a sudo script
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers \
	&& mv /usr/bin/docker /usr/bin/docker.bin \
	&& printf '#!/bin/bash\nsudo docker.bin "$@"\n' > /usr/bin/docker \
	&& chmod +x /usr/bin/docker

# Copy basic configuration into jenkins
COPY config.xml credentials.xml hudson.tasks.Ant.xml hudson.tasks.Maven.xml plugins.txt $JENKINS_HOME/

# Install Jenkins plugins from the specified list
# Install jobs & setup ownership & links
COPY plugins.sh /usr/local/bin/plugins.sh
COPY jobs/. $JENKINS_HOME/jobs
RUN chmod +x /usr/local/bin/plugins.sh; sleep 1 \
	&& /usr/local/bin/plugins.sh $JENKINS_HOME/plugins.txt \
	&& chown -R jenkins:jenkins /var/lib/jenkins

# Define the workspace - assuming the path does not contain #
ARG WORKSPACE='${ITEM_ROOTDIR}\/workspace'
RUN sed -i -- "s#\${ITEM_ROOTDIR}/workspace#${WORKSPACE}#" $JENKINS_HOME/config.xml

# Expose Jenkins default port
EXPOSE 8080

# Become the jenkins user (who thinks sudo is not needed for docker commands)
USER jenkins
WORKDIR /var/lib/jenkins

# Start the war
CMD ["java", "-jar", "/usr/share/jenkins/jenkins.war"]
