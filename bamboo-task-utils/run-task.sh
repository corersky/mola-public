#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

####################################################
# Defaults
####################################################
BAMBOO_EC2_PROPS='/home/bamboo/.ec2/ec2.properties'
BAMBOO_JDK_8_STRING='JDK-1.8'
BAMBOO_JDK_DEFAULT='JDK-1.7'

ANT_OPTS_BASIC="-Dhalt.on.failure=false -Dmysql.tests.enabled=true -Xmx512m -XX:MaxPermSize=256m"
GRADLE_WRAPPER='./gradlew'

declare -A myEnvVariables


#$ curl -sSk --user $BAM_API_USER:$BAM_API_PW "https://build.datameer.com/rest/api/latest/project/MASTER.json?expand=plans.plan.stages.stage.plans.plan" | python -m json.tool | grep "                                        \"name.*," | sed 's/.*"name\": \"//' | sed 's/\",$//'
declare -A jobNames
jobNames[compile]='Datameer - Green Builds - Compile Datameer Distributions - it-jar and job-jar'
jobNames[findbugs]='Datameer - Green Builds - Unit Tests - findbugs'
jobNames[unitTests]='Datameer - Green Builds - Unit Tests - Unit Tests'

jobNames[dbLocal]='Datameer - Master Branch - Database Tests - Local Database Tests'
jobNames[dbRemote]='Datameer - Master Branch - Database Tests - Remote Database Tests'
jobNames[itTestsCluster]='Datameer - Master Branch - Embedded Cluster (APACHE-2.6.0) - Integration Tests'
jobNames[itTestsEC2]='Datameer - Master Branch - Full YARN Cluster Test (HDP-2.1.2) - EC2 Integration Tests'
jobNames[itTests]='Datameer - Master Branch - Integration Tests - Integration Tests'
jobNames[itTests1.8]='Datameer - Master Branch - Integration Tests (JDK-1.8) - Integration Tests'
jobNames[jsSpecs]='Datameer - Master Branch - JavaScript Specifications - Specs'
jobNames[localEF]='Datameer - Master Branch - Local Execution Framework - Default'
jobNames[itTestsLong]='Datameer - Master Branch - Long Running Integration Tests - Default Job'
jobNames[itTestsLong1.8]='Datameer - Master Branch - Long Running Integration Tests (JDK-1.8) - Default Job'
jobNames[mixedEF]='Datameer - Master Branch - Mixed Execution Framework (CDH-5.0.5) - Default Job'
jobNames[parquetItTestsEmbedded]='Datameer - Master Branch - Parquet Storage Format - Embedded Cluster'
jobNames[parquetItTests]='Datameer - Master Branch - Parquet Storage Format - Integration Tests'
jobNames[parquetItTestsLong]='Datameer - Master Branch - Parquet Storage Format - Long Running Tests'
jobNames[parquetUnitTests]='Datameer - Master Branch - Parquet Storage Format - Unit Tests'
jobNames[smallEF]='Datameer - Master Branch - Small Job Execution Framework (CDH-5.0.5) - Default Job'
jobNames[smartEF]='Datameer - Master Branch - Smart Execution Framework (CDH-5.1.0) - Default Job'
jobNames[sparkClientEF]='Datameer - Master Branch - Spark Client Execution Framework (CDH-5.4.2) - Default Job'
jobNames[sparkClientEFFull]='Datameer - Master Branch - Spark Client Execution Framework (full) - Default Job'
jobNames[sparkClusterEF]='Datameer - Master Branch - Spark Cluster Execution Framework (CDH-5.4.2) - Default Job'
jobNames[sparkClusterEFFull]='Datameer - Master Branch - Spark Cluster Execution Framework (full) - Default Job'
jobNames[sparkSxEF]='Datameer - Master Branch - Spark SX Framework (CDH-5.4.2) - Default Job'
jobNames[tezEF]='Datameer - Master Branch - Tez Execution Cluster (HDP-2.1.2) - Default Job'
jobNames[tezEFFast]='Datameer - Master Branch - Tez Execution Cluster Fast (CDH-5.3.0) - Default Job'
jobNames[findbugsCore1.8]='Datameer - Master Branch - Unit Test (JDK-1.8) - Findbugs core'
jobNames[findbugsPlugins1.8]='Datameer - Master Branch - Unit Test (JDK-1.8) - Findbugs plugins'
jobNames[unitTests1.8]='Datameer - Master Branch - Unit Test (JDK-1.8) - Unit Tests'
jobNames[findbugsCore]='Datameer - Master Branch - Unit Tests - Findbugs'
jobNames[findbugsPlugins]='Datameer - Master Branch - Unit Tests - Findbugs plugins'


