package edu.berkeley.eecs.emission.cordova.usercache;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import com.google.gson.Gson;
import com.google.gson.JsonSyntaxException;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.lang.reflect.Array;
import java.util.Arrays;
import java.util.TimeZone;

import edu.berkeley.eecs.emission.R;
import edu.berkeley.eecs.emission.cordova.tracker.ConfigManager;
import edu.berkeley.eecs.emission.cordova.unifiedlogger.Log;
import edu.berkeley.eecs.emission.cordova.tracker.wrapper.Metadata;
import edu.berkeley.eecs.emission.cordova.unifiedlogger.NotificationHelper;

/**
 * Concrete implementation of the user cache that stores the entries
 * in an SQLite database.
 *
 * Big design question: should we store the data in separate tables which are put
 * in here
 */
public class BuiltinUserCache extends SQLiteOpenHelper implements UserCache {

    // All Static variables
    // Database Version
    private static final int DATABASE_VERSION = 1;

    // Database Name
    private static final String DATABASE_NAME = "userCacheDB";

    // Table names
    private static final String TABLE_USER_CACHE = "userCache";
    private static final String TABLE_USER_CACHE_ERROR = "userCacheError";

    // USER_CACHE Table Columns names
    // We expand the metadata and store the data as a JSON blob
    private static final String KEY_WRITE_TS = "write_ts";
    private static final String KEY_READ_TS = "read_ts";
    private static final String KEY_TIMEZONE = "timezone";
    private static final String KEY_TYPE = "type";
    private static final String KEY_KEY = "key";
    private static final String KEY_PLUGIN = "plugin";
    private static final String KEY_DATA = "data";

    private static final String TAG = "BuiltinUserCache";

    private static final String METADATA_TAG = "metadata";
    private static final String DATA_TAG = "data";

    private static final String SENSOR_DATA_TYPE = "sensor-data";
    private static final String MESSAGE_TYPE = "message";
    private static final String DOCUMENT_TYPE = "document";
    private static final String RW_DOCUMENT_TYPE = "rw-document";

    private Context cachedCtx;
    private static BuiltinUserCache database;

    public static BuiltinUserCache getDatabase(Context ctxt) {
        if (ctxt == null) {
            return null;
        }
        if (database == null) {
            System.out.println("logger == null, lazily creating new logger");
            database = new BuiltinUserCache(ctxt);
        }
        // System.out.println("Returning logger "+logger);
        return database;
    }

    private BuiltinUserCache(Context ctx) {
        super(ctx, DATABASE_NAME, null, DATABASE_VERSION);
        cachedCtx = ctx;
    }

    @Override
    public void onCreate(SQLiteDatabase sqLiteDatabase) {
        String CREATE_USER_CACHE_TABLE = "CREATE TABLE " + TABLE_USER_CACHE +" (" +
                KEY_WRITE_TS + " REAL, "+ KEY_READ_TS +" REAL, " +
                KEY_TIMEZONE + " TEXT, " +
                KEY_TYPE + " TEXT, " + KEY_KEY + " TEXT, "+
                KEY_PLUGIN + " TEXT, " + KEY_DATA + " TEXT)";
        System.out.println("CREATE_USER_CACHE_TABLE = " + CREATE_USER_CACHE_TABLE);
        sqLiteDatabase.execSQL(CREATE_USER_CACHE_TABLE);
        String CREATE_USER_CACHE_ERROR_TABLE = "CREATE TABLE " + TABLE_USER_CACHE_ERROR +" (" +
                KEY_WRITE_TS + " REAL, "+ KEY_READ_TS +" REAL, " +
                KEY_TIMEZONE + " TEXT, " +
                KEY_TYPE + " TEXT, " + KEY_KEY + " TEXT, "+
                KEY_PLUGIN + " TEXT, " + KEY_DATA + " TEXT)";
        System.out.println("CREATE_USER_CACHE_ERROR_TABLE = " + CREATE_USER_CACHE_ERROR_TABLE);
        sqLiteDatabase.execSQL(CREATE_USER_CACHE_ERROR_TABLE);
    }

    private String getKey(int keyRes) {
        return cachedCtx.getString(keyRes);
    }

