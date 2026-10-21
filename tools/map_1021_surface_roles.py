# -*- coding: utf-8 -*-
"""Shared classification for retained land and architectural megastructure parts.

Compatible with the Rhino IronPython exporter and CPython/Blender tools.
"""
from __future__ import unicode_literals
import io, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POLICY_PATH = os.path.join(ROOT, 'assets', 'world', 'current_map_validation', 'surface_roles.json')

def read_policy():
    with io.open(POLICY_PATH, 'r', encoding='utf-8-sig') as stream:
        return json.load(stream)

def classify(record, policy=None):
    policy = policy if policy is not None else read_policy()
    rule = policy['objects'].get(record['id'])
    if rule:
        return rule['kind'], rule['role']
    current = record['kind']
    if current in policy['preserve_special_kinds']:
        return current, current.lower()
    for layer in sorted(policy['layer_defaults'], key=len, reverse=True):
        kind = policy['layer_defaults'][layer]
        if record['layer'] == layer or record['layer'].startswith(layer+'::'):
            return kind, 'plantable_host' if kind=='Terrain' else 'architectural_component'
    return current, current.lower()

def apply(records):
    policy = read_policy()
    changes = []
    for record in records:
        before = record['kind']
        kind, role = classify(record, policy)
        record['kind'], record['surface_role'] = kind, role
        if before != kind:
            changes.append({'id': record['id'], 'name': record['name'], 'before': before, 'after': kind, 'role': role})
    return changes
