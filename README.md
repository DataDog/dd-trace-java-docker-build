# dd-trace-java-docker-build

This repository holds the original Docker images for continuous integration jobs in [dd-trace-java](https://github.com/datadog/dd-trace-java). The images built here are mirrored into `registry.ddbuild.io` before use in `dd-trace-java` CI. This is to ensure that all CI images are properly signed. See [DataDog/images image-mirroring](https://github.com/DataDog/images#image-mirroring) for more details.

## Usage

Pre-built images are available in the [GitHub Container Registry](https://github.com/DataDog/dd-trace-java-docker-build/pkgs/container/dd-trace-java-docker-build).

Image variants are available on a per JDK basis:
- The `base` variant and its aliases — `8`, `11`, `17`, `21`, `25`, and `tip` — contain the base Eclipse Temurin JDK 8, 11, 17, 21, 25, and tip JDK version releases.
- The `zulu8`, `zulu11`, `oracle8`, `ibm8`, `semeru8`, `semeru11`, `semeru17`, `graalvm17`, `graalvm21`, and `graalvm25` variants all contain the base JDKs in addition to the specific JDK from their name.
- The `latest` variant contains the base JDKs and all of the specific JDKs above.

## Development

To build all the Docker images:

```bash
./build
```

And then check the built images:

```bash
./build --test
```

## Testing

Images are built per PR for ease in testing. These test images are prefixed with `N_merge-`, where N is the PR number. See the [GitHub Container Registry](https://github.com/DataDog/dd-trace-java-docker-build/pkgs/container/dd-trace-java-docker-build) for examples.

To test these images in `dd-trace-java` CI:

1. Open a PR in [DataDog/dd-trace-java-docker-build](https://github.com/DataDog/dd-trace-java-docker-build) with the changes you want to test. It's important that this PR is opened on the latest tip of `master` to ensure that the test images are up-to-date. Let's say these changes are made in PR #123.
2. Run the [generate-test-image-yaml](https://github.com/DataDog/dd-trace-java-docker-build/tree/master/scripts/generate-test-image-yaml.sh) script to generate the YAML snippets that you will need in the following steps:
```bash
./scripts/generate-test-image-yaml.sh 123
```
Note that the test images have `renovate` enabled. This means that any changes to your upstream image (i.e. `DataDog/dd-trace-java-docker-build` PR images) will be auto-updated in `DataDog/images`. The update is done via a bot ([example](https://github.com/DataDog/images/pull/8756)).

3. Open a PR in [DataDog/images](https://github.com/DataDog/images) that adds the generated snippets to the corresponding files. This PR should be automatically merged with the `dd-prapprover` bot. If not, then manually merge the PR. The images should be generated a few minutes after the PR lands on `master`. One way to confirm this is by pulling a test image locally, e.g. by running:
```bash
docker pull registry.ddbuild.io/images/mirror/datadog/dd-trace-java-docker-build:123_merge-base
```
4. Open a PR in [DataDog/dd-trace-java](https://github.com/DataDog/dd-trace-java) that updates the `TESTER_IMAGE_VERSION_PREFIX` variable according to the output from step 2. Here, you can check your test images with `DataDog/dd-trace-java` CI.
5. For each following change made to your original PR #123, ensure the test image (i.e. prefixed with `123_merge-`) SHAs in `DataDog/images` are updated. This should be done via the bot mentioned in step 2 but can also be updated manually.
6. When the test images look good and `DataDog/dd-trace-java` CI is green, merge your `DataDog/dd-trace-java-docker-build` PR #123, close the test `DataDog/dd-trace-java` PR, and **revert the `DataDog/images` PR**.
7. Finally, confirm that the original image (i.e. no prefix) SHAs in `DataDog/images` are updated.
