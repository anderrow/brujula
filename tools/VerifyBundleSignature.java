import java.io.InputStream;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.jar.JarFile;

/** Read every payload entry to validate JAR signatures and reject unsigned content. */
class VerifyBundleSignature {
    public static void main(String[] args) throws Exception {
        String expected = args[1];
        int verified = 0;
        try (JarFile jar = new JarFile(Path.of(args[0]).toFile(), true)) {
            var entries = jar.entries();
            while (entries.hasMoreElements()) {
                var entry = entries.nextElement();
                if (entry.isDirectory() || entry.getName().startsWith("META-INF/")) continue;
                try (InputStream in = jar.getInputStream(entry)) { in.transferTo(java.io.OutputStream.nullOutputStream()); }
                var certificates = entry.getCertificates();
                if (certificates == null || certificates.length != 1) throw new SecurityException("Unsigned payload entry");
                String actual = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(certificates[0].getEncoded()));
                if (!actual.equals(expected)) throw new SecurityException("Unexpected app signing certificate");
                verified++;
            }
        }
        if (verified == 0) throw new SecurityException("Empty bundle");
        System.out.println("App Bundle signature verified for all " + verified + " payload entries; certificate SHA-256: " + expected);
    }
}
