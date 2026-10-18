'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FIELDS, projectMember } = require('../../functions/member_directory_projection');

test('projection uses exact published allowlist', () => {
  assert.deepEqual(FIELDS, [
    'name', 'nickname', 'useNickname', 'function', 'functionIds', 'teamId',
    'active', 'role', 'photoBase64', 'phone', 'city', 'county', 'contractFunction'
  ]);
});

test('hidden and admin profiles are excluded', () => {
  assert.equal(projectMember({ name: 'Synthetic', hiddenFromMembers: true }), null);
  assert.equal(projectMember({ name: 'Synthetic', role: 'admin' }), null);
  assert.equal(projectMember(null), null);
});

test('sensitive non-allowlisted fields are not copied', () => {
  const result = projectMember({
    name: 'Synthetic', active: true, role: 'manager',
    email: 'synthetic@example.invalid', passwordHash: 'fixture', permissions: ['admin']
  });
  assert.deepEqual(result, { name: 'Synthetic', active: true, role: 'member' });
});

test('inactive members remain visible but inactive', () => {
  assert.deepEqual(projectMember({ name: 'Synthetic', active: false }),
    { name: 'Synthetic', active: false, role: 'member' });
});

test('projection does not mutate the source', () => {
  const source = Object.freeze({ name: 'Synthetic', active: true, role: 'manager' });
  assert.deepEqual(projectMember(source), { name: 'Synthetic', active: true, role: 'member' });
  assert.equal(source.role, 'manager');
});
