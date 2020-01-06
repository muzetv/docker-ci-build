#!/bin/sh
set -ex

env
n 12.13.0
export JAVA_HOME="$JAVA_11_HOME"
export JRE_HOME="$JRE_11_HOME"
export JDK_HOME="$JDK_11_HOME"

for tool_path in "$JAVA_HOME"/bin/*;
 do tool=`basename "$tool_path"`;
  if [ $tool != 'java-rmi.cgi' ];
  then
   update-alternatives --list "$tool" | grep -q "$tool_path" \
    && update-alternatives --set "$tool" "$tool_path";
  fi;
done

#localstack start --host &

/usr/local/bin/dockerd \
	--host=unix:///var/run/docker.sock \
	--host=tcp://127.0.0.1:2375 \
	--storage-driver=overlay2 &>/var/log/docker.log &


tries=0
d_timeout=60
until docker info >/dev/null 2>&1
do
	if [ "$tries" -gt "$d_timeout" ]; then
                cat /var/log/docker.log
		echo 'Timed out trying to connect to internal docker host.' >&2
		exit 1
	fi
        tries=$(( $tries + 1 ))
	sleep 1
done

#eval "$@"
