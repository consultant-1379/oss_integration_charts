"""This module contains test cases to verify that the templates follow the guidelines for Customer Environments."""

import pytest
from helm_template import HelmTemplate
from site_values import SiteValues

@pytest.fixture(scope="module")
def site_values_object():
    return SiteValues("/testsuite/site_values.yaml")

helm_template_object = HelmTemplate("/eric-oss.tgz", "/testsuite/site_values.yaml")
images = helm_template_object.get_all_references_with_given_key("image")

@pytest.mark.parametrize(('template', 'kind', 'image'), images)
def test_global_registry_url_usage(template, kind, image, site_values_object):
    """Test that the global registry url is set in all image references in the templates."""
    registry_url = site_values_object.get_registry_url()
    assert registry_url in image

imagePullSecrets = helm_template_object.get_all_references_with_given_key("imagePullSecrets")

@pytest.mark.parametrize(('template', 'kind', 'imagePullSecret'), imagePullSecrets)
def test_global_registry_pull_secret_usage(template, kind, imagePullSecret, site_values_object):
    """Test that the global registry pull secret is set correctly in the templates."""
    registry_pull_secret = site_values_object.get_registry_pull_secret()
    assert registry_pull_secret in imagePullSecret[0].get('name')

spec_templates = helm_template_object.get_values_with_a_specific_path("spec.template.spec")

@pytest.mark.parametrize(('template', 'kind', 'spec_template'), spec_templates)
def test_missing_global_registry_pull_secret(template, kind, spec_template):
    """Test that Image Pull Secrets are set in the template.spec of all necessary resources."""
    assert spec_template.get('imagePullSecrets', None) is not None

containers = helm_template_object.get_values_with_a_specific_path("spec.template.spec.containers")

@pytest.mark.parametrize(('template', 'kind', 'container'), containers)
def test_zypper_commands_are_not_used(template, kind, container):
    """Test that zypper is not used in the template.spec.containers of all necessary resources."""
    assert 'zypper' not in str(container)