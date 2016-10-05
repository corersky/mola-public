#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

####################################################
# Defaults
####################################################
DU_LOG="/var/tmp/du.log"
BAMBOO_EC2_PROPS='/home/bamboo/.ec2/ec2.properties'
RELEASES_ARCHIVE_DIR='/home/bamboo/ak_releases'
DOWNLOAD_USER_EC2_PROPS='/home/download/ec2/ec2.properties.bamboo'
BAMBOO_JDK_8_STRING='JDK-1.8'
BAMBOO_JDK_DEFAULT='JDK-1.7'
GRADLE_WRAPPER='./gradlew'
GRADLE_TMP_BASE='/tmp/gradlehome'
buildProperties="src/build/ant/build.properties"
PARQUET='-Duse-parquet-storage=true'
declare -A myEnvVariables # fresh set of envVars to fill on a per job basis

# util to get a green build name
function getGB() { echo "Datameer - Green Builds - $@ - job"; }
function getIB() { echo "Datameer - Info Builds - $@ - job"; }

# jobNames
declare -A jobNames
# Green Builds
jobNames[compile]="$(getGB 'Compile Datameer Distributions')"
jobNames[findbugs]="$(getGB 'Findbugs')"
jobNames[unitTests]="$(getGB 'Unit Tests')"
jobNames[itTests]="$(getGB 'Integration Tests')"
jobNames[itTestsLong]="$(getGB 'Long Running Integration Tests')"
jobNames[jsSpecs]="$(getGB 'Javascript Specs')"
jobNames[embeddedCluster]="$(getGB 'Embedded Cluster')"
jobNames[efwLocal]="$(getGB 'EFW Local')"
jobNames[efwSmallJob]="$(getGB 'EFW Small Job')"
jobNames[efwMapReduce]="$(getGB 'EFW MapReduce')"
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
# Info Builds
jobNames[efwSparkClientFull]="$(getIB 'EFW Spark Client (full)')"
jobNames[efwSparkClusterFull]="$(getIB 'EFW Spark Cluster (full)')"
jobNames[efwTezFull]="$(getIB 'EFW Tez (full)')"
jobNames[itTestsLong18]="$(getIB 'Long Running Integration Tests (JDK-1.8)')"
jobNames[psfUnitTests]="$(getIB 'Parquet Unit Tests')"
jobNames[psfItTests]="$(getIB 'Parquet Integration Tests')"
jobNames[psfItTestsLong]="$(getIB 'Parquet Long Running Integration Tests')"
jobNames[psfEmbeddedCluster]="$(getIB 'Parquet Embedded Cluster')"
# other builds
jobNames[allDists]='Datameer - Releases - All Distributions - job'

# Default values
VERBOSE=0
DRYRUN=0


function usage()
{
cat << EOF
usage: $0 [OPTIONS]

This script executes a job step according to the job name.

OPTIONS:
   -h      Show this message
   -v      Verbose
   -j <j>  JobName
   -l      List possible job names
   -L      List possible job names and dry-run
   -d      Dry run
EOF
}

function preTasks() {
    echoInfo "In preTasks..."
    jobCreatesTestXmls=true
    if [ $DRYRUN  -eq 0 ]; then
        printDiskUsage 'PRE '
    fi
}

function postTasks() {
    echoInfo "In postTasks..."
    if [ $DRYRUN  -eq 0 ]; then
        printDiskUsage 'POST'
        outputDiskUsageForjob
        # If we got this far without an exiting with an error, check for unit-test files.
        # If there are none, add a dummy.
        if [[ "$jobCreatesTestXmls" == 'false' ]]; then
            addDummyUnitTestXmlIfNeeded
        fi
    else
        if [[ "$jobCreatesTestXmls" == 'false' ]]; then
            echoInfo "DRYRUN: Adding a dummy test xml if none found..."
        fi
    fi
}

function outputDiskUsageForjob() {
    if onBamboo; then
        if [ -f "$DU_LOG" ]; then
            echoInfo "Disk usage from job below sorted by mount point: "
            tail -n $tailNum $DU_LOG | sort -k 11
        fi
    fi
}

