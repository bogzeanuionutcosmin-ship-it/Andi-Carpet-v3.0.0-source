const test = require('node:test');
const assert = require('node:assert/strict');
const { FIELDS, projectMember } = require('../functions/member_directory_projection');
test('hidden/admin/deleted profiles never project', () => {
  assert.equal(projectMember(null), null);
  assert.equal(projectMember({role:'admin',name:'A'}), null);
  assert.equal(projectMember({role:'member',hiddenFromMembers:true,name:'B'}), null);
});
test('only approved fields are projected', () => {
  const data = {role:'member',name:'Test',phone:'123',active:true,hireDate:'secret',profileFields:{secret:1},email:'private',hiddenFromMembers:false};
  assert.deepEqual(projectMember(data), {role:'member',name:'Test',phone:'123',active:true});
  assert.equal(FIELDS.includes('hireDate'), false);
  assert.equal(FIELDS.includes('profileFields'), false);
});
test('inactive members remain inactive, never admins', () => {
  assert.deepEqual(projectMember({role:'member',active:false}), {role:'member',active:false});
});
