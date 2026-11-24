<?php
/**
 * Generic PHP payment-plugin callback harness  (copy & edit the CONFIG block).
 *
 * Loads an UNMODIFIED plugin and drives its REAL callback entry point with a
 * forged payload. Proves "handler trusts raw input" without re-implementing
 * anything. Pair with a *_fixed.php control (see bottom) that rejects the same
 * payloads, to prove the missing check is the sole root cause.
 *
 * Run:  php harness.php
 */

define('DS', DIRECTORY_SEPARATOR);

/* ------------------------------------------------------------------ *
 * 1. Stub the MINIMAL framework surface (edit per framework).
 *    NOTE: do NOT redeclare properties the plugin itself owns (e.g. $meta).
 *    If you do, PHP fatals: "Access level to Plisio::$meta must be
 *    protected (as in class NonmerchantGateway) or weaker".
 * ------------------------------------------------------------------ */
class NonmerchantGateway {                       // framework base class name
    public function loadConfig($p) {}
    public function makeView($a = null, $b = null, $c = null) {
        return new class { public function set($k, $v = null) {} public function fetch() { return ''; } };
    }
    public function getVersion() { return '1.0.0'; }
    public function getCommonError($t) { return []; }
    public function log($a = null, $b = null, $c = null, $d = null) {}
}
class Loader {
    public static function loadComponents($o, $c) {}
    public static function loadModels($o, $m) {}
    public static function load($f) {}
}
class Language { public static function loadLang($a, $b = null, $c = null) {} }

/* ------------------------------------------------------------------ *
 * 2. Load the REAL plugin, unmodified.
 * ------------------------------------------------------------------ */
require __DIR__ . '/path/to/plugin.php';

/* ------------------------------------------------------------------ *
 * 3. CONFIG — the merchant's real key + the forged callback.
 * ------------------------------------------------------------------ */
$SECRET = 'sk_live_the_merchants_actual_api_key';

$get  = ['client_id' => '99', 'invoices' => '555=0.0001|556=999.00'];
$post = [                                   // forged: no valid verify_hash
    'order_number'    => 'forge-1',
    'status'          => 'completed',
    'source_amount'   => '999.00',
    'source_currency' => 'USD',
    'txn_id'          => '99@1700000000',
];

/* ------------------------------------------------------------------ *
 * 4. Drive the entry point.
 * ------------------------------------------------------------------ */
$gw = new Plisio();                                   // <-- plugin class
$gw->setMeta(['api_key' => $SECRET]);                 // <-- plugin's REAL setter

$r      = $gw->validate($get, $post);                 // <-- REAL entry point
$status = is_array($r) ? ($r['status'] ?? '?') : var_export($r, true);

echo "validate() status = $status\n";
echo ($status === 'approved')
    ? "RESULT: *** VULNERABLE *** forged, unsigned callback accepted as APPROVED\n"
    : "RESULT: rejected (ok)\n";

/* ------------------------------------------------------------------ *
 * 5. FIXED CONTROL — copy this file to harness_fixed.php, require a
 *    plisio_fixed.php (plugin copy with the one-line fix), and assert:
 *      [forged, bogus hash] -> rejected
 *      [forged, no hash]    -> rejected
 *      [legit, signed]      -> approved
 *    Same payloads, opposite outcome => missing check is the root cause.
 * ------------------------------------------------------------------ */