function printDiskUsage() {
    if onBamboo; then
        local dt=$(date '+%D %T')
        local prefix=$(printf "%s " "$dt $1"; printf "%*s" -50 "${bamboo_agentId} ${bamboo_buildResultKey}")
        local dfOutput=$(df -h | sed -e 1d | sort -u -k 6) # shows only the unique filesystems and no header
        local numOfLines=$(echo "$dfOutput" | wc -l)
        let "tailNum=$numOfLines*10" # needed for grepping number of lines in post step
        while read line; do
            echo "$prefix $line" >> $DU_LOG
        done <<< "$dfOutput"
    fi
}

function die() {
    (>&2 echo -e "RUN-TASK - ERROR: $@")
    exit 1
}

function echoInfo() {
    echo -e "RUN-TASK - INFO:  $@"
}

function echoDebug() {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "RUN-TASK - DEBUG: $@"
    fi
}

function copyEc2Properties() {
    echoInfo "Downloading ec2.properties for CI Server..."
    scp download@build.datameer.com:$DOWNLOAD_USER_EC2_PROPS "$bamboo_build_working_directory/modules/dap-common/src/it/resources/ec2.properties"
    # if [ -e "$BAMBOO_EC2_PROPS" ]; then
    #     exec cp "$BAMBOO_EC2_PROPS" "$bamboo_build_working_directory/modules/dap-common/src/it/resources/ec2.properties"
    # fi
}

function listJobs() {
    printf "%-25s   %s\n" "SHORTNAME" "LONGNAME"
    for i in "${!jobNames[@]}"; do
        printf "%-25s   %s\n" "$i" "${jobNames[$i]}"
    done
}

function listJobsAndDryRun() {
    printf "%-25s   %s\n" "SHORTNAME" "LONGNAME"
    for i in "${!jobNames[@]}"; do
        printf "########### %-25s   %s\n" "$i" "${jobNames[$i]}"
        setDryRun
        runJob $i
    done
}

