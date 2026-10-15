<?php
// Load balancer and pipeline smoke-test target. Keep it dependency-free.
http_response_code(200);
header('Content-Type: text/plain');
echo 'ok';
