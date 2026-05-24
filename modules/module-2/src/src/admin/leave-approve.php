<?php

include_once '../config.inc';

    if (isset($_POST['save_leave_status'])){
        $response = $_POST['review'];
        $leaveid = $_POST['leave_id'];
        $query = mysqli_prepare($conn, "UPDATE `leave_applications` SET `status` = ? WHERE `leave_id` = ?");
        mysqli_stmt_bind_param($query, "ss", $response, $leaveid);
        mysqli_stmt_execute($query);
        header('Location: ./leave-application.php');
    }
    if (isset($_POST['delete_leave_status'])) {
        $leaveid = $_POST['leave_id'];
        $query = mysqli_prepare($conn, "DELETE FROM `leave_applications` WHERE `leave_id` = ?");
        mysqli_stmt_bind_param($query, "s", $leaveid);
        mysqli_stmt_execute($query);
        header('Location: ./leave-application.php');
    }
?>