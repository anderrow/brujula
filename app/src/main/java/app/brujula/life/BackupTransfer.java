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
    private boolean busy, delivering;

    private BackupTransfer(Context context) {
        this.context = context;
        directory = new File(context.getNoBackupFilesDir(), "backup-transfer");
        if (!directory.exists() && !directory.mkdirs()) throw new IllegalStateException("Backup staging unavailable");
    }
    synchronized void attach(MainActivity next) {
        activity = new WeakReference<>(next); delivering = false;
        worker.execute(() -> {
            synchronized (this) {
                if (!busy && file("running.json").exists()) {
                    JSONObject running = readRecord("running.json");
                    notice(running.optString("kind").equals("import") ? "importFailed" : "exportFailed");
                    file("running.json").delete();
                }
            }
            dispatch();
        });
    }
    synchronized void detach(MainActivity previous) {
        if (activity.get() == previous) { activity.clear(); delivering = false; }
    }
    synchronized boolean current(MainActivity candidate) { return activity.get() == candidate; }
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
    synchronized String pendingExport() { return readRecord("export.json").optString("id", ""); }
    private synchronized boolean begin() {
        if (busy || file("result.json").exists()) return false;
        busy = true; return true;
    }
    void export(String text, boolean recovery) {
        if (!begin()) { dispatch(); return; }
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
        worker.execute(() -> {
            JSONObject pending = readRecord("export.json");
            String id = pending.optString("id");
            if (id.isEmpty()) { notice("exportFailed"); dispatch(); }
            else openExport(id, pending.optBoolean("recovery"));
        });
    }
    private void openExport(String id, boolean recovery) {
        main.post(() -> {
            MainActivity target;
            synchronized (this) { target = activity.get(); }
            if (target != null && !target.isFinishing()) target.openExportPicker(id, recovery);
        });
    }
    synchronized void cancelExport(String id) {
        if (id.equals(pendingExport())) { payload(id).delete(); file("export.json").delete(); }
    }
    void complete(int request, Uri uri, String exportId) {
        if (!begin()) { dispatch(); return; }
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
        if (!id.equals(result.optString("id"))) return;
        if ("import".equals(result.optString("kind"))) payload(id).delete();
        file("result.json").delete(); delivering = false;
    }
    void dispatch() {
        worker.execute(() -> {
            JSONObject result; MainActivity target;
            synchronized (this) {
                target = activity.get();
                if (target == null || delivering || !target.backupPageReady()) return;
                result = readRecord("result.json");
                if (!result.has("id")) return;
                delivering = true;
            }
            String id = result.optString("id"); boolean imported = "import".equals(result.optString("kind"));
            try {
                if (imported && target.importApplied(id)) { consume(id); return; }
                String script = imported ? "window.restoreBackup(" + JSONObject.quote(new String(Files.readAllBytes(payload(id).toPath()), StandardCharsets.UTF_8)) + "," + JSONObject.quote(id) + ")" : "(window.nativeNotice(" + JSONObject.quote(result.optString("key")) + "),true)";
                main.post(() -> target.deliverBackup(id, script, imported));
            } catch (Exception error) { synchronized (this) { delivering = false; } notice("importFailed"); }
        });
    }
    synchronized void delivered(String id, boolean imported, boolean success) {
        delivering = false;
        if (success && !imported) consume(id);
    }
}
