#!/bin/bash

set -o errexit
set -o nounset

export BIN_DIR=${BIN_DIR:-${HOME}/.local/bin}

rm -rf ${BIN_DIR}/tmp-install-savilerow
mkdir -p ${BIN_DIR}/tmp-install-savilerow
pushd ${BIN_DIR}/tmp-install-savilerow

function download {
    if which curl 2> /dev/null > /dev/null; then
        curl -L -O $1
    elif which wget 2> /dev/null > /dev/null; then
        wget --no-check-certificate -c $1
    else
        echo "You seem to have neither curl nor wget on this computer."
        echo "Cannot download without one of them."
        exit 1
    fi
}
export -f download

OS=$(uname)

if [ "$OS" == "Darwin" ]; then
    download https://savilerow.cs.st-andrews.ac.uk/savilerow-1.7.0RC-mac.tgz
    tar zxf savilerow-1.7.0RC-mac.tgz
    mv savilerow-1.7.0RC-mac/savilerow.jar ${BIN_DIR}/savilerow.jar
    mv savilerow-1.7.0RC-mac/lib ${BIN_DIR}/
    echo '#!/bin/bash'                                                               >  ${BIN_DIR}/savilerow
    echo 'DIR="$( cd "$( dirname "$0" )" && pwd )"'                                  >> ${BIN_DIR}/savilerow
    echo 'java -ea -XX:ParallelGCThreads=1 -Xmx8G -jar "$DIR/savilerow.jar" "$@"'    >> ${BIN_DIR}/savilerow
    chmod +x ${BIN_DIR}/savilerow
elif [ "$OS" == "Linux" ]; then
    download https://savilerow.cs.st-andrews.ac.uk/savilerow-1.7.0RC-linux.tgz
    tar zxf savilerow-1.7.0RC-linux.tgz
    mv savilerow-1.7.0RC-linux/savilerow.jar ${BIN_DIR}/savilerow.jar
    mv savilerow-1.7.0RC-linux/lib ${BIN_DIR}/
    echo '#!/bin/bash'                                                               >  ${BIN_DIR}/savilerow
    echo 'DIR="$( cd "$( dirname "$0" )" && pwd )"'                                  >> ${BIN_DIR}/savilerow
    echo 'java -ea -XX:ParallelGCThreads=1 -Xmx8G -jar "$DIR/savilerow.jar" "$@"'    >> ${BIN_DIR}/savilerow
    chmod +x ${BIN_DIR}/savilerow
else
    echo "Cannot determine your OS, uname reports: ${OS}"
    exit 1
fi

rm -rf ${BIN_DIR}/tmp-install-savilerow

