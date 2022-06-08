#!/bin/bash

# Destination directory of modifications
DEST="."

# Original project variables
originalProjectName="project"
originalPackageName="github.com/sagikazarmark/modern-go-application"
originalBinaryName="modern-go-application"
originalAppName="mga"
originalFriendlyAppName="Modern Go Application"

# Prepare testing
if [[ ! -z "${TEST}" ]]; then
    #set -xe
    DEST="tmp/inittest"
    mkdir -p ${DEST}
    echo "." > tmp/.gitignore
fi

function prompt() {
    echo -n -e "\033[1;32m?\033[0m \033[1m$1\033[0m ($2) "
}

function replace() {
    if [[ ! -z "${TEST}" ]]; then
        dest=$(echo $2 | sed "s|^${DEST}/||")
        mkdir -p $(dirname "${DEST}/${dest}")
        if [[ "$2" == "${DEST}/${dest}" ]]; then
            sed -E -e "$1" $2 > ${DEST}/${dest}.new
            mv -f ${DEST}/${dest}.new ${DEST}/${dest}
        else
            sed -E -e "$1" $2 > ${DEST}/${dest}
        fi
    else
        sed -E -e "$1" $2 > $2.new
        mv -f $2.new $2
    fi
}

function move() {
    if [[ ! -z "${TEST}" ]]; then
        dest=$(echo $2 | sed "s|^${DEST}/||")
        mkdir -p $(dirname "${DEST}/${dest}")
        cp -r "$1" ${DEST}/${dest}
    else
        mv $@
    fi
}

function remove() {
    if [[ -z "${TEST}" ]]; then
        rm $@
    fi
}

defaultPackageName=${PWD##*src/}
prompt "Package name" ${defaultPackageName}
read packageName
packageName=$(echo "${packageName:-${defaultPackageName}}" | sed 's/[[:space:]]//g')

defaultProjectName=$(basename ${packageName})
prompt "Project name" ${defaultProjectName}
read projectName
projectName=$(echo "${projectName:-${defaultProjectName}}" | sed 's/[[:space:]]//g')

prompt "Binary name" ${projectName}
read binaryName
binaryName=$(echo "${binaryName:-${projectName}}" | sed 's/[[:space:]]//g')

prompt "Application name" ${projectName}
read appName
appName=$(echo "${appName:-${projectName}}" | sed 's/[[:space:]]//g')

defaultFriendlyAppName=$(echo "${appName}" | sed -e 's/-/ /g;' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1')
prompt "Friendly application name" "${defaultFriendlyAppName}"
read friendlyAppName
friendlyAppName=${friendlyAppName:-${defaultFriendlyAppName}}

prompt "Update README" "Y/n"
read updateReadme
updateReadme=${updateReadme:-y}

prompt "Remove init script" "y/N"
read removeInit
removeInit=${removeInit:-n}

# IDE configuration
move .idea/${originalProjectName}.iml .idea/${projectName}.iml
replace "s|.idea/${originalProjectName}.iml|.idea/${projectName}.iml|g" .idea/modules.xml

# Run configurations
replace 's|name="project"|name="'${projectName}'"|' .idea/runConfigurations/All_tests.xml
replace 's|name="project"|name="'${projectName}'"|; s|value="\$PROJECT_DIR\$\/cmd\/'${originalBinaryName}'\/"|value="$PROJECT_DIR$/cmd/'${binaryName}'/"|' .idea/runConfigurations/Debug.xml
replace 's|name="project"|name="'${projectName}'"|' .idea/runConfigurations/Integration_tests.xml
replace 's|name="project"|name="'${projectName}'"|' .idea/runConfigurations/Tests.xml
replace "s|${originalBinaryName}|${binaryName}|" .vscode/launch.json

# Binary changes:
#   - binary name
#   - source code
#   - variables
move cmd/${originalBinaryName} cmd/${binaryName}
replace "s|${originalAppName}|${appName}|; s|${originalFriendlyAppName}|${friendlyAppName}|" ${DEST}/cmd/${binaryName}/main.go
find ${DEST}/cmd -type f | while read file; do replace "s|${originalPackageName}|${packageName}|" "$file"; done

# Other project files
declare -a files=("CHANGELOG.md" "prototool.yaml" "go.mod" ".golangci.yml" "gqlgen.yml")
for file in "${files[@]}"; do
    if [[ -f "${file}" ]]; then
        replace "s|${originalPackageName}|${packageName}|" ${file}
    fi
done
declare -a files=("prototool.yaml")
for file in "${files[@]}"; do
    if [[ -f "${file}" ]]; then
        replace "s|${originalProjectName}|${projectName}|" ${file}
    fi
done
declare -a files=("Dockerfile")
for file in "${files[@]}"; do
    if [[ -f "${file}" ]]; then
        replace "s|${originalBinaryName}|${binaryName}|" ${file}
    fi
done

# Update source code
find .gen -type f | while read file; do replace "s|${originalPackageName}|${packageName}|" "$file"; done
find internal -type f | while read file; do replace "s|${originalPackageName}|${packageName}|" "$file"; done

if [[ "${removeInit}" != "n" && "${removeInit}" != "N" ]]; then
    remove "$0"
fi

# Update readme
if [[ "${updateReadme}" == "y" || "${updateReadme}" == "Y" ]]; then
    echo -e "# FRIENDLY_PROJECT_NAME\n\n**Project description.**" | sed "s/FRIENDLY_PROJECT_NAME/${friendlyAppName}/" > ${DEST}/README.md
fi
