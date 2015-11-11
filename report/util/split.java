import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.Map;

public class split {
    public static void main(String[] args) {
        BufferedReader reader = null;
        try {
            if (args.length >= 1)
                reader = new BufferedReader(new FileReader(args[0]));
            else
                reader = new BufferedReader(new InputStreamReader(System.in));
        } catch (FileNotFoundException e1) {
            System.out.println("Error opening input file");
            e1.printStackTrace();
        }

        if (reader == null) {
            System.exit(-1);
        }

        int expectedFields = 18;
        try {
            String line = null;
            long lineNum = 0;
            Map<String,BufferedWriter> files = new HashMap<String,BufferedWriter>();
            while ((line = reader.readLine()) != null) {
                lineNum++;
                String[] pieces = line.split("\t");
                if (pieces.length != expectedFields) {
                    System.err.println(String.format("Error on line %d: Found %d fields. Line was: %s", lineNum, pieces.length, line));
                }
                String day = pieces[expectedFields - 1].trim();
                BufferedWriter f = files.get(day);
                if (f == null) {
                    // Open for appending.
                    f = new BufferedWriter(new FileWriter(String.format("split/%s", day), true));
                    files.put(day, f);
                }
                f.write(line);
                f.write("\r\n");
            }
            for (Map.Entry<String,BufferedWriter> e : files.entrySet()) {
                e.getValue().close();
            }
        } catch (IOException e) {
            System.err.println("IO Error: " + e.getMessage());
        }
    }
}
