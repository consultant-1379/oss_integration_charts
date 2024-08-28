"""This module contains test cases to verify that only the default storage class is referenced."""

import pytest
from helm_template import HelmTemplate

helm_template_object = HelmTemplate("/eric-oss.tgz", "/testsuite/site_values.yaml")
storage_class_names = helm_template_object.get_all_references_with_given_key("storageClassName")
@pytest.mark.parametrize(('template', 'kind', 'storage_class_name'), storage_class_names)
def test_storage_class_names_use_default_storage_class(template, kind, storage_class_name):
    """Test that the default storage class is used."""
    assert storage_class_name is None
