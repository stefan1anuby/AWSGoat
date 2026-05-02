<?php
require_once '/var/www/html/vendor/autoload.php';

use Aws\S3\S3Client;

function uploadToS3($tmpFile, $s3Prefix, $fileName) {
    // 1. Debug Input Data
    error_log("Starting S3 Upload Process...");
    error_log("Source File: $tmpFile");
    error_log("Target Path: $s3Prefix/$fileName");

    $bucketName = getenv('S3_BUCKET_NAME');
    $region = getenv('AWS_REGION') ?: 'eu-central-1';

    // 2. Verify Environment Variables
    if (!$bucketName) {
        error_log("ERROR: S3_BUCKET_NAME environment variable is not set!");
    }
    error_log("Using Bucket: $bucketName in Region: $region");

    $config = [
        'version' => 'latest',
        'region'  => $region,
    ];

    $endpointUrl = getenv('S3_ENDPOINT_URL');
    if ($endpointUrl) {
        error_log("Custom Endpoint Detected: $endpointUrl");
        $config['endpoint'] = $endpointUrl;
        $config['use_path_style_endpoint'] = true;
    }

    try {
        $s3 = new S3Client($config);
        $s3Key = $s3Prefix . '/' . $fileName;

        error_log("Attempting to putObject: $s3Key");

        $result = $s3->putObject([
            'Bucket' => $bucketName,
            'Key'    => $s3Key,
            'Body'   => fopen($tmpFile, 'rb'),
            'ACL'    => 'public-read',
        ]);

        // 3. Confirm Success
        error_log("Successfully uploaded to S3. VersionId: " . ($result['VersionId'] ?? 'None'));

        $publicUrl = getenv('S3_PUBLIC_URL');
        if ($publicUrl) {
            $finalUrl = rtrim($publicUrl, '/') . '/' . $bucketName . '/' . $s3Key;
        } else {
            $finalUrl = "https://{$bucketName}.s3.{$region}.amazonaws.com/{$s3Key}";
        }

        error_log("Final Public URL: $finalUrl");
        return $finalUrl;

    } catch (Exception $e) {
        error_log("GENERAL ERROR: " . $e->getMessage());
        return false;
    }
}
?>