<?php 

// Enforce strict Content-Security-Policy
header("Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' https://stackpath.bootstrapcdn.com https://cdnjs.cloudflare.com; font-src 'self' https://stackpath.bootstrapcdn.com https://cdnjs.cloudflare.com; img-src 'self';");

$server = "RDS_ENDPOINT_VALUE";
$user = "root";
$pass = "T2kVB3zgeN3YbrKS";
$database = "appdb";

$conn = mysqli_connect($server, $user, $pass, $database);

if (!$conn) {
    die("<script>alert('Connection Failed.')</script>");
}

?>