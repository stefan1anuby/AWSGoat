<?php 

$server = "RDS_ENDPOINT_VALUE";
$user = "root";
$pass = "RDS_PASSWORD_VALUE";
$database = "appdb";

$conn = mysqli_connect($server, $user, $pass, $database);

if (!$conn) {
    die("<script>alert('Connection Failed.')</script>");
}

?>