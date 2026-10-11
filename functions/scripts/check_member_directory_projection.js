'use strict';
const assert = require('node:assert/strict');
const { projectMember } = require('../member_directory_projection');

assert.equal(projectMember(null), null);
assert.equal(projectMember({ name:'Hidden', role:'admin', active:true, hiddenFromMembers:true }), null);
assert.equal(projectMember({ name:'Hidden worker', role:'member', active:true, hiddenFromMembers:true }), null);
const visibleAdmin = projectMember({ name:'Admin', role:'admin', active:true, phone:'0700000000', email:'secret@example.com' });
assert.equal(visibleAdmin.role, 'admin');
assert.equal(visibleAdmin.name, 'Admin');
assert.equal(visibleAdmin.active, true);
assert.equal(visibleAdmin.email, undefined);
const visibleMember = projectMember({ name:'Worker', role:'member', active:true });
assert.equal(visibleMember.role, 'member');
console.log('Member directory projection checks passed.');
