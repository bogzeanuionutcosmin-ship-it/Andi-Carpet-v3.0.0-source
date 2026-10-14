self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDbCrAkYTS-ikxjc0JLrYwCww8_ybgndtM',
  authDomain: 'andicarpet-e777e.firebaseapp.com',
  projectId: 'andicarpet-e777e',
  storageBucket: 'andicarpet-e777e.firebasestorage.app',
  messagingSenderId: '141489733149',
  appId: '1:141489733149:web:ac0615c9d57c5ab9da10f4'
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  // Pentru payload-urile cu `notification`, browserul afișează notificarea
  // sistem automat. Handlerul rămâne aici pentru diagnostic/extensii viitoare.
  console.log('[Andi Carpetă] Push în fundal', payload && payload.messageId, payload);
});
