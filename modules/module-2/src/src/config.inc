<?php 

// Enforce strict Content-Security-Policy
header("Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' https://stackpath.bootstrapcdn.com https://cdnjs.cloudflare.com; font-src 'self' https://stackpath.bootstrapcdn.com https://cdnjs.cloudflare.com; img-src 'self';");
// Prevent Clickjacking attacks
header("X-Frame-Options: SAMEORIGIN");

// Disable displaying errors to the client when not on DEBUG
define('DEBUG', false);
error_reporting(E_ALL);
ini_set('display_errors', DEBUG ? 'On' : 'Off');

session_set_cookie_params([
    'lifetime' => 3600,         // Cookie expires in 1 hour
    'path' => '/',              // Available across the whole site
    'domain' => '',             // Default domain
    'secure' => true,           // ONLY send over HTTPS (Requires SSL/TLS)
    'httponly' => true,         // Prevent JavaScript from reading the cookie
    'samesite' => 'Strict'      // Prevent cross-site request forgery
]);

$server = "RDS_ENDPOINT_VALUE";
$user = "root";
$pass = "T2kVB3zgeN3YbrKS";
$database = "appdb";

$conn = mysqli_connect($server, $user, $pass, $database);

if (!$conn) {
    die("<script>alert('Connection Failed.')</script>");
}

?>