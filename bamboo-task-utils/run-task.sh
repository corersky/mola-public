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
GRADLE_WRAPPER='./gradlew'
buildProperties="src/build/ant/build.properties"

# util to get a green build name
getGB() { echo "Datameer - Green Builds - $@ - job"; }
declare -A jobNames
jobNames[compile]="$(getGB 'Compile Datameer Distributions')"
jobNames[findbugs]="$(getGB 'Findbugs')"
jobNames[unitTests]="$(getGB 'Unit Tests')"
jobNames[itTests]="$(getGB 'Integration Tests')"
jobNames[itTestsLong]="$(getGB 'Long Running Integration Tests')"
jobNames[jsSpecs]="$(getGB 'Javascript Specs')"
jobNames[embeddedCluster]="$(getGB 'Embedded Cluster')"
jobNames[efwLocal]="$(getGB 'EFW Local')"
jobNames[efwSmallJob]="$(getGB 'EFW Small Job')"
jobNames[efwSmart]="$(getGB 'EFW Smart')"
jobNames[efwSparkClient]="$(getGB 'EFW Spark Client')"
jobNames[efwSparkCluster]="$(getGB 'EFW Spark Cluster')"
jobNames[efwSparkSX]="$(getGB 'EFW Spark SX')"
jobNames[efwTez]="$(getGB 'EFW Tez')"
jobNames[findbugs18]="$(getGB 'Findbugs (JDK-1.8)')"
jobNames[unitTests18]="$(getGB 'Unit Tests (JDK-1.8)')"
jobNames[itTests18]="$(getGB 'Integration Tests (JDK-1.8)')"
jobNames[localDB]="$(getGB 'Local Database Tests')"
jobNames[remoteDB]="$(getGB 'Remote Database Tests')"

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
        exec cp "$BAMBOO_EC2_PROPS" "$bamboo_build_working_directory/modules/dap-common/src/it/resources/ec2.properties"
    fi
}

listJobs() {
    printf "%-25s   %s\n" "SHORTNAME" "LONGNAME"
    for i in "${!jobNames[@]}"; do
        printf "%-25s   %s\n" "$i" "${jobNames[$i]}"
    done
}

listJobsAndDryRun() {
    printf "%-25s   %s\n" "SHORTNAME" "LONGNAME"
    for i in "${!jobNames[@]}"; do
        printf "%-25s   %s\n" "$i" "${jobNames[$i]}"
        setDryRun && setVerbose
        runJob $i
    done
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
    [ "$latestVersion" == "$version" ]
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
    if [ $expectedVersion -ne $version ]; then
        local errorMsg="Wrong java version found. Found '$version', expected '$expectedVersion'"
        if [ $DRYRUN  -eq 1 ]; then
            echoInfo "DRYRUN: $errorMsg"
        else
            die "$errorMsg"
        fi
     fi
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
    if [ $expectedVersion -ne $version ]; then
        local errorMsg="Wrong ant version found. Found '$version', expected '$expectedVersion'"
        if [ $DRYRUN  -eq 1 ]; then
            echoInfo "DRYRUN: $errorMsg"
        else
            die "$errorMsg"
        fi
     fi
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
        exec export $i="'${myEnvVariables[$i]}'"
    done
}

exec() {
    if [ $DRYRUN  -eq 1 ]; then
        echoInfo "DRYRUN: $@"
        return 0
    fi
    eval "$@"
}

# environment variables need to be set before
runAnt() {
    local jdkVersion=$1
    local antVersion=$2
    local target=$3
    setJdk $jdkVersion
    setAnt $antVersion
    cmd="ant $target"
    echoInfo "Running... $cmd"
    exec $cmd
}

# environment variables need to be set before
runGradle() {
    [ -x $GRADLE_WRAPPER ] || die "File '$GRADLE_WRAPPER' either non-existent or not executable."
    local jdkVersion=$1
    local antVersion=$2
    local target=$3
    setJdk $jdkVersion
    setAnt $antVersion
    cmd="$GRADLE_WRAPPER $target"
    echoInfo "Running... $cmd"
    exec $cmd
}

getKey() {
    for i in "${!jobNames[@]}"; do
        if [ "$1" == "$i" ] || [ "$1" == "${jobNames[$i]}" ] ; then
              echo "$i"
        fi
    done
}

optCommon() { echo "-Dhalt.on.failure=false -DshowOutput=false"; }
optEFW() { echo "-Dexecution-framework=$1 -Dtest.groups=${2:-execution_framework}"; }
optPlan() {
    if onBamboo; then
        echo "-Dplan.name=${bamboo_buildResultKey}-${bamboo_repository_branch.name}"
    else
        echo "-Dplan.name=${bamboo_buildResultKey:-dummyKey}-${bamboo_repository_branch_name:-dummyBranch}"
    fi
}
optDist() { echo "-Dhadoop.dist=$1"; }
optTestGroups() { echo "-Dtest.groups=$1"; }

