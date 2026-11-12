package app.brujula.life;

import android.app.Activity;
import android.Manifest;
import android.content.pm.PackageManager;
import android.provider.Settings;
import android.annotation.SuppressLint;
import android.content.Intent;
import android.database.sqlite.SQLiteStatement;
import android.database.sqlite.SQLiteDoneException;
import android.database.sqlite.SQLiteDatabase;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.view.WindowInsets;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import org.json.JSONObject;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Collections;

/** Offline-only shell. Only packaged resources can execute code or access the bridge. */
public class MainActivity extends Activity {
    static final int EXPORT = 11, IMPORT = 12;
    private static final String ORIGIN = "https://app.brujula.local/";
    private WebView web;
    private SQLiteDatabase database;
    private String pendingExport = "";
    private BackupTransfer backups;
    private volatile boolean pageReady;
    private int pageGeneration;
    private JSONObject pendingReminder;
    private static final int NOTIFICATIONS = 21;

    // JavaScript runs only packaged assets. External navigation and network requests
    // are blocked, CSP is restrictive, and user-written text is always escaped.
    @SuppressLint("SetJavaScriptEnabled")
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        openDatabase();
        try { backups = BackupTransfer.get(this); pendingExport = backups.pendingExport(); }
        catch (RuntimeException ignored) { backups = null; }
        if (state != null) pendingExport = state.getString("pendingExport", pendingExport);
        if (backups != null && state != null) backups.restorePicker(state.getInt("pendingPicker", 0));
        Reminders.ensureChannel(this);
        if (state != null && state.getString("pendingReminder") != null) {
            try { pendingReminder = Reminders.parse(state.getString("pendingReminder")); } catch (Exception ignored) { }
        }
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(247, 246, 241));
        web = new WebView(this);
        root.addView(web, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            getWindow().setDecorFitsSystemWindows(false);
            root.setOnApplyWindowInsetsListener((view, insets) -> {
                android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
                android.graphics.Insets keyboard = insets.getInsets(WindowInsets.Type.ime());
                view.setPadding(bars.left, bars.top, bars.right, Math.max(bars.bottom, keyboard.bottom));
                // The root owns all safe-area padding; do not apply it again in WebView.
                return WindowInsets.CONSUMED;
            });
            root.requestApplyInsets();
        }
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSupportZoom(false);
        web.addJavascriptInterface(new LocalStore(), "BrujulaNative");
        web.setWebViewClient(new WebViewClient() {
            @Override public void onPageStarted(WebView view, String url, android.graphics.Bitmap icon) {
                pageReady = false; pageGeneration++;
                if (backups != null) backups.pageChanged(MainActivity.this);
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) { return true; }
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req) {
                String url = req.getUrl().toString();
                if (url.startsWith(ORIGIN)) {
                    String path = req.getUrl().getPath();
                    if (path == null || path.contains("..")) return denied();
                    if (path.equals("/")) path = "/index.html";
                    String mime = path.endsWith(".js") ? "text/javascript" : path.endsWith(".css") ? "text/css" : "text/html";
                    try { return new WebResourceResponse(mime, "UTF-8", getAssets().open("web" + path)); }
                    catch (Exception ignored) { return denied(); }
                }
                return denied();
            }
        });
        if (backups != null) backups.attach(this);
        web.loadUrl(ORIGIN + "index.html");
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, this::handleBack);
        }
    }

    private WebResourceResponse denied() {
        return new WebResourceResponse("text/plain", "UTF-8", 403, "Blocked", Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
    }

    private final class LocalStore {
        @JavascriptInterface public String readReminders() { return Reminders.settings(MainActivity.this).toString(); }
        @JavascriptInterface public void configureReminder(String json) {
            runOnUiThread(() -> {
                try {
                    JSONObject config = Reminders.parse(json);
                    if (config.getBoolean("enabled") && android.os.Build.VERSION.SDK_INT >= 33
                            && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        pendingReminder = config;
                        requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, NOTIFICATIONS);
                    } else applyReminder(config);
                } catch (Exception ignored) { reminderReply(false, "reminderFailed"); }
            });
        }
        @JavascriptInterface public void updateReminderLocale(String locale) {
            try {
                JSONObject config = Reminders.settings(MainActivity.this);
                config.put("locale", "en".equals(locale) ? "en" : "es");
                Reminders.save(MainActivity.this, config);
            } catch (Exception ignored) { }
        }
        @JavascriptInterface public void notificationSettings() {
            runOnUiThread(() -> {
                try { startActivity(new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName())); }
                catch (Exception ignored) { notifyJs("reminderFailed"); }
            });
        }
        @JavascriptInterface public String read() { return readState(openDatabase()); }
        @JavascriptInterface public boolean write(String value) { return writeState(openDatabase(), value, null); }
        @JavascriptInterface public boolean restoreData(String value, String operation) {
            boolean ok = writeState(openDatabase(), value, operation);
            if (ok && backups != null) backups.consume(operation);
            return ok;
        }
        @JavascriptInterface public void consumeTransfer(String operation) { if (backups != null && operation != null) backups.consume(operation); }
        @JavascriptInterface public void pageReady() {
            runOnUiThread(() -> { pageReady = true; if (backups != null) backups.dispatch(); });
        }
        @JavascriptInterface public void exportBackup(String json, boolean recovery) {
            if (backups != null) backups.export(json, recovery); else runOnUiThread(() -> notifyJs("exportFailed"));
        }
        @JavascriptInterface public void retryExport() { if (backups != null) backups.retryExport(); }
        @JavascriptInterface public void retryTransfer() { if (backups != null) backups.retryDelivery(); }
        @JavascriptInterface public void importBackup() {
            runOnUiThread(() -> {
                if (backups == null) { notifyJs("importFailed"); return; }
                if (!backups.reserveImport()) { backupBusy(); return; }
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE); intent.setType("*/*");
                intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json", "text/plain", "application/octet-stream"});
                try { startActivityForResult(intent, IMPORT); }
                catch (Exception ignored) { backups.cancelPicker(IMPORT, pendingExport); notifyJs("importFailed"); }
            });
        }
        @JavascriptInterface public void resetData(String value) {
            boolean ok = resetState(MainActivity.this, openDatabase(), value);
            runOnUiThread(() -> { if (web != null) web.evaluateJavascript("window.resetResult({ok:" + ok + "})", null); });
        }
    }

    synchronized SQLiteDatabase openDatabase() {
        if (database != null && database.isOpen()) return database;
        SQLiteDatabase candidate = null;
        try {
            candidate = openOrCreateDatabase("brujula.db", MODE_PRIVATE, null, broken -> {
                throw new android.database.sqlite.SQLiteException("Saved database is damaged; original files preserved");
            });
            candidate.execSQL("CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK(id=1), json TEXT NOT NULL)");
            candidate.execSQL("CREATE TABLE IF NOT EXISTS import_receipt (id INTEGER PRIMARY KEY CHECK(id=1), operation TEXT NOT NULL)");
            database = candidate;
        } catch (RuntimeException error) {
            if (candidate != null) candidate.close();
            database = null;
        }
        return database;
    }

    static String readState(SQLiteDatabase db) {
        if (db == null) throw new IllegalStateException("Saved data is unavailable and has not been replaced");
        try (SQLiteStatement query = db.compileStatement("SELECT json FROM state WHERE id=1")) {
            return query.simpleQueryForString();
        } catch (SQLiteDoneException empty) { return ""; }
    }
    static boolean writeState(SQLiteDatabase db, String value, String importId) {
        if (db == null) return false;
        try {
            if (value.getBytes(StandardCharsets.UTF_8).length > 8_000_000) return false;
            new JSONObject(value);
            db.beginTransaction();
            try {
                db.execSQL("INSERT OR REPLACE INTO state (id,json) VALUES (1,?)", new Object[]{value});
                if (importId != null) db.execSQL("INSERT OR REPLACE INTO import_receipt (id,operation) VALUES (1,?)", new Object[]{importId});
                db.setTransactionSuccessful();
            } finally { db.endTransaction(); }
            return true;
        } catch (Exception ignored) { return false; }
    }
    static boolean resetState(android.content.Context context, SQLiteDatabase db, String value) {
        if (db == null) return false;
        try {
            JSONObject previous = Reminders.settings(context);
            JSONObject disabled = Reminders.parse(previous.toString()); disabled.put("enabled", false);
            if (!Reminders.save(context, disabled)) return false;
            if (writeState(db, value, null)) return true;
            Reminders.save(context, previous);
        } catch (Exception ignored) { }
        return false;
    }
    void openExportPicker(String id, boolean recovery) {
        pendingExport = id;
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE); intent.setType("application/json");
        intent.putExtra(Intent.EXTRA_TITLE, "brujula-" + (recovery ? "recovery-copy-" : "backup-") + LocalDate.now() + ".json");
        try { startActivityForResult(intent, EXPORT); }
        catch (Exception ignored) { backups.cancelPicker(EXPORT, ""); notifyJs("exportFailed"); }
    }
    boolean backupPageReady() { return pageReady && web != null && !isFinishing(); }
    boolean importApplied(String operation) {
        if (database == null) return false;
        try (SQLiteStatement query = database.compileStatement("SELECT operation FROM import_receipt WHERE id=1")) {
            return operation.equals(query.simpleQueryForString());
        } catch (RuntimeException ignored) { return false; }
    }
    void deliverBackup(String id, String script, boolean imported, long token) {
        if (!backupPageReady() || backups == null || !backups.currentDelivery(this, token)) {
            if (backups != null) backups.delivered(id, imported, false, token); return;
        }
        int generation = pageGeneration;
        web.evaluateJavascript(script, result -> {
            boolean currentPage = generation == pageGeneration && backupPageReady() && backups.currentDelivery(this, token);
            backups.delivered(id, imported, currentPage && "true".equals(result), token);
        });
    }
    void backupStagingFailed() { notifyJs("exportFailed"); }
    void backupBusy() { notifyJs("transferBusy"); if (backups != null) backups.dispatch(); }

    private void applyReminder(JSONObject config) throws Exception {
        if (config.getBoolean("enabled") && !Reminders.allowed(this)) {
            reminderReply(false, "reminderBlocked"); return;
        }
        boolean ok = Reminders.save(this, config);
        reminderReply(ok, ok ? (config.getBoolean("enabled") ? "reminderSaved" : "reminderDisabled") : "reminderFailed");
    }
    private void reminderReply(boolean ok, String key) {
        try {
            JSONObject result = new JSONObject().put("ok", ok).put("key", key).put("settings", Reminders.settings(this));
            if (web != null) web.evaluateJavascript("window.reminderResult(" + result + ")", null);
        } catch (Exception ignored) { notifyJs("reminderFailed"); }
    }
    @Override public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grants) {
        super.onRequestPermissionsResult(requestCode, permissions, grants);
        if (requestCode == NOTIFICATIONS) {
            JSONObject config = pendingReminder; pendingReminder = null;
            if (config != null && grants.length > 0 && grants[0] == PackageManager.PERMISSION_GRANTED) {
                try { applyReminder(config); } catch (Exception ignored) { reminderReply(false, "reminderFailed"); }
            } else reminderReply(false, "reminderBlocked");
        }
    }
    @Override protected void onSaveInstanceState(Bundle outState) {
        if (pendingReminder != null) outState.putString("pendingReminder", pendingReminder.toString());
        outState.putString("pendingExport", pendingExport);
        if (backups != null) outState.putInt("pendingPicker", backups.pickerRequest());
        super.onSaveInstanceState(outState);
    }
    @Override protected void onResume() {
        super.onResume();
        try { Reminders.reschedule(this); } catch (RuntimeException ignored) { }
        if (web != null) web.evaluateJavascript("window.reminderRefresh && window.reminderRefresh()", null);
    }

    private void notifyJs(String key) {
        if (web != null) web.evaluateJavascript("window.nativeNotice(" + JSONObject.quote(key) + ")", null);
    }

    @Override protected void onActivityResult(int requestCode, int resultCode, Intent result) {
        super.onActivityResult(requestCode, resultCode, result);
        if (requestCode != EXPORT && requestCode != IMPORT) return;
        if (resultCode != RESULT_OK || result == null || result.getData() == null) {
            if (backups != null) backups.cancelPicker(requestCode, pendingExport);
            return;
        }
        if (backups == null) { notifyJs(requestCode == EXPORT ? "exportFailed" : "importFailed"); return; }
        if (!backups.complete(requestCode, result.getData(), pendingExport)) backupBusy();
    }

    @Override public void onBackPressed() {
        handleBack();
    }
    private void handleBack() {
        web.evaluateJavascript("window.handleBack()", result -> { if (!"true".equals(result)) finish(); });
    }
    @Override protected void onDestroy() {
        pageReady = false;
        if (backups != null) backups.detach(this);
        if (web != null) { web.removeJavascriptInterface("BrujulaNative"); web.destroy(); web = null; }
        // SQLite is process-owned; do not close it while a bridge call may be in flight.
        super.onDestroy();
    }
}