    @Override
    public void putSensorData(int keyRes, Object value) {
        putValue(getKey(keyRes), new Gson().toJson(value), SENSOR_DATA_TYPE);
    }

    @Override
    public void putMessage(int keyRes, Object value) {
        putValue(getKey(keyRes), new Gson().toJson(value), MESSAGE_TYPE);
    }

    @Override
    public void putReadWriteDocument(int keyRes, Object value) {
        putValue(getKey(keyRes), new Gson().toJson(value), RW_DOCUMENT_TYPE);
    }

    @Override
    public void putSensorData(String key, JSONObject value) {
        putValue(key, value.toString(), SENSOR_DATA_TYPE);
    }

    @Override
    public void putMessage(String key, JSONObject value) {
        putValue(key, value.toString(), MESSAGE_TYPE);
    }

    @Override
    public void putReadWriteDocument(String key, JSONObject value) {
        putValue(key, value.toString(), RW_DOCUMENT_TYPE);
    }

    private void putValue(String key, String value, String type) {
        SQLiteDatabase db = this.getWritableDatabase();

        ContentValues newValues = new ContentValues();
        newValues.put(KEY_WRITE_TS, ((double)System.currentTimeMillis()/1000));
        newValues.put(KEY_TIMEZONE, TimeZone.getDefault().getID());
        newValues.put(KEY_TYPE, type);
        newValues.put(KEY_KEY, key);
        newValues.put(KEY_DATA, value);
        db.insert(TABLE_USER_CACHE, null, newValues);
        Log.d(cachedCtx, TAG, "Added value for key " + key +
                " at time "+newValues.getAsDouble(KEY_WRITE_TS));
        }

    private void putErrorValue(Metadata md, String dataStr) {
        SQLiteDatabase db = this.getWritableDatabase();

        ContentValues newValues = new ContentValues();
        newValues.put(KEY_WRITE_TS, md.getWrite_ts());
        newValues.put(KEY_TIMEZONE, md.getTimeZone());
        newValues.put(KEY_TYPE, md.getType());
        newValues.put(KEY_KEY, md.getKey());
        newValues.put(KEY_DATA, dataStr);
        db.insert(TABLE_USER_CACHE_ERROR, null, newValues);
        Log.d(cachedCtx, TAG, "Added error value for key "+ md.getKey());
    }

    @Override
    public <T> T getDocument(int keyRes, Class<T> classOfT) {
        String key = getKey(keyRes);
        String docString = getDocumentString(key);
        if (docString != null) {
            T retVal = new Gson().fromJson(docString, classOfT);
            return retVal;
        }
        return null;
    }

    @Override
    public String getDocument(String key) throws JSONException {
        return getDocumentString(key);
    }

    private String getDocumentString(String key) {
        // Since we are ordering the results by write_ts, we expect the following behavior:
        // - only RW_DOCUMENT -> it is returned
        // - only DOCUMENT -> it is returned
        // - both RW_DOCUMENT and DOCUMENT, and DOCUMENT is generated from RW_DOCUMENT -> DOCUMENT is returned
        // since it has the later timestamp
        // - both RW_DOCUMENT and DOCUMENT, and RW_DOCUMENT is created by cloning DOCUMENT -> RW_DOCUMENT
        // since it has the later timestamp
        // If any of the assumptions in the RW_DOCUMENT and DOCUMENT case are violated, we need to change this
        // to read both values and look at their types

        SQLiteDatabase db = this.getReadableDatabase();
        String selectQuery = "SELECT "+KEY_DATA+" from " + TABLE_USER_CACHE +
                " WHERE " + KEY_KEY + " = '" + key + "'" +
                " AND ("+ KEY_TYPE + " = '"+ DOCUMENT_TYPE + "' OR " + KEY_TYPE + " = '" + RW_DOCUMENT_TYPE + "')"+
                " ORDER BY "+KEY_WRITE_TS+" DESC LIMIT 1";
        Cursor queryVal = db.rawQuery(selectQuery, null);
        if (queryVal.moveToFirst()) {
            String data = queryVal.getString(0);
            System.out.println("data = "+data);
                String retVal = data;
                // updateReadTimestamp(key);
            return retVal;
        } else {
            // If there was no matching entry, return an empty list instead of null
            return null;
        }
    }

