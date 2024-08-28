#!/usr/bin/env groovy

def bob = "bob/bob -r \${WORKSPACE}/ci/rulesets/ruleset2.0.yaml"

pipeline {
    agent {
        label env.SLAVE_LABEL
    }
    parameters {
        booleanParam(name: 'RELEASE', defaultValue: true, description: 'Release the CSAR to Nexus')
        booleanParam(name: 'INCLUDE_CRD', defaultValue: false, description: 'Include CRD package in CSAR')
        string( name: 'INT_CHART_VERSION', description: 'Version of Base Chart to build from')
        string( name: 'ICCR_CRD_VERSION', defaultValue: '5.4.0+18', description: 'Version of ICCR crd helm Chart to download.')
        choice( name: 'VALUE_PACK',
                choices: "oss-so\noss-pf\noss-uds",
                description: 'Value pack to build the CSAR for'
        )
        choice( name: 'TAG',
                choices: "so\npf\nuds",
                description: 'Tag used to gather the appropriate applications from the requirements.yaml to build the CSAR'
        )
        string( name: 'SCRIPTS_DIRECTORY', defaultValue: './csar-scripts', description: 'Scripts Directory to include in CSAR. NOTE: Use Default if unsure')
        string( name: 'VALUES_DIRECTORY', defaultValue: './values/csar-builder', description: 'Values Directory to use to build the CSAR.')
        string( name: 'HELM_REPOSITORY_NAME',
                defaultValue: 'proj-eric-oss-drop-helm',
                description: 'Helm Repo to pull the base chart from. NOTE: Use Default if unsure')
        string( name: 'CSAR_STORAGE_INSTANCE',
                defaultValue: 'arm.seli.gic.ericsson.se',
                description: 'Storage Instance to push the CSARs to. NOTE: Use Default if unsure')
        string( name: 'CSAR_STORAGE_REPO',
                defaultValue: 'proj-eric-oss-drop-generic-local',
                description: 'Storage directory to push the CSARs to. NOTE: Use Default if unsure')
        string(name: 'ARMDOCKER_USER_SECRET',
                description: 'ARM Docker secret')
        string(name: 'FUNCTIONAL_USER_SECRET',
                defaultValue: 'cloudman-user-creds',
                description: 'Jenkins secret ID for ARM Registry Credentials')
        string(name: 'SLAVE_LABEL',
                defaultValue: 'evo_docker_engine',
                description: 'Specify the slave label that you want the job to run on')
    }
    stages {
        stage('Clean Workspace') {
            steps {
                sh 'git submodule sync'
                sh 'git submodule update --init --recursive'
                sh "${bob} git-clean"
            }
        }
        stage('Inject Creds') {
            steps {
                withCredentials( [file(credentialsId: params.ARMDOCKER_USER_SECRET, variable: 'dockerConfig')]) {
                    sh "install -m 666 ${dockerConfig} ${HOME}/.docker/config.json"
                }
            }
        }
        stage('Get Base Helm Chart') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.FUNCTIONAL_USER_SECRET, usernameVariable: 'FUNCTIONAL_USER_USERNAME', passwordVariable: 'FUNCTIONAL_USER_PASSWORD')]) {
                    sh "${bob} set-helm-repository fetch-chart"
                }
            }
        }
        stage('Get ICCR CRD Helm Chart') {
            when {
                expression { params.INCLUDE_CRD == true }
            }
            steps {
                sh "${bob} fetch-crd-chart"
            }
        }
        stage('Get and Retag Deployment Manager') {
            steps {
                sh "${bob} pull-deployment-manager-image"
            }
        }
        stage('Save Deployment Manager to Scripts') {
            steps {
                sh "${bob} save-deployment-manager"
            }
        }
        stage('Build the CSAR') {
            when {
                expression { params.INCLUDE_CRD == false }
            }
            steps {
                sh "${bob} build-csar"
            }
        }
        stage('Build the CSAR with ICCR CRD') {
            when {
                expression { params.INCLUDE_CRD == true }
            }
            steps {
                sh "${bob} build-csar-with-iccr-crd"
            }
        }
        stage('Upload CSAR to Storage Location') {
            when {
                expression { params.RELEASE == true }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: env.FUNCTIONAL_USER_SECRET, usernameVariable: 'FUNCTIONAL_USER_USERNAME', passwordVariable: 'FUNCTIONAL_USER_PASSWORD')]) {
                    sh "${bob} upload-csar"
                }
            }
        }
    }
    post {
        success {
            script {
                sh "rm -f ${env.WORKSPACE}/eric-${params.VALUE_PACK}-${params.INT_CHART_VERSION}.csar"
                currentBuild.description = "See published CSAR below:\nhttps://${params.CSAR_STORAGE_INSTANCE}/artifactory/${params.CSAR_STORAGE_REPO}/eric-oss/eric-${params.VALUE_PACK}/${params.INT_CHART_VERSION}"
                sh "echo 'CSAR_STORAGE_INSTANCE=${params.CSAR_STORAGE_INSTANCE}' > artifact.properties"
                sh "echo 'CSAR_STORAGE_REPO=${params.CSAR_STORAGE_REPO}' >> artifact.properties"
                archiveArtifacts 'artifact.properties'
            }
        }
    }
}