function atLeastVersion() {
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

function checkJdk() {
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

function checkAnt() {
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

function onBamboo() {
    [[ "$USER" == "bamboo" ]]
}

function setJdk() {
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

function setAnt() {
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

function setEnvVars() {
    # need to add this to workaround https://issues.gradle.org/browse/GRADLE-2795
    if onBamboo; then
        myEnvVariables[GRADLE_USER_HOME]="$HOME/.gradle_for_agent_$bamboo_agentId"
    fi
    # Add ANT_OPTS again if not null
    if [ -n "$ANT_OPTS" ]; then
        myEnvVariables[ANT_OPTS]="$ANT_OPTS"
    fi
    for i in "${!myEnvVariables[@]}"
    do
        echoInfo "Exporting... $i=${myEnvVariables[$i]}"
        exec export $i="'${myEnvVariables[$i]}'"
    done
}

function exec() {
    if [ $DRYRUN  -eq 1 ]; then
        echoInfo "DRYRUN: $@"
        return 0
    fi
    eval "$@"
}

function runAnt() {
    local jdkVersion=$1
    local antVersion=$2
    local target=$3
    if onBamboo; then
        echoInfo "Fix for BAM-55: adding tmp directory setting to all builds"
        mkdir -v "$bamboo_build_working_directory/tmp"
        ANT_OPTS="$ANT_OPTS -Djava.io.tmpdir=$bamboo_build_working_directory/tmp"
        copyEc2Properties
        echoInfo "Adding plan name per default"
        ANT_OPTS="$ANT_OPTS $(getAntOptPlanName)"
    fi
    setEnvVars
    setJdk $jdkVersion
    setAnt $antVersion
    cmd="ant $target"
    echoInfo "Running... $cmd"
    exec $cmd
}

function runGradle() {
    [ -x $GRADLE_WRAPPER ] || die "File '$GRADLE_WRAPPER' either non-existent or not executable."
    local jdkVersion=$1
    local antVersion=$2
    local target=$3
    if onBamboo; then
        echoInfo "Fix for BAM-55: adding tmp directory setting to all builds"
        mkdir -pv "$bamboo_build_working_directory/tmp"
        target="$target -Djava.io.tmpdir=$bamboo_build_working_directory/tmp"
        echoInfo "Adding plan name per default"
        target="$target $(getGradleOptPlanName)"
        target="$target -PignoreTestFailures=true"
        copyEc2Properties
    fi
    setEnvVars
    setJdk $jdkVersion
    setAnt $antVersion
    cmd="$GRADLE_WRAPPER $target"
    echoInfo "Running... $cmd"
    exec $cmd
}

function runNpm() {
    local target=$1
    setEnvVars
    cmd="npm $target"
    echoInfo "Running... $cmd from $(pwd)"
    echoInfo "In directory... $(pwd)"
    exec $cmd
}


function getKey() {
    for i in "${!jobNames[@]}"; do
        if [ "$1" == "$i" ] || [ "$1" == "${jobNames[$i]}" ] ; then
              echo "$i"
        fi
    done
}

function notImpemented() {
    if [ $DRYRUN  -eq 1 ]; then
        echoInfo "DRYRUN: Job not yet implemented"
    else
        die "Not yet implemented" # TODO: what to do here?
    fi
}

function getAntOptsBasic() {
    local ANT_OPTS=''
    ANT_OPTS="$ANT_OPTS -Dhalt.on.failure=false -DshowOutput=false"
    ANT_OPTS="$ANT_OPTS -Xmx${1:-512}m -XX:MaxPermSize=256m"
    echo "$ANT_OPTS"
}

function getAntOptsEfwLocal() {
    local ANT_OPTS=''
    ANT_OPTS="$ANT_OPTS -Dhalt.on.failure=false -DshowOutput=false"
    ANT_OPTS="$ANT_OPTS -Xmx2048m"
    ANT_OPTS="$ANT_OPTS -Dtest.groups=${2:-execution_framework}"
    ANT_OPTS="$ANT_OPTS -Dexecution-framework=$1"
    echo "$ANT_OPTS"
}

function getAntOptsEfw() {
    local ANT_OPTS=''
    ANT_OPTS="$(getAntOptsEfwLocal $*)"
    ANT_OPTS="$ANT_OPTS -Dhadoop.dist=cdh-5.4.2-mr2"
    ANT_OPTS="$ANT_OPTS -Dtest.cluster=ec2"
    echo "$ANT_OPTS"
}

function getAntOptPlanName() {
    if onBamboo; then
        # Git branch can contain '/' and can cause problems with tests that use this property
        if [[ 'master' == "$bamboo_repository_branch_name" ]]; then
            echo "-Dplan.name=${bamboo_buildResultKey}-${bamboo_repository_branch_name}"
        else
            echo "-Dplan.name=${bamboo_buildResultKey}-${bamboo_shortPlanName}"
        fi
    else
        echo "-Dplan.name=${bamboo_buildResultKey:-dummyKey}-${bamboo_repository_branch_name:-dummyBranch}"
    fi
}

function getGradleOptPlanName() {
    getAntOptPlanName
}

function runJob() {
    preTasks
    local jobArg=$1
    # the following two lines are necessary because, on branch runs, the bamboo_buildPlanName
    # has the branch and job name as a suffix. These must be removed!
    local planNameInQuestion=${bamboo_buildPlanName:-}
    if [[ "master" != "${bamboo_repository_branch_name:-}" ]]; then
        planNameInQuestion="${planNameInQuestion// - ${bamboo_shortPlanName:-}/}"
    fi
    local jobInQuestion="${jobArg:-$planNameInQuestion}"
    [ -z "$jobInQuestion" ] && die "Neither bamboo_buildPlanName variable nor input argument passed."
    local shortName=$(getKey "$jobInQuestion")
    [ -n "$shortName" ] || die "Could not find '$jobInQuestion' in job list. Check the supported job list."
    echoInfo "Looking for '$jobInQuestion',  with shortName '$shortName'"

    local ANT_OPTS=''
    case "$shortName" in

        'allDists')
            echoInfo "Running...$jobInQuestion"
            jobCreatesTestXmls=false
            if atLeastVersion 9; then
                notImpemented
            else
                ANT_OPTS="$(getAntOptsBasic)"
                runAnt 17 19 'clean-all dist-all-versions'
                local distArtifactDir="/tmp/dummy-local-archive-dir"
                if onBamboo; then
                    distArtifactDir="$RELEASES_ARCHIVE_DIR/$bamboo_planRepository_revision"
                fi
                echoInfo "Copying all dist artifacts to '$distArtifactDir'"
                exec mkdir -p "$distArtifactDir"
                exec cp "build/dist/*" "$distArtifactDir"
            fi
            ;;

        # jobNames[compile]="$(getGB 'Compile Datameer Distributions')"
        'compile')
            echoInfo "Running...$jobInQuestion"
            jobCreatesTestXmls=false
            if atLeastVersion 6; then
                for ver in $(./gradlew versions | grep -P "^\t[a-z]+"); do
                    runGradle 17 19 "compileIntegTestJava jobJar -DhadoopVersion=$ver"
                done
            else
                ANT_OPTS="$(getAntOptsBasic)"
                runAnt 17 19 'clean-all it-jar job-jar'
            fi
            ;;

        # jobNames[findbugs]="$(getGB 'Findbugs')"
        'findbugs')
            echoInfo "Running...$jobInQuestion"
            jobCreatesTestXmls=false
            if atLeastVersion 6; then
                runGradle 17 19 'findbugsMain'
                echoInfo "Exit code: $?"
            else
                ANT_OPTS="$(getAntOptsBasic)"
                runAnt 17 19 'clean-all findbugs-core findbugs-plugins'
            fi
            ;;

        # jobNames[unitTests]="$(getGB 'Unit Tests')"
        'unitTests')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.1; then
                runGradle 17 19 'test'
            else
                ANT_OPTS="$(getAntOptsBasic)"
                runAnt 17 19 "clean-all unit"
            fi
            ;;

        # jobNames[itTests]="$(getGB 'Integration Tests')"
        'itTests')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
                runGradle 17 19 'downloadEc2StaticPropertyEU integTest'
            else
                ANT_OPTS="$(getAntOptsBasic 1024)"
                runAnt 17 19 "clean-all download-ec2-static-property it"
            fi
            ;;

        # jobNames[itTestsLong]="$(getGB 'Long Running Integration Tests')"
        'itTestsLong')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
                runGradle 17 19 'downloadEc2StaticPropertyEU integTest -Dtest.groups=long'
            else
                ANT_OPTS="$(getAntOptsBasic)"
                runAnt 17 19 "clean-all download-ec2-static-property it-long"
            fi
            ;;

        # jobNames[jsSpecs]="$(getGB 'Javascript Specs')"
        'jsSpecs')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
                myEnvVariables[CHROME_BIN]="/opt/google/chrome/google-chrome"
                myEnvVariables[FIREFOX_BIN]="/opt/firefox_30.0_js/firefox"
                myEnvVariables[DISPLAY]="localhost:0.0"
                exec cd modules/dap-conductor
                runNpm 'test'
            else
                ANT_OPTS="$(getAntOptsBasic)"
                runAnt 17 19 "clean-all specs"
            fi
            ;;

        # jobNames[localDB]="$(getGB 'Local Database Tests')"
        'localDB')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
                runGradle 17 19 'dap-common:integTest -Dtest.groups=db_netezza'
            else
                ANT_OPTS="$(getAntOptsBasic 1024)"
                runAnt 17 19 "clean-all it-db-netezza"
            fi
            ;;

        # jobNames[remoteDB]="$(getGB 'Remote Database Tests')"
        'remoteDB')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
                # not using until the necessary gradle tasks are implemented
                # see: https://jira.datameer.com/browse/BUILD-128
                # runGradle 17 19 'downloadEc2StaticPropertyEU dap-common:integTest dap-conductor:integTest pluginsIntegTest -Dtest.groups=scp,s3,db'
            else
                ANT_OPTS="$(getAntOptsBasic 1024)"
                runAnt 17 19 "clean-all download-ec2-static-property it-external-resources-managed"
            fi
            ;;

        # jobNames[clusterTests]="$(getGB 'Cluster Tests')"
        'embeddedCluster')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6; then
                runGradle 17 19 'downloadEc2StaticPropertyEU integTest -Dtest.groups=cluster'
            else
                ANT_OPTS="$(getAntOptsBasic 1024)"
                ANT_OPTS="$ANT_OPTS -Dtest.groups=cluster"
                runAnt 17 19 "clean-all download-ec2-static-property it"
            fi
            ;;

        # jobNames[efwLocal]="$(getGB 'EFW Local')"
        'efwLocal')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$(getAntOptsEfw Local)"
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSmallJob]="$(getGB 'EFW Small Job')"
        'efwSmallJob')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$(getAntOptsEfw SmallJob)"
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwMapReduce]="$(getGB 'EFW MapReduce')"
        'efwMapReduce')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$(getAntOptsEfw MapReduce)"
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSmart]="$(getGB 'EFW Smart')"
        'efwSmart')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS=$(getAntOptsEfw Smart)
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSparkClient]="$(getGB 'EFW Spark Client')"
        'efwSparkClient')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS=$(getAntOptsEfw SparkClient)
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSparkCluster]="$(getGB 'EFW Spark Cluster')"
        'efwSparkCluster')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS=$(getAntOptsEfw SparkCluster)
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSparkSX]="$(getGB 'EFW Spark SX')"
        'efwSparkSX')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS=$(getAntOptsEfw SparkSX)
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwTez]="$(getGB 'EFW Tez')"
        'efwTez')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS=$(getAntOptsEfw Tez)
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[findbugs18]="$(getGB 'Findbugs (JDK-1.8)')"
        'findbugs18')
            echoInfo "Running...$jobInQuestion"
            jobCreatesTestXmls=false
            if atLeastVersion 6; then
                runGradle 18 19 findbugsMain
            else
                ANT_OPTS="$(getAntOptsBasic)"
                runAnt 18 19 "clean-all findbugs-core findbugs-plugins"
            fi
            ;;

        # jobNames[unitTests18]="$(getGB 'Unit Tests (JDK-1.8)')"
        'unitTests18')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 6.2; then
                runGradle 18 19 'test'
            else
                ANT_OPTS="$(getAntOptsBasic)"
                runAnt 18 19 "clean-all unit"
            fi
            ;;

        # jobNames[itTests18]="$(getGB 'Integration Tests (JDK-1.8)')"
        'itTests18')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                runGradle 18 19 'downloadEc2StaticPropertyEU integTest'
            else
                ANT_OPTS="$(getAntOptsBasic 1024)"
                runAnt 18 19 "clean-all download-ec2-static-property it"
            fi
            ;;

        # jobNames[efwSparkClientFull]="$(getIB 'EFW Spark Client (full)')"
        'efwSparkClientFull')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$(getAntOptsEfw SparkClient cluster,dist_sanity)"
                ANT_OPTS="$ANT_OPTS -DinstanceType=m3.large"
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwSparkClusterFull]="$(getIB 'EFW Spark Cluster (full)')"
        'efwSparkClusterFull')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$(getAntOptsEfw SparkCluster cluster,dist_sanity)"
                ANT_OPTS="$ANT_OPTS -DinstanceType=m3.large"
                ANT_OPTS="$ANT_OPTS -Dspark.thrift=true"
                runAnt 17 19 "clean-all download-ec2-static-property unit it-ec2-managed"
            fi
            ;;

        # jobNames[efwTezFull]="$(getIB 'EFW Tez (full)')"

        'efwTezFull')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$(getAntOptsEfw Tez cluster,dist_sanity)"
                ANT_OPTS="$ANT_OPTS"
                runAnt 17 19 "clean-all download-ec2-static-property it-ec2-managed"
                # TODO: why no unit test? (comparing to e.g. efwSparkClientFull)
            fi
            ;;

        # jobNames[itTestsLong18]="$(getIB 'Long Running Integration Tests (JDK-1.8)')"
        'itTestsLong18')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                runGradle 18 19 'downloadEc2StaticPropertyEU integTest -Dtest.groups=long'
            else
                ANT_OPTS="$(getAntOptsBasic)"
                runAnt 18 19 "clean-all download-ec2-static-property it-long"
            fi
            ;;

        # jobNames[psfUnitTests]="$(getGB 'Parquet Unit Tests')"
        'psfUnitTests')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$(getAntOptsBasic) $PARQUET"
                runAnt 17 19 "clean-all unit"
            fi
            ;;

        # jobNames[psfItTests]="$(getGB 'Parquet Integration Tests')"
        'psfItTests')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$ANT_OPTS $PARQUET"
                ANT_OPTS="$ANT_OPTS -Xmx1024m -XX:MaxPermSize=256m"
                ANT_OPTS="$ANT_OPTS -XX:SurvivorRatio=6"
                ANT_OPTS="$ANT_OPTS -XX:+UseConcMarkSweepGC"
                ANT_OPTS="$ANT_OPTS -XX:CMSInitiatingOccupancyFraction=80"
                ANT_OPTS="$ANT_OPTS -DshowOutput=false"
                ANT_OPTS="$ANT_OPTS -Dhalt.on.failure=false"
                runAnt 17 19 "clean-all download-ec2-static-property it"
            fi
            ;;

        # jobNames[psfItTestsLong]="$(getGB 'Parquet Long Running Integration Tests')"
        'psfItTestsLong')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$ANT_OPTS $PARQUET"
                ANT_OPTS="$ANT_OPTS -Xmx1024m -XX:MaxPermSize=256m"
                ANT_OPTS="$ANT_OPTS -XX:SurvivorRatio=6"
                ANT_OPTS="$ANT_OPTS -XX:+UseConcMarkSweepGC"
                ANT_OPTS="$ANT_OPTS -XX:CMSInitiatingOccupancyFraction=80"
                ANT_OPTS="$ANT_OPTS -DshowOutput=false"
                ANT_OPTS="$ANT_OPTS -Dhalt.on.failure=false"
                runAnt 17 19 "clean-all download-ec2-static-property it-long"
            fi
            ;;

        # jobNames[psfEmbeddedCluster]="$(getGB 'Parquet Embedded Cluster')"
        'psfEmbeddedCluster')
            echoInfo "Running...$jobInQuestion"
            if atLeastVersion 9.2; then
                notImpemented
            else
                ANT_OPTS="$ANT_OPTS $PARQUET"
                ANT_OPTS="$ANT_OPTS -Dtest.groups=cluster,dist_sanity"
                ANT_OPTS="$ANT_OPTS -Dtest.cluster=in_vm"
                ANT_OPTS="$ANT_OPTS -Dhalt.on.failure=false"
                ANT_OPTS="$ANT_OPTS -Xmx768m"
                ANT_OPTS="$ANT_OPTS -DinstanceType=m3.large"
                runAnt 17 19 "clean-all download-ec2-static-property it"
            fi
            ;;

        *)
            die "Job with name '$jobInQuestion' not found/supported."
            ;;
    esac
    echoInfo "Finished...'$jobInQuestion'"
    postTasks
}