    private <T> T[] wrapGson(String[] stringObjects, Class<T> classOfT) {
        T[] resultArray = (T[]) Array.newInstance(classOfT, stringObjects.length);
        for (int i=0; i < stringObjects.length; i++) {
            resultArray[i] = new Gson().fromJson(stringObjects[i], classOfT);
            }
        return resultArray;
        }

    private JSONArray wrapJson(String[] stringObjects) throws JSONException {
        JSONArray resultArray = new JSONArray();
        for (int i=0; i < stringObjects.length; i++) {
            resultArray.put(new JSONObject(stringObjects[i]));
        }
        return resultArray;
    }

    @Override
    public <T> T[] getMessagesForInterval(int keyRes, TimeQuery tq, Class<T> classOfT) {
        return wrapGson(getValuesForInterval(getKey(keyRes), MESSAGE_TYPE, tq), classOfT);
    }

    @Override
    public <T> T[] getSensorDataForInterval(int keyRes, TimeQuery tq, Class<T> classOfT) {
        return wrapGson(getValuesForInterval(getKey(keyRes), SENSOR_DATA_TYPE, tq), classOfT);
    }

    @Override
    public JSONArray getMessagesForInterval(String key, TimeQuery tq) throws JSONException {
        return wrapJson(getValuesForInterval(key, MESSAGE_TYPE, tq));
    }

    @Override
    public JSONArray getSensorDataForInterval(String key, TimeQuery tq) throws JSONException {
        return wrapJson(getValuesForInterval(key, SENSOR_DATA_TYPE, tq));
    }

    public String[] getValuesForInterval(String key, String type, TimeQuery tq){
        /*
         * Note: the first getKey(key) is the key of the message (e.g. 'background/location').
         * The second getKey(tq.key) is the key of the time query (e.g. 'write_ts')
         */
        String queryString = "SELECT "+KEY_DATA+" FROM "+TABLE_USER_CACHE+
                " WHERE "+KEY_KEY+" = '"+ key + "'"+
                " AND "+KEY_TYPE+" = '" + type + "'" +
                " AND "+ tq.key +" >= "+tq.startTs+
                " AND "+ tq.key +" <= "+tq.endTs+
                " ORDER BY write_ts DESC";
        System.out.println("About to execute query "+queryString);
        SQLiteDatabase db = this.getReadableDatabase();
        Cursor resultCursor = db.rawQuery(queryString, null);

        String[] result = getValuesFromCursor(resultCursor);
        return result;
    }

    @Override
    public <T> T[] getLastMessages(int key, int nEntries, Class<T> classOfT) {
        return wrapGson(getLastValues(getKey(key), MESSAGE_TYPE, nEntries), classOfT);
    }

    @Override
    public <T> T[] getLastSensorData(int key, int nEntries, Class<T> classOfT) {
        return wrapGson(getLastValues(getKey(key), SENSOR_DATA_TYPE, nEntries), classOfT);
    }

    public JSONArray getLastMessages(String key, int nEntries) throws JSONException {
        return wrapJson(getLastValues(key, MESSAGE_TYPE, nEntries));
    }

    public JSONArray getLastSensorData(String key, int nEntries) throws JSONException {
        return wrapJson(getLastValues(key, SENSOR_DATA_TYPE, nEntries));
    }

    public String[] getLastValues(String key, String type, int nEntries) {
        String queryString = "SELECT "+KEY_DATA+" FROM "+TABLE_USER_CACHE+
                " WHERE "+KEY_KEY+" = '"+ key + "'"+
                " AND "+KEY_TYPE+" = '" + type + "'" +
                " ORDER BY write_ts DESC  LIMIT "+nEntries;
        SQLiteDatabase db = this.getReadableDatabase();
        Cursor resultCursor = db.rawQuery(queryString, null);

        String[] valueList = getValuesFromCursor(resultCursor);
        return valueList;
    }

    private String[] getValuesFromCursor(Cursor resultCursor) {
        int resultCount = resultCursor.getCount();
        String[] resultArray = new String[resultCount];
        // System.out.println("resultArray is " + resultArray);
        if (resultCursor.moveToFirst()) {
            for (int i = 0; i < resultCount; i++) {
                String data = resultCursor.getString(0);
                // System.out.println("data = "+data);
                resultArray[i] = data;
                resultCursor.moveToNext();
            }
        }
        return resultArray;
    }

