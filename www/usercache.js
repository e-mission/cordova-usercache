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

    getDocument: function(key) {
        return new Promise (function(resolve, reject){
            exec(resolve, reject, "UserCache", "getDocument", [key])
        });
    },

    getAllSensorDataForInterval: function(key) {
        return UserCache.getSensorDataForInterval(key, UserCache.getAllTimeQuery());
    },
    getAllMessagesForInterval: function(key) {
        return UserCache.getMessagesForInterval(key, UserCache.getAllTimeQuery());
    },
    getSensorDataForInterval: function(key, tq) {
        /*
         The tq parameter represents a time query, a json object with the structure
         {
              "key": "write_ts",
              "startTs": <timestamp_in_secs>,
              "endTs": <timestamp_in_secs>
         }
         */
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getSensorDataForInterval", [key, tq]);
        });
    },

    getMessagesForInterval: function(key, tq) {
        /*
         The tq parameter represents a time query, a json object with the structure
         {
              "key": "write_ts",
              "startTs": <timestamp_in_secs>,
              "endTs": <timestamp_in_secs>
         }
         */
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getMessagesForInterval", [key, tq]);
        });
    },

    getAllTimeQuery: function() {
        // Using the standard Date instead of moment in order to reduce dependencies
        return {key: "write_ts", startTs: 0, endTs: Date.now()/1000}
    },

    getLastMessages: function(key, nEntries) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getLastMessages", [key, nEntries]);
        });
    },

    getLastSensorData: function(key, nEntries) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "UserCache", "getLastSensorData", [key, nEntries]);
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

    // No putSensorData exposed through javascript since it is not intended for regularly sensed data
    clearEntries: function() {
        return UserCache.clearEntries(UserCache.getAllTimeQuery());
    },
    invalidateCache: function() {
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
            exec(resolve, reject, "UserCache", "clearAll");
        });
    }
}

module.exports = UserCache;
