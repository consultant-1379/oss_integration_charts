import pytest
from semver import VersionInfo
from helm_template import HelmTemplate

@pytest.fixture(scope="module")
def image_versions():
    return [("keycloak-client", "1.0.0-17")]

helm_template_object = HelmTemplate("/eric-oss.tgz", "/testsuite/site_values.yaml")
images = helm_template_object.get_all_references_with_given_key("image")
@pytest.mark.parametrize(('template', 'kind', 'image'), images)
def test_minimum_image_version(template, kind, image, image_versions):
    """Test that for each docker image used in the OSS Chart doesn't fall below a minimum image version (Only Keycloak-client for now)"""
    for image_version in image_versions:
        if image_version[0] in image:
           assert VersionInfo.compare(VersionInfo.parse(image.split(":")[1]), VersionInfo.parse(image_version[1])) != -1