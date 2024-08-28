"""This module contains test cases to verify that the templates follow the Security Guidelines."""

import pytest
from helm_template import HelmTemplate

helm_template_object = HelmTemplate("/eric-oss.tgz", "/testsuite/site_values.yaml")
service_types = helm_template_object.get_values_with_a_specific_path("spec.type")

@pytest.mark.parametrize(('template', 'kind', 'service_type'), service_types)
def test_nodeport_is_not_used_in_service_exposure(template, kind, service_type):
    """Test that NodePort is not used in the template.type of all necessary resources."""
    assert 'NodePort' not in service_type
