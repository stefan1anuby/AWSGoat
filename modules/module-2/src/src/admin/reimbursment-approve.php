<?php

include_once '../config.inc';

    if (isset($_POST['save_rem_status'])){
        $response = $_POST['review'];
        $remid = $_POST['reimbursment_id'];
        $query = mysqli_prepare($conn, "UPDATE `reimbursments` SET `status` = ? WHERE `reimbursment_id` = ?");
        mysqli_stmt_bind_param($query, "ss", $response, $remid);
        mysqli_stmt_execute($query);
        header('Location: reimbursment.php');
    }
    if (isset($_POST['delete_rem_status'])){
        $remid = $_POST['reimbursment_id'];
        $query = mysqli_prepare($conn, "DELETE FROM `reimbursments` WHERE `reimbursment_id` = ?");
        mysqli_stmt_bind_param($query, "s", $remid);
        mysqli_stmt_execute($query);
        header('Location: reimbursment.php');
    }
?>