// Single source of truth for public member directory fields.
// Imported by both the deployed trigger and the one-time migration.
'use strict';
const FIELDS = Object.freeze([
  'name', 'nickname', 'useNickname', 'function', 'functionIds', 'teamId',
  'active', 'role', 'photoBase64', 'phone', 'city', 'county', 'contractFunction'
]);
function projectMember(data) {
  if (!data || data.hiddenFromMembers === true || data.role === 'admin') return null;
  const result = {};
  for (const field of FIELDS) {
    if (Object.prototype.hasOwnProperty.call(data, field)) result[field] = data[field];
  }
  result.active = data.active === true;
  result.role = 'member';
  return result;
}
module.exports = { FIELDS, projectMember };
