// Ghidra headless post-script: decompile every function to a file.
// Emits markers of the form:
//   // ==== FUN_ram_00021e70 @ ram:00021e70 (size=1234) ====
// which downstream extractors parse to pull a function by address or by line.
//
// MUST be .java (PyGhidra installs do not run .py postScripts).
// Invoked by sbf_ghidra_decompile.sh.
//
// @category SBF
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.util.task.ConsoleTaskMonitor;
import java.io.PrintWriter;

public class DumpDecomp extends GhidraScript {
    public void run() throws Exception {
        String[] args = getScriptArgs();
        String out = (args.length > 0) ? args[0] : "/tmp/decomp_all.c";

        DecompInterface ifc = new DecompInterface();
        ifc.openProgram(currentProgram);
        ConsoleTaskMonitor mon = new ConsoleTaskMonitor();

        PrintWriter w = new PrintWriter(out);
        FunctionIterator fit = currentProgram.getFunctionManager().getFunctions(true);
        int n = 0;
        while (fit.hasNext()) {
            Function f = fit.next();
            DecompileResults r = ifc.decompileFunction(f, 60, mon);
            w.println("// ==== " + f.getName() + " @ " + f.getEntryPoint()
                      + " (size=" + f.getBody().getNumAddresses() + ") ====");
            if (r != null && r.decompileCompleted()) {
                w.println(r.getDecompiledFunction().getC());
            } else {
                w.println("// (decompile failed)");
            }
            w.println();
            n++;
        }
        w.close();
        println("decompiled " + n + " functions -> " + out);
    }
}
