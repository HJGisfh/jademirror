"""Shared JadeMirror Flask implementation (web + mobile app instances)."""

from .factory import create_app

__all__ = ['create_app']
