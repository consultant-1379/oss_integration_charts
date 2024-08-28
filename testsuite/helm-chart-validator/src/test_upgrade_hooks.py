"""This module contains test cases to verify that the templates use the correct hooks strategy."""

import pytest
from datetime import date
from utils import mark_test_parameters
from helm_template import HelmTemplate

helm_template_object = HelmTemplate("/eric-oss.tgz", "/testsuite/site_values.yaml")
annotations = helm_template_object.get_values_with_a_specific_path("metadata.annotations")


marks = [
    (['eric-oss-dmaap-post-install'], ['Job'], pytest.mark.xfail(strict=True, reason='should this fail?')),
    (['eric-eo-bro-configurator'], ['Job'], pytest.mark.skip(reason='never runs on upgrade'))
]
test_parameters = mark_test_parameters(annotations, marks)


@pytest.mark.parametrize(('template', 'kind', 'annotation'), test_parameters)
def test_postUpgrade_is_used_in_postInstall_service_hook(template, kind, annotation):
    """Test that post-upgrade is in the metadata.annotations of all Hooks marked for post-install."""
    helm_hook = annotation.get('helm.sh/hook')
    if helm_hook:
        if "post-install" in helm_hook:
            assert 'post-upgrade' in helm_hook


marks = [
    (['eric-eo-tenantmgmt-hook-sync-tenants'], ['Job'], pytest.mark.skip(reason='Not required to run post-install')),
    (['eric-data-search-engine-postupgrade'], ['Job'], pytest.mark.skip(reason='Not required to run post-install'))
]
test_parameters = mark_test_parameters(annotations, marks)


@pytest.mark.parametrize(('template', 'kind', 'annotation'), test_parameters)
def test_postInstall_is_used_in_post_Upgrade_service_hook(template, kind, annotation):
    """Test that post-install is in the metadata.annotations of all Hooks marked for post-upgrade."""
    helm_hook = annotation.get('helm.sh/hook')
    if helm_hook:
        if "post-upgrade" in helm_hook:
            assert 'post-install' in helm_hook


marks = [
    (['-db$'], ['Role', 'RoleBinding'],
     pytest.mark.xfail(date.today() < date(2020, 8, 18),
                       reason='https://cc-jira.rnd.ki.sw.ericsson.se/browse/ADPPRG-29560'))
]
test_parameters = mark_test_parameters(annotations, marks)


@pytest.mark.parametrize(('template', 'kind', 'annotation'), test_parameters)
def test_preUpgrade_is_used_in_preInstall_service_hook(template, kind, annotation):
    """Test that pre-upgrade is in the metadata.annotations of all Hooks marked for pre-install."""
    helm_hook = annotation.get('helm.sh/hook')
    if helm_hook:
        if "pre-install" in helm_hook:
            assert 'pre-upgrade' in helm_hook
