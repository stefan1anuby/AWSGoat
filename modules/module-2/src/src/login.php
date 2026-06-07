<?php 

include 'config.inc';

session_start();

error_reporting(0);
// --- 1. GENERATE CSRF TOKEN ---
// Generate a cryptographic token if one doesn't already exist for this session
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

if (isset($_GET['organization'])) {
	$oidres = mysqli_query($conn,"SELECT organization_id from organizations where organization = '{$_GET['organization']}'");
	$oidq = mysqli_fetch_assoc($oidres);
	$oid = $oidq['organization_id'];
	$_SESSION['organization_id'] = $oid; 
    header("Location: ./superadmin/superadmin-index.php");
    exit(); // Always exit after a header redirect
}

if (isset($_POST['submit'])) {
    // --- 2. VALIDATE CSRF TOKEN ---
    // Verify that the token exists in the POST data and matches the session token
    if (!isset($_POST['csrf_token']) || !hash_equals($_SESSION['csrf_token'], $_POST['csrf_token'])) {
        die('CSRF token validation failed. Request aborted.');
    }

    $email = $_POST['email'];
    $password = md5($_POST['password']);

	$sql = "SELECT * FROM users WHERE email='$email' AND password='$password' LIMIT 1";
	$result = mysqli_query($conn, $sql);
	if ($result->num_rows > 0) {
		$row = mysqli_fetch_assoc($result);
		$_SESSION['username'] = $row['username'];
		$_SESSION['id'] = $row['id'];
		$_SESSION['isadmin']  = $row['isadmin'];
		$isadmin = $row['isadmin'];
		$_SESSION['organization_id'] = $row['organization_id'];
		
		if($result->num_rows > 1){
			while($row = $result->fetch_assoc()){
				$_SESSION['username'] = $row['username'];
				$_SESSION['id'] = $row['id'];
				$_SESSION['isadmin']  = $row['isadmin'];
				$isadmin = $row['isadmin'];
				$_SESSION['organization_id'] = $row['organization_id'];
			}
		}
		if ($isadmin == 0)
			header("Location: ./user/index.php");
		else if($isadmin == 1){
			header("Location: ./admin/admin-index.php");
		}
		else if($isadmin == 2){
			$_SESSION['organization_id'] = 1;
			header("Location: ./superadmin/superadmin-index.php");
		}
	} 
	else {
		echo "<script>alert('Email or Password is Wrong.')</script>";
	}
}

?>

<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">

	<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css">
	<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.1/css/all.min.css">
	<link rel="stylesheet" type="text/css" href="CSS/loginstyle.css">
	<link rel="icon" type="image/x-icon" href="./images/AWScloud.png">
	<title>AWS GOAT V2 - Login</title>
</head>
<body>
	

	<div class="container">
		<form action="" method="POST" class="login-email">
			<input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($_SESSION['csrf_token'], ENT_QUOTES, 'UTF-8'); ?>">
			<div style="text-align:center;"><img src="./images/logo-login.png" height ="100" width="180"></div>
			<p class="login-text" style="font-size: 2rem; font-weight: 800;">Login</p>
			<div class="input-group">
				<input type="email" placeholder="Email" name="email" value="<?php echo $email; ?>" required>
			</div>
			<div class="input-group">
				<input type="password" placeholder="Password" name="password" value="<?php echo $_POST['password']; ?>" required>
			</div>
			<div class="input-group">
				<button name="submit" class="btn">Login</button>
			</div>
		</form>
		<div style="text-align:center;">
			<section>Made with &hearts; by INE</section></br>
				<div style="text-align:center;">
					<img src="./images/ine-logo.png" height ="25" width="50">
				</div>
		</div>
		
	</div>

	
	
</body>

</html>
