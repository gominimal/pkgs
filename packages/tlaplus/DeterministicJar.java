// Writes a jar whose bytes depend only on its inputs: entries in sorted path
// order, directory entries included, and one fixed timestamp on every entry.
//
// `jar --create` cannot do both at once. Fed only files (a sorted list), it
// writes no directory entries, and TLA+ needs them: SANY and TLC locate their
// standard modules with ClassLoader.getResource("tla2sany"), which is null for
// a jar without a "tla2sany/" entry. Fed directories, it recurses in
// filesystem order, so the entry order would depend on the build host.
//
// Run in source-file mode: java DeterministicJar.java <out.jar> <manifest> <root>
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.stream.Stream;
import java.util.zip.Deflater;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public class DeterministicJar {
    // The zip (DOS) epoch; jar --date accepts nothing earlier.
    private static final LocalDateTime EPOCH = LocalDateTime.of(1980, 1, 1, 0, 0, 2);

    public static void main(String[] args) throws IOException {
        Path out = Paths.get(args[0]);
        Path manifest = Paths.get(args[1]);
        Path root = Paths.get(args[2]);

        List<String> names = new ArrayList<>();
        try (Stream<Path> walk = Files.walk(root)) {
            walk.filter(p -> !p.equals(root)).forEach(p -> {
                String name = root.relativize(p).toString().replace('\\', '/');
                if (name.equals("META-INF") || name.equals("META-INF/MANIFEST.MF")) {
                    return; // written first, below
                }
                names.add(Files.isDirectory(p) ? name + "/" : name);
            });
        }
        Collections.sort(names);

        try (OutputStream fos = Files.newOutputStream(out);
             ZipOutputStream zip = new ZipOutputStream(fos)) {
            zip.setLevel(Deflater.BEST_COMPRESSION);
            // The manifest leads, as java.util.jar.JarInputStream expects.
            putDir(zip, "META-INF/");
            putFile(zip, "META-INF/MANIFEST.MF", Files.readAllBytes(manifest));
            for (String name : names) {
                if (name.endsWith("/")) {
                    putDir(zip, name);
                } else {
                    putFile(zip, name, Files.readAllBytes(root.resolve(name)));
                }
            }
        }
    }

    private static void putDir(ZipOutputStream zip, String name) throws IOException {
        ZipEntry e = new ZipEntry(name);
        e.setTimeLocal(EPOCH);
        zip.putNextEntry(e);
        zip.closeEntry();
    }

    private static void putFile(ZipOutputStream zip, String name, byte[] data) throws IOException {
        ZipEntry e = new ZipEntry(name);
        e.setTimeLocal(EPOCH);
        zip.putNextEntry(e);
        zip.write(data);
        zip.closeEntry();
    }
}
