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
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import android.os.Bundle;
import android.os.Looper;
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
    public static class FlakyActivity extends MainActivity {
        boolean failOpening = true;
        @Override public SQLiteDatabase openOrCreateDatabase(String name, int mode,
                SQLiteDatabase.CursorFactory factory, android.database.DatabaseErrorHandler handler) {
            if (failOpening) throw new android.database.sqlite.SQLiteException("Synthetic unavailable storage");
            return super.openOrCreateDatabase(name, mode, factory, handler);
        }
    }
    public static class TransferActivity extends MainActivity {
        volatile String received;
        @Override boolean backupPageReady() { return true; }
        @Override void deliverBackup(String id, String script, boolean imported, long token) {
            received = script;
            BackupTransfer.get(this).delivered(id, imported, true, token);
        }
    }
    private void await(java.util.function.BooleanSupplier condition) throws Exception {
        long deadline = System.nanoTime() + java.util.concurrent.TimeUnit.SECONDS.toNanos(5);
        while (!condition.getAsBoolean() && System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle(); Thread.sleep(5);
        }
        assertTrue("Background transfer did not reach its expected state", condition.getAsBoolean());
    }
    private WebView shellWeb(MainActivity activity) {
        FrameLayout content = activity.findViewById(android.R.id.content);
        return (WebView) ((FrameLayout)content.getChildAt(0)).getChildAt(0);
    }
    private void bridgeAction(WebView web, String name) throws Exception {
        Object bridge = shadowOf(web).getJavascriptInterface("BrujulaNative");
        java.lang.reflect.Method method = bridge.getClass().getDeclaredMethod(name);
        method.setAccessible(true); method.invoke(bridge);
        shadowOf(Looper.getMainLooper()).idle();
    }
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
        try (SQLiteDatabase db = stateDatabase()) {
            assertTrue(MainActivity.writeState(db, "{\"original\":true}", null));
            db.execSQL("CREATE TRIGGER reject_reset BEFORE INSERT ON state BEGIN SELECT RAISE(FAIL, 'Synthetic write denial'); END");
            assertFalse(MainActivity.resetState(app, db, "{}"));
            assertEquals("{\"original\":true}", MainActivity.readState(db));
        }
        assertTrue(Reminders.settings(app).getBoolean("enabled"));
        assertTrue(Reminders.settings(app).getBoolean("registered"));
        assertEquals(1, shadowOf(app.getSystemService(android.app.AlarmManager.class)).getScheduledAlarms().size());
    }

    @Test public void diskStateSurvivesCloseAndReopen() {
        Application app = RuntimeEnvironment.getApplication();
        String value = "{\"note\":\"" + "a".repeat(3_000_000) + "\"}";
        try (SQLiteDatabase db = app.openOrCreateDatabase("disk-reopen.db", 0, null)) {
            db.execSQL("CREATE TABLE state (id INTEGER PRIMARY KEY CHECK(id=1), json TEXT NOT NULL)");
            assertTrue(MainActivity.writeState(db, value, null));
        }
        try (SQLiteDatabase reopened = app.openOrCreateDatabase("disk-reopen.db", 0, null)) {
            assertEquals(value, MainActivity.readState(reopened));
        }
    }

    @Test public void databaseRetry() {
        Application app = RuntimeEnvironment.getApplication();
        try (SQLiteDatabase db = app.openOrCreateDatabase("brujula.db", 0, null)) {
            db.execSQL("CREATE TABLE state (id INTEGER PRIMARY KEY CHECK(id=1), json TEXT NOT NULL)");
            assertTrue(MainActivity.writeState(db, "{\"original\":true}", null));
        }
        try (ActivityController<FlakyActivity> controller = Robolectric.buildActivity(FlakyActivity.class).setup()) {
            FlakyActivity activity = controller.get();
            assertNull(activity.openDatabase());
            activity.failOpening = false;
            assertEquals("{\"original\":true}", MainActivity.readState(activity.openDatabase()));
        }
    }

    @Test public void pickerReservationSurvivesRecreationAndCancellationIsScoped() throws Exception {
        Application app = RuntimeEnvironment.getApplication();
        BackupTransfer transfer = BackupTransfer.get(app);
        try (ActivityController<MainActivity> first = Robolectric.buildActivity(MainActivity.class).setup()) {
            assertTrue(transfer.reserveImport());
            assertFalse(transfer.reserveImport());
            Bundle saved = new Bundle(); first.saveInstanceState(saved);
            assertEquals(MainActivity.IMPORT, saved.getInt("pendingPicker"));
            first.pause().stop().destroy();
            try (ActivityController<MainActivity> next = Robolectric.buildActivity(MainActivity.class).setup(saved)) {
                assertEquals(MainActivity.IMPORT, transfer.pickerRequest());
                assertFalse(transfer.reserveImport());
                transfer.cancelPicker(MainActivity.IMPORT, "");
                assertTrue(transfer.reserveImport());
                transfer.cancelPicker(MainActivity.IMPORT, "");
            }
        }
        File directory = new File(app.getNoBackupFilesDir(), "backup-transfer");
        String export = UUID.randomUUID().toString(), unrelated = UUID.randomUUID().toString();
        BackupTransfer.writeAtomic(new File(directory, export + ".json"), new byte[]{1});
        BackupTransfer.writeAtomic(new File(directory, unrelated + ".json"), new byte[]{2});
        BackupTransfer.writeAtomic(new File(directory, "export.json"), new JSONObject().put("id", export).put("recovery", false).toString().getBytes(StandardCharsets.UTF_8));
        transfer.restorePicker(MainActivity.EXPORT);
        transfer.cancelPicker(MainActivity.IMPORT, export);
        assertTrue(new File(directory, export + ".json").exists());
        transfer.cancelPicker(MainActivity.EXPORT, export);
        assertFalse(new File(directory, export + ".json").exists());
        assertTrue(new File(directory, unrelated + ".json").exists());
    }

    @Test public void importRedelivery() throws Exception {
        Application app = RuntimeEnvironment.getApplication();
        BackupTransfer.get(app);
        File directory = new File(app.getNoBackupFilesDir(), "backup-transfer");
        String id = UUID.randomUUID().toString(), value = "{\"note\":\"Preserved import\"}";
        File result = new File(directory, "result.json"), payload = new File(directory, id + ".json");
        BackupTransfer.writeAtomic(payload, value.getBytes(StandardCharsets.UTF_8));
        BackupTransfer.writeAtomic(result, new JSONObject().put("id", id).put("kind", "import").toString().getBytes(StandardCharsets.UTF_8));
        // A process can stop after recording completion but before removing its running marker.
        BackupTransfer.writeAtomic(new File(directory, "running.json"), new JSONObject().put("id", id).put("kind", "import").toString().getBytes(StandardCharsets.UTF_8));
        try (ActivityController<TransferActivity> first = Robolectric.buildActivity(TransferActivity.class).setup()) {
            await(() -> first.get().received != null);
            assertTrue(first.get().received.contains("Preserved import"));
            assertTrue(result.exists());
        }
        try (ActivityController<TransferActivity> next = Robolectric.buildActivity(TransferActivity.class).setup()) {
            await(() -> next.get().received != null);
            assertTrue(next.get().received.contains(id));
            assertTrue(MainActivity.writeState(next.get().openDatabase(), value, id));
        }
        try (ActivityController<TransferActivity> afterCommit = Robolectric.buildActivity(TransferActivity.class).setup()) {
            await(() -> !result.exists());
            assertNull(afterCommit.get().received);
            assertFalse(payload.exists());
            assertEquals(value, MainActivity.readState(afterCommit.get().openDatabase()));
        }
    }

    @Test public void pageDelivery() throws Exception {
        Application app = RuntimeEnvironment.getApplication(); BackupTransfer.get(app);
        File result = new File(app.getNoBackupFilesDir(), "backup-transfer/result.json");
        String id = UUID.randomUUID().toString();
        BackupTransfer.writeAtomic(result, new JSONObject().put("id", id).put("kind", "notice").put("key", "exported").toString().getBytes(StandardCharsets.UTF_8));
        try (ActivityController<MainActivity> controller = Robolectric.buildActivity(MainActivity.class).setup()) {
            WebView web = shellWeb(controller.get());
            bridgeAction(web, "pageReady");
            await(() -> shadowOf(web).getLastEvaluatedJavascript().contains("window.nativeNotice"));
            android.webkit.ValueCallback<String> obsolete = shadowOf(web).getLastEvaluatedJavascriptCallback();
            shadowOf(web).getWebViewClient().onPageStarted(web, "https://app.brujula.local/index.html", null);
            bridgeAction(web, "pageReady");
            await(() -> shadowOf(web).getLastEvaluatedJavascriptCallback() != obsolete);
            android.webkit.ValueCallback<String> current = shadowOf(web).getLastEvaluatedJavascriptCallback();
            obsolete.onReceiveValue("true");
            assertTrue("An obsolete page must not acknowledge the new delivery", result.exists());
            current.onReceiveValue("true");
            assertFalse(result.exists());
        }
    }

    @Test public void deliveryRetry() throws Exception {
        Application app = RuntimeEnvironment.getApplication(); BackupTransfer transfer = BackupTransfer.get(app);
        File directory = new File(app.getNoBackupFilesDir(), "backup-transfer");
        String id = UUID.randomUUID().toString(); File result = new File(directory, "result.json");
        BackupTransfer.writeAtomic(result, new JSONObject().put("id", id).put("kind", "import").toString().getBytes(StandardCharsets.UTF_8));
        try (ActivityController<MainActivity> controller = Robolectric.buildActivity(MainActivity.class).setup()) {
            WebView web = shellWeb(controller.get()); bridgeAction(web, "pageReady");
            await(() -> shadowOf(web).getLastEvaluatedJavascript().startsWith("window.importUnavailable"));
            shadowOf(web).getLastEvaluatedJavascriptCallback().onReceiveValue("true");
            assertTrue(result.exists());
            BackupTransfer.writeAtomic(new File(directory, id + ".json"), "{}".getBytes(StandardCharsets.UTF_8));
            bridgeAction(web, "retryTransfer");
            await(() -> shadowOf(web).getLastEvaluatedJavascript().startsWith("window.restoreBackup"));
            assertTrue(result.exists());
            transfer.consume(id);
            assertFalse(result.exists());
        }
    }

    @Test public void metadataRetry() throws Exception {
        Application app = RuntimeEnvironment.getApplication(); BackupTransfer transfer = BackupTransfer.get(app);
        File directory = new File(app.getNoBackupFilesDir(), "backup-transfer"), result = new File(directory, "result.json");
        BackupTransfer.writeAtomic(result, "{unreadable metadata".getBytes(StandardCharsets.UTF_8));
        try (ActivityController<MainActivity> controller = Robolectric.buildActivity(MainActivity.class).setup()) {
            WebView web = shellWeb(controller.get()); bridgeAction(web, "pageReady");
            await(() -> shadowOf(web).getLastEvaluatedJavascript().contains("unreadable-transfer"));
            shadowOf(web).getLastEvaluatedJavascriptCallback().onReceiveValue("true");
            assertTrue(result.exists()); assertFalse(transfer.reserveImport());
            String id = UUID.randomUUID().toString();
            // Directly repair the fixture: Windows renameTo does not emulate Android AtomicFile replacement.
            java.nio.file.Files.write(result.toPath(), new JSONObject().put("id", id).put("kind", "notice").put("key", "exported").toString().getBytes(StandardCharsets.UTF_8));
            bridgeAction(web, "retryTransfer");
            await(() -> shadowOf(web).getLastEvaluatedJavascript().contains("window.nativeNotice"));
            shadowOf(web).getLastEvaluatedJavascriptCallback().onReceiveValue("true");
            assertFalse(result.exists());
            File export = new File(directory, "export.json"), payload = new File(directory, id + ".json");
            BackupTransfer.writeAtomic(export, "{unreadable export metadata".getBytes(StandardCharsets.UTF_8));
            BackupTransfer.writeAtomic(payload, "Preserved staged payload".getBytes(StandardCharsets.UTF_8));
            transfer.cancelExport("unreadable-transfer");
            assertTrue(export.exists());
            bridgeAction(web, "retryTransfer");
            await(() -> shadowOf(web).getLastEvaluatedJavascript().contains("unreadable-transfer"));
            transfer.consume("unreadable-transfer");
            assertFalse(export.exists()); assertTrue(payload.exists());
            assertTrue(transfer.reserveImport()); transfer.cancelPicker(MainActivity.IMPORT, "");
        }
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
