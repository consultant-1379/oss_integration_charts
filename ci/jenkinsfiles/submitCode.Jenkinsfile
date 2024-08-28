#!/usr/bin/env groovy

/* IMPORTANT:
 *
 * In order to make this pipeline work, the following configuration on Jenkins is required:
 * - slave with a specific label (see pipeline.agent.label below)
 * - Credentials Plugin should be installed and have the secrets with the following names:
 *   + eo-helm-repo-api-token (token to access Helm repository)
 */

def bob = "bob/bob -r \${WORKSPACE}/ci/rulesets/ruleset2.0.yaml"

pipeline {
    parameters {
        string(name: 'GERRIT_USER_SECRET',
                defaultValue: 'eoadm100-user-credentials',
                description: 'Jenkins secret ID with Gerrit username and password')
        string(name: 'ARMDOCKER_USER_SECRET',
                defaultValue: 'eoadm100-docker-auth-config',
                description: 'ARM Docker secret')
        string( name: 'GERRIT_REFSPEC',
                description: 'Ref Spec from the Gerrit review. Example: refs/changes/10/5002010/1.')
        string( name: 'CHART_NAME',
                description: 'Comma-separated dependency helm chart name list. E.g.: eric-pm-server, eric-data-document-database-pg')
        string( name: 'CHART_VERSION',
                description: 'Comma-separated dependency helm chart version list. E.g.: 1.0.0+66, 2.3.0+57')
        string( name: 'CHART_REPO',
                description: 'Comma-separated dependency helm chart url list. E.g.: https://arm.rnd.ki.sw.ericsson.se/artifactory/proj-pm-1,https://arm.rnd.ki.sw.ericsson.se/artifactory/proj-pm-2')
        string( name: 'GIT_REPO_URL',
                defaultValue: 'https://gerrit.ericsson.se/a/OSS/com.ericsson.oss.aeonic/oss_integration_charts.git',
                description: 'gerrit https url to helm chart git repo. Example: https://gerrit.ericsson.se/adp-cicd/demo-app-release-chart')
        string( name: 'VCS_BRANCH',
                defaultValue: 'master',
                description: 'Branch for the change to be pushed')
        string( name: 'CHART_PATH',
                defaultValue: 'charts/eric-oss',
                description: 'Relative path to helm chart in git repo.')
        string( name: 'HELM_INTERNAL_REPO',
                defaultValue: 'https://arm.seli.gic.ericsson.se/artifactory/proj-eric-oss-ci-internal-helm',
                description: 'Internal Helm chart repository url.')
        string( name: 'HELM_DROP_REPO',
                defaultValue: 'https://arm.seli.gic.ericsson.se/artifactory/proj-eric-oss-drop-helm',
                description: 'Drop Helm chart repository url.')
        string( name: 'HELM_RELEASED_REPO',
                defaultValue: 'https://arm.seli.gic.ericsson.se/artifactory/proj-eric-oss-released-helm-perm',
                description: 'Released Helm chart repository url.')
        string( name: 'HELM_REPO_CREDENTIALS_ID',
                defaultValue: 'eoadm100_helm_repository_creds',
                description: 'Repositories.yaml file credential used for auth')
        string( name: 'ALLOW_DOWNGRADE',
                defaultValue: 'true',
                description: 'Default is \'false\', if set to true, downgrade of dependency is allowed.')
        string( name: 'IGNORE_NON_RELEASED',
                defaultValue: 'false',
                description: 'Default is \'false\', if set to true, wont upload helm chart to drop or release repo if CHART_VERSION is non-released (e.g. 1.0.0-11).')
        string( name: 'AUTOMATIC_RELEASE',
                defaultValue: 'true',
                description: 'Default is \'true\', if set to true, publish integration helm chart to released repo if all dependencies are released.')
        string( name: 'ALWAYS_RELEASE',
                defaultValue: 'false',
                description: 'Default is \'false\', if set to true, Always use upload to released repo with released version.')
        choice( name: 'VERSION_STEP_STRATEGY_DEPENDENCY',
                choices: "PATCH\nMINOR\nMAJOR",
                description: 'Possible values: MAJOR, MINOR, PATCH. Step this digit automatically in Chart.yaml after release when dependency change received. Default is PATCH')
        choice( name: 'VERSION_STEP_STRATEGY_MANUAL',
                choices: "PATCH\nMINOR\nMAJOR",
                description: 'Possible values: MAJOR, MINOR, PATCH. Step this digit automatically in Chart.yaml after release when manaul change received. Default is MINOR')
        choice( name: 'GERRIT_PREPARE_OR_PUBLISH',
                choices: "prepare\npublish\nprepare-dev\nprep\n",
                description: 'prepare-dev :: Prepare Integration Helm Chart for development\nprepare :: Prepare Integration Helm Chart\npublish :: Publish Integration Helm Chart\npublish :: Checks in the updates to git and upload to the release repo\nprep :: Builds a local copy of the snapshot tar file and executes the precode tests against the updated chart')
        string( name: 'COMMIT_MESSAGE_FORMAT_MANUAL',
                defaultValue: '%ORIGINAL_TITLE (%INT_CHART_VERSION)',
                description: 'User defined manual git commit message format string template')
        string( name: 'GIT_TAG_ENABLED',
                defaultValue: 'true',
                description: 'Create a tag for the git commit, default is false')
        string( name: 'WAIT_SUBMITTABLE_BEFORE_PUBLISH',
                defaultValue: 'true',
                description: 'For the publish command, wait for the gerrit patch to be set for a verified +1 or +2 or both before submitting, default is false')
        string( name: 'WAIT_TIMEOUT_SEC_BEFORE_PUBLISH',
                defaultValue: '120',
                description: 'Timeout in seconds wait for a verifed +1 or +2 or both before submitting. Default is 120s.')
        string( name: 'PRE_CODE_LEVEL',
                defaultValue: 'application',
                description: 'This is used to tell what time DR tests to execute whether it is all the full application level or just the eo top level, option application or eo')
        string(name: 'SLAVE_LABEL',
                defaultValue: 'evo_docker_engine',
                description: 'Specify the slave label that you want the job to run on')
    }
    agent {
        label env.SLAVE_LABEL
    }
    environment {
        HELM_REPO_CREDENTIALS = "${env.WORKSPACE}/repositories.yaml"
        UPLOAD_INTERNAL = false
        HELM_UPLOAD_REPO = "${params.HELM_INTERNAL_REPO}"
    }
    stages {
        stage('Cleaning Git Repo') {
            steps {
                sh 'git submodule sync'
                sh 'git submodule update --init --recursive'
                sh "${bob} git-clean"
            }
        }
        stage('Checkout Commit/Branch') {
            options { retry(3) }
			steps {
                script {
                    if (params.GERRIT_REFSPEC) {
                        checkout([$class: 'GitSCM',
                                  branches: [[name: "FETCH_HEAD"]],
                                  doGenerateSubmoduleConfigurations: false,
                                  extensions: [[$class: 'CleanBeforeCheckout']],
                                  submoduleCfg: [],
                                  userRemoteConfigs:  [[credentialsId: params.GERRIT_USER_SECRET, refspec: params.GERRIT_REFSPEC, url: env.GIT_URL]]
                        ])
                    } else {
                        checkout([$class: 'GitSCM',
                                  branches: [[name: params.VCS_BRANCH]],
                                  doGenerateSubmoduleConfigurations: false,
                                  extensions: [[$class: 'CleanBeforeCheckout']],
                                  submoduleCfg: [],
                                  userRemoteConfigs: [[credentialsId: params.GERRIT_USER_SECRET, url: env.GIT_URL]]
                        ])
                    }
                }
            }
        }
        stage('Prep helm chart') {
            when {
                expression { params.GERRIT_PREPARE_OR_PUBLISH == "prep" }
            }
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: params.GERRIT_USER_SECRET, usernameVariable: 'GERRIT_USERNAME', passwordVariable: 'GERRIT_PASSWORD'), file(credentialsId: env.HELM_REPO_CREDENTIALS_ID, variable: 'HELM_REPO_CREDENTIALS_FILE'), string(credentialsId: 'eo-helm-repo-api-token', variable: 'ARM_API_TOKEN')]) {
                        sh "install -m 600 ${HELM_REPO_CREDENTIALS_FILE} ${env.HELM_REPO_CREDENTIALS}"
                        sh "${bob} review-publish-submit-chart"
                    }
                }
            }
        }
        stage('Copy Helm Template to Workspace Base Dir'){
            when {
                expression { params.GERRIT_PREPARE_OR_PUBLISH == "prep" }
            }
            steps {
                sh "${bob} copy-helm-template-to-base-dir"
            }
        }

        stage('Validate Helm3 Chart Schema') {
            when {
                expression { params.GERRIT_PREPARE_OR_PUBLISH == "prep" }
            }
            steps{
                wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                    sh "${bob} validate-helm3-charts"
                }
            }
        }
        stage('Build Helm Testsuite Image'){
            when {
                expression { params.GERRIT_PREPARE_OR_PUBLISH == "prep" }
            }
            steps {
                sh "${bob} build-testsuite-image"
            }
        }
        stage('Run Helm Chart Testsuite'){
            when {
                expression { params.GERRIT_PREPARE_OR_PUBLISH == "prep" }
            }
            steps {
                sh "${bob} run-chart-testsuite"
            }
            post {
                always {
                    sh "${bob} test-suite-report-and-clean"
                    archiveArtifacts artifacts: 'chart-test-report.html', allowEmptyArchive: true
                }
            }
        }
        stage('Set Design Rules Check parameters appropriate for the flow'){
            when {
                expression { params.GERRIT_PREPARE_OR_PUBLISH == "prep" }
            }
            steps {
                sh "${bob} set-design-rule-parameters"
            }
        }
        stage('Design Rules Check') {
            when {
                expression { params.GERRIT_PREPARE_OR_PUBLISH == "prep" }
            }
            steps {
                withCredentials([file(credentialsId: env.HELM_REPO_CREDENTIALS_ID, variable: 'HELM_REPO_CREDENTIALS_FILE')]) {
                    sh "install -m 600 ${HELM_REPO_CREDENTIALS_FILE} ${HELM_REPO_CREDENTIALS}"
                    sh "${bob} design-rule-checker || true"
                }
            }
            post {
                always {
                    archiveArtifacts 'design-rule-check-report.html'
                }
            }
        }
        stage('Kubernetes Range Compatibility Tests') {
            when {
                expression { params.GERRIT_PREPARE_OR_PUBLISH == "prep" }
            }
            steps {
                sh "${bob} kube-version kubeval deprek8ion"
            }
        }
        stage('Package and release helm chart') {
            when {
                expression { params.GERRIT_PREPARE_OR_PUBLISH != "prep" }
            }
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: params.GERRIT_USER_SECRET, usernameVariable: 'GERRIT_USERNAME', passwordVariable: 'GERRIT_PASSWORD'), file(credentialsId: env.HELM_REPO_CREDENTIALS_ID, variable: 'HELM_REPO_CREDENTIALS_FILE'), string(credentialsId: 'eo-helm-repo-api-token', variable: 'ARM_API_TOKEN')]) {
                        sh "install -m 600 ${HELM_REPO_CREDENTIALS_FILE} ${env.HELM_REPO_CREDENTIALS}"
                        sh "${bob} review-publish-submit-chart"
                        sh 'echo "TYPE_DEPLOYMENT=${GERRIT_PREPARE_OR_PUBLISH}" >> artifact.properties'
                        archiveArtifacts 'artifact.properties'
                    }
                }
            }
        }
    }
}
