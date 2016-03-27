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
    db: function() {
        // One handle for each thread
        if (UserCache.dbHandle == null) {
            UserCache.dbHandle = window.sqlitePlugin.openDatabase({
                name: "userCacheDB",
                location: 2,
                createFromLocation: 1
            });
        }
        return UserCache.dbHandle;
    },

    getDocument: function(key, successCallback, errorCallback) {
        UserCache.db().readTransaction(function(tx) {
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
            window.Logger.log(window.Logger.LEVEL_INFO, "About to execute query "+selQuery+" against userCache")
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

    getEntries: function(type, key, successCallback, errorCallback) {
        UserCache.db().readTransaction(function(tx) {
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
            window.Logger.log(window.Logger.LEVEL_INFO,
                "About to execute query "+selQuery+" against userCache")
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
                    successCallback(resultList);
                }, function(e) {
                    console.log(e);
                    errorCallback(response);
                });
        });
    },
    // Let's try to use promises this time, instead of using callbacks. Since
    // we are putting a document, we don't actually need to return anything,
    // but whatever.
    putRWDocument: function(key, value) {
        return UserCache.putEntries(UserCache.RW_DOCUMENT_TYPE, key, [value]);
    },

    putMessage: function(key, value) {
        return UserCache.putEntries(UserCache.MESSAGE_TYPE, key, [value]);
    },

    putEntries: function(type, key, valueList) {
        UserCache.db().transaction(function(tx) {
            var selQuery = "INSERT INTO "+UserCache.TABLE_USER_CACHE+
                    " ("+UserCache.KEY_WRITE_TS+"," + UserCache.KEY_TIMEZONE + "," +
                    UserCache.KEY_TYPE + "," + UserCache.KEY_KEY + ","
                    UserCache.KEY_DATA + ") VALUES (?, ?, ?, ?, ?)";
            window.Logger.log(window.Logger.LOG_INFO,
                "About to execute query "+selQuery+" against userCache");
            // If we tried to execute these serially, it is unclear when
            // all of the values have been stored because there is a
            // callback for each of them, and we can get callbacks at
            // various times. So when do we mark the parent promise as
            // complete?  We can store both success and fail results in
            // arrays and generate an event when the sum is complete, but
            // why not just use promises directly instead?
            var promiseList = valueList.map(function(value, index, array) {
                var currPromise = new Promise(function(resolve, reject) {
                    tx.executeSql(selQuery,
                         // date in milliseconds, converted by division. Trying to
                         // keep it consistent with native code and to get more
                         // uniqueness for the log display.
                        [moment().unix(),
                         // Unsure how accurate this is - do we need a native plugin?
                         moment.tz.guess(),
                         type, key, value], 
                        function(tx, data) {
                            // We are inserting, so no expected result
                            // Didn't fail either, so nothing to push into the
                            // index list
                            resolve();
                        }, function(e) {
                            reject({"index": index, "value": value,
                                "error": response});
                     }); // exec SQL
                }); // promise
            }); // map
            return Promise.all(promiseList);
        }); // transaction
    }
}

module.exports = UserCache;
