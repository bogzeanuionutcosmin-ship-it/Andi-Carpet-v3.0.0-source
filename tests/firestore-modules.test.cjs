const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const fs = require('node:fs');
const {test} = require('node:test');

test('messaging, locations, documents, settings, reports and backups', async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet-modules',
    firestore: {rules: fs.readFileSync('firestore.rules', 'utf8')},
  });
  try {
    await env.withSecurityRulesDisabled(async c => {
      const db = c.firestore();
      await db.doc('users/admin').set({role: 'admin', active: true});
      for (const uid of ['alice', 'bob', 'outsider']) {
        await db.doc('users/' + uid).set({
          role: 'member', active: true, function: 'worker',
          effectivePermissions: ['viewOwnDecont', 'editProgram'],
        });
      }
      await db.doc('documents/manual').set({title: 'Safety'});
      await db.doc('meta/uiSettings').set({theme: 'green'});
      await db.doc('backups/snapshot').set({version: 1});
    });
    const db = uid => env.authenticatedContext(uid).firestore();
    const message = (senderId, recipientId) => ({
      chatId: 'alice_bob', senderId, senderName: senderId,
      recipientId, recipientName: recipientId,
      participantIds: ['alice', 'bob'], text: 'Salut',
      read: false, createdAt: new Date(),
    });
    await assertSucceeds(db('alice').doc('chatMessages/m1').set(message('alice','bob')));
    await assertFails(db('outsider').doc('chatMessages/m1').get());
    await assertSucceeds(db('bob').doc('chatMessages/m1').get());
    await assertFails(db('bob').doc('chatMessages/forged').set(message('alice','bob')));
    await assertFails(db('alice').doc('chatMessages/empty').set({...message('alice','bob'),text:''}));
    await assertFails(db('alice').doc('chatMessages/m1').update({text:'edited'}));
    await assertSucceeds(db('bob').doc('chatMessages/m1').update({read:true}));

    const group = (senderId,text) => ({
      senderId,senderName:senderId,senderPhotoBase64:'',text,
      createdAt:new Date(),
    });
    await assertSucceeds(db('alice').doc('groupChatMessages/g1').set(group('alice','Salut tuturor')));
    await assertFails(db('bob').doc('groupChatMessages/g2').set(group('alice','Forged')));
    await assertFails(db('alice').doc('groupChatMessages/g3').set(group('alice','')));
    await assertFails(db('alice').doc('groupChatMessages/g1').update({text:'changed'}));
    await assertFails(db('alice').doc('groupChatMessages/g1').delete());

    await assertSucceeds(db('alice').doc('users/alice/pushTokens/token1').set({token:'abc'}));
    await assertFails(db('bob').doc('users/alice/pushTokens/token2').set({token:'xyz'}));

    await assertSucceeds(db('alice').doc('liveLocations/alice').set({lat:45,long:24}));
    await assertFails(db('alice').doc('liveLocations/bob').set({lat:45,long:24}));
    await assertSucceeds(db('bob').doc('liveLocations/alice').get());

    await assertSucceeds(db('alice').doc('documents/manual').get());
    await assertFails(db('alice').doc('documents/manual').update({title:'altered'}));
    await assertSucceeds(db('admin').doc('documents/manual').update({title:'Updated'}));
    await assertSucceeds(db('alice').doc('meta/uiSettings').get());
    await assertFails(db('alice').doc('meta/uiSettings').update({theme:'purple'}));

    await assertSucceeds(db('alice').doc('errorReports/err1').set({userId:'alice',details:'Crash'}));
    await assertFails(db('alice').doc('errorReports/err2').set({userId:'bob',details:'Fake'}));
    await assertFails(db('bob').doc('errorReports/err1').get());
    await assertSucceeds(db('admin').doc('errorReports/err1').get());

    await assertSucceeds(db('alice').doc('suggestions/s1').set({userId:'alice',title:'Feature'}));
    await assertFails(db('alice').doc('suggestions/s2').set({userId:'bob',title:'Fake'}));
    await assertSucceeds(db('bob').doc('suggestions/s1').update({upVotes:1}));
    await assertFails(db('bob').doc('suggestions/s1').update({title:'Hijacked'}));
    await assertFails(db('bob').doc('suggestions/s1').delete());
    await assertSucceeds(db('alice').doc('suggestions/s1').delete());

    await assertFails(db('alice').doc('backups/snapshot').get());
    await assertSucceeds(db('admin').doc('backups/snapshot').get());
    await assertFails(db('alice').doc('updateHistory/change1').set({version:1}));
    await assertSucceeds(db('admin').doc('updateHistory/change1').set({version:1}));
    await assertSucceeds(db('alice').doc('audit/action1').set({actorUid:'alice',action:'test'}));
    await assertFails(db('bob').doc('audit/action1').get());
    await assertFails(db('alice').doc('audit/action2').set({actorUid:'bob',action:'forged'}));
  } finally {
    await env.cleanup();
  }
});