    private void updateReadTimestamp(String key) {
        SQLiteDatabase writeDb = this.getWritableDatabase();
        ContentValues updateValues = new ContentValues();
        updateValues.put(KEY_READ_TS, ((double)System.currentTimeMillis())/1000);
        updateValues.put(KEY_KEY, key);
        writeDb.update(TABLE_USER_CACHE, updateValues, null, null);
    }

    @Override
    public void clearEntries(TimeQuery tq) {
        Log.d(cachedCtx, TAG, "Clearing entries for timequery " + tq);

        // First, we delete those rw-documents that have been superceded by a real document
        // We cannot use the delete method easily because we want to join the usercache table to itself
        // We could retrieve all rw documents and iterate through them to delete but that seems less
        // efficient than this. Note that this needs to happen BEFORE the general clear step because
        // otherwise, the real documents will also be deleted and so we won't detect the superceding.

        // DELETE FROM TABLE_USER_CACHE WHERE write_ts IN (SELECT B.write_ts FROM TABLE_USER_CACHE A JOIN TABLE_USER_CACHE B
        // on B.KEY_KEY == A.KEY_KEY
        // WHERE (B.KEY_TYPE == 'RW_DOCUMENT_TYPE' AND A.KEY_TYPE == 'DOCUMENT_TYPE' AND A.KEY_WRITE_TS > B.KEY_WRITE_TS))

        SQLiteDatabase db = this.getWritableDatabase();
        String rwDocDeleteQuery = "DELETE FROM " + TABLE_USER_CACHE +" WHERE "+KEY_WRITE_TS+
                " IN (SELECT B."+KEY_WRITE_TS+" FROM "+
                TABLE_USER_CACHE + " A JOIN " + TABLE_USER_CACHE+" B "+
                " on B."+KEY_KEY +" = A."+KEY_KEY +
                " WHERE (B."+KEY_TYPE+" = '"+RW_DOCUMENT_TYPE+"' AND A."+KEY_TYPE+" = '"+DOCUMENT_TYPE+"'"+
                " AND A."+KEY_WRITE_TS+" > B."+KEY_WRITE_TS+"))";
        Log.d(cachedCtx, TAG, "Clearing obsolete RW-DOCUMENTS using "+rwDocDeleteQuery);
        db.rawQuery(rwDocDeleteQuery, null);

        // This clears everything except the read-write documents
        String whereString = tq.key + " > ? AND " + tq.key + " < ? "+
                " AND "+KEY_TYPE+" != '"+RW_DOCUMENT_TYPE+"'";
        String[] whereArgs = {String.valueOf(tq.startTs), String.valueOf(tq.endTs)};
        Log.d(cachedCtx, TAG, "Args =  " + whereString + " : " + Arrays.toString(whereArgs));
        // SQLiteDatabase db = this.getWritableDatabase();
        db.delete(TABLE_USER_CACHE, whereString, whereArgs);

        /*
        if (resultCount > 0) {
            SQLiteDatabase delDB = this.getWritableDatabase();
            String rwDocDeleteQuery = "DELETE FROM " + TABLE_USER_CACHE + " WHERE " + KEY_WRITE_TS + inString;
            Log.d(cachedCtx, TAG, "Clearing obsolete RW-DOCUMENTS using " + rwDocDeleteQuery);
            delDB.rawQuery(rwDocDeleteQuery, null);
        }
        */
    }

    @Override
    public void invalidateCache(TimeQuery tq) {
        Log.d(cachedCtx, TAG, "Clearing entries for timequery " + tq);

        SQLiteDatabase db = this.getWritableDatabase();
        // This clears everything except the read-write documents
        String whereString = tq.key + " > ? AND " + tq.key + " < ? "+
                " AND "+KEY_TYPE+" == '"+DOCUMENT_TYPE+"'";
        String[] whereArgs = {String.valueOf(tq.startTs), String.valueOf(tq.endTs)};
        Log.d(cachedCtx, TAG, "Args =  " + whereString + " : " + Arrays.toString(whereArgs));
        // SQLiteDatabase db = this.getWritableDatabase();
        db.delete(TABLE_USER_CACHE, whereString, whereArgs);
    }

