#!/usr/bin/env groovy
/* IMPORTANT:
 *
 * In order to make this pipeline work, the following configuration on Jenkins is required:
 * - slave with a specific label (see pipeline.agent.label below)
 */

def bob = "bob/bob -r \${WORKSPACE}/ci/rulesets/ruleset2.0.yaml"

pipeline {
    agent {
        label env.SLAVE_LABEL
    }
    parameters {
        string(name: 'CHART_NAME', description: 'Chart name e.g.: eric-sec-access-mgmt')
        string(name: 'CHART_VERSION', description: 'Chart version e.g.: 1.1.1')
        string(name: 'SLAVE_LABEL', defaultValue: 'evo_docker_engine', description: 'Specify the slave label that you want the job to run on')
    }
    stages {
        stage('Clean') {
            steps {
                sh 'git submodule sync'
                sh 'git submodule update --init --recursive'
                sh "${bob} git-clean"
            }
        }
        stage('Saving Requirement File Info to artifact.properties') {
            steps {
                script {
                    sh "${bob} save-requirement-file-info"
                }
            }
        }
        stage('Archiving artifact.properties') {
            steps {
                script {
                    archiveArtifacts 'artifact.properties'
                }
            }
        }
    }
}
