// CONSTANTS
var exec = require("cordova/exec")

var UserCache = {
    TABLE_USER_CACHE: "userCache",
    KEY_WRITE_TS: "write_ts",
    KEY_READ_TS: "read_ts",
    KEY_TIMEZONE: "timezone",
    KEY_TYPE: "type",
    KEY_KEY: "key",
    KEY_PLUGIN: "plugin",
    KEY_DATA: "data",

    METADATA_TAG: "metadata",
    DATA_TAG: "data",

    SENSOR_DATA_TYPE: "sensor-data",
    MESSAGE_TYPE: "message",
    DOCUMENT_TYPE: "document",
    RW_DOCUMENT_TYPE: "rw-document",

    getDocument: function(key, withMetadata) {
        return new Promise (function(resolve, reject){
            exec(resolve, reject, "UserCache", "getDocument", [key, withMetadata])
        });
    },

    isEmptyDoc: function(resultDoc) {
        /*
         * Checks to see if the returned document is empty. Needed because we can't return
         * null from android plugins, so we return the empty document instead, but
         * then we need to check for it.
         * https://github.com/apache/cordova-android/blob/457c5b8b3b694265c991b456b15015741ade5014/framework/src/org/apache/cordova/PluginResult.java#L52
         */
        return (Object.keys(resultDoc).length) == 0
    },

    getAllSensorData: function(key) {
        return UserCache.getSensorDataForInterval(key, UserCache.getAllTimeQuery(), true);
    },
    getAllMessages: function(key) {
        return UserCache.getMessagesForInterval(key, UserCache.getAllTimeQuery(), true);
    },
    getSensorDataForInterval: function(key, tq, withMetadata) {
        /*
         The tq parameter represents a time query, a json object with the structure
         {
              "key": "write_ts",
              "startTs": <timestamp_in_secs>,
              "endTs": <timestamp_in_secs>
         }
         */
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getSensorDataForInterval", [key, tq, withMetadata]);
        });
    },

    getMessagesForInterval: function(key, tq, withMetadata) {
        /*
         The tq parameter represents a time query, a json object with the structure
         {
              "key": "write_ts",
              "startTs": <timestamp_in_secs>,
              "endTs": <timestamp_in_secs>
         }
         */
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getMessagesForInterval", [key, tq, withMetadata]);
        });
    },

    getAllTimeQuery: function() {
        // Using the standard Date instead of moment in order to reduce dependencies
        return {key: "write_ts", startTs: 0, endTs: Date.now()/1000}
    },

    getLastMessages: function(key, nEntries, withMetadata) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getLastMessages", [key, nEntries, withMetadata]);
        });
    },

    getLastSensorData: function(key, nEntries, withMetadata) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getLastSensorData", [key, nEntries, withMetadata]);
        });
    },

    getFirstMessages: function(key, nEntries, withMetadata) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getFirstMessages", [key, nEntries, withMetadata]);
        });
    },

    getFirstSensorData: function(key, nEntries, withMetadata) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getFirstSensorData", [key, nEntries, withMetadata]);
        });
    },

    putMessage: function(key, value) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "putMessage", [key, value]);
        });
    },

    putRWDocument: function(key, value) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "putRWDocument", [key, value]);
        });
    },

    putLocalStorage: function(key, value) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "putLocalStorage", [key, value]);
        });
    },

    getLocalStorage: function(key, withMetadata) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getLocalStorage", [key, withMetadata]);
        });
    },

    removeLocalStorage: function(key) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "removeLocalStorage", [key]);
        });
    },

    // No putSensorData exposed through javascript since it is not intended for regularly sensed data
    clearAllEntries: function() {
        return UserCache.clearEntries(UserCache.getAllTimeQuery());
    },
    invalidateAllCache: function() {
        return UserCache.invalidateCache(UserCache.getAllTimeQuery());
    },
    clearEntries: function(tq) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "clearEntries", [tq]);
        });
    },
    invalidateCache: function(tq) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "invalidateCache", [tq]);
        });
    },
    // The nuclear option
    clearAll: function() {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "clearAll", []);
        });
    }
}

module.exports = UserCache;
