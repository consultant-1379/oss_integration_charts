FROM armdocker.rnd.ericsson.se/dockerhub-ericsson-remote/amd64/python:3.6.10-alpine

RUN apk add curl unzip

WORKDIR /helm3/
RUN curl -O https://arm1s11-eiffel052.eiffel.gic.ericsson.se:8443/nexus/service/local/repositories/eo-3pp-foss/content/org/cncf/helm/3.2.0/helm-3.2.0.zip \
 && unzip helm-3.2.0.zip \
 && mv /helm3/linux-amd64/helm /usr/bin/helm \
 && rm -rf /helm3

WORKDIR /testsuite/

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY site_values.yaml setup.cfg /testsuite/
COPY src /testsuite/helm-chart-validator

ENTRYPOINT ["pytest", "--html=report.html", "--self-contained-html", "/testsuite/helm-chart-validator"]
