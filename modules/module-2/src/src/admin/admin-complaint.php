<?php

include_once '../config.inc';

    if (isset($_POST['submit'])) {
        $compid = $_POST['complaint_id'];
        $remark = $_POST['remark'];
        $query = mysqli_prepare($conn, "UPDATE `complaints` SET `remark` = ? WHERE complaint_id = ?");
        mysqli_stmt_bind_param($query, "ss", $remark, $compid);
        mysqli_stmt_execute($query);

        header('Location: complaints.php');
    }

    if (isset($_POST['delete'])) {
        $compid = $_POST['complaint_id'];
        $query = mysqli_prepare($conn, "DELETE FROM `complaints` WHERE complaint_id = ?");
        mysqli_stmt_bind_param($query, "s", $compid);
        mysqli_stmt_execute($query);

        header('Location: complaints.php');
    }
?>