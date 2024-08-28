"""This module contains test cases to verify that the templates follow the guidelines for Openshift Environments."""

import pytest
from helm_template import HelmTemplate
from utils import mark_test_parameters
from memoization import cached

helm_template_object = HelmTemplate("/eric-oss.tgz", "/testsuite/site_values.yaml")

marks = [
    (['eric-am-common-wfs'], ['StatefulSet'], pytest.mark.skip(reason='Its service account is created as a manual step in CPI')),
    (['eric-sec-access-mgmt'], ['StatefulSet'], pytest.mark.skip(reason='Remove when GSSUPP-3600 is resolved.')),
    (['eric-data-search-engine-curator'], ['CronJob'], pytest.mark.skip(reason='Need to log ticket as they are missing the service account')), 
    (['eric-gr-bur-orchestrator-post-hook'], ['Job'], pytest.mark.skip(reason='Remove via SM-78549 when openshift support is added.')),
    (['eric-data-search-engine-postupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-preupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt'))
]
test_parameters = mark_test_parameters(helm_template_object.get_pod_specs(), marks)

@pytest.mark.parametrize(('template_name', 'kind', 'pod_spec'), test_parameters)
def test_service_account_referenced_per_pod(template_name, kind, pod_spec):
    """Test that there is a service account associated with each pod."""
    assert 'serviceAccountName' in pod_spec
    assert len(pod_spec['serviceAccountName']) > 0
    assert pod_spec['serviceAccountName'] in helm_template_object.get_names_of_objects_of_kind('ServiceAccount')

