package app.brujula.life;

import android.graphics.Insets;
import android.view.View;
import android.view.WindowInsets;
import android.webkit.WebView;
import android.widget.FrameLayout;
import android.database.sqlite.SQLiteDatabase;
import android.app.Application;
import org.robolectric.RuntimeEnvironment;
import org.json.JSONObject;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
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
    private SQLiteDatabase stateDatabase() {
        SQLiteDatabase db = SQLiteDatabase.create(null);
        db.execSQL("CREATE TABLE state (id INTEGER PRIMARY KEY CHECK(id=1), json TEXT NOT NULL)");
        db.execSQL("CREATE TABLE import_receipt (id INTEGER PRIMARY KEY CHECK(id=1), operation TEXT NOT NULL)");
        return db;
    }

    @Test public void largeStatesUseScalarReadAndByteLimitsPreserveThePreviousValue() {
        try (SQLiteDatabase db = stateDatabase()) {
            assertEquals("", MainActivity.readState(db));
            String large = "{\"note\":\"" + "a".repeat(3_000_000) + "\"}";
            assertTrue(MainActivity.writeState(db, large, "import-one"));
            assertEquals(large, MainActivity.readState(db));
            assertEquals("import-one", db.compileStatement("SELECT operation FROM import_receipt WHERE id=1").simpleQueryForString());
            assertFalse(MainActivity.writeState(db, "{\"note\":\"" + "€".repeat(3_000_000) + "\"}", "rejected"));
            assertEquals(large, MainActivity.readState(db));
            assertEquals("import-one", db.compileStatement("SELECT operation FROM import_receipt WHERE id=1").simpleQueryForString());
        }
        assertThrows(IllegalStateException.class, () -> MainActivity.readState(null));
        try (SQLiteDatabase db = SQLiteDatabase.create(null)) {
            assertThrows(RuntimeException.class, () -> MainActivity.readState(db));
        }
    }

    @Test public void resetWriteFailurePreservesTheOldReminder() throws Exception {
        Application app = RuntimeEnvironment.getApplication();
        shadowOf(app).grantPermissions(android.Manifest.permission.POST_NOTIFICATIONS);
        JSONObject enabled = Reminders.parse("{\"enabled\":true,\"frequency\":\"daily\",\"hour\":20,\"minute\":0,\"weekday\":1,\"monthDay\":1,\"locale\":\"en\"}");
        assertTrue(Reminders.save(app, enabled));
        assertFalse(MainActivity.resetState(app, null, "{}"));
        assertTrue(Reminders.settings(app).getBoolean("enabled"));
        assertTrue(Reminders.settings(app).getBoolean("registered"));
    }

    @Test public void providerCopyRejectsOversizeWithoutPretendingSuccess() throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        BackupTransfer.copy(new ByteArrayInputStream(new byte[8192]), out, 8192);
        assertEquals(8192, out.size());
        assertThrows(IOException.class, () -> BackupTransfer.copy(new ByteArrayInputStream(new byte[8193]), new ByteArrayOutputStream(), 8192));
    }
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
