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

function getPresignedS3Url($s3Url) {
    if (!$s3Url || strpos($s3Url, 'amazonaws.com') === false) {
        return $s3Url;
    }

    $bucketName = getenv('S3_BUCKET_NAME');
    $region = getenv('AWS_REGION') ?: 'eu-central-1';

    if (!$bucketName) {
        return $s3Url;
    }

    // Extract the S3 Key from the URL
    // Format: https://bucketname.s3.region.amazonaws.com/s3Key
    $parsedUrl = parse_url($s3Url);
    if (!isset($parsedUrl['path'])) {
        return $s3Url;
    }
    
    // The path starts with a slash, so we remove it
    $s3Key = ltrim($parsedUrl['path'], '/');

    $config = [
        'version' => 'latest',
        'region'  => $region,
    ];

    $endpointUrl = getenv('S3_ENDPOINT_URL');
    if ($endpointUrl) {
        $config['endpoint'] = $endpointUrl;
        $config['use_path_style_endpoint'] = true;
        // In path style endpoint, the first part of the path is the bucket name
        // The URL would be: http://endpoint/bucket/s3Key
        $pathParts = explode('/', $s3Key, 2);
        if (count($pathParts) == 2 && $pathParts[0] == $bucketName) {
            $s3Key = $pathParts[1];
        }
    }

    try {
        $s3 = new S3Client($config);
        $cmd = $s3->getCommand('GetObject', [
            'Bucket' => $bucketName,
            'Key'    => $s3Key
        ]);

        $request = $s3->createPresignedRequest($cmd, '+15 minutes');
        return (string) $request->getUri();
    } catch (Exception $e) {
        error_log("Error generating presigned URL: " . $e->getMessage());
        return $s3Url;
    }
}
?>