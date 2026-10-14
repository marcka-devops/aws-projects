<?php
// Automation case study, task 2: the page uploaded to Elastic Beanstalk.
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Updated Hello World | Marck Enterprise</title>
  <link rel="stylesheet" href="assets/style.css">
</head>
<body>
  <main>
    <h1>Updated Hello World</h1>
    <p class="muted">Deployed by the Marck Enterprise pipeline at <?= htmlspecialchars(gmdate('Y-m-d H:i')) ?> UTC.</p>
  </main>
</body>
</html>
