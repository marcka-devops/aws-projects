<?php
require_once __DIR__ . '/lib/platform.php';

$info = platform_info();
$version = is_readable(__DIR__ . '/version.txt') ? trim(file_get_contents(__DIR__ . '/version.txt')) : 'local';
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Marck Enterprise | Branch Portal</title>
  <link rel="stylesheet" href="assets/style.css">
</head>
<body>
  <header class="bar">
    <strong>Marck Enterprise</strong>
    <span class="muted">Branch Portal</span>
  </header>

  <main>
    <h1>Branch reports</h1>
    <p class="muted">Served by the web fleet. Refresh to see the load balancer spread requests across instances.</p>

    <table>
      <tr><th>Region</th><td><?= htmlspecialchars($info['region']) ?></td></tr>
      <tr><th>Availability Zone</th><td><?= htmlspecialchars($info['az']) ?></td></tr>
      <tr><th>Instance</th><td><?= htmlspecialchars($info['instance']) ?></td></tr>
      <tr><th>Release</th><td><code><?= htmlspecialchars(substr($version, 0, 12)) ?></code></td></tr>
    </table>

    <p><a href="hello.php">Updated Hello World page</a></p>
  </main>
</body>
</html>
