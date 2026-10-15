<?php
/**
 * Reads where this copy of the app is running from the EC2 instance metadata service (IMDSv2).
 * Returns "unknown" values off EC2 or when MARCK_SKIP_IMDS is set (tests, local runs).
 */
function platform_info(): array
{
    $unknown = ['region' => 'unknown', 'az' => 'unknown', 'instance' => 'unknown'];
    if (getenv('MARCK_SKIP_IMDS')) {
        return $unknown;
    }

    $base = 'http://169.254.169.254/latest';
    $token = @file_get_contents("$base/api/token", false, stream_context_create(['http' => [
        'method' => 'PUT',
        'header' => "X-aws-ec2-metadata-token-ttl-seconds: 60\r\n",
        'timeout' => 1,
    ]]));
    if ($token === false) {
        return $unknown;
    }

    $get = function (string $path) use ($base, $token): string {
        $value = @file_get_contents("$base/meta-data/$path", false, stream_context_create(['http' => [
            'header' => "X-aws-ec2-metadata-token: $token\r\n",
            'timeout' => 1,
        ]]));
        return $value === false ? 'unknown' : $value;
    };

    return [
        'region' => $get('placement/region'),
        'az' => $get('placement/availability-zone'),
        'instance' => $get('instance-id'),
    ];
}