    /*
     * Nuclear option that just deletes everything. Useful for debugging.
     */
    public void clear() {
        Log.d(cachedCtx, TAG, "Clearing all messages ");
        SQLiteDatabase db = this.getWritableDatabase();
        db.delete(TABLE_USER_CACHE, null, null);
    }

    @Override
    public void onUpgrade(SQLiteDatabase sqLiteDatabase, int oldVersion, int newVersion) {
        sqLiteDatabase.execSQL("DROP TABLE IF EXISTS " + TABLE_USER_CACHE);
        onCreate(sqLiteDatabase);
    }

    /* BEGIN: Methods that are invoked to get the data for syncing to the host
     * Note that these are not defined in the interface, since other methods for syncing,
     * such as couchdb and azure, have their own syncing mechanism that don't depend on our
     * REST API.
     */

    /**
     * Ensure that we don't delete points that we are using for trip end
     * detection. Note that we could just refactor the check for trip end and
     * use the same logic to determine which points to delete - i.e. sync and
     * delete everything older than 30 mins, but I want to keep our options
     * open in case it turns out that we want to do some preprocessing of
     * sensitive trips on the phone before uploading them to the server.
     */
    public double getTsOfLastTransition() {
        /*
         * Find the last transition that was "stopped moving" using a direct SQL query.
         * Note that we cannot use the @see getLastMessage call here because that returns the messages
         * (the transition strings in this case) but not the metadata.
         */
        String selectQuery = "SELECT * FROM "+TABLE_USER_CACHE+
                " WHERE "+KEY_KEY+" = '"+getKey(R.string.key_usercache_transition)+ "'"+
                " AND "+KEY_DATA+" LIKE '%_transition_:_" + cachedCtx.getString(R.string.transition_stopped_moving) +"_%'"+
                " ORDER BY write_ts DESC  LIMIT 1";

        SQLiteDatabase db = this.getReadableDatabase();
        Cursor resultCursor = db.rawQuery(selectQuery, null);
        Log.d(cachedCtx, TAG, "While searching for regex of last transition, got "+resultCursor.getCount()+" results");
        if (resultCursor.moveToFirst()) {
            double write_ts = resultCursor.getDouble(resultCursor.getColumnIndex(KEY_WRITE_TS));
            Log.d(cachedCtx, TAG, write_ts + ": "+
                    resultCursor.getString(resultCursor.getColumnIndex(KEY_DATA)));
            resultCursor.close();
            return write_ts;
        } else {
            resultCursor.close();
            // There was one instance when it looked like the regex search did not work.
            // However, it turns out that it was just a logging issue.
            // Let's have a more robust fallback and see how often we need to use it.
            // But this should almost certainly be removed before deployment.
            String selectQueryAllTrans = "SELECT * FROM "+TABLE_USER_CACHE+
                    " WHERE "+KEY_KEY+" = '"+getKey(R.string.key_usercache_transition)+ "'"+
                    " ORDER BY write_ts DESC";
            Cursor allCursor = db.rawQuery(selectQueryAllTrans, null);

            int resultCount = allCursor.getCount();
            Log.d(cachedCtx, TAG, "While searching for all, got "+resultCount+" results");
            if (allCursor.moveToFirst() && resultCount > 0) {
                for (int i = 0; i < resultCount; i++) {
                    Log.d(cachedCtx, TAG, "Considering transition "+
                            allCursor.getDouble(allCursor.getColumnIndex(KEY_WRITE_TS)) + ": "+
                            allCursor.getString(allCursor.getColumnIndex(KEY_DATA)));
                    if(allCursor.getString(allCursor.getColumnIndex(KEY_DATA))
                            .contains("\"transition\":\"local.transition.stopped_moving\"")) {
                        // when we find stopped moving, we return, so this must be the first
                        // time we have found it
                        NotificationHelper.createNotification(cachedCtx, 5, "Had to look in all!");
                        Log.w(cachedCtx, TAG, "regex did not find entry, had to search all");
                        double retVal = allCursor.getDouble(allCursor.getColumnIndex(KEY_WRITE_TS));
                        allCursor.close();
                        return retVal;
                    }
                    allCursor.moveToNext();
                }
                allCursor.close();
            } else {
                Log.d(cachedCtx, TAG, "There are no entries in the usercache." +
                        "A sync must have just completed!");
                allCursor.close();
            }
        }
        // Did not find a stopped_moving transition.
        // This may mean that we have pushed all completed trips.
        // Since this is supposed to return the millisecond timestamp,
        // we just return a negative number (-1)
        return -1;
    }

