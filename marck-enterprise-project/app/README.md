# Application

The Marck Enterprise branch portal: a small PHP site. It is deliberately simple; the point of this repository is how it gets built, tested and released.

```
app/
├── src/                 Web root: index.php, hello.php ("Updated Hello World"), health.php
├── tests/run_tests.php  Dependency-free tests (exit code 1 on failure)
├── scripts/             CodeDeploy lifecycle hooks
├── appspec.yml          CodeDeploy deployment spec
├── .ebextensions/       Elastic Beanstalk settings
├── buildspec.yml        CodeBuild: lint, test, package
└── buildspec-smoke.yml  CodeBuild: smoke test QA before production
```

## Run and test locally

```bash
php app/tests/run_tests.php
MARCK_SKIP_IMDS=1 php -S localhost:8080 -t app/src
```

## How a release moves

1. **Build:** `buildspec.yml` lints every PHP file, runs the tests, and packages one bundle that both CodeDeploy and Elastic Beanstalk accept. The commit ID is written to `version.txt`.
2. **QA:** CodeDeploy installs it on the development `web` instance. `scripts/validate_service.sh` fails the deployment if `/health.php` does not answer.
3. **QA smoke test:** `buildspec-smoke.yml` checks `/health.php`, `/hello.php` and `/` on QA over HTTP. Production waits for this.
4. **Production:** CodeDeploy updates the Virginia and Oregon fleets one instance at a time, taking each out of the load balancer while it updates. A failed hook rolls back.
5. **Beanstalk:** the same bundle goes to the PHP environment.
