package edu.berkeley.eecs.emission.cordova.usercache;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.Context;

import com.google.gson.Gson;

import edu.berkeley.eecs.emission.R;

public class UserCachePlugin extends CordovaPlugin {

    protected void pluginInitialize() {
        // TODO: Figure out whether we still need this, given that we are using the standard usercache
        // interface anyway. But for now, we will retain it because otherwise, I am not sure how
        // best to deal with this.

        // Let's just access the usercache so that it is created
        UserCache currCache = UserCacheFactory.getUserCache(cordova.getActivity());
        System.out.println("During plugin initialize, created usercache" + currCache);
        // let's get a document - the table is created lazily during first use
        try {
            currCache.getDocument(R.string.key_usercache_transition, JSONObject.class);
        } catch (Exception e) {
            System.out.println("Expected error "+e+" while getting document since we are reading a dummy key");
        }
    }

    @Override
    public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {
        Context ctxt = cordova.getActivity();
        if (action.equals("getDocument")) {
            final String documentKey = data.getString(0);
            String docStr = UserCacheFactory.getUserCache(ctxt).getDocument(documentKey);
            if (docStr == null) {
                // Cordova doesn't like us to return with an empty objectA
                // because then we get an NPE while initializing the result
                // https://github.com/apache/cordova-android/blob/457c5b8b3b694265c991b456b15015741ade5014/framework/src/org/apache/cordova/PluginResult.java#L52
                callbackContext.success(new JSONObject());
            } else {
                try {
                    callbackContext.success(new JSONObject(docStr));
                } catch (JSONException e) {
                    System.out.println("document was not a JSONObject, trying JSONArray");
                    callbackContext.success(new JSONArray(docStr));
                }
            }
            return true;
        } else if (action.equals("getSensorDataForInterval")) {
            final String key = data.getString(0);
            final JSONObject tqJsonObject = data.getJSONObject(1);
            final UserCache.TimeQuery timeQuery = new Gson().fromJson(tqJsonObject.toString(), UserCache.TimeQuery.class);
            JSONArray result = UserCacheFactory.getUserCache(ctxt)
                    .getSensorDataForInterval(key, timeQuery);
            callbackContext.success(result);
            return true;
        } else if (action.equals("getMessagesForInterval")) {
            final String key = data.getString(0);
            final JSONObject tqJsonObject = data.getJSONObject(1);
            final UserCache.TimeQuery timeQuery = new Gson().fromJson(tqJsonObject.toString(),
                    UserCache.TimeQuery.class);
            JSONArray result = UserCacheFactory.getUserCache(ctxt)
                    .getMessagesForInterval(key, timeQuery);
            callbackContext.success(result);
            return true;
        } else if (action.equals("getLastMessages")) {
            final String key = data.getString(0);
            final int nEntries = data.getInt(1);
            JSONArray result = UserCacheFactory.getUserCache(ctxt)
                    .getLastMessages(key, nEntries);
            callbackContext.success(result);
            return true;
        } else if (action.equals("getLastSensorData")) {
            final String key = data.getString(0);
            final int nEntries = data.getInt(1);
            JSONArray result = UserCacheFactory.getUserCache(ctxt)
                    .getLastSensorData(key, nEntries);
            callbackContext.success(result);
            return true;
        } else if (action.equals("putMessage")) {
            final String key = data.getString(0);
            final JSONObject msg = data.getJSONObject(1);
            UserCacheFactory.getUserCache(ctxt).putMessage(key, msg);
            callbackContext.success();
            return true;
        } else if (action.equals("putRWDocument")) {
            final String key = data.getString(0);
            final JSONObject msg = data.getJSONObject(1);
            UserCacheFactory.getUserCache(ctxt).putReadWriteDocument(key, msg);
            callbackContext.success();
            return true;
        } else if (action.equals("putSensorData")) {
            final String key = data.getString(0);
            final JSONObject msg = data.getJSONObject(1);
            UserCacheFactory.getUserCache(ctxt).putSensorData(key, msg);
            callbackContext.success();
            return true;
        } else if (action.equals("clearEntries")) {
            final JSONObject tqJsonObject = data.getJSONObject(1);

            final UserCache.TimeQuery timeQuery = new Gson().fromJson(tqJsonObject.toString(),
                    UserCache.TimeQuery.class);
            UserCacheFactory.getUserCache(ctxt).clearEntries(timeQuery);
            callbackContext.success();
            return true;
        } else if (action.equals("invalidateCache")) {
            final JSONObject tqJsonObject = data.getJSONObject(1);

            final UserCache.TimeQuery timeQuery = new Gson().fromJson(tqJsonObject.toString(),
                    UserCache.TimeQuery.class);
            UserCacheFactory.getUserCache(ctxt).invalidateCache(timeQuery);
            callbackContext.success();
            return true;
        } else if (action.equals("clearAll")) {
            UserCacheFactory.getUserCache(ctxt).clear();
            callbackContext.success();
            return true;
        }
        return false;
    }
}

