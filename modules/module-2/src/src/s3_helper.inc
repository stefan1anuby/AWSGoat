<?php
require_once '/var/www/html/vendor/autoload.php';

use Aws\S3\S3Client;

function uploadToS3($tmpFile, $s3Prefix, $fileName) {
    $bucketName = getenv('S3_BUCKET_NAME');
    $region = getenv('AWS_REGION') ?: 'eu-central-1';

    $config = [
        'version' => 'latest',
        'region'  => $region,
    ];

    $endpointUrl = getenv('S3_ENDPOINT_URL');
    if ($endpointUrl) {
        $config['endpoint'] = $endpointUrl;
        $config['use_path_style_endpoint'] = true;
    }

    $s3 = new S3Client($config);
    $s3Key = $s3Prefix . '/' . $fileName;

    $s3->putObject([
        'Bucket' => $bucketName,
        'Key'    => $s3Key,
        'Body'   => fopen($tmpFile, 'rb'),
        'ACL'    => 'public-read',
    ]);

    $publicUrl = getenv('S3_PUBLIC_URL');
    if ($publicUrl) {
        return rtrim($publicUrl, '/') . '/' . $bucketName . '/' . $s3Key;
    }

    return "https://{$bucketName}.s3.{$region}.amazonaws.com/{$s3Key}";
}
?>
