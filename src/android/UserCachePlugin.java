package edu.berkeley.eecs.emission.cordova.usercache;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;

import android.content.Context;

import edu.berkeley.eecs.emission.R;
import edu.berkeley.eecs.emission.cordova.usercache.UserCacheFactory;

public class UserCachePlugin extends CordovaPlugin {

    protected void pluginInitialize() {
        // Let's just access the usercache so that it is created
        UserCache currCache = UserCacheFactory.getUserCache(cordova.getActivity());
        System.out.println("During plugin initialize, created usercache" + currCache);
        // we need to put some kind of message - the table is created lazily during first use
        currCache.putMessage(R.string.key_usercache_transition, "app launched");
    }

    @Override
    public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {
        callbackContext.error("Not implemented");
        return false;
    }
}