runJob() {
    local ANT_OPTS_BASIC="$(optCommon) -Xmx512m  -XX:MaxPermSize=256m -Dmysql.tests.enabled=true"
    local ANT_OPTS_IT_LONG="$(optCommon) -Xmx512m  -XX:MaxPermSize=256m"
    local ANT_OPTS_IT="$(optCommon) -Xmx1024m -XX:MaxPermSize=256m"
    local ANT_OPTS_CLUSTER="$(optCommon) -Xmx1024m -XX:MaxPermSize=256m $(optTestGroups cluster)"
    local ANT_OPTS_CLUSTER_EC2="$(optCommon) -Xmx1024m -XX:MaxPermSize=256m $(optPlan)"
    local ANT_OPTS_CLUSTER_EFW_LOCAL="$(optCommon) -Xmx512m -XX:MaxPermSize=256m $(optEFW Local)"
    local ANT_OPTS_CLUSTER_EFW_SMALL="$(optCommon) -Xmx2048m $(optEFW SmallJob) $(optDist cdh-5.4.2-mr2) $(optPlan) -Dtest.cluster=ec2"
    local ANT_OPTS_CLUSTER_EFW_MIXED="$(optCommon) -Xmx2048m $(optEFW ExampleMixed) $(optDist cdh-5.4.2-mr2) $(optPlan) -Dtest.cluster=ec2"
    local ANT_OPTS_CLUSTER_EFW_SMART="$(optCommon) -Xmx2048m $(optEFW Smart) $(optDist cdh-5.4.2-mr2) $(optPlan) -Dtest.cluster=ec2"
    local ANT_OPTS_CLUSTER_EFW_SPARK_CLIENT="$(optCommon) -Xmx2048m $(optEFW SparkClient cluster,dist_sanity) $(optDist cdh-5.4.2-mr2) $(optPlan) -Dtest.cluster=ec2 -DinstanceType=m3.large"
    local ANT_OPTS_CLUSTER_EFW_SPARK_CLUSTER="$(optCommon) -Xmx2048m $(optEFW SparkCluster) $(optDist cdh-5.4.2-mr2) $(optPlan) -Dtest.cluster=ec2"
    local ANT_OPTS_CLUSTER_EFW_SPARK_SX="$(optCommon) -Xmx2048m $(optEFW SparkSx) $(optDist cdh-5.4.2-mr2) $(optPlan) -Dtest.cluster=ec2"
    local ANT_OPTS_CLUSTER_EFW_TEZ="$(optCommon) -Xmx2048m $(optEFW Tez dist_sanity) $(optDist cdh-5.4.2-mr2) $(optPlan) -Dtest.cluster=ec2"
    # TODO: why -Dmysql.tests.enabled=true?
    # TODO: why 1024m for some jobs and only 512m for others?

    local jobInQuestion="${1:-${bamboo_buildPlanName:-}}"
    [ -z "$jobInQuestion" ] && die "Neither bamboo_buildPlanName variable nor input argument passed."
    local shortName=$(getKey "$jobInQuestion")
    [ -n "$shortName" ] || die "Could not find '$jobInQuestion' in job list. Check the supported job list."
    echo "Looking for '$jobInQuestion',  with shortName '$shortName'"
    declare -A myEnvVariables # fresh set of envVars to fill on a per job basis
    case "$shortName" in

        # jobNames[compile]="$(getGB 'Compile Datameer Distributions')"
        'compile')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
                local tmpDir=/tmp/gradlehome/${bamboo_buildKey:-local-run}
                exec mkdir -pv $tmpDir
                runGradle 17 19 "onAllVersions -i -Ptarget=it-jar --gradle-user-home $tmpDir"
                runGradle 17 19 "onAllVersions -i -Ptarget=job-jar --gradle-user-home $tmpDir"
            else
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_BASIC"
                setEnvVars
                runAnt 17 19 'clean-all it-jar job-jar'
            fi
            ;;

        # jobNames[findbugs]="$(getGB 'Findbugs')"
        'findbugs')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
                runGradle 17 19 findbugs
            else
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_BASIC"
                setEnvVars
                runAnt 17 19 'clean-all findbugs-core findbugs-plugins'
            fi
            ;;

        # jobNames[unitTests]="$(getGB 'Unit Tests')"
        'unitTests')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 17 19 test
            else
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_BASIC"
                setEnvVars
                runAnt 17 19 "clean-all unit"
            fi
            ;;

        # jobNames[itTests]="$(getGB 'Integration Tests')"
        'itTests')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                die "Not yet implemented" # TODO: fill with life
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_IT"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property it"
            fi
            ;;

        # jobNames[itTestsLong]="$(getGB 'Long Running Integration Tests')"
        'itTestsLong')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                die "Not yet implemented" # TODO: fill with life
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_IT_LONG"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property it-long"
            fi
            ;;

        # jobNames[jsSpecs]="$(getGB 'Javascript Specs')"
        'jsSpecs')
            if [ $DRYRUN  -eq 1 ]; then
                echoInfo "DRYRUN: Job not yet implemented"
            else
                die "Not yet implemented" # TODO: what to do here?
            fi
            ;;

        # jobNames[localDB]="$(getGB 'Local Database Tests')"
        'localDB')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                die "Not yet implemented" # TODO: fill with life
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EC2"
                setEnvVars
                runAnt 17 19 "clean-all it-db-netezza"
            fi
            ;;

        # jobNames[remoteDB]="$(getGB 'Remote Database Tests')"
        'remoteDB')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                die "Not yet implemented" # TODO: fill with life
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EC2"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property it-external-resources-managed"
            fi
            ;;

        # jobNames[clusterTests]="$(getGB 'Cluster Tests')"
        'embeddedCluster')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                die "Not yet implemented" # TODO: fill with life
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EC2"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property it"
            fi
            ;;

        # jobNames[efwLocal]="$(getGB 'EFW Local')"
        'efwLocal')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 17 19 test
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EFW_LOCAL"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property it"
            fi
            ;;

        # jobNames[efwSmallJob]="$(getGB 'EFW Small Job')"
        'efwSmallJob')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 17 19 test
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EFW_SMALL"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSmart]="$(getGB 'EFW Smart')"
        'efwSmart')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 17 19 test
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EFW_SMART"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSparkClient]="$(getGB 'EFW Spark Client')"
        'efwSparkClient')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 17 19 test
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EFW_SPARK_CLIENT"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSparkCluster]="$(getGB 'EFW Spark Cluster')"
        'efwSparkCluster')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 17 19 test
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EFW_SPARK_CLUSTER"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSparkSX]="$(getGB 'EFW Spark SX')"
        'efwSparkSX')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 17 19 test
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EFW_SPARK_SX"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwTez]="$(getGB 'EFW Tez')"
        'efwTez')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 17 19 test
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_CLUSTER_EFW_TEZ"
                setEnvVars
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[findbugs18]="$(getGB 'Findbugs (JDK-1.8)')"
        'findbugs18')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 18 19 findbugs
            else
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_BASIC"
                setEnvVars
                runAnt 18 19 "clean-all findbugs-core findbugs-plugins"
            fi
            ;;

        # jobNames[unitTests18]="$(getGB 'Unit Tests (JDK-1.8)')"
        'unitTests18')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 18 19 test
            else
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_BASIC"
                setEnvVars
                runAnt 18 19 "clean-all unit"
            fi
            ;;

        # jobNames[itTests18]="$(getGB 'Integration Tests (JDK-1.8)')"
        'itTests18')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 18 19 it
            else
                copyEc2Properties
                myEnvVariables[ANT_OPTS]="$ANT_OPTS_IT"
                setEnvVars
                runAnt 18 19 "clean-all download-ec2-static-property it"
            fi
            ;;

        *)
            die "Job with name '$jobInQuestion' not found/supported."
            ;;
    esac
}

setDryRun() { DRYRUN=1; }
setVerbose() { VERBOSE=1; }

###############################################
# Program
###############################################
# Options parsing
while getopts “:hvdlLj:” OPTION
do
     case $OPTION in
    h)
        usage
        exit
        ;;
    d)
        setDryRun
        ;;
    j)
        JOB_ARG=$OPTARG
        ;;
    l)
        listJobs
        exit 0
        ;;
    L)
        listJobsAndDryRun
        exit 0
        ;;
    v)
        setVerbose
        ;;
    ?)
        die "Unrecognised option."
        ;;
    esac
done


# atLeastVersion 6 && echo "6 yes" || echo "6 no"
# atLeastVersion 6.2 && echo "6.2 yes" || echo "6.2 no"
# atLeastVersion 6.11 && echo "6.11 yes" || echo "6.11 no"
# atLeastVersion 6.2.0 && echo "6.2.0 yes" || echo "6.2.0 no"
# atLeastVersion 6.1.9 && echo "6.1.9 yes" || echo "6.1.9 no"
runJob "${JOB_ARG:-}"
[ $? -eq 0 ] && echo "Done!"

