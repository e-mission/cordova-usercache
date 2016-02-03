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
            var selQuery = "SELECT "+UserCache.KEY_DATA+" FROM "+UserCache.TABLE_USER_CACHE +
                " WHERE "+ UserCache.KEY_KEY + " = '" + key + "'" +
                " AND ("+ UserCache.KEY_TYPE + " = '" + UserCache.DOCUMENT_TYPE + "'" +
                  " OR "+ UserCache.KEY_TYPE + " = '" + UserCache.RW_DOCUMENT_TYPE+ "') "+
                  "ORDER BY "+UserCache.KEY_WRITE_TS+" DESC LIMIT 1";
            console.log("About to execute query "+selQuery+" against userCache")
            tx.executeSql(selQuery,
                [],
                function(tx, data) {
                    var resultList = [];
                    console.log("Result has "+data.rows.length+" rows");
                    for (i = 0; i < data.rows.length; i++) {
                        resultList.push(data.rows.item(i)[UserCache.KEY_DATA]);
                    }
                    successCallback(resultList);
                }, function(e, response) {
                    errorCallback(response);
                });
        });
    },

    getSensorData: function(key, successCallback, errorCallback) {
        UserCache.getEntries(UserCache.SENSOR_DATA_TYPE, key, successCallback, errorCallback);
    },

    getMessages: function(key, successCallback, errorCallback) {
        UserCache.getEntries(UserCache.MESSAGE_TYPE, key, successCallback, errorCallback);
    },

    getEntries: function(type, key, callBack) {
        UserCache.db.readTransaction(function(tx) {
            /*
             * We can have multiple entries for a particular key as the document associated with the key
             * is updated throughout the day. We should really override as part of the sync. But for now,
             * will deal with it in the client by retrieving the last entry.
             */
            var selQuery = "SELECT "+UserCache.KEY_WRITE_TS+"," + UserCache.KEY_TIMEZONE+","+UserCache.KEY_DATA+
                " FROM "+UserCache.TABLE_USER_CACHE +
                " WHERE "+ UserCache.KEY_KEY + " = '" + key + "'" +
                " AND "+ UserCache.KEY_TYPE + " = '" + type + "'" +
                " ORDER BY "+UserCache.KEY_WRITE_TS;
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
                        metadata.write_ts = row[UserCache.KEY_WRITE_TS];
                        metadata.tz = row[UserCache.KEY_TIMEZONE];
                        metadata.write_fmt_time = moment.unix(metadata.write_ts)
                                                    .tz(metadata.tz)
                                                    .format("llll");
                        entry.metadata = metadata;
                        entry.data = row[UserCache.KEY_DATA];
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
