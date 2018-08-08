const functions = require('firebase-functions');
const cors = require('cors')({ origin: true });
const Busboy = require('busboy');
const os = require('os');
const path = require('path');
const fs = require('fs');
const uuid = require('uuid/v4');
const fbAdmin = require('firebase-admin');

const gcconfig = {
  projectId: 'flutter-products-6fdce',
  keyFilename: 'flutter-products.json'
};

const gcs = require('@google-cloud/storage')(gcconfig);

fbAdmin.initializeApp({ credential: fbAdmin.credential.cert(require('./flutter-products.json')) });

exports.storeImage = functions.https.onRequest((req, res) => {
  return cors(req, res, () => {
    if (req.method !== 'POST') {
      return res.status(500).json({ message: 'Not allowed.' });
    }

    if (!req.headers.authorization || !req.headers.authorization.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized.' });
    }

    let idToken;
    idToken = req.headers.authorization.split(' ')[1];

    const busboy = new Busboy({ headers: req.headers });
    let uploadData;
    let oldImagePath;

    busboy.on('file', (fieldName, file, fileName, encoding, mimetype) => {
      const filePath = path.join(os.tmpdir(), fileName);
      uploadData = { filePath, type: mimetype, name: fileName };
      file.pipe(fs.createWriteStream(filePath));
    });

    busboy.on('field', (fieldName, value) => {
      oldImagePath = decodeURIComponent(value);
    });

    busboy.on('finish', () => {
      const bucket = gcs.bucket('flutter-products-6fdce.appspot.com');
      const id = uuid();
      let imagePath = 'images/' + id + '-' + uploadData.name;
      if (oldImagePath) {
        imagePath = oldImagePath;
      }

      return fbAdmin
        .auth()
        .verifyIdToken(idToken)
        .then(decodedToken => {
          return bucket.upload(uploadData.filePath, {
            uploadType: 'media',
            destination: imagePath,
            metadata: {
              metadata: {
                contentType: uploadData.type,
                firebaseStorageDownloadToken: id
              }
            }
          });
        })
        .then(() => {
          return res.status(201).json({
            imageUrl: `https://firebasestorage.googleapis.com/v0/b/${
              bucket.name
            }/o/${encodeURIComponent(imagePath)}?alt=media&token=${id}`,
            imagePath: imagePath
          });
        })
        .catch(error => {
          return res.status(401).json({ error: 'Unauthorized.' });
        });
    });

    return busboy.end(req.rawBody);
  });
});