marks = [
    (['-database-pg$'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['-database-pg-hook'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['application-manager-postgres$'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['application-manager-postgres-hook'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-vnflcm-db$'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-vnflcm-db-hook$'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-sec-access-mgmt'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-log-transformer'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-curator'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-cm-.*-db'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['-postgres'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['ecm-admin-'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['ecm-installation-'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-gr-bur-database-pg-sa'], ['ServiceAccount'], pytest.mark.skip(reason='Remove via SM-78549 when openshift support is added.')),
    (['eric-tm-ingress-controller-cr-envoy'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-tm-ingress-controller-cr'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-subsystem-management-database-pg-pgdata-hook'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-eai-database-pg-pgdata-hook'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-gr-bur-database-pg-pgdata-hook'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-oss-notification-service-database-pg-pgdata-hook'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt')),
    (['idam-database-pg-pgdata-hook'], ['ServiceAccount'], pytest.mark.skip(reason='Not required, exempt'))
]
test_parameters = mark_test_parameters(helm_template_object.get_names_of_objects_of_kind_with_test_params('ServiceAccount'), marks)

@pytest.mark.parametrize(('template_name', 'kind', 'service_account_name'), test_parameters)
def test_openshift_cluster_role_binding_referenced_per_service_account(template_name, kind, service_account_name):
    """Test that each service account has the required openshift role binding."""
    role_bindings = helm_template_object.get_objects_of_kind('RoleBinding')
    found = False
    for role_binding in role_bindings:
        if helm_template_object.does_role_binding_have_cluster_role_reference(role_binding=role_binding, service_account_name=service_account_name, cluster_role_name='RELEASE-NAME-allowed-use-privileged-policy'):
            found = True
            break

    assert found == True

marks = [
    (['-hook-cleanup'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-message-bus-kf'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-oss-uds-service'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-cm-eoc-'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-cm-eoc'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['-postgres'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-gr-bur-orchestrator-post-hook'], ['Job'], pytest.mark.skip(reason='Remove via SM-78549 when openshift support is added.')),
    (['eric-data-search-engine-postupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-preupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt'))
]
test_parameters = mark_test_parameters(helm_template_object.get_pods_and_containers(), marks)

@pytest.mark.parametrize(('template_name', 'kind', 'pod_spec', 'container_spec'), test_parameters)
def test_to_ensure_all_containers_have_securitycontext_set(template_name, kind, pod_spec, container_spec):
    """Test that there is a securityContext associated to each pod or container."""
    assert 'securityContext' in container_spec or 'securityContext' in pod_spec

marks = [
    (['eric-data-search-engine-ingest'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-master'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-master'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-lcm-container-registry-registry'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['-pg'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['-pg'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-lcm-helm-chart-registry'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-log-transformer'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-ctrl-bro'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-coordinator-zk'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-data'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-message-bus-kf'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-pm-server'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-sec-access-mgmt'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-curator'], ['CronJob'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-wide-column-database-cd'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-wide-column-database-cd-configure-keyspaces'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-wide-column-database-cd-bra'], ['Deployment'], pytest.mark.skip(reason='SM-92538 - ADP Component Exempt')),
    (['eric-data-wide-column-database-cd-datacenter1-bra'], ['Deployment'], pytest.mark.skip(reason='SM-98825 - ADP Component Exempt')),
    (['eric-data-wide-column-database-cd-datacenter1-post'], ['Job'], pytest.mark.skip(reason='SM-98825 - ADP Component Exempt')),
    (['eric-oss-uds-service'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['-hook-cleanup'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['-postgres'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['-postgres'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-cm-eoc-'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-cm-eoc'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-gr-bur-orchestrator-post-hook'], ['Job'], pytest.mark.skip(reason='Remove via SM-78549 when openshift support is added.')),
    (['eric-sec-access-mgmt-pre-upgrade-job'], ['Job'], pytest.mark.skip(reason='never runs on upgrade')),
    (['eric-adp-gui-aggregator-service'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-tm-ingress-controller-cr-envoy'], ['DaemonSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-tm-ingress-controller-cr-contour'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-postupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-preupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-eai-database-pg-restore-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-eai-database-pg-backup-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-subsystem-management-database-pg-restore-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-subsystem-management-database-pg-backup-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-gr-bur-database-pg-restore-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-gr-bur-database-pg-backup-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-oss-common-postgres-restore-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-oss-common-postgres-backup-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-oss-notification-service-database-pg-restore-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-oss-notification-service-database-pg-backup-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['idam-database-pg-restore-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['idam-database-pg-backup-pgdata'], ['Job'], pytest.mark.skip(reason='Not required, exempt'))

]
test_parameters = mark_test_parameters(helm_template_object.get_pods_and_containers(), marks)

@pytest.mark.parametrize(('template_name', 'kind', 'pod_spec', 'container_spec'), test_parameters)
def test_to_ensure_all_containers_with_securitycontext_has_runAsUser_set(template_name, kind, pod_spec, container_spec):
    """Test that there is a runUser set with appropriate permission associated to each security context set"""
    resulting_security_context = helm_template_object.get_resulting_container_security_context(pod_spec=pod_spec, container_spec=container_spec)
    assert type(resulting_security_context.get('runAsUser', None)) is int

marks = [
    (['eric-data-search-engine-ingest'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-master'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-master'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-lcm-container-registry-registry'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-lcm-helm-chart-registry'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-ctrl-bro'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-coordinator-zk'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-data'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['-pg'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['-postgres'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-message-bus-kf'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-pm-server'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-vnflcm-db'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-wide-column-database-cd'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-wide-column-database-cd-configure-keyspaces'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-oss-uds-service'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['-hook-cleanup'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-cm-eoc-'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-cm-eoc'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-gr-bur-orchestrator-post-hook'], ['Job'], pytest.mark.skip(reason='Remove via SM-78549 when openshift support is added.')),
    (['eric-eo-cm-licencing'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-postupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-preupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt'))
]
test_parameters = mark_test_parameters(helm_template_object.get_pods_and_containers(), marks)
@pytest.mark.parametrize(('template_name', 'kind', 'pod_spec', 'container_spec'), test_parameters)
def test_to_ensure_all_containers_with_securitycontext_has_runAsNonRoot_set(template_name, kind, pod_spec, container_spec):
    """Test that there is a runAsNonRoot set with appropriate permission associated with each security context set"""
    resulting_security_context = helm_template_object.get_resulting_container_security_context(pod_spec=pod_spec, container_spec=container_spec)
    assert type(resulting_security_context.get('runAsNonRoot', None)) is bool

marks = [
    (['eric-log-shipper'], ['DaemonSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-ingest'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-master'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-master'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['-pg-bragent'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['-postgres-bragent'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-lcm-container-registry-registry'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-lcm-helm-chart-registry'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-log-transformer'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-ctrl-bro'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-coordinator-zk'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-data'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['-pg'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['-postgres'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-message-bus-kf'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-pm-server'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-vnflcm-db'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-wide-column-database-cd'], ['StatefulSet'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-wide-column-database-cd-configure-keyspaces'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-oss-uds-service'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['-hook-cleanup'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-cm-eoc-'], ['Deployment'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-eo-cm-eoc'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-gr-bur-orchestrator-post-hook'], ['Job'], pytest.mark.skip(reason='Remove via SM-78549 when openshift support is added.')),
    (['eric-data-search-engine-postupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt')),
    (['eric-data-search-engine-preupgrade'], ['Job'], pytest.mark.skip(reason='Not required, exempt'))
]
test_parameters = mark_test_parameters(helm_template_object.get_pods_and_containers(), marks)
@pytest.mark.parametrize(('template_name', 'kind', 'pod_spec', 'container_spec'), test_parameters)
def test_to_ensure_all_containers_with_securitycontext_has_allowPrivilegeEscalation_set(template_name, kind, pod_spec, container_spec):
    """Test that there is an allowPrivilegeEscalation set with appropriate permission associated with each security context set"""
    resulting_security_context = helm_template_object.get_resulting_container_security_context(pod_spec=pod_spec, container_spec=container_spec)
    assert type(resulting_security_context.get('allowPrivilegeEscalation', None)) is bool
