package us.hyph.capchildwindow;

import android.util.Log;

public class ChildWindow {

    public String echo(String value) {
        Log.i("Echo", value);
        return value;
    }
}
