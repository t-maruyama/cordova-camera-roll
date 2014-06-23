var exec = require('cordova/exec');

var cameraRoll = {};

cameraRoll.getPhotos = function(successCallback, errorCallback, options) {
  exec(successCallback, errorCallback, "CameraRoll", "getPhotos", []);
};

cameraRoll.getFullScreenImage = function(successCallback, errorCallback, options) {
  exec(successCallback, errorCallback, "CameraRoll", "getFullScreenImage", options);
};

cameraRoll.cleanup = function(successCallback, errorCallback) {
  exec(successCallback, errorCallback, "CameraRoll", "cleanup", []);
};

module.exports = cameraRoll;