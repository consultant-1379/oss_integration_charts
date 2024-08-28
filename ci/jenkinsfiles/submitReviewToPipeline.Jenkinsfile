#!/usr/bin/env groovy

import groovy.json.JsonOutput

node {
    stage('Call Spinnaker Webhook') {
        def json = JsonOutput.toJson(params)
        def post = new URL("https://spinnaker-api.rnd.gic.ericsson.se/webhooks/webhook/submit-oss-chart-reviews").openConnection()
        post.setRequestMethod("POST")
        post.setDoOutput(true)
        post.setRequestProperty("Content-Type", "application/json")
        post.getOutputStream().write(json.getBytes("UTF-8"))
        def postRC = post.getResponseCode()
        if(postRC.equals(200)) {
            println(post.getInputStream().getText())
        }
        else {
            println(postRC)
        }
    }
}
