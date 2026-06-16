# Dasel Melange + apko Exercise

This project packages `dasel` version `v3.3.1` with Melange, applies a backported fix for `CVE-2026-33320`, and builds a minimal `linux/amd64` container image with apko that installs the locally built package.

## Project structure

```text
.
├── melange/
│   ├── dasel.yaml
│   └── dasel/
│       └── CVE-2026-33320.patch
├── apko/
│   └── dasel.yaml
├── tests/
│   └── test.sh
├── README.md
├── .gitignore
└── melange.rsa.pub
```

## Requirements

* Docker
* Git
* Linux/amd64 build target
* This repository cloned locally

The commands below use Docker to run Melange and apko, so Melange and apko do not need to be installed directly on the host machine.

## CVE fix

The package builds from the upstream `dasel` git repository, pinned to the `v3.3.1` tag and expected commit.

The fix for `CVE-2026-33320` is included as a patch file:

```text
melange/dasel/CVE-2026-33320.patch
```

This patch was backported from the upstream `v3.3.2` fix for YAML unbounded expansion. The package version remains `3.3.1`.

The test coverage includes a regression test payload for `CVE-2026-33320` (YAML alias expansion bomb) and verifies that parsing fails with bounded-expansion errors.

## Generate signing key

If the signing key does not exist yet, generate it:

```bash
docker run --rm \
  -v "$PWD":/work \
  -w /work \
  cgr.dev/chainguard/melange keygen
```

This creates:

```text
melange.rsa
melange.rsa.pub
```

`melange.rsa` is the private signing key and should not be committed.

`melange.rsa.pub` is the public key used by apko to trust the locally built package.

## Build the Melange package

Run from the repository root. All commands target **linux/amd64**:

```bash
docker run --rm --privileged \
  -v "$PWD":/work \
  -w /work \
  cgr.dev/chainguard/melange build melange/dasel.yaml \
  --arch amd64 \
  --out-dir packages \
  --signing-key melange.rsa \
  --source-dir melange/dasel
```

Expected output:

```text
packages/x86_64/dasel-3.3.1-r0.apk
packages/x86_64/APKINDEX.tar.gz
```

## Run the Melange package tests

Run from the repository root:

```bash
docker run --rm --privileged \
  -v "$PWD":/work \
  -w /work \
  cgr.dev/chainguard/melange test melange/dasel.yaml \
  --arch amd64 \
  --source-dir melange/dasel
```

This runs package functional tests defined in `melange/dasel.yaml`, including:

1. JSON query correctness (`dasel query -i json 'name'`)
2. CVE-2026-33320 regression verification (bounded YAML expansion behavior)

## Build the apko image

Run from the repository root:

```bash
docker run --rm \
  -v "$PWD":/work \
  -w /work \
  cgr.dev/chainguard/apko build apko/dasel.yaml dasel-amd64:latest dasel-amd64.tar \
  --arch amd64
```

This creates:

```text
dasel-amd64.tar
```

## Load the image into Docker

```bash
docker load < dasel-amd64.tar
```

Expected loaded image tag:

```text
dasel-amd64:latest-amd64
```

Check that the image exists:

```bash
docker images | grep dasel
```

## Run the image test

Make the test script executable:

```bash
chmod +x tests/test.sh
```

Run the test:

```bash
./tests/test.sh
```

Expected output:

```text
Checking dasel is runnable...
development
Checking real JSON query behavior...
Test passed
```

The test verifies that:

1. `dasel` is present and runnable inside the image.
2. `dasel` performs a real JSON query inside the container.
3. The CVE-2026-33320 payload is rejected in runtime behavior tests.

## Manual runtime test

You can also run the behavior test manually:

```bash
echo '{"name":"noa","role":"backend"}' | \
  docker run --rm -i --platform linux/amd64 dasel-amd64:latest-amd64 query -i json 'name'
```

Expected output:

```text
"noa"
```

## Commands run

The main commands used were:

```bash
docker run --rm --privileged \
  -v "$PWD":/work \
  -w /work \
  cgr.dev/chainguard/melange build melange/dasel.yaml \
  --arch amd64 \
  --out-dir packages \
  --signing-key melange.rsa \
  --source-dir melange/dasel

docker run --rm --privileged \
  -v "$PWD":/work \
  -w /work \
  cgr.dev/chainguard/melange test melange/dasel.yaml \
  --arch amd64 \
  --source-dir melange/dasel

docker run --rm \
  -v "$PWD":/work \
  -w /work \
  cgr.dev/chainguard/apko build apko/dasel.yaml dasel-amd64:latest dasel-amd64.tar \
  --arch amd64

docker load < dasel-amd64.tar

./tests/test.sh
```

## Result

The package build completed successfully.

The apko image build completed successfully.

The final image was loaded as:

```text
dasel-amd64:latest-amd64
```

The image test passed and verified real `dasel` JSON query behavior.

## Assumptions and notes

* The target platform is `linux/amd64`.
* Development was done on macOS, so Docker may print a platform warning when running the AMD64 image on Apple Silicon. This is expected.
* The generated package files, image tarball, SBOM files, and private signing key are not committed.
* The image is intentionally minimal and centered on the `dasel` binary.