    /*
     * If we never duty cycle, we don't have any transitions. So we can push to the server without
     * any issues. So we just find the last entry in the cache.
     */
    private double getTsOfLastEntry() {
        String selectQuery = "SELECT * FROM " + TABLE_USER_CACHE +
                " ORDER BY write_ts DESC LIMIT 1";
        SQLiteDatabase db = this.getReadableDatabase();
        Cursor resultCursor = db.rawQuery(selectQuery, null);
        Log.d(cachedCtx, TAG, "While searching for regex for last entry, got " + resultCursor.getCount() + " results");
        if (resultCursor.moveToFirst()) {
            double write_ts = resultCursor.getDouble(resultCursor.getColumnIndex(KEY_WRITE_TS));
            Log.d(cachedCtx, TAG, write_ts + ": " +
                    resultCursor.getString(resultCursor.getColumnIndex(KEY_DATA)));
            resultCursor.close();
            return write_ts;
        } else {
            Log.d(cachedCtx, TAG, "There are no entries in the usercache." +
                    "A sync must have just completed!");
        }
        resultCursor.close();
        return -1;
    }

    private double getLastTs() {
        if (ConfigManager.getConfig(cachedCtx).isDutyCycling()) {
            return getTsOfLastTransition();
        } else {
            return getTsOfLastEntry();
        }
    }

    /*
     * Return a string version of the messages and rw documents that need to be sent to the server.
     */

    public JSONArray sync_phone_to_server() {
        double lastTripEndTs = getLastTs();
        Log.d(cachedCtx, TAG, "Last trip end was at "+lastTripEndTs);

        if (lastTripEndTs < 0) {
            // We don't have a completed trip, so we don't want to push anything yet.
            Log.i(cachedCtx,TAG, "We don't have a completed trip, so we don't want to push anything yet");
            return new JSONArray();
        }

        Log.d(cachedCtx, TAG, "About to query database for data");
        String selectQuery = "SELECT * from " + TABLE_USER_CACHE +
                " WHERE (" + KEY_TYPE + " = '"+ MESSAGE_TYPE +
                "' OR " + KEY_TYPE + " = '" + RW_DOCUMENT_TYPE +
                "' OR " + KEY_TYPE + " = '" + SENSOR_DATA_TYPE + "')" +
                " AND (" + KEY_WRITE_TS + " <= " + lastTripEndTs + ")" +
                " ORDER BY "+KEY_WRITE_TS + " LIMIT 10000";

        Log.d(cachedCtx, TAG, "Query is "+selectQuery);
        SQLiteDatabase db = this.getReadableDatabase();
        Cursor queryVal = db.rawQuery(selectQuery, null);

        int resultCount = queryVal.getCount();
        Log.d(cachedCtx, TAG, "Result count = "+resultCount);
        JSONArray entryArray = new JSONArray();

        // Returns fals if the cursor is empty
        // in which case we return the empty JSONArray, to be consistent.
        if (queryVal.moveToFirst()) {
            for (int i = 0; i < resultCount; i++) {
                Metadata md = new Metadata();
                md.setWrite_ts(queryVal.getDouble(0));
                md.setRead_ts(queryVal.getDouble(1));
                md.setTimeZone(queryVal.getString(2));
                md.setType(queryVal.getString(3));
                md.setKey(queryVal.getString(4));
                md.setPlugin(queryVal.getString(5));
                String dataStr = queryVal.getString(6);
                if (i % 500 == 0) {
                    Log.d(cachedCtx, TAG, "Reading entry = " + i+" with key "+md.getKey()
                            + " and write_ts "+md.getWrite_ts());
                }

                /*
                 * I used to have a GSON wrapper here called "Entry" which encapsulated the metadata
                 * and the data. However, that didn't really work because it was unclear what type
                 * the data was.
                 *
                 * If we assumed that the data was a string, then GSON would escape and encode it
                 * during serialization (e.g. {"data":"{\"mProvider\":\"TEST\",\"mResults\":[0.0,0.0],\"mAccuracy\":5.5,
                 * or {"data":"[\u0027accelerometer\u0027, \u0027gyrometer\u0027, \u0027linear_accelerometer\u0027]
                 * , and expect an encoded string during deserialization.
                 *
                 * This is not consistent with the server, which returns actual JSON in the data, not a string.
                 *
                 * We could attempt to overcome this by assuming that the data is an object, not a string. But in that case,
                 * it is not clear how it would be deserialized, since we wouldn't know what class it was.
                 *
                 * So we are going to return a raw JSON object here instead of a GSONed object. That will also allow us to
                 * put it into the right wrapper object (phone_to_server or server_to_phone).
                 */
                try {
                JSONObject entry = new JSONObject();
                entry.put(METADATA_TAG, new JSONObject(new Gson().toJson(md)));
                entry.put(DATA_TAG, new JSONObject(dataStr));
                // Log.d(cachedCtx, TAG, "For row " + i + ", about to send string " + entry.toString());
                entryArray.put(entry);
                queryVal.moveToNext();
                } catch (JSONException e) {
                    Log.e(cachedCtx, TAG, "Error " + e + " while converting data string " + dataStr + " to JSON, skipping it");
                    // TODO: Re-enable once we resolve
                    // https://github.com/e-mission/cordova-usercache/issues/7
                    // putErrorValue(md, dataStr);
                    queryVal.moveToNext();
                }
            }
        }
        queryVal.close();
        Log.i(cachedCtx, TAG, "Returning array of length "+entryArray.length());
        return entryArray;
    }

