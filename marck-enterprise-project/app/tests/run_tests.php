<?php
/**
 * Dependency-free tests for the pages. Run: php app/tests/run_tests.php
 * Exits non-zero on the first failure so CodeBuild and GitHub Actions stop the release.
 */
putenv('MARCK_SKIP_IMDS=1');

$src = dirname(__DIR__) . '/src';
$failures = 0;

function render(string $file): string
{
    ob_start();
    include $file;
    return ob_get_clean();
}

function check(string $name, bool $ok): void
{
    global $failures;
    echo ($ok ? 'PASS ' : 'FAIL ') . $name . PHP_EOL;
    if (!$ok) {
        $failures++;
    }
}

$hello = render("$src/hello.php");
check('hello.php says "Updated Hello World"', str_contains($hello, 'Updated Hello World'));

$index = render("$src/index.php");
check('index.php shows the company name', str_contains($index, 'Marck Enterprise'));
check('index.php links to the hello page', str_contains($index, 'href="hello.php"'));
check('index.php escapes platform values', !str_contains($index, '<script'));

$health = render("$src/health.php");
check('health.php returns ok', trim($health) === 'ok');

$info = platform_info();
check('platform_info falls back off EC2', $info['region'] === 'unknown');

echo PHP_EOL . ($failures === 0 ? 'All tests passed' : "$failures test(s) failed") . PHP_EOL;
exit($failures === 0 ? 0 : 1);