buildProperties="src/build/ant/build.properties"


usage()
{
cat << EOF
usage: $0 [OPTIONS]

This script executes a job step according to the job name.

OPTIONS:
   -h      Show this message
   -v      Verbose
   -j <j>  JobName
   -J      List possible job names
   -d      Dry run
EOF
}

# Default values
VERBOSE=0
DRYRUN=0

# Options parsing
while getopts “:hvdj:” OPTION
do
     case $OPTION in
    h)
        usage
        exit
        ;;
    d)
        DRYRUN=1
        ;;
    j)
        JOB_ARG=$OPTARG
        ;;
    J)
        listJobs
        ;;
    v)
        VERBOSE=1
        ;;
    ?)
        die "Unrecognised option."
        ;;
    esac
done

die() {
    (>&2 echo -e "RUN-TASK - ERROR: $@")
    exit 1
}

echoInfo() {
    echo -e "RUN-TASK - INFO:  $@"
}

echoDebug() {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "RUN-TASK - DEBUG: $@"
    fi
}

copyEc2Properties() {
    if [ -e "$BAMBOO_EC2_PROPS" ]; then
        exec cp /home/bamboo/.ec2/ec2.properties "$bamboo_build_working_directory/modules/dap-common/src/it/resources/ec2.properties"
    fi
}

listJobs() {
    for i in "${!array[@]}"; do
      echo "Short  : $i"
      echo "value: ${array[$i]}"
    done

}
dapVersionCheck() {
    [ ! -e $buildProperties ] && die "Cannot find file '$buildProperties'"
    local version="$(grep -oE "^version=.*" $buildProperties | cut -f2 -d'=')"
    echoInfo "Found DAP version: '$version'"
    [ ${version/\.*/} -lt 6 ] && needsAnt=1 || needsAnt=0
}

atLeastVersion() {
	local atLeastRaw=$1
	local atLeast=$(echo $atLeastRaw | sed 's/\(\.0\)*$//')
	echoDebug "At least version: '$atLeast' (normalised from $atLeastRaw)"
    [ ! -e $buildProperties ] && die "Cannot find file '$buildProperties'"
	local versionRaw="$(grep -oE "^version=.*" $buildProperties | cut -f2 -d'=')"
	local version=$(echo $versionRaw | sed 's/\(\.0\)*$//')
    echoInfo "Found DAP version: '$version' (normalised from $versionRaw). Comparing to version $atLeast"
	local latestVersion=$(echo -e "$atLeast\n$version" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -g | tail -n 1)
	echoDebug "Latest version determined as: '$latestVersion'"
	[ "$latestVersion" == "$atLeast" ]
}

checkJdk() {
    local version execProgram expectedVersion
    expectedVersion=$1 || die "No expectedVersion parameter passed."
    execProgram=$(which java || die "No java found on PATH")
    echoDebug "Using $execProgram"
    case ${#expectedVersion} in
        2) version=$(java -version 2>&1 | grep "^.*\sversion" | sed 's/.*version "\([0-9]*\)\.\([0-9]*\)\..*"/\1\2/; 1q');;
        3) version=$(java -version 2>&1 | grep "^.*\sversion" | sed 's/.*version "\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\).*"/\1\2\3/; 1q');;
        *) die "You must specify a version between 2 and 3 digits."
    esac
    echoInfo "Found java version: $version"
    [ $expectedVersion -eq $version ] || die "Wrong java version found. Expected: $expectedVersion"
}

checkAnt() {
    local version execProgram expectedVersion
    expectedVersion=$1 || die "No expectedVersion parameter passed."
    execProgram=$(which ant || die "No ant found on PATH")
    echoDebug "Using $execProgram"
    case ${#expectedVersion} in
        2) version=$(ant -version 2>&1 | grep "^.*\sversion" | sed 's/.*version \([0-9]*\)\.\([0-9]*\)\..*/\1\2/; 1q');;
        3) version=$(ant -version 2>&1 | grep "^.*\sversion" | sed 's/.*version \([0-9]*\)\.\([0-9]*\)\.\([0-9]*\) .*/\1\2\3/; 1q');;
        *) die "You must specify a version between 2 and 3 digits."
    esac
    echoInfo "Found ant version: $version"
    [ $expectedVersion -eq $version ] || die "Wrong ant version found. Expected: $expectedVersion"
}

onBamboo() {
    [[ "$USER" == "bamboo" ]]
}