    public void sync_server_to_phone(JSONArray entryArray) throws JSONException {
        SQLiteDatabase db = this.getWritableDatabase();
        Log.d(cachedCtx, TAG, "received "+entryArray.length()+" items");
        for (int i = 0; i < entryArray.length(); i++) {
            /*
             * I used to use a GSON entry class here but switched to JSON instead.
             * Look at the comment in sync_phone_to_server for details.
             */
            JSONObject entry = entryArray.getJSONObject(i);
            Metadata md = new Gson().fromJson(entry.getJSONObject(METADATA_TAG).toString(), Metadata.class);
            ContentValues newValues = new ContentValues();
            newValues.put(KEY_WRITE_TS, md.getWrite_ts());
            newValues.put(KEY_READ_TS, md.getRead_ts());
            newValues.put(KEY_TYPE, md.getType());
            newValues.put(KEY_KEY, md.getKey());
            newValues.put(KEY_PLUGIN, md.getPlugin());
            // We use get() here instead of getJSONObject() because we can get either an object or
            // an array
            String dataStr = entry.get(DATA_TAG).toString();
            Log.d(cachedCtx, TAG, "for key "+md.getKey()+", storing data of length "+dataStr.length());
            newValues.put(KEY_DATA, dataStr);
            long resultVal = db.insert(TABLE_USER_CACHE, null, newValues);
            Log.d(cachedCtx, TAG, "result of insert = "+resultVal);
        }
    }


    /*
     * TODO: This should probably be moved into the usercache somehow
     */
    public static UserCache.TimeQuery getTimeQuery(Context cachedContext, JSONArray pointList) throws JSONException {
        long start_ts = pointList.getJSONObject(0).getJSONObject("metadata").getLong("write_ts");
        long end_ts = pointList.getJSONObject(pointList.length() - 1).getJSONObject("metadata").getLong("write_ts");
        // This might still have a race in which there are new entries added with the same timestamp as the last
        // entry. Use an id instead? Or manually choose a slightly earlier ts to be on the safe side?
        // TODO: Need to figure out which one to do
        // Start slightly before and end slightly after to make sure that we get all entries
        UserCache.TimeQuery tq = new UserCache.TimeQuery(cachedContext.getString(R.string.metadata_usercache_write_ts),
                start_ts - 1, end_ts + 1);
        return tq;
    }

    // END: Methods invoked for syncing the data to the host. Not part of the interface.
}
