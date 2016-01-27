// CONSTANTS
var exec = require("cordova/exec")

var UserCache = {
    var TABLE_USER_CACHE = "userCache";
    var KEY_WRITE_TS = "write_ts";
    var KEY_READ_TS = "read_ts";
    var KEY_TIMEZONE = "timezone";
    var KEY_TYPE = "type";
    var KEY_KEY = "key";
    var KEY_PLUGIN = "plugin";
    var KEY_DATA = "data";

    var METADATA_TAG = "metadata";
    var DATA_TAG = "data";

    var SENSOR_DATA_TYPE = "sensor-data";
    var MESSAGE_TYPE = "message";
    var DOCUMENT_TYPE = "document";
    var RW_DOCUMENT_TYPE = "rw-document";

    /*
     * If this is not done, then we may read read the table before making any
     * native calls, and on iOS, that will cause us to create a loggerDB
     * instead of copying the template.
     */
    init: function() {
        /*
         No native code call in here, so we can't really call anything in init.
         We could either change this to use the UserCache interface directly,
         or just assume that at least the startup transitions will be written
         to the usercache.
         before the webview is launched.

        ULogger.log(ULogger.LEVEL_INFO, "finished init of native code", function(error) {
            alert("Error "+error+" while initializing the unified logger");
        });
        */
        UserCache.db = window.sqlitePlugin.openDatabase({
            name: "userCacheDB",
            location: 0,
            createFromLocation: 1
        })
    },

    getDocument: function(key, successCallback, errorCallback) {
        UserCache.db.readTransaction(function(tx) {
            /*
             * We can have multiple entries for a particular key as the document associated with the key
             * is updated throughout the day. We should really override as part of the sync. But for now,
             * will deal with it in the client by retrieving the last entry.
             */
            var selQuery = "SELECT "+KEY_DATA+" FROM "+TABLE_USER_CACHE +
                " WHERE "+ KEY_KEY + " = '" + key + "'" +
                " AND ("+ KEY_TYPE + " = '" + DOCUMENT_TYPE + "'" +
                  " OR "+ KEY_TYPE + " = '" + RW_DOCUMENT_TYPE+ "') "+
                  "ORDER BY "+KEY_WRITE_TS+" DESC LIMIT 1";
            console.log("About to execute query "+selQuery+" against userCache")
            tx.executeSql(selQuery,
                [],
                function(tx, data) {
                    var resultList = [];
                    console.log("Result has "+data.rows.length+" rows");
                    for (i = 0; i < data.rows.length; i++) {
                        resultList.push(data.rows.item(i)[KEY_DATA]);
                    }
                    successCallback(resultList);
                }, function(e, response) {
                    errorCallback(response);
                });
        });
    },

    getSensorData: function(key, successCallback, errorCallback) {
        UserCache.getEntries(SENSOR_DATA_TYPE, key, successCallback, errorCallback);
    },

    getMessages: function(key, successCallback, errorCallback) {
        UserCache.getEntries(MESSAGE_TYPE, key, successCallback, errorCallback);
    },

    getEntries: function(type, key, callBack) {
        UserCache.db.readTransaction(function(tx) {
            /*
             * We can have multiple entries for a particular key as the document associated with the key
             * is updated throughout the day. We should really override as part of the sync. But for now,
             * will deal with it in the client by retrieving the last entry.
             */
            var selQuery = "SELECT "+KEY_WRITE_TS+"," + KEY_TIMEZONE+","+KEY_DATA+
                " FROM "+TABLE_USER_CACHE +
                " WHERE "+ KEY_KEY + " = '" + key + "'" +
                " AND "+ KEY_TYPE + " = '" + type + "'" +
                " ORDER BY "+KEY_WRITE_TS;
            console.log("About to execute query "+selQuery+" against userCache")
            tx.executeSql(selQuery,
                [],
                function(tx, data) {
                    var resultList = [];
                    console.log("Result has "+data.rows.length+" rows");
                    for (i = 0; i < data.rows.length; i++) {
                        row = data.rows.item(i)
                        entry = {};
                        metadata = {};
                        metadata.write_ts = row[KEY_WRITE_TS];
                        metadata.tz = row[KEY_TIMEZONE];
                        metadata.write_fmt_time = moment.unix(metadata.write_ts)
                                                    .tz(metadata.tz)
                                                    .format("llll");
                        entry.metadata = metadata;
                        entry.data = row[KEY_DATA];
                        resultList.push(entry);
                    }
                    successCallBack(resultList);
                }, function(e) {
                    console.log(e);
                    errorCallback(response);
                });
        });
    }
}

module.exports = UserCache;