setJdk() {
    if onBamboo; then
        local jdkDir
        case "$1" in
            17) jdkDir="$bamboo_capability_system_jdk_JDK_1_7";;
            18) jdkDir="$bamboo_capability_system_jdk_JDK_1_8";;
            *) die "Unexpected JDK Version '$1'";;
        esac
        [ -e "$jdkDir" ] || die "Directory '$jdkDir' not found."
        export JAVA_HOME="$jdkDir"
        export PATH="$jdkDir/bin:$PATH"
    else
        echoInfo "Not on CI Server - Not setting JDK."
    fi
    checkJdk $1
}

setAnt() {
    if onBamboo; then
        local antDir
        case "$1" in
            18) antDir="$bamboo_capability_system_builder_ant_Ant_1_8_4";;
            19) antDir="$bamboo_capability_system_builder_ant_Ant_1_9_4";;
            *) die "Unexpected ANT Version '$1'";;
        esac
        [ -e "$antDir" ] || die "Directory '$antDir' not found."
        export ANT_HOME="$antDir"
        export PATH="$antDir/bin:$PATH"
    else
        echoInfo "Not on CI Server - Not setting ANT."
    fi
    checkAnt $1
}

setEnvVars() {
    for i in "${!myEnvVariables[@]}"
    do
        echoInfo "Exporting... $i=${myEnvVariables[$i]}"
        exec export $i="${myEnvVariables[$i]}"
    done
}

exec() {
    if [ $DRYRUN  -eq 1 ]; then
        echoInfo "DRYRUN: $@"
        return 0
    fi
    eval "$@"
}

runBasicAnt() {
    local jdkVersion=$1
    local antVersion=$2
    local target=$3
    myEnvVariables[ANT_OPTS]="$ANT_OPTS_BASIC"
    setEnvVars
    setJdk $jdkVersion
    setAnt $antVersion
    cmd="ant $target"
    echoInfo "Running... $cmd"
    exec eval $cmd
}

runBasicGradle() {
    [ -x $GRADLE_WRAPPER ] || die "File '$GRADLE_WRAPPER' either non-existent or not executable."
    local jdkVersion=$1
    local antVersion=$2
    local target=$3
    setJdk $jdkVersion
    setAnt $antVersion
    cmd="$GRADLE_WRAPPER $target"
    echoInfo "Running... $cmd"
    exec eval $cmd
}

runJob() {
    local jobInQuestion="${1:-${bamboo_buildPlanName:-}}"
    [ -z "$jobInQuestion" ] && die "Neither bamboo_buildPlanName variable nor input argument passed."
    dapVersionCheck # ant or gradle
    echo "Looking for $jobInQuestion"
    case "$jobInQuestion" in

        'compile'|${jobNames['compile']})
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
				local tmpDir=/tmp/gradlehome/${bamboo_buildKey:-local-run}
                mkdir -pv $tmpDir
                runBasicGradle 17 19 "onAllVersions -i -Ptarget=it-jar --gradle-user-home $tmpDir"
                runBasicGradle 17 19 "onAllVersions -i -Ptarget=job-jar --gradle-user-home $tmpDir"
            else
				runBasicAnt 17 19 'clean-all it-jar job-jar'
            fi
            ;;

		'findbugs'|${jobNames['findbugs']})
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
				runBasicGradle 17 19 findbugs
            else
				runBasicAnt 17 19 'clean-all findbugs-core findbugs-plugins'
            fi
            ;;

		'findbugsCore'|${jobNames['findbugsCore']})
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
				runBasicGradle 17 19 findbugsCore
            else
				runBasicAnt 17 19 'clean-all findbugs-core'
            fi
            ;;

        'findbugsPlugins'|${jobNames['findbugsPlugins']})
            echoInfo "Running...$jobInQuestion"
			if atLeastVersion 6; then
				runBasicGradle 17 19 findbugsMain
            else
				runBasicAnt 17 19 'clean-all findbugs-plugins'
            fi
            ;;

        'unitTests'|${jobNames['unitTests']})
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
				runBasicGradle 17 19 test
            else
				runBasicAnt 17 19 "clean-all unit"
            fi
            ;;

        *)
            die "Job with name '$jobInQuestion' not found/supported."
            ;;
    esac
}

###############################################
# Program
###############################################
# atLeastVersion 6 && echo "6 yes" || echo "6 no"
# atLeastVersion 6.2 && echo "6.2 yes" || echo "6.2 no"
# atLeastVersion 6.11 && echo "6.11 yes" || echo "6.11 no"
# atLeastVersion 6.2.0 && echo "6.2.0 yes" || echo "6.2.0 no"
# atLeastVersion 6.1.9 && echo "6.1.9 yes" || echo "6.1.9 no"
runJob "${JOB_ARG:-}"
[ $? -eq 0 ] && echo "Done!"

