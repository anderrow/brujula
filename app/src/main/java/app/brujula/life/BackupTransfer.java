package app.brujula.life;

import android.app.Activity;
import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.AtomicFile;
import org.json.JSONObject;
import java.io.*;
import java.lang.ref.WeakReference;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Private staging and background provider I/O; imports live until explicit user disposition. */
final class BackupTransfer {
    private static final String UNAVAILABLE = "unreadable-transfer";
    private static BackupTransfer instance;
    static synchronized BackupTransfer get(Context context) {
        Context app = context.getApplicationContext();
        if (instance == null || instance.context != app) instance = new BackupTransfer(app);
        return instance;
    }
    private final Context context;
    private final File directory;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor(r -> {
        Thread thread = new Thread(r, "Brujula-backup"); thread.setDaemon(true); return thread;
    });
    private WeakReference<MainActivity> activity = new WeakReference<>(null);
    private boolean busy;
    private long delivering, sequence;
    private int picker;

    private BackupTransfer(Context context) {
        this.context = context;
        directory = new File(context.getNoBackupFilesDir(), "backup-transfer");
        if (!directory.exists() && !directory.mkdirs()) throw new IllegalStateException("Backup staging unavailable");
    }
    synchronized void attach(MainActivity next) {
        activity = new WeakReference<>(next); delivering = 0;
        worker.execute(() -> {
            synchronized (this) {
                if (!busy && file("running.json").exists()) {
                    picker = 0;
                    JSONObject running = readRecord("running.json");
                    if (!file("result.json").exists()) {
                        notice(running.optString("kind").equals("import") ? "importFailed" : "exportFailed");
                    }
                    file("running.json").delete();
                }
            }
            dispatch();
        });
    }
    synchronized void detach(MainActivity previous) {
        if (activity.get() == previous) { activity.clear(); delivering = 0; }
    }
    synchronized void pageChanged(MainActivity target) { if (activity.get() == target) delivering = 0; }
    synchronized boolean currentDelivery(MainActivity candidate, long token) { return activity.get() == candidate && delivering == token; }
    private File file(String name) { return new File(directory, name); }
    private File payload(String id) {
        if (!id.matches("[a-f0-9-]{36}")) throw new IllegalArgumentException("Invalid transfer identifier");
        return file(id + ".json");
    }
    static void writeAtomic(File file, byte[] bytes) throws IOException {
        AtomicFile target = new AtomicFile(file); FileOutputStream out = target.startWrite();
        try { out.write(bytes); target.finishWrite(out); }
        catch (IOException | RuntimeException error) { target.failWrite(out); throw error; }
    }
    private JSONObject readRecord(String name) {
        try { return new JSONObject(new String(new AtomicFile(file(name)).readFully(), StandardCharsets.UTF_8)); }
        catch (Exception ignored) { return new JSONObject(); }
    }
    private void record(String name, JSONObject value) {
        try { writeAtomic(file(name), value.toString().getBytes(StandardCharsets.UTF_8)); }
        catch (IOException error) { throw new IllegalStateException("Cannot preserve backup operation", error); }
    }
    private boolean validID(String id) { return id.matches("[a-f0-9-]{36}"); }
    private boolean validResult(JSONObject result) {
        String kind = result.optString("kind");
        return validID(result.optString("id")) && ("import".equals(kind)
            || ("notice".equals(kind) && result.opt("key") instanceof String && !result.optString("key").isEmpty()));
    }
    private boolean unreadableExport() {
        if (!file("export.json").exists()) return false;
        JSONObject pending = readRecord("export.json");
        return !validID(pending.optString("id")) || !(pending.opt("recovery") instanceof Boolean);
    }
    synchronized String pendingExport() {
        return unreadableExport() ? UNAVAILABLE : readRecord("export.json").optString("id", "");
    }
    private synchronized boolean begin() {
        if (busy || picker != 0 || file("result.json").exists() || unreadableExport()) return false;
        busy = true; return true;
    }
    synchronized boolean reserveImport() {
        if (busy || picker != 0 || file("result.json").exists() || unreadableExport()) return false;
        picker = MainActivity.IMPORT; return true;
    }
    synchronized int pickerRequest() { return picker; }
    synchronized void restorePicker(int request) {
        if (!busy && picker == 0 && (request == MainActivity.IMPORT || request == MainActivity.EXPORT)) picker = request;
    }
    synchronized void cancelPicker(int request, String exportId) {
        if (picker != request) return;
        picker = 0;
        if (request == MainActivity.EXPORT && !exportId.isEmpty()) cancelExport(exportId);
    }
    private void rejected() {
        main.post(() -> { MainActivity target = activity.get(); if (target != null) target.backupBusy(); });
    }
    void export(String text, boolean recovery) {
        if (!begin()) { rejected(); return; }
        worker.execute(() -> {
            try {
                if (!pendingExport().isEmpty()) throw new IOException("Finish the pending export first");
                byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
                if (bytes.length > 32_000_000) throw new IOException("Recovery copy is too large");
                String id = UUID.randomUUID().toString();
                writeAtomic(payload(id), bytes);
                record("export.json", new JSONObject().put("id", id).put("recovery", recovery));
                openExport(id, recovery);
            } catch (Exception error) { notice("exportFailed"); }
            finally { synchronized (this) { busy = false; } dispatch(); }
        });
    }
    void retryExport() {
        if (!begin()) { rejected(); return; }
        worker.execute(() -> {
            try {
                JSONObject pending = readRecord("export.json");
                String id = pending.optString("id");
                if (id.isEmpty()) notice("exportFailed");
                else openExport(id, pending.optBoolean("recovery"));
            } finally { synchronized (this) { busy = false; } dispatch(); }
        });
    }
    private void openExport(String id, boolean recovery) {
        synchronized (this) { picker = MainActivity.EXPORT; }
        main.post(() -> {
            MainActivity target;
            synchronized (this) { target = activity.get(); }
            if (target != null && !target.isFinishing()) target.openExportPicker(id, recovery);
            else {
                cancelPicker(MainActivity.EXPORT, ""); notice("exportFailed"); dispatch();
            }
        });
    }
    synchronized void cancelExport(String id) {
        if (id.equals(pendingExport())) { payload(id).delete(); file("export.json").delete(); }
    }
    boolean complete(int request, Uri uri, String exportId) {
        synchronized (this) {
            if (busy || picker != request || file("result.json").exists()) return false;
            picker = 0; busy = true;
        }
        worker.execute(() -> {
            String id = request == MainActivity.EXPORT ? exportId : UUID.randomUUID().toString();
            try {
                record("running.json", new JSONObject().put("id", id).put("kind", request == MainActivity.EXPORT ? "export" : "import"));
                if (request == MainActivity.EXPORT) {
                    if (!id.equals(pendingExport())) throw new IOException("Export payload is unavailable");
                    try (InputStream in = new FileInputStream(payload(id)); OutputStream out = context.getContentResolver().openOutputStream(uri, "wt")) {
                        if (out == null) throw new IOException("Destination unavailable");
                        copy(in, out, 32_000_000);
                    }
                    cancelExport(id); notice("exported");
                } else {
                    AtomicFile target = new AtomicFile(payload(id)); FileOutputStream out = target.startWrite();
                    try (InputStream in = context.getContentResolver().openInputStream(uri)) {
                        if (in == null) throw new IOException("Source unavailable");
                        copy(in, out, 8_000_000); target.finishWrite(out);
                    } catch (Exception error) { target.failWrite(out); throw error; }
                    record("result.json", new JSONObject().put("id", id).put("kind", "import"));
                }
            } catch (Exception error) { notice(request == MainActivity.EXPORT ? "exportFailed" : "importFailed"); }
            finally { file("running.json").delete(); synchronized (this) { busy = false; } dispatch(); }
        });
        return true;
    }
    static void copy(InputStream in, OutputStream out, int limit) throws IOException {
        byte[] bytes = new byte[8192]; int count, total = 0;
        while ((count = in.read(bytes)) != -1) {
            total += count; if (total > limit) throw new IOException("Backup exceeds supported size");
            out.write(bytes, 0, count);
        }
    }
    private void notice(String key) {
        try { record("result.json", new JSONObject().put("id", UUID.randomUUID().toString()).put("kind", "notice").put("key", key)); }
        catch (Exception ignored) { main.post(() -> { MainActivity target = activity.get(); if (target != null) target.backupStagingFailed(); }); }
    }
    synchronized void consume(String id) {
        JSONObject result = readRecord("result.json");
        if (UNAVAILABLE.equals(id)) {
            boolean discarded = false;
            if (file("result.json").exists() && !validResult(result)) { new AtomicFile(file("result.json")).delete(); discarded = true; }
            if (unreadableExport()) { new AtomicFile(file("export.json")).delete(); discarded = true; }
            if (discarded) { delivering = 0; picker = 0; }
            return; // Preserve payloads whose operation metadata cannot be read.
        }
        if (!id.equals(result.optString("id"))) return;
        if ("import".equals(result.optString("kind"))) payload(id).delete();
        file("result.json").delete(); delivering = 0;
    }
    void dispatch() {
        worker.execute(() -> {
            JSONObject result; MainActivity target; long token;
            synchronized (this) {
                target = activity.get();
                if (target == null || delivering != 0 || !target.backupPageReady()) return;
                result = readRecord("result.json");
                if (!validResult(result)) {
                    if (!file("result.json").exists() && !unreadableExport()) return;
                    result = new JSONObject();
                }
                token = delivering = ++sequence;
            }
            boolean unavailable = !validResult(result);
            String id = unavailable ? UNAVAILABLE : result.optString("id");
            boolean imported = unavailable || "import".equals(result.optString("kind"));
            try {
                if (!unavailable && imported && target.importApplied(id)) { consume(id); return; }
                String script = unavailable ? "window.importUnavailable(" + JSONObject.quote(id) + ")"
                    : imported ? "window.restoreBackup(" + JSONObject.quote(new String(Files.readAllBytes(payload(id).toPath()), StandardCharsets.UTF_8)) + "," + JSONObject.quote(id) + ")"
                    : "(window.nativeNotice(" + JSONObject.quote(result.optString("key")) + "),true)";
                main.post(() -> target.deliverBackup(id, script, imported, token));
            } catch (Exception error) {
                // Keep the staged result through temporary read failures; retry/cancel is explicit.
                main.post(() -> target.deliverBackup(id, "window.importUnavailable(" + JSONObject.quote(id) + ")", true, token));
            }
        });
    }
    synchronized void delivered(String id, boolean imported, boolean success, long token) {
        if (delivering != token) return;
        delivering = 0;
        if (success && !imported) consume(id);
    }
}
