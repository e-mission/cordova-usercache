package edu.berkeley.eecs.emission.cordova.usercache;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.Context;

import edu.berkeley.eecs.emission.R;
import edu.berkeley.eecs.emission.cordova.usercache.UserCacheFactory;

public class UserCachePlugin extends CordovaPlugin {

    protected void pluginInitialize() {
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
        callbackContext.error("Not implemented");
        return false;
    }
}

