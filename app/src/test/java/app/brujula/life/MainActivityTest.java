package app.brujula.life;

import android.graphics.Insets;
import android.view.View;
import android.view.WindowInsets;
import android.webkit.WebView;
import android.widget.FrameLayout;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.android.controller.ActivityController;
import org.robolectric.annotation.Config;
import static org.junit.Assert.*;
import static org.robolectric.Shadows.shadowOf;

/** Native Android 16 layout and offline-shell regression coverage. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 36)
public class MainActivityTest {
    @Test public void safeAreasAndKeyboardAreAppliedOnce() {
        try (ActivityController<MainActivity> controller = Robolectric.buildActivity(MainActivity.class).setup()) {
            FrameLayout content = controller.get().findViewById(android.R.id.content);
            View root = content.getChildAt(0);
            WindowInsets insets = new WindowInsets.Builder()
                .setInsets(WindowInsets.Type.systemBars(), Insets.of(0, 24, 0, 48))
                .setInsets(WindowInsets.Type.displayCutout(), Insets.of(12, 0, 0, 0))
                .setInsets(WindowInsets.Type.ime(), Insets.of(0, 0, 0, 280)).build();
            assertTrue(root.dispatchApplyWindowInsets(insets).isConsumed());
            assertEquals(12, root.getPaddingLeft());
            assertEquals(24, root.getPaddingTop());
            assertEquals(280, root.getPaddingBottom());
            root.dispatchApplyWindowInsets(new WindowInsets.Builder()
                .setInsets(WindowInsets.Type.systemBars(), Insets.of(0, 24, 0, 48)).build());
            assertEquals(48, root.getPaddingBottom());
        }
    }

    @Test public void shellLoadsOnlyPackagedContentWithoutBroadFileAccess() {
        try (ActivityController<MainActivity> controller = Robolectric.buildActivity(MainActivity.class).setup()) {
            FrameLayout content = controller.get().findViewById(android.R.id.content);
            WebView web = (WebView) ((FrameLayout)content.getChildAt(0)).getChildAt(0);
            assertEquals("https://app.brujula.local/index.html", shadowOf(web).getLastLoadedUrl());
            assertFalse(web.getSettings().getAllowFileAccess());
            assertFalse(web.getSettings().getAllowContentAccess());
            assertFalse(web.getSettings().getDomStorageEnabled());
        }
    }
}
