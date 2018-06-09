"use strict";

const admin = require('firebase-admin');

const functions = require('firebase-functions');

admin.initializeApp(functions.config().firebase);
const db = admin.firestore();


// exports.sendNotification = functions.https.onRequest((request, response) => {

// var topic = 'All';

//    var message = {
//   notification: {
//     title: '$GOOG up 1.43% on the day',
//     body: '$GOOG gained 11.80 points to close at 835.67, up 1.43% on the day.'
//   },
//   topic: topic 

// };

// // Send a message to devices subscribed to the combination of topics
// // specified by the provided condition.
// admin.messaging().send(request.body.message)
//   .then((response) => {
//     // Response is a message ID string.
//     console.log('Successfully sent message:', response);
//     response.send("ok");
//     return;
//   })
//   .catch((error) => {
//     console.log('Error sending message:', error);
//   });


// });




// exports.sendPush = functions.https.onRequest((request, response) => {


//     let msg = request.body.message;
//     let tokens = [];

//     // var addDoc = db.collection('Notifications').add({ message: msg});
//     // firebase.firestore.FieldValue.serverTimestamp()
//     var query = db.collection('Users').get()
//         .then(snapshot => {
//             snapshot.forEach(snapshot => {
//                 tokens.push(snapshot.get('pushToken'));
//                 console.log('tok: ', tokens);
//                 let payload = {
//                     notification: {
//                         title: 'Firebase Notification',
//                         body: msg,
//                         sound: 'default',
//                         badge: '1'
//                     }
//                 };
//             });
//             return admin.messaging().sendToDevice(tokens, payload);
//         }).catch(err => {
//             response.send(err);
//         });
// });




exports.sendPushNotifications = functions.https.onRequest((req, res) => {
    // res.send('Attempting to send push notifications');
    console.log('LOGGER -- Trying to send push message');

    let msg = req.body.message;
    let title = req.body.heading;
    let tokens = [];
    console.log('title: ', title, ' msg: ', msg);
    // This registration token comes from the client FCM SDKs.
    // var fcmToken = 'c3aHR6j3QJE:APA91bGy3xturh8PQ1gYpGiIM6KwoiibOzljmWrBDFB-87TLNvtV_EVVrmVDZIklupWBpJRoy6QoOn1lq9BWSWOFVZDW1ZFMrwlhumwN3HikWRxL9iUzvY9aAnIPug9G6TKUqha_1VqQ';
    // tokens.push(fcmToken);
    // See documentation on defining a message payload.
    var message = {
        notification: {
            title: title,
            body: msg
        },
    };

    new Promise(function(resolve, reject) {

        var query = db.collection('Users').get()
            .then(snapshot => {
                snapshot.forEach(snapshot => {
                    tokens.push(snapshot.get('pushToken'));
                    console.log('tok: ', tokens);
                });
                return admin.messaging().sendToDevice(tokens, message);
            }).then((result) => {
                // Response is a message ID string.
                console.log('Successfully sent message:', result);
                res.send(result);
                return result;
            })
            .catch((error) => {
                console.log('Error sending message:', error);
                throw new Error('Error sending message');
            });

    });


});




exports.sendNotificationOnCreate = functions.firestore
  .document('Notifications/{id}')
  .onCreate((snap, context) => {

    console.log('LOGGER -- Trying to send event push message');

    let msg = snap.data().message;
    let title = snap.data().title;
    let tokens = [];
    console.log('title: ', title, ' msg: ', msg);
    // This registration token comes from the client FCM SDKs.
    // var fcmToken = 'c3aHR6j3QJE:APA91bGy3xturh8PQ1gYpGiIM6KwoiibOzljmWrBDFB-87TLNvtV_EVVrmVDZIklupWBpJRoy6QoOn1lq9BWSWOFVZDW1ZFMrwlhumwN3HikWRxL9iUzvY9aAnIPug9G6TKUqha_1VqQ';
    // tokens.push(fcmToken);
    // See documentation on defining a message payload.
    var message = {
        notification: {
            title: title,
            body: msg
        },
    };

    new Promise(function(resolve, reject) {

        var query = db.collection('Users').get()
            .then(snapshot => {
                snapshot.forEach(snapshot => {
                    tokens.push(snapshot.get('pushToken'));
                    console.log('tok: ', tokens);
                });
                return admin.messaging().sendToDevice(tokens, message);
            }).then((result) => {
                // Response is a message ID string.
                console.log('Successfully sent message:', result);
                return result;
            })
            .catch((error) => {
                console.log('Error sending message:', error);
                throw new Error('Error sending message');
            });
            
    });


});