function addDummyUnitTestXmlIfNeeded() {
    if [ $DRYRUN  -eq 0 ]; then
        local jsSpecsTestFiles="$(find . -name ui-specs-results -type d | xargs -I{} find {} -name "*-results.xml" -type f)"
        local unitTestFiles="$(find . -name unit-reports -type d | xargs -I{} find {} -name "TEST-*.xml" -type f)"
        local itTestFiles="$(find . -name it-reports -type d | xargs -I{} find {} -name "TEST-*.xml" -type f)"
        local itTestFilesGradle="$(find . -name test-results -type d | xargs -I{} find {} -name "TEST-*.xml" -type f)"
        cd "$myDir"
        if [ -z "$jsSpecsTestFiles$unitTestFiles$itTestFiles$itTestFilesGradle" ]; then
            echoInfo "Could not find any Junit test files. Adding a dummy..."
            mkdir -pv modules/dap-common/build/reports/it-reports
            echo '<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
   <testsuite name="JUnitXmlReporter" errors="0" tests="1" failures="0" time="0" timestamp="2015-01-01T00:00:01">
      <testcase classname="DummyTestToFoolBambooJunitParser" name="dummyTest" time="0.000" />
   </testsuite>
</testsuites>' > modules/dap-common/build/reports/it-reports/junit-template.xml
        else
            echoInfo "Found some junit test files. No need to create a dummy."
            echoDebug "Listing: jsSpecsTestFiles"
            echoDebug "$jsSpecsTestFiles"
            echoDebug "Listing: unitTestFiles"
            echoDebug "$unitTestFiles"
            echoDebug "Listing: itTestFiles"
            echoDebug "$itTestFiles"
            echoDebug "Listing: itTestFilesGradle"
            echoDebug "$itTestFilesGradle"
        fi
    fi
}

function setDryRun() { DRYRUN=1; }

function setVerbose() { VERBOSE=1; }

function finish() {
    # echoInfo "In 'finish' function, triggered on signal EXIT."
    # cleanup gradle temp directory if created.
    if [[ "${gradleTmpDir:-}" == $GRADLE_TMP_BASE/* ]]; then
        echoInfo "Cleaning up gradle temp directory if present..."
        rm -rf "$gradleTmpDir" ]] || true
    fi
    # [ $? -eq 0 ] && echo "Done!"
}

###############################################
# Program
###############################################
myDir="$(pwd)"
trap finish EXIT
# Options parsing
while getopts “:hvdlLj:” OPTION
do
     case $OPTION in
    h)
        usage
        exit 0
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
