"""This module handles site values file interaction."""

from memoization import cached
import operator
import yaml


class SiteValues:
    """This is the class to handle reading of values from the site_values_<template>.yaml."""

    @cached
    def __init__(self, values_file_path):
        """The constructor."""
        self.values_file_path = values_file_path
        with open(values_file_path) as values_file:
            self.site_values = yaml.safe_load(values_file)

    @cached
    def get_registry_url(self):
        """Get the global.registry.url."""
        return self.site_values['global']['registry']['url']

    @cached
    def get_registry_pull_secret(self):
        """Get the global.pullSecret."""
        return self.site_values['global']['pullSecret']